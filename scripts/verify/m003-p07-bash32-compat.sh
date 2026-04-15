#!/usr/bin/env bash
set -eu
files="scripts/migrate/migrate.sh scripts/migrate/transform/milestone-rollup.sh scripts/migrate/transform/active-milestone.sh scripts/migrate/transform/milestone-tiering.sh scripts/migrate/lib/idempotency.sh"
for f in $files; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
done
# Strip comments and blank lines, then scan for Bash 4+ constructs.
hits=0
for f in $files; do
  if grep -nE '^[[:space:]]*[^#].*(declare -A|mapfile|readarray|\|&|\$\{[A-Za-z_][A-Za-z0-9_]*,,\}|\$\{[A-Za-z_][A-Za-z0-9_]*\^\^\})' "$f"; then
    hits=$((hits+1))
  fi
done
if [ "$hits" -gt 0 ]; then
  echo "FAIL: Bash 3.2 incompatible constructs found in migration scripts"
  exit 1
fi
echo "PASS: all modified migration scripts are Bash 3.2 compatible"
