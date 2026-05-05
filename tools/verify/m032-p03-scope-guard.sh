#!/usr/bin/env bash
# tools/verify/m032-p03-scope-guard.sh — SC-13 scope-guard for P03.
# Asserts P03's git-tracked changes are confined to the P03 allowlist
# and do not touch the P00/P01/P02 denylist. Single-script-file shape
# per AD-19. Bash 3.2 compatible.
#
# Baseline-ref convention (mirrors P01/P02 m032-p0?-baseline-ref.txt):
#   First run records HEAD SHA into
#     tools/verify/fixtures/m032-p03-baseline-ref.txt
#   and PASSes unconditionally. Subsequent runs read the recorded ref
#   and compute `git diff --name-only <baseline_ref> HEAD` --
#   committed-history-only diff per the P01 patterns-established lesson
#   (working-tree-status was the failure mode that produced the M032/P01
#   99-PASS-trajectory rebaseline; P02 followed the same lesson).
#   Re-baselining is a deliberate operator act -- delete the fixture
#   file and re-run to recapture.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
BASELINE_REF_FILE="$SCRIPT_DIR/fixtures/m032-p03-baseline-ref.txt"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# P03 allowlist regex -- every path P03 may touch (create or modify).
ALLOWED_RE='^(wiki/overrides/partials/comments\.html|scripts/lifecycle/wiki-init\.sh|scripts/wiki/wiki-deploy\.sh|scripts/wiki/wiki-generate-nav\.sh|wiki/mkdocs\.yml|references/installation\.md|tests/m032-acceptance/throwaway-fixture-protocol\.md|tests/m032-acceptance/p02-wiki-init-with-giscus\.sh|tests/m032-acceptance/p03-wiki-init-deploy-live\.sh|tests/m032-acceptance/p02-wiki-generate-nav-custom-region\.sh|tools/verify/m032-p03-.*\.sh|tools/verify/fixtures/m032-p03-.*|\.orchestrator/milestones/M032/phases/P03/.*|\.orchestrator/milestones/M032/execution-log\.jsonl)$'

# Denylist regex -- paths owned by P00/P01/P02 that P03 MUST NOT touch
# (SC-13 violation if any matches in the diff set).
DENIED_RE='^(packaging/install/install-claude-code\.sh|packaging/install/install-codex\.sh|packaging/install/install-cursor\.sh|packaging/bundle/manifest\.yml|commands/init\.md|scripts/lifecycle/init-project\.sh|wiki/glossary\.md|scripts/wiki/wiki-scan-sources\.sh|scripts/knowledge/lookup-mems\.sh|tests/paired-m032-m033/seam-A\.sh|tests/paired-m032-m033/seam-B\.sh|tests/paired-m032-m033/seam-C\.sh)$'

# First-run capture branch: record the current HEAD as baseline.
if [ ! -f "$BASELINE_REF_FILE" ]; then
    mkdir -p "$( dirname "$BASELINE_REF_FILE" )"
    head_sha="$( git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null )"
    if [ -z "$head_sha" ]; then
        printf 'FAIL: m032-p03 scope-guard: cannot resolve HEAD in %s\n' "$PROJECT_ROOT" >&2
        printf 'SUMMARY: m032-p03-scope-guard.sh pass=0 fail=1\n'
        exit 1
    fi
    {
        printf '# M032/P03 scope-guard baseline ref -- captured at first scope-guard run.\n'
        printf '# To re-baseline (e.g. after milestone close), delete this file and re-run.\n'
        printf '%s\n' "$head_sha"
    } > "$BASELINE_REF_FILE"
    say_pass "m032-p03 scope-guard baseline captured at $head_sha"
    printf 'PASS: m032-p03 scope-guard pass=%d fail=%d in_scope=0 denylist_hits=0\n' "$pass" "$fail"
    printf 'SUMMARY: m032-p03-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 0
fi

baseline_ref="$( grep -v '^#' "$BASELINE_REF_FILE" | grep -v '^$' | head -n 1 | tr -d '[:space:]' )"
if [ -z "$baseline_ref" ]; then
    say_fail "baseline-ref file is non-empty after stripping comments"
    printf 'SUMMARY: m032-p03-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
say_pass "baseline-ref file is non-empty after stripping comments"

if ! git -C "$PROJECT_ROOT" rev-parse --verify "$baseline_ref" >/dev/null 2>&1; then
    say_fail "baseline ref '$baseline_ref' resolves in this repo"
    printf 'SUMMARY: m032-p03-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
say_pass "baseline ref '$baseline_ref' resolves in this repo"

# Committed-history-only diff (P01/P02 patterns-established lesson).
diff_paths="$( git -C "$PROJECT_ROOT" diff --name-only "$baseline_ref" HEAD 2>/dev/null )"

TMP_PATHS="$(mktemp)"
OUT_OF_SCOPE_LOG="${TMPDIR:-/tmp}/m032-p03-scope-guard-out-of-scope-$$.log"
DENY_LOG="${TMPDIR:-/tmp}/m032-p03-scope-guard-deny-$$.log"
: > "$OUT_OF_SCOPE_LOG"
: > "$DENY_LOG"
trap 'rm -f "$TMP_PATHS" "$OUT_OF_SCOPE_LOG" "$DENY_LOG"' EXIT

printf '%s\n' "$diff_paths" | sort -u | grep -v '^$' > "$TMP_PATHS"

# Allowlist check: every diff path must match the allowlist regex.
while IFS= read -r dpath; do
    [ -n "$dpath" ] || continue
    if ! printf '%s' "$dpath" | grep -E "$ALLOWED_RE" >/dev/null; then
        printf 'OUT-OF-SCOPE: %s\n' "$dpath" >> "$OUT_OF_SCOPE_LOG"
    fi
done < "$TMP_PATHS"

out_of_scope_count="$( wc -l < "$OUT_OF_SCOPE_LOG" | tr -d ' ' )"
in_scope_count="$( wc -l < "$TMP_PATHS" | tr -d ' ' )"
in_scope_count=$((in_scope_count - out_of_scope_count))

if [ "$out_of_scope_count" -eq 0 ]; then
    say_pass "scope: all $in_scope_count diff paths within P03 allowlist"
else
    say_fail "scope: $out_of_scope_count diff path(s) outside P03 allowlist"
    cat "$OUT_OF_SCOPE_LOG" >&2
fi

# Denylist check: no diff path may match the denylist regex.
while IFS= read -r dpath; do
    [ -n "$dpath" ] || continue
    if printf '%s' "$dpath" | grep -E "$DENIED_RE" >/dev/null; then
        printf 'DENYLIST: %s\n' "$dpath" >> "$DENY_LOG"
    fi
done < "$TMP_PATHS"

deny_count="$( wc -l < "$DENY_LOG" | tr -d ' ' )"

if [ "$deny_count" -eq 0 ]; then
    say_pass "scope: no diff path in P00/P01/P02 denylist"
else
    say_fail "scope: $deny_count diff path(s) in P00/P01/P02 denylist (SC-13 violation)"
    cat "$DENY_LOG" >&2
fi

printf 'PASS: m032-p03 scope-guard pass=%d fail=%d in_scope=%d denylist_hits=%d\n' "$pass" "$fail" "$in_scope_count" "$deny_count"
printf 'SUMMARY: m032-p03-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
