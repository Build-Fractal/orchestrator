#!/usr/bin/env bash
# tools/verify/p02-shadow-compare-verdicts.sh — M030/P02/T03
#
# Exercises the four-verdict closed enum (D-A1) by running
# scripts/diagnostics/shadow-compare.sh against four fixture corpora,
# one per verdict. For each scenario:
#   - assert exit 0
#   - assert stdout contains exactly one ^flip_recommendation= line
#   - assert that line's value matches the expected verdict
#
# Bash 3.2 compatible. AD-19 single-script-file shape: tmp-file
# intermediates instead of inline pipes-in-command-substitution.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/diagnostics/shadow-compare.sh"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p02"

pass=0
fail=0

run_scenario() {
  scenario_name="$1"
  fixture_basename="$2"
  expected_verdict="$3"

  fixture="$FIXTURES/$fixture_basename"
  out_tmp="/tmp/p02-shadow-compare-verdicts-${scenario_name}.txt"
  rc_tmp="/tmp/p02-shadow-compare-verdicts-${scenario_name}.rc"
  rm -f "$out_tmp" "$rc_tmp" 2>/dev/null

  if [ ! -f "$fixture" ]; then
    fail=$((fail + 1))
    printf 'FAIL: scenario %s — fixture missing: %s\n' "$scenario_name" "$fixture"
    return 0
  fi

  bash "$SCRIPT" --corpus "$fixture" > "$out_tmp" 2>/dev/null
  rc=$?

  if [ "$rc" -ne 0 ]; then
    fail=$((fail + 1))
    printf 'FAIL: scenario %s — shadow-compare.sh exited %d (expected 0)\n' "$scenario_name" "$rc"
    rm -f "$out_tmp" 2>/dev/null
    return 0
  fi

  count_tmp="/tmp/p02-shadow-compare-verdicts-${scenario_name}-count.txt"
  grep -c '^flip_recommendation=' "$out_tmp" > "$count_tmp" 2>/dev/null
  count="$(cat "$count_tmp")"
  rm -f "$count_tmp" 2>/dev/null

  if [ "$count" != "1" ]; then
    fail=$((fail + 1))
    printf 'FAIL: scenario %s — expected exactly 1 flip_recommendation= line, got %s\n' "$scenario_name" "$count"
    rm -f "$out_tmp" 2>/dev/null
    return 0
  fi

  grep -q "^flip_recommendation=${expected_verdict}\$" "$out_tmp"
  if [ $? -ne 0 ]; then
    fail=$((fail + 1))
    printf 'FAIL: scenario %s — expected flip_recommendation=%s; got:\n' "$scenario_name" "$expected_verdict"
    grep '^flip_recommendation=' "$out_tmp" || printf '(no flip_recommendation= line)\n'
    rm -f "$out_tmp" 2>/dev/null
    return 0
  fi

  pass=$((pass + 1))
  rm -f "$out_tmp" 2>/dev/null
  return 0
}

run_scenario "A-ready" "shadow-corpus-ready.jsonl" "ready"
run_scenario "B-partially-ready" "shadow-corpus-partially-ready.jsonl" "partially_ready"
run_scenario "C-block" "shadow-corpus-block.jsonl" "block"
run_scenario "D-evidence-insufficient" "shadow-corpus-evidence-insufficient.jsonl" "evidence_insufficient"

printf 'SUMMARY: p02-shadow-compare-verdicts.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
