#!/usr/bin/env bash
# Verify docs/hook-development.md documents verdict protocol, testing, debugging, and examples.
set -eu
f="docs/hook-development.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "PRE_DISPATCH" "$f" || { echo "FAIL: missing PRE_DISPATCH lifecycle point"; exit 1; }
grep -q "POST_DISPATCH" "$f" || { echo "FAIL: missing POST_DISPATCH lifecycle point"; exit 1; }
grep -q "POST_VERIFY" "$f" || { echo "FAIL: missing POST_VERIFY lifecycle point"; exit 1; }
grep -q "PRE_ADVANCE" "$f" || { echo "FAIL: missing PRE_ADVANCE lifecycle point"; exit 1; }
grep -q "PASS" "$f" || { echo "FAIL: missing PASS verdict type"; exit 1; }
grep -q "BLOCK" "$f" || { echo "FAIL: missing BLOCK verdict type"; exit 1; }
grep -q "WARN" "$f" || { echo "FAIL: missing WARN verdict type"; exit 1; }
grep -q "NEEDS_REVIEW" "$f" || { echo "FAIL: missing NEEDS_REVIEW verdict type"; exit 1; }
grep -qi "budget.*gate\|budget gate" "$f" || { echo "FAIL: missing budget gate hook example"; exit 1; }
grep -qi "quality.*check\|quality check" "$f" || { echo "FAIL: missing quality check hook example"; exit 1; }
grep -qi "test" "$f" || { echo "FAIL: missing testing section"; exit 1; }
grep -qi "debug" "$f" || { echo "FAIL: missing debugging section"; exit 1; }
grep -q "hooks.md" "$f" || { echo "FAIL: missing cross-link to hooks.md"; exit 1; }
echo "PASS: hook-development.md content documentation"
