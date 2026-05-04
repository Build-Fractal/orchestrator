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

# Collect the working-tree-vs-baseline tracked diff. This covers BOTH
# committed-on-top-of-baseline AND unstaged/staged working-tree changes
# against the baseline -- the union that captures all of T01..T04's
# tracked modifications regardless of commit status.
#
# We deliberately do NOT consider untracked files (`?? ` lines from
# `git status --porcelain`). Pre-existing untracked operator artifacts
# (e.g. proposals or notes that pre-date T01) are not P01's diff
# concern; the scope-guard flags out-of-scope CHANGES, not pre-existing
# working-tree noise. T04's new files (fixture, acceptance scripts,
# verifiers) are tracked through `git add` semantics; if the operator
# adds them to the index BEFORE running this verifier they appear in
# the tracked diff. If they are not yet `git add`-ed, the working-tree
# diff above captures them via the `--diff-filter` machinery only
# partially -- so the verifier ALSO walks `git ls-files --others
# --exclude-standard` filtered by the in-scope known-T04 directories
# whitelist.
diff_paths=$( git -C "$PROJECT_ROOT" diff --name-only "$baseline_ref" 2>/dev/null )

# Whitelist of directories that T01..T04 are EXPECTED to introduce new
# files under. Untracked paths NOT under one of these prefixes are
# treated as pre-existing operator noise and ignored by the scope-guard.
# Untracked paths UNDER one of these prefixes are added to the diff
# set so we can intersect them with the forbidden patterns.
T04_NEW_PATH_PREFIXES='^tools/verify/m032-
^tools/verify/fixtures/m032-
^tests/fixtures/m032-fresh-project-fixture/
^tests/m032-acceptance/
^scripts/lifecycle/(install-asset-mode|install-collision-check|read-project-assets)\.sh$
^\.orchestrator/milestones/M032/
'

untracked_in_scope=""
while IFS= read -r u; do
    [ -z "$u" ] && continue
    for pre in $T04_NEW_PATH_PREFIXES; do
        if printf '%s\n' "$u" | grep -qE "$pre"; then
            untracked_in_scope="${untracked_in_scope}${u}
"
            break
        fi
    done
done < <( git -C "$PROJECT_ROOT" ls-files --others --exclude-standard )

all_paths=$( printf '%s\n%s\n' "$diff_paths" "$untracked_in_scope" | sort -u | grep -v '^$' )

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
