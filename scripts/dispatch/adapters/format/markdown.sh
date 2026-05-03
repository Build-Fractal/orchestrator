#!/usr/bin/env bash
# scripts/dispatch/adapters/format/markdown.sh -- Tier 1 markdown passthrough adapter.
# Usage: markdown.sh <input-path>
# Reads <input-path> and emits its content to stdout unchanged. The Tier 1
# contract for already-normalized markdown is "preserve the source body
# verbatim" -- cat is the correct semantic. Exit 0 on success, 1 on missing
# or unreadable input. Bash 3.2 / POSIX-sh per CON-2.
set -eu
if [ "$#" -lt 1 ]; then
  echo "usage: markdown.sh <input-path>" >&2
  exit 1
fi
input="$1"
if [ ! -f "$input" ]; then
  echo "markdown.sh: input not found: $input" >&2
  exit 1
fi
cat "$input"
