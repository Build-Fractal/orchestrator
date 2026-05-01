#!/usr/bin/env bash
# tests/m031-acceptance/test-universal-entry-trivial.sh
#
# M031/P03/T02 -- SC-7 acceptance test for the universal-entry fast path
# at scripts/intake/do-entry.sh. Drives the entry script against a
# trivial Tier A degenerate input (the classifier emits idea/high) and
# asserts:
#
#   1. exit code 0;
#   2. stderr contains exactly one line matching the FR-12 summary
#        ^doing: .* — knowledge: [0-9]+ MEMs / [0-9]+ tokens$
#      (the em-dash is U+2014);
#   3. stderr contains zero approval-prompt residue (no `(y)` substring,
#      i.e. the low-confidence prompt did not fire);
#   4. the canned dispatch stub at do-entry-stub.sh fired exactly once
#      with branch=tier_a_degenerate (knowledge inject + payload write
#      observable via the stub log).
#
# The test exercises the entry via the --dispatch-stub seam, so no real
# agent runtime is required (MEM018: production handoff to agent runtime
# is integration-tested under M033 onboarding flows; SC-7 gates the
# contract surface, not the production runtime end-to-end -- plan-time
# discipline rule 5).
#
# The build-context.sh invocation that the entry fires writes the
# dispatch payload to a tmp path under the system tmp dir, so the SC-7
# fixture task plan does not need a richer body -- the minimal inline
# task plan in run_tier_a_degenerate is sufficient (verified empirically
# during T02 authoring).
#
# Output envelope:
#   RESULT: SC-7 pass   on success
#   RESULT: SC-7 fail: <diagnostic>   on failure
#
# Single-script Truth Check shape per AD-19. Bash 3.2 compatible
# (MEM001). No scaffold-placeholder bracket-TODO byte pattern (D020).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENTRY="$PROJECT_ROOT/scripts/intake/do-entry.sh"
STUB="$PROJECT_ROOT/tests/m031-acceptance/fixtures/do-entry-stub.sh"
INPUT_FIXTURE="$PROJECT_ROOT/tests/m031-acceptance/fixtures/do-entry-trivial-input.txt"

fail_messages=""

record_fail() {
    fail_messages="$fail_messages
  - $1"
}

# Per-test scratch root + stub log path. Tmp dirs are out of the
# scope-guard's purview because /tmp lives outside the repo tree
# (CON-4 / DC-4 -- no orchestration-state writes from this test).
work_dir="${TMPDIR:-/tmp}/m031-p03-t02-sc7-$$"
rm -rf "$work_dir"
mkdir -p "$work_dir"
trap 'rm -rf "$work_dir"' EXIT

stub_log="$work_dir/stub.log"
stderr_capture="$work_dir/stderr.txt"
: > "$stub_log"

if [ ! -x "$ENTRY" ]; then
    record_fail "do-entry.sh not executable at $ENTRY"
fi
if [ ! -x "$STUB" ]; then
    record_fail "do-entry-stub.sh not executable at $STUB"
fi
if [ ! -f "$INPUT_FIXTURE" ]; then
    record_fail "do-entry-trivial-input.txt missing at $INPUT_FIXTURE"
fi

trivial_task=""
if [ -f "$INPUT_FIXTURE" ]; then
    trivial_task=$(head -1 "$INPUT_FIXTURE")
fi

if [ -z "$trivial_task" ]; then
    record_fail "trivial fixture is empty"
fi

if [ -z "$fail_messages" ]; then
    ORCH_DO_ENTRY_STUB_LOG="$stub_log" \
    bash "$ENTRY" \
        --task "$trivial_task" \
        --dispatch-stub "$STUB" \
        --scratch-root "$work_dir" \
        2> "$stderr_capture"
    rc=$?

    if [ "$rc" -ne 0 ]; then
        record_fail "do-entry.sh exited rc=$rc (expected 0)"
    fi

    doing_count=$(grep -cE '^doing: .* — knowledge: [0-9]+ MEMs / [0-9]+ tokens$' "$stderr_capture" || true)
    if [ "${doing_count:-0}" -ne 1 ]; then
        record_fail "expected exactly 1 FR-12 'doing:' summary line on stderr, got $doing_count"
    fi

    yprompt_count=$(grep -c '(y)' "$stderr_capture" || true)
    if [ "${yprompt_count:-0}" -ne 0 ]; then
        record_fail "expected zero approval-prompt '(y)' residue on stderr, got $yprompt_count"
    fi

    stub_count=$(grep -c '^stub-invocation: branch=tier_a_degenerate ' "$stub_log" || true)
    if [ "${stub_count:-0}" -ne 1 ]; then
        record_fail "expected exactly 1 stub invocation with branch=tier_a_degenerate, got $stub_count"
    fi
fi

if [ -z "$fail_messages" ]; then
    echo "RESULT: SC-7 pass"
    exit 0
fi

printf 'RESULT: SC-7 fail:%s\n' "$fail_messages"
exit 1
