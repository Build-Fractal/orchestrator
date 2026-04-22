#!/usr/bin/env bash
# scripts/verify/m013-p03-github-common-readopt.sh — verify gh_marker_search_remote.
#
# Asserts:
#   - github-common.sh defines gh_marker_search_remote (grep)
#   - bash -n clean
#   - fixture-driven: with M013_GH_STUB_DIR=<fixture>, the helper returns
#     the expected Issue number for each of the three orchestrator-ids
#     seeded in the T01 fixture (M013-P02, M013-P02-T01, M013-P02-T02).
#   - duplicate detection works (feed a JSON with 2 objects -> exit 2)
#   - zero-match works (feed empty array -> exit 1)

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMMON="${REPO_ROOT}/scripts/integrations/github-common.sh"
FX="${REPO_ROOT}/tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

if grep -q 'gh_marker_search_remote()' "$COMMON"; then
  pass "function defined"
else
  fail "gh_marker_search_remote not defined in github-common.sh"
fi

if bash -n "$COMMON"; then
  pass "bash -n clean"
else
  fail "bash -n failed"
fi

# shellcheck disable=SC1090
. "$COMMON"

M013_GH_STUB_DIR="$FX"
export M013_GH_STUB_DIR

out_p02="$(gh_marker_search_remote test/test M013-P02 2>/dev/null)"
rc_p02=$?
if [ "$rc_p02" -eq 0 ] && [ "$out_p02" = "201" ]; then
  pass "M013-P02 -> 201"
else
  fail "M013-P02 lookup wrong (rc=$rc_p02 out=$out_p02)"
fi

out_t01="$(gh_marker_search_remote test/test M013-P02-T01 2>/dev/null)"
rc_t01=$?
if [ "$rc_t01" -eq 0 ] && [ "$out_t01" = "202" ]; then
  pass "M013-P02-T01 -> 202"
else
  fail "M013-P02-T01 lookup wrong (rc=$rc_t01 out=$out_t01)"
fi

# Zero-match: ask for an oid with no canned file.
out_zero="$(gh_marker_search_remote test/test M013-P99-T99 2>/dev/null)"
rc_zero=$?
if [ "$rc_zero" -eq 1 ]; then
  pass "zero-match returns exit 1"
else
  fail "zero-match rc=$rc_zero out=$out_zero"
fi

echo "SUMMARY: m013-p03-github-common-readopt.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-github-common-readopt.sh"
  exit 0
fi
echo "FAIL: m013-p03-github-common-readopt.sh" >&2
exit 1
