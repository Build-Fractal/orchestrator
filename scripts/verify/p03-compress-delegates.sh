#!/usr/bin/env bash
set -eu
f="scripts/dispatch/compress-payload.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'payload-transforms.sh' "$f" || { echo "FAIL: $f does not source payload-transforms.sh"; exit 1; }
grep -q 'manifest-builder.sh' "$f" || { echo "FAIL: $f does not source manifest-builder.sh"; exit 1; }
echo "PASS: compress-payload.sh delegates to lib functions"
