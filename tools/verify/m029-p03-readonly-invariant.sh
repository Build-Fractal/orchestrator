#!/usr/bin/env bash
# tools/verify/m029-p03-readonly-invariant.sh -- M029 P03 read-only invariant verifier (project-tree variant).
#
# LIVE-tree complement to P03's SC-fixture readonly checks. Where the SC
# acceptance scripts (tests/m029-acceptance/p03-sc*.sh) drive their
# scenarios against fixture trees under tests/m029-acceptance/fixtures/,
# this verifier exercises P03's surfaces against the LIVE project tree
# and asserts no `.orchestrator/` file gets written as a side effect.
#
# The two checks are diagnostic-distinct, not redundant: a write that only
# surfaces under real-disk shapes (e.g. a stray `.lock` from a race) will
# never appear in a fixture but will surface here.
#
# Mechanism: drop a sentinel file under ${TMPDIR:-/tmp}/ with a known
# mtime (NOT under .orchestrator/, per the run-probe.sh scope rule 4
# domain), invoke each P03 surface in read-only mode, then `find` for any
# `.orchestrator/` file with mtime newer than the sentinel.
#
# Surfaces under test:
#   1. scripts/diagnostics/render-position.sh --live --milestone M029
#      (timed kill at ~1.5s -- the --live mode is a long-running poll loop).
#   2. scripts/diagnostics/render-position.sh --milestone M029
#      (at-rest baseline render -- FR-5).
#   3. scripts/diagnostics/summarize-milestone.sh --milestone M029 --format=keys
#      (used by the AD-4 SC-8 oracle wrapper).
#
# Exclusions when scanning .orchestrator/ for newer-than-sentinel offenders:
#   - execution-log.jsonl       (M019 owned, written by other surfaces during
#                                concurrent dispatcher activity -- not in scope
#                                for the renderer's read-only contract)
#   - *.sentinel                (defensive; sentinel itself lives under /tmp)
#   - *.complete / *.txt        (auto-loop / dispatch-side markers; out of P03 surface scope)
#
# Pattern after tools/verify/m029-p02-readonly-invariant.sh.
#
# Bash 3.2 / MEM001. AD-19 straight-line bash -- no compound chains, no
# process substitution, no associative arrays. The `<<<` herestring (used
# in some prior drafts) is replaced with `printf '%s\n' | while read` for
# uniform shape across phases.

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
SENTINEL_FILE="$SENTINEL_DIR/m029-p03-readonly.$$.sentinel"
printf 'sentinel created %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$SENTINEL_FILE"
trap 'rm -f "$SENTINEL_FILE"' EXIT

# Sleep 1 second so any subsequent mtime is strictly newer than the sentinel
# (filesystem mtime resolution is whole seconds on some FSes).
sleep 1

# Helper -- detect any file under .orchestrator/ newer than the sentinel.
# Excludes execution-log.jsonl (M019 owned), sentinel files (defensive),
# and auto-loop/dispatch-side markers (*.complete / *.txt) which sit
# outside the P03 surface read-only contract.
_check_no_writes() {
    label="$1"
    violations="$SENTINEL_DIR/m029-p03-readonly-violations.$$.out"
    find "$PROJECT_ROOT/.orchestrator" -type f -newer "$SENTINEL_FILE" \
        -not -name 'execution-log.jsonl' \
        -not -name '*.sentinel' \
        -not -name '*.complete' \
        -not -name '*.txt' \
        > "$violations" 2>/dev/null || true
    if [ -s "$violations" ]; then
        bad "$label: write detected under .orchestrator/"
        sed 's/^/   | /' "$violations" >&2
    else
        ok "$label: no writes under .orchestrator/"
    fi
    rm -f "$violations"
}

# --- Surface 1: render-position --live (timed kill at ~1.5s) ----------------
LIVE_OUT="$SENTINEL_DIR/m029-p03-render-live.$$.out"
set +e
bash "$PROJECT_ROOT/scripts/diagnostics/render-position.sh" --live --milestone M029 > "$LIVE_OUT" 2>&1 &
RP_PID=$!
sleep 1.5
kill "$RP_PID" 2>/dev/null || true
wait "$RP_PID" 2>/dev/null || true
set -e
ok "render-position.sh --live --milestone M029 completed timed-kill cycle"
rm -f "$LIVE_OUT"
_check_no_writes "after render-position --live invocation"

# --- Surface 2: render-position at-rest --------------------------------------
RENDER_OUT="$SENTINEL_DIR/m029-p03-render.$$.out"
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
_check_no_writes "after render-position at-rest invocation"

# --- Surface 3: summarize-milestone (AD-4 oracle wrapper input) -------------
SUMMARIZE_OUT="$SENTINEL_DIR/m029-p03-summarize.$$.out"
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

printf 'SUMMARY: m029-p03-readonly-invariant.sh pass=%d fail=%d\n' "$pass" "$fail"
printf 'note: project-tree variant of P03 readonly contract; fixture-tree variants are inside tests/m029-acceptance/p03-sc*.sh\n'
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
