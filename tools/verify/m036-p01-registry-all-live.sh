#!/usr/bin/env bash
# tools/verify/m036-p01-registry-all-live.sh -- M036 P01 registry contract
# verifier. Asserts every Tier 1 format row in
# scripts/dispatch/adapters/format/registry.tsv is at status=live (no
# `stub` rows remaining for the four formats {markdown, pdf, docx, xlsx}).
# Single-script-file shape per AD-19 / AP-009 -- one awk invocation per
# format (awk is one tool, not a pipe), independent statements, no
# compound chains.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
REGISTRY="$ROOT/scripts/dispatch/adapters/format/registry.tsv"
pass=0
fail=0

if [ ! -f "$REGISTRY" ]; then
  echo "FAIL: registry-missing ($REGISTRY)"
  echo "SUMMARY: m036-p01-registry-all-live pass=0 fail=1"
  exit 1
fi

check_row() {
  local fmt="$1"
  local status
  status="$(awk -F'\t' -v f="$fmt" '$1==f {print $3}' "$REGISTRY")"
  if [ "$status" = "live" ]; then
    echo "PASS: $fmt=live"
    pass=$((pass + 1))
  elif [ -z "$status" ]; then
    echo "FAIL: $fmt=<row-missing>"
    fail=$((fail + 1))
  else
    echo "FAIL: $fmt=$status"
    fail=$((fail + 1))
  fi
}

check_row markdown
check_row pdf
check_row docx
check_row xlsx

echo "SUMMARY: m036-p01-registry-all-live pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
