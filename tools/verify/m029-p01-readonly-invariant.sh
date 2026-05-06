#!/usr/bin/env bash
# tools/verify/m029-p01-readonly-invariant.sh -- M029 P01 read-only invariant verifier.
#
# Asserts that every P01 surface (the AD-1 invocation-context resolver, the
# FR-3 JSON renderer, plus the read-pattern that commands/context.md and
# commands/status.md drive) is read-only against an orchestrator state tree.
# Implements the CON-1 / FR-14 read-only invariant.
#
# Mechanism: copy the SC-2 fixture into a tmpdir, place a sentinel file
# inside the .orchestrator/ tree with a known mtime, run each P01 surface
# against the fixture, then assert that NO file under .orchestrator/ has an
# mtime newer than the sentinel (excluding the sentinel itself).
#
# Note: this is the P01 PRECURSOR to the AD-9 / SC-14 production read-only
# mechanism (full SC-14 lands in P02 alongside the where-renderer surfaces).
# The precursor exercises the read-only invariant for the four surfaces
# shipped in P01; P02 extends the mechanism to the where renderer + position
# summary + the milestone-summary path.
#
# Bash 3.2 compatible -- no associative arrays, no process substitution.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FIXTURE_SRC="$PROJECT_ROOT/tests/m029-acceptance/fixtures/status-headline-executing.fixture"

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

if [ ! -d "$FIXTURE_SRC" ]; then
    bad "SC-2 fixture missing at $FIXTURE_SRC"
    printf 'SUMMARY: m029-p01-readonly-invariant.sh pass=%d fail=%d\n' "$pass" "$fail"
    printf 'note: P01 precursor to AD-9 / SC-14; full mechanism lands in P02\n'
    exit 1
fi

TMPDIR_LOCAL="$(mktemp -d -t m029-p01-readonly-XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

# Build the fixture root: copy the fixture into <tmpdir>/orch-root/.orchestrator/
# so the on-disk shape is .orchestrator/milestones/M999/... matching the
# orchestrator-root convention consumed by render-status-json.sh.
ORCH_ROOT_PARENT="$TMPDIR_LOCAL/orch-root"
ORCH_ROOT="$ORCH_ROOT_PARENT/.orchestrator"
mkdir -p "$ORCH_ROOT"

# Copy fixture contents (milestones/ tree) into the staged .orchestrator/ root.
cp -R "$FIXTURE_SRC/milestones" "$ORCH_ROOT/milestones"

SENTINEL="$ORCH_ROOT/.m029-p01-sentinel"
printf 'sentinel created %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$SENTINEL"

# Sleep 1 second to ensure any subsequent mtime would be strictly newer than
# the sentinel (filesystem mtime resolution is whole seconds on some FSes).
sleep 1

# Helper -- detect any file under .orchestrator/ newer than the sentinel
# (excluding the sentinel itself).
_check_no_writes() {
    label="$1"
    violations="$TMPDIR_LOCAL/violations-$RANDOM.out"
    find "$ORCH_ROOT" -type f -newer "$SENTINEL" -not -name '.m029-p01-sentinel' >"$violations" 2>/dev/null || true
    if [ -s "$violations" ]; then
        bad "$label: write detected under .orchestrator/"
        sed 's/^/   | /' "$violations" >&2
    else
        ok "$label: no writes under .orchestrator/"
    fi
    rm -f "$violations"
}

# Surface 1: invocation-context resolver (production callers omit injection
# flags; here we exercise both production-shape and test-injection paths).
set +e
bash "$PROJECT_ROOT/scripts/state/detect-invocation-context.sh" --tty=true --ci=false >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
    ok "resolver --tty=true --ci=false exits 0"
else
    bad "resolver --tty=true --ci=false exited rc=$rc"
fi
_check_no_writes "after resolver invocation"

# Surface 2: JSON renderer (FR-3) -- read-only over the orchestrator root.
set +e
bash "$PROJECT_ROOT/scripts/diagnostics/render-status-json.sh" --orchestrator-root "$ORCH_ROOT" >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
    ok "render-status-json.sh --orchestrator-root exits 0"
else
    bad "render-status-json.sh exited rc=$rc"
fi
_check_no_writes "after render-status-json invocation"

# Surface 3: commands/context.md skill read-pattern. The skill itself is a
# Markdown command document driven by Claude Code; the underlying read
# pattern it drives is resolve-root + find-active-milestone + the resolver.
# Approximate that read pattern here without invoking the harness.
set +e
ORCHESTRATOR_ROOT="$ORCH_ROOT" bash "$PROJECT_ROOT/scripts/state/resolve-root.sh" >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
    ok "resolve-root.sh exits 0 against fixture"
else
    bad "resolve-root.sh exited rc=$rc"
fi
_check_no_writes "after resolve-root invocation"

set +e
bash "$PROJECT_ROOT/scripts/state/find-active-milestone.sh" "$ORCH_ROOT" >/dev/null 2>&1
rc=$?
set -e
# find-active-milestone.sh may legitimately exit non-zero when no active
# milestone is found; the read-only invariant is what matters here.
if [ "$rc" -le 1 ]; then
    ok "find-active-milestone.sh runs against fixture (rc=$rc)"
else
    bad "find-active-milestone.sh exited unexpectedly rc=$rc"
fi
_check_no_writes "after find-active-milestone invocation"

# Surface 4: commands/status.md headline read-pattern. The headline is built
# from derive-phase + read-roadmap + recency-from-execution-log. Approximate.
MILESTONE_DIR="$ORCH_ROOT/milestones/M999"
if [ -d "$MILESTONE_DIR" ]; then
    set +e
    bash "$PROJECT_ROOT/scripts/state/derive-phase.sh" "$MILESTONE_DIR" >/dev/null 2>&1
    rc=$?
    set -e
    if [ "$rc" -le 1 ]; then
        ok "derive-phase.sh runs against fixture milestone (rc=$rc)"
    else
        bad "derive-phase.sh exited unexpectedly rc=$rc"
    fi
    _check_no_writes "after derive-phase invocation"

    ROADMAP="$MILESTONE_DIR/M999-ROADMAP.md"
    if [ -f "$ROADMAP" ]; then
        set +e
        bash "$PROJECT_ROOT/scripts/state/read-roadmap.sh" "$ROADMAP" list-phases >/dev/null 2>&1
        rc=$?
        set -e
        if [ "$rc" -le 1 ]; then
            ok "read-roadmap.sh runs against fixture roadmap (rc=$rc)"
        else
            bad "read-roadmap.sh exited unexpectedly rc=$rc"
        fi
        _check_no_writes "after read-roadmap invocation"
    fi
fi

printf 'SUMMARY: m029-p01-readonly-invariant.sh pass=%d fail=%d\n' "$pass" "$fail"
printf 'note: P01 precursor to AD-9 / SC-14; full mechanism lands in P02\n'
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
