#!/usr/bin/env bash
# m020-p02-query-default-state-filter.sh — assert default state filter is
# `graduated` only (FR-2 sub-clause d). Bash 3.2 safe. AD-19 shape compliant.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

# Three entries on topic "auth": one graduated, one candidate, one archived.
for trip in "MEM700:graduated" "MEM701:candidate" "MEM702:archived"; do
  id="${trip%%:*}"
  st="${trip##*:}"
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
topic: "auth"
tags: []
last_verified: 2026-04-25
status: ${st}
---

# ${id}: ${st} fixture
EOF
done

export PROJECT_ROOT="$tmpdir"

out="$(bash "$SCRIPT" --topic auth 2>/dev/null)"

case "$out" in
  *"entry_id=MEM700"*) ;;
  *)
    echo "FAIL: graduated entry MEM700 missing from default-filter result. Got: $out"
    exit 1
    ;;
esac

case "$out" in
  *"entry_id=MEM701"*)
    echo "FAIL: candidate entry MEM701 leaked through default state filter. Got: $out"
    exit 1
    ;;
  *) ;;
esac

case "$out" in
  *"entry_id=MEM702"*)
    echo "FAIL: archived entry MEM702 leaked through default state filter. Got: $out"
    exit 1
    ;;
  *) ;;
esac

echo "PASS: default state filter returns only graduated entries"
exit 0
