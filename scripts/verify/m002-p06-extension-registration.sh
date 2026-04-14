#!/usr/bin/env bash
set -eu
f="extension.yml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'scripts/dispatch/classify-complexity.sh' "$f" || { echo "FAIL: classify-complexity.sh not registered in extension.yml"; exit 1; }
grep -q 'scripts/dispatch/select-model.sh' "$f" || { echo "FAIL: select-model.sh not registered in extension.yml"; exit 1; }
echo "PASS: extension.yml registers both routing scripts"
