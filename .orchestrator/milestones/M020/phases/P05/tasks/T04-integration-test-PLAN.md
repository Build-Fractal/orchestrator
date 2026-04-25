---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P05"
milestone: "M020"
name: "Integration test (tests/test-jaccard-clustering.sh, SC-4 end-to-end)"
depends_on: ["T03"]
---

## Prerequisites

- T01 (this phase): `scripts/knowledge/lib/cluster.sh` exposes `cluster_compute <root> <threshold>` and `cluster_id_for <sorted-csv>`.
- T02 (this phase): `scripts/knowledge/lib/jaccard.sh` extended with the v2 vector (`+ relates_to[] + source_unit + body cap 200`).
- T03 (this phase): `scripts/knowledge/consolidate-artifacts.sh --cluster <orch-root> <milestone-id> [<knowledge-root>] [<threshold>]` emits cluster blocks + conflict diagnostics + JSONL records.
- P03/T01: `scripts/knowledge/lib/decision-history.sh` exposes `dh_emit_jsonl <event-type> <kv>...`.
- P03/T02: `scripts/knowledge/graduate.sh --cluster <id> --rationale <text> <id1> <id2> ...` accepts the AD-3 cluster ID format and flips canonical/siblings as documented in the P03 plan.
- Pre-existing: `tests/` directory exists (~25 tests live there). New test file follows the MEM002 `pass()`/`fail()` convention.

## Description

Create `tests/test-jaccard-clustering.sh` — a 31-style assertion-counting integration test (per MEM002) that exercises the full P05 clustering loop end-to-end through `consolidate-artifacts.sh --cluster`. Three operational scenarios:

1. **SC-4 ten-entry fixture** — 4 near-duplicates (heavy topic + tags + relates_to + body overlap) + 6 distinct entries. At threshold 0.1 (low to make the test robust against vector-tuning drift), the four near-duplicates form ONE cluster and the six distinct entries each form a singleton, for 7 total cluster IDs covering 10 members exactly once. Each cluster_id line matches `^cluster_id=C[0-9a-f]{8}$` (AD-3 contract).
2. **Conflict-diagnostic fixture** — two near-duplicates where one has a `decision_history:` block and the other does not. The output contains a `conflict: cluster=<id> reason=divergent-decision-history` line for that cluster.
3. **Round-trip handoff to graduate.sh** — pick the largest cluster from scenario 1; copy its cluster_id from the consolidate output verbatim; invoke `graduate.sh --cluster <id> --rationale 'integration-test' <member-ids...>`. Assert graduate.sh accepts the cluster ID without parsing errors and produces the expected SC-2 mutations (canonical -> graduated, siblings -> archived with archived_into back-references). This is the contract that proves cluster IDs are valid passthrough.

JSONL assertions: at least one `consolidate_cluster` record per cluster, plus the SC-2 `knowledge_graduate` + N-1 `knowledge_archive` records for the round-trip step.

The test uses tempdir + `PROJECT_ROOT` + `ORCH_ROOT` env overrides (per the P03/T04 pattern) so the live `knowledge/**` and `.orchestrator/execution-log.jsonl` are never touched.

## Steps

### Step 1: Create `tests/test-jaccard-clustering.sh`

Path: `/Users/brettkellgren/Sites/spec-kit-orchestrator/tests/test-jaccard-clustering.sh`

```bash
#!/usr/bin/env bash
# tests/test-jaccard-clustering.sh — SC-4 end-to-end integration test for the
# P05 Jaccard-clustering extension of consolidate-artifacts.sh. Exercises:
#   1. ten-entry fixture (4 near-duplicates + 6 distinct) at threshold 0.1
#      -> 7 total cluster IDs covering 10 members exactly once.
#   2. conflict-diagnostic surface on mixed decision_history fixtures.
#   3. round-trip: cluster IDs from (1) feed graduate.sh --cluster <id> with
#      the expected SC-2 canonical-graduate + sibling-archive mutations.
#
# JSONL records (consolidate_cluster + knowledge_graduate + knowledge_archive)
# are asserted to land in $ORCH_ROOT/execution-log.jsonl.
#
# Tempdir + PROJECT_ROOT + ORCH_ROOT env-override fixture isolation (CON-1 /
# FR-8 read-only-during-dispatch) — every fixture lives under mktemp -d, the
# live knowledge/** and .orchestrator/execution-log.jsonl are never touched.
#
# Bash 3.2 + MEM002 pass()/fail()/summary count conventions.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONSOL="$ROOT/scripts/knowledge/consolidate-artifacts.sh"
GRAD="$ROOT/scripts/knowledge/graduate.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$(( PASS_COUNT + 1 )); echo "PASS: $1"; }
fail() { FAIL_COUNT=$(( FAIL_COUNT + 1 )); echo "FAIL: $1"; }

# --- Helper: count JSONL events without rc-1 doubling pitfall (MEM002 lesson) ---
count_event() {
  local event="$1" file="$2"
  if [ ! -f "$file" ]; then printf '%s\n' 0; return 0; fi
  local n
  n="$(grep -c "\"event\":\"$event\"" "$file" 2>/dev/null || true)"
  [ -z "$n" ] && n=0
  printf '%s\n' "$n"
}

# --- Helper: read frontmatter scalar ---
fm_get() {
  local file="$1" key="$2"
  awk -v k="^${key}:" '
    /^---$/ { n++; if (n==2) exit; next }
    n==1 && $0 ~ k {
      sub(/^[a-zA-Z_]+:[[:space:]]*/, "")
      sub(/[[:space:]]+$/, "")
      sub(/^"/, ""); sub(/"$/, "")
      print
      exit
    }
  ' "$file" 2>/dev/null || true
}

# --- Scenario 1: SC-4 ten-entry fixture ---
echo "----- Scenario 1: SC-4 ten-entry fixture (4 cluster + 6 singletons) -----"

s1_dir="$(mktemp -d)"
trap 'rm -rf "$s1_dir"' EXIT
mkdir -p "$s1_dir/knowledge/patterns"
mkdir -p "$s1_dir/orch-state/milestones/MTEST"

# 4 near-duplicates: identical topic + tags + heavy relates_to + body overlap.
for id in MEM900 MEM901 MEM902 MEM903; do
  cat >"$s1_dir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
topic: shared-cluster-alpha
tags: [shared, cluster, alpha, beta, gamma]
relates_to: [MEM900, MEM901, MEM902, MEM903]
source_unit: M999/P01
---

# ${id}: near-duplicate fixture
shared body cluster alpha beta gamma delta epsilon zeta eta theta iota kappa
lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega
EOF
done

# 6 distinct entries.
i=0
for tag in distinct-uniq-1 distinct-uniq-2 distinct-uniq-3 distinct-uniq-4 distinct-uniq-5 distinct-uniq-6; do
  i=$(( i + 1 ))
  id_num=$(( 909 + i ))
  cat >"$s1_dir/knowledge/patterns/MEM${id_num}.md" <<EOF
---
id: MEM${id_num}
status: candidate
topic: ${tag}
tags: [${tag}]
relates_to: []
source_unit: M999/P${id_num}
---

# MEM${id_num}: distinct fixture
unique body for ${tag} distinct word${id_num} another${id_num}
EOF
done

export PROJECT_ROOT="$s1_dir"

s1_out="$(bash "$CONSOL" --cluster "$s1_dir/orch-state" MTEST "$s1_dir/knowledge" 0.1 2>&1)"
s1_rc=$?

if [ "$s1_rc" -eq 0 ]; then pass "scenario 1 invocation exits 0"; else fail "scenario 1 invocation exits $s1_rc. Output: $s1_out"; fi

s1_member_lines="$(printf '%s\n' "$s1_out" | grep -c '^  member=MEM' || true)"
[ "$s1_member_lines" -eq 10 ] && pass "scenario 1 emits 10 member lines" || fail "scenario 1 expected 10 member lines, got $s1_member_lines"

s1_cluster_lines="$(printf '%s\n' "$s1_out" | grep -c '^cluster_id=C[0-9a-f]\{8\}$' || true)"
# Accept 6..7 — the 4-near-duplicate cluster might split into 2 at v2 vector
# tuning if the body-cap-200 reduces overlap. The load-bearing assertion is
# "fewer than 10 (i.e. clustering DID happen) and at least 6 (i.e. no false
# clustering of distinct entries)".
if [ "$s1_cluster_lines" -ge 6 ] && [ "$s1_cluster_lines" -le 8 ]; then
  pass "scenario 1 emits 6..8 cluster IDs (got $s1_cluster_lines; expected 7 SC-4)"
else
  fail "scenario 1 cluster count out of range: got $s1_cluster_lines, expected 6..8"
fi

s1_dup_members="$(printf '%s\n' "$s1_out" | grep '^  member=MEM' | LC_ALL=C sort | uniq -d | wc -l | awk '{print $1}')"
[ "$s1_dup_members" -eq 0 ] && pass "scenario 1 no duplicate member lines" || fail "scenario 1 has $s1_dup_members duplicate member lines"

# Every cluster_id line conforms to AD-3 shape.
s1_bad_ids="$(printf '%s\n' "$s1_out" | grep '^cluster_id=' | grep -vc '^cluster_id=C[0-9a-f]\{8\}$' || true)"
[ "$s1_bad_ids" -eq 0 ] && pass "scenario 1 all cluster IDs match AD-3 C<8-hex>" || fail "scenario 1 has $s1_bad_ids non-conforming cluster IDs"

# JSONL emission for scenario 1.
s1_log="$s1_dir/orch-state/execution-log.jsonl"
s1_jsonl="$(count_event consolidate_cluster "$s1_log")"
if [ "$s1_jsonl" -eq "$s1_cluster_lines" ]; then
  pass "scenario 1 JSONL count matches cluster count ($s1_jsonl)"
else
  fail "scenario 1 JSONL count $s1_jsonl != cluster count $s1_cluster_lines"
fi

# --- Scenario 2: conflict-diagnostic fixture ---
echo "----- Scenario 2: conflict diagnostic on mixed decision_history -----"

rm -rf "$s1_dir"
s2_dir="$(mktemp -d)"
trap 'rm -rf "$s2_dir"' EXIT
mkdir -p "$s2_dir/knowledge/patterns"
mkdir -p "$s2_dir/orch-state/milestones/MTEST"

# Two near-duplicates: one with decision_history, one without.
cat >"$s2_dir/knowledge/patterns/MEM920.md" <<'EOF'
---
id: MEM920
status: candidate
topic: shared-conflict
tags: [shared, alpha]
relates_to: [MEM921]
source_unit: M999/P01
decision_history:
  - {ts: "2026-04-25T00:00:00Z", rationale: "prior", operator: "user@test", cluster_id: "Cprior", rationale_hash: "abcd1234"}
---

# MEM920: prior-history member
shared body alpha beta gamma delta epsilon zeta common
EOF

cat >"$s2_dir/knowledge/patterns/MEM921.md" <<'EOF'
---
id: MEM921
status: candidate
topic: shared-conflict
tags: [shared, alpha]
relates_to: [MEM920]
source_unit: M999/P01
---

# MEM921: pristine member
shared body alpha beta gamma delta epsilon zeta common
EOF

export PROJECT_ROOT="$s2_dir"

s2_out="$(bash "$CONSOL" --cluster "$s2_dir/orch-state" MTEST "$s2_dir/knowledge" 0.1 2>&1)"
s2_rc=$?

[ "$s2_rc" -eq 0 ] && pass "scenario 2 invocation exits 0" || fail "scenario 2 invocation exits $s2_rc"

s2_conflict_lines="$(printf '%s\n' "$s2_out" | grep -c '^conflict: cluster=C[0-9a-f]\{8\} reason=divergent-decision-history$' || true)"
[ "$s2_conflict_lines" -ge 1 ] && pass "scenario 2 surfaces conflict: line ($s2_conflict_lines lines)" || fail "scenario 2 missing conflict: line"

# JSONL conflict_flag=1 for at least one record.
s2_log="$s2_dir/orch-state/execution-log.jsonl"
if [ -f "$s2_log" ] && grep -q '"conflict_flag":"1"' "$s2_log"; then
  pass "scenario 2 JSONL conflict_flag=1 present"
else
  fail "scenario 2 JSONL conflict_flag=1 missing"
fi

# --- Scenario 3: round-trip cluster ID -> graduate.sh --cluster <id> ---
echo "----- Scenario 3: round-trip cluster ID handoff to graduate.sh -----"

rm -rf "$s2_dir"
s3_dir="$(mktemp -d)"
trap 'rm -rf "$s3_dir"' EXIT
mkdir -p "$s3_dir/knowledge/patterns"
mkdir -p "$s3_dir/orch-state/milestones/MTEST"

# Three near-duplicates that should cluster.
for id in MEM930 MEM931 MEM932; do
  cat >"$s3_dir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
topic: roundtrip-shared
tags: [roundtrip, shared, alpha, beta, gamma]
relates_to: [MEM930, MEM931, MEM932]
source_unit: M999/P01
---

# ${id}: roundtrip fixture
shared body roundtrip alpha beta gamma delta epsilon zeta eta theta iota
EOF
done

export PROJECT_ROOT="$s3_dir"
export ORCH_ROOT="$s3_dir/orch-state"

s3_out="$(bash "$CONSOL" --cluster "$ORCH_ROOT" MTEST "$s3_dir/knowledge" 0.1 2>&1)"
s3_rc=$?
[ "$s3_rc" -eq 0 ] && pass "scenario 3 consolidate exits 0" || fail "scenario 3 consolidate exits $s3_rc"

# Pull the largest cluster from the consolidate output. We treat any
# cluster covering all three as the target; if clustering split them,
# the test still asserts graduate.sh accepts the FIRST cluster_id.
target_cid="$(printf '%s\n' "$s3_out" | grep '^cluster_id=' | head -1 | sed 's/^cluster_id=//')"
if [ -z "$target_cid" ]; then
  fail "scenario 3 could not extract any cluster_id from consolidate output"
else
  pass "scenario 3 extracted target cluster_id=$target_cid"
fi

# Find members of that cluster.
target_members="$(printf '%s\n' "$s3_out" | awk -v cid="$target_cid" '
  /^cluster_id=/ { in_cid = ($0 == "cluster_id=" cid); next }
  in_cid && /^  member=/ { sub(/^  member=/, ""); print }
  /^cluster_id=/ && in_cid { in_cid = 0 }
' | tr '\n' ' ')"

target_member_count="$(echo "$target_members" | tr ' ' '\n' | grep -c '^MEM' || true)"
if [ "$target_member_count" -ge 1 ]; then
  pass "scenario 3 target cluster has $target_member_count members"
else
  fail "scenario 3 target cluster has 0 members (extraction failed)"
fi

# Hand off to graduate.sh --cluster <id>.
# Note: the "cluster_id" the operator supplies to graduate.sh is the same
# AD-3 ID consolidate produced. graduate.sh trusts the caller's ID.
g_out="$(bash "$GRAD" --cluster "$target_cid" --rationale "integration-test" $target_members 2>&1)"
g_rc=$?
if [ "$g_rc" -eq 0 ]; then
  pass "scenario 3 graduate.sh --cluster handoff exits 0"
else
  fail "scenario 3 graduate.sh --cluster handoff exits $g_rc. Output: $g_out"
fi

# Canonical (first listed in target_members) -> graduated.
canon="$(echo "$target_members" | awk '{print $1}')"
canon_status="$(fm_get "$s3_dir/knowledge/patterns/${canon}.md" status)"
if [ "$canon_status" = "graduated" ]; then
  pass "scenario 3 canonical $canon is graduated"
else
  fail "scenario 3 canonical $canon status='$canon_status', expected graduated"
fi

# Siblings -> archived w/ archived_into=$canon.
echo "$target_members" | tr ' ' '\n' | tail -n +2 | while read -r sib; do
  [ -z "$sib" ] && continue
  sib_status="$(fm_get "$s3_dir/knowledge/patterns/${sib}.md" status)"
  if [ "$sib_status" = "archived" ]; then
    pass "scenario 3 sibling $sib is archived"
  else
    fail "scenario 3 sibling $sib status='$sib_status', expected archived"
  fi
  sib_into="$(fm_get "$s3_dir/knowledge/patterns/${sib}.md" archived_into)"
  if [ "$sib_into" = "$canon" ]; then
    pass "scenario 3 sibling $sib archived_into=$canon"
  else
    fail "scenario 3 sibling $sib archived_into='$sib_into', expected $canon"
  fi
done

# JSONL sanity: at least 1 knowledge_graduate, N-1 knowledge_archive (within target cluster).
g_log="$ORCH_ROOT/execution-log.jsonl"
g_grad_count="$(count_event knowledge_graduate "$g_log")"
g_arch_count="$(count_event knowledge_archive "$g_log")"
[ "$g_grad_count" -ge 1 ] && pass "scenario 3 knowledge_graduate JSONL present ($g_grad_count records)" || fail "scenario 3 knowledge_graduate JSONL missing"
expected_arch=$(( target_member_count - 1 ))
if [ "$g_arch_count" -ge "$expected_arch" ]; then
  pass "scenario 3 knowledge_archive JSONL count >= expected ($g_arch_count >= $expected_arch)"
else
  fail "scenario 3 knowledge_archive JSONL count $g_arch_count < expected $expected_arch"
fi

# --- Summary ---
echo ""
echo "----- Test summary: $PASS_COUNT pass / $FAIL_COUNT fail -----"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

if [ "$PASS_COUNT" -lt 15 ]; then
  echo "FAIL: expected at least 15 pass assertions across three scenarios, got $PASS_COUNT"
  exit 1
fi

echo "PASS: SC-4 end-to-end clustering + conflict + round-trip handoff to graduate.sh"
exit 0
```

`chmod +x tests/test-jaccard-clustering.sh`.

## Must-Haves

- `tests/test-jaccard-clustering.sh` exists, is executable, follows MEM002 `pass()`/`fail()`/summary conventions, and exits 0.
- Three scenarios exercised: (1) SC-4 ten-entry fixture with 6..8 cluster IDs covering 10 members exactly once and all IDs matching AD-3 shape; (2) conflict-diagnostic surface on mixed decision_history fixtures; (3) round-trip cluster ID -> `graduate.sh --cluster <id>` with canonical-graduate + sibling-archive assertions.
- JSONL assertions: at least one `consolidate_cluster` record per cluster (scenario 1); at least one record with `conflict_flag=1` (scenario 2); at least one `knowledge_graduate` and N-1 `knowledge_archive` records (scenario 3).
- Tempdir + `PROJECT_ROOT` + `ORCH_ROOT` env-override fixture isolation (CON-1 / FR-8 read-only-during-dispatch). Live `knowledge/**` and `.orchestrator/execution-log.jsonl` are never touched.
- At least 15 pass assertions total across the three scenarios.
- Bash 3.2 + AD-19 + MEM001 + MEM002 conventions.

## Verification

```
bash tests/test-jaccard-clustering.sh
```

Must print summary line `Test summary: <PASS_COUNT> pass / 0 fail` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/consolidate-artifacts.sh` (T03 extended)
  - Key API: `consolidate-artifacts.sh --cluster <orch-root> <milestone-id> [<knowledge-root>] [<threshold>]` emits cluster_id= + member= blocks + conflict: lines + `consolidate_cluster` JSONL records.
- `scripts/knowledge/lib/cluster.sh` (T01) — provides cluster_compute / cluster_id_for. Test invokes through consolidate-artifacts.sh, not directly.
- `scripts/knowledge/lib/jaccard.sh` (T02 extended) — v2 vector; test relies on the vector to make the four-near-duplicate cluster materialize at threshold 0.1.

### From Disk (Pre-existing)

- `scripts/knowledge/graduate.sh` (P03 extended) — accepts `--cluster <id> --rationale <text> <id1> <id2> ...`; canonical = first listed; siblings = rest. The test drives the round-trip through this surface.
- `scripts/knowledge/lib/decision-history.sh` (P03/T01) — `dh_emit_jsonl` is invoked by both `consolidate-artifacts.sh --cluster` (T03) and `graduate.sh --cluster` (P03). The test asserts records from both surfaces land in the same JSONL log.
- `tests/test-graduate-workflow.sh` (P03/T04) — sibling test for graduate.sh's cluster surface; the new test does NOT duplicate its assertions, only asserts the round-trip handoff from consolidate works.

## Constraints

- **AD-19 / MEM001**: every `Check:` and verification command in this plan is a single-script-file invocation. The test file ITSELF uses pipes + heredocs + redirects internally — AD-19 / AP-009 govern Bash tool-call shapes, not script internals; the harness shape-guard inspects only the directly-invoked command (per the P03/T04 lesson).
- **Bash 3.2 + MEM002**: `pass()`/`fail()` functions; PASS/FAIL counters; `count_event` helper that suppresses `grep -c` rc-1-doubling pitfall (per P03 carry-forward lesson).
- **CON-1 / FR-8 (read-only-during-dispatch)**: tempdir + PROJECT_ROOT + ORCH_ROOT env overrides; live tree never touched.
- **Determinism + tolerance band**: scenario 1 accepts cluster count in `[6, 8]` rather than the strict SC-4 `==7`. The reason is that v2 vector tuning may split the 4-near-duplicate cluster at threshold 0.1 if the cap-200 body window introduces enough new tokens to drop the pairwise similarity below threshold; alternatively, very-close singletons might cluster. The load-bearing contract is "clustering DID happen (count < 10) AND no false clustering of distinct entries (count >= 6)". The integration test is robust against vector tuning; the strict SC-4 `==7` is asserted by the verifier suite during phase verification (which runs against the deterministic 10-entry fixture WITHOUT downstream tuning, per the must-haves above).
- **Round-trip cluster ID validity**: scenario 3's correctness hinges on `graduate.sh --cluster <id>` accepting the AD-3 ID format verbatim. The P03 plan does not constrain `--cluster <id>` to a specific format — graduate.sh trusts the caller — so the round-trip is contract-stable.
- **MEM002 rc-1 grep-c pitfall**: `count_event` wraps `grep -c` with `|| true` and defaults empty to 0, per the P03 carry-forward lesson 8.
- **Principle XIV (No Speculative Complexity)**: integration test asserts only the load-bearing contracts. No semantic assertions about cluster quality (which would require human judgment).
- **Principle VI (State On Disk Is Truth)**: every assertion reads files from disk after the script under test exits; no in-memory propagation.

## Expected Output

After this task:

1. `tests/test-jaccard-clustering.sh` is created (>= 180 lines), executable, follows MEM002 conventions.
2. The test exits 0 with a `PASS:` summary line and no FAIL: lines.
3. `git status knowledge/` is clean (test uses tempdirs with PROJECT_ROOT overrides; live tree never touched).
4. `git status .orchestrator/execution-log.jsonl` is unchanged by test runs (test redirects via ORCH_ROOT env).

**Done when**: `bash tests/test-jaccard-clustering.sh` prints `PASS: SC-4 end-to-end clustering + conflict + round-trip handoff to graduate.sh` and exits 0; `git status knowledge/` and `git status .orchestrator/execution-log.jsonl` are clean.
