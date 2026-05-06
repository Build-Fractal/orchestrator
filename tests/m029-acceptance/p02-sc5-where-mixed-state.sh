#!/usr/bin/env bash
# tests/m029-acceptance/p02-sc5-where-mixed-state.sh
#
# M029 P02 / SC-5 acceptance script.
#
# Renders scripts/diagnostics/render-position.sh against the SC-5
# mixed-state fixture, normalizes the output through
# tests/m029-acceptance/timestamp-strip.sh (#Q-G6), and diffs against
# the byte-stable golden at
# tests/m029-acceptance/fixtures/where-mixed-state.golden.
#
# All four glyph states (✓ ▶ ◇ ✗) are present in the fixture and the
# golden:
#   ✓ — P01 phase (has P01-SUMMARY.md), T01 task in P02
#   ▶ — P02 phase (PLAN, no SUMMARY); T02/T03/T04 in P02
#   ✗ — P03 phase (verify_result fail in execution-log.jsonl)
#   ◇ — P04 phase (empty directory)
#
# Spec references: FR-5, FR-13, SC-5, AD-6, #Q-G6, #Q-G8, MEM004
# carve-out (sed pipes inside script bodies are permitted).
#
# Bash 3.2 compatible. AD-19: this script is the IMPLEMENTATION; the
# Check: line that invokes it from the harness is single-script-file
# straight-line bash. The pipe through timestamp-strip.sh inside the
# script body is the legitimate transformation pipe permitted by MEM004.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$PROJECT_ROOT/tests/m029-acceptance/fixtures/where-mixed-state.fixture/.orchestrator"
GOLDEN="$PROJECT_ROOT/tests/m029-acceptance/fixtures/where-mixed-state.golden"
RENDERER="$PROJECT_ROOT/scripts/diagnostics/render-position.sh"
STRIP="$PROJECT_ROOT/tests/m029-acceptance/timestamp-strip.sh"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

TMP="${TMPDIR:-/tmp}/m029-sc5.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

# Gate: fixture tree exists.
if [ -d "$FIXTURE/milestones/M998" ]; then
    ok "SC-5 mixed-state fixture tree exists"
else
    bad "SC-5 fixture tree missing at $FIXTURE/milestones/M998"
    printf 'SUMMARY: p02-sc5-where-mixed-state.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Gate: golden file exists.
if [ -f "$GOLDEN" ]; then
    ok "SC-5 golden file exists"
else
    bad "SC-5 golden missing at $GOLDEN"
    printf 'SUMMARY: p02-sc5-where-mixed-state.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Gate: timestamp-strip.sh exists and is executable.
if [ -x "$STRIP" ]; then
    ok "timestamp-strip.sh exists and is executable"
else
    bad "timestamp-strip.sh missing or not executable at $STRIP"
    printf 'SUMMARY: p02-sc5-where-mixed-state.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Render. ORCHESTRATOR_ROOT is exported so metrics-rollup.sh (invoked
# transitively by render-position.sh) reads from the fixture tree, not
# from the project's live .orchestrator/.
RAW="$TMP/actual.raw"
NORMALIZED="$TMP/actual.normalized"
ORCHESTRATOR_ROOT="$FIXTURE" bash "$RENDERER" --milestone M998 --root "$FIXTURE" >"$RAW" 2>/dev/null

# Normalize through timestamp-strip.sh (MEM004 carve-out -- pipes
# inside script bodies are permitted; the AD-19 constraint applies to
# the Check: line at the task-plan level).
bash "$STRIP" <"$RAW" >"$NORMALIZED"

# Sanity-check the normalized output carries all four glyph states (so
# a fixture mutation that drops one glyph fails this assertion before
# the diff step).
glyph_failures=0
for g in '✓' '▶' '◇' '✗'; do
    if grep -q -- "$g" "$NORMALIZED"; then
        ok "normalized output contains glyph $g"
    else
        bad "normalized output missing glyph $g"
        glyph_failures=$(( glyph_failures + 1 ))
    fi
done

# Diff against golden.
if diff -u "$GOLDEN" "$NORMALIZED" >"$TMP/diff.out" 2>&1; then
    ok "SC-5 byte-identity"
else
    bad "SC-5 byte-identity"
    printf '----- diff (golden vs normalized actual) -----\n'
    cat "$TMP/diff.out"
    printf '----- end diff -----\n'
fi

printf 'SUMMARY: p02-sc5-where-mixed-state.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
