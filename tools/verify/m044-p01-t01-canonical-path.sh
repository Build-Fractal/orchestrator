#!/usr/bin/env bash
# tools/verify/m044-p01-t01-canonical-path.sh
# M044/P01/T01 (FR-11/SC-12): exactly one get_index_path()/get_db_path()
# definition, each in its canonical lib; no divergent definition elsewhere.
# Bash 3.2 compatible. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0

# --- get_index_path: exactly one definition, in index-utils.sh ---
idx_defs="$(grep -rlE '^[[:space:]]*get_index_path[[:space:]]*\(\)' scripts/ 2>/dev/null | sort)"
idx_count="$(printf '%s\n' "$idx_defs" | grep -c . )"
if [ "$idx_count" -ne 1 ]; then
  echo "FAIL: expected exactly 1 get_index_path() definition, found $idx_count:"
  printf '  %s\n' $idx_defs
  fail=1
elif [ "$idx_defs" != "scripts/knowledge/lib/index-utils.sh" ]; then
  echo "FAIL: get_index_path() defined in unexpected file: $idx_defs"
  fail=1
fi

# --- get_db_path: exactly one definition, in graph-db.sh ---
db_defs="$(grep -rlE '^[[:space:]]*get_db_path[[:space:]]*\(\)' scripts/ 2>/dev/null | sort)"
db_count="$(printf '%s\n' "$db_defs" | grep -c . )"
if [ "$db_count" -ne 1 ]; then
  echo "FAIL: expected exactly 1 get_db_path() definition, found $db_count:"
  printf '  %s\n' $db_defs
  fail=1
elif [ "$db_defs" != "scripts/knowledge/lib/graph-db.sh" ]; then
  echo "FAIL: get_db_path() defined in unexpected file: $db_defs"
  fail=1
fi

# --- canonical location is documented ---
if ! grep -q 'get_index_path' docs/knowledge-management.md 2>/dev/null; then
  echo "FAIL: canonical index path not documented in docs/knowledge-management.md"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: single canonical get_index_path()/get_db_path() resolvers, documented"
  exit 0
fi
exit 1
