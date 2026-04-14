#!/usr/bin/env bash
# Verify references/file-formats.md documents hooks.yaml format.
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "hooks.yaml" "$f" || { echo "FAIL: missing hooks.yaml documentation"; exit 1; }
grep -q "PRE_DISPATCH" "$f" || { echo "FAIL: missing PRE_DISPATCH lifecycle point"; exit 1; }
grep -q "POST_DISPATCH" "$f" || { echo "FAIL: missing POST_DISPATCH lifecycle point"; exit 1; }
grep -q "POST_VERIFY" "$f" || { echo "FAIL: missing POST_VERIFY lifecycle point"; exit 1; }
grep -q "PRE_ADVANCE" "$f" || { echo "FAIL: missing PRE_ADVANCE lifecycle point"; exit 1; }
grep -q "block_on_fail" "$f" || { echo "FAIL: missing block_on_fail field"; exit 1; }
echo "PASS: file-formats.md documents hooks.yaml"
