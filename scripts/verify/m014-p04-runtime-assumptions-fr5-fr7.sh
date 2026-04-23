#!/usr/bin/env bash
# Gate: T06 — RUNTIME-ASSUMPTIONS.md FR-5 body replaced + FR-7 entry appended.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REG="${PROJECT_ROOT}/RUNTIME-ASSUMPTIONS.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$REG" ] || fail "RUNTIME-ASSUMPTIONS.md missing"

# FR-5 full body markers present.
grep -qF 'spec-complexity-contradiction-prompt.md' "$REG" \
  || fail "FR-5 body missing spec-complexity-contradiction-prompt.md reference"
grep -qF 'dispatch-interface.sh' "$REG" \
  || fail "FR-5 body missing dispatch-interface.sh reference"

# P01 stub language gone from FR-5.
grep -qF 'P01 stub' "$REG" \
  && fail "FR-5 body still contains 'P01 stub' language"
grep -qF 'P04 replaces the body' "$REG" \
  && fail "FR-5 body still contains deferral language"

# FR-7 entry present.
grep -qE '^### FR-7: LLM-assisted spec decomposition' "$REG" || fail "FR-7 heading missing"

# Ordering: FR-3 < FR-5 < FR-7 < sentinel.
L3="$(grep -nE '^### FR-3:' "$REG" | head -n 1 | awk -F: '{print $1}')"
L5="$(grep -nE '^### FR-5:' "$REG" | head -n 1 | awk -F: '{print $1}')"
L7="$(grep -nE '^### FR-7:' "$REG" | head -n 1 | awk -F: '{print $1}')"
LE="$(grep -n 'Future entries land below this line' "$REG" | head -n 1 | awk -F: '{print $1}')"
[ -n "$L3" ] && [ -n "$L5" ] && [ -n "$L7" ] && [ -n "$LE" ] || fail "could not locate entry line numbers"
if [ "$L5" -le "$L3" ]; then fail "FR-5 before FR-3"; fi
if [ "$L7" -le "$L5" ]; then fail "FR-7 before FR-5"; fi
if [ "$L7" -ge "$LE" ]; then fail "FR-7 after sentinel"; fi

echo "PASS: RUNTIME-ASSUMPTIONS.md FR-5-full body + FR-7 entry verified"
exit 0
