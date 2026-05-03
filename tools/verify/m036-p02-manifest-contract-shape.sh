#!/usr/bin/env bash
# tools/verify/m036-p02-manifest-contract-shape.sh -- M036 P02 T01.
# Asserts references/extract-manifest-contract.md exists with the
# required headings + schema field declarations. Single-script-file
# shape per AD-19 (no compound chains at the invocation layer).
# Bash 3.2 / POSIX-sh per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DOC="$ROOT/references/extract-manifest-contract.md"
fail=0
if [ ! -f "$DOC" ]; then
  echo "FAIL: missing $DOC"
  exit 1
fi
check() {
  local pattern="$1"
  if grep -qF "$pattern" "$DOC"; then
    echo "PASS: contains '$pattern'"
  else
    echo "FAIL: missing '$pattern'"
    fail=$((fail + 1))
  fi
}
check "## Top-Level Fields"
check "## Per-Document Fields"
check "## Summary Modes"
check "## Default-Tier Resolution"
check "size_cap_bytes"
check "summary_mode"
check "cite_id"
check "category"
check "topic_tags"
check "applies_to_field"
check "operator"
check "stub"
check "auto"
echo "SUMMARY: m036-p02-manifest-contract-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
