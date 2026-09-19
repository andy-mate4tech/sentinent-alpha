#!/usr/bin/env bash
# OpenAI-compatible bridge on :8099 using kimi-cli or cursor-agent (or DeepSeek).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONPATH="${ROOT}/backend:${PYTHONPATH:-}"
export LLM_MODE="${LLM_MODE:-cli}"
export LLM_CLI_PROVIDER="${LLM_CLI_PROVIDER:-kimi}"
cd "${ROOT}/backend"
exec python3 -m uvicorn app.llm_bridge.server:app --host 0.0.0.0 --port 8099
