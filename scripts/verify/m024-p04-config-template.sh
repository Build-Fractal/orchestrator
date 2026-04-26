#!/usr/bin/env bash
# scripts/verify/m024-p04-config-template.sh
# Verifies templates/orchestrator-config-default.yml ships auto_proceed: true
# with the inline documentation block.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
F="$ROOT/templates/orchestrator-config-default.yml"

[ -f "$F" ] || { echo "FAIL: $F missing"; exit 1; }

grep -q '^auto_proceed: true' "$F" \
  || { echo "FAIL: auto_proceed: true default not present in $F"; exit 1; }

grep -q 'fast-path' "$F" \
  || { echo "FAIL: defaults file missing inline 'fast-path' documentation comment"; exit 1; }

grep -q 'FR-3' "$F" \
  || { echo "FAIL: defaults file missing FR-3 anchor in inline documentation"; exit 1; }

echo "PASS: orchestrator-config-default.yml — auto_proceed default + FR-3 inline doc present"
exit 0
