#!/usr/bin/env bash
# scripts/verify/lib/m026-p01-recent-changes-region.sh
# Helper: extracts the body between the orchestrator:recent-changes markers
# in the file passed as $1, printing it to stdout. Exits 0 on success, 1 if
# the file is missing or the markers are absent. No compound inline bash —
# callers source the output via a single-command substitution.
#
# Bash 3.2 safe (MEM001). AD-19 single-script-file shape.

set -u

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <path-to-md-file>" >&2
  exit 1
fi

src="$1"

if [ ! -f "$src" ]; then
  echo "ERROR: file not found: ${src}" >&2
  exit 1
fi

# awk extracts lines strictly between the begin/end markers.
awk '
  /^# >>> orchestrator:recent-changes >>>/ { inside=1; next }
  /^# <<< orchestrator:recent-changes <<</  { inside=0; next }
  inside { print }
' "$src"
