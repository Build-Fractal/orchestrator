#!/usr/bin/env bash
# scripts/verify/m027-p00-pricing-warning.sh — M027/P00 FR-11.
#
# Runs the rollup against tests/fixtures/m027-p00/pricing-warning.jsonl
# (5 records, 2 with estimated_cost_usd:null + pricing_warning:missing).
# Asserts:
#   - exit 0
#   - stdout contains the substring `(2 missing)` somewhere on the cost
#     cell of the relevant scope row.
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-pricing-warning.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
FIX="$PROJECT_ROOT/tests/fixtures/m027-p00/pricing-warning.jsonl"

if [ ! -r "$ROLLUP" ] || [ ! -r "$FIX" ]; then
  printf 'FAIL: %s rollup-or-fixture-missing\n' "$NAME" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

out="$tmp/out"
err="$tmp/err"
bash "$ROLLUP" --granularity milestone --milestone M999 --log "$FIX" >"$out" 2>"$err"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s rollup rc=%d\n' "$NAME" "$rc" >&2
  cat "$err" >&2 || true
  exit 1
fi

if ! grep -qF '(2 missing)' "$out"; then
  printf 'FAIL: %s output missing "(2 missing)" suffix\n' "$NAME" >&2
  cat "$out" >&2 || true
  exit 1
fi

# Sanity: the suffix lives on a milestone data row.
if ! grep -E '^milestone[[:space:]].*\(2 missing\)' "$out" >/dev/null; then
  printf 'FAIL: %s "(2 missing)" not on a milestone data row\n' "$NAME" >&2
  cat "$out" >&2 || true
  exit 1
fi

printf 'PASS: %s pricing-warning-suffix-present\n' "$NAME"
exit 0
