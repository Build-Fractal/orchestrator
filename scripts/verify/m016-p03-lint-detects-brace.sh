#!/usr/bin/env bash
# m016-p03-lint-detects-brace.sh — Verify linter catches {a,b} brace expansion
# Bash 3.2 compatible. Standalone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/verify/anti-pattern-lint.sh"

_tmpfile="$(mktemp)"
trap 'rm -f "$_tmpfile"' EXIT

# Create a fixture with brace expansion inside a code block
cat > "$_tmpfile" <<'FIXTURE'
# Test fixture

```bash
cp file.{txt,bak}
```
FIXTURE

# Run linter on fixture — should fail
if bash "$LINTER" --fixture "$_tmpfile" > /dev/null 2>&1; then
  echo "FAIL: linter did not detect brace expansion"
  exit 1
fi

# Confirm output mentions brace expansion
_output="$(bash "$LINTER" --fixture "$_tmpfile" 2>&1 || true)"
case "$_output" in
  *"brace expansion"*)
    echo "PASS: linter detects brace expansion"
    exit 0
    ;;
  *)
    echo "FAIL: linter output does not mention brace expansion"
    exit 1
    ;;
esac
