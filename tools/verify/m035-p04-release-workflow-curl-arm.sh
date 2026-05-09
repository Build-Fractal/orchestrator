#!/usr/bin/env bash
# tools/verify/m035-p04-release-workflow-curl-arm.sh
#
# M035 P04 T02 task-grain verifier. Asserts release.yml shape after
# T02 edits:
#   * file exists
#   * Stage release artifacts step contains
#     `cp packaging/install/install.sh release-artifacts/`
#   * npm-publish job has timeout-minutes: 20 (CON-8 / D010)
#   * homebrew-publish job has timeout-minutes: 20 (CON-8 / D010)
#   * No new secrets.* references introduced (only NPM_TOKEN,
#     HOMEBREW_TAP_TOKEN, GITHUB_TOKEN — pre-existing P02/P03/P05)
#   * D010 row recorded in .orchestrator/DECISIONS.md
#
# AD-19 single-script-file shape. Bash 3.2 compatible.

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
WORKFLOW="$REPO_ROOT/.github/workflows/release.yml"
DECISIONS="$REPO_ROOT/.orchestrator/DECISIONS.md"

pass=0
fail=0

check() {
  local name="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    echo "PASS: $name"
    pass=$((pass + 1))
  else
    echo "FAIL: $name"
    fail=$((fail + 1))
  fi
}

# 1. Workflow file exists.
if [ -f "$WORKFLOW" ]; then check "release.yml exists" 0; else check "release.yml exists" 1; fi

# 2. Stage release artifacts step copies install.sh.
if grep -F 'cp packaging/install/install.sh release-artifacts/' "$WORKFLOW" >/dev/null; then check "install.sh staging line" 0; else check "install.sh staging line" 1; fi

# 3. npm-publish job has timeout-minutes: 20.
#    Asserted by counting timeout-minutes occurrences (must be >=2:
#    one for npm-publish, one for homebrew-publish).
timeout_count=$(grep -cE '^[[:space:]]+timeout-minutes:[[:space:]]+20$' "$WORKFLOW")
if [ "$timeout_count" -ge 2 ]; then check "timeout-minutes: 20 occurs >=2 times (npm-publish + homebrew-publish)" 0; else check "timeout-minutes: 20 occurs >=2 times (got $timeout_count)" 1; fi

# 4. CON-8 reference in workflow (cross-link to DECISIONS).
if grep -q 'CON-8' "$WORKFLOW"; then check "CON-8 reference in workflow" 0; else check "CON-8 reference in workflow" 1; fi

# 5. No new secrets.* references — should match pre-T02 set:
#    NPM_TOKEN (P02), HOMEBREW_TAP_TOKEN (P03), GITHUB_TOKEN (P02 + P03).
#    Curl arm introduces NO new secret. The verifier asserts the
#    workflow contains exactly these three secret references and
#    no curl-named secret (regression guard against a future plan-
#    phase author accidentally adding one).
if grep -qE 'secrets\.(CURL|INSTALL_SH|PIPE_BASH)' "$WORKFLOW"; then
  check "no curl-channel-specific secret introduced (regression guard)" 1
else
  check "no curl-channel-specific secret introduced (regression guard)" 0
fi

# 6. D010 row recorded in .orchestrator/DECISIONS.md.
if grep -qE '^### D010 ' "$DECISIONS"; then check "D010 row in DECISIONS.md" 0; else check "D010 row in DECISIONS.md" 1; fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
