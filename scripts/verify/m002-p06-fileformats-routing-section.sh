#!/usr/bin/env bash
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi 'routing' "$f" || { echo "FAIL: file-formats.md does not mention routing"; exit 1; }
grep -q 'routing.yaml' "$f" || { echo "FAIL: file-formats.md does not document routing.yaml"; exit 1; }
grep -q 'models' "$f" || { echo "FAIL: file-formats.md routing section missing models description"; exit 1; }
grep -q 'classification' "$f" || { echo "FAIL: file-formats.md routing section missing classification description"; exit 1; }
grep -q 'history_weight\|budget_ceiling' "$f" || { echo "FAIL: file-formats.md routing section missing top-level config fields"; exit 1; }
echo "PASS: references/file-formats.md documents routing.yaml format"
