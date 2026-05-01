#!/usr/bin/env bash
# tests/m031-acceptance/test-universal-entry-lowconf.sh
#
# M031/P03/T02 -- SC-8 acceptance test for the universal-entry
# low-confidence branch at scripts/intake/do-entry.sh. Drives the
# entry script against a low-confidence input (the classifier emits
# idea/low at the 8-10 word boundary band per shape-detect.sh) and
# asserts:
#
#   Sub-case A (operator selects Tier A in the prompt, --no-prompt-mode A):
#     1. exit code 0;
#     2. stderr renders the explicit prompt (literal substrings
#          `Tier A` AND `Tier B` AND `?`);
#     3. the JSONL unit_close record at ${ORCH_DO_ENTRY_LOG} contains
#        exactly one occurrence of `"chosen_shape":"A"`;
#     4. the canned dispatch stub fired exactly once with
#        branch=tier_a_degenerate (the prompt collapsed to the
#        Tier A degenerate fast-path).
#
#   Sub-case B (operator selects Tier B in the prompt, --no-prompt-mode B):
#     1. exit code 0;
#     2. stderr contains the literal substrings `route=tier_bc` AND
#        `passthrough=orchestrator:specify` (Tier B/C passthrough fired);
#     3. the JSONL unit_close record contains exactly one occurrence of
#        `"chosen_shape":"B"`;
#     4. zero stub invocations fired (the passthrough branch does NOT
#        fire a dispatch).
#
# The test exercises the entry via the --dispatch-stub seam and
# overrides ORCH_DO_ENTRY_LOG to a per-sub-case tmp path so the
# assertions read only the records emitted in this test run (CON-4 /
# DC-4 -- no orchestration-state writes from this test).
#
# Output envelope:
#   RESULT: SC-8 pass   on success (both sub-cases)
#   RESULT: SC-8 fail: <diagnostic>   on failure
#
# Single-script Truth Check shape per AD-19. Bash 3.2 compatible
# (MEM001). No scaffold-placeholder bracket-TODO byte pattern (D020).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENTRY="$PROJECT_ROOT/scripts/intake/do-entry.sh"
STUB="$PROJECT_ROOT/tests/m031-acceptance/fixtures/do-entry-stub.sh"
INPUT_FIXTURE="$PROJECT_ROOT/tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt"

fail_messages=""

record_fail() {
    fail_messages="$fail_messages
  - $1"
}

if [ ! -x "$ENTRY" ]; then
    record_fail "do-entry.sh not executable at $ENTRY"
fi
if [ ! -x "$STUB" ]; then
    record_fail "do-entry-stub.sh not executable at $STUB"
fi
if [ ! -f "$INPUT_FIXTURE" ]; then
    record_fail "do-entry-lowconf-input.txt missing at $INPUT_FIXTURE"
fi

lowconf_task=""
if [ -f "$INPUT_FIXTURE" ]; then
    lowconf_task=$(head -1 "$INPUT_FIXTURE")
fi
if [ -z "$lowconf_task" ]; then
    record_fail "low-confidence fixture is empty"
fi

# Independent tmp scratch roots per sub-case so they do not race.
work_a="${TMPDIR:-/tmp}/m031-p03-t02-sc8a-$$"
work_b="${TMPDIR:-/tmp}/m031-p03-t02-sc8b-$$"
rm -rf "$work_a" "$work_b"
mkdir -p "$work_a" "$work_b"
trap 'rm -rf "$work_a" "$work_b"' EXIT

stub_log_a="$work_a/stub.log"
jsonl_log_a="$work_a/dispatch-log.jsonl"
stderr_a="$work_a/stderr.txt"
: > "$stub_log_a"
: > "$jsonl_log_a"

stub_log_b="$work_b/stub.log"
jsonl_log_b="$work_b/dispatch-log.jsonl"
stderr_b="$work_b/stderr.txt"
: > "$stub_log_b"
: > "$jsonl_log_b"

# ----- Sub-case A: --no-prompt-mode A -----
if [ -z "$fail_messages" ]; then
    ORCH_DO_ENTRY_STUB_LOG="$stub_log_a" \
    ORCH_DO_ENTRY_LOG="$jsonl_log_a" \
    bash "$ENTRY" \
        --task "$lowconf_task" \
        --no-prompt-mode A \
        --dispatch-stub "$STUB" \
        --scratch-root "$work_a" \
        2> "$stderr_a"
    rc_a=$?

    if [ "$rc_a" -ne 0 ]; then
        record_fail "sub-case A: do-entry.sh exited rc=$rc_a (expected 0)"
    fi

    if ! grep -F -q -e 'Tier A' "$stderr_a"; then
        record_fail "sub-case A: stderr missing literal 'Tier A'"
    fi
    if ! grep -F -q -e 'Tier B' "$stderr_a"; then
        record_fail "sub-case A: stderr missing literal 'Tier B'"
    fi
    if ! grep -F -q -e '?' "$stderr_a"; then
        record_fail "sub-case A: stderr missing literal '?'"
    fi

    a_count=$(grep -c '"chosen_shape":"A"' "$jsonl_log_a" || true)
    if [ "${a_count:-0}" -ne 1 ]; then
        record_fail "sub-case A: expected 1 chosen_shape:A record, got $a_count"
    fi

    stub_a_count=$(grep -c '^stub-invocation: branch=tier_a_degenerate ' "$stub_log_a" || true)
    if [ "${stub_a_count:-0}" -ne 1 ]; then
        record_fail "sub-case A: expected 1 stub invocation tier_a_degenerate, got $stub_a_count"
    fi
fi

# ----- Sub-case B: --no-prompt-mode B -----
if [ -z "$fail_messages" ]; then
    ORCH_DO_ENTRY_STUB_LOG="$stub_log_b" \
    ORCH_DO_ENTRY_LOG="$jsonl_log_b" \
    bash "$ENTRY" \
        --task "$lowconf_task" \
        --no-prompt-mode B \
        --dispatch-stub "$STUB" \
        --scratch-root "$work_b" \
        2> "$stderr_b"
    rc_b=$?

    if [ "$rc_b" -ne 0 ]; then
        record_fail "sub-case B: do-entry.sh exited rc=$rc_b (expected 0)"
    fi

    if ! grep -F -q -e 'route=tier_bc' "$stderr_b"; then
        record_fail "sub-case B: stderr missing literal 'route=tier_bc'"
    fi
    if ! grep -F -q -e 'passthrough=orchestrator:specify' "$stderr_b"; then
        record_fail "sub-case B: stderr missing literal 'passthrough=orchestrator:specify'"
    fi

    b_count=$(grep -c '"chosen_shape":"B"' "$jsonl_log_b" || true)
    if [ "${b_count:-0}" -ne 1 ]; then
        record_fail "sub-case B: expected 1 chosen_shape:B record, got $b_count"
    fi

    stub_b_lines=$(awk 'END {print NR}' "$stub_log_b")
    if [ "${stub_b_lines:-0}" -ne 0 ]; then
        record_fail "sub-case B: expected 0 stub invocations on Tier B passthrough, got $stub_b_lines"
    fi
fi

if [ -z "$fail_messages" ]; then
    echo "RESULT: SC-8 pass"
    exit 0
fi

printf 'RESULT: SC-8 fail:%s\n' "$fail_messages"
exit 1
