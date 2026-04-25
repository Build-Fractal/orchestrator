#!/usr/bin/env bash
# m020-p03-graduate-cluster-multi-entry.sh — assert --cluster three-entry
# graduate flips canonical=graduated, siblings=archived w/ archived_into,
# and decision_history appended on every entry.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state"

for id in MEM900 MEM901 MEM902; do
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
last_verified: 2026-04-25
---

# ${id}: cluster fixture
EOF
done

export PROJECT_ROOT="$tmpdir"
export ORCH_ROOT="$tmpdir/orch-state"

if ! bash "$SCRIPT" --cluster Ctest --rationale "merge - same assertion" \
       MEM900 MEM901 MEM902 >/dev/null 2>"$tmpdir/err"; then
  echo "FAIL: graduate.sh --cluster exited non-zero. stderr:"
  cat "$tmpdir/err"
  exit 1
fi

# Canonical (MEM900) -> graduated.
status_canon="$(awk '/^---$/{n++; if (n>=2) exit; next} n==1 && /^status:/{sub(/^status:[[:space:]]*/,""); print; exit}' "$tmpdir/knowledge/patterns/MEM900.md")"
if [ "$status_canon" != "graduated" ]; then
  echo "FAIL: canonical MEM900 status='$status_canon', expected graduated"
  exit 1
fi

# Siblings (MEM901, MEM902) -> archived + archived_into=MEM900.
for sib in MEM901 MEM902; do
  status_sib="$(awk '/^---$/{n++; if (n>=2) exit; next} n==1 && /^status:/{sub(/^status:[[:space:]]*/,""); print; exit}' "$tmpdir/knowledge/patterns/${sib}.md")"
  if [ "$status_sib" != "archived" ]; then
    echo "FAIL: sibling $sib status='$status_sib', expected archived"
    exit 1
  fi
  archived_into="$(awk '/^---$/{n++; if (n>=2) exit; next} n==1 && /^archived_into:/{sub(/^archived_into:[[:space:]]*/,""); print; exit}' "$tmpdir/knowledge/patterns/${sib}.md")"
  if [ "$archived_into" != "MEM900" ]; then
    echo "FAIL: sibling $sib archived_into='$archived_into', expected MEM900"
    exit 1
  fi
done

# All three -> decision_history block present with rationale text.
for id in MEM900 MEM901 MEM902; do
  if ! grep -q '^decision_history:' "$tmpdir/knowledge/patterns/${id}.md"; then
    echo "FAIL: $id missing decision_history block"
    exit 1
  fi
  if ! grep -q 'merge - same assertion' "$tmpdir/knowledge/patterns/${id}.md"; then
    echo "FAIL: $id decision_history missing rationale text"
    exit 1
  fi
done

echo "PASS: --cluster multi-entry graduate flow (canonical+siblings+archived_into+decision_history)"
exit 0
