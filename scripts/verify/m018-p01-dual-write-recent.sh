#!/usr/bin/env bash
# scripts/verify/m018-p01-dual-write-recent.sh — phase-truth verifier:
# "CLAUDE.md and AGENTS.md `recent-changes` block both name M018/P01".
#
# Both files contain a delimited block:
#   # >>> orchestrator:recent-changes >>>
#   ...
#   # <<< orchestrator:recent-changes <<<
# The block in each file MUST contain the literal substring `M018/P01`.
# AGENTS.md is mirrored from CLAUDE.md via scripts/util/dual-write-runtime-md.sh
# (NEVER edit AGENTS.md directly).
#
# AD-19 single-script-file shape, bash 3.2, MEM001 PASS/FAIL, exit 0/1.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
AGENTS_MD="$REPO_ROOT/AGENTS.md"

check_block() {
  local label="$1"
  local file="$2"

  if [ ! -f "$file" ]; then
    printf 'FAIL: %s missing at %s\n' "$label" "$file" >&2
    return 1
  fi

  local block_file
  block_file=$(mktemp)
  awk '
    /^# >>> orchestrator:recent-changes >>>/ { capture = 1; next }
    /^# <<< orchestrator:recent-changes <<</ { capture = 0 }
    capture { print }
  ' "$file" > "$block_file"

  if [ ! -s "$block_file" ]; then
    printf 'FAIL: %s recent-changes block missing or empty\n' "$label" >&2
    rm -f "$block_file"
    return 1
  fi

  if grep -qF 'M018/P01' "$block_file"; then
    printf 'PASS: M018/P01 named in %s recent-changes\n' "$label"
    rm -f "$block_file"
    return 0
  fi

  printf 'FAIL: M018/P01 not named in %s recent-changes block\n' "$label" >&2
  rm -f "$block_file"
  return 1
}

FAIL_COUNT=0
if ! check_block 'CLAUDE.md' "$CLAUDE_MD"; then
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi
if ! check_block 'AGENTS.md' "$AGENTS_MD"; then
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
