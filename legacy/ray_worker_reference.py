"""Historical Ray worker-placement concept, sanitized.

Reconstructed from an archived September 2026 project note, NOT the complete
original production script. Requires running Ray, llama-server and requests.
Do not use as-is for public-facing services.
"""

import os
import requests
import ray
from ray.util.scheduling_strategies import NodeAffinitySchedulingStrategy

ray.init(address="auto")

# Replace with actual accessible private LAN hosts.
HOSTS = os.environ.get("RAY_CLUSTER_HOSTS", "192.168.50.10,192.168.50.11").split(",")


def node_id_for_ip(ip: str) -> str:
    for node in ray.nodes():
        if node["Alive"] and node["NodeManagerAddress"] == ip:
            return node["NodeID"]
    raise RuntimeError(f"Ray node not found for host {ip}")


@ray.remote(num_cpus=1)
class LLMWorker:
    def __init__(self, ip: str):
        self.ip = ip

    def generate(self, payload: dict) -> dict:
        reply = requests.post(f"http://{self.ip}:8000/v1/chat/completions", json=payload, timeout=300)
        reply.raise_for_status()
        return {"node": self.ip, "response": reply.json()}


if __name__ == "__main__":
    workers = [
        LLMWorker.options(scheduling_strategy=NodeAffinitySchedulingStrategy(
            node_id=node_id_for_ip(host), soft=False
        )).remote(host)
        for host in HOSTS
    ]
    print(f"Ray actors scheduled: {len(workers)}. Submit jobs through .generate.remote(payload).")
