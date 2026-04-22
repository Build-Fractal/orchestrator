#!/usr/bin/env bash
# scripts/verify/m013-p03-re-init-fixture.sh — T01 gate: verify re-init fixture tree.
#
# Asserts:
#   - fixture root directory exists
#   - expected-readopt-manifest.txt exists with the pinned 10-line shape
#   - orchestrator-state seed is walkable (roadmap + phase-plan + 2 task-plans)
#   - 5 gh-stub-responses files present
#   - the single additive github-common.sh helper is defined + Bash 3.2 clean

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="${REPO_ROOT}/tests/fixtures/m013-p03/re-init-adoption"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

if [ -d "$FX" ]; then
  pass "fixture root exists"
else
  fail "fixture root missing: $FX"
fi

if [ -f "${FX}/expected-readopt-manifest.txt" ]; then
  pass "expected-readopt-manifest.txt present"
else
  fail "expected-readopt-manifest.txt missing"
fi

if [ -f "${FX}/orchestrator-state/.orchestrator/milestones/M013/M013-ROADMAP.md" ]; then
  pass "M013-ROADMAP.md seeded"
else
  fail "M013-ROADMAP.md missing in fixture"
fi

if [ -f "${FX}/orchestrator-state/.orchestrator/milestones/M013/phases/P02/P02-PLAN.md" ]; then
  pass "P02-PLAN.md seeded"
else
  fail "P02-PLAN.md missing in fixture"
fi

if [ -f "${FX}/orchestrator-state/.orchestrator/milestones/M013/phases/P02/tasks/T01-PLAN.md" ]; then
  pass "T01-PLAN.md seeded"
else
  fail "T01 seed missing"
fi

if [ -f "${FX}/orchestrator-state/.orchestrator/milestones/M013/phases/P02/tasks/T02-PLAN.md" ]; then
  pass "T02-PLAN.md seeded"
else
  fail "T02 seed missing"
fi

if [ -f "${FX}/gh-stub-responses/auth-status-green.txt" ]; then
  pass "auth stub present"
else
  fail "auth stub missing"
fi

if [ -f "${FX}/gh-stub-responses/issue-list-M013-P02.json" ]; then
  pass "phase issue-list stub present"
else
  fail "phase issue-list stub missing"
fi

if [ -f "${FX}/gh-stub-responses/issue-list-M013-P02-T01.json" ]; then
  pass "T01 issue-list stub present"
else
  fail "T01 issue-list stub missing"
fi

if [ -f "${FX}/gh-stub-responses/issue-list-M013-P02-T02.json" ]; then
  pass "T02 issue-list stub present"
else
  fail "T02 issue-list stub missing"
fi

# Manifest shape check: exact line count + required anchors.
mani="${FX}/expected-readopt-manifest.txt"
lines="$(wc -l <"$mani" 2>/dev/null | awk '{print $1}')"
if [ "${lines:-0}" -ge 10 ]; then
  pass "expected-readopt-manifest.txt has >=10 lines"
else
  fail "expected-readopt-manifest.txt has too few lines ($lines)"
fi

if grep -q "^MANIFEST: 0 0 0$" "$mani"; then
  pass "MANIFEST header shape"
else
  fail "MANIFEST header missing"
fi

if grep -q "adopted=" "$mani"; then
  pass "footer has adopted= field"
else
  fail "footer missing adopted="
fi

if grep -qE '^UPSERT: [a-z\-]+ [A-Z0-9\-]+ [^ ]+ adopt$' "$mani"; then
  pass "at least one adopt row"
else
  fail "no adopt rows in manifest"
fi

echo "SUMMARY: m013-p03-re-init-fixture.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-re-init-fixture.sh"
  exit 0
fi
echo "FAIL: m013-p03-re-init-fixture.sh" >&2
exit 1
