#!/usr/bin/env bash
# m020-p05-consolidate-cluster-emit.sh — assert consolidate-artifacts.sh
# --cluster emits human-readable cluster blocks with cluster_id= + indent
# member= lines, and the cluster IDs match the AD-3 C<8-hex> shape.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/consolidate-artifacts.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state/milestones/MTEST"

# Three candidates: two near-duplicates + one distinct. Threshold low.
cat >"$tmpdir/knowledge/patterns/MEM800.md" <<'EOF'
---
id: MEM800
status: candidate
topic: shared-cluster
tags: [shared, alpha, beta]
relates_to: [MEM801]
source_unit: M999/P01
---

# MEM800: cluster-A entry one
shared body alpha beta gamma delta common-tokens for clustering
EOF

cat >"$tmpdir/knowledge/patterns/MEM801.md" <<'EOF'
---
id: MEM801
status: candidate
topic: shared-cluster
tags: [shared, alpha, beta]
relates_to: [MEM800]
source_unit: M999/P01
---

# MEM801: cluster-A entry two
shared body alpha beta gamma delta common-tokens for clustering
EOF

cat >"$tmpdir/knowledge/patterns/MEM802.md" <<'EOF'
---
id: MEM802
status: candidate
topic: distinct
tags: [distinct]
relates_to: []
source_unit: M999/P02
---

# MEM802: distinct entry
unique body epsilon zeta eta theta nothing-in-common
EOF

export PROJECT_ROOT="$tmpdir"

out="$(bash "$SCRIPT" --cluster "$tmpdir/orch-state" MTEST "$tmpdir/knowledge" 0.1 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: consolidate-artifacts.sh --cluster exited $rc. Output:"
  printf '%s\n' "$out"
  exit 1
fi

# At least one cluster_id= line matching AD-3 shape.
cluster_lines="$(printf '%s\n' "$out" | grep -E '^cluster_id=C[0-9a-f]{8}$' | wc -l | awk '{print $1}')"
if [ "$cluster_lines" -lt 1 ]; then
  echo "FAIL: no cluster_id=C<8-hex> lines in output:"
  printf '%s\n' "$out"
  exit 1
fi

# Each member listed exactly once with two-space indent.
member_lines="$(printf '%s\n' "$out" | grep -E '^  member=MEM[0-9]+$' | wc -l | awk '{print $1}')"
if [ "$member_lines" -ne 3 ]; then
  echo "FAIL: expected 3 member= lines, got $member_lines. Output:"
  printf '%s\n' "$out"
  exit 1
fi

# Check no member appears twice.
dup="$(printf '%s\n' "$out" | grep -E '^  member=MEM[0-9]+$' | LC_ALL=C sort | uniq -d | wc -l | awk '{print $1}')"
if [ "$dup" -ne 0 ]; then
  echo "FAIL: $dup duplicate member lines. Output:"
  printf '%s\n' "$out"
  exit 1
fi

echo "PASS: consolidate-artifacts.sh --cluster emits cluster_id= + member= lines with AD-3 shape"
exit 0
