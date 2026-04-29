#!/usr/bin/env bash
# scripts/util/node-eval.sh -- Run a Node.js script file (not an inline -e body).
#
# Usage: node-eval.sh <script-path> [args...]
#   <script-path> -- path to a .js / .mjs / .cjs file (positional, REQUIRED).
#   [args...]     -- forwarded as positional argv to node.
#
# Output:
#   Whatever the script writes to stdout / stderr.
#
# Exit:
#   0 -- node returned 0.
#   N -- node's exit code (forwarded).
#   2 -- usage / validation error (missing path, file unreadable, -e attempted).
#   127 -- node not on PATH.
#
# Replaces the AP-012 multi-line `node -e "<body>"` shape (M028 FR-16).
# Refuses any `-e` argument to prevent rebuilding the AP-012 shape.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

if [ $# -lt 1 ]; then
  echo "usage: node-eval.sh <script-path> [args...]" >&2
  exit 2
fi

# Defensive guard: reject -e / --eval to keep callers from rebuilding the AP-012 shape.
case "$1" in
  -e|--eval|-p|--print)
    echo "node-eval.sh: -e/-p/--eval/--print are not supported (use a script file)" >&2
    exit 2
    ;;
esac

script_path="$1"
shift

if [ ! -f "$script_path" ]; then
  echo "node-eval.sh: script not found: $script_path" >&2
  exit 2
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node-eval.sh: node not on PATH" >&2
  exit 127
fi

exec node "$script_path" "$@"
