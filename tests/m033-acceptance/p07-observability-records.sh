#!/usr/bin/env bash
# tests/m033-acceptance/p07-observability-records.sh
#
# SC-13 / FR-22 acceptance script for M033 (Project Onboarding
# Experience). Spec: 036-project-onboarding-experience.
#
# Exercises all 11 documented event types end-to-end via the
# T01-shipped emitter scripts/util/jsonl-event-emitter.sh.
#
# Validates:
#   - schema_version "1.0" appears in every record
#   - ISO 8601 UTC timestamp appears in every record
#   - payload pass-through is verbatim
#   - the closed-enum negative path rejects unknown event types
#   - the schema-version literal "1.0" is hard-coded in the emitter
#     source (drift catch)
#
# The 11 event types under test (FR-22 closed enum):
#   start_branch_detected
#   start_init_invoked
#   constitution_authored
#   ingest_codebase_completed
#   materials_intake_completed
#   ideation_completed
#   migrate_routed
#   customblock_drafted
#   wiki_init_invoked
#   github_init_invoked
#   friendly_tester_report_validated
#
# Each event-type emit is hard-coded as a separate line (no loop
# indirection) so a regression in any single event-type is named in
# the failure output.
#
# Bash 3.2 compatible (MEM001) — no `declare -A`, no process
# substitution, no `$(...)` containing pipes.
#
# Cross-reference: scripts/util/jsonl-event-emitter.sh (T01),
# .orchestrator/execution-log.jsonl (the JSONL surface under test).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EMITTER="$PROJECT_ROOT/scripts/util/jsonl-event-emitter.sh"

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

# Setup: staging dir + cleanup trap.
STAGING="$(mktemp -d -t m033-p02-sc13-XXXXXX)"
cleanup() {
    rm -rf "$STAGING"
}
trap cleanup EXIT

LOG="$STAGING/.orchestrator/execution-log.jsonl"

# --- Test 1 — emit each of the 11 event types (hard-coded calls). ---
PROJECT_DIR="$STAGING" bash "$EMITTER" emit start_branch_detected '{"test":"sc13","seq":0}' \
    && check_pass "emit start_branch_detected" \
    || check_fail "emit start_branch_detected"

PROJECT_DIR="$STAGING" bash "$EMITTER" emit start_init_invoked '{"test":"sc13","seq":1}' \
    && check_pass "emit start_init_invoked" \
    || check_fail "emit start_init_invoked"

PROJECT_DIR="$STAGING" bash "$EMITTER" emit constitution_authored '{"test":"sc13","seq":2}' \
    && check_pass "emit constitution_authored" \
    || check_fail "emit constitution_authored"

PROJECT_DIR="$STAGING" bash "$EMITTER" emit ingest_codebase_completed '{"test":"sc13","seq":3}' \
    && check_pass "emit ingest_codebase_completed" \
    || check_fail "emit ingest_codebase_completed"

PROJECT_DIR="$STAGING" bash "$EMITTER" emit materials_intake_completed '{"test":"sc13","seq":4}' \
    && check_pass "emit materials_intake_completed" \
    || check_fail "emit materials_intake_completed"

PROJECT_DIR="$STAGING" bash "$EMITTER" emit ideation_completed '{"test":"sc13","seq":5}' \
    && check_pass "emit ideation_completed" \
    || check_fail "emit ideation_completed"

PROJECT_DIR="$STAGING" bash "$EMITTER" emit migrate_routed '{"test":"sc13","seq":6}' \
    && check_pass "emit migrate_routed" \
    || check_fail "emit migrate_routed"

PROJECT_DIR="$STAGING" bash "$EMITTER" emit customblock_drafted '{"test":"sc13","seq":7}' \
    && check_pass "emit customblock_drafted" \
    || check_fail "emit customblock_drafted"

PROJECT_DIR="$STAGING" bash "$EMITTER" emit wiki_init_invoked '{"test":"sc13","seq":8}' \
    && check_pass "emit wiki_init_invoked" \
    || check_fail "emit wiki_init_invoked"

PROJECT_DIR="$STAGING" bash "$EMITTER" emit github_init_invoked '{"test":"sc13","seq":9}' \
    && check_pass "emit github_init_invoked" \
    || check_fail "emit github_init_invoked"

PROJECT_DIR="$STAGING" bash "$EMITTER" emit friendly_tester_report_validated '{"test":"sc13","seq":10}' \
    && check_pass "emit friendly_tester_report_validated" \
    || check_fail "emit friendly_tester_report_validated"

# --- Test 2 — assert exactly 11 lines appended. ---
if [ ! -f "$LOG" ]; then
    check_fail "execution-log.jsonl was not created at $LOG"
else
    check_pass "execution-log.jsonl exists at $LOG"
    line_count=0
    while IFS= read -r _line; do
        line_count=$((line_count + 1))
    done < "$LOG"
    if [ "$line_count" -eq 11 ]; then
        check_pass "11 lines appended to execution-log.jsonl"
    else
        check_fail "expected 11 lines, got $line_count"
    fi
fi

# --- Test 3 — schema_version 1.0 in every line. ---
schema_count=0
if [ -f "$LOG" ]; then
    schema_count=$(grep -c '"schema_version":"1.0"' "$LOG" || true)
fi
if [ "$schema_count" -eq 11 ]; then
    check_pass "schema_version 1.0 present in all 11 lines"
else
    check_fail "schema_version 1.0 count expected 11, got $schema_count"
fi

# --- Test 4 — every event_type appears exactly once. ---
assert_event_once() {
    local et="$1"
    local count=0
    if [ -f "$LOG" ]; then
        count=$(grep -c "\"event_type\":\"$et\"" "$LOG" || true)
    fi
    if [ "$count" -eq 1 ]; then
        check_pass "event_type $et appears exactly once"
    else
        check_fail "event_type $et expected 1, got $count"
    fi
}

assert_event_once start_branch_detected
assert_event_once start_init_invoked
assert_event_once constitution_authored
assert_event_once ingest_codebase_completed
assert_event_once materials_intake_completed
assert_event_once ideation_completed
assert_event_once migrate_routed
assert_event_once customblock_drafted
assert_event_once wiki_init_invoked
assert_event_once github_init_invoked
assert_event_once friendly_tester_report_validated

# --- Test 5 — every line has an ISO 8601 UTC timestamp. ---
ts_count=0
if [ -f "$LOG" ]; then
    ts_count=$(grep -c '"timestamp":"[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}Z"' "$LOG" || true)
fi
if [ "$ts_count" -eq 11 ]; then
    check_pass "ISO 8601 UTC timestamp present on all 11 lines"
else
    check_fail "ISO 8601 timestamp count expected 11, got $ts_count"
fi

# --- Test 6 — payload pass-through. ---
payload_count=0
if [ -f "$LOG" ]; then
    payload_count=$(grep -c '"test":"sc13"' "$LOG" || true)
fi
if [ "$payload_count" -eq 11 ]; then
    check_pass "payload pass-through verified on all 11 lines"
else
    check_fail "payload pass-through count expected 11, got $payload_count"
fi

# --- Test 7 — unknown event_type rejected (closed-enum negative path). ---
NEG_STAGING="$(mktemp -d -t m033-p02-sc13-neg-XXXXXX)"
neg_stderr_file="$NEG_STAGING/stderr.txt"
PROJECT_DIR="$NEG_STAGING" bash "$EMITTER" emit unknown_event '{}' 2> "$neg_stderr_file"
neg_rc=$?
if [ "$neg_rc" -ne 0 ]; then
    check_pass "unknown event_type exits non-zero (rc=$neg_rc)"
else
    check_fail "unknown event_type expected non-zero exit, got 0"
fi
if grep -F -q 'valid:' "$neg_stderr_file"; then
    check_pass "negative stderr names 'valid:' enum prefix"
else
    check_fail "negative stderr missing 'valid:' enum prefix"
fi
if grep -F -q 'friendly_tester_report_validated' "$neg_stderr_file"; then
    check_pass "negative stderr enumerates closed-enum tokens"
else
    check_fail "negative stderr missing closed-enum tokens"
fi
rm -rf "$NEG_STAGING"

# --- Test 8 — schema-version literal in emitter source (drift catch). ---
schema_lit_count=0
if [ -f "$EMITTER" ]; then
    schema_lit_count=$(grep -c '"1.0"' "$EMITTER" || true)
fi
if [ "$schema_lit_count" -ge 1 ]; then
    check_pass "schema_version literal '1.0' present in emitter source"
else
    check_fail "schema_version literal '1.0' missing from emitter source"
fi

echo "SUMMARY: p07-observability-records.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
