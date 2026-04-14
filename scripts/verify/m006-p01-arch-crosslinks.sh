#!/usr/bin/env bash
# Verify references/architecture.md cross-links to other reference docs via relative paths.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "state-machine.md" "$f" || { echo "FAIL: missing cross-link to state-machine.md"; exit 1; }
grep -q "file-formats.md" "$f" || { echo "FAIL: missing cross-link to file-formats.md"; exit 1; }
grep -q "verification-ladder.md" "$f" || { echo "FAIL: missing cross-link to verification-ladder.md"; exit 1; }
grep -q "tier-definitions.md" "$f" || { echo "FAIL: missing cross-link to tier-definitions.md"; exit 1; }
# Verify links are relative (no absolute paths)
grep -qE "\(/.*references/" "$f" && { echo "FAIL: absolute path found in cross-links (DC-3 violation)"; exit 1; }
echo "PASS: architecture.md cross-links"
