"""FastAPI gateway demo that forwards OpenAI-style requests to llama-server.

For trusted private LANs only. No auth, TLS termination, rate limiting or
origin validation; do not expose this app directly to the public Internet.
"""
import json
import logging
import os

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, StreamingResponse

from .balancer import LeastBusyPool
from .config import load_nodes

log = logging.getLogger("cluster")
app = FastAPI(title="CPU LLM Cluster - Reference Gateway", version="0.1.0")

NODES = load_nodes()
BY_NAME = {n.name: n for n in NODES}
POOL = LeastBusyPool([n.name for n in NODES])
MODEL = os.getenv("CLUSTER_MODEL", "your-model-id")
TIMEOUT = httpx.Timeout(300.0, connect=10.0)


@app.get("/health")
async def health():
    return {"status": "ok", "configured_nodes": len(NODES), "active_jobs": await POOL.snapshot()}


@app.get("/cluster/status")
async def status():
    async with httpx.AsyncClient(timeout=httpx.Timeout(3.0)) as client:
        async def probe(node):
            try:
                resp = await client.get(f"{node.base_url}/health")
                return {"name": node.name, "healthy": resp.status_code == 200}
            except httpx.HTTPError:
                return {"name": node.name, "healthy": False}
        import asyncio
        states = await asyncio.gather(*(probe(node) for node in NODES))
    return {"nodes": states, "active_jobs": await POOL.snapshot()}


@app.get("/v1/models")
async def models():
    return {"object": "list", "data": [{"id": MODEL, "object": "model", "owned_by": "local-cluster"}]}


@app.post("/v1/chat/completions")
async def chat(request: Request):
    try:
        payload = await request.json()
    except (ValueError, json.JSONDecodeError):
        raise HTTPException(status_code=400, detail="Invalid JSON")
    if not isinstance(payload, dict) or not isinstance(payload.get("messages"), list):
        raise HTTPException(status_code=422, detail="Expected an object containing messages list")

    stream = bool(payload.get("stream", False))
    payload["model"] = MODEL  # backend model selected in deployment config
    attempted = set()

    for _ in NODES:
        name = await POOL.reserve(exclude=attempted)
        attempted.add(name)
        node = BY_NAME[name]
        url = f"{node.base_url}/v1/chat/completions"

        if not stream:
            try:
                async with httpx.AsyncClient(timeout=TIMEOUT) as client:
                    response = await client.post(url, json=payload)
                    response.raise_for_status()
                    data = response.json()
                    if not isinstance(data, dict):
                        raise ValueError("Unexpected upstream response")
                    data["cluster_node"] = name
                    return JSONResponse(data)
            except (httpx.HTTPError, ValueError) as exc:
                log.warning("Node %s failed: %s", name, exc)
            finally:
                await POOL.release(name)
            continue

        # Establish connection and verify HTTP status before sending SSE headers.
        client = httpx.AsyncClient(timeout=TIMEOUT)
        try:
            upstream_req = client.build_request("POST", url, json=payload)
            upstream = await client.send(upstream_req, stream=True)
            upstream.raise_for_status()
        except httpx.HTTPError as exc:
            log.warning("Node %s stream failed before headers: %s", name, exc)
            await client.aclose()
            await POOL.release(name)
            continue

        async def body(upstream=upstream, client=client, name=name):
            try:
                async for chunk in upstream.aiter_bytes():
                    yield chunk
            finally:
                await upstream.aclose()
                await client.aclose()
                await POOL.release(name)

        return StreamingResponse(body(), media_type="text/event-stream", headers={"Cache-Control": "no-cache", "X-Cluster-Node": name})

    raise HTTPException(status_code=503, detail="No inference node available")
