#!/usr/bin/env bash
# scripts/verify/m025-p01-recent-changes.sh -- M025/P01/T03 gate (will fail
# until T04 re-runs dual-write with the P01-completion fragment):
# asserts CLAUDE.md and AGENTS.md Recent Changes regions contain a
# dual-write fragment naming M025/P01 or the 021-github-installer-coexistence
# spec.
#
# The regions are delimited by '# >>> orchestrator:recent-changes >>>' and
# '# <<< orchestrator:recent-changes <<<' markers; this gate extracts the
# region body between those markers and greps for the M025/P01 or
# 021-github-installer-coexistence token.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Dual-write verifier.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

check_region() {
  rel="$1"
  path="${REPO_ROOT}/${rel}"
  if [ ! -f "$path" ]; then
    fail "${rel} missing"
    return
  fi
  # Extract region body via awk (bash 3.2 safe, no proc-subst).
  region="$(awk '
    /^# >>> orchestrator:recent-changes >>>/ { inside=1; next }
    /^# <<< orchestrator:recent-changes <<</  { inside=0; next }
    inside { print }
  ' "$path")"
  if [ -z "$region" ]; then
    fail "${rel}: Recent Changes region empty or markers missing"
    return
  fi
  if echo "$region" | grep -nE 'M025/P01|021-github-installer-coexistence' >/dev/null 2>&1; then
    pass "${rel}: Recent Changes region contains M025/P01 or 021-github-installer-coexistence fragment"
  else
    fail "${rel}: Recent Changes region missing M025/P01 or 021-github-installer-coexistence fragment"
  fi
}

check_region "CLAUDE.md"
check_region "AGENTS.md"

echo "SUMMARY: m025-p01-recent-changes.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m025-p01-recent-changes.sh"
  exit 0
fi
echo "FAIL: m025-p01-recent-changes.sh" >&2
exit 1
