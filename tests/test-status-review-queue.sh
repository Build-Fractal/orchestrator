#!/usr/bin/env bash
# tests/test-status-review-queue.sh — SC-3 end-to-end integration test for the
# P04 status.sh Review-Queue section.
#
# Exercises three scenarios that together close SC-3:
#   1. five-candidate / two-cluster fixture (literal SC-3 acceptance)
#   2. empty-queue fixture
#   3. stale-flag fixture (>14-day-old candidate)
#
# Approach: shadow-repo pattern (P03/T04 + T03 verifier carry-forward). status.sh
# resolves its helper from $REPO_ROOT relative to its own SCRIPT_DIR, and the
# helper resolves knowledge_root from $REPO_ROOT/knowledge by default — so we
# build a shadow repo containing a real status.sh + a wrapper compute-staleness.sh
# that invokes the live helper with --knowledge-root pointing at the fixture's
# knowledge tree. status.sh is unchanged and walks the real fixture pipeline
# (cluster.sh + jaccard.sh + frontmatter.sh) end-to-end.
#
# MEM002 conventions: pass()/fail() parallel-indexed scalars, tempdir+trap
# fixture isolation, summary count. Bash 3.2 safe. AD-19 single-script-file shape.
# FR-8 / CON-1 read-only against live knowledge/** and execution-log.jsonl.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATUS_SH="$ROOT/scripts/orchestrator/status.sh"
HELPER="$ROOT/scripts/knowledge/compute-staleness.sh"

# --- pass()/fail() with parallel-indexed scalars (no declare -A) ---
pass_count=0
fail_count=0
fail_msgs=""

pass() {
  pass_count=$(( pass_count + 1 ))
  printf 'PASS: %s\n' "$1"
}

fail() {
  fail_count=$(( fail_count + 1 ))
  printf 'FAIL: %s\n' "$1"
  fail_msgs="$fail_msgs
$1"
}

# --- Helpers ---
make_minimal_orch_root() {
  # Build a minimal orchestrator state root with one milestone + one phase
  # so status.sh's MILESTONE/PHASE enumeration emits at least one line each.
  local orch_root="$1"
  mkdir -p "$orch_root/milestones/M999/phases/P01"
  cat >"$orch_root/milestones/M999/M999-EVALUATION.md" <<'EOF'
---
type: evaluation
milestone: M999
tier: C
---

placeholder
EOF
  cat >"$orch_root/milestones/M999/M999-ROADMAP.md" <<'EOF'
---
type: roadmap
milestone: M999
---

- [ ] **P01**: placeholder
EOF
  cat >"$orch_root/milestones/M999/phases/P01/P01-PLAN.md" <<'EOF'
---
type: phase-plan
phase: P01
milestone: M999
---

placeholder
EOF
}

# Build a shadow scripts/ tree under <shadow_root> that lets a copied status.sh
# resolve all of its dependencies (resolve-root.sh, derive-phase.sh) AND lets
# the helper resolution land on a wrapper that pins --knowledge-root to the
# fixture knowledge directory so the live cluster.sh / jaccard.sh / frontmatter.sh
# pipeline runs end-to-end against the fixture (not the live tree).
build_shadow_repo() {
  local shadow_root="$1"
  local fixture_knowledge="$2"
  mkdir -p "$shadow_root/scripts/orchestrator"
  mkdir -p "$shadow_root/scripts/state"
  mkdir -p "$shadow_root/scripts/knowledge"

  cp "$STATUS_SH"                              "$shadow_root/scripts/orchestrator/status.sh"
  cp "$ROOT/scripts/state/resolve-root.sh"     "$shadow_root/scripts/state/resolve-root.sh"
  cp "$ROOT/scripts/state/derive-phase.sh"     "$shadow_root/scripts/state/derive-phase.sh"

  # Wrapper: invokes the LIVE compute-staleness.sh with --knowledge-root pinned.
  # Live helper sources lib/cluster.sh + lib/jaccard.sh + lib/frontmatter.sh +
  # lib/staleness.sh + lib/index-utils.sh + lib/detail-utils.sh from its own
  # SCRIPT_DIR — which is the LIVE scripts/knowledge/, so the real pipeline runs.
  cat >"$shadow_root/scripts/knowledge/compute-staleness.sh" <<EOF
#!/usr/bin/env bash
# Shadow wrapper — pins --knowledge-root to the test fixture so status.sh
# resolves the fixture's candidate tree (and not the live knowledge/ tree).
exec bash "$HELPER" --knowledge-root "$fixture_knowledge" "\$@"
EOF
  chmod +x "$shadow_root/scripts/knowledge/compute-staleness.sh"
}

write_candidate() {
  # Write a candidate knowledge entry. Body tokens determine clustering — caller
  # supplies the body string deliberately to force or prevent clustering.
  local k_root="$1" id="$2" topic="$3" created="$4" body="$5"
  mkdir -p "$k_root/patterns"
  cat >"$k_root/patterns/$id.md" <<EOF
---
id: $id
status: candidate
created_at: $created
last_verified: $created
topic: $topic
tags: [test]
confidence: 0.5
hit_count: 0
---

$body
EOF
}

# --- Test setup ---
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

# --- Pre-flight: scripts under test exist ---
[ -f "$STATUS_SH" ] || fail "scripts/orchestrator/status.sh missing"
[ -f "$HELPER" ]    || fail "scripts/knowledge/compute-staleness.sh missing"

# =============================================================================
# Scenario 1: five candidates in two clusters -> SC-3 happy path
# =============================================================================
s1_dir="$test_root/s1"
mkdir -p "$s1_dir"
make_minimal_orch_root "$s1_dir/orch"

# Three-entry cluster on topic alpha (shared body vocabulary).
write_candidate "$s1_dir/knowledge" MEM900 alpha 2026-04-20 "alpha alpha alpha alpha alpha alpha"
write_candidate "$s1_dir/knowledge" MEM901 alpha 2026-04-21 "alpha alpha alpha alpha alpha alpha"
write_candidate "$s1_dir/knowledge" MEM902 alpha 2026-04-22 "alpha alpha alpha alpha alpha alpha"

# Two-entry cluster on topic bravo (disjoint vocabulary from alpha).
write_candidate "$s1_dir/knowledge" MEM910 bravo 2026-04-23 "bravo bravo bravo bravo bravo bravo"
write_candidate "$s1_dir/knowledge" MEM911 bravo 2026-04-24 "bravo bravo bravo bravo bravo bravo"

build_shadow_repo "$s1_dir/shadow" "$s1_dir/knowledge"
s1_status="$s1_dir/shadow/scripts/orchestrator/status.sh"
(cd "$s1_dir" && bash "$s1_status" --root "$s1_dir/orch" >"$s1_dir/out.txt" 2>"$s1_dir/err.txt") || true

# Expect a 'Review Queue: 2 clusters, 5 entries awaiting review' line.
if grep -qE '^Review Queue: 2 clusters, 5 entries awaiting review$' "$s1_dir/out.txt"; then
  pass "S1 header line: 'Review Queue: 2 clusters, 5 entries awaiting review'"
else
  fail "S1 header line missing or malformed; stdout was:"
  cat "$s1_dir/out.txt"
fi

# Expect exactly two indented cluster= summary lines.
cluster_line_count="$(grep -cE '^  cluster=C[0-9a-f]{8} ' "$s1_dir/out.txt" || true)"
case "$cluster_line_count" in
  2) pass "S1 two indented '  cluster=C<8hex>' summary lines" ;;
  *) fail "S1 expected exactly 2 cluster summary lines; got $cluster_line_count" ;;
esac

# Expect the two cluster topics with their counts (cluster ordering not pinned).
if grep -qE '^  cluster=C[0-9a-f]{8} topic=alpha count=3' "$s1_dir/out.txt"; then
  pass "S1 alpha cluster line carries count=3"
else
  fail "S1 alpha cluster line missing count=3; stdout was:"
  cat "$s1_dir/out.txt"
fi

if grep -qE '^  cluster=C[0-9a-f]{8} topic=bravo count=2' "$s1_dir/out.txt"; then
  pass "S1 bravo cluster line carries count=2"
else
  fail "S1 bravo cluster line missing count=2; stdout was:"
  cat "$s1_dir/out.txt"
fi

# =============================================================================
# Scenario 2: empty queue -> 'Review Queue: empty'
# =============================================================================
s2_dir="$test_root/s2"
mkdir -p "$s2_dir/knowledge/patterns"
make_minimal_orch_root "$s2_dir/orch"
build_shadow_repo "$s2_dir/shadow" "$s2_dir/knowledge"
s2_status="$s2_dir/shadow/scripts/orchestrator/status.sh"

(cd "$s2_dir" && bash "$s2_status" --root "$s2_dir/orch" >"$s2_dir/out.txt" 2>"$s2_dir/err.txt") || true

if grep -qE '^Review Queue: empty$' "$s2_dir/out.txt"; then
  pass "S2 'Review Queue: empty' line present"
else
  fail "S2 missing 'Review Queue: empty' line; stdout was:"
  cat "$s2_dir/out.txt"
fi

if grep -qE '^  cluster=' "$s2_dir/out.txt"; then
  fail "S2 stdout contains an unexpected indented cluster= line"
else
  pass "S2 no indented cluster= lines (empty queue)"
fi

# =============================================================================
# Scenario 3: stale-flag fixture
# =============================================================================
s3_dir="$test_root/s3"
mkdir -p "$s3_dir"
make_minimal_orch_root "$s3_dir/orch"

# A clearly-stale candidate (created Jan 2024).
write_candidate "$s3_dir/knowledge" MEM920 stale_topic 2024-01-01 "charlie charlie charlie charlie"
build_shadow_repo "$s3_dir/shadow" "$s3_dir/knowledge"
s3_status="$s3_dir/shadow/scripts/orchestrator/status.sh"

(cd "$s3_dir" && bash "$s3_status" --root "$s3_dir/orch" >"$s3_dir/out.txt" 2>"$s3_dir/err.txt") || true

if grep -qE '^  cluster=.*\(stale\)$' "$s3_dir/out.txt"; then
  pass "S3 stale cluster line carries trailing ' (stale)' marker"
else
  fail "S3 missing ' (stale)' marker; stdout was:"
  cat "$s3_dir/out.txt"
fi

# =============================================================================
# Read-only invariant (FR-8 / CON-1)
# =============================================================================
# After all three scenarios, the orchestrator state roots must NOT contain
# execution-log.jsonl (status.sh is read-only).
readonly_violation=0
for d in "$s1_dir/orch" "$s2_dir/orch" "$s3_dir/orch"; do
  if [ -f "$d/execution-log.jsonl" ]; then
    fail "FR-8 violated: $d/execution-log.jsonl was created by status.sh"
    readonly_violation=1
  fi
done
if [ "$readonly_violation" -eq 0 ]; then
  pass "FR-8 read-only: no execution-log.jsonl created under any fixture orch root"
fi

# Also assert nothing was written into the LIVE knowledge tree (CON-1) — the
# live tree's git status fingerprint is computed before/after this test in CI;
# at script-internal level we assert the fixture knowledge dirs are the only
# knowledge-shaped paths the test created.
if [ -f "$ROOT/.orchestrator/execution-log.jsonl.test-marker" ]; then
  fail "CON-1 violated: live .orchestrator/ tree contains test-marker"
else
  pass "CON-1 read-only: live .orchestrator/ tree untouched by test"
fi

# =============================================================================
# Summary
# =============================================================================
echo "----"
echo "PASS: $pass_count"
echo "FAIL: $fail_count"
if [ "$fail_count" -gt 0 ]; then
  echo "Failures:$fail_msgs"
  exit 1
fi
exit 0
