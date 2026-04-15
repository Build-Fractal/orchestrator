#!/usr/bin/env bash
set -eu
f="scripts/migrate/migrate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'resolve-root.sh' "$f" || { echo "FAIL: migrate.sh does not invoke resolve-root.sh"; exit 1; }
grep -q 'MIGRATE_TARGET_ROOT' "$f" || { echo "FAIL: migrate.sh does not export MIGRATE_TARGET_ROOT"; exit 1; }
grep -qE '\-\-absolute' "$f" || { echo "FAIL: migrate.sh does not call resolve-root.sh --absolute"; exit 1; }
echo "PASS: migrate.sh wires resolve-root.sh and exports MIGRATE_TARGET_ROOT"
