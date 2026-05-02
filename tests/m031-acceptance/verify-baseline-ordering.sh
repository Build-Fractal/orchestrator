#!/usr/bin/env bash
# tests/m031-acceptance/verify-baseline-ordering.sh
#
# AD-12 / SC-13 baseline-ordering verifier for milestone M031.
#
# Two options:
#
#   - Option B (preferred): assert via `git log` that the first commit
#     touching the empirical-baseline corpus path predates the first
#     commit touching each protected path (commands/dispatch.md and
#     scripts/dispatch/build-context.sh) per AD-14's single-window
#     discipline. This guarantees the pre-M031 baseline JSONL was
#     captured BEFORE the post-M031 dispatch surface was modified.
#
#   - Option A (fallback): when `git log` is unavailable (shallow
#     clone, non-git checkout, etc.), SC-13 reclassifies as a P00
#     protocol note. The N adjustment in SC-14 (N >= 14 instead of
#     N >= 15) takes effect. The operator records the option in
#     SC13-OPTION.md.
#
# CLI:
#   --corpus-path <path>     (default fixtures/empirical-baseline/)
#   --protected-paths <csv>  (default scripts/dispatch/build-context.sh,commands/dispatch.md)
#
# Output:
#   ORDERING: option=<A|B> verdict=<pass|fail|protocol-note>
#
# Exit 0 on Option B pass or Option A protocol-note; exit 1 on Option B fail.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no process
# substitution.

set -u

corpus_path="tests/m031-acceptance/fixtures/empirical-baseline/"
protected_paths_csv="scripts/dispatch/build-context.sh,commands/dispatch.md"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --corpus-path)
            corpus_path="$2"
            shift 2
            ;;
        --protected-paths)
            protected_paths_csv="$2"
            shift 2
            ;;
        *)
            echo "ERROR: unrecognized argument: $1" >&2
            exit 1
            ;;
    esac
done

# Option detection: try `git log -1 --format=%ct -- <corpus_path>` and
# check that we get a non-empty commit timestamp back.
corpus_first_ct=$(git log --diff-filter=AM --reverse --format=%ct -- "$corpus_path" 2>/dev/null | head -n 1)

if [ -z "$corpus_first_ct" ]; then
    # Option A fallback: corpus has no committed history yet (e.g.
    # T03 hasn't committed) OR the runtime is a shallow clone /
    # non-git checkout. Either way, ordering enforcement defers to
    # AD-14 manual review and SC-14 uses N >= 14.
    echo "OPTION-A: SC-13 reclassifies as P00 protocol note; ordering enforcement deferred to AD-14 manual review."
    echo "ORDERING: option=A verdict=protocol-note"
    exit 0
fi

# Option B: walk each protected path. If a protected path has no
# commit history yet (e.g., the path doesn't exist or hasn't been
# touched), we treat that as PASS for that path — the corpus commit
# trivially predates "no commit yet." If a protected path has a first
# commit, assert corpus_first_ct < protected_first_ct.
fail_count=0
old_IFS="$IFS"
IFS=','
for path in $protected_paths_csv; do
    IFS="$old_IFS"
    protected_first_ct=$(git log --diff-filter=AM --reverse --format=%ct --follow -- "$path" 2>/dev/null | head -n 1)
    if [ -z "$protected_first_ct" ]; then
        # No commit yet touching this path — corpus trivially predates.
        IFS=','
        continue
    fi
    if [ "$corpus_first_ct" -lt "$protected_first_ct" ]; then
        IFS=','
        continue
    fi
    echo "ORDERING-FAIL: corpus_first_commit_ct=$corpus_first_ct >= protected_first_commit_ct=$protected_first_ct ($path)" >&2
    fail_count=$(( fail_count + 1 ))
    IFS=','
done
IFS="$old_IFS"

if [ "$fail_count" -gt 0 ]; then
    echo "ORDERING: option=B verdict=fail"
    exit 1
fi

echo "ORDERING: option=B verdict=pass"
exit 0
