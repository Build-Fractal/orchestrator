#!/usr/bin/env bash
# tools/verify/m032-p04-acceptance-shape-sc8.sh — SC-8 artifact-shape guard.
#
# Asserts the SC-8 acceptance script
# tests/m032-acceptance/p0X-scanner-extensions.sh exists, is executable, and
# contains the load-bearing tokens that pin its FR-17 + FR-18 + FR-19 contract
# (per M032 patterns-established acceptance-shape verifier convention).
#
# Bash 3.2 compatible. Single-script-file shape per AD-19.
# Exit 0 on PASS; 1 on FAIL.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ACC="$ROOT/tests/m032-acceptance/p0X-scanner-extensions.sh"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -f "$ACC" ]; then
  say_fail "SC-8 acceptance script missing at $ACC"
  printf 'SUMMARY: m032-p04-acceptance-shape-sc8 pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

if [ ! -x "$ACC" ]; then
  say_fail "SC-8 acceptance script not executable: $ACC"
else
  say_pass "SC-8 acceptance script executable"
fi

# Load-bearing token surface
for tok in 'SC-8' 'FR-17' 'FR-18' 'FR-19' 'proposals:' 'extra:' 'knowledge-flat' \
           'no-include-proposals' 'wiki.extra_dirs' '\[brief\]'; do
  if grep -qE "$tok" "$ACC"; then
    say_pass "SC-8 contains: $tok"
  else
    say_fail "SC-8 missing: $tok"
  fi
done

# trap-EXIT cleanup pattern (M032 patterns-established)
if grep -qE 'trap[[:space:]]+.*EXIT' "$ACC"; then
  say_pass "SC-8 declares trap-EXIT cleanup"
else
  say_fail "SC-8 missing trap-EXIT cleanup"
fi

# Three-category fixture surface (FR-18-present + FR-18-absent + fixture)
if grep -qE 'FIXTURE_NOEXTRA|noextra' "$ACC"; then
  say_pass "SC-8 exercises FR-18-absent fixture (no false-positive section)"
else
  say_fail "SC-8 missing FR-18-absent (no-config) fixture"
fi

# RESULT envelope per the plan-time sketch
if grep -qE '^printf .RESULT: SC-8 pass=' "$ACC"; then
  say_pass "SC-8 emits RESULT pass/fail envelope"
else
  say_fail "SC-8 missing RESULT envelope"
fi

printf 'SUMMARY: m032-p04-acceptance-shape-sc8 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
