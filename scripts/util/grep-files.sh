#!/usr/bin/env bash
# scripts/util/grep-files.sh -- Grep one pattern across multiple files with per-file separators.
#
# Usage: grep-files.sh <pattern> <file...>
#   <pattern> -- ERE pattern (passed verbatim to grep -E).
#   <file...> -- one or more file paths (no recursion; for recursion use peek-files.sh).
#
# Output:
#   --- <file> ---       (per-file separator, stdout)
#   <matching lines>     (grep output for that file, stdout)
#   ...                  (repeated for each file)
#
# Exit:
#   0 -- at least one file produced at least one match.
#   1 -- no file produced any match (clean run, nothing found).
#   2 -- usage error (missing args, unreadable file).
#
# Replaces the Screenshot 1 shape `grep P f1 ; echo "---" ; grep P f2` (M028 FR-14, AP-009 / AP-010 sibling).
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

if [ $# -lt 2 ]; then
  echo "usage: grep-files.sh <pattern> <file...>" >&2
  exit 2
fi

pattern="$1"
shift

any_match=1   # 1 = no match (default), 0 = at least one match
for f in "$@"; do
  if [ ! -f "$f" ]; then
    echo "grep-files.sh: file not found: $f" >&2
    exit 2
  fi
  printf -- '--- %s ---\n' "$f"
  if grep -E -- "$pattern" "$f"; then
    any_match=0
  fi
done

exit "$any_match"
