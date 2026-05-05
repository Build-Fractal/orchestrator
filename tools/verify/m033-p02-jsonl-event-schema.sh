#!/usr/bin/env bash
# m033-p02-jsonl-event-schema.sh
#
# Verifier for M033/P02/T01: scripts/util/jsonl-event-emitter.sh
# (FR-22 emitter library).
#
# Asserts shape (closed-enum event types, schema version literal,
# fenced SSOT block markers, append target string) and exercises a
# functional smoke test (positive emit produces one well-formed JSONL
# record) plus a negative-path test (unknown event_type exits non-zero
# and stderr names the closed enum).
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/m033-p02-jsonl-event-schema.sh
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

emitter="$PROJECT_ROOT/scripts/util/jsonl-event-emitter.sh"

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

# Check 1: emitter exists.
if [ ! -f "$emitter" ]; then
    echo "FAIL: emitter missing at $emitter"
    echo "SUMMARY: m033-p02-jsonl-event-schema.sh pass=0 fail=1"
    exit 1
fi
check_pass "emitter exists at $emitter"

# Check 2: emitter is executable.
if [ ! -x "$emitter" ]; then
    check_fail "emitter not executable: $emitter"
else
    check_pass "emitter is executable"
fi

# Check 3: schema version literal "1.0" appears.
if grep -F -q '"schema_version":"1.0"' "$emitter"; then
    check_pass 'schema version literal "1.0" appears in emitter body'
else
    check_fail 'schema version literal "1.0" missing from emitter body'
fi

# Check 4-14: all 11 event-type tokens appear via grep -F.
for token in start_branch_detected start_init_invoked constitution_authored ingest_codebase_completed materials_intake_completed ideation_completed migrate_routed customblock_drafted wiki_init_invoked github_init_invoked friendly_tester_report_validated; do
    if grep -F -q "$token" "$emitter"; then
        check_pass "event-type token present: $token"
    else
        check_fail "event-type token missing: $token"
    fi
done

# Check 15: fenced SSOT block opening marker.
if grep -F -q '# >>> event-types >>>' "$emitter"; then
    check_pass 'fenced SSOT opening marker present'
else
    check_fail 'fenced SSOT opening marker missing: # >>> event-types >>>'
fi

# Check 16: fenced SSOT block closing marker.
if grep -F -q '# <<< event-types <<<' "$emitter"; then
    check_pass 'fenced SSOT closing marker present'
else
    check_fail 'fenced SSOT closing marker missing: # <<< event-types <<<'
fi

# Check 17: execution-log.jsonl append target string appears.
if grep -F -q 'execution-log.jsonl' "$emitter"; then
    check_pass 'execution-log.jsonl append target string present'
else
    check_fail 'execution-log.jsonl append target string missing'
fi

# --- Functional smoke test: positive path ---

staging="$(mktemp -d 2>/dev/null)"
if [ -z "$staging" ] || [ ! -d "$staging" ]; then
    check_fail "could not create mktemp -d staging dir for smoke test"
    echo "SUMMARY: m033-p02-jsonl-event-schema.sh pass=$pass fail=$fail"
    if [ "$fail" -gt 0 ]; then
        exit 1
    fi
    exit 0
fi

PROJECT_DIR="$staging" bash "$emitter" emit ideation_completed '{"test":"smoke"}' >/dev/null 2>&1
emit_rc=$?

log_path="$staging/.orchestrator/execution-log.jsonl"

if [ "$emit_rc" -eq 0 ]; then
    check_pass "positive smoke: emit ideation_completed exited 0"
else
    check_fail "positive smoke: emit ideation_completed exited $emit_rc"
fi

if [ -f "$log_path" ]; then
    check_pass "positive smoke: execution-log.jsonl created at $log_path"
else
    check_fail "positive smoke: execution-log.jsonl not created at $log_path"
fi

if [ -f "$log_path" ]; then
    line_count=$(wc -l < "$log_path")
    line_count=${line_count// /}
    if [ "$line_count" = "1" ]; then
        check_pass "positive smoke: log contains exactly 1 line"
    else
        check_fail "positive smoke: log line count = $line_count (expected 1)"
    fi

    if grep -F -q '"event_type":"ideation_completed"' "$log_path"; then
        check_pass 'positive smoke: log line contains "event_type":"ideation_completed"'
    else
        check_fail 'positive smoke: log line missing "event_type":"ideation_completed"'
    fi

    if grep -F -q '"schema_version":"1.0"' "$log_path"; then
        check_pass 'positive smoke: log line contains "schema_version":"1.0"'
    else
        check_fail 'positive smoke: log line missing "schema_version":"1.0"'
    fi
fi

# --- Negative smoke test: unknown event_type ---

neg_stderr="$staging/neg.stderr"
PROJECT_DIR="$staging" bash "$emitter" emit unknown_event '{}' >/dev/null 2>"$neg_stderr"
neg_rc=$?

if [ "$neg_rc" -ne 0 ]; then
    check_pass "negative smoke: unknown_event exits non-zero (rc=$neg_rc)"
else
    check_fail "negative smoke: unknown_event exited 0 (expected non-zero)"
fi

# Stderr must surface the closed enum (or at minimum the leading + trailing tokens).
if grep -F -q 'start_branch_detected' "$neg_stderr"; then
    check_pass 'negative smoke: stderr names start_branch_detected (closed-enum echo)'
else
    check_fail 'negative smoke: stderr missing start_branch_detected'
fi

if grep -F -q 'friendly_tester_report_validated' "$neg_stderr"; then
    check_pass 'negative smoke: stderr names friendly_tester_report_validated (closed-enum echo)'
else
    check_fail 'negative smoke: stderr missing friendly_tester_report_validated'
fi

# Cleanup staging.
rm -rf "$staging"

echo "SUMMARY: m033-p02-jsonl-event-schema.sh pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
