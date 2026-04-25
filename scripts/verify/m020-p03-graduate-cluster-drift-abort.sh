#!/usr/bin/env bash
# m020-p03-graduate-cluster-drift-abort.sh — assert --cluster aborts atomically
# when any member is not in candidate state (THREAT-006 disposition).
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state"

# Three entries: two candidate, one already graduated (drift).
for trip in "MEM910:candidate" "MEM911:graduated" "MEM912:candidate"; do
  id="${trip%%:*}"
  st="${trip##*:}"
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: ${st}
last_verified: 2026-04-25
---

# ${id}: drift fixture
EOF
done

# Snapshot files BEFORE invocation (md5+size) so we can assert zero mutation.
if command -v md5sum >/dev/null 2>&1; then
  snap_pre="$(find "$tmpdir/knowledge" -name 'MEM*.md' -type f -exec md5sum {} \;)"
else
  snap_pre="$(find "$tmpdir/knowledge" -name 'MEM*.md' -type f -exec md5 -r {} \;)"
fi

export PROJECT_ROOT="$tmpdir"
export ORCH_ROOT="$tmpdir/orch-state"

set +e
out="$(bash "$SCRIPT" --cluster Cdrift --rationale "test" MEM910 MEM911 MEM912 2>&1)"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "FAIL: graduate.sh --cluster did not abort on drift. Output: $out"
  exit 1
fi

case "$out" in
  *"cluster-membership-drift"*) ;;
  *)
    echo "FAIL: drift abort missing 'cluster-membership-drift' diagnostic. Got: $out"
    exit 1
    ;;
esac

# Snapshot files AFTER invocation; assert byte-identical to pre.
if command -v md5sum >/dev/null 2>&1; then
  snap_post="$(find "$tmpdir/knowledge" -name 'MEM*.md' -type f -exec md5sum {} \;)"
else
  snap_post="$(find "$tmpdir/knowledge" -name 'MEM*.md' -type f -exec md5 -r {} \;)"
fi

if [ "$snap_pre" != "$snap_post" ]; then
  echo "FAIL: drift abort mutated files (atomicity violation):"
  printf 'PRE:\n%s\n' "$snap_pre"
  printf 'POST:\n%s\n' "$snap_post"
  exit 1
fi

echo "PASS: cluster-membership-drift abort is atomic (zero file mutations)"
exit 0
