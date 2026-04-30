#!/usr/bin/env bash
# tools/verify/p03-con3-closure.sh -- M030 P03 CON-3 closure gate.
#
# Asserts that the T02 amendment to scripts/dispatch/dispatch-interface.sh
# introduces zero NEW provider-model-ID literals. Compares per-pattern
# occurrence counts in:
#   - HEAD version (git show HEAD:<path>) — pre-T02 baseline (P02 close)
#   - working tree (current file)
# and asserts working-tree count <= HEAD count for each closed-set pattern.
#
# Closed pattern set (provider model-ID prefixes):
#   claude-haiku-, claude-sonnet-, claude-opus-, gpt-, o1-, o3-, gemini-
#
# Mirrors the P02/T02 p02-con3-closure.sh shape.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Tmp-file
# intermediates per AP-009. Exit 0 iff fail == 0.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_REL="scripts/dispatch/dispatch-interface.sh"
TARGET="$REPO_ROOT/$TARGET_REL"

pass=0
fail=0

if [ ! -f "$TARGET" ]; then
  printf 'FAIL: target file missing at %s\n' "$TARGET"
  printf 'SUMMARY: p03-con3-closure.sh pass=0 fail=1\n'
  exit 1
fi

# Snapshot HEAD version once.
HEAD_TMP="/tmp/p03-con3-head.txt"
rm -f "$HEAD_TMP" 2>/dev/null
( cd "$REPO_ROOT" && git show "HEAD:$TARGET_REL" > "$HEAD_TMP" 2>/dev/null )
if [ ! -s "$HEAD_TMP" ]; then
  : > "$HEAD_TMP"
fi

_check_pattern() {
  # $1 = pattern; $2 = label
  local pattern="$1"
  local label="$2"
  local head_count_tmp="/tmp/p03-con3-headc.txt"
  local wt_count_tmp="/tmp/p03-con3-wtc.txt"
  local head_count wt_count

  rm -f "$head_count_tmp" "$wt_count_tmp" 2>/dev/null
  grep -c -E "$pattern" "$HEAD_TMP" > "$head_count_tmp" 2>/dev/null
  grep -c -E "$pattern" "$TARGET" > "$wt_count_tmp" 2>/dev/null
  head_count="$(tr -d '[:space:]' < "$head_count_tmp")"
  wt_count="$(tr -d '[:space:]' < "$wt_count_tmp")"
  rm -f "$head_count_tmp" "$wt_count_tmp" 2>/dev/null
  [ -n "$head_count" ] || head_count=0
  [ -n "$wt_count" ] || wt_count=0

  if [ "$wt_count" -le "$head_count" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: CON-3 closure violated for pattern %s (%s) -- HEAD=%d, working-tree=%d\n' \
      "$pattern" "$label" "$head_count" "$wt_count"
  fi
}

_check_pattern 'claude-haiku-' 'claude-haiku'
_check_pattern 'claude-sonnet-' 'claude-sonnet'
_check_pattern 'claude-opus-' 'claude-opus'
_check_pattern 'gpt-' 'openai-gpt'
_check_pattern 'o1-' 'openai-o1'
_check_pattern 'o3-' 'openai-o3'
_check_pattern 'gemini-' 'google-gemini'

rm -f "$HEAD_TMP" 2>/dev/null

printf 'SUMMARY: p03-con3-closure.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
