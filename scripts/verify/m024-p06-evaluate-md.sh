#!/usr/bin/env bash
# scripts/verify/m024-p06-evaluate-md.sh
# Asserts commands/evaluate.md revise verb description names the wired P06 surface.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$ROOT/commands/evaluate.md"

[ -f "$DOC" ] || { echo "FAIL: $DOC not found"; exit 1; }

# Must mention the wired-in-P06 status.
grep -q "wired in P06" "$DOC" || { echo "FAIL: 'wired in P06' not in commands/evaluate.md"; exit 1; }

# Must reference the revise.sh script.
grep -q 'scripts/intake/revise.sh' "$DOC" || { echo "FAIL: 'scripts/intake/revise.sh' not referenced in commands/evaluate.md"; exit 1; }

# The legacy "P03 surface-only — full re-emit lands in P06" string must NOT remain.
if grep -q "P03 surface-only" "$DOC"; then
  echo "FAIL: legacy 'P03 surface-only' string still present in commands/evaluate.md — should be replaced by 'wired in P06'"
  exit 1
fi

echo "PASS: commands/evaluate.md — revise verb description names wired in P06 surface"
exit 0
