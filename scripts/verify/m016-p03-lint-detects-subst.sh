#!/usr/bin/env bash
# m016-p03-lint-detects-subst.sh — Verify linter catches $(...) command substitution
# Bash 3.2 compatible. Standalone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/verify/anti-pattern-lint.sh"

_tmpfile="$(mktemp)"
trap 'rm -f "$_tmpfile"' EXIT

# Create a fixture with command substitution inside a code block
cat > "$_tmpfile" <<'FIXTURE'
# Test fixture

```bash
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "$ts"
```
FIXTURE

# Run linter on fixture — should fail
if bash "$LINTER" --fixture "$_tmpfile" > /dev/null 2>&1; then
  echo "FAIL: linter did not detect command substitution"
  exit 1
fi

# Confirm output mentions command substitution
_output="$(bash "$LINTER" --fixture "$_tmpfile" 2>&1 || true)"
case "$_output" in
  *"command substitution"*)
    echo "PASS: linter detects command substitution"
    exit 0
    ;;
  *)
    echo "FAIL: linter output does not mention command substitution"
    exit 1
    ;;
esac
