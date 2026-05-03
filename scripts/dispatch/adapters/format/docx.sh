#!/usr/bin/env bash
# scripts/dispatch/adapters/format/docx.sh -- Tier 1 DOCX text-extraction adapter.
# Usage: docx.sh <input-path>
# Shells out to `pandoc <input> -t plain` (pandoc's plain writer preserves
# heading hierarchy and paragraph breaks per US-6 AS-2). Emits text on stdout.
# Exit 0 on success, 1 on missing input, 2 on missing pandoc.
# Run scripts/lifecycle/probe-extraction-tools.sh for install hints.
# Bash 3.2 / POSIX-sh per CON-2.
set -eu
if [ "$#" -lt 1 ]; then
  echo "usage: docx.sh <input-path>" >&2
  exit 1
fi
input="$1"
if [ ! -f "$input" ]; then
  echo "docx.sh: input not found: $input" >&2
  exit 1
fi
if ! command -v pandoc >/dev/null 2>&1; then
  echo "docx.sh: pandoc not found on PATH; run scripts/lifecycle/probe-extraction-tools.sh for install hints" >&2
  exit 2
fi
pandoc "$input" -t plain
