#!/usr/bin/env bash
# m020-p03-graduate-reject-path.sh — assert --reject --cluster archives every
# member without writing archived_into and emits decision_history on each.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state"

for id in MEM920 MEM921; do
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
last_verified: 2026-04-25
---

# ${id}: reject fixture
EOF
done

export PROJECT_ROOT="$tmpdir"
export ORCH_ROOT="$tmpdir/orch-state"

if ! bash "$SCRIPT" --reject --cluster Crej --rationale "superseded by M021" \
       MEM920 MEM921 >/dev/null 2>"$tmpdir/err"; then
  echo "FAIL: graduate.sh --reject exited non-zero. stderr:"
  cat "$tmpdir/err"
  exit 1
fi

for id in MEM920 MEM921; do
  status="$(awk '/^---$/{n++; if (n>=2) exit; next} n==1 && /^status:/{sub(/^status:[[:space:]]*/,""); print; exit}' "$tmpdir/knowledge/patterns/${id}.md")"
  if [ "$status" != "archived" ]; then
    echo "FAIL: $id status='$status' after reject, expected archived"
    exit 1
  fi
  if grep -q '^archived_into:' "$tmpdir/knowledge/patterns/${id}.md"; then
    echo "FAIL: $id has archived_into after reject (expected absent)"
    exit 1
  fi
  if ! grep -q '^decision_history:' "$tmpdir/knowledge/patterns/${id}.md"; then
    echo "FAIL: $id missing decision_history after reject"
    exit 1
  fi
  if ! grep -q 'superseded by M021' "$tmpdir/knowledge/patterns/${id}.md"; then
    echo "FAIL: $id decision_history missing rationale text"
    exit 1
  fi
done

echo "PASS: --reject --cluster archives every member without archived_into"
exit 0
