#!/usr/bin/env bash
# m016-p03-lint-detects-backtick.sh — Verify linter catches backtick command substitution
# Bash 3.2 compatible. Standalone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/verify/anti-pattern-lint.sh"

_tmpfile="$(mktemp)"
trap 'rm -f "$_tmpfile"' EXIT

# Create a fixture with backtick command substitution inside a code block
cat > "$_tmpfile" <<'FIXTURE'
# Test fixture

```bash
state=`bash scripts/state/derive-phase.sh dir`
echo "$state"
```
FIXTURE

# Run linter on fixture — should fail
if bash "$LINTER" --fixture "$_tmpfile" > /dev/null 2>&1; then
  echo "FAIL: linter did not detect backtick substitution"
  exit 1
fi

# Confirm output mentions backtick
_output="$(bash "$LINTER" --fixture "$_tmpfile" 2>&1 || true)"
case "$_output" in
  *"backtick"*)
    echo "PASS: linter detects backtick command substitution"
    exit 0
    ;;
  *)
    echo "FAIL: linter output does not mention backtick"
    exit 1
    ;;
esac
