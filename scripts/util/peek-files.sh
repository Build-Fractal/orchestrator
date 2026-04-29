#!/usr/bin/env bash
# scripts/util/peek-files.sh -- Enumerate files matching a glob and head-N each match.
#
# Usage: peek-files.sh <glob-pattern> [--lines N] [--exclude PATH] [--max N]
#   <glob-pattern> -- path glob suitable for find -name (e.g. "T*-SUMMARY.md").
#   --lines N      -- lines per file (default 20).
#   --exclude PATH -- exclude any path containing this substring (find -not -path "*PATH*").
#   --max N        -- cap on the number of files to peek (default 20).
#
# Output:
#   --- <file> ---       (per-file separator, stdout)
#   <first N lines>      (stdout)
#   ...
#
# Exit:
#   0 -- at least one file peeked.
#   1 -- no files matched.
#   2 -- usage / validation error.
#
# Replaces the Finding G shape `find ... | head ... | xargs -I{} sh -c 'echo "---"; head -N "{}"'`
# (M028 FR-17 / AP-014). Internal impl uses find + while-read; never invokes sh -c.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

if [ $# -lt 1 ]; then
  echo "usage: peek-files.sh <glob-pattern> [--lines N] [--exclude PATH] [--max N]" >&2
  exit 2
fi

pattern="$1"
shift

lines=20
exclude=""
max=20

while [ $# -gt 0 ]; do
  case "$1" in
    --lines)
      if [ $# -lt 2 ]; then echo "peek-files.sh: --lines requires a value" >&2; exit 2; fi
      lines="$2"; shift 2
      ;;
    --exclude)
      if [ $# -lt 2 ]; then echo "peek-files.sh: --exclude requires a value" >&2; exit 2; fi
      exclude="$2"; shift 2
      ;;
    --max)
      if [ $# -lt 2 ]; then echo "peek-files.sh: --max requires a value" >&2; exit 2; fi
      max="$2"; shift 2
      ;;
    *)
      echo "peek-files.sh: unknown option $1" >&2
      exit 2
      ;;
  esac
done

# Validate integers.
case "$lines" in ''|*[!0-9]*) echo "peek-files.sh: --lines must be a positive integer" >&2; exit 2 ;; esac
case "$max"   in ''|*[!0-9]*) echo "peek-files.sh: --max must be a positive integer" >&2; exit 2 ;; esac

# Enumerate matches via find. Search root is CWD.
list_tmp="$(mktemp)"
trap 'rm -f "$list_tmp"' EXIT

if [ -n "$exclude" ]; then
  find . -type f -name "$pattern" -not -path "*${exclude}*" -print > "$list_tmp"
else
  find . -type f -name "$pattern" -print > "$list_tmp"
fi

count=0
while IFS= read -r f; do
  if [ "$count" -ge "$max" ]; then break; fi
  printf -- '--- %s ---\n' "$f"
  head -n "$lines" -- "$f"
  count=$((count + 1))
done < "$list_tmp"

if [ "$count" -eq 0 ]; then
  exit 1
fi
exit 0
