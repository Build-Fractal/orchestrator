#!/usr/bin/env bash
# Verifies the hardcoded stage x intensity matrix returns expected values
# for the critical corner cases.
set -u

f="scripts/engine/intensity-gate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# discuss Quick -> skip all
out="$(bash "$f" --stage discuss --intensity Quick 2>/dev/null)"
echo "$out" | grep -q '^skip_substeps=all' || { echo "FAIL: discuss Quick should skip=all"; exit 1; }

# discuss Full -> execute required
out="$(bash "$f" --stage discuss --intensity Full 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=required' || { echo "FAIL: discuss Full should execute=required"; exit 1; }

# verify Quick -> tier1 only
out="$(bash "$f" --stage verify --intensity Quick 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=tier1$' || { echo "FAIL: verify Quick should execute=tier1"; exit 1; }

# verify Full -> all four tiers
out="$(bash "$f" --stage verify --intensity Full 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=tier1,tier2,tier3,tier4' || { echo "FAIL: verify Full should execute all four tiers"; exit 1; }

# knowledge Quick -> summary only
out="$(bash "$f" --stage knowledge --intensity Quick 2>/dev/null)"
echo "$out" | grep -q '^execute_substeps=summary$' || { echo "FAIL: knowledge Quick should execute=summary"; exit 1; }

# knowledge Full -> full pipeline
out="$(bash "$f" --stage knowledge --intensity Full 2>/dev/null)"
echo "$out" | grep -q 'rebuild-index' || { echo "FAIL: knowledge Full should include rebuild-index"; exit 1; }

# auto Full -> human-review present
out="$(bash "$f" --stage auto --intensity Full 2>/dev/null)"
echo "$out" | grep -q 'human-review' || { echo "FAIL: auto Full should include human-review"; exit 1; }

echo "PASS: intensity matrix yields expected values for all documented corner cases"
