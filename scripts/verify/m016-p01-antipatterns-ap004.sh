#!/usr/bin/env bash
set -euo pipefail
# Verify ANTIPATTERNS.md contains AP-004 with required sections
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$PROJECT_ROOT/ANTIPATTERNS.md"

if ! [ -f "$TARGET" ]; then
  echo "FAIL: ANTIPATTERNS.md not found"
  exit 1
fi

fail=0
for marker in "AP-004" "command substitution" "Brace expansion" "Compound bash" "Remedy"; do
  if ! grep -qi "$marker" "$TARGET"; then
    echo "FAIL: ANTIPATTERNS.md missing expected content: $marker"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "PASS: ANTIPATTERNS.md contains AP-004 with all required sections"
  exit 0
fi
exit 1
