#!/usr/bin/env bash
# tools/verify/m035-p015-sc7.sh -- SC-7 cohort grep-zero-match assertion.
#
# Asserts the M035 spec SC-7 invariant: zero residual matches of
# 'speckit.orchestrator.<lowercase>' tokens in the operational subtrees,
# minus the historical/migration paths enumerated in the
# legacy-namespace allowlist authored by T01.
#
# Single-script-file shape per AD-19. No compound chains (CON-3 / AP-009).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

ALLOWLIST="$REPO_ROOT/tests/m035-acceptance/legacy-namespace-allowlist.txt"
if [ ! -f "$ALLOWLIST" ]; then
  echo "FAIL: SC-7 allowlist file missing at $ALLOWLIST" >&2
  exit 1
fi

# The SC-7 grep is restricted to the operational subtrees per the
# spec (commands/ scripts/ templates/ references/ docs/).
residue=$(grep -rE 'speckit\.orchestrator\.[a-z]' \
  commands/ scripts/ templates/ references/ docs/ 2>/dev/null \
  | grep -v -F -f "$ALLOWLIST" || true)

if [ -n "$residue" ]; then
  echo "FAIL: SC-7 residual speckit.orchestrator.* matches:" >&2
  echo "$residue" >&2
  exit 1
fi

echo "PASS: m035-p015-sc7"
exit 0
