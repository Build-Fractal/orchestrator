#!/usr/bin/env bash
# scripts/diagnostics/detective-recommend.sh — Cross-command detective recommendation helper (FR-8)
# Usage: detective-recommend.sh --symptom "<text>" [--path "<error-path>"]
# Emits RECOMMEND: orchestrator:detective line to stderr if path is orchestrator-internal.
# If --path is omitted, always emits (caller has already verified orchestrator-side).
# Advisory only — always exits 0, never blocks the calling command.
set -uo pipefail

SYMPTOM=""
ERROR_PATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --symptom) SYMPTOM="$2"; shift 2 ;;
    --path)    ERROR_PATH="$2"; shift 2 ;;
    *)         shift ;;
  esac
done

if [ -z "$SYMPTOM" ]; then
  exit 0
fi

# If --path provided, only recommend when path is orchestrator-internal.
if [ -n "$ERROR_PATH" ]; then
  ORCH_ROOT="$(bash "$(dirname "$0")/../state/resolve-root.sh" 2>/dev/null || echo "")"
  if [ -z "$ORCH_ROOT" ]; then
    exit 0  # can't resolve root — can't confirm orchestrator-internal
  fi
  # Make absolute if relative (prepend PROJECT_ROOT)
  case "$ORCH_ROOT" in
    /*) ;;
    *)  ORCH_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/$ORCH_ROOT" ;;
  esac
  case "$ERROR_PATH" in
    "$ORCH_ROOT"*) ;;  # orchestrator-internal — continue to emit
    *) exit 0 ;;       # user-project path — skip silently
  esac
fi

printf 'RECOMMEND: orchestrator:detective --symptom "%s"\n' "$SYMPTOM" >&2
exit 0
