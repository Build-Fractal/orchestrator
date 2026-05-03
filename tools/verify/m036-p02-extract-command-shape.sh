#!/usr/bin/env bash
# tools/verify/m036-p02-extract-command-shape.sh -- M036 P02 T03.
# Asserts commands/extract.md exists with the required headings.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DOC="$ROOT/commands/extract.md"
fail=0
if [ ! -f "$DOC" ]; then
  echo "FAIL: missing $DOC"
  exit 1
fi
check() {
  local pat="$1"
  if grep -qF -e "$pat" "$DOC"; then
    echo "PASS: contains '$pat'"
  else
    echo "FAIL: missing '$pat'"
    fail=$((fail + 1))
  fi
}
check "## Prerequisites"
check "## Inputs"
check "## Output"
check "## Idempotency"
check "## Error Handling"
check "## Referenced Scripts"
check "--manifest"
check "EXTRACTED:"
check "SKIPPED:"
echo "SUMMARY: m036-p02-extract-command-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
