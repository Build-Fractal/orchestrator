#!/usr/bin/env bash
# tools/verify/m036-p05-edges-schema-accepts-old.sh — assert that pre-existing
# relates_to and supersedes edge inserts continue to succeed after the M036/P05
# CHECK enum widening. CON-5 regression guard at the schema layer.
#
# T01 of M036/P05: shape verifier for graph-db edges schema (legacy edge types).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
. "$ROOT/scripts/knowledge/lib/graph-db.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
db="$tmpdir/test.db"
db_init "$db"
db_insert_edge "$db" "MEM001" "MEM002" "relates_to"
db_insert_edge "$db" "MEM003" "MEM004" "supersedes"
count="$(sqlite3 "$db" "SELECT COUNT(*) FROM edges;")"
if [ "$count" = "2" ]; then
  echo "PASS: m036-p05-edges-schema-accepts-old (2 legacy-edge rows)"
  exit 0
fi
echo "FAIL: m036-p05-edges-schema-accepts-old (expected 2 rows, got $count)" >&2
exit 1
