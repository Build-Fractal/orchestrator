#!/usr/bin/env bash
# Verify references/file-formats.md documents routing.yaml format.
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "routing.yaml" "$f" || { echo "FAIL: missing routing.yaml documentation"; exit 1; }
grep -q "models:" "$f" || { echo "FAIL: missing models block documentation"; exit 1; }
grep -q "classification:" "$f" || { echo "FAIL: missing classification block documentation"; exit 1; }
grep -q "fallback" "$f" || { echo "FAIL: missing fallback documentation"; exit 1; }
grep -q "history_weight" "$f" || { echo "FAIL: missing history_weight documentation"; exit 1; }
grep -q "budget_ceiling_usd" "$f" || { echo "FAIL: missing budget_ceiling_usd documentation"; exit 1; }
echo "PASS: file-formats.md documents routing.yaml"
