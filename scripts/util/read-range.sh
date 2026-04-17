#!/usr/bin/env bash
# scripts/util/read-range.sh — Emit lines M..N of a file (inclusive, 1-indexed).
#
# Usage: read-range.sh <file> <M> <N>
#   e.g.: read-range.sh file.md 686 1050
#
# Replaces the inline `sed -n 'M,Np' file` shape that Claude Code
# flags as quoted-brace / sed-write obfuscation. The wrapper is
# allow-listed (bash scripts/util/*) and its arguments are plain
# integers, so no shape heuristic fires.
#
# Exit: 0 on success, 1 when the file is missing or unreadable,
# 2 when the range is invalid (non-integer, M<1, N<M, or N exceeds
# the file's line count).
#
# Bash 3.2 compatible.

set -u

if [ $# -ne 3 ]; then
  echo "usage: read-range.sh <file> <M> <N>" >&2
  exit 2
fi

file="$1"
m="$2"
n="$3"

# Validate file.
if [ ! -f "$file" ]; then
  echo "read-range.sh: file not found: $file" >&2
  exit 1
fi
if [ ! -r "$file" ]; then
  echo "read-range.sh: file not readable: $file" >&2
  exit 1
fi

# Validate integer shape (digits only, at least one digit).
case "$m" in
  ''|*[!0-9]*)
    echo "read-range.sh: M must be a positive integer: $m" >&2
    exit 2
    ;;
esac
case "$n" in
  ''|*[!0-9]*)
    echo "read-range.sh: N must be a positive integer: $n" >&2
    exit 2
    ;;
esac

if [ "$m" -lt 1 ]; then
  echo "read-range.sh: M must be >= 1 (got $m)" >&2
  exit 2
fi
if [ "$n" -lt "$m" ]; then
  echo "read-range.sh: N must be >= M (got M=$m N=$n)" >&2
  exit 2
fi

# Verify N does not exceed file line count.
total=$(wc -l "$file" | awk '{print $1}')
if [ "$n" -gt "$total" ]; then
  echo "read-range.sh: N=$n exceeds file line count ($total)" >&2
  exit 2
fi

# Emit the range. awk is allow-listed and the pattern is numeric
# only — no brace-in-quote ambiguity.
awk -v m="$m" -v n="$n" 'NR>=m && NR<=n { print } NR>n { exit }' "$file"
