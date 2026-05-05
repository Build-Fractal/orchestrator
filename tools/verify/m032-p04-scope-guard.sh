#!/usr/bin/env bash
# tools/verify/m032-p04-scope-guard.sh — SC-13 scope-guard for P04.
# Asserts P04's git-tracked changes (committed-history-only diff per
# the P01/P02/P03 patterns-established lesson — working-tree noise
# is the failure mode that produces sibling-phase false-positives
# in dogfood loops with parallel M033 development) are confined to
# the P04 allowlist and do not touch the P00/P01/P02/P03 denylist.
# Single-script-file shape per AD-19. Bash 3.2.
#
# Baseline-ref convention (mirrors P01/P02/P03 m032-p0?-baseline-ref.txt):
#   First run records HEAD SHA into
#     tools/verify/fixtures/m032-p04-baseline-ref.txt
#   and PASSes unconditionally. Subsequent runs read the recorded ref
#   and compute `git diff --name-only <baseline_ref> HEAD`.
#   Re-baselining is a deliberate operator act -- delete the fixture
#   file and re-run to recapture.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
BASELINE_REF_FILE="$SCRIPT_DIR/fixtures/m032-p04-baseline-ref.txt"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# P04 allowlist regex -- every path P04 may touch (create or modify).
# Includes:
#   - P04-owned scanner/nav/decorator scripts (T01/T02 deliverables)
#   - sibling-phase wiki-init.sh in-flight repair (T02 --with-wiki noop)
#   - P04-owned acceptance scripts (T01/T02/T03/T04 + run-acceptance-battery.sh)
#   - milestone-grain close-ceremony artifacts (T05)
#   - P04 phase-grain plan/payload/summary tree
#   - P04-owned tools/verify scripts + baseline-ref fixture
#   - milestone execution-log.jsonl (unit_close record)
#   - T05 in-flight repairs to sibling-phase verifier shape drift
#     (golden refresh, SC-7 marker fix, SC-5 fixture-completeness skip
#     precondition) per the P02/T02 + P03/T05 in-flight-repair convention.
ALLOWED_RE='^(scripts/wiki/wiki-scan-sources\.sh|scripts/wiki/wiki-generate-nav\.sh|scripts/wiki/wiki-generate-stubs\.sh|scripts/wiki/wiki-decorate-codes\.sh|scripts/lifecycle/wiki-init\.sh|tests/m032-acceptance/p0X-scanner-extensions\.sh|tests/m032-acceptance/p0X-code-decorator\.sh|tests/m032-acceptance/sc11-doctor-no-warnings\.sh|tests/m032-acceptance/run-acceptance-battery\.sh|tests/m032-acceptance/p02-glossary-surface\.sh|tests/m032-acceptance/p03-wiki-init-deploy-live\.sh|tools/verify/fixtures/m032-pre-m032-golden\.txt|\.orchestrator/milestones/M032/M032-VALIDATED|\.orchestrator/milestones/M032/M032-SUMMARY\.md|\.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE\.md|\.orchestrator/milestones/M032/execution-log\.jsonl|\.orchestrator/milestones/M032/phases/P04/.*|tools/verify/m032-p04-.*\.sh|tools/verify/fixtures/m032-p04-.*)$'

# Denylist regex -- paths owned by P00/P01/P02/P03 that P04 MUST NOT touch.
# (T05's in-flight repairs to sibling-phase verifiers are excluded from
# the denylist because the P02/T02 + P03/T05 convention permits sibling-
# phase repair within the same task that surfaces the drift.)
DENIED_RE='^(packaging/install/install-claude-code\.sh|packaging/install/install-codex\.sh|packaging/install/install-cursor\.sh|packaging/bundle/manifest\.yml|commands/init\.md|scripts/lifecycle/init-project\.sh|wiki/glossary\.md|wiki/mkdocs\.yml|scripts/knowledge/lookup-mems\.sh|scripts/wiki/wiki-deploy\.sh|wiki/overrides/partials/comments\.html|references/installation\.md|tests/m032-acceptance/throwaway-fixture-protocol\.md|tests/paired-m032-m033/seam-A\.sh|tests/paired-m032-m033/seam-B\.sh|tests/paired-m032-m033/seam-C\.sh)$'

# First-run capture branch: record current HEAD as baseline.
if [ ! -f "$BASELINE_REF_FILE" ]; then
    mkdir -p "$( dirname "$BASELINE_REF_FILE" )"
    head_sha="$( git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null )"
    if [ -z "$head_sha" ]; then
        printf 'FAIL: m032-p04 scope-guard: cannot resolve HEAD in %s\n' "$PROJECT_ROOT" >&2
        printf 'SUMMARY: m032-p04-scope-guard.sh pass=0 fail=1\n'
        exit 1
    fi
    {
        printf '# M032/P04 scope-guard baseline ref -- captured at first scope-guard run.\n'
        printf '# To re-baseline (e.g. after milestone close), delete this file and re-run.\n'
        printf '%s\n' "$head_sha"
    } > "$BASELINE_REF_FILE"
    say_pass "m032-p04 scope-guard baseline captured at $head_sha"
    printf 'PASS: m032-p04 scope-guard pass=%d fail=%d in_scope=0 denylist_hits=0\n' "$pass" "$fail"
    printf 'SUMMARY: m032-p04-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 0
fi

baseline_ref="$( grep -v '^#' "$BASELINE_REF_FILE" | grep -v '^$' | head -n 1 | tr -d '[:space:]' )"
if [ -z "$baseline_ref" ]; then
    say_fail "baseline-ref file is non-empty after stripping comments"
    printf 'SUMMARY: m032-p04-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
say_pass "baseline-ref file is non-empty after stripping comments"

if ! git -C "$PROJECT_ROOT" rev-parse --verify "$baseline_ref" >/dev/null 2>&1; then
    say_fail "baseline ref '$baseline_ref' resolves in this repo"
    printf 'SUMMARY: m032-p04-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
say_pass "baseline ref '$baseline_ref' resolves in this repo"

# Committed-history-only diff (P01/P02/P03 patterns-established lesson).
diff_paths="$( git -C "$PROJECT_ROOT" diff --name-only "$baseline_ref" HEAD 2>/dev/null )"

TMP_PATHS="$(mktemp)"
OUT_OF_SCOPE_LOG="${TMPDIR:-/tmp}/m032-p04-scope-guard-out-of-scope-$$.log"
DENY_LOG="${TMPDIR:-/tmp}/m032-p04-scope-guard-deny-$$.log"
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
    say_pass "scope: all $in_scope_count diff paths within P04 allowlist"
else
    say_fail "scope: $out_of_scope_count diff path(s) outside P04 allowlist"
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
    say_pass "scope: no diff path in P00/P01/P02/P03 denylist"
else
    say_fail "scope: $deny_count diff path(s) in P00/P01/P02/P03 denylist (SC-13 violation)"
    cat "$DENY_LOG" >&2
fi

printf 'PASS: m032-p04 scope-guard pass=%d fail=%d in_scope=%d denylist_hits=%d\n' "$pass" "$fail" "$in_scope_count" "$deny_count"
printf 'SUMMARY: m032-p04-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
