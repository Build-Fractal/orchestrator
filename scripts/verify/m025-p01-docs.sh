#!/usr/bin/env bash
# scripts/verify/m025-p01-docs.sh -- M025/P01/T03 gate (will fail until T04
# lands the doc writes):
#   - references/installation.md contains an "Uninstall" heading.
#   - references/hooks.md contains the six-event mapping section, with
#     TODO(M025+) markers for the four deferred events.
#   - CHANGELOG.md contains a v0.9.1 heading and references M013/P04/T04.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

INSTALL_MD="${REPO_ROOT}/references/installation.md"
HOOKS_MD="${REPO_ROOT}/references/hooks.md"
CHANGELOG="${REPO_ROOT}/CHANGELOG.md"

# references/installation.md: "Uninstall" heading.
if [ ! -f "$INSTALL_MD" ]; then
  fail "references/installation.md missing"
elif grep -nE '^#{1,6}[[:space:]]+Uninstall' "$INSTALL_MD" >/dev/null 2>&1; then
  pass "references/installation.md has Uninstall heading"
else
  fail "references/installation.md missing Uninstall heading"
fi

# references/hooks.md: M025 marker and TODO(M025+) deferral markers.
if [ ! -f "$HOOKS_MD" ]; then
  fail "references/hooks.md missing"
else
  if grep -n 'M025' "$HOOKS_MD" >/dev/null 2>&1; then
    pass "references/hooks.md references M025"
  else
    fail "references/hooks.md missing M025 reference"
  fi
  if grep -nE 'TODO\(M025\+\)' "$HOOKS_MD" >/dev/null 2>&1; then
    pass "references/hooks.md contains TODO(M025+) deferral markers"
  else
    fail "references/hooks.md missing TODO(M025+) markers"
  fi
  # Six-event mapping: the four deferred orchestrator events must be named.
  deferred_missing=0
  for ev in before_tasks after_tasks before_implement after_implement; do
    if ! grep -n "$ev" "$HOOKS_MD" >/dev/null 2>&1; then
      deferred_missing=$((deferred_missing + 1))
    fi
  done
  if [ "$deferred_missing" -eq 0 ]; then
    pass "references/hooks.md names all four deferred events"
  else
    fail "references/hooks.md missing ${deferred_missing} deferred-event names"
  fi
fi

# CHANGELOG.md: v0.9.1 + M013/P04/T04 reference.
if [ ! -f "$CHANGELOG" ]; then
  fail "CHANGELOG.md missing"
else
  if grep -n 'v0\.9\.1' "$CHANGELOG" >/dev/null 2>&1; then
    pass "CHANGELOG.md has v0.9.1 heading"
  else
    fail "CHANGELOG.md missing v0.9.1 heading"
  fi
  if grep -nE 'M013/P04/T04' "$CHANGELOG" >/dev/null 2>&1; then
    pass "CHANGELOG.md references M013/P04/T04"
  else
    fail "CHANGELOG.md missing M013/P04/T04 reference"
  fi
fi

echo "SUMMARY: m025-p01-docs.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m025-p01-docs.sh"
  exit 0
fi
echo "FAIL: m025-p01-docs.sh" >&2
exit 1
