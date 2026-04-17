#!/usr/bin/env bash
# scripts/verify/m011-p04-bash32-compat.sh
# Verifies that scripts touched by M011/P04 pass Bash 3.2 syntax and do not
# use forbidden constructs:
#   - scripts/dispatch/scope-filter.sh       (T01)
#   - scripts/dispatch/build-context.sh      (T02)
#   - scripts/dispatch/lib/section-handlers.sh (T02)
#
# Forbidden constructs:
#   declare -A   (associative arrays — bash 4.0+)
#   mapfile      (bash 4.0+ array builtin)
#   readarray    (bash 4.0+ array builtin)
#   <(...)       (process substitution — inconsistent under bash 3.2)
#
# Comment-aware scan: lines are stripped of trailing '# ...' before matching
# so a harmless mention inside a comment does not trip the check.
#
# Output: PASS: or FAIL: prefixed lines to stdout. Exit 0 on pass, 1 on fail.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGETS="$PROJECT_ROOT_REPO/scripts/dispatch/scope-filter.sh \
$PROJECT_ROOT_REPO/scripts/dispatch/build-context.sh \
$PROJECT_ROOT_REPO/scripts/dispatch/lib/section-handlers.sh"

fail_count=0

# 1) bash -n syntax check (per-target)
for target in $TARGETS; do
  if [ ! -f "$target" ]; then
    echo "FAIL: $target does not exist"
    fail_count=$((fail_count + 1))
    continue
  fi
  if ! /bin/bash -n "$target" 2>/dev/null; then
    echo "FAIL: $target does not pass bash -n syntax check"
    fail_count=$((fail_count + 1))
  fi
done

# 2) Forbidden construct scan. Strip comments from each line first so that a
# harmless mention in a comment does not trip the scan.
scan_forbidden() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  local hits=0
  local line=""
  while IFS= read -r line || [ -n "$line" ]; do
    local stripped
    stripped="$(printf '%s' "$line" | sed 's/[[:space:]]*#.*$//')"
    case "$stripped" in
      *"$pattern"*)
        hits=$((hits + 1))
        ;;
    esac
  done < "$file"
  if [ "$hits" -gt 0 ]; then
    echo "FAIL: $file contains forbidden construct '$label' ($hits occurrence(s))"
    return 1
  fi
  return 0
}

for target in $TARGETS; do
  [ -f "$target" ] || continue
  if ! scan_forbidden "$target" "declare -A" "declare -A"; then
    fail_count=$((fail_count + 1))
  fi
  if ! scan_forbidden "$target" "mapfile" "mapfile"; then
    fail_count=$((fail_count + 1))
  fi
  if ! scan_forbidden "$target" "readarray" "readarray"; then
    fail_count=$((fail_count + 1))
  fi
  # Process-substitution scan: look for "<(" tokens. We strip comments first
  # (handled above) so comment explanations of the anti-pattern do not trip.
  if ! scan_forbidden "$target" '<(' 'process substitution <(...)'; then
    fail_count=$((fail_count + 1))
  fi
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: all M011/P04 dispatch scripts pass Bash 3.2 syntax + forbidden-construct scan"
  exit 0
else
  echo "FAIL: $fail_count check(s) failed"
  exit 1
fi
