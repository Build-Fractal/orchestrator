#!/usr/bin/env bash
# m020-p05-cluster-determinism.sh — assert cluster_compute output is byte-
# identical across two runs against the same fixture.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/knowledge/lib/cluster.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/patterns"

# Three candidates; not all expected to cluster; exact clustering
# depends on the feature vector but determinism is invariant.
for trip in "MEM800:alpha:body about alpha and beta" \
            "MEM801:alpha:body about alpha and gamma" \
            "MEM802:delta:body about delta and epsilon"; do
  id="${trip%%:*}"; rest="${trip#*:}"
  topic="${rest%%:*}"; body="${rest#*:}"
  cat >"$tmpdir/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
topic: ${topic}
tags: [${topic}]
---

# ${id}: determinism fixture
${body}
EOF
done

run1="$(bash -c ". '$LIB' && cluster_compute '$tmpdir' 0.1" 2>&1)"
rc1=$?
run2="$(bash -c ". '$LIB' && cluster_compute '$tmpdir' 0.1" 2>&1)"
rc2=$?

if [ "$rc1" -ne 0 ] || [ "$rc2" -ne 0 ]; then
  echo "FAIL: cluster_compute exited non-zero ($rc1, $rc2). Outputs:"
  printf 'run1:\n%s\nrun2:\n%s\n' "$run1" "$run2"
  exit 1
fi

if [ "$run1" != "$run2" ]; then
  echo "FAIL: cluster_compute output is not deterministic across runs"
  echo "----- run1 -----"; printf '%s\n' "$run1"
  echo "----- run2 -----"; printf '%s\n' "$run2"
  exit 1
fi

echo "PASS: cluster_compute is deterministic (run1 == run2 byte-for-byte)"
exit 0
