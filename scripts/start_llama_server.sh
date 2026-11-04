#!/usr/bin/env bash
set -Eeuo pipefail
: "${LLAMA_SERVER:?Set LLAMA_SERVER to path of llama-server binary}"
: "${MODEL_PATH:?Set MODEL_PATH to the path of an existing GGUF file}"
PORT="${PORT:-8000}"
THREADS="${THREADS:-4}"
CTX_SIZE="${CTX_SIZE:-4096}"
HOST="${HOST:-127.0.0.1}"
# For multi-host networking set HOST to a private LAN interface and protect it
# with a firewall. Never expose an unauthenticated inference server publicly.
exec "$LLAMA_SERVER" -m "$MODEL_PATH" --host "$HOST" --port "$PORT"   -t "$THREADS" -c "$CTX_SIZE" -ngl 0
