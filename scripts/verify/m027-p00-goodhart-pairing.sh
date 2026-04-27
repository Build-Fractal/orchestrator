#!/usr/bin/env bash
# scripts/verify/m027-p00-goodhart-pairing.sh — M027/P00 FR-4 / SC-12.
#
# For each granularity in {task, phase, milestone}, run the rollup against
# tests/fixtures/m027-p00/mixed-source-aggregate.jsonl. For every data row
# emitted, assert that the row carries both a cost cell AND a quality cell.
# A row that has a cost-numeric column without a paired pass_rate column
# (numeric or "unknown") fails — Goodhart pairing.
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-goodhart-pairing.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
FIX="$PROJECT_ROOT/tests/fixtures/m027-p00/mixed-source-aggregate.jsonl"

if [ ! -r "$ROLLUP" ] || [ ! -r "$FIX" ]; then
  printf 'FAIL: %s rollup-or-fixture-missing rollup=%s fix=%s\n' "$NAME" "$ROLLUP" "$FIX" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

violations=0
total_rows=0
for gran in task phase milestone; do
  out="$tmp/$gran.out"
  bash "$ROLLUP" --granularity "$gran" --milestone M999 --log "$FIX" >"$out" 2>/dev/null
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'FAIL: %s rollup gran=%s rc=%d\n' "$NAME" "$gran" "$rc" >&2
    exit 1
  fi
  # Skip the header line (starts with GRANULARITY); analyse data rows.
  data_rows="$(grep -v '^GRANULARITY' "$out" | grep -v '^[[:space:]]*$' || true)"
  if [ -z "$data_rows" ]; then
    printf 'FAIL: %s gran=%s produced no data rows\n' "$NAME" "$gran" >&2
    cat "$out" >&2 || true
    exit 1
  fi
  # Emit data rows and count cost-only violations via awk.
  v="$(printf '%s\n' "$data_rows" | awk '
    {
      n_cost = 0; n_qual = 0;
      for (i=1; i<=NF; i++) {
        if ($i ~ /^-?[0-9]+\.[0-9]+$/) n_cost++;
        if ($i ~ /^[0-9]+\.[0-9]{4}$/ || $i == "unknown") n_qual++;
      }
      total++;
      if (n_cost > 0 && n_qual == 0) bad++;
    }
    END { printf "%d %d", total+0, bad+0 }
  ')"
  rows="${v% *}"
  bad="${v#* }"
  total_rows=$((total_rows + rows))
  violations=$((violations + bad))
done

if [ "$violations" -ne 0 ]; then
  printf 'FAIL: %s %d cost-only rows (no quality cell)\n' "$NAME" "$violations" >&2
  exit 1
fi

printf 'PASS: %s %d rows all carry paired cost+quality\n' "$NAME" "$total_rows"
exit 0
