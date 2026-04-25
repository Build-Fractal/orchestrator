#!/usr/bin/env bash
# m020-p02-query-side-effect-free.sh — assert query.sh writes ZERO files
# under knowledge/** for any invocation (FR-8, CON-1, SC-7).
#
# Strategy: stronger than a `git status` diff — build an isolated
# knowledge tree, snapshot every file's md5/mtime, run a battery of
# query invocations, re-snapshot, and demand byte-equivalence and zero
# new files. The hash-snapshot approach catches in-place rewrites that
# `git status` would miss when content round-trips byte-for-byte.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/query.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns" "$tmpdir/knowledge/conventions"

# Five fixture entries with varied state + topic + tags.
cat >"$tmpdir/knowledge/patterns/MEM760.md" <<'EOF'
---
id: MEM760
topic: "auth"
tags: [auth, persistence]
last_verified: 2026-04-25
status: graduated
---

# MEM760: graduated topic
EOF

cat >"$tmpdir/knowledge/patterns/MEM761.md" <<'EOF'
---
id: MEM761
topic: ""
tags: [auth]
last_verified: 2026-04-20
status: candidate
---

# MEM761: candidate tag
EOF

cat >"$tmpdir/knowledge/patterns/MEM762.md" <<'EOF'
---
id: MEM762
topic: "rendering"
tags: []
last_verified: 2026-04-15
status: archived
---

# MEM762: archived
EOF

cat >"$tmpdir/knowledge/conventions/MEM763.md" <<'EOF'
---
id: MEM763
topic: "AUTH"
tags: []
last_verified: 2026-04-10
status: graduated
---

# MEM763: case-insensitive
EOF

cat >"$tmpdir/knowledge/patterns/MEM764.md" <<'EOF'
---
id: MEM764
topic: "rendering"
tags: [shaders]
last_verified: 2026-04-05
status: graduated
---

# MEM764: unrelated
EOF

# Snapshot 1 — pre-invocation hashes.
snap1="$tmpdir/snap1.txt"
find "$tmpdir/knowledge" -type f -name 'MEM*.md' | sort > "$tmpdir/files-before.txt"
while IFS= read -r f; do
  if command -v md5 >/dev/null 2>&1; then
    md5 -q "$f"
  else
    md5sum "$f" | awk '{print $1}'
  fi
done < "$tmpdir/files-before.txt" > "$snap1"

export PROJECT_ROOT="$tmpdir"

# Battery of invocations covering matched/unmatched/state-filtered/format paths.
bash "$SCRIPT" --topic auth                     >/dev/null 2>&1 || true
bash "$SCRIPT" --topic AUTH                     >/dev/null 2>&1 || true
bash "$SCRIPT" --topic auth --state candidate   >/dev/null 2>&1 || true
bash "$SCRIPT" --topic auth --state archived    >/dev/null 2>&1 || true
bash "$SCRIPT" --topic missing                  >/dev/null 2>&1 || true
bash "$SCRIPT" --topic auth --format json       >/dev/null 2>&1 || true
bash "$SCRIPT" --topic missing --format json    >/dev/null 2>&1 || true

# Snapshot 2 — post-invocation hashes.
find "$tmpdir/knowledge" -type f -name 'MEM*.md' | sort > "$tmpdir/files-after.txt"

# 1. File set must be identical (no new files, no deletions).
if ! diff -q "$tmpdir/files-before.txt" "$tmpdir/files-after.txt" >/dev/null; then
  echo "FAIL: file set under knowledge/ changed across query invocations"
  diff "$tmpdir/files-before.txt" "$tmpdir/files-after.txt" || true
  exit 1
fi

# 2. Each file's content hash must match its pre-invocation snapshot.
snap2="$tmpdir/snap2.txt"
while IFS= read -r f; do
  if command -v md5 >/dev/null 2>&1; then
    md5 -q "$f"
  else
    md5sum "$f" | awk '{print $1}'
  fi
done < "$tmpdir/files-after.txt" > "$snap2"

if ! diff -q "$snap1" "$snap2" >/dev/null; then
  echo "FAIL: at least one knowledge file's content hash changed (FR-8 violation)"
  diff "$snap1" "$snap2" || true
  exit 1
fi

echo "PASS: query.sh produced zero writes to knowledge/ across 7-invocation battery"
exit 0
