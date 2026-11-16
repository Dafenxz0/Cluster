# Recovery and validation notes

## Provenance

- **Source:** a user-recovered patch from the local cluster machine, derived from a unified diff between `llama.cpp/conversion/deepseek.py` and `llama-hyper-src/conversion/deepseek.py`.
- **Original upstream checkout:** local `llama.cpp` reported commit `543158132`, with `origin` set to `https://github.com/ggml-org/llama.cpp.git`.
- **Historical modified-file timestamp:** `2026-09-23 14:00:25 +0200` (filesystem metadata only).
- **Patch SHA-256:** `738cf7328cc77266d3d61440c2ce1f4dd4269cf3577648cedb6ce5b634f99922`.
- **Patch diff summary:** one file changed, 73 insertions and 5 deletions.
- **Backup observation:** `deepseek.py.backup-before-bf16-mini` matched the unmodified `llama.cpp` comparison file byte-for-byte (`cmp` exit status 0).

## Verified from the recovered patch

- The unified diff is syntactically parsable with `git apply --stat` and `git apply --numstat`.
- The modified logic detects `.ffn.experts.*.scale` source tensors and introduces a non-MXFP4 expert-stacking branch.
- No credentials, machine IP addresses, or local infrastructure hostnames were found in the uploaded patch in a targeted string scan. This is not a general security audit.

## Reported but not independently reproduced

- The user's original command included `git apply --check` and showed no error output; this suggests it could apply to the local source tree, but the exit code was not captured in the provided output.

## Not verified

- Successful end-to-end conversion of a specific DeepSeek model.
- GGUF tensor correctness, output values, supported dtypes, and runtime inference compatibility.
- Backward compatibility with actual MXFP4 checkpoints.
- Performance or memory improvements.
- Validity across different upstream `llama.cpp` revisions.

## Suggested reproducibility tests

1. Check patch application against a clean, pinned `llama.cpp` checkout.
2. Build a minimal BF16/FP16 synthetic expert-tensor fixture (including all `w1`, `w2`, `w3` experts).
3. Assert the stacked tensor shape and expert order; check that original source tensors are consumed only once.
4. Verify missing-expert, mixed-format, and shape-mismatch behavior.
5. Convert a licensed, small compatible checkpoint to GGUF and compare numerical outputs against the original framework.
6. Test a known MXFP4 checkpoint to ensure no regression.
7. Record exact environment, model revision, logs, model license, hashes, RAM peaks, and success/failure outcomes.

Until these tests pass, describe this artifact as a **recovered experimental patch** rather than a supported feature.
