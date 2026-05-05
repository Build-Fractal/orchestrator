#!/usr/bin/env bash
# m033-p02-acceptance-shape-sc13.sh
#
# T05 verifier: shape of the SC-13 acceptance script
# tests/m033-acceptance/p07-observability-records.sh.
#
# Asserts:
#   - The acceptance script exists and is executable.
#   - The literal SC-13 + FR-22 tokens appear (spec-ref discipline).
#   - All 11 event-type tokens appear.
#   - The 'schema_version' and '1.0' tokens appear.
#   - The execution-log.jsonl cross-reference appears.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/tests/m033-acceptance/p07-observability-records.sh"

pass=0
fail=0

check_pass() {
    pass=$((pass + 1))
    echo "PASS: $1"
}

check_fail() {
    fail=$((fail + 1))
    echo "FAIL: $1"
}

if [ ! -f "$target" ]; then
    echo "FAIL: SC-13 acceptance script missing at $target"
    echo "SUMMARY: m033-p02-acceptance-shape-sc13.sh pass=0 fail=1"
    exit 1
fi
check_pass "p07-observability-records.sh exists at $target"

if [ ! -x "$target" ]; then
    check_fail "p07-observability-records.sh not executable: $target"
else
    check_pass "p07-observability-records.sh is executable"
fi

# Spec-reference tokens.
if grep -F -q 'SC-13' "$target"; then
    check_pass "'SC-13' spec-reference token present"
else
    check_fail "'SC-13' spec-reference token missing"
fi
if grep -F -q 'FR-22' "$target"; then
    check_pass "'FR-22' spec-reference token present"
else
    check_fail "'FR-22' spec-reference token missing"
fi

# All 11 event-type tokens.
for et in start_branch_detected start_init_invoked constitution_authored \
          ingest_codebase_completed materials_intake_completed ideation_completed \
          migrate_routed customblock_drafted wiki_init_invoked github_init_invoked \
          friendly_tester_report_validated; do
    if grep -F -q "$et" "$target"; then
        check_pass "event-type token '$et' present"
    else
        check_fail "event-type token '$et' missing"
    fi
done

# schema_version token.
if grep -F -q 'schema_version' "$target"; then
    check_pass "'schema_version' token present"
else
    check_fail "'schema_version' token missing"
fi
# schema-version literal value.
if grep -F -q '"1.0"' "$target"; then
    check_pass "schema-version literal '\"1.0\"' present"
else
    check_fail "schema-version literal '\"1.0\"' missing"
fi

# execution-log.jsonl cross-reference.
if grep -F -q 'execution-log.jsonl' "$target"; then
    check_pass "'execution-log.jsonl' cross-reference present"
else
    check_fail "'execution-log.jsonl' cross-reference missing"
fi

echo "SUMMARY: m033-p02-acceptance-shape-sc13.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
