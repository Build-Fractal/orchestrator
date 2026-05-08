#!/usr/bin/env bash
# tools/verify/m035-p015-allowlist-shape.sh
#
# M035/P01.5/T01 verifier — asserts the legacy-namespace allowlist file
# enumerates exactly the 5 historical/migration paths per the M035 roadmap
# Boundary Map, with each path resolving to a file or directory on disk.
#
# Single-script-file shape per AD-19. No compound chains (CON-3 / AP-009).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ALLOWLIST="$REPO_ROOT/tests/m035-acceptance/legacy-namespace-allowlist.txt"
fail=0

if [ ! -f "$ALLOWLIST" ]; then
  echo "FAIL: allowlist file missing at $ALLOWLIST" >&2
  exit 1
fi

line_count=$(wc -l < "$ALLOWLIST" | tr -d ' ')
if [ "$line_count" != "5" ]; then
  echo "FAIL: expected exactly 5 allowlist entries, got $line_count" >&2
  fail=1
fi

for expected in \
  "commands/migrate.md" \
  "docs/migrating-from-speckit.md" \
  "references/RENAME-PLAN.md" \
  "scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt" \
  "scripts/state/namespace-aliases.sh"; do
  if ! grep -qxF "$expected" "$ALLOWLIST"; then
    echo "FAIL: allowlist missing required entry $expected" >&2
    fail=1
  fi
  if [ ! -e "$REPO_ROOT/$expected" ]; then
    echo "FAIL: allowlisted path does not exist on disk: $expected" >&2
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "PASS: m035-p015-allowlist-shape"
  exit 0
fi
exit 1
