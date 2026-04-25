#!/usr/bin/env bash
# m020-p02-query-match-rule.sh — assert FR-2 sub-clauses (a, b, c):
# topic-field equality (case-insensitive) OR tags[] membership (case-folded).
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"

# MEM710: topic field "auth"; tags empty.
cat >"$tmpdir/knowledge/patterns/MEM710.md" <<'EOF'
---
id: MEM710
topic: "auth"
tags: []
last_verified: 2026-04-25
status: graduated
---

# MEM710: topic-field hit
EOF

# MEM711: topic empty; tags include "Auth" (case mismatch).
cat >"$tmpdir/knowledge/patterns/MEM711.md" <<'EOF'
---
id: MEM711
topic: ""
tags: [Auth, persistence]
last_verified: 2026-04-25
status: graduated
---

# MEM711: tag hit (case-folded)
EOF

# MEM712: topic field different; tags do not include auth.
cat >"$tmpdir/knowledge/patterns/MEM712.md" <<'EOF'
---
id: MEM712
topic: "rendering"
tags: [shaders]
last_verified: 2026-04-25
status: graduated
---

# MEM712: no-match
EOF

# MEM713: topic field "AUTH" (case-insensitive equality must hit).
cat >"$tmpdir/knowledge/patterns/MEM713.md" <<'EOF'
---
id: MEM713
topic: "AUTH"
tags: []
last_verified: 2026-04-25
status: graduated
---

# MEM713: case-insensitive topic hit
EOF

export PROJECT_ROOT="$tmpdir"
out="$(bash "$SCRIPT" --topic auth 2>/dev/null)"

for id in MEM710 MEM711 MEM713; do
  case "$out" in
    *"entry_id=${id}"*) ;;
    *)
      echo "FAIL: expected match ${id} missing. Got: $out"
      exit 1
      ;;
  esac
done

case "$out" in
  *"entry_id=MEM712"*)
    echo "FAIL: non-matching MEM712 leaked. Got: $out"
    exit 1
    ;;
  *) ;;
esac

echo "PASS: query.sh honors topic-field + tags[] match rule (case-insensitive)"
exit 0
