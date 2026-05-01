#!/usr/bin/env bash
# tests/m031-acceptance/doc-drift-verifier.sh
# M031/P04/T01 — SC-9 doc-drift verifier (FR-17).
#
# Asserts commands/evaluate.md and references/tier-definitions.md
# contain the canonical Tier A description and zero matches for the
# pre-M024 prohibited phrasings. POSIX-bash per CON-6 / DC-7 — runs
# under bash 3.2 + dash + sh without modification.
#
# Required absence (post-M024 doc-drift fix, FR-14 + FR-15):
#   - "no orchestrator overhead"               in commands/evaluate.md
#   - "Do NOT create any orchestrator directory" in commands/evaluate.md
#   - "no orchestrator overhead"               in references/tier-definitions.md
#
# Required presence (canonical Tier A descriptor, post-M031):
#   - "Quick profile" in commands/evaluate.md
#   - "Quick profile" in references/tier-definitions.md
#
# Emits RESULT: SC-9 pass (exit 0) or RESULT: SC-9 fail (exit 1).

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
EVAL_MD="$PROJECT_ROOT/commands/evaluate.md"
TIER_DEF="$PROJECT_ROOT/references/tier-definitions.md"

pass=0
fail=0

check_absent() {
    # $1 file, $2 needle, $3 label
    if grep -q -F -- "$2" "$1"; then
        printf 'FAIL: %s -- %s contains "%s"\n' "$3" "$1" "$2"
        fail=$((fail + 1))
    else
        printf 'PASS: %s\n' "$3"
        pass=$((pass + 1))
    fi
}

check_present() {
    # $1 file, $2 needle, $3 label
    if grep -q -F -- "$2" "$1"; then
        printf 'PASS: %s\n' "$3"
        pass=$((pass + 1))
    else
        printf 'FAIL: %s -- %s missing "%s"\n' "$3" "$1" "$2"
        fail=$((fail + 1))
    fi
}

check_absent  "$EVAL_MD"  "no orchestrator overhead"                "evaluate.md drift phrasing 1 absent"
check_absent  "$EVAL_MD"  "Do NOT create any orchestrator directory" "evaluate.md drift phrasing 2 absent"
check_present "$EVAL_MD"  "Quick profile"                           "evaluate.md canonical Tier A descriptor"
check_absent  "$TIER_DEF" "no orchestrator overhead"                "tier-definitions.md drift phrasing absent"
check_present "$TIER_DEF" "Quick profile"                           "tier-definitions.md canonical Tier A descriptor"

printf 'SC-9 totals: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    printf 'RESULT: SC-9 pass\n'
    exit 0
fi
printf 'RESULT: SC-9 fail\n'
exit 1
