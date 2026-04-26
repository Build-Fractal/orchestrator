#!/usr/bin/env bash
# scripts/verify/m024-p05-evaluate-md.sh
# M024/P05 verify — commands/evaluate.md empty-shape row mentions qa-loop and empty_qa.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
F="$ROOT/commands/evaluate.md"

[ -f "$F" ] || { echo "FAIL: $F missing"; exit 1; }

grep -q 'empty_qa'  "$F" || { echo "FAIL: commands/evaluate.md missing 'empty_qa'"; exit 1; }
grep -q 'qa-loop'   "$F" || { echo "FAIL: commands/evaluate.md missing reference to qa-loop"; exit 1; }
# Old placeholder text must be gone.
grep -q 'P05+ wires Q&A' "$F" && { echo "FAIL: stale 'P05+ wires Q&A' placeholder still present"; exit 1; }

echo "PASS: commands/evaluate.md — empty-shape row updated to name empty_qa + qa-loop"
exit 0
