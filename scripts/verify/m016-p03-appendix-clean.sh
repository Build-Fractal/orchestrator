#!/usr/bin/env bash
# m016-p03-appendix-clean.sh — Verify claude-code-appendix.md has no output=$(bash ...) in code blocks
# Bash 3.2 compatible. Standalone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$PROJECT_ROOT/templates/claude-code-appendix.md"

if [ ! -f "$TARGET" ]; then
  echo "FAIL: templates/claude-code-appendix.md not found"
  exit 1
fi

# Scan code blocks for output=$(bash ...) pattern
in_code_block=0
line_num=0
_found=0
while IFS= read -r line; do
  line_num=$((line_num + 1))
  case "$line" in
    '```'*)
      if [ "$in_code_block" -eq 0 ]; then
        in_code_block=1
      else
        in_code_block=0
      fi
      continue
      ;;
  esac
  if [ "$in_code_block" -eq 1 ]; then
    if printf '%s\n' "$line" | grep -q 'output=\$(bash' 2>/dev/null; then
      echo "FAIL: templates/claude-code-appendix.md line $line_num contains output=\$(bash in code block"
      _found=1
    fi
  fi
done < "$TARGET"

if [ "$_found" -eq 0 ]; then
  echo "PASS: templates/claude-code-appendix.md code blocks are clean of output=\$(bash"
  exit 0
else
  exit 1
fi
