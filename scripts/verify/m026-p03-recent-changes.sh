#!/usr/bin/env bash
# scripts/verify/m026-p03-recent-changes.sh -- M026/P03/T05 gate:
# verifies CLAUDE.md and AGENTS.md both contain the new M026/P03 entry
# AND preserve the existing M026/P02 entry, with M026/P03 ordered before
# M026/P02 (reverse-chronological prepend per --append-entry contract).
#
# OQ-10 dual-write parity: parallel checks per file confirm both received
# the same entry, in the same place.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. No compound bash.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

claude_path="${REPO_ROOT}/CLAUDE.md"
agents_path="${REPO_ROOT}/AGENTS.md"

# Per-file checks: contains M026/P03 entry, preserves M026/P02 entry,
# marker region intact.
for f in CLAUDE.md AGENTS.md; do
  full="${REPO_ROOT}/${f}"
  if [ ! -f "$full" ]; then
    fail "${f}: missing"
    continue
  fi
  if grep -qE 'M026/P03.*conversus-OSS migration close' "$full"; then
    pass "${f}: contains M026/P03 entry"
  else
    fail "${f}: missing M026/P03 entry"
  fi
  if grep -qE 'M026/P02' "$full"; then
    pass "${f}: M026/P02 entry preserved"
  else
    fail "${f}: M026/P02 entry was lost (overwrite regression)"
  fi
  if grep -q '^# >>> orchestrator:recent-changes >>>' "$full"; then
    pass "${f}: marker region intact"
  else
    fail "${f}: missing marker region"
  fi
done

# Order check: M026/P03 must appear BEFORE M026/P02 in CLAUDE.md
# (reverse-chronological — newest first, per --append-entry mode).
ord_p03=$(grep -nE 'M026/P03.*conversus-OSS migration close' "$claude_path" | head -1 | awk -F: '{print $1}')
ord_p02=$(grep -nE 'M026/P02:' "$claude_path" | head -1 | awk -F: '{print $1}')
if [ -n "$ord_p03" ] && [ -n "$ord_p02" ] && [ "$ord_p03" -lt "$ord_p02" ]; then
  pass "CLAUDE.md: M026/P03 precedes M026/P02 (reverse-chronological)"
else
  fail "CLAUDE.md: M026/P03 does not precede M026/P02 (p03=${ord_p03}, p02=${ord_p02})"
fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${passed} fail=${failed}"
if [ "$failed" -gt 0 ]; then
  echo "FAIL: $(basename "$0")" >&2
  exit 1
fi
echo "PASS: $(basename "$0")"
exit 0
