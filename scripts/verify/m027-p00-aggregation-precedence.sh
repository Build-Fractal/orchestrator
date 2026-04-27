#!/usr/bin/env bash
# scripts/verify/m027-p00-aggregation-precedence.sh — M027/P00 FR-18 / AD-1 / SC-14.
#
# Verifies aggregation precedence aggregate > runtime > estimate against
# tests/fixtures/m027-p00/mixed-source-aggregate.jsonl, which contains:
#   - 3 task-granularity estimate rows (T01, T02, T03 at 0.10 each)
#   - 1 phase-granularity aggregate row (P00 at 0.50)
#
# Contract:
#   --granularity phase: cost cell == 0.50 (aggregate row wins, NOT 0.30+0.50)
#   --granularity task : cost cells sum to 0.30 (children visible, aggregate
#                         row not double-applied)
#
# Bash 3.2 compatible. MEM004 carve-out — pipes/$()/awk permitted.

set -u

NAME="m027-p00-aggregation-precedence.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
FIX="$PROJECT_ROOT/tests/fixtures/m027-p00/mixed-source-aggregate.jsonl"

if [ ! -r "$ROLLUP" ] || [ ! -r "$FIX" ]; then
  printf 'FAIL: %s rollup-or-fixture-missing\n' "$NAME" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

# Helper: extract first numeric of pattern X.XXXXXXXX from a stream.
first_cost() {
  awk '
    {
      for (i=1; i<=NF; i++) {
        if ($i ~ /^[0-9]+\.[0-9]+$/) { print $i; exit }
      }
    }
  ' "$1"
}

sum_cost_column() {
  # Sum the first numeric token (cost) per data row.
  awk '
    /^GRANULARITY/ { next }
    /^[[:space:]]*$/ { next }
    {
      for (i=1; i<=NF; i++) {
        if ($i ~ /^[0-9]+\.[0-9]+$/) { sum += $i; break }
      }
    }
    END { printf "%.8f", sum + 0 }
  ' "$1"
}

# --- (1) phase: cost cell == 0.50 ---------------------------------------
out_phase="$tmp/phase.out"
bash "$ROLLUP" --granularity phase --milestone M999 --log "$FIX" >"$out_phase" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s phase rc=%d\n' "$NAME" "$rc" >&2
  exit 1
fi
phase_rows="$(grep -c '^phase[[:space:]]' "$out_phase" || true)"
if [ "$phase_rows" -ne 1 ]; then
  printf 'FAIL: %s phase expected 1 row got %s\n' "$NAME" "$phase_rows" >&2
  cat "$out_phase" >&2 || true
  exit 1
fi
phase_row_only="$tmp/phase.row"
grep '^phase[[:space:]]' "$out_phase" > "$phase_row_only"
phase_cost="$(first_cost "$phase_row_only")"
# Compare via awk numeric tolerance (within 0.0001).
phase_ok="$(awk -v v="$phase_cost" 'BEGIN { d=v-0.50; if (d<0) d=-d; print (d<0.0001)?"yes":"no" }')"
if [ "$phase_ok" != "yes" ]; then
  printf 'FAIL: %s phase cost=%s expected 0.50000000\n' "$NAME" "$phase_cost" >&2
  cat "$out_phase" >&2 || true
  exit 1
fi

# --- (2) task: cost cells sum to 0.30 -----------------------------------
out_task="$tmp/task.out"
bash "$ROLLUP" --granularity task --milestone M999 --log "$FIX" >"$out_task" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s task rc=%d\n' "$NAME" "$rc" >&2
  exit 1
fi
task_only="$tmp/task.rows"
grep '^task[[:space:]]' "$out_task" > "$task_only" || true
if [ ! -s "$task_only" ]; then
  printf 'FAIL: %s task produced 0 data rows\n' "$NAME" >&2
  cat "$out_task" >&2 || true
  exit 1
fi
task_sum="$(sum_cost_column "$task_only")"
task_ok="$(awk -v v="$task_sum" 'BEGIN { d=v-0.30; if (d<0) d=-d; print (d<0.0001)?"yes":"no" }')"
if [ "$task_ok" != "yes" ]; then
  printf 'FAIL: %s task cost-sum=%s expected 0.30000000\n' "$NAME" "$task_sum" >&2
  cat "$out_task" >&2 || true
  exit 1
fi

printf 'PASS: %s phase-cost=%s task-sum=%s\n' "$NAME" "$phase_cost" "$task_sum"
exit 0
