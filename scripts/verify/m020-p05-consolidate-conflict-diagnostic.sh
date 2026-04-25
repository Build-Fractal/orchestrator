#!/usr/bin/env bash
# m020-p05-consolidate-conflict-diagnostic.sh — assert consolidate-artifacts.sh
# --cluster surfaces a `conflict:` line when a proposed cluster contains
# entries with mixed decision_history state (one with history, one without).
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/consolidate-artifacts.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state/milestones/MTEST"

# Two near-duplicates: one with decision_history, one without.
# This represents the operator-archived-once-then-resurrected scenario.
cat >"$tmpdir/knowledge/patterns/MEM900.md" <<'EOF'
---
id: MEM900
status: candidate
topic: shared-conflict
tags: [shared, alpha]
relates_to: [MEM901]
source_unit: M999/P01
decision_history:
  - {ts: "2026-04-25T00:00:00Z", rationale: "prior decision", operator: "user@test", cluster_id: "Cprior", rationale_hash: "abcd1234"}
---

# MEM900: prior-history member
shared body alpha beta gamma delta epsilon zeta common
EOF

cat >"$tmpdir/knowledge/patterns/MEM901.md" <<'EOF'
---
id: MEM901
status: candidate
topic: shared-conflict
tags: [shared, alpha]
relates_to: [MEM900]
source_unit: M999/P01
---

# MEM901: pristine member
shared body alpha beta gamma delta epsilon zeta common
EOF

export PROJECT_ROOT="$tmpdir"

out="$(bash "$SCRIPT" --cluster "$tmpdir/orch-state" MTEST "$tmpdir/knowledge" 0.1 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: consolidate-artifacts.sh --cluster exited $rc. Output:"
  printf '%s\n' "$out"
  exit 1
fi

# Find the conflict line.
conflict_lines="$(printf '%s\n' "$out" | grep -c '^conflict: cluster=C[0-9a-f]\{8\} reason=divergent-decision-history$' || true)"
if [ "$conflict_lines" -lt 1 ]; then
  echo "FAIL: no conflict: line in output. Output:"
  printf '%s\n' "$out"
  exit 1
fi

echo "PASS: --cluster surfaces conflict: cluster=<id> reason=divergent-decision-history"
exit 0
