#!/usr/bin/env bash
# Verify references/errors.md documents the RESULT: format and emit_result protocol.
set -eu
f="references/errors.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "RESULT:" "$f" || { echo "FAIL: missing RESULT: format documentation"; exit 1; }
grep -q "emit_result" "$f" || { echo "FAIL: missing emit_result protocol documentation"; exit 1; }
grep -q "status" "$f" || { echo "FAIL: missing status field documentation"; exit 1; }
grep -q "error_kind" "$f" || { echo "FAIL: missing error_kind field documentation"; exit 1; }
echo "PASS: errors.md RESULT: format and emit_result protocol"
