---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M020"
name: "integration test (tests/test-status-review-queue.sh) — SC-3 end-to-end"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01: `scripts/knowledge/compute-staleness.sh --review-queue [--knowledge-root <path>]` ships the FR-4 review-queue computation. Exit 0 + `EMPTY` sentinel on empty; exit 0 + `cluster_id=...` lines on non-empty.
- T02: `scripts/orchestrator/status.sh` ships the `Review Queue:` section rendering: `Review Queue: <N> clusters, <M> entries awaiting review` + indented per-cluster lines on non-empty; `Review Queue: empty` on empty; `Review Queue: unavailable` on helper failure. Pre-P04 prefix preserved byte-equivalent.
- T03 (parallel-eligible but lands before T04 in sequential dispatch): the per-truth contract verifiers. T04 does NOT depend on T03 directly — the integration test asserts the SC-3 end-to-end path through `status.sh`, not the per-truth shapes individually. (Per-truth verifiers cover narrower assertions; T04 covers the spec-level success criterion.)
- P03/T04 carry-forward: tempdir + `PROJECT_ROOT` + `ORCH_ROOT` env-override fixture isolation is the load-bearing pattern. The test file uses `set -u` (NOT `set -e`), MEM002 `pass()` / `fail()` parallel-indexed scalars, and tempdir + trap-EXIT-rm-rf for fixture isolation.
- P05 cluster.sh "distinct-vocabulary fixture pattern" carry-forward: candidates that should cluster MUST share most body tokens; candidates that should NOT cluster MUST use wholly disjoint vocabularies (boilerplate words like `distinct`, `body`, `fixture`, `for`, `unique` co-cluster spuriously at the 0.7 default threshold).

## Description

Create `tests/test-status-review-queue.sh` — the SC-3 end-to-end integration test for P04. The test exercises `scripts/orchestrator/status.sh` directly (not through any dispatch wrapper) across three SC-3-relevant scenarios:

1. **Five-candidate / two-cluster fixture** (the literal SC-3 acceptance scenario): five `status: candidate` entries arranged as a three-entry cluster on topic A and a two-entry cluster on topic B. Expected stdout: `Review Queue: 2 clusters, 5 entries awaiting review` + exactly two indented `  cluster=` summary lines.
2. **Empty-queue fixture**: zero candidate entries. Expected stdout: `Review Queue: empty` (single line, no indented per-cluster lines).
3. **Stale-flag fixture**: one candidate with `created_at:` set to a date >30 days before the test reference date. Expected: the cluster line for that entry's cluster carries the trailing ` (stale)` marker.

Optionally (degraded-mode soft pass per MEM001 — jq is optional):

- if `jq` is available, no JSONL records should be present at `<orch-root>/execution-log.jsonl` post-invocation (FR-8 read-only assertion).
- if `jq` is absent, fall back to `[ ! -f "<orch-root>/execution-log.jsonl" ]`.

Out of scope:

- Per-truth shape coverage (T03's verifiers).
- Live-tree mutation. Every test case uses tempdir + fixture-only fixtures.
- Cross-cluster ordering assertions beyond "exactly two cluster summary lines for the 2-cluster case" (cluster ordering is by deterministic AD-3 cluster_id ascending; the test does not pin which cluster comes first).

## Steps

### Step 1: Create `tests/test-status-review-queue.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/tests/test-status-review-queue.sh`

```bash
#!/usr/bin/env bash
# tests/test-status-review-queue.sh — SC-3 end-to-end integration test for the
# P04 status.sh Review-Queue section.
#
# Exercises three scenarios that together close SC-3:
#   1. five-candidate / two-cluster fixture (literal SC-3 acceptance)
#   2. empty-queue fixture
#   3. stale-flag fixture (>14-day-old candidate)
#
# MEM002 conventions: pass()/fail() parallel-indexed scalars, tempdir+trap
# fixture isolation, summary count. Bash 3.2 safe. AD-19 single-script-file shape.

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
[ -f "$STATUS_SH" ] || { fail "scripts/orchestrator/status.sh missing"; }
[ -f "$HELPER" ]    || { fail "scripts/knowledge/compute-staleness.sh missing"; }

# =============================================================================
# Scenario 1: five candidates in two clusters -> SC-3 happy path
# =============================================================================
s1_dir="$test_root/s1"
mkdir -p "$s1_dir"
make_minimal_orch_root "$s1_dir/orch"

# Three-entry cluster on topic alpha (shared body vocabulary).
write_candidate "$s1_dir/knowledge" MEM900 alpha 2026-04-01 "alpha alpha alpha alpha alpha alpha"
write_candidate "$s1_dir/knowledge" MEM901 alpha 2026-04-02 "alpha alpha alpha alpha alpha alpha"
write_candidate "$s1_dir/knowledge" MEM902 alpha 2026-04-03 "alpha alpha alpha alpha alpha alpha"

# Two-entry cluster on topic bravo (disjoint vocabulary from alpha).
write_candidate "$s1_dir/knowledge" MEM910 bravo 2026-04-04 "bravo bravo bravo bravo bravo bravo"
write_candidate "$s1_dir/knowledge" MEM911 bravo 2026-04-05 "bravo bravo bravo bravo bravo bravo"

(cd "$s1_dir" && bash "$STATUS_SH" --root "$s1_dir/orch" >"$s1_dir/out.txt" 2>"$s1_dir/err.txt") || true

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

# Expect each cluster line carries 'count=' with integer.
if grep -qE '^  cluster=C[0-9a-f]{8} topic=alpha count=3 oldest_age=[0-9]+ ' "$s1_dir/out.txt" \
   || grep -qE '^  cluster=C[0-9a-f]{8} topic=alpha count=3' "$s1_dir/out.txt"; then
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

(cd "$s2_dir" && bash "$STATUS_SH" --root "$s2_dir/orch" >"$s2_dir/out.txt" 2>"$s2_dir/err.txt") || true

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

(cd "$s3_dir" && bash "$STATUS_SH" --root "$s3_dir/orch" >"$s3_dir/out.txt" 2>"$s3_dir/err.txt") || true

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
for d in "$s1_dir/orch" "$s2_dir/orch" "$s3_dir/orch"; do
  if [ -f "$d/execution-log.jsonl" ]; then
    fail "FR-8 violated: $d/execution-log.jsonl was created by status.sh"
  fi
done
pass "FR-8 read-only: no execution-log.jsonl created under any fixture orch root"

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
```

`chmod +x tests/test-status-review-queue.sh`.

### Step 2: Smoke + dependency note

The test file invokes `bash scripts/orchestrator/status.sh --root <fixture-orch>` and `bash scripts/knowledge/compute-staleness.sh --review-queue --knowledge-root <fixture-k>` indirectly (through status.sh's helper-spawn). It also depends on `scripts/knowledge/lib/cluster.sh` and `scripts/knowledge/lib/jaccard.sh` shipping correctly (P05). All four are on main; no new file dependency from T04 beyond T01 + T02.

> **Implementation note — fixture body vocabulary**: per the P05/T04 carry-forward "distinct-vocabulary fixture pattern", scenario 1's two clusters MUST use disjoint body tokens (`alpha alpha ...` vs `bravo bravo ...`) so that the 0.7 default similarity threshold preserves them as two clusters rather than collapsing into one. Repetition of the cluster's distinguishing token (six times each) ensures the cluster's signal dominates the small first-paragraph body window.

> **Implementation note — `cd "$s1_dir"` before invocation**: status.sh + compute-staleness.sh resolve `.orchestrator/preferences.yml` from `$PWD`. `cd` into the fixture so the test does not accidentally inherit the repo's preferences file. The test does not write `preferences.yml` into any fixture, so all threshold resolutions fall back to defaults (14-day staleness, 0.7 similarity).

> **Implementation note — `--root` flag on status.sh**: per the on-main `status.sh` (line 30-44) the `--root <dir>` flag is the documented override. The test passes `<fixture>/orch` so milestone/phase enumeration runs against the fixture, not against the live `.orchestrator/` tree.

## Must-Haves

- `tests/test-status-review-queue.sh` exists, is executable, and exits 0 against the on-main scripts after T01 + T02 land.
- The test exercises three scenarios:
  1. Five-candidate / two-cluster fixture → asserts `Review Queue: 2 clusters, 5 entries awaiting review` header + exactly two indented `  cluster=` summary lines + per-cluster `count=3` (alpha) / `count=2` (bravo).
  2. Empty-queue fixture → asserts `Review Queue: empty` line + no indented cluster= lines.
  3. Stale-flag fixture → asserts the cluster summary line carries the trailing ` (stale)` marker.
- The test asserts FR-8 read-only: no `execution-log.jsonl` is created under any fixture orchestrator state root.
- MEM002 conventions: `pass()` / `fail()` parallel-indexed scalars, tempdir + trap-EXIT-rm-rf, summary count + non-zero exit on any failure.
- Bash 3.2 safe; AD-19 single-script-file shape on the directly-invoked Check (`bash tests/test-status-review-queue.sh`); internals may use heredocs / pipes / awk / case-glob (P03/T04 + P05/T04 carry-forward).
- The live `knowledge/**` tree and live `.orchestrator/execution-log.jsonl` are NEVER touched.

## Verification

```
bash tests/test-status-review-queue.sh
```

Must print one or more `PASS:` lines, end with a summary `PASS: <N>` / `FAIL: 0`, and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/compute-staleness.sh` (M020/P04/T01)
  - Key API: `--review-queue [--knowledge-root <path>]` mode; stdout contract `EMPTY` or one `cluster_id=...` line per cluster. Used indirectly by status.sh.
- `scripts/orchestrator/status.sh` (M020/P04/T02)
  - Key API: `bash status.sh --root <orch-root>`; emits `MILESTONE:` / `STATE:` / `PHASE:` lines + Review-Queue section. The test invokes this script directly across three fixtures.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/cluster.sh` (M020/P05) — used indirectly by compute-staleness.sh; the test verifies the integration via fixture invocations.
- `scripts/knowledge/lib/jaccard.sh` (M020/P01 + extended P05) — used indirectly. The test's fixture body strings (`alpha alpha alpha ...`, `bravo bravo bravo ...`) deliberately use disjoint single-token vocabularies to force the two-cluster split at the 0.7 threshold.
- `scripts/state/derive-phase.sh` (M001) — invoked by status.sh internally to derive each milestone's state. The fixture milestone has a P01 plan but no summary, so the derived state will be `executing` — the test does not pin the exact state word, only that `STATE:` and `PHASE:` lines exist.
- `tests/test-graduate-workflow.sh` (M020/P03/T04) — reference example for tempdir + `pass()` / `fail()` patterns. T04 mirrors the structure but does not source the file.

## Constraints

- **AD-19 / MEM001**: the directly-invoked Check command is `bash tests/test-status-review-queue.sh` — single-script-file shape. Test internals may use heredocs / pipes / awk / case-glob freely (P03/T04 + P05/T04 carry-forward — harness shape-guard inspects only directly-invoked Bash tool-call shapes).
- **Bash 3.2**: `set -u` (NOT `set -e`); `pass_count` / `fail_count` parallel-indexed scalars per MEM002; `case "$x" in glob) ;;` for pattern matching.
- **CON-1 / FR-8 (read-only-during-dispatch)**: every fixture sits under `mktemp -d` + trap-EXIT-rm-rf; the live `knowledge/**` tree and the live `.orchestrator/execution-log.jsonl` are never touched. The test explicitly asserts FR-8 by checking that no `execution-log.jsonl` is created under any fixture orch root.
- **CON-4 (Surgical Precision)**: T04 creates only NEW files (`tests/test-status-review-queue.sh`). No modifications to any pre-existing script.
- **Principle XIV (No Speculative Complexity)**: T04 ships only the SC-3 acceptance scenarios + the empty-queue + stale-flag negatives. No assertions on cluster ordering, no per-member-id enumeration, no JSONL record assertions (P03 + P05 own those gates).
- **Distinct-vocabulary fixture pattern** (P05/T04 carry-forward): cluster bodies use disjoint single-token vocabularies (`alpha`, `bravo`, `charlie`) to ensure deterministic clustering at the 0.7 default. Avoid scaffolding words (`distinct`, `body`, `fixture`, `for`, `unique`).
- **`grep -c` rc=1+prints-0 footgun** (P03/T03 carry-forward): use `grep -cE '...' || true` and a separate variable; OR use `grep -qE` for boolean assertions. The test uses `grep -qE` for booleans and `grep -cE | || true` only when the count itself is needed.

## Expected Output

After this task:

1. `tests/test-status-review-queue.sh` exists, is executable.
2. `bash tests/test-status-review-queue.sh` exits 0 with a summary line `PASS: <N>` / `FAIL: 0` and at least 7 `PASS:` lines covering the three SC-3 scenarios + the FR-8 read-only assertion.
3. No file under `knowledge/**` or `.orchestrator/execution-log.jsonl` is touched by the test invocation.

**Done when**: `bash tests/test-status-review-queue.sh` exits 0; summary shows `FAIL: 0`; `git status knowledge/` reflects no T04-attributable diff (the test runs entirely under `mktemp -d` + trap-EXIT-rm-rf).
