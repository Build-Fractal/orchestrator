#!/usr/bin/env bash
# tests/m031-acceptance/scope-guard.sh -- M031 milestone-grain SC-12 scope-guard.
#
# Authored at M031/P04/T04. This is the operator-facing acceptance-test
# entry for SC-12 (boundary write-site enforcement) at the WHOLE-MILESTONE
# scope. It is intentionally distinct from the per-phase scope-guards at
# tools/verify/m031-p0X-scope-guard.sh:
#
#   - Per-phase scope-guards (tools/verify/m031-p01-scope-guard.sh and
#     siblings) gate a single phase's working-tree diff with a per-phase
#     allow-list (Files Likely Touched per the phase plan).
#   - This milestone-grain scope-guard gates the entire M031 working-tree
#     diff with the UNION of every phase's allow-list. It is the gate the
#     M031 acceptance battery (run-acceptance-battery.sh) chains as SC-12.
#
# Both surfaces share the same SC-12 normative block-list (inherited
# verbatim from CON-1 + DC-3 + Principle XV via the per-phase verifiers):
#
#   - knowledge/                        (knowledge graph -- M020 owns)
#   - scripts/cost/                     (cost surfaces -- M027 owns)
#   - scripts/dispatch/adapters/router/ (router -- M030 owns)
#   - scripts/auto/loop/                (auto-loop -- M021 owns)
#
# Future maintainers tempted to relax the block-list MUST first amend the
# spec's "Boundary write-sites M031 delegates" section -- do NOT edit this
# verifier to "fix" a violation.
#
# MEM hit_count carve-out (inherited verbatim from M031/P01/T04 +
# M031/P02/T05 + M031/P03/T03): orchestrator-emitted hit_count drift on
# knowledge/MEM*.md is a dispatch side-effect, not a manual M031 scope
# violation. When a knowledge/(conventions|lessons|patterns)/MEM*.md file
# shows up in the diff, the verifier inspects its actual diff content; if
# every changed line matches `^[+-]hit_count: [0-9]+$` the path is carved
# out of the block-list. Any other knowledge edit -- including
# non-hit_count line changes to MEM files, or any change to non-MEM
# knowledge files -- still triggers a hard violation.
#
# Dual-prefix permissive carve-out (inherited verbatim from P02 + P03):
# the .orchestrator/observability/ AND .orchestrator/tier-a-plus/
# prefixes are permissive. The observability prefix is used by JSONL
# emission records; the tier-a-plus prefix is per-flow scratch artifacts
# written during router test runs and integration smoke runs.
#
# Allow-list (UNION of M031 P00..P04 "Files Likely Touched"): only the
# files listed below + the dual-prefix permissive prefixes may
# legitimately differ from the project main baseline.
#
# Diff source: `git diff --name-only HEAD` reports staged + unstaged
# changes in the working tree. The verifier walks each changed path,
# matches it against the block-list (HARD FAIL on any match) and the
# allow-list (soft WARN on miss). The scope-guard verifier itself is in
# the allow-list, so the verifier does not flag its own creation.
#
# Output:
#   FAIL: scope-guard violation: <path> matches <block-pattern>
#   WARN: out-of-allow-list: <path>
#   OK:   <path> (allow-listed | mem-hitcount-only carve-out)
#
# Final lines (dual envelope):
#   RESULT: SC-12 pass            (acceptance-test envelope, mirrors run-acceptance-battery.sh sub-gate convention)
#   SUMMARY: scope-guard.sh pass=N fail=M block_list_violations=K mem_hitcount_carveouts=L
#
# Exit 0 iff zero block-list matches; exit 1 on any block-list match.
#
# POSIX-bash compatible (CON-6 / DC-7): no [[ ]], no `declare -A`, no
# `echo -e`; arithmetic via $(( ... )); single-script Truth Check shape
# per AD-19.

set -u

# ---------- Locate project root ----------

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd "$PROJECT_ROOT"

# ---------- Allow-list (newline-delimited; matched by exact path) ----------
# UNION of M031 P00..P04 "Files Likely Touched" surfaces.
ALLOW_LIST_EXACT='# P00 (baseline corpus + ordering verifier)
tests/m031-acceptance/empirical-baseline.sh
tests/m031-acceptance/verify-baseline-ordering.sh
tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md
tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md
tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh
tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh
tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl
tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl
tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-02.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-03.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-04.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-05.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-06.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-07.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-08.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-09.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-10.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-11.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-12.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-13.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-14.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-15.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-16.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-17.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-18.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-19.txt
tests/m031-acceptance/fixtures/empirical-baseline/task-20.txt
.orchestrator/direct-mode-execution-log.jsonl
# P01 (build-context profile + dispatch.md amendment + acceptance tests)
scripts/dispatch/build-context.sh
commands/dispatch.md
templates/orchestrator-config-default.yml
tests/m031-acceptance/test-quick-injects-knowledge.sh
tests/m031-acceptance/test-build-context-profile.sh
tests/m031-acceptance/test-compression-applies-to-quick.sh
tests/m031-acceptance/test-quick-budget-median.sh
tools/verify/m031-p01-build-context-profile-shape.sh
tools/verify/m031-p01-quick-no-skip-branch.sh
tools/verify/m031-p01-config-knobs-stable.sh
tools/verify/m031-p01-post-baseline-jsonl-population.sh
tools/verify/m031-p01-dispatch-md-reconciliation.sh
tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh
tools/verify/m031-p01-test-build-context-profile-shape.sh
tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh
tools/verify/m031-p01-test-quick-budget-median-shape.sh
tools/verify/m031-p01-phase-suite.sh
tools/verify/m031-p01-scope-guard.sh
# P02 (Tier A+ classifier + slug + role templates + prompt + router)
scripts/intake/shape-detect.sh
scripts/intake/paragraph-classify.sh
scripts/intake/route-to-dispatch.sh
scripts/intake/lib/task-slug.sh
scripts/intake/lib/tier-a-plus-prompt.sh
templates/dispatch-role-research.md
templates/dispatch-role-plan.md
templates/dispatch-role-build.md
tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md
tests/m031-acceptance/fixtures/tier-a-plus-input.txt
tests/m031-acceptance/test-tier-a-plus-classifier.sh
tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh
tests/m031-acceptance/test-tier-a-plus-flow.sh
tools/verify/m031-p02-classifier-extension-shape.sh
tools/verify/m031-p02-fixture-provenance-shape.sh
tools/verify/m031-p02-tier-a-plus-input-shape.sh
tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh
tools/verify/m031-p02-task-slug-shape.sh
tools/verify/m031-p02-role-templates-shape.sh
tools/verify/m031-p02-prompt-shape.sh
tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh
tools/verify/m031-p02-router-shape.sh
tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh
tools/verify/m031-p02-phase-suite.sh
tools/verify/m031-p02-scope-guard.sh
# P03 (universal-entry skill + entry script + acceptance tests)
commands/do.md
scripts/intake/do-entry.sh
tests/m031-acceptance/fixtures/do-entry-stub.sh
tests/m031-acceptance/fixtures/do-entry-trivial-input.txt
tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt
tests/m031-acceptance/test-universal-entry-trivial.sh
tests/m031-acceptance/test-universal-entry-lowconf.sh
tools/verify/m031-p03-do-md-shape.sh
tools/verify/m031-p03-do-entry-shape.sh
tools/verify/m031-p03-fastpath-shape.sh
tools/verify/m031-p03-passthrough-shape.sh
tools/verify/m031-p03-test-universal-entry-trivial-shape.sh
tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh
tools/verify/m031-p03-phase-suite.sh
tools/verify/m031-p03-scope-guard.sh
# P04 (drift fix + doctor + budget-warning + scope-guard + battery + ledger)
commands/evaluate.md
references/tier-definitions.md
CHANGELOG.md
scripts/diagnostics/run-doctor.sh
scripts/diagnostics/efficiency-footer.sh
tests/m031-acceptance/doc-drift-verifier.sh
tests/m031-acceptance/test-auto-proceed-default.sh
tests/m031-acceptance/test-doctor-compound-change.sh
tests/m031-acceptance/test-budget-drift-warning.sh
tests/m031-acceptance/scope-guard.sh
tests/m031-acceptance/run-acceptance-battery.sh
.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md
tools/verify/m031-p04-evaluate-md-drift-shape.sh
tools/verify/m031-p04-tier-definitions-drift-shape.sh
tools/verify/m031-p04-auto-proceed-default-shape.sh
tools/verify/m031-p04-changelog-shape.sh
tools/verify/m031-p04-doctor-compound-change-shape.sh
tools/verify/m031-p04-budget-drift-shape.sh
tools/verify/m031-p04-test-doc-drift-shape.sh
tools/verify/m031-p04-test-auto-proceed-shape.sh
tools/verify/m031-p04-test-doctor-compound-change-shape.sh
tools/verify/m031-p04-test-budget-drift-shape.sh
tools/verify/m031-p04-test-scope-guard-shape.sh
tools/verify/m031-p04-battery-shape.sh
tools/verify/m031-p04-evidence-ledger-shape.sh
tools/verify/m031-p04-phase-suite.sh
tools/verify/m031-p04-scope-guard.sh
# Phase / task plan + summary paths under .orchestrator/milestones/M031/
.orchestrator/milestones/M031/M031-CONTEXT.md
.orchestrator/milestones/M031/M031-EVALUATION.md
.orchestrator/milestones/M031/M031-ROADMAP.md
.orchestrator/milestones/M031/M031-SUMMARY.md
.orchestrator/milestones/M031/execution-log.jsonl'

# Allow-list prefixes (permissive; for JSONL emission records and per-flow
# Tier A+ / universal-entry scratch artifacts).
ALLOW_LIST_PREFIX_OBSERVABILITY='.orchestrator/observability/'
ALLOW_LIST_PREFIX_TIER_A_PLUS='.orchestrator/tier-a-plus/'
ALLOW_LIST_PREFIX_M031_PHASES='.orchestrator/milestones/M031/phases/'

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
# Inherited verbatim from M031/P01/T04 + M031/P02/T05 + M031/P03/T03.
is_mem_hitcount_only_carveout() {
    p="$1"
    case "$p" in
        knowledge/conventions/MEM*.md|knowledge/lessons/MEM*.md|knowledge/patterns/MEM*.md)
            ;;
        *)
            return 1
            ;;
    esac
    diff_body="$( git diff -- "$p" )"
    if [ -z "$diff_body" ]; then
        return 1
    fi
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
# SC-12 block-list verbatim from spec "Boundary write-sites M031 delegates":
# knowledge/, scripts/cost/, scripts/dispatch/adapters/router/, scripts/auto/loop/.
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
    case "$p" in
        "$ALLOW_LIST_PREFIX_OBSERVABILITY"*)
            return 0
            ;;
    esac
    case "$p" in
        "$ALLOW_LIST_PREFIX_TIER_A_PLUS"*)
            return 0
            ;;
    esac
    case "$p" in
        "$ALLOW_LIST_PREFIX_M031_PHASES"*)
            return 0
            ;;
    esac
    while IFS= read -r entry; do
        case "$entry" in
            ''|'#'*)
                continue
                ;;
        esac
        if [ "$p" = "$entry" ]; then
            return 0
        fi
    done <<EOF
$ALLOW_LIST_EXACT
EOF
    return 1
}

# ---------- Collect changed paths ----------

changed_paths_file="$( mktemp -t m031-scope-guard.XXXXXX )"
trap 'rm -f "$changed_paths_file"' EXIT

git diff --name-only HEAD > "$changed_paths_file"
# Include untracked (new) files so M031-additive paths register.
git ls-files --others --exclude-standard >> "$changed_paths_file"

# ---------- Walk each changed path ----------

while IFS= read -r path; do
    if [ -z "$path" ]; then
        continue
    fi

    block_match="$( match_block_list "$path" )"
    if [ -n "$block_match" ]; then
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
    fi
done < "$changed_paths_file"

# ---------- Aggregate summary ----------

if [ "$block_list_violations" -eq 0 ]; then
    printf 'RESULT: SC-12 pass\n'
else
    printf 'RESULT: SC-12 fail\n'
fi
printf 'SUMMARY: scope-guard.sh pass=%d fail=%d block_list_violations=%d mem_hitcount_carveouts=%d\n' \
    "$pass" "$fail" "$block_list_violations" "$mem_hitcount_carveouts"

if [ "$block_list_violations" -eq 0 ]; then
    exit 0
fi
exit 1
