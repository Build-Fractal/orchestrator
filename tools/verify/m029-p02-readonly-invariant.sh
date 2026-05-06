#!/usr/bin/env bash
# tools/verify/m029-p02-readonly-invariant.sh -- M029 P02 read-only invariant verifier (project-tree variant).
#
# Project-tree complement to the SC-14 acceptance script. Where SC-14
# (tests/m029-acceptance/p02-sc14-readonly.sh) drives the AD-9 sentinel
# harness against the FIXTURE tree, this verifier exercises P02's renderer
# surfaces against the LIVE project tree and asserts no `.orchestrator/`
# file gets written as a side effect.
#
# The two checks are diagnostic-distinct, not redundant: a write that only
# surfaces under real-disk shapes (e.g. a stray `.lock` from a race) will
# never appear in the fixture but will surface here.
#
# Mechanism: drop a sentinel file under ${TMPDIR:-/tmp}/ with a known
# mtime (NOT under .orchestrator/, per the run-probe.sh scope rule 4
# domain), invoke each P02 surface in read-only mode, then `find` for any
# `.orchestrator/` file with mtime newer than the sentinel.
#
# Surfaces under test:
#   1. scripts/diagnostics/render-position.sh --milestone M029
#   2. scripts/diagnostics/summarize-milestone.sh --milestone M029 --format=keys
#
# Pattern after tools/verify/m029-p01-readonly-invariant.sh.
#
# Bash 3.2 / MEM001. AD-19 straight-line bash -- no compound chains, no
# process substitution, no associative arrays.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

pass=0
fail=0

ok() {
    printf 'PASS: %s\n' "$1"
    pass=$((pass + 1))
}

bad() {
    printf 'FAIL: %s\n' "$1"
    fail=$((fail + 1))
}

# --- Sentinel under /tmp (not .orchestrator/) -------------------------------
SENTINEL_DIR="${TMPDIR:-/tmp}"
SENTINEL_FILE="$SENTINEL_DIR/m029-p02-readonly.$$.sentinel"
printf 'sentinel created %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$SENTINEL_FILE"
trap 'rm -f "$SENTINEL_FILE"' EXIT

# Sleep 1 second so any subsequent mtime is strictly newer than the sentinel
# (filesystem mtime resolution is whole seconds on some FSes).
sleep 1

# Helper -- detect any file under .orchestrator/ newer than the sentinel.
# Excludes execution-log.jsonl (M019 owned, written by other surfaces during
# concurrent dispatcher activity -- not in scope for the renderer's
# read-only contract). Excludes sentinel files themselves (we only ever
# write the one under /tmp, but defensive).
_check_no_writes() {
    label="$1"
    violations="$SENTINEL_DIR/m029-p02-readonly-violations.$$.out"
    find "$PROJECT_ROOT/.orchestrator" -type f -newer "$SENTINEL_FILE" \
        -not -name 'execution-log.jsonl' \
        -not -name '*.sentinel' \
        > "$violations" 2>/dev/null || true
    if [ -s "$violations" ]; then
        bad "$label: write detected under .orchestrator/"
        sed 's/^/   | /' "$violations" >&2
    else
        ok "$label: no writes under .orchestrator/"
    fi
    rm -f "$violations"
}

# --- Surface 1: render-position.sh ------------------------------------------
RENDER_OUT="$SENTINEL_DIR/m029-p02-render-position.$$.out"
set +e
bash "$PROJECT_ROOT/scripts/diagnostics/render-position.sh" --milestone M029 > "$RENDER_OUT" 2>&1
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
    ok "render-position.sh --milestone M029 exits 0"
else
    bad "render-position.sh --milestone M029 exited rc=$rc"
    sed 's/^/   | /' "$RENDER_OUT" >&2
fi
rm -f "$RENDER_OUT"
_check_no_writes "after render-position invocation"

# --- Surface 2: summarize-milestone.sh --------------------------------------
SUMMARIZE_OUT="$SENTINEL_DIR/m029-p02-summarize.$$.out"
set +e
bash "$PROJECT_ROOT/scripts/diagnostics/summarize-milestone.sh" --milestone M029 --format=keys > "$SUMMARIZE_OUT" 2>&1
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
    ok "summarize-milestone.sh --milestone M029 --format=keys exits 0"
else
    bad "summarize-milestone.sh --milestone M029 --format=keys exited rc=$rc"
    sed 's/^/   | /' "$SUMMARIZE_OUT" >&2
fi
rm -f "$SUMMARIZE_OUT"
_check_no_writes "after summarize-milestone invocation"

printf 'SUMMARY: m029-p02-readonly-invariant.sh pass=%d fail=%d\n' "$pass" "$fail"
printf 'note: project-tree variant of SC-14; SC-14 (fixture variant) lives at tests/m029-acceptance/p02-sc14-readonly.sh\n'
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
