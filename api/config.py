"""Configuration for a sanitized reference LLM gateway."""
from dataclasses import dataclass
import json
import os
from pathlib import Path


@dataclass(frozen=True)
class Node:
    name: str
    host: str
    port: int = 8000

    @property
    def base_url(self) -> str:
        return f"http://{self.host}:{self.port}"


def load_nodes(path: str | None = None) -> list[Node]:
    chosen = Path(path or os.environ.get("CLUSTER_NODES_FILE", "examples/nodes.example.json"))
    raw = json.loads(chosen.read_text(encoding="utf-8"))
    nodes = []
    for n in raw["nodes"]:
        host = n.get("host", "")
        name = n.get("name", "")
        if not host or not name or "://" in host or "/" in host:
            raise ValueError("Each node needs a name and plain host/IP (no URL scheme)")
        port = int(n.get("port", 8000))
        if port < 1 or port > 65535:
            raise ValueError("Invalid node port")
        nodes.append(Node(name=name, host=host, port=port))
    if not nodes:
        raise ValueError("No nodes configured")
    if len({n.name for n in nodes}) != len(nodes):
        raise ValueError("Duplicate node names")
    return nodes
