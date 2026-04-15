#!/usr/bin/env bash
# scripts/verify/m003-p08-p07-still-green.sh
# Truth: P07 verification suite still passes after P08 test harness is in
# place. Iterates every scripts/verify/m003-p07-*.sh and asserts each exits 0.
#
# The iteration lives inside this single-script-file so every Check: command
# at the call site stays AD-19-safe.
#
# MEM001 safe. Exit 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_DIR="$REPO_ROOT/scripts/verify"

count=0
for f in "$VERIFY_DIR"/m003-p07-*.sh; do
  [ -f "$f" ] || continue
  count=$((count + 1))
  if ! bash "$f" >/dev/null 2>&1; then
    echo "FAIL: P07 regression -- $(basename "$f") exited non-zero"
    echo "Rerun: bash $f" >&2
    exit 1
  fi
done

if [ "$count" -lt 1 ]; then
  echo "FAIL: no m003-p07-*.sh scripts found under $VERIFY_DIR"
  exit 1
fi

echo "PASS: P07 green ($count script(s))"
exit 0
