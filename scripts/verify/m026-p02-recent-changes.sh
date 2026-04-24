#!/usr/bin/env bash
# scripts/verify/m026-p02-recent-changes.sh -- M026/P02/T05 gate:
# asserts CLAUDE.md and AGENTS.md Recent Changes regions contain the
# M026/P02 dual-write fragment and remain byte-identical inside the marker
# region (OQ-10 dual-write parity). Also asserts the P01 fragment survives
# (non-overwrite invariant).
#
# Marker-bounded region helper:
#   scripts/verify/lib/m026-p01-recent-changes-region.sh
# extracts the body between
#   # >>> orchestrator:recent-changes >>>
#   # <<< orchestrator:recent-changes <<<
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HELPER="${SCRIPT_DIR}/lib/m026-p01-recent-changes-region.sh"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

if [ ! -f "$HELPER" ]; then
  fail "recent-changes region helper missing at ${HELPER}"
  echo "SUMMARY: m026-p02-recent-changes.sh pass=${passed} fail=${failed}"
  exit 1
fi

CLAUDE_REGION=""
AGENTS_REGION=""

claude_path="${REPO_ROOT}/CLAUDE.md"
agents_path="${REPO_ROOT}/AGENTS.md"

if [ ! -f "$claude_path" ]; then
  fail "CLAUDE.md missing"
else
  CLAUDE_REGION=$(bash "$HELPER" "$claude_path" 2>/dev/null || true)
fi

if [ ! -f "$agents_path" ]; then
  fail "AGENTS.md missing"
else
  AGENTS_REGION=$(bash "$HELPER" "$agents_path" 2>/dev/null || true)
fi

# 1. CLAUDE.md region must contain M026/P02 fragment.
if [ -n "$CLAUDE_REGION" ]; then
  if echo "$CLAUDE_REGION" | grep -q 'M026/P02'; then
    pass "CLAUDE.md: Recent Changes region contains M026/P02 fragment"
  else
    fail "CLAUDE.md: Recent Changes region missing M026/P02 fragment"
  fi
else
  fail "CLAUDE.md: Recent Changes region empty or markers missing"
fi

# 2. AGENTS.md region must contain M026/P02 fragment.
if [ -n "$AGENTS_REGION" ]; then
  if echo "$AGENTS_REGION" | grep -q 'M026/P02'; then
    pass "AGENTS.md: Recent Changes region contains M026/P02 fragment"
  else
    fail "AGENTS.md: Recent Changes region missing M026/P02 fragment"
  fi
else
  fail "AGENTS.md: Recent Changes region empty or markers missing"
fi

# 3. OQ-10 dual-write parity: both regions byte-identical.
if [ -n "$CLAUDE_REGION" ] && [ -n "$AGENTS_REGION" ]; then
  if [ "$CLAUDE_REGION" = "$AGENTS_REGION" ]; then
    pass "OQ-10: CLAUDE.md and AGENTS.md Recent Changes regions byte-identical"
  else
    fail "OQ-10: CLAUDE.md and AGENTS.md Recent Changes regions DIVERGED"
  fi
fi

# 4. Non-overwrite: P01 fragment still present in both files.
if [ -n "$CLAUDE_REGION" ]; then
  if echo "$CLAUDE_REGION" | grep -q 'M026/P01'; then
    pass "CLAUDE.md: P01 fragment preserved (non-overwrite)"
  else
    fail "CLAUDE.md: P01 fragment missing — non-overwrite invariant violated"
  fi
fi
if [ -n "$AGENTS_REGION" ]; then
  if echo "$AGENTS_REGION" | grep -q 'M026/P01'; then
    pass "AGENTS.md: P01 fragment preserved (non-overwrite)"
  else
    fail "AGENTS.md: P01 fragment missing — non-overwrite invariant violated"
  fi
fi

echo "SUMMARY: m026-p02-recent-changes.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m026-p02-recent-changes.sh"
  exit 0
fi
echo "FAIL: m026-p02-recent-changes.sh" >&2
exit 1
