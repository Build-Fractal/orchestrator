#!/usr/bin/env bash
# scripts/verify/m003-p08-integration-test-exists.sh
# Truth: tests/integration/test-m003-e2e-migration.sh exists, is executable,
# is a non-trivial (>=120 lines) end-to-end test, and mentions the downstream
# integration surfaces it validates (sqlite3 | traverse-graph | derive-phase |
# status.sh).
#
# AD-19 / MEM001 safe. Exit 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
T="$REPO_ROOT/tests/integration/test-m003-e2e-migration.sh"

if [ ! -f "$T" ]; then
  echo "FAIL: $T missing"
  exit 1
fi

if [ ! -x "$T" ]; then
  echo "FAIL: $T not executable"
  exit 1
fi

lines="$(wc -l <"$T" | tr -d ' ')"
if [ "$lines" -lt 120 ]; then
  echo "FAIL: $T too short ($lines lines; expected >= 120)"
  exit 1
fi

if ! grep -qE '(sqlite3|traverse-graph|derive-phase|status\.sh)' "$T"; then
  echo "FAIL: $T does not mention any of: sqlite3, traverse-graph, derive-phase, status.sh"
  exit 1
fi

# Assert skip-gracefully wording is present (contract from phase plan)
if ! grep -q 'lakeledger fixture not present' "$T"; then
  echo "FAIL: $T missing skip-gracefully message 'lakeledger fixture not present'"
  exit 1
fi

echo "PASS: integration test present and non-trivial ($lines lines)"
exit 0
