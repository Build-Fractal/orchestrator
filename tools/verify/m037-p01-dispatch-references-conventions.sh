#!/usr/bin/env bash
# tools/verify/m037-p01-dispatch-references-conventions.sh — M037 P01 T04 Truth #9 verifier.
#
# Asserts commands/dispatch.md references the authoring-conventions doc by
# checking for the literal string 'references/authoring-conventions.md'.
#
# Expected output on pass: 'PASS: m037-p01-dispatch-references-conventions'.
# Single-script-file shape (AD-19). Bash 3.2 + POSIX sh compatible (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="$PROJECT_ROOT/commands/dispatch.md"
NEEDLE='references/authoring-conventions.md'

if [ ! -f "$TARGET" ]; then
  printf 'FAIL: m037-p01-dispatch-references-conventions: %s not found\n' "$TARGET" >&2
  exit 1
fi

if grep -F -q "$NEEDLE" "$TARGET"; then
  printf 'PASS: m037-p01-dispatch-references-conventions\n'
  exit 0
fi

printf 'FAIL: m037-p01-dispatch-references-conventions: literal "%s" not found in %s\n' \
  "$NEEDLE" "$TARGET" >&2
exit 1
