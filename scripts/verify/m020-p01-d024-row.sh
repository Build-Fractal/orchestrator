#!/usr/bin/env bash
# m020-p01-d024-row.sh — assert D024 row exists in DECISIONS.md and cites
# the load-bearing schema-authority tokens. Bash 3.2 safe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FILE="$ROOT/.orchestrator/DECISIONS.md"

if [ ! -f "$FILE" ]; then
  echo "FAIL: DECISIONS.md missing at $FILE"
  exit 1
fi

if ! grep -qw "D024" "$FILE"; then
  echo "FAIL: D024 row missing from DECISIONS.md"
  exit 1
fi

# The D024 row line must mention status, candidate, graduated, archived, MEM031
line="$(grep "^| D024 " "$FILE" | head -1)"
if [ -z "$line" ]; then
  echo "FAIL: D024 not in pipe-row form (expected '| D024 |' prefix)"
  exit 1
fi

for token in status: candidate graduated archived MEM031 FR-9; do
  case "$line" in
    *"$token"*) ;;
    *)
      echo "FAIL: D024 row missing token: $token"
      exit 1
      ;;
  esac
done

echo "PASS: D024 row present and cites schema-authority tokens"
exit 0
