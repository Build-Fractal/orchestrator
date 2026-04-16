#!/usr/bin/env bash
# scripts/verify/m016-p04-zero-prompts.sh — SC-1 gate: validate zero-prompts dogfood evidence
# Checks:
#   1. Attestation file exists with prompt_count: 0
#   2. P01-P03 phase summaries all show verification_result: "pass"
#   3. Anti-pattern lint passes
#   4. settings.json contains sed wildcard (spot check for promotion)
set -eu

root="$(cd "$(dirname "$0")/../.." && pwd)"
fails=0

# --- Check 1: Attestation file exists with prompt_count: 0 ---
attestation="$root/.orchestrator/milestones/M016/phases/P04/evidence/zero-prompts-attestation.md"
if [ ! -f "$attestation" ]; then
  echo "FAIL: attestation file missing: $attestation"
  fails=$((fails + 1))
else
  if grep -q 'prompt_count: 0' "$attestation"; then
    echo "PASS: attestation file exists with prompt_count: 0"
  else
    echo "FAIL: attestation file does not contain prompt_count: 0"
    fails=$((fails + 1))
  fi
fi

# --- Check 2: P01-P03 phase summaries show verification_result: "pass" ---
for phase in P01 P02 P03; do
  summary="$root/.orchestrator/milestones/M016/phases/$phase/${phase}-SUMMARY.md"
  if [ ! -f "$summary" ]; then
    echo "FAIL: $phase summary missing: $summary"
    fails=$((fails + 1))
  else
    if grep -q 'verification_result: "pass"' "$summary"; then
      echo "PASS: $phase summary has verification_result: pass"
    else
      echo "FAIL: $phase summary missing verification_result: pass"
      fails=$((fails + 1))
    fi
  fi
done

# --- Check 3: Anti-pattern lint passes ---
lint_script="$root/scripts/verify/anti-pattern-lint.sh"
if [ ! -f "$lint_script" ]; then
  echo "FAIL: anti-pattern-lint.sh missing"
  fails=$((fails + 1))
else
  lint_output="$(bash "$lint_script" 2>&1)" || true
  if echo "$lint_output" | grep -q 'LINT PASS'; then
    echo "PASS: anti-pattern lint passes"
  else
    echo "FAIL: anti-pattern lint did not pass"
    echo "  lint output: $lint_output"
    fails=$((fails + 1))
  fi
fi

# --- Check 4: settings.json contains sed wildcard (spot check for promotion) ---
settings="$root/.claude/settings.json"
if [ ! -f "$settings" ]; then
  echo "FAIL: settings.json missing"
  fails=$((fails + 1))
else
  if grep -q '"Bash(sed \*)"' "$settings"; then
    echo "PASS: settings.json contains sed wildcard"
  else
    echo "FAIL: settings.json missing sed wildcard entry"
    fails=$((fails + 1))
  fi
fi

# --- Summary ---
if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails check(s) failed"
  exit 1
fi
echo "PASS: all SC-1 zero-prompts gate checks passed"
exit 0
