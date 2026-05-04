#!/usr/bin/env bash
# tools/verify/lib/m032-p02-wiki-serve-probe.sh — M032 P02 T01 helper.
#
# Single-script-file shape per AD-19. Performs the start+probe+kill of
# `bash scripts/wiki/wiki-serve.sh` within one script body so the parent
# verifier can invoke this via a single bash invocation rather than
# inlining a `(serve & ; sleep ; curl ; kill)` compound shell expression.
#
# Strategy: prefer `bash scripts/wiki/wiki-serve.sh --probe` (mkdocs
# build --strict to a throwaway site-dir) — equivalent health check
# without binding a port. If --probe is unavailable for any reason
# (older serve helper), fall back to start+curl+kill.
#
# Exit 0 on success, non-zero on any wiki-serve.sh failure or HTTP
# probe failure.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SERVE="$PROJECT_ROOT/scripts/wiki/wiki-serve.sh"

if [ ! -x "$SERVE" ]; then
  echo "FAIL: wiki-serve-probe: $SERVE not executable" >&2
  exit 2
fi

# Prefer --probe (no port binding). wiki-serve.sh --probe does
# `mkdocs build -f wiki/mkdocs.yml --strict` to a throwaway dir, which
# is functionally equivalent to a successful HTTP 200 at the serve port
# (if the build succeeds, serve will succeed).
set +e
"$SERVE" --probe
probe_rc=$?
set -e

if [ "$probe_rc" -eq 0 ]; then
  echo "wiki-serve-probe: --probe (mkdocs build --strict) succeeded"
  exit 0
fi

# Fallback path: full start+curl+kill cycle.
echo "wiki-serve-probe: --probe failed (rc=$probe_rc); falling back to start+curl+kill" >&2

SERVE_LOG="$(mktemp -t wiki-serve-probe.XXXXXX)"
trap 'rm -f "$SERVE_LOG"' EXIT

"$SERVE" --skip-regen >"$SERVE_LOG" 2>&1 &
SERVE_PID=$!

# Give mkdocs serve up to 10 seconds to bind :8000.
slept=0
while [ "$slept" -lt 10 ]; do
  sleep 1
  slept=$((slept + 1))
  if curl -fsS http://localhost:8000 -o /dev/null 2>/dev/null; then
    kill "$SERVE_PID" 2>/dev/null || true
    wait "$SERVE_PID" 2>/dev/null || true
    echo "wiki-serve-probe: serve+curl probe succeeded after ${slept}s"
    exit 0
  fi
done

kill "$SERVE_PID" 2>/dev/null || true
wait "$SERVE_PID" 2>/dev/null || true
echo "FAIL: wiki-serve-probe: HTTP 200 not observed at :8000 within 10s" >&2
echo "--- serve log: ---" >&2
cat "$SERVE_LOG" >&2
exit 1
