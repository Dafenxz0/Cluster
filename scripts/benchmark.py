#!/usr/bin/env python3
"""Small reproducible concurrent-request probe (requires httpx).

Generates aggregate throughput from *server-reported* completion token counts.
Does not estimate tokens from string length when usage data is absent.
"""
import argparse
import asyncio
import os
import time

import httpx


async def main():
    p = argparse.ArgumentParser()
    p.add_argument("--url", default="http://127.0.0.1:9000/v1/chat/completions")
    p.add_argument("--model", default=os.getenv("CLUSTER_MODEL", "your-model-id"))
    p.add_argument("--concurrency", type=int, default=6)
    p.add_argument("--max-tokens", type=int, default=64)
    args = p.parse_args()
    if args.concurrency < 1 or args.max_tokens < 1:
        p.error("concurrency and max-tokens must be positive")

    body = {"model": args.model, "messages": [{"role": "user", "content": "Explain CPU inference in one paragraph."}], "max_tokens": args.max_tokens, "stream": False}
    async with httpx.AsyncClient(timeout=300.0) as client:
        async def run_one(i):
            start = time.perf_counter()
            try:
                res = await client.post(args.url, json=body)
                res.raise_for_status()
                data = res.json()
                return {"index": i, "ok": True, "time": time.perf_counter() - start, "node": data.get("cluster_node"), "tokens": (data.get("usage") or {}).get("completion_tokens")}
            except (httpx.HTTPError, ValueError) as exc:
                return {"index": i, "ok": False, "error": str(exc)}
        start = time.perf_counter()
        results = await asyncio.gather(*(run_one(i) for i in range(args.concurrency)))
        elapsed = time.perf_counter() - start
    ok = [r for r in results if r["ok"]]
    tokens = [r["tokens"] for r in ok]
    print(f"Completed: {len(ok)}/{args.concurrency}; wall time: {elapsed:.2f}s")
    for row in results:
        print(row)
    if ok and all(isinstance(t, int) for t in tokens):
        print(f"Aggregate generation throughput: {sum(tokens) / elapsed:.2f} tokens/sec (server-reported)")
    else:
        print("Throughput unavailable: missing server-reported completion_tokens or requests failed")


if __name__ == "__main__":
    asyncio.run(main())
