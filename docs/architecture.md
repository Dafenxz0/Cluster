# Architecture and development history

## Design target

Run small quantized language models on 3 existing x86 desktops without dedicated GPUs, prioritizing accessible local inference and concurrent users rather than maximum single-request performance.

## Recorded topology

- Three active Intel i7-4770 / 16 GiB Ubuntu 24.04.1 nodes on a low-latency Ethernet LAN.
- One head node hosting API gateway, UI and Ray head service.
- Two workers running inference server and Ray worker service.
- Fourth similar host was planned but not part of the measured setup.
- Each active node independently hosts its own model files.

## Two technical stages

1. **Ray actor stage:** Ray was used to discover live node IDs and schedule worker actors using `NodeAffinitySchedulingStrategy`. The actors forwarded HTTP requests to their node-local `llama-server`. The historical mechanism is represented in `legacy/ray_worker_reference.py`.
2. **HTTP gateway stage:** The later documented system used a FastAPI HTTP gateway, node discovery from a local JSON file, round-robin scheduling, fallback to other nodes, SSE streaming and compatibility with OpenAI-style chat clients. The self-contained reference in `api/` uses least-busy scheduling with rotated ties, which was explored in the earlier stage. These implementations are not claimed to be identical to the archived deployed source.

**Important:** Ray is not a speed-up mechanism for a *single* inference in this setup. In the main design each node produces a separate inference independently. Only the separately explored `llama.cpp` RPC mode attempts to execute one model using computation on several machines.

## Operational insights recorded

- Model quantization made local deployment tractable within 16 GiB memory per node.
- Comparing 4, 5 and 6 CPU threads and OpenBLAS builds exposed bottlenecks and scheduling trade-offs.
- Ray node identifiers changed on restart, so they should be discovered dynamically rather than hardcoded.
- Storage placement (NVMe vs SATA) affected model-load and observed performance in the recorded system.
- Context size and parallel slot count had to be balanced under tight RAM constraints.
- In the final documented topology, a per-node HTTP inference process was the main worker execution path.

## Ports in the recorded architecture

| Port | Component | Typical placement |
|---|---|---|
| 6379 | Ray head control plane | Head only; LAN-only |
| 8000 | llama-server | Every active node |
| 9000 | FastAPI gateway | Head |
| 3000 | Open WebUI | Head |
| 8010 | Experimental distributed RPC server | Head, separate stack |

Not all of these services are implemented by the files in this repository. In particular, there is no claim that the stored systemd units or original Docker stack are fully reproduced.
