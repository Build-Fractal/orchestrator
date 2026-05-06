#!/usr/bin/env bash
# tools/verify/m029-p03-auto-preflight-shape.sh -- M029 P03 / T02 shape verifier
# for the FR-9 + AD-3 + AD-4 Preflight Summary section in commands/auto.md.
#
# Bash 3.2 (MEM001). AD-19 straight-line bash. Negative-assertion discipline
# for forbidden write-tokens (CON-1 read-only).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

FILE="commands/auto.md"
pass=0
fail=0

_assert_present() {
  local needle="$1"
  local label="$2"
  if grep -F -q -e "$needle" "$FILE"; then
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$label"
  else
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n' "$label"
  fi
}

_assert_absent() {
  local needle="$1"
  local label="$2"
  if grep -F -q -e "$needle" "$FILE"; then
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n' "$label"
  else
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$label"
  fi
}

if [ ! -f "$FILE" ]; then
  printf 'FAIL: commands/auto.md missing\n'
  exit 1
fi

_assert_present 'Preflight Summary' 'preflight summary header present'
_assert_present 'FR-9' 'FR-9 reference present'
_assert_present 'AD-3' 'AD-3 reference present'
_assert_present 'AD-4' 'AD-4 reference present'
_assert_present 'M029_PREFLIGHT_NEEDS_CONFIRMATION' 'byte-stable confirmation token present'
_assert_present 'predictive-surface.sh' 'oracle script reference present'
_assert_present 'summarize-milestone.sh' 'oracle wrapper reference present'
_assert_present 'auto_proceed' 'auto_proceed config reference present'
_assert_present '--yes' '--yes flag reference present'
_assert_present 'Quick intensity suppresses' 'quick-intensity suppression invariant present'
_assert_present 'cost_standard_usd' 'cost_standard_usd byte-identity field present'
_assert_present 'detect-invocation-context.sh' 'AD-1 single-resolve reference present'

_assert_absent '>> .orchestrator' 'no append-write to .orchestrator/'
_assert_absent 'mkdir -p .orchestrator' 'no .orchestrator/ creation in preflight surface'

printf 'SUMMARY: m029-p03-auto-preflight-shape.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
