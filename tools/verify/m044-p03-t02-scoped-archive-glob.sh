#!/usr/bin/env bash
# tools/verify/m044-p03-t02-scoped-archive-glob.sh
# M044/P03/T02 (FR-4/SC-4/CON-4): a project rooted under a path segment named
# `archive` builds a NON-EMPTY index, while a genuine knowledge/archive/ entry
# stays excluded. Also exercises resolve-entries.sh's scoped glob.
# Bash 3.2. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
# Project root whose ABSOLUTE path contains a segment literally named `archive`.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BASE="$TMP/archive/proj"
mkdir -p "$BASE/knowledge/conventions" "$BASE/knowledge/archive" "$BASE/.orchestrator"

cat > "$BASE/knowledge/conventions/MEM700.md" <<'EOF'
---
id: MEM700
scope_tags: "[project]"
category: conventions
confidence: 0.9
created_at: 2026-06-07
last_verified: 2026-06-07
hit_count: 1
---

# MEM700: Indexed under an archive-rooted path

Body.
EOF

cat > "$BASE/knowledge/archive/MEM701.md" <<'EOF'
---
id: MEM701
scope_tags: "[project]"
category: archive
confidence: 0.9
created_at: 2026-06-07
last_verified: 2026-06-07
hit_count: 1
---

# MEM701: Genuine cold-storage entry

Body.
EOF

bash scripts/knowledge/rebuild-index.sh --root "$BASE" >/dev/null 2>&1

# Index is non-empty (the archive-rooted path did NOT zero it).
if ! grep -qE '^MEM700 ' "$BASE/KNOWLEDGE-INDEX.md" 2>/dev/null; then
  echo "FAIL: MEM700 not indexed — archive-rooted path zeroed the index (B-4 not fixed)"
  fail=1
fi
# Genuine knowledge/archive/ entry stays excluded (CON-4).
if grep -qE '^MEM701 ' "$BASE/KNOWLEDGE-INDEX.md" 2>/dev/null; then
  echo "FAIL: genuine knowledge/archive/ MEM701 leaked into the index (CON-4 violated)"
  fail=1
fi

# resolve-entries.sh reads PROJECT_ROOT via get_project_root (no --root flag).
# MEM700 resolves; MEM701 (genuine knowledge/archive/) does not.
r700="$(PROJECT_ROOT="$BASE" bash scripts/knowledge/resolve-entries.sh MEM700 2>/dev/null)"
if ! printf '%s' "$r700" | grep -qF 'Indexed under an archive-rooted path'; then
  echo "FAIL: resolve-entries.sh did not resolve MEM700 under an archive-rooted path"
  fail=1
fi
r701="$(PROJECT_ROOT="$BASE" bash scripts/knowledge/resolve-entries.sh MEM701 2>/dev/null)"
if printf '%s' "$r701" | grep -qF 'Genuine cold-storage entry'; then
  echo "FAIL: resolve-entries.sh resolved a genuine knowledge/archive/ entry (CON-4 violated)"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: archive-rooted project indexes; genuine knowledge/archive/ excluded (rebuild + resolve)"
  exit 0
fi
exit 1
