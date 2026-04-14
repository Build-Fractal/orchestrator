#!/usr/bin/env bash
# Verifies context-pressure.sh evaluates token estimates and outputs pressure/action.
set -eu

f="scripts/engine/context-pressure.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Test 1: Low pressure (10k tokens in 200k window = 5%)
output="$(bash "$f" --tokens 10000 --context-window 200000 2>/dev/null)"
pressure="$(echo "$output" | grep "^pressure=" | cut -d= -f2)"
action="$(echo "$output" | grep "^action=" | cut -d= -f2)"
if [[ "$pressure" != "low" ]]; then
  echo "FAIL: 10k/200k should be pressure=low, got $pressure"; exit 1
fi
if [[ "$action" != "proceed" ]]; then
  echo "FAIL: 10k/200k should be action=proceed, got $action"; exit 1
fi

# Test 2: High pressure (160k tokens in 200k window = 80%)
output="$(bash "$f" --tokens 160000 --context-window 200000 2>/dev/null)"
pressure="$(echo "$output" | grep "^pressure=" | cut -d= -f2)"
action="$(echo "$output" | grep "^action=" | cut -d= -f2)"
if [[ "$pressure" != "high" ]]; then
  echo "FAIL: 160k/200k should be pressure=high, got $pressure"; exit 1
fi
if [[ "$action" != "decompose" ]]; then
  echo "FAIL: 160k/200k should be action=decompose, got $action"; exit 1
fi

# Test 3: Critical pressure (180k tokens in 200k window = 90%)
output="$(bash "$f" --tokens 180000 --context-window 200000 2>/dev/null)"
pressure="$(echo "$output" | grep "^pressure=" | cut -d= -f2)"
action="$(echo "$output" | grep "^action=" | cut -d= -f2)"
if [[ "$pressure" != "critical" ]]; then
  echo "FAIL: 180k/200k should be pressure=critical, got $pressure"; exit 1
fi
if [[ "$action" != "refuse" ]]; then
  echo "FAIL: 180k/200k should be action=refuse, got $action"; exit 1
fi

# Test 4: Verify all output fields present
echo "$output" | grep -q "^pressure=" || { echo "FAIL: missing pressure="; exit 1; }
echo "$output" | grep -q "^action=" || { echo "FAIL: missing action="; exit 1; }
echo "$output" | grep -q "^utilization_pct=" || { echo "FAIL: missing utilization_pct="; exit 1; }
echo "$output" | grep -q "^threshold_warn=" || { echo "FAIL: missing threshold_warn="; exit 1; }
echo "$output" | grep -q "^threshold_decompose=" || { echo "FAIL: missing threshold_decompose="; exit 1; }
echo "$output" | grep -q "^threshold_refuse=" || { echo "FAIL: missing threshold_refuse="; exit 1; }

# Test 5: Quick intensity tightens thresholds (10% tighter)
# At Standard, 110k/200k = 55% is below 60% warn = low.
# At Quick, warn is 50%, so 55% > 50% -> medium.
output="$(bash "$f" --tokens 110000 --context-window 200000 --intensity Quick 2>/dev/null)"
pressure="$(echo "$output" | grep "^pressure=" | cut -d= -f2)"
if [[ "$pressure" != "medium" ]]; then
  echo "FAIL: Quick intensity at 55% should be pressure=medium (warn at 50%), got $pressure"; exit 1
fi

echo "PASS: context-pressure.sh correctly evaluates pressure levels, actions, and intensity-aware thresholds"
