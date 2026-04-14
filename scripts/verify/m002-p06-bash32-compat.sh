#!/usr/bin/env bash
set -eu
files="scripts/dispatch/classify-complexity.sh scripts/dispatch/select-model.sh"
for f in $files; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
done
grep -rlE 'declare -A|readarray|mapfile' $files && { echo "FAIL: Bash 3.2 incompatible constructs found"; exit 1; }
echo "PASS: all routing scripts are Bash 3.2 compatible"
