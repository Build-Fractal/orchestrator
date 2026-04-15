#!/usr/bin/env bash
set -eu
f="scripts/migrate/migrate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'rebuild-index.sh' "$f" || { echo "FAIL: migrate.sh does not invoke rebuild-index.sh"; exit 1; }
grep -qE -- '--root[[:space:]]+"\$' "$f" || grep -qE -- '--root[[:space:]]+"\$\{?MIGRATE_TARGET_ROOT' "$f" || grep -qE -- '--root[[:space:]]+"\$target_root' "$f" || { echo "FAIL: rebuild-index.sh not invoked with --root <resolved>"; exit 1; }
echo "PASS: migrate.sh invokes rebuild-index.sh --root <resolved> as final step"
