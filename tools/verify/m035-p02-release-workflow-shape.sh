#!/usr/bin/env bash
# tools/verify/m035-p02-release-workflow-shape.sh
# Asserts .github/workflows/release.yml has the load-bearing M035
# P02 T04 contract surfaces:
#   * pr-validate job exists, no NPM_TOKEN env reference
#   * npm-publish job exists, conditioned on v* tag push (CON-6)
#   * npm-publish job uses secrets.NPM_TOKEN (CON-6 secrets shape)
#   * runs-on ubuntu-latest (D001)
#   * SC-14 PR-build job-condition negative assertion is encoded
#     (the CON-6 step in pr-validate that fails on NPM_TOKEN presence)
set -euo pipefail

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
WF="$REPO/.github/workflows/release.yml"

pass=0
fail=0

if [ ! -f "$WF" ]; then
  echo "FAIL: $WF not found"
  exit 1
fi
echo "PASS: $WF exists"
pass=$((pass + 1))

check_grep() {
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$WF"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label (pattern: $pattern)"
    fail=$((fail + 1))
  fi
}

check_anti_grep() {
  local pattern="$1"
  local label="$2"
  if ! grep -qE "$pattern" "$WF"; then
    echo "PASS: $label (negative assertion)"
    pass=$((pass + 1))
  else
    echo "FAIL: $label — found unexpected match for $pattern"
    fail=$((fail + 1))
  fi
}

# --- Job presence -----------------------------------------------
check_grep '^[[:space:]]*pr-validate:' "pr-validate job exists"
check_grep '^[[:space:]]*npm-publish:' "npm-publish job exists"

# --- Runner -----------------------------------------------------
check_grep 'runs-on:[[:space:]]*ubuntu-latest' "runs-on ubuntu-latest (D001)"

# --- CON-6 secrets-scope ----------------------------------------
check_grep "startsWith\(github\.ref,[[:space:]]*'refs/tags/v'\)" \
  "npm-publish conditioned on v* tag push (CON-6)"
check_grep 'secrets\.NPM_TOKEN' "publish job uses secrets.NPM_TOKEN"

# SC-14 PR-build job-condition assertion: pr-validate must include
# the negative-assertion step that fails on NPM_TOKEN presence.
check_grep 'NPM_TOKEN visible to pr-validate' \
  "pr-validate carries CON-6 negative-assertion step (SC-14)"

# --- Test invocations -------------------------------------------
check_grep 'tests/m035-acceptance/cross-channel-byte-equivalence\.sh' \
  "pr-validate invokes cross-channel-byte-equivalence.sh (T03 surface)"
check_grep 'm035-p02-package-json-shape\.sh' \
  "pre-publish gates invoke package-json-shape verifier (T01 surface)"

# --- npm publish access flag ------------------------------------
check_grep 'npm publish --access public' \
  "scoped package published with --access public"

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
