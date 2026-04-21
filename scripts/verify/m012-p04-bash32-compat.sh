#!/usr/bin/env bash
# scripts/verify/m012-p04-bash32-compat.sh — M012/P04 compat scan.
#
# Scans every .sh file in the P04 surface for Bash 4+ constructs that
# macOS's bash 3.2 cannot parse/execute. Forbidden patterns in
# non-comment, non-assignment-name-echo code:
#   declare -A, mapfile, readarray, ${var^^}, ${var,,}, <(...), >(...), &>
#
# Self-inclusive: includes this file in the scan surface. The self-scan
# carve-out is an assignment-line filter that drops `^NAME=` lines so
# the literal pattern names this script itself declares don't trip it.
# Mirrors the P02/P03 compat pattern.
#
# Target surface:
#   scripts/wiki/wiki-deploy.sh
#   scripts/verify/m012-p04-*.sh  (self-inclusive)
#
# Bash 3.2 compliant.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

SCAN_TMP="/tmp/m012-p04-compat-scan.$$.tmp"
# shellcheck disable=SC2064
trap "rm -f '$SCAN_TMP'" EXIT INT TERM

targets=""
for f in \
  "$ROOT/scripts/wiki/wiki-deploy.sh"
do
  targets="$targets
$f"
done

# Add every scripts/verify/m012-p04-*.sh file (self-inclusive).
for f in "$ROOT"/scripts/verify/m012-p04-*.sh; do
  [ -f "$f" ] || continue
  targets="$targets
$f"
done

# Pattern source-of-truth as an assignment so the self-scan skips it.
# (The assignment-line carve-out drops `^NN:[ws]*NAME=` matches.)
PAT_BASH4='declare -A|mapfile|readarray|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^\}|\$\{[a-zA-Z_][a-zA-Z0-9_]*,,\}|<\(|>\(|&>'

hits=0
missing=0
OLD_IFS="$IFS"
IFS='
'
for f in $targets; do
  [ -n "$f" ] || continue
  if [ ! -f "$f" ]; then
    printf 'FAIL: target missing: %s\n' "$f" >&2
    missing=$((missing + 1))
    continue
  fi
  # Filter out:
  #  - comment lines (^NN: #...)
  #  - assignment-lines that happen to echo the pattern as a string
  #    (e.g. `targets=...declare -A...` or the PAT_BASH4 line above).
  grep -nE "$PAT_BASH4" "$f" \
    | grep -vE '^[[:digit:]]+:[[:space:]]*#' \
    | grep -vE '^[[:digit:]]+:[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*=' \
    > "$SCAN_TMP" || true
  if [ -s "$SCAN_TMP" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      printf 'FAIL: %s %s\n' "$f" "$line" >&2
      hits=$((hits + 1))
    done < "$SCAN_TMP"
  fi
done
IFS="$OLD_IFS"

if [ "$missing" -gt 0 ]; then
  printf 'FAIL: %d target files missing\n' "$missing" >&2
  exit 1
fi
if [ "$hits" -gt 0 ]; then
  printf 'FAIL: %d bash-3.2-incompatible constructs\n' "$hits" >&2
  exit 1
fi

printf 'PASS: bash 3.2 compat clean across P04 surface\n'
exit 0
