#!/usr/bin/env bash
# tools/verify/p05-by-model-cost-rates-absent.sh -- M030/P05/T02 SC-8 gate (sentence 3).
#
# Asserts the FR-15 fallback path: when the routing-table at the path
# passed to metrics-rollup.sh has no `cost_rates:` section, --by-model
# emits the per-tier dispatch-count line + a "cost rates not configured"
# warning + a zero-savings line, and exits 0 (warning, not hard failure).
#
# Routing-table fixture: tests/fixtures/m030-p05/no-cost-rates-routing.yml
# (verbatim derivative of templates/model-routing.yml with cost_rates:
# section removed -- T01 fixture).
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p05/live-routed-corpus.jsonl"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"
NO_COST_RATES="$PROJECT_ROOT/tests/fixtures/m030-p05/no-cost-rates-routing.yml"

pass=0
fail=0

if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: live-routed-corpus.jsonl missing at $FIXTURE"
  echo "SUMMARY: p05-by-model-cost-rates-absent.sh pass=0 fail=1"
  exit 1
fi

if [ ! -f "$NO_COST_RATES" ]; then
  echo "FAIL: no-cost-rates-routing.yml fixture missing at $NO_COST_RATES"
  echo "SUMMARY: p05-by-model-cost-rates-absent.sh pass=0 fail=1"
  exit 1
fi

# Sanity check the fixture itself: cost_rates: must be ABSENT.
if grep -qE '^cost_rates:' "$NO_COST_RATES"; then
  echo "FAIL: cost_rates: present in $NO_COST_RATES (fixture invalid for this gate)"
  echo "SUMMARY: p05-by-model-cost-rates-absent.sh pass=0 fail=1"
  exit 1
fi

ACTUAL="$(mktemp -t p05-by-model-cost-rates-absent.XXXXXX)"
trap 'rm -f "$ACTUAL"' EXIT

bash "$ROLLUP" --by-model --log "$FIXTURE" --routing-table "$NO_COST_RATES" > "$ACTUAL" 2>/dev/null
rc=$?

# Exit 0 (warning, not hard failure) -- FR-15 third sentence.
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
  echo "OK: --by-model exit 0 under cost_rates-absent (warning, not hard failure)"
else
  fail=$((fail + 1))
  echo "FAIL: --by-model exited $rc (expected 0)"
fi

# Per-tier dispatch-count line still emitted (fall-through from the rollup
# amendment -- the dispatch-count line is unconditional whether cost_rates:
# is present or absent).
if grep -qE '^23 dispatches: 14 fast / 7 balanced / 2 smart' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: dispatch-count line still emitted under cost_rates-absent branch"
else
  fail=$((fail + 1))
  echo "FAIL: dispatch-count line missing under cost_rates-absent branch"
  echo "Actual stdout:"
  cat "$ACTUAL"
fi

# "cost rates not configured" warning line present.
if grep -qE '^cost rates not configured' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: 'cost rates not configured' warning emitted"
else
  fail=$((fail + 1))
  echo "FAIL: 'cost rates not configured' warning missing"
  echo "Actual stdout:"
  cat "$ACTUAL"
fi

# Zero-savings aggregated line.
if grep -qE '^aggregated_cost_usd: 0$' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: aggregated_cost_usd: 0 (zero-savings fallback)"
else
  fail=$((fail + 1))
  echo "FAIL: aggregated_cost_usd: 0 line missing under cost_rates-absent branch"
fi

# Zero-savings counterfactual line.
if grep -qE '^counterfactual_all_smart_cost_usd: 0$' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: counterfactual_all_smart_cost_usd: 0 (zero-savings fallback)"
else
  fail=$((fail + 1))
  echo "FAIL: counterfactual_all_smart_cost_usd: 0 line missing under cost_rates-absent branch"
fi

echo "SUMMARY: p05-by-model-cost-rates-absent.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
