#!/usr/bin/env bash
# tools/verify/m034-p00-addendum.sh — M034 P00 phase verifier (project-owned).
#
# Asserts the P00 pre-planning addendum + representative fixture are complete:
#   - addendum exists with the PC-1 / PC-2 / #Q-1 section markers
#   - PC-2 names the real backend (local-agent.sh) and the RISK-5 decision
#   - PC-1 committed the stdin wire format; #Q-1 committed supersede semantics
#   - fixture exists, >=30 lines, carries alternatives_considered + boundary_translation
#
# AD-19-clean: sequential simple grep -q / test guards, early `exit 1`, no
# compound chains, no $(...)-with-pipe. Runs under auto-loop --step=V.
# Bash 3.2 compatible. Prints PASS + exit 0 on success, FAIL + exit 1 on any miss.

set -u

ADDENDUM=".orchestrator/milestones/M034/M034-P00-ADDENDUM.md"
FIXTURE=".orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md"

fail() {
  echo "FAIL: $1"
  exit 1
}

# --- Addendum existence + section markers (PC-1 / PC-2 / #Q-1) ---
test -f "$ADDENDUM" || fail "addendum missing: $ADDENDUM"
grep -qF "## PC-1" "$ADDENDUM" || fail "addendum missing '## PC-1' section"
grep -qF "## PC-2" "$ADDENDUM" || fail "addendum missing '## PC-2' section"
grep -qF "## #Q-1" "$ADDENDUM" || fail "addendum missing '## #Q-1' section"

# --- PC-2 evidence: real backend inspected + RISK-5 decision recorded ---
grep -qF "local-agent.sh" "$ADDENDUM" || fail "PC-2 must name the real backend local-agent.sh"
grep -qF "RISK-5" "$ADDENDUM" || fail "PC-2 must record the RISK-5 escalation decision"

# --- PC-1 wire format committed + #Q-1 supersede decided ---
grep -qF "stdin" "$ADDENDUM" || fail "PC-1 must commit the stdin wire format"
grep -qF "supersede" "$ADDENDUM" || fail "#Q-1 must record the supersede decision"

# --- Fixture existence + size + required field coverage ---
test -f "$FIXTURE" || fail "fixture missing: $FIXTURE"
FIXTURE_LINES=$(wc -l < "$FIXTURE")
test "$FIXTURE_LINES" -ge 30 || fail "fixture has <30 lines ($FIXTURE_LINES)"
grep -qF "alternatives_considered" "$FIXTURE" || fail "fixture missing alternatives_considered field"
grep -qF "boundary_translation" "$FIXTURE" || fail "fixture missing a boundary_translation entry"

echo "PASS: M034 P00 addendum complete"
exit 0
