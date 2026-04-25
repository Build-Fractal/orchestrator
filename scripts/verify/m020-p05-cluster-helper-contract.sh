#!/usr/bin/env bash
# m020-p05-cluster-helper-contract.sh — assert cluster.sh exposes
# cluster_compute and cluster_id_for with the AD-3 + FR-5 contracts.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/knowledge/lib/cluster.sh"

if [ ! -f "$LIB" ]; then
  echo "FAIL: $LIB does not exist"
  exit 1
fi

# Source the helper in a fresh subshell to detect non-clean source.
out_src="$(bash -c ". '$LIB' && type cluster_compute && type cluster_id_for" 2>&1)"
rc_src=$?
if [ "$rc_src" -ne 0 ]; then
  echo "FAIL: sourcing cluster.sh exited $rc_src. Output: $out_src"
  exit 1
fi
case "$out_src" in
  *"cluster_compute is a function"*) ;;
  *) echo "FAIL: cluster_compute is not exposed as a function. Got: $out_src"; exit 1 ;;
esac
case "$out_src" in
  *"cluster_id_for is a function"*) ;;
  *) echo "FAIL: cluster_id_for is not exposed as a function. Got: $out_src"; exit 1 ;;
esac

# AD-3 ID shape: cluster_id_for emits C<8-hex>.
id1="$(bash -c ". '$LIB' && cluster_id_for 'MEM900,MEM901,MEM902'")"
case "$id1" in
  C[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) echo "FAIL: cluster_id_for output '$id1' does not match C<8-hex> shape"; exit 1 ;;
esac

# Determinism: same input twice -> same output.
id2="$(bash -c ". '$LIB' && cluster_id_for 'MEM900,MEM901,MEM902'")"
if [ "$id1" != "$id2" ]; then
  echo "FAIL: cluster_id_for non-deterministic ('$id1' vs '$id2')"
  exit 1
fi

# Different input -> different output.
id3="$(bash -c ". '$LIB' && cluster_id_for 'MEM910,MEM911'")"
if [ "$id1" = "$id3" ]; then
  echo "FAIL: cluster_id_for collision on distinct inputs ('$id1')"
  exit 1
fi

# cluster_compute on an empty knowledge-root emits no output and exits 0.
empty_dir="$(mktemp -d)"
trap 'rm -rf "$empty_dir"' EXIT
out_empty="$(bash -c ". '$LIB' && cluster_compute '$empty_dir' 0.5" 2>&1)"
rc_empty=$?
if [ "$rc_empty" -ne 0 ]; then
  echo "FAIL: cluster_compute on empty root exited $rc_empty. Output: $out_empty"
  exit 1
fi
if [ -n "$out_empty" ]; then
  echo "FAIL: cluster_compute on empty root emitted output: '$out_empty'"
  exit 1
fi

# cluster_compute on a single-candidate fixture emits one line.
mkdir -p "$empty_dir/patterns"
cat >"$empty_dir/patterns/MEM800.md" <<'EOF'
---
id: MEM800
status: candidate
topic: alpha
tags: [alpha, beta]
---

# MEM800: single candidate fixture
A short body for token extraction.
EOF
out_one="$(bash -c ". '$LIB' && cluster_compute '$empty_dir' 0.5" 2>&1)"
rc_one=$?
if [ "$rc_one" -ne 0 ]; then
  echo "FAIL: cluster_compute on single-candidate fixture exited $rc_one. Output: $out_one"
  exit 1
fi
line_count="$(printf '%s\n' "$out_one" | grep -c '^C[0-9a-f]\{8\}	MEM800$' || true)"
if [ "$line_count" -ne 1 ]; then
  echo "FAIL: cluster_compute on single-candidate fixture did not emit exactly 1 line matching '<cluster-id>\\tMEM800'. Got:"
  printf '%s\n' "$out_one"
  exit 1
fi

echo "PASS: cluster.sh helper contract (function exposure + AD-3 ID shape + determinism + empty + singleton)"
exit 0
