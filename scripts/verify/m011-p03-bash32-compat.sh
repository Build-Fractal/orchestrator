#!/usr/bin/env bash
# scripts/verify/m011-p03-bash32-compat.sh
# Verifies scripts/knowledge/ingest-spec.sh passes Bash 3.2 syntax check
# and does not use forbidden constructs (declare -A, mapfile, readarray).
#
# Output: PASS: or FAIL: prefixed lines to stdout. Exit 0 on pass, 1 on fail.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"
fail_count=0

if [ ! -f "$target" ]; then
  echo "FAIL: $target does not exist"
  exit 1
fi

# 1) bash -n syntax check
if ! /bin/bash -n "$target" 2>/dev/null; then
  echo "FAIL: $target does not pass bash -n syntax check"
  fail_count=$((fail_count + 1))
fi

# 2) Forbidden construct scan. We strip comments from each line first
# so that a harmless mention in a comment doesn't trip the scan.
scan_forbidden() {
  local pattern="$1"
  local label="$2"
  local hits=0
  local line=""
  while IFS= read -r line || [ -n "$line" ]; do
    # Strip everything from the first unescaped '#' to end-of-line.
    # This is intentionally simple: it drops lines that are pure comments
    # and trims trailing comments. It does not attempt to handle '#' inside
    # quoted strings, which matches the project's comment-aware scan convention.
    local stripped
    stripped="$(printf '%s' "$line" | sed 's/[[:space:]]*#.*$//')"
    case "$stripped" in
      *"$pattern"*)
        hits=$((hits + 1))
        ;;
    esac
  done < "$target"
  if [ "$hits" -gt 0 ]; then
    echo "FAIL: $target contains forbidden construct '$label' ($hits occurrence(s))"
    return 1
  fi
  return 0
}

if ! scan_forbidden "declare -A" "declare -A"; then
  fail_count=$((fail_count + 1))
fi
if ! scan_forbidden "mapfile" "mapfile"; then
  fail_count=$((fail_count + 1))
fi
if ! scan_forbidden "readarray" "readarray"; then
  fail_count=$((fail_count + 1))
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: ingest-spec.sh passes Bash 3.2 syntax + forbidden-construct scan"
  exit 0
else
  echo "FAIL: $fail_count check(s) failed"
  exit 1
fi
