# Historical benchmark log

**Source:** Archived project notes dated 21 September 2026. These figures are transcribed historical observations, not independently verified with current hardware and not produced by the sample `scripts/benchmark.py`.

## Hardware and test conditions

- 2 vs 3 x86 desktops, each Intel Core i7-4770, 16 GiB RAM, Ubuntu 24.04.1.
- CPU-only inference; no discrete GPUs.
- A quantized 3B-family GGUF LLM on each participating node.
- Tests recorded under different concurrent request counts with no background load in the notes.
- Aggregate rate is **total completion tokens / elapsed wall time** across all concurrent requests, not tokens/sec/user.

| Nodes | Parallel requests | Total output rate (tok/s) |
|---:|---:|---:|
| 2 | 1 | ~9.4 |
| 2 | 4 | 19.59 |
| 2 | 8 | 17.84 |
| 3 | 1 | ~9.5 |
| 3 | 6 | 33.22 |
| 3 | 9 | 32.02 |
| 3 | 12 | 34.92 |

## Interpretation and limitations

- The measurements suggest improved *aggregate* throughput as more independent machines serve parallel requests.
- Different concurrency levels were measured for 2-node and 3-node configurations; this is not a controlled, matched-throughput scaling study.
- Per-request latencies, prompt lengths, raw benchmark logs, seeds, measurement variance and token-count definition are not included in the surviving record.
- Avoid calculating a precise scaling factor from mismatched concurrency tests.
- Do not extrapolate a fourth node as an achieved result. A fourth node was only planned.

## Suggested reproduction protocol

1. Fix one GGUF model, quantization, llama.cpp build and prompt set across every node.
2. Record CPU model, thread count, RAM, network, generation settings, prompt tokens and output-token limits.
3. Warm model instances and measure both cold-start and steady-state runs.
4. Sweep concurrency in matched configurations (e.g., 1, 2, 4, 6, 8, 12).
5. Save raw per-request durations, model-reported tokens and node names; repeat multiple times.
6. Report mean, median and p95 latency, total token throughput and failure rate with run timestamps.

Run the example probe as follows (requires a running gateway):

```bash
python scripts/benchmark.py --model your-model-id --concurrency 6 --max-tokens 64
```
