#!/usr/bin/env bash
# tools/verify/m035-p06-milestone-close-shape.sh
# M035 P06 — milestone-close-shape verifier.
# Asserts the milestone-close artifacts are present and well-shaped:
#   - M035-VALIDATED marker exists with valid ISO 8601 UTC timestamp
#   - M035-SUMMARY.md exists and carries the required headings
#   - validate-milestone.sh M035 reports PASS (SC-16 oracle assertion)
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.
# Emits BATTERY: pass=9 fail=0 when all assertions hold.
set -u

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
cd "$REPO_ROOT"

MARKER=".orchestrator/milestones/M035/M035-VALIDATED"
SUMMARY=".orchestrator/milestones/M035/M035-SUMMARY.md"
VALIDATE="scripts/verify/validate-milestone.sh"

pass=0
fail=0

say_pass() { echo "PASS: $1"; pass=$((pass + 1)); }
say_fail() { echo "FAIL: $1" >&2; fail=$((fail + 1)); }

# 1. Marker exists.
if [ -f "$MARKER" ]; then
    say_pass "M035-VALIDATED marker exists"
else
    say_fail "M035-VALIDATED marker missing at $MARKER"
fi

# 2. Marker non-empty AND carries ISO 8601 UTC timestamp.
if [ -s "$MARKER" ] && grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' "$MARKER"; then
    say_pass "M035-VALIDATED carries valid ISO 8601 UTC timestamp"
else
    say_fail "M035-VALIDATED missing or lacks ISO 8601 UTC timestamp"
fi

# 3. Summary exists.
if [ -f "$SUMMARY" ]; then
    say_pass "M035-SUMMARY.md exists"
else
    say_fail "M035-SUMMARY.md missing at $SUMMARY"
fi

# 4. Summary contains H1 — uses the canonical milestone heading.
if [ -f "$SUMMARY" ] && grep -qF -- '# M035 — packaging & distribution' "$SUMMARY"; then
    say_pass "M035-SUMMARY.md contains H1 # M035 — packaging & distribution"
else
    say_fail "M035-SUMMARY.md missing canonical H1 # M035 — packaging & distribution"
fi

# 5. Summary contains H2 ## What was built.
if [ -f "$SUMMARY" ] && grep -qF -- '## What was built' "$SUMMARY"; then
    say_pass "M035-SUMMARY.md contains ## What was built"
else
    say_fail "M035-SUMMARY.md missing ## What was built"
fi

# 6. Summary contains H2 ## Verification.
if [ -f "$SUMMARY" ] && grep -qF -- '## Verification' "$SUMMARY"; then
    say_pass "M035-SUMMARY.md contains ## Verification"
else
    say_fail "M035-SUMMARY.md missing ## Verification"
fi

# 7. Summary references the acceptance battery (SC-15 evidence pointer).
if [ -f "$SUMMARY" ] && grep -qF -- 'tests/m035-acceptance/run-acceptance-battery.sh' "$SUMMARY"; then
    say_pass "M035-SUMMARY.md references tests/m035-acceptance/run-acceptance-battery.sh"
else
    say_fail "M035-SUMMARY.md missing acceptance-battery path reference"
fi

# 8. Summary cites a BATTERY: rollup line (operator can find evidence).
if [ -f "$SUMMARY" ] && grep -qE '^- .*BATTERY:|`BATTERY:|BATTERY: pass=' "$SUMMARY"; then
    say_pass "M035-SUMMARY.md cites BATTERY rollup"
else
    say_fail "M035-SUMMARY.md missing BATTERY: rollup citation"
fi

# 9. validate-milestone.sh reports PASS for M035 (SC-16 oracle).
if [ -x "$VALIDATE" ] || [ -f "$VALIDATE" ]; then
    vlog="$(mktemp -t m035-p06-validate.XXXXXX)"
    bash "$VALIDATE" .orchestrator/milestones/M035 >"$vlog" 2>&1
    vrc=$?
    vline="$(grep -E '^VALIDATE: (PASS|FAIL)' "$vlog" | tail -1)"
    if [ "$vrc" -eq 0 ] && echo "$vline" | grep -qE '^VALIDATE: PASS'; then
        say_pass "validate-milestone.sh M035 reports PASS ($vline)"
    else
        say_fail "validate-milestone.sh M035 rc=$vrc; tail=$(tail -3 "$vlog" | tr '\n' ' ')"
    fi
    rm -f "$vlog" 2>/dev/null || true
else
    say_fail "validate-milestone.sh not found at $VALIDATE"
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
