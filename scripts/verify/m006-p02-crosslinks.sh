#!/usr/bin/env bash
# Verify P02 docs cross-link to each other and existing refs using relative paths.
set -eu

# engine.md must link to events.md, errors.md, hooks.md, architecture.md
f="references/engine.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "events.md" "$f" || { echo "FAIL: engine.md missing cross-link to events.md"; exit 1; }
grep -q "errors.md" "$f" || { echo "FAIL: engine.md missing cross-link to errors.md"; exit 1; }
grep -q "hooks.md" "$f" || { echo "FAIL: engine.md missing cross-link to hooks.md"; exit 1; }
grep -q "architecture.md" "$f" || { echo "FAIL: engine.md missing cross-link to architecture.md"; exit 1; }

# events.md must link to engine.md, errors.md
f="references/events.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "engine.md" "$f" || { echo "FAIL: events.md missing cross-link to engine.md"; exit 1; }
grep -q "errors.md" "$f" || { echo "FAIL: events.md missing cross-link to errors.md"; exit 1; }

# errors.md must link to events.md, engine.md
f="references/errors.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "events.md" "$f" || { echo "FAIL: errors.md missing cross-link to events.md"; exit 1; }
grep -q "engine.md" "$f" || { echo "FAIL: errors.md missing cross-link to engine.md"; exit 1; }

# hooks.md must link to engine.md, events.md, file-formats.md
f="references/hooks.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "engine.md" "$f" || { echo "FAIL: hooks.md missing cross-link to engine.md"; exit 1; }
grep -q "events.md" "$f" || { echo "FAIL: hooks.md missing cross-link to events.md"; exit 1; }
grep -q "file-formats.md" "$f" || { echo "FAIL: hooks.md missing cross-link to file-formats.md"; exit 1; }

echo "PASS: all P02 cross-links validated"
