# Experimental DeepSeek BF16/FP16 MoE conversion patch

> **Status: archived experiment, not validated end-to-end.** This directory preserves a small source modification recovered from the original local AI cluster work. It is **not** a claim of a production-ready DeepSeek converter, successful GGUF export, or an inference performance improvement.

## What this contains

- [`deepseek-bf16-mini.patch`](./deepseek-bf16-mini.patch): a 73-line addition / 5-line removal patch against `conversion/deepseek.py` in the local `llama.cpp` source tree.
- [`VALIDATION.md`](./VALIDATION.md): provenance, checks that can be reproduced, outstanding test cases, and known limitations.

The original local checkout identified `llama.cpp` commit **`543158132`** (recorded in September 2026). The changed file in the experimental `llama-hyper-src` copy had a timestamp of **23 September 2026**; timestamps are historical file metadata, not proof of when the implementation was authored.

Upstream project: [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp). The patch contains only the changed lines, not a redistribution of the full upstream source tree, model weights, or checkpoints.

## Motivation

The observed converter implementation took the MXFP4 route for DeepSeek V4 MoE routed experts. The experiment aimed to support *some* DeepSeek-V4-format mini/replica checkpoints that instead store individual routed expert weights in BF16/FP16 without MXFP4 `.scale` tensors.

## What the patch changes

1. Detects whether any routed expert `.scale` tensor is present in the input tensor names.
2. Keeps the pre-existing MXFP4 expert-writing path when such a tensor is present.
3. Otherwise loads each expert projection (`w1`, `w2`, `w3`) and stacks its weights into an `[experts, out, in]` tensor with `torch.stack`.
4. Maps the resulting `experts_merged` tensors to the corresponding GGUF expert tensor types.
5. Only forces `MOSTLY_MXFP4_MOE` output type when MXFP4 expert scales were detected; it avoids that override on the BF16/FP16 branch.

## How to inspect or apply

Use a **disposable** checkout at the recorded upstream revision. From the root of that checkout:

```bash
git checkout 543158132
git apply --check /path/to/deepseek-bf16-mini.patch
git apply /path/to/deepseek-bf16-mini.patch
```

`git apply --check` is read-only. `git apply` modifies the working tree; only run it on a disposable or clean checkout. Check the upstream revision and diff before applying. The recorded revision is a local observation, not a compatibility guarantee for newer `llama.cpp` releases.

## Limitations

This is **exploratory converter code**, not a vetted implementation. In particular:

- Detecting just *one* expert `.scale` tensor assumes a consistent source layout; mixed or incomplete layouts may be routed incorrectly.
- Every expert is materialized eagerly for stacking, potentially increasing peak RAM usage.
- Missing experts raise `KeyError`; inconsistent shapes or unsupported dtypes may fail during stacking.
- No successful full HF-to-GGUF conversion, correct numerical output, or usable inference result has been supplied with this recovered artifact.
- `torch.stack` is a data-layout operation here; it is **not** evidence of faster inference, better accuracy, or model training.

See [validation notes](./VALIDATION.md) before making any functional claims.
