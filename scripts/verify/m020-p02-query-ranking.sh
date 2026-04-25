#!/usr/bin/env bash
# m020-p02-query-ranking.sh — assert FR-2 sub-clause (e):
# topic-field hits rank above tag-only hits; ties broken by last_verified desc.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

# Two topic-field hits with different last_verified, two tag-only hits with
# different last_verified. Expected order:
#   1. MEM720 (topic-field, last_verified=2026-04-20)
#   2. MEM721 (topic-field, last_verified=2026-04-10)
#   3. MEM722 (tag-only,    last_verified=2026-04-15)
#   4. MEM723 (tag-only,    last_verified=2026-04-05)

cat >"$tmpdir/knowledge/patterns/MEM720.md" <<'EOF'
---
id: MEM720
topic: "auth"
tags: []
last_verified: 2026-04-20
status: graduated
---

# MEM720: topic recent
EOF

cat >"$tmpdir/knowledge/patterns/MEM721.md" <<'EOF'
---
id: MEM721
topic: "auth"
tags: []
last_verified: 2026-04-10
status: graduated
---

# MEM721: topic older
EOF

cat >"$tmpdir/knowledge/patterns/MEM722.md" <<'EOF'
---
id: MEM722
topic: ""
tags: [auth]
last_verified: 2026-04-15
status: graduated
---

# MEM722: tag recent
EOF

cat >"$tmpdir/knowledge/patterns/MEM723.md" <<'EOF'
---
id: MEM723
topic: ""
tags: [auth]
last_verified: 2026-04-05
status: graduated
---

# MEM723: tag older
EOF

export PROJECT_ROOT="$tmpdir"
out="$(bash "$SCRIPT" --topic auth 2>/dev/null)"

# Capture the rank order as a single string for comparison.
expected="entry_id=MEM720
entry_id=MEM721
entry_id=MEM722
entry_id=MEM723"

if [ "$out" != "$expected" ]; then
  echo "FAIL: rank order mismatch."
  echo "Expected:"
  echo "$expected"
  echo "Got:"
  echo "$out"
  exit 1
fi

echo "PASS: query.sh ranks topic-field hits above tag hits; ties by last_verified desc"
exit 0
