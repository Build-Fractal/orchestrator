#!/usr/bin/env bash
# Verify docs/getting-started.md documents engine output interpretation.
set -eu
f="docs/getting-started.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi "event" "$f" || { echo "FAIL: missing event output documentation"; exit 1; }
grep -qi "result" "$f" || { echo "FAIL: missing result output documentation"; exit 1; }
grep -qi "state" "$f" || { echo "FAIL: missing state documentation"; exit 1; }
grep -q "events.md" "$f" || { echo "FAIL: missing cross-link to events.md"; exit 1; }
grep -q "engine.md" "$f" || { echo "FAIL: missing cross-link to engine.md"; exit 1; }
echo "PASS: getting-started.md engine output documentation"
