#!/usr/bin/env bash
# Verify docs/getting-started.md documents installation with cross-link.
set -eu
f="docs/getting-started.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi "install" "$f" || { echo "FAIL: missing installation documentation"; exit 1; }
grep -q "installation.md" "$f" || { echo "FAIL: missing cross-link to installation.md"; exit 1; }
grep -qi "spec-kit\|speckit" "$f" || { echo "FAIL: missing spec-kit prerequisite mention"; exit 1; }
echo "PASS: getting-started.md installation section"
