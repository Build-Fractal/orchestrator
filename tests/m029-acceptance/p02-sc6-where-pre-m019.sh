#!/usr/bin/env bash
# tests/m029-acceptance/p02-sc6-where-pre-m019.sh
#
# M029 P02 / SC-6 acceptance script.
#
# Renders scripts/diagnostics/render-position.sh against the SC-6
# pre-M019 fixture (a milestone with NO execution-log.jsonl), and
# asserts:
#   1. The cost-column delimiter (`$` USD prefix or literal `cost=`
#      token) does NOT appear in stdout (FR-6 silent suppression).
#   2. Stderr is byte-empty (CON-3 silent suppression — no warnings,
#      no advisory text on the pre-M019 path).
#
# Spec references: FR-6, CON-3, SC-6.
#
# Bash 3.2 compatible. AD-19: this script is the IMPLEMENTATION; the
# Check: line that invokes it is single-script-file straight-line bash.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$PROJECT_ROOT/tests/m029-acceptance/fixtures/where-pre-m019.fixture/.orchestrator"
RENDERER="$PROJECT_ROOT/scripts/diagnostics/render-position.sh"

pass=0
fail=0

ok() { printf 'PASS: %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$(( fail + 1 )); }

TMP="${TMPDIR:-/tmp}/m029-sc6.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

# Gate: fixture tree exists.
if [ -d "$FIXTURE/milestones/M997" ]; then
    ok "SC-6 pre-M019 fixture tree exists"
else
    bad "SC-6 fixture tree missing at $FIXTURE/milestones/M997"
    printf 'SUMMARY: p02-sc6-where-pre-m019.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Gate: fixture has NO execution-log.jsonl (the pre-M019 marker).
if [ ! -f "$FIXTURE/milestones/M997/execution-log.jsonl" ]; then
    ok "SC-6 fixture lacks execution-log.jsonl (pre-M019 marker)"
else
    bad "SC-6 fixture unexpectedly contains execution-log.jsonl"
fi

# Render with both stdout and stderr captured to separate tempfiles.
STDOUT_FILE="$TMP/stdout"
STDERR_FILE="$TMP/stderr"
ORCHESTRATOR_ROOT="$FIXTURE" bash "$RENDERER" --milestone M997 --root "$FIXTURE" >"$STDOUT_FILE" 2>"$STDERR_FILE"

# Assert the cost-column delimiter does NOT appear in stdout. The
# renderer emits `  $<NUMBER>` for cost cells (see _rp_cost_column);
# the pre-M019 path returns the empty string and the column is
# silently omitted.
if grep -q -- '\$[0-9]' "$STDOUT_FILE"; then
    bad "SC-6 cost column unexpectedly present in stdout"
    printf '----- stdout -----\n'
    cat "$STDOUT_FILE"
    printf '----- end stdout -----\n'
else
    ok "SC-6 cost column suppressed (no \$<num> tokens in stdout)"
fi
if grep -q -- 'cost=' "$STDOUT_FILE"; then
    bad "SC-6 unexpected literal 'cost=' token in stdout"
else
    ok "SC-6 no literal 'cost=' token in stdout"
fi

# Assert stderr is byte-empty.
if [ ! -s "$STDERR_FILE" ]; then
    ok "SC-6 stderr empty (CON-3 silent suppression)"
else
    bad "SC-6 stderr non-empty (CON-3 violation)"
    printf '----- stderr -----\n'
    cat "$STDERR_FILE"
    printf '----- end stderr -----\n'
fi

printf 'SUMMARY: p02-sc6-where-pre-m019.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
