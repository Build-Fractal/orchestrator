#!/usr/bin/env bash
# tests/m029-acceptance/sentinel-harness.sh
# M029 / AD-9 sentinel-file harness for SC-14 read-only enforcement.
#
# Usage: bash sentinel-harness.sh <command> [args...]
#
# Mechanism (AD-9 — see .orchestrator/milestones/M029/M029-CONTEXT.md AD-9):
#   1. Write .orchestrator/.m029-sc14-sentinel with the current ISO-8601
#      UTC timestamp.
#   2. Capture the sentinel's mtime via `stat`.
#   3. Run the wrapped command (forwarded as "$@").
#   4. Scan .orchestrator/ for any file whose mtime is newer than the
#      sentinel's, EXCLUDING the sentinel itself AND
#      .orchestrator/start-state/*.complete (the only documented write-
#      site exception per AD-9 / FR-10).
#   5. PASS iff no offenders; FAIL with one line per offender otherwise.
#
# Output (stdout):
#   - PASS: read-only invariant held
#   - SUMMARY: sentinel-harness.sh pass=N fail=M
#   On violation: one `FAIL: read-only invariant violated by <path>` line
#   per offender + final SUMMARY.
#
# Exit codes:
#   0 — read-only invariant held; if the wrapped command exited non-zero
#       the harness propagates that exit code (for visibility into both
#       the command failure AND the read-only invariant simultaneously).
#   1 — read-only invariant violated.
#   2 — usage error (missing args, ORCHESTRATOR_ROOT missing).
#
# Bash 3.2 / MEM001 compatible. AD-19: straight-line bash. No process
# substitution, no <<< herestrings. `find -newer` is the AD-9 mechanism
# choice precisely because it is a single-command (no pipe chain) probe.
#
# Spec references: M029 / AD-9 / FR-10 / SC-14 / CON-1 / FR-14.

set -u

if [ $# -lt 1 ]; then
    printf 'Usage: sentinel-harness.sh <command> [args...]\n' >&2
    exit 2
fi

ORCH_ROOT="${ORCHESTRATOR_ROOT:-.orchestrator}"
if [ ! -d "$ORCH_ROOT" ]; then
    printf 'sentinel-harness.sh: %s does not exist\n' "$ORCH_ROOT" >&2
    exit 2
fi

SENTINEL="$ORCH_ROOT/.m029-sc14-sentinel"
date -u +%Y-%m-%dT%H:%M:%SZ > "$SENTINEL"

# Run the wrapped command. Forward exit code on failure but always
# proceed to the sentinel scan so the operator sees both the command
# failure AND any read-only violation simultaneously.
"$@"
CMD_RC=$?

# `find -newer` is AD-19 safe (single command, no pipe chain, no $()).
# Use a tempfile under $TMPDIR to capture output (run-probe.sh scope
# rule 4 — staged-probe domain).
TMP_OUT="${TMPDIR:-/tmp}/m029-sentinel-scan.$$"
find "$ORCH_ROOT" -type f -newer "$SENTINEL" \
    ! -path "$SENTINEL" \
    ! -path "$ORCH_ROOT/start-state/*.complete" \
    > "$TMP_OUT" 2>/dev/null

fail=0
while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf 'FAIL: read-only invariant violated by %s\n' "$line"
    fail=$(( fail + 1 ))
done < "$TMP_OUT"
rm -f "$TMP_OUT"

if [ "$fail" -eq 0 ]; then
    printf 'PASS: read-only invariant held\n'
    printf 'SUMMARY: sentinel-harness.sh pass=1 fail=0\n'
    exit "$CMD_RC"
fi

printf 'SUMMARY: sentinel-harness.sh pass=0 fail=%d\n' "$fail"
exit 1
