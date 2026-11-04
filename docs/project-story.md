# Engineering case study: local AI under hardware constraints

## The challenge

I wanted to serve local LLMs to multiple clients while relying on existing desktop hardware instead of dedicated inference GPUs. The machines had only 16 GiB RAM each and consumer CPUs from an older generation. That made memory use, quantization, threading and operational reliability first-class design constraints.

## Work carried out

1. Set up Ubuntu nodes, a Python virtual environment, and CPU builds of llama.cpp.
2. Started local model-serving processes, initially using Qwen2.5-3B GGUF quantized weights.
3. Added Ray to discover nodes and explore affinity-based actor placement.
4. Built an HTTP gateway exposing OpenAI-style chat-completion paths and routing to node-local inference services.
5. Compared throughput for concurrent request counts and experimented with CPU threads, OpenBLAS and model choices.
6. Explored RPC-based cross-host model execution as a separate experimental path, without mixing those results with the request-routing benchmarks.

## Problems and learning

- **Dynamic node identities:** Ray node IDs can change after restarts, so runtime discovery is safer than storing IDs in configuration files.
- **Throughput vs. latency:** Adding model replicas helps parallel clients, but does not necessarily speed up one completion.
- **Memory-aware operation:** Quantized GGUF models allowed CPU-only inference without dedicated GPUs.
- **Compatibility:** A stable HTTP API and SSE output enable use from common LLM clients.
- **Failure handling:** The gateway should track in-flight work and handle node failures instead of assuming every server is always available.

## What is demonstrated publicly

The original operational notes and one experimental script survived; the final deployed API file did not. This repository therefore combines documented observations with reconstructed, sanitized reference code. It intentionally does not present the reference gateway as an exact original artifact or its test results as measurements from the original cluster.

## Next engineering iteration

Obtain fresh, reproducible measurements, including raw run logs and per-request latency distributions. Expand automated failover tests, add access controls and run a controlled same-concurrency comparison across two and three nodes.
