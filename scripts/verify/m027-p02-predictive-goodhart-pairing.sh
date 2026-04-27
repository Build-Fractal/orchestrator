#!/usr/bin/env bash
# scripts/verify/m027-p02-predictive-goodhart-pairing.sh -- M027/P02 Truth #8.
#
# Asserts CON-4 / SC-18 Goodhart pairing at the dispatch-time predictive
# surface attach point: every cost_*_usd line in the rendered block has a
# paired cost_*_quality line. The P01 cost-annotation hook contract
# (carried into the surface) guarantees both classes on every render; this
# verifier asserts the contract holds at THIS attach point.
#
# Bash 3.2 compatible. MEM004 carve-out -- pipes / grep used internally.

set -u

NAME="m027-p02-predictive-goodhart-pairing.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

HELPER="scripts/dispatch/predictive-surface.sh"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if [ ! -x "$HELPER" ]; then
  fail "$HELPER not executable"
fi

out="$(bash "$HELPER" --description "test" --intensity standard 2>/dev/null)"
rc=$?
if [ "$rc" -ne 0 ]; then
  fail "default invocation exited non-zero ($rc)"
fi

# Count cost_*_usd lines and cost_*_quality lines.
cost_lines="$(printf '%s\n' "$out" | grep -cE '^cost_(quick|standard|full)_usd=')"
quality_lines="$(printf '%s\n' "$out" | grep -cE '^cost_(quick|standard|full)_quality=')"

if [ "$cost_lines" -lt 1 ]; then
  fail "no cost_*_usd lines in render (expected at least 1)"
fi
if [ "$quality_lines" -lt 1 ]; then
  fail "no cost_*_quality lines in render (Goodhart pairing violated)"
fi

# Stronger structural check -- each tier present in cost_*_usd must have
# a matching cost_*_quality line.
for tier in quick standard full; do
  has_cost=$(printf '%s\n' "$out" | grep -cE "^cost_${tier}_usd=")
  has_quality=$(printf '%s\n' "$out" | grep -cE "^cost_${tier}_quality=")
  if [ "$has_cost" -gt 0 ] && [ "$has_quality" -lt 1 ]; then
    fail "tier=$tier has cost_${tier}_usd but no cost_${tier}_quality (Goodhart pairing violated)"
  fi
done

echo "PASS: $NAME cost_lines=$cost_lines quality_lines=$quality_lines"
exit 0
