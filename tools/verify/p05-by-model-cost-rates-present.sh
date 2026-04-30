#!/usr/bin/env bash
# tools/verify/p05-by-model-cost-rates-present.sh -- M030/P05/T02 SC-8 gate (sentence 2).
#
# Asserts that with the shipped templates/model-routing.yml (cost_rates:
# present), `bash scripts/diagnostics/metrics-rollup.sh --by-model --log
# tests/fixtures/m030-p05/live-routed-corpus.jsonl` additionally emits an
# aggregated_cost_usd: line and a counterfactual_all_smart_cost_usd: line.
#
# Hand-computed expected values (token shape: 1024 input + 512 output per
# record; tier rates: fast 1.00/5.00, balanced 3.00/15.00, smart 15.00/75.00):
#
#   fast tier per-record:     1024/1e6 * 1.00 + 512/1e6 * 5.00 = 0.003584
#   balanced tier per-record: 1024/1e6 * 3.00 + 512/1e6 * 15.00 = 0.010752
#   smart tier per-record:    1024/1e6 * 15.00 + 512/1e6 * 75.00 = 0.053760
#
#   aggregated     = 14 * 0.003584 + 7 * 0.010752 + 2 * 0.053760
#                  = 0.050176 + 0.075264 + 0.107520
#                  = 0.232960
#   counterfactual = 23 * 0.053760 = 1.236480
#
# Verifier asserts the rollup emits these values to 8-decimal precision
# (0.23296000 and 1.23648000 respectively) -- the existing printf precision
# of the M027 cost cells.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p05/live-routed-corpus.jsonl"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
ROUTING="$PROJECT_ROOT/templates/model-routing.yml"

pass=0
fail=0

if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: live-routed-corpus.jsonl missing at $FIXTURE"
  echo "SUMMARY: p05-by-model-cost-rates-present.sh pass=0 fail=1"
  exit 1
fi

if [ ! -f "$ROUTING" ]; then
  echo "FAIL: templates/model-routing.yml missing at $ROUTING"
  echo "SUMMARY: p05-by-model-cost-rates-present.sh pass=0 fail=1"
  exit 1
fi

# cost_rates: must be present in the shipped routing-table for this gate
# to be meaningful.
if ! grep -qE '^cost_rates:' "$ROUTING"; then
  echo "FAIL: cost_rates: section not present in $ROUTING (this gate requires the shipped table)"
  echo "SUMMARY: p05-by-model-cost-rates-present.sh pass=0 fail=1"
  exit 1
fi

ACTUAL="$(mktemp -t p05-by-model-cost-rates-present.XXXXXX)"
trap 'rm -f "$ACTUAL"' EXIT

bash "$ROLLUP" --by-model --log "$FIXTURE" --routing-table "$ROUTING" > "$ACTUAL" 2>/dev/null
rc=$?

if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
  echo "OK: --by-model exit 0"
else
  fail=$((fail + 1))
  echo "FAIL: --by-model exited $rc"
fi

# Aggregated cost line present + numeric value.
if grep -qE '^aggregated_cost_usd: 0\.23296000' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: aggregated_cost_usd matches expected 0.23296000"
else
  fail=$((fail + 1))
  echo "FAIL: aggregated_cost_usd missing or != 0.23296000"
  echo "Actual stdout:"
  cat "$ACTUAL"
fi

# Counterfactual cost line present + numeric value.
if grep -qE '^counterfactual_all_smart_cost_usd: 1\.23648000' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: counterfactual_all_smart_cost_usd matches expected 1.23648000"
else
  fail=$((fail + 1))
  echo "FAIL: counterfactual_all_smart_cost_usd missing or != 1.23648000"
  echo "Actual stdout:"
  cat "$ACTUAL"
fi

# Per-tier dispatch-count line still emitted alongside cost lines.
if grep -qE '^23 dispatches: 14 fast / 7 balanced / 2 smart' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: dispatch-count line still emitted alongside cost lines"
else
  fail=$((fail + 1))
  echo "FAIL: dispatch-count line missing under cost_rates-present branch"
fi

# "cost rates not configured" line MUST NOT be present (negative gate).
if grep -qE '^cost rates not configured' "$ACTUAL"; then
  fail=$((fail + 1))
  echo "FAIL: 'cost rates not configured' present under cost_rates-present branch"
else
  pass=$((pass + 1))
  echo "OK: 'cost rates not configured' absent (correctly suppressed)"
fi

echo "SUMMARY: p05-by-model-cost-rates-present.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
