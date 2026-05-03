#!/usr/bin/env bash
# scripts/dispatch/adapters/format/xlsx.sh -- Tier 1 XLSX -> per-sheet CSV adapter.
# Usage: xlsx.sh <input.xlsx> --out-dir <target-dir>
# Delegates to scripts/dispatch/adapters/format/lib/xlsx-to-csv.py
# (openpyxl-based pure-Python shim). Emits one CSV per sheet to
# <target-dir>; stdout lists emitted paths via `CSV:` lines.
# Exit 0 on success, 1 on missing input/args, 2 on missing python3 or openpyxl.
# Run scripts/lifecycle/probe-extraction-tools.sh for install hints.
# Bash 3.2 / POSIX-sh per CON-2.
set -eu
if [ "$#" -lt 3 ]; then
  echo "usage: xlsx.sh <input.xlsx> --out-dir <target-dir>" >&2
  exit 1
fi
input="$1"
if [ ! -f "$input" ]; then
  echo "xlsx.sh: input not found: $input" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "xlsx.sh: python3 not found on PATH" >&2
  exit 2
fi
here="$(cd "$(dirname "$0")" && pwd)"
shim="$here/lib/xlsx-to-csv.py"
if [ ! -f "$shim" ]; then
  echo "xlsx.sh: shim not found at $shim" >&2
  exit 1
fi
python3 "$shim" "$@"
