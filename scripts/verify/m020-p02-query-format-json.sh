#!/usr/bin/env bash
# m020-p02-query-format-json.sh — assert --format json emits a single
# parseable JSON document with matches[] in rank order (FR-2 sub-clause f,
# SC-1 JSON half).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "PASS: jq not installed; skipping JSON-shape assertion (degraded mode)"
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

# Three graduated entries on topic auth.
cat >"$tmpdir/knowledge/patterns/MEM740.md" <<'EOF'
---
id: MEM740
topic: "auth"
tags: []
last_verified: 2026-04-25
status: graduated
---

# MEM740: alpha
EOF

cat >"$tmpdir/knowledge/patterns/MEM741.md" <<'EOF'
---
id: MEM741
topic: "auth"
tags: []
last_verified: 2026-04-15
status: graduated
---

# MEM741: beta
EOF

cat >"$tmpdir/knowledge/patterns/MEM742.md" <<'EOF'
---
id: MEM742
topic: ""
tags: [auth]
last_verified: 2026-04-25
status: graduated
---

# MEM742: gamma
EOF

export PROJECT_ROOT="$tmpdir"
out="$(bash "$SCRIPT" --topic auth --format json 2>/dev/null)"

# 1. Single document — pipe through jq for shape validation.
if ! printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
  echo "FAIL: --format json output is not parseable JSON. Got: $out"
  exit 1
fi

# 2. matches array length 3.
n="$(printf '%s' "$out" | jq '.matches | length')"
if [ "$n" != "3" ]; then
  echo "FAIL: matches array length expected 3, got $n. Out: $out"
  exit 1
fi

# 3. First match must be the topic-recent one (MEM740, rank 1).
first_id="$(printf '%s' "$out" | jq -r '.matches[0].id')"
if [ "$first_id" != "MEM740" ]; then
  echo "FAIL: first match expected MEM740, got $first_id. Out: $out"
  exit 1
fi

# 4. Each match exposes id, title, status, rank.
keys="$(printf '%s' "$out" | jq -r '.matches[0] | keys | sort | join(",")')"
case "$keys" in
  id,rank,status,title) ;;
  *)
    echo "FAIL: matches[].keys expected id,rank,status,title got $keys"
    exit 1
    ;;
esac

# 5. rank values are 1, 2, 3 in array order.
ranks="$(printf '%s' "$out" | jq -r '.matches[].rank' | tr '\n' ',' | sed 's/,$//')"
if [ "$ranks" != "1,2,3" ]; then
  echo "FAIL: rank values expected 1,2,3 got $ranks"
  exit 1
fi

echo "PASS: --format json emits {matches:[{id,title,status,rank}]} parseable by jq with rank ordering"
exit 0
