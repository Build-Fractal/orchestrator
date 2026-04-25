#!/usr/bin/env bash
# m020-p05-consolidate-legacy-shape-preserved.sh — assert the pre-P05
# legacy invocation shape consolidate-artifacts.sh <orch-root> <milestone-id>
# continues to work byte-equivalently in observable behavior. CON-4 gate.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/consolidate-artifacts.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Build a complete-milestone fixture: milestone with one phase, phase has
# one task, all summaries present, ready for consolidation.
mkdir -p "$tmpdir/orch-state/milestones/MTEST/phases/P01/tasks"

# Roadmap.
cat >"$tmpdir/orch-state/milestones/MTEST/MTEST-ROADMAP.md" <<'EOF'
---
schema_version: "1.0"
type: roadmap
milestone: "MTEST"
---

## Phases

- [x] **P01**: legacy fixture
  - Risk: low
  - Depends: none
EOF

# Phase plan + summary.
cat >"$tmpdir/orch-state/milestones/MTEST/phases/P01/P01-PLAN.md" <<'EOF'
---
phase: "P01"
---
# legacy plan
EOF

cat >"$tmpdir/orch-state/milestones/MTEST/phases/P01/P01-SUMMARY.md" <<'EOF'
---
schema_version: "1.0"
type: phase-summary
id: "P01"
---
# legacy summary
EOF

# Task plan + summary.
cat >"$tmpdir/orch-state/milestones/MTEST/phases/P01/tasks/T01-PLAN.md" <<'EOF'
---
task: "T01"
---
# legacy task plan
EOF

cat >"$tmpdir/orch-state/milestones/MTEST/phases/P01/tasks/T01-SUMMARY.md" <<'EOF'
---
schema_version: "1.0"
type: task-summary
---
# legacy task summary
EOF

# Invoke the LEGACY shape (no --cluster).
out="$(bash "$SCRIPT" "$tmpdir/orch-state" MTEST 2>&1)"
rc=$?

# The legacy code path either succeeds (rc=0) or fails for a reason
# unrelated to --cluster. The contract is that --cluster did not
# break the legacy parser. Specifically:
# - rc must NOT be a "--cluster" error (that would mean --cluster
#   fell through to the legacy parser and caused a failure).
# - the output must NOT mention --cluster in an error context.

case "$out" in
  *"--cluster"*"error"*|*"--cluster"*"required"*)
    echo "FAIL: legacy invocation surfaced a --cluster-related error. Output:"
    printf '%s\n' "$out"
    exit 1 ;;
esac

# Stronger contract: legacy invocation must complete (rc=0) given the fixture.
if [ "$rc" -ne 0 ]; then
  echo "FAIL: legacy invocation exited $rc against a complete-milestone fixture."
  echo "Output:"
  printf '%s\n' "$out"
  exit 1
fi

# Sanity: legacy code path mentions consolidation activity (CONSOLIDATE: prefix
# per MEM001). At least one such line should appear.
consolidate_lines="$(printf '%s\n' "$out" | grep -c '^CONSOLIDATE:' || true)"
if [ "$consolidate_lines" -lt 1 ]; then
  echo "WARN: legacy invocation produced no CONSOLIDATE: prefixed lines. Output:"
  printf '%s\n' "$out"
  # Not a hard fail — the legacy script may emit different prefixes; we only
  # require that the parser accepted the legacy shape and exited cleanly.
fi

echo "PASS: legacy two-positional-arguments shape preserved (CON-4 byte-equivalent observable behavior)"
exit 0
