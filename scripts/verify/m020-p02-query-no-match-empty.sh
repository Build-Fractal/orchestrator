#!/usr/bin/env bash
# m020-p02-query-no-match-empty.sh — assert empty-result diagnostic per
# US-1 acceptance scenario 3 (returns empty structured result with a
# no-matches diagnostic field; does NOT error).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

# One unrelated graduated entry.
cat >"$tmpdir/knowledge/patterns/MEM750.md" <<'EOF'
---
id: MEM750
topic: "rendering"
tags: [shaders]
last_verified: 2026-04-25
status: graduated
---

# MEM750: unrelated
EOF

export PROJECT_ROOT="$tmpdir"

# 1. ids format: empty result with diagnostic; exit 0.
out_ids="$(bash "$SCRIPT" --topic auth 2>/dev/null)"
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: --topic auth (no matches) exited $rc; expected 0"
  exit 1
fi
case "$out_ids" in
  *"no-matches=true"*) ;;
  *)
    echo "FAIL: ids no-match output missing no-matches=true. Got: $out_ids"
    exit 1
    ;;
esac

# 2. json format: parseable JSON with empty matches[] and no_matches=true.
out_json="$(bash "$SCRIPT" --topic auth --format json 2>/dev/null)"
case "$out_json" in
  *'"matches": []'*) ;;
  *'"matches":[]'*) ;;
  *)
    echo "FAIL: json no-match output missing empty matches[]. Got: $out_json"
    exit 1
    ;;
esac
case "$out_json" in
  *'"no_matches": true'*) ;;
  *'"no_matches":true'*) ;;
  *)
    echo "FAIL: json no-match output missing no_matches:true. Got: $out_json"
    exit 1
    ;;
esac

echo "PASS: empty-result diagnostic emitted for both ids and json formats; exit 0"
exit 0
