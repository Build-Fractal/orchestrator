#!/usr/bin/env bash
# tools/verify/m036-p04-command-shape.sh -- M036 P04 T03.
# Asserts commands/ingest-reference.md exists with the M036/P02-canonical
# command-doc structure (Prerequisites + Inputs + Output + Idempotency
# + Error Handling + Referenced Scripts sections) and declares the
# stdout protocol + flags per the M036 P04 contract.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
CMD="$ROOT/commands/ingest-reference.md"
fail=0
if [ -f "$CMD" ]; then
  echo "PASS: command doc exists $CMD"
else
  echo "FAIL: command doc missing $CMD"
  echo "SUMMARY: m036-p04-command-shape.sh fail=1"
  exit 1
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$CMD"; then
    echo "PASS: '$pat' in $(basename "$CMD")"
  else
    echo "FAIL: '$pat' missing in $(basename "$CMD")"
    fail=$((fail + 1))
  fi
}
checkpat "## Prerequisites"
checkpat "## Inputs"
checkpat "## Output"
checkpat "## Idempotency"
checkpat "## Error Handling"
checkpat "## Referenced Scripts"
checkpat "--reference-root"
checkpat "--no-index-rebuild"
checkpat "CREATED:"
checkpat "SKIPPED:"
checkpat "REJECTED:"
checkpat "BLOCKED:"
checkpat "ingest-reference.sh"
checkpat "FR-18"
echo "SUMMARY: m036-p04-command-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
