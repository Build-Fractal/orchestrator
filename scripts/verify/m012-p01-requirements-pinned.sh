#!/usr/bin/env bash
# scripts/verify/m012-p01-requirements-pinned.sh — asserts exact-pin discipline.
#
# Requires >=4 lines of shape `<pkg>==<ver>` in wiki/requirements.txt.
# No `>=`, `~=`, `<`, `!=`, or bare package names without pins allowed.
#
# Bash 3.2 compatible. Single-script-file shape.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
REQ="$ROOT/wiki/requirements.txt"

FAIL_COUNT=0
fail() {
  printf 'FAIL: m012-p01-requirements-pinned %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

if [ ! -f "$REQ" ]; then
  fail "wiki/requirements.txt not found"
  exit 1
fi

# Count exact-pin lines: package name + == + version.
PIN_COUNT=$(grep -c '^[a-zA-Z0-9_.-]\{1,\}==' "$REQ" 2>/dev/null || printf '0')
# grep may emit "0" even on success; normalize.
[ -z "$PIN_COUNT" ] && PIN_COUNT=0

if [ "$PIN_COUNT" -lt 4 ]; then
  fail "expected >=4 exact pins (== form), found: $PIN_COUNT"
fi

# Reject non-exact specifiers. Comments and blank lines are ignored.
# Walk the file line-by-line to avoid pipe subshell state loss.
LINENO_VAL=0
while IFS= read -r line || [ -n "$line" ]; do
  LINENO_VAL=$((LINENO_VAL + 1))
  # strip leading whitespace
  case "$line" in
    ""|\#*) continue ;;
    [[:space:]]*)
      trimmed=$(printf '%s' "$line" | sed 's/^[[:space:]]*//')
      case "$trimmed" in
        ""|\#*) continue ;;
      esac
      line="$trimmed"
      ;;
  esac
  # Detect forbidden operators. Note: `==` contains `=`, so test for
  # forbidden operators first, then confirm `==` pin shape.
  case "$line" in
    *'>='*|*'<='*|*'~='*|*'!='*)
      fail "forbidden range operator on line $LINENO_VAL: $line"
      continue
      ;;
  esac
  # A lone `<` or `>` without `=` is also a range.
  case "$line" in
    *'<'*|*'>'*)
      fail "forbidden range operator on line $LINENO_VAL: $line"
      continue
      ;;
  esac
  # Require either `==` pin or a valid `; python_version` style marker on
  # a pinned line. For simplicity: every non-blank, non-comment line must
  # contain `==`.
  case "$line" in
    *'=='*) : ;;
    *)
      fail "non-pinned dependency on line $LINENO_VAL: $line"
      ;;
  esac
done < "$REQ"

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m012-p01-requirements-pinned %s exact pins, no range operators\n' "$PIN_COUNT"
  exit 0
fi
exit 1
