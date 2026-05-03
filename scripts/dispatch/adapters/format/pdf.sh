#!/usr/bin/env bash
# scripts/dispatch/adapters/format/pdf.sh -- Tier 1 PDF text-extraction adapter.
# Usage: pdf.sh <input-path>
# Shells out to `pdftotext -layout <input> -` (poppler-utils). -layout
# preserves visual ordering, which matters for tabular regulatory PDFs.
# Exit 0 on success, 1 on missing input, 2 on missing pdftotext.
# Run scripts/lifecycle/probe-extraction-tools.sh for install hints.
# Bash 3.2 / POSIX-sh per CON-2.
set -eu
if [ "$#" -lt 1 ]; then
  echo "usage: pdf.sh <input-path>" >&2
  exit 1
fi
input="$1"
if [ ! -f "$input" ]; then
  echo "pdf.sh: input not found: $input" >&2
  exit 1
fi
if ! command -v pdftotext >/dev/null 2>&1; then
  echo "pdf.sh: pdftotext not found on PATH; run scripts/lifecycle/probe-extraction-tools.sh for install hints" >&2
  exit 2
fi
pdftotext -layout "$input" -
