#!/usr/bin/env bash
# scripts/verify/m027-p00-input-schema.sh — M027/P00 FR-17.
#
# Runs the rollup against tests/fixtures/m027-p00/missing-fields.jsonl.
# The fixture contains lines that are missing one of the FR-17 required
# fields: estimated_cost_usd, record_type, or granularity.
# Asserts:
#   - exit 0
#   - stderr contains exactly 2 `WARN: input-schema` lines (one for the
#     missing-estimated_cost_usd row, one for the missing-granularity row)
#   - the rollup aggregated only the 6 valid records (not 8) — verified
#     by summing the DISPATCHES column at --granularity task.
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-input-schema.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
FIX="$PROJECT_ROOT/tests/fixtures/m027-p00/missing-fields.jsonl"

if [ ! -r "$ROLLUP" ] || [ ! -r "$FIX" ]; then
  printf 'FAIL: %s rollup-or-fixture-missing\n' "$NAME" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

out="$tmp/out"
err="$tmp/err"
bash "$ROLLUP" --granularity task --milestone M999 --log "$FIX" >"$out" 2>"$err"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s rollup rc=%d\n' "$NAME" "$rc" >&2
  cat "$err" >&2 || true
  exit 1
fi

schema_warns="$(grep -c '^WARN: input-schema' "$err" || true)"
if [ "$schema_warns" -ne 2 ]; then
  printf 'FAIL: %s expected 2 input-schema WARNs got %s\n' "$NAME" "$schema_warns" >&2
  cat "$err" >&2 || true
  exit 1
fi

disp_sum="$(grep '^task[[:space:]]' "$out" | awk '
  {
    for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+$/) { sum += $i; break }
  }
  END { print sum+0 }
')"
if [ "$disp_sum" != "6" ]; then
  printf 'FAIL: %s DISPATCHES sum=%s expected 6\n' "$NAME" "$disp_sum" >&2
  cat "$out" >&2 || true
  exit 1
fi

printf 'PASS: %s schema-warns=%s dispatches=%s\n' "$NAME" "$schema_warns" "$disp_sum"
exit 0
