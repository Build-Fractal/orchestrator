#!/usr/bin/env bash
# scripts/verify/m011-p05-bash32-compat.sh
# Bash 3.2 compatibility scan for all scripts P05 created or modified.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

FILES="
scripts/state/spec-metrics.sh
scripts/knowledge/spec-story-graph.sh
scripts/engine/intensity-gate.sh
"

fail=0

check_syntax() {
  local f="$1"
  if ! bash -n "$REPO/$f" 2>/dev/null; then
    printf 'FAIL[syntax]: %s\n' "$f"
    fail=1
  fi
}

check_no_forbidden() {
  local f="$1" path="$REPO/$f"
  # Strip comments before scanning so a descriptive comment does not
  # trigger the lint (pattern consistent with P04 bash32-compat scan).
  local tmp
  tmp="$(mktemp)"
  sed 's/#.*$//' "$path" > "$tmp"

  local pat
  for pat in 'declare -A' 'mapfile' 'readarray'; do
    if grep -q "$pat" "$tmp"; then
      printf 'FAIL[forbidden-token]: %s contains: %s\n' "$f" "$pat"
      fail=1
    fi
  done

  # Process substitution: <(...) or >(...). Match with extended regex.
  if grep -Eq '<\(|>\(' "$tmp"; then
    printf 'FAIL[process-substitution]: %s uses <(...) or >(...)\n' "$f"
    fail=1
  fi

  rm -f "$tmp"
}

for f in $FILES; do
  check_syntax "$f"
  check_no_forbidden "$f"
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: P05 scripts are Bash 3.2 compatible"
