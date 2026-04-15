#!/usr/bin/env bash
set -eu
f="commands/migrate.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'AD-13' "$f" || { echo "FAIL: commands/migrate.md missing AD-13 reference"; exit 1; }
grep -q 'AD-14' "$f" || { echo "FAIL: commands/migrate.md missing AD-14 reference"; exit 1; }
grep -q 'AD-15' "$f" || { echo "FAIL: commands/migrate.md missing AD-15 reference"; exit 1; }
grep -q 'resolve-root' "$f" || { echo "FAIL: commands/migrate.md missing resolve-root reference"; exit 1; }
grep -q 'detect-overlap' "$f" || { echo "FAIL: commands/migrate.md missing detect-overlap reference"; exit 1; }
grep -q 'rebuild-index' "$f" || { echo "FAIL: commands/migrate.md missing rebuild-index reference"; exit 1; }
echo "PASS: commands/migrate.md documents AD-13/14/15 and references all three scripts"
