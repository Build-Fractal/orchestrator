#!/usr/bin/env bash
# scripts/verify/m027-p00-source-filter.sh — M027/P00 FR-3 / SC-6.
#
# Exercises --source filter behaviour against tests/fixtures/m027-p00/
# estimate-only.jsonl:
#   - --source runtime  → "no records match filter" annotation, exit 0
#   - --source estimate → non-empty paired data row, exit 0
#   - --source all      → equivalent row count to --source estimate
#   - --source bogus    → exit 2 (usage / bad arg)
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-source-filter.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
FIX="$PROJECT_ROOT/tests/fixtures/m027-p00/estimate-only.jsonl"

if [ ! -r "$ROLLUP" ] || [ ! -r "$FIX" ]; then
  printf 'FAIL: %s rollup-or-fixture-missing\n' "$NAME" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

# --- (1) --source runtime: empty rollup + annotation, exit 0 -------------
out_runtime="$tmp/runtime.out"
bash "$ROLLUP" --source runtime --granularity milestone --milestone M999 --log "$FIX" >"$out_runtime" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s --source runtime rc=%d expected 0\n' "$NAME" "$rc" >&2
  exit 1
fi
if ! grep -q "no records match filter" "$out_runtime"; then
  printf 'FAIL: %s --source runtime missing annotation\n' "$NAME" >&2
  cat "$out_runtime" >&2 || true
  exit 1
fi

# --- (2) --source estimate: non-empty paired row, exit 0 -----------------
out_estimate="$tmp/estimate.out"
bash "$ROLLUP" --source estimate --granularity milestone --milestone M999 --log "$FIX" >"$out_estimate" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s --source estimate rc=%d\n' "$NAME" "$rc" >&2
  exit 1
fi
estimate_rows="$(grep -c '^milestone[[:space:]]' "$out_estimate" || true)"
if [ "$estimate_rows" -lt 1 ]; then
  printf 'FAIL: %s --source estimate produced 0 data rows\n' "$NAME" >&2
  cat "$out_estimate" >&2 || true
  exit 1
fi

# --- (3) --source all: same data-row count as --source estimate ---------
out_all="$tmp/all.out"
bash "$ROLLUP" --source all --granularity milestone --milestone M999 --log "$FIX" >"$out_all" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s --source all rc=%d\n' "$NAME" "$rc" >&2
  exit 1
fi
all_rows="$(grep -c '^milestone[[:space:]]' "$out_all" || true)"
if [ "$all_rows" -ne "$estimate_rows" ]; then
  printf 'FAIL: %s --source all rows=%s != --source estimate rows=%s\n' "$NAME" "$all_rows" "$estimate_rows" >&2
  exit 1
fi

# --- (4) --source bogus: exit 2 -----------------------------------------
bash "$ROLLUP" --source bogus --granularity milestone --milestone M999 --log "$FIX" >/dev/null 2>"$tmp/bogus.err"
rc=$?
if [ "$rc" -ne 2 ]; then
  printf 'FAIL: %s --source bogus rc=%d expected 2\n' "$NAME" "$rc" >&2
  exit 1
fi

printf 'PASS: %s runtime-empty estimate-rows=%s all-rows=%s bogus-rc=2\n' \
  "$NAME" "$estimate_rows" "$all_rows"
exit 0
