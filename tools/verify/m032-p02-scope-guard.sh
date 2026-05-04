#!/usr/bin/env bash
# tools/verify/m032-p02-scope-guard.sh — M032 P02 T05 (SC-13 scope-guard).
#
# Asserts that the P02 diff between the recorded baseline ref
# (`tools/verify/fixtures/m032-p02-baseline-ref.txt`) and HEAD is confined
# to the declared "Files Likely Touched" allowlist for P02.
#
# Allowlist (per the P02 plan + T01..T05 deliverables):
#   - commands/wiki-init.md                   (T01)
#   - scripts/lifecycle/wiki-init.sh          (T01)
#   - wiki/mkdocs.yml                         (T01 + FR-6 self-application)
#   - packaging/bundle/manifest.yml           (T01 wiki/ entry)
#   - commands/init.md                        (T02)
#   - scripts/lifecycle/init-project.sh       (T02)
#   - wiki/glossary.md                        (T03)
#   - scripts/wiki/wiki-scan-sources.sh       (T03)
#   - scripts/wiki/wiki-generate-nav.sh       (T03)
#   - scripts/wiki/wiki-generate-stubs.sh     (T03 -- stub generator)
#   - scripts/knowledge/lookup-mems.sh        (T04)
#   - tests/m032-acceptance/p02-*.sh          (T05 SC-3/SC-7 acceptance scripts)
#   - tests/paired-m032-m033/seam-*.sh        (T05 paired-launch seams)
#   - tools/verify/m032-p02-*.sh              (T01..T05 verifiers)
#   - tools/verify/lib/m032-p02-*.sh          (T01 wiki-serve probe helper)
#   - tools/verify/fixtures/m032-p02-*        (T05 baseline ref + per-task fixtures)
#   - .orchestrator/milestones/M032/phases/P02/**  (plan + summary + payload artifacts)
#
# Baseline-ref capture: the FIRST run of this verifier records HEAD as the
# baseline (mirroring P01's m032-p01-baseline-ref.txt precedent) and PASSes
# unconditionally. Subsequent runs read the recorded ref and diff against
# HEAD. Re-baselining is a deliberate operator act -- delete the fixture
# file and re-run to recapture.
#
# Per the P01 patterns-established lesson: committed-history-only diff
# (`git diff --name-only "$baseline_ref" HEAD`) -- working-tree-vs-baseline
# was the failure mode that produced the M032/P01 99-PASS-trajectory
# rebaseline.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
BASELINE_REF_FILE="$SCRIPT_DIR/fixtures/m032-p02-baseline-ref.txt"

pass=0
fail=0

check() {
    desc="$1"; rc="$2"
    if [ "$rc" -eq 0 ]; then
        printf 'PASS: %s\n' "$desc"; pass=$((pass + 1))
    else
        printf 'FAIL: %s\n' "$desc"; fail=$((fail + 1))
    fi
}

# First-run capture branch: record the current HEAD as baseline.
if [ ! -f "$BASELINE_REF_FILE" ]; then
    mkdir -p "$( dirname "$BASELINE_REF_FILE" )"
    head_sha="$( git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null )"
    if [ -z "$head_sha" ]; then
        echo "FAIL: m032-p02 scope-guard: cannot resolve HEAD in $PROJECT_ROOT"
        printf 'SUMMARY: m032-p02-scope-guard.sh pass=0 fail=1\n'
        exit 1
    fi
    {
        printf '# M032/P02 scope-guard baseline ref -- captured at first scope-guard run.\n'
        printf '# To re-baseline (e.g. after milestone close), delete this file and re-run.\n'
        printf '%s\n' "$head_sha"
    } > "$BASELINE_REF_FILE"
    printf 'PASS: m032-p02 scope-guard baseline captured at %s\n' "$head_sha"
    printf 'SUMMARY: m032-p02-scope-guard.sh pass=1 fail=0\n'
    exit 0
fi

baseline_ref="$( grep -v '^#' "$BASELINE_REF_FILE" | grep -v '^$' | head -n 1 | tr -d '[:space:]' )"
if [ -z "$baseline_ref" ]; then
    check "baseline-ref file is non-empty after stripping comments" 1
    printf 'SUMMARY: m032-p02-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
check "baseline-ref file is non-empty after stripping comments" 0

if ! git -C "$PROJECT_ROOT" rev-parse --verify "$baseline_ref" >/dev/null 2>&1; then
    check "baseline ref '$baseline_ref' resolves in this repo" 1
    printf 'SUMMARY: m032-p02-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi
check "baseline ref '$baseline_ref' resolves in this repo" 0

# Allowlist regex -- paths matching are P02-scoped.
ALLOWED_RE='^(commands/wiki-init\.md|scripts/lifecycle/wiki-init\.sh|wiki/mkdocs\.yml|packaging/bundle/manifest\.yml|commands/init\.md|scripts/lifecycle/init-project\.sh|wiki/glossary\.md|scripts/wiki/wiki-scan-sources\.sh|scripts/wiki/wiki-generate-nav\.sh|scripts/wiki/wiki-generate-stubs\.sh|scripts/knowledge/lookup-mems\.sh|tests/m032-acceptance/p02-.*\.sh|tests/paired-m032-m033/seam-.*\.sh|tools/verify/m032-p02-.*\.sh|tools/verify/lib/m032-p02-.*\.sh|tools/verify/fixtures/m032-p02-.*|\.orchestrator/milestones/M032/phases/P02/.*)$'

# Committed-history-only diff (P01 patterns-established lesson).
diff_paths="$( git -C "$PROJECT_ROOT" diff --name-only "$baseline_ref" HEAD 2>/dev/null )"

violation_log="${TMPDIR:-/tmp}/m032-p02-scope-guard-violations-$$.log"
: > "$violation_log"

# Walk the diff path list; collect any path that fails the allowlist regex.
TMP_PATHS="$(mktemp)"
trap 'rm -f "$TMP_PATHS" "$violation_log"' EXIT
printf '%s\n' "$diff_paths" | sort -u | grep -v '^$' > "$TMP_PATHS"

while IFS= read -r path; do
    [ -n "$path" ] || continue
    if ! printf '%s' "$path" | grep -E "$ALLOWED_RE" >/dev/null; then
        printf 'OUT-OF-SCOPE: %s\n' "$path" >> "$violation_log"
    fi
done < "$TMP_PATHS"

violation_count="$( wc -l < "$violation_log" | tr -d ' ' )"

if [ "$violation_count" -eq 0 ]; then
    in_scope_count="$( wc -l < "$TMP_PATHS" | tr -d ' ' )"
    check "P02 diff contains no out-of-scope paths ($in_scope_count in-scope paths)" 0
else
    check "P02 diff contains no out-of-scope paths (violations=$violation_count)" 1
    cat "$violation_log" >&2
fi

printf 'SUMMARY: m032-p02-scope-guard.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
