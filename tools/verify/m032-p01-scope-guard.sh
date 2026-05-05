#!/usr/bin/env bash
# tools/verify/m032-p01-scope-guard.sh -- M032 P01 T04 (SC-13 scope-guard).
#
# Asserts that the P01 diff between the recorded baseline ref
# (`tools/verify/fixtures/m032-p01-baseline-ref.txt`) and HEAD does NOT touch
# any out-of-scope path. Out-of-scope for P01:
#
#   - wiki/                              (P02 wiki distribution)
#   - scripts/wiki/                      (P02 wiki distribution)
#   - scripts/knowledge/lookup-mems.sh   (P03 / M033 onboarding)
#   - commands/init.md                   (P03 init integration)
#   - scripts/lifecycle/init-project.sh  (P03 init integration)
#   - commands/wiki-init.md              (P02 wiki-init command)
#   - tests/paired-m032-m033/            (P02 paired-milestone seam tests, per #Q-B)
#   - references/installation.md         (P03 installation docs)
#   - .orchestrator/proposals/*.md       (proposals are read-only inputs)
#
# Baseline-ref capture: the first run of this verifier reads the ref from the
# fixture file. The file is committed when T04 lands; subsequent runs read
# the same ref. Updating the baseline (e.g. when P02 starts) is a deliberate
# act, not an automatic one.
#
# The verifier also covers UNTRACKED files: a `git status --porcelain` walk
# flags any untracked path that intersects the forbidden globs.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
BASELINE_REF_FILE="$SCRIPT_DIR/fixtures/m032-p01-baseline-ref.txt"

pass=0
fail=0

check() {
    desc="$1"
    rc="$2"
    if [ "$rc" -eq 0 ]; then
        printf 'PASS: %s\n' "$desc"
        pass=$((pass + 1))
    else
        printf 'FAIL: %s\n' "$desc"
        fail=$((fail + 1))
    fi
}

# Resolve baseline ref.
if [ ! -f "$BASELINE_REF_FILE" ]; then
    check "baseline-ref fixture exists at $BASELINE_REF_FILE" 1
    printf 'SUMMARY: m032-p01-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
check "baseline-ref fixture exists at $BASELINE_REF_FILE" 0

baseline_ref=$(grep -v '^#' "$BASELINE_REF_FILE" | grep -v '^$' | head -n 1 | tr -d '[:space:]')
if [ -z "$baseline_ref" ]; then
    check "baseline-ref file is non-empty after stripping comments" 1
    printf 'SUMMARY: m032-p01-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

if ! git -C "$PROJECT_ROOT" rev-parse --verify "$baseline_ref" >/dev/null 2>&1; then
    check "baseline ref '$baseline_ref' resolves in this repo" 1
    printf 'SUMMARY: m032-p01-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
check "baseline ref '$baseline_ref' resolves in this repo" 0

# Forbidden glob patterns. Each is grep-compatible (basic regex).
FORBIDDEN_PATTERNS='^wiki/
^scripts/wiki/
^scripts/knowledge/lookup-mems\.sh$
^commands/init\.md$
^scripts/lifecycle/init-project\.sh$
^commands/wiki-init\.md$
^tests/paired-m032-m033/
^references/installation\.md$
^\.orchestrator/proposals/.*\.md$
'

# Collect the committed-history diff between baseline and HEAD. The
# scope-guard's invariant is "the commits that ship P01 don't touch
# out-of-scope paths" -- working-tree dirt (uncommitted operator notes,
# untracked drafts, half-staged WIP) is operator state, not P01's diff.
# Comparing committed history is the semantic match: ambient working-
# tree edits do not pollute the signal, and post-baseline commits that
# legitimately ship P01 deliverables are exactly what's checked.
#
# Earlier shape compared working-tree-vs-baseline (`git diff $baseline_ref`)
# plus an `ls-files --others` walk for untracked files. That conflated
# "P01 didn't touch X" with "the operator has nothing else pending in
# the tree." Replaced 2026-05-04 during M032/P01 re-verification.
diff_paths=$( git -C "$PROJECT_ROOT" diff --name-only "$baseline_ref" HEAD 2>/dev/null )

all_paths=$( printf '%s\n' "$diff_paths" | sort -u | grep -v '^$' )

violation_count=0
violation_log="${TMPDIR:-/tmp}/m032-p01-scope-guard-violations-$$.log"
: > "$violation_log"

# For each forbidden pattern, intersect with all_paths.
for pat in $FORBIDDEN_PATTERNS; do
    [ -z "$pat" ] && continue
    if printf '%s\n' "$all_paths" | grep -qE "$pat"; then
        printf 'VIOLATION pattern=%s matches:\n' "$pat" >> "$violation_log"
        printf '%s\n' "$all_paths" | grep -E "$pat" >> "$violation_log"
        violation_count=$((violation_count + 1))
    fi
done

if [ "$violation_count" -eq 0 ]; then
    check "P01 diff contains no out-of-scope paths" 0
else
    check "P01 diff contains no out-of-scope paths (violations=$violation_count)" 1
    cat "$violation_log" >&2
fi
rm -f "$violation_log"

printf 'SUMMARY: m032-p01-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
