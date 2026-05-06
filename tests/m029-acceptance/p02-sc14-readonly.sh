#!/usr/bin/env bash
# tests/m029-acceptance/p02-sc14-readonly.sh
#
# M029 P02 / SC-14 acceptance script.
#
# Wraps tests/m029-acceptance/sentinel-harness.sh around a
# `bash scripts/diagnostics/render-position.sh ...` invocation and
# asserts the AD-9 read-only invariant holds: the renderer must not
# create or modify any file under `.orchestrator/` other than the
# sentinel itself.
#
# The harness's $ORCHESTRATOR_ROOT is pointed at the SC-5 fixture's
# `.orchestrator/` so the scan is over the fixture tree rather than
# the project's live `.orchestrator/`. This avoids false-positive
# collisions with developer state in the project tree (e.g.
# concurrent edits to .orchestrator/proposals/ that have nothing to
# do with the renderer).
#
# Spec references: CON-1, FR-14, AD-9, SC-14.
#
# Bash 3.2 compatible. AD-19: single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARNESS="$PROJECT_ROOT/tests/m029-acceptance/sentinel-harness.sh"
RENDERER="$PROJECT_ROOT/scripts/diagnostics/render-position.sh"
FIXTURE_ORCH="$PROJECT_ROOT/tests/m029-acceptance/fixtures/where-mixed-state.fixture/.orchestrator"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

# Gate: harness exists and is executable.
if [ -x "$HARNESS" ]; then
    ok "sentinel-harness.sh exists and is executable"
else
    bad "sentinel-harness.sh missing or not executable at $HARNESS"
    printf 'SUMMARY: p02-sc14-readonly.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Gate: renderer exists.
if [ -x "$RENDERER" ]; then
    ok "render-position.sh exists and is executable"
else
    bad "render-position.sh missing or not executable at $RENDERER"
    printf 'SUMMARY: p02-sc14-readonly.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Gate: fixture orchestrator-root exists.
if [ -d "$FIXTURE_ORCH" ]; then
    ok "SC-14 fixture orchestrator-root exists"
else
    bad "SC-14 fixture orchestrator-root missing at $FIXTURE_ORCH"
    printf 'SUMMARY: p02-sc14-readonly.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Run the harness around the renderer. ORCHESTRATOR_ROOT scopes the
# sentinel scan to the fixture tree (NOT the project's live
# .orchestrator/, which would surface unrelated developer-side writes).
HARNESS_OUT="${TMPDIR:-/tmp}/m029-sc14-harness.$$"
set +e
ORCHESTRATOR_ROOT="$FIXTURE_ORCH" bash "$HARNESS" \
    bash "$RENDERER" --milestone M998 --root "$FIXTURE_ORCH" \
    >"$HARNESS_OUT" 2>&1
harness_rc=$?
set -e

if [ "$harness_rc" -eq 0 ]; then
    ok "SC-14 read-only invariant (sentinel-harness exits 0)"
else
    bad "SC-14 read-only invariant violated (sentinel-harness exit=$harness_rc)"
    printf '----- harness output -----\n'
    cat "$HARNESS_OUT"
    printf '----- end harness output -----\n'
fi

# Sanity: harness output should carry the literal PASS phrase from
# sentinel-harness.sh.
if grep -q -- 'PASS: read-only invariant held' "$HARNESS_OUT"; then
    ok "SC-14 harness emitted canonical PASS line"
else
    bad "SC-14 harness did not emit canonical PASS line"
fi

# Cleanup the sentinel left in the fixture so subsequent runs see a
# clean tree. The sentinel is the ONLY file the harness writes inside
# $ORCHESTRATOR_ROOT (AD-9 mechanism). Removing it is a CON-1 carve-out
# for the test driver itself, not the renderer.
rm -f "$FIXTURE_ORCH/.m029-sc14-sentinel"
rm -f "$HARNESS_OUT"

printf 'SUMMARY: p02-sc14-readonly.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
