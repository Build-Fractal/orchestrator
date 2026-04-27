#!/usr/bin/env bash
# scripts/verify/m027-p00-fs-race.sh — M027/P00 FR-13 / FR-19 / AD-3 / SC-19.
#
# Tests the snapshot semantic: the rollup must copy the JSONL into a
# tmpfile before iterating it, so a concurrent truncation of the source
# does NOT crash or skew the output.
#
# Procedure:
#   1. Build a temp working JSONL (copy of corrupt-line.jsonl).
#   2. Background a sleeper that truncates the working JSONL after 0.05s.
#   3. Run the rollup synchronously against the working JSONL.
#   4. Assert the rollup exited 0 (snapshot protected it from truncation).
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-fs-race.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
SRC_FIX="$PROJECT_ROOT/tests/fixtures/m027-p00/corrupt-line.jsonl"

if [ ! -r "$ROLLUP" ] || [ ! -r "$SRC_FIX" ]; then
  printf 'FAIL: %s rollup-or-fixture-missing\n' "$NAME" >&2
  exit 1
fi

tmp="$(mktemp -d)"
bg_pid=""
cleanup() {
  if [ -n "$bg_pid" ]; then
    kill "$bg_pid" 2>/dev/null || true
    wait "$bg_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

work="$tmp/work.jsonl"
cp "$SRC_FIX" "$work"

# Background process: sleep then truncate the working JSONL.
(
  sleep 0.05
  : > "$work"
) &
bg_pid=$!

# Run the rollup synchronously.
out="$tmp/out"
err="$tmp/err"
bash "$ROLLUP" --granularity task --milestone M999 --log "$work" >"$out" 2>"$err"
rc=$?

# Reap the background truncator.
wait "$bg_pid" 2>/dev/null || true
bg_pid=""

if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s rollup rc=%d expected 0 (snapshot should protect)\n' "$NAME" "$rc" >&2
  cat "$err" >&2 || true
  exit 1
fi

printf 'PASS: %s rollup-rc=0 under concurrent truncation\n' "$NAME"
exit 0
