#!/usr/bin/env bash
# tools/verify/m036-p05-edges-schema-accepts-new.sh — assert the widened
# CHECK enum accepts cites / derived_from / applies_to_field inserts.
#
# T01 of M036/P05: shape verifier for graph-db edges schema CHECK widening.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
. "$ROOT/scripts/knowledge/lib/graph-db.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
db="$tmpdir/test.db"
db_init "$db"
db_insert_edge "$db" "SPEC-A" "REF-B" "cites"
db_insert_edge "$db" "REF-C" "REF-D" "derived_from"
db_insert_edge "$db" "REF-E" "staff_count" "applies_to_field"
count="$(sqlite3 "$db" "SELECT COUNT(*) FROM edges;")"
if [ "$count" = "3" ]; then
  echo "PASS: m036-p05-edges-schema-accepts-new (3 new-edge rows)"
  exit 0
fi
echo "FAIL: m036-p05-edges-schema-accepts-new (expected 3 rows, got $count)" >&2
exit 1
