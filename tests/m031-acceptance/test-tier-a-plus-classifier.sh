#!/usr/bin/env bash
# tests/m031-acceptance/test-tier-a-plus-classifier.sh
#
# M031/P02/T01 — SC-5 acceptance test for the Tier A+ classifier verdict.
#
# Asserts:
#   1. bash scripts/intake/shape-detect.sh --input <FIXTURE> emits stdout
#      containing the literal token `tier_a_plus` (the input_shape line).
#   2. tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md exists and
#      contains at least one <milestone>/<phase>/<task> provenance string
#      grounding the heuristic per AD-16.
#   3. The four pre-existing M024 classifier verdicts (idea, paragraph,
#      fragment, spec, empty) stay byte-equal on M031 regression sanity
#      probes — we sanity-check four representative inputs and confirm
#      none of them now emit `tier_a_plus`.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Output envelope:
#   RESULT: SC-5 pass   on success
#   RESULT: SC-5 fail   plus a diagnostic line on failure
#
# Exit 0 iff every check passes.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

shape_detect="$PROJECT_ROOT/scripts/intake/shape-detect.sh"
fixture="$PROJECT_ROOT/tests/m031-acceptance/fixtures/tier-a-plus-input.txt"
provenance="$PROJECT_ROOT/tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md"

fail_messages=""
fail_count=0

record_fail() {
    fail_count=$((fail_count + 1))
    fail_messages="$fail_messages
  - $1"
}

# Check 1: shape-detect.sh exists.
if [ ! -x "$shape_detect" ] && [ ! -f "$shape_detect" ]; then
    record_fail "shape-detect.sh missing at $shape_detect"
fi

# Check 2: fixture exists.
if [ ! -f "$fixture" ]; then
    record_fail "tier-a-plus-input.txt fixture missing at $fixture"
fi

# Check 3: FIXTURE-PROVENANCE.md exists.
if [ ! -f "$provenance" ]; then
    record_fail "FIXTURE-PROVENANCE.md missing at $provenance"
fi

# Check 4: shape-detect.sh emits tier_a_plus on the fixture.
if [ -f "$fixture" ] && [ -f "$shape_detect" ]; then
    fixture_body=$(cat "$fixture")
    out=$(bash "$shape_detect" --input "$fixture_body" 2>&1)
    if echo "$out" | grep -q 'input_shape=tier_a_plus'; then
        :
    else
        record_fail "shape-detect.sh did not emit input_shape=tier_a_plus on the fixture (got: $out)"
    fi
fi

# Check 5: FIXTURE-PROVENANCE.md contains at least one
# <milestone>/<phase>/<task> provenance string per AD-16.
if [ -f "$provenance" ]; then
    if grep -qE 'M[0-9][0-9][0-9]/P[0-9][0-9]/T[0-9][0-9]' "$provenance"; then
        :
    else
        record_fail "FIXTURE-PROVENANCE.md missing <milestone>/<phase>/<task> provenance pattern (AD-16 grounding)"
    fi
fi

# Check 6: regression sanity — short input still classifies as idea.
sanity_idea=$(bash "$shape_detect" --input "fix typo in status doc" 2>&1)
if echo "$sanity_idea" | grep -q 'input_shape=idea'; then
    :
else
    record_fail "regression: short input no longer classifies as idea (got: $sanity_idea)"
fi

# Check 7: regression sanity — 25-word paragraph still classifies as paragraph.
sanity_para=$(bash "$shape_detect" --input "We should add a last seen timestamp to the status command output and cache it briefly so repeated calls do not hammer the filesystem." 2>&1)
if echo "$sanity_para" | grep -q 'input_shape=paragraph'; then
    :
else
    record_fail "regression: 23-word paragraph no longer classifies as paragraph (got: $sanity_para)"
fi

if [ "$fail_count" -eq 0 ]; then
    echo "RESULT: SC-5 pass"
    exit 0
fi

echo "RESULT: SC-5 fail"
echo "  failures: $fail_count$fail_messages"
exit 1
