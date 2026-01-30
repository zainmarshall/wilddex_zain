#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8000}"
RELOAD_FLAG="${RELOAD:-}" # set RELOAD=1 for dev autoreload
if [ -n "$RELOAD_FLAG" ]; then
  uvicorn main:app --reload --host 0.0.0.0 --port "$PORT"
else
  uvicorn main:app --host 0.0.0.0 --port "$PORT"
fi
