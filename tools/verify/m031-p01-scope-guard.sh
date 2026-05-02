#!/usr/bin/env bash
# tools/verify/m031-p01-scope-guard.sh -- M031 P01 SC-12 scope-guard verifier.
#
# Asserts the P01 diff (working tree vs HEAD) does NOT touch any path
# under the SC-12 normative block-list. The block-list is normative
# per CON-1 + DC-3 + Principle XV. Future maintainers tempted to
# relax it MUST first amend the spec's "Boundary write-sites M031
# delegates" section -- do NOT edit this verifier to "fix" a violation.
#
# SC-12 forbidden paths (block-list):
#   - knowledge/                       (knowledge graph -- M020 owns)
#   - scripts/cost/                    (cost surfaces -- M027 owns)
#   - scripts/dispatch/adapters/router/ (router -- M030 owns)
#   - scripts/auto/loop/               (auto-loop -- M021 owns)
#
# M031/P01/T04 remediation: orchestrator-emitted hit_count drift on
# knowledge/MEM*.md is a dispatch side-effect, not a manual P01 scope
# violation. When a `knowledge/(conventions|lessons|patterns)/MEM*.md`
# file shows up in the diff, the verifier inspects its actual diff
# content; if every changed line matches `^[+-]hit_count: [0-9]+$` the
# path is carved out of the block-list. Any other knowledge edit --
# including non-hit_count line changes to MEM files, or any change to
# non-MEM knowledge files -- still triggers a hard violation.
#
# Allow-list (P01 "Files Likely Touched" per P01-PLAN.md): only the
# files listed below + the permissive `.orchestrator/observability/`
# prefix may legitimately differ from the M031 baseline.
#
# Diff source: `git diff --name-only HEAD` reports staged + unstaged
# changes in the working tree. The verifier walks each changed path,
# matches it against the block-list (HARD FAIL on any match) and the
# allow-list (soft WARN on miss). The scope-guard verifier itself
# (`tools/verify/m031-p01-scope-guard.sh`) is in the allow-list, so
# the verifier does not flag its own creation.
#
# Output:
#   FAIL: scope-guard violation: <path> matches <block-pattern>
#   WARN: out-of-allow-list: <path>
#   OK:   <path> (allow-listed)
#
# Final line: SUMMARY: m031-p01-scope-guard.sh pass=N fail=M block_list_violations=K
# Exit 0 iff zero block-list matches; exit 1 on any block-list match.
#
# Bash 3.2 compatible.

set -u

# ---------- Locate project root ----------

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd "$PROJECT_ROOT"

# ---------- Allow-list (newline-delimited; matched by exact path) ----------

ALLOW_LIST_EXACT='scripts/dispatch/build-context.sh
commands/dispatch.md
tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh
tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl
tests/m031-acceptance/test-quick-injects-knowledge.sh
tests/m031-acceptance/test-build-context-profile.sh
tests/m031-acceptance/test-compression-applies-to-quick.sh
tests/m031-acceptance/test-quick-budget-median.sh
tools/verify/m031-p01-build-context-profile-shape.sh
tools/verify/m031-p01-quick-no-skip-branch.sh
tools/verify/m031-p01-config-knobs-stable.sh
tools/verify/m031-p01-dispatch-md-reconciliation.sh
tools/verify/m031-p01-post-baseline-jsonl-population.sh
tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh
tools/verify/m031-p01-test-build-context-profile-shape.sh
tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh
tools/verify/m031-p01-test-quick-budget-median-shape.sh
tools/verify/m031-p01-phase-suite.sh
tools/verify/m031-p01-scope-guard.sh
.orchestrator/milestones/M031/phases/P01/P01-PLAN.md
.orchestrator/milestones/M031/phases/P01/tasks/T01-build-context-profile-PLAN.md
.orchestrator/milestones/M031/phases/P01/tasks/T02-ad14-capture-and-fr4-PLAN.md
.orchestrator/milestones/M031/phases/P01/tasks/T03-acceptance-tests-PLAN.md
.orchestrator/milestones/M031/phases/P01/tasks/T04-phase-suite-and-scope-guard-PLAN.md
.orchestrator/milestones/M031/phases/P01/tasks/T01-SUMMARY.md
.orchestrator/milestones/M031/phases/P01/tasks/T02-SUMMARY.md
.orchestrator/milestones/M031/phases/P01/tasks/T03-SUMMARY.md
.orchestrator/milestones/M031/phases/P01/tasks/T04-SUMMARY.md
.orchestrator/milestones/M031/phases/P01/P01-SUMMARY.md'

# Allow-list prefix (permissive; for JSONL emission records).
ALLOW_LIST_PREFIX='.orchestrator/observability/'

# ---------- Counters ----------

pass=0
fail=0
block_list_violations=0
mem_hitcount_carveouts=0

# ---------- MEM hit_count-only carve-out ----------
# Returns 0 if the path is a knowledge/(conventions|lessons|patterns)/MEM*.md
# file whose diff contents are exclusively `hit_count:` line changes
# (orchestrator dispatch side-effect, not a manual scope violation).
# Returns 1 otherwise (path not MEM-shaped, or diff contains other changes).
is_mem_hitcount_only_carveout() {
    p="$1"
    # Path must match knowledge/(conventions|lessons|patterns)/MEM*.md exactly.
    case "$p" in
        knowledge/conventions/MEM*.md|knowledge/lessons/MEM*.md|knowledge/patterns/MEM*.md)
            ;;
        *)
            return 1
            ;;
    esac
    # Inspect the actual diff body. Lines starting with `+` or `-` (but not
    # the `+++ ` / `--- ` file headers) are the changed lines; every such
    # line must match `^[+-]hit_count: [0-9]+$`. If we find any other
    # changed line, the carve-out does NOT apply.
    diff_body="$( git diff -- "$p" )"
    if [ -z "$diff_body" ]; then
        return 1
    fi
    # Walk diff body line by line; track whether we saw any changed lines
    # and whether all of them are hit_count lines.
    saw_change=0
    while IFS= read -r line; do
        case "$line" in
            '+++ '*|'--- '*)
                continue
                ;;
            '+'*|'-'*)
                saw_change=1
                case "$line" in
                    '+hit_count: '*|'-hit_count: '*)
                        # Validate the numeric tail.
                        tail="${line#?hit_count: }"
                        case "$tail" in
                            ''|*[!0-9]*)
                                return 1
                                ;;
                        esac
                        ;;
                    *)
                        return 1
                        ;;
                esac
                ;;
        esac
    done <<EOF
$diff_body
EOF
    if [ "$saw_change" -eq 1 ]; then
        return 0
    fi
    return 1
}

# ---------- Match a single path against the block-list ----------
# Echoes the matched block-pattern on stdout, or empty string on no match.
match_block_list() {
    p="$1"
    case "$p" in
        knowledge/*)
            printf 'knowledge/'
            return
            ;;
        scripts/cost/*)
            printf 'scripts/cost/'
            return
            ;;
        scripts/dispatch/adapters/router/*)
            printf 'scripts/dispatch/adapters/router/'
            return
            ;;
        scripts/auto/loop/*)
            printf 'scripts/auto/loop/'
            return
            ;;
    esac
    printf ''
}

# ---------- Match a single path against the allow-list ----------
# Returns 0 if allow-listed, 1 otherwise.
match_allow_list() {
    p="$1"
    # Prefix match (observability JSONL).
    case "$p" in
        "$ALLOW_LIST_PREFIX"*)
            return 0
            ;;
    esac
    # Exact match against newline-delimited list.
    while IFS= read -r entry; do
        if [ "$p" = "$entry" ]; then
            return 0
        fi
    done <<EOF
$ALLOW_LIST_EXACT
EOF
    return 1
}

# ---------- Collect changed paths ----------

changed_paths_file="$( mktemp -t m031-p01-scope-guard.XXXXXX )"
trap 'rm -f "$changed_paths_file"' EXIT

git diff --name-only HEAD > "$changed_paths_file"

# ---------- Walk each changed path ----------

while IFS= read -r path; do
    # Skip empty lines (trailing newline from git diff).
    if [ -z "$path" ]; then
        continue
    fi

    block_match="$( match_block_list "$path" )"
    if [ -n "$block_match" ]; then
        # MEM hit_count-only carve-out (T04 remediation): orchestrator
        # dispatch side-effect, not a manual scope violation.
        if is_mem_hitcount_only_carveout "$path"; then
            printf 'OK: %s (mem-hitcount-only carve-out)\n' "$path"
            pass=$(( pass + 1 ))
            mem_hitcount_carveouts=$(( mem_hitcount_carveouts + 1 ))
            continue
        fi
        printf 'FAIL: scope-guard violation: %s matches %s\n' "$path" "$block_match"
        fail=$(( fail + 1 ))
        block_list_violations=$(( block_list_violations + 1 ))
        continue
    fi

    if match_allow_list "$path"; then
        printf 'OK: %s (allow-listed)\n' "$path"
        pass=$(( pass + 1 ))
    else
        printf 'WARN: out-of-allow-list: %s\n' "$path"
        # Soft warning; not counted as fail.
    fi
done < "$changed_paths_file"

# ---------- Aggregate summary ----------

printf 'SUMMARY: m031-p01-scope-guard.sh pass=%d fail=%d block_list_violations=%d mem_hitcount_carveouts=%d\n' \
    "$pass" "$fail" "$block_list_violations" "$mem_hitcount_carveouts"

if [ "$block_list_violations" -eq 0 ]; then
    exit 0
else
    exit 1
fi
