#!/usr/bin/env bash
set -euo pipefail
# Verify commands/auto.md does not contain $( in write-summary examples
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$PROJECT_ROOT/commands/auto.md"

if ! [ -f "$TARGET" ]; then
  echo "FAIL: commands/auto.md not found"
  exit 1
fi

# Check for $(date or $(bash in code blocks near write-summary
if grep -n 'write-summary' "$TARGET" | grep -q '\$(' ; then
  echo "FAIL: commands/auto.md still contains \$( near write-summary invocations"
  grep -n 'write-summary.*\$(' "$TARGET"
  exit 1
fi

echo "PASS: commands/auto.md write-summary examples contain no command substitution"
exit 0
