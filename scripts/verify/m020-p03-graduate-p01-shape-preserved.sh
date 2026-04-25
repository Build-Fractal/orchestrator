#!/usr/bin/env bash
# m020-p03-graduate-p01-shape-preserved.sh — assert the P01 single-entry
# invocation shape continues to work byte-equivalently after the P03 extension.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state"

cat >"$tmpdir/knowledge/patterns/MEM950.md" <<'EOF'
---
id: MEM950
status: candidate
last_verified: 2026-04-25
---

# MEM950: P01 shape fixture
EOF

cat >"$tmpdir/knowledge/patterns/MEM951.md" <<'EOF'
---
id: MEM951
status: graduated
last_verified: 2026-04-25
---

# MEM951: idempotent NO-OP fixture
EOF

cat >"$tmpdir/knowledge/patterns/MEM952.md" <<'EOF'
---
id: MEM952
status: archived
last_verified: 2026-04-25
---

# MEM952: archived FAIL fixture
EOF

export PROJECT_ROOT="$tmpdir"
export ORCH_ROOT="$tmpdir/orch-state"

# Case 1: candidate -> graduated.
set +e
out1="$(bash "$SCRIPT" --rationale "p01-shape" MEM950 2>&1)"
rc1=$?
set -e
if [ "$rc1" -ne 0 ]; then
  echo "FAIL: P01 single-entry candidate path exited $rc1. Output: $out1"
  exit 1
fi
status1="$(awk '/^---$/{n++; if (n>=2) exit; next} n==1 && /^status:/{sub(/^status:[[:space:]]*/,""); print; exit}' "$tmpdir/knowledge/patterns/MEM950.md")"
if [ "$status1" != "graduated" ]; then
  echo "FAIL: P01 path did not flip MEM950 to graduated. status='$status1'"
  exit 1
fi

# Case 2: idempotent NO-OP on graduated.
set +e
out2="$(bash "$SCRIPT" --rationale "p01-shape" MEM951 2>&1)"
rc2=$?
set -e
if [ "$rc2" -ne 0 ]; then
  echo "FAIL: P01 NO-OP on graduated exited $rc2. Output: $out2"
  exit 1
fi
case "$out2" in
  *"NO-OP"*) ;;
  *)
    echo "FAIL: idempotent re-graduate did not emit NO-OP. Got: $out2"
    exit 1 ;;
esac

# Case 3: archived FAIL.
set +e
out3="$(bash "$SCRIPT" --rationale "p01-shape" MEM952 2>&1)"
rc3=$?
set -e
if [ "$rc3" -eq 0 ]; then
  echo "FAIL: archived re-graduate succeeded (expected non-zero). Output: $out3"
  exit 1
fi

echo "PASS: P01 single-entry shape preserved (candidate flip + NO-OP + archived FAIL)"
exit 0
