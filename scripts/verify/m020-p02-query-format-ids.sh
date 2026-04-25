#!/usr/bin/env bash
# m020-p02-query-format-ids.sh — assert default --format ids emits
# `^entry_id=<ID>$` lines only (FR-2 sub-clause f, T01 scope).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

cat >"$tmpdir/knowledge/patterns/MEM730.md" <<'EOF'
---
id: MEM730
topic: "auth"
tags: []
last_verified: 2026-04-25
status: graduated
---

# MEM730: ids fixture
EOF

export PROJECT_ROOT="$tmpdir"
out="$(bash "$SCRIPT" --topic auth 2>/dev/null)"

if ! printf '%s\n' "$out" | grep -qx 'entry_id=MEM730'; then
  echo "FAIL: ids format did not emit ^entry_id=MEM730$. Got: $out"
  exit 1
fi

# Also assert NO non-matching prefix lines slipped in.
non_match="$(printf '%s\n' "$out" | grep -v -E '^entry_id=' || true)"
if [ -n "$non_match" ]; then
  echo "FAIL: ids format emitted non-id lines: $non_match"
  exit 1
fi

# Explicit --format ids must produce the same output.
out2="$(bash "$SCRIPT" --topic auth --format ids 2>/dev/null)"
if [ "$out" != "$out2" ]; then
  echo "FAIL: explicit --format ids differs from default. default=$out explicit=$out2"
  exit 1
fi

echo "PASS: --format ids emits entry_id=<ID> lines only (default)"
exit 0
