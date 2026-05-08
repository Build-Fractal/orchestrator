---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M020"
name: "integration test (tests/test-graduate-workflow.sh) — SC-2 end-to-end"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01: `scripts/knowledge/lib/decision-history.sh` exposes `dh_resolve_operator` + `dh_emit_jsonl`.
- T02: `scripts/knowledge/graduate.sh` ships the full FR-3 surface (`--cluster <id>`, `--reject`, multi-entry atomicity, `archived_into:` back-references, `decision_history:` append, JSONL emission).
- T03 (parallel): `scripts/verify/knowledge-schema-lint.sh` ships the FR-9 + SC-8 enforcement. T04 does NOT depend on T03 directly — the integration test asserts the graduate workflow end-to-end, NOT the schema-authority lint (which has its own contract verifiers in T03).
- P01: `tests/` directory hosts integration tests; `MEM002` (test conventions) governs the structure (`pass()` / `fail()` parallel-indexed scalars, tempdir+trap fixture isolation, `PROJECT_ROOT` env override, summary count at end).

## Description

Create `tests/test-graduate-workflow.sh` — the SC-2 end-to-end integration test. This test exercises `scripts/knowledge/graduate.sh` directly (not through dispatch) across the four operational modes that landed in T01 + T02:

1. **Three-entry cluster graduate**: candidate fixture of three entries; `graduate.sh --cluster Cint --rationale "merge - same assertion" MEM700 MEM701 MEM702`. Asserts:
   - MEM700 (canonical, lexicographically first) -> `status: graduated`
   - MEM701 + MEM702 -> `status: archived` with `archived_into: MEM700`
   - all three -> `decision_history:` block with rationale text + ISO-8601 timestamp + non-empty operator + `cluster_id: Cint`
   - `.orchestrator/execution-log.jsonl` contains 1 `knowledge_graduate` + 2 `knowledge_archive` records.

2. **Single-entry cluster graduate**: candidate fixture of one entry; `graduate.sh --cluster Csingle --rationale "lone candidate" MEM710`. Asserts:
   - MEM710 -> `status: graduated`
   - no `archived_into:` field on MEM710 (canonical, not archived)
   - `decision_history:` block with `cluster_id: Csingle`
   - `.orchestrator/execution-log.jsonl` contains 1 `knowledge_graduate` record (and 0 `knowledge_archive` for this cluster).

3. **Cluster reject**: candidate fixture of two entries; `graduate.sh --reject --cluster Crej --rationale "superseded by M021" MEM720 MEM721`. Asserts:
   - both entries -> `status: archived`
   - NO `archived_into:` field on either (rejection has no canonical)
   - both -> `decision_history:` with rationale text + `cluster_id: Crej`
   - `.orchestrator/execution-log.jsonl` contains 2 `knowledge_archive` records (and 0 `knowledge_graduate` for this cluster).

4. **Cluster-membership-drift abort**: fixture with one candidate + one already-graduated; `graduate.sh --cluster Cdrift --rationale "test" MEM730 MEM731`. Asserts:
   - exit non-zero
   - stderr contains `cluster-membership-drift`
   - both fixture files are byte-identical pre/post invocation (atomic abort, zero mutations)
   - `.orchestrator/execution-log.jsonl` is unchanged for this invocation (no records emitted on drift abort).

Optionally (degraded-mode soft pass per MEM001 — jq is optional):
- if `jq` is available, parse each emitted JSONL record and assert structural shape (`event`, `entry_id`, `cluster_id`, `rationale_hash`, optional `archived_into`, `timestamp`).
- if `jq` is absent, fall back to `grep` on the canonical key strings.

Out of scope:
- Schema-authority lint integration. T03's verifiers (`m020-p03-schema-lint-contract.sh` + `m020-p03-schema-lint-vocabulary-drift.sh`) cover that contract. T04's test focuses purely on the graduate workflow.
- Live-tree mutation. Every test case uses tempdir + `PROJECT_ROOT` + `ORCH_ROOT` env overrides.

## Steps

### Step 1: Create `tests/test-graduate-workflow.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/tests/test-graduate-workflow.sh`

```bash
#!/usr/bin/env bash
# tests/test-graduate-workflow.sh — SC-2 end-to-end integration test for the
# P03 graduate.sh extension. Exercises the four operational modes that landed
# in T01 (decision-history helper) + T02 (graduate.sh extension):
#
#   1. Three-entry cluster graduate (canonical + 2 siblings)
#   2. Single-entry cluster graduate (canonical only)
#   3. Cluster reject (every member archived)
#   4. Cluster-membership-drift abort (zero file mutations)
#
# MEM002 conventions: pass()/fail() parallel-indexed scalars, tempdir+trap
# fixture isolation, PROJECT_ROOT + ORCH_ROOT env overrides, summary count.
# Bash 3.2 safe. AD-19 single-script-file shape.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

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

# --- portable md5 (macOS + linux) ---
md5_of() {
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$1" | awk '{print $1}'
  else
    md5 -q "$1"
  fi
}

# --- frontmatter readers (read first --- block) ---
fm_get() {
  local file="$1" key="$2"
  awk -v k="$key" '
    /^---$/ { n++; if (n>=2) exit; next }
    n==1 {
      pat = "^" k ":[[:space:]]"
      if ($0 ~ pat) {
        sub(pat, "")
        sub(/[[:space:]]+$/, "")
        sub(/^"/, ""); sub(/"$/, "")
        print
        exit
      }
    }
  ' "$file"
}

fm_has_block_key() {
  local file="$1" key="$2"
  grep -q "^${key}:" "$file"
}

# --- Test fixtures isolation ---
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state"

export PROJECT_ROOT="$tmpdir"
export ORCH_ROOT="$tmpdir/orch-state"

LOG="$ORCH_ROOT/execution-log.jsonl"

# =====================================================================
# Case 1 (SC-2 main): three-entry cluster graduate
# =====================================================================
case1_setup() {
  for id in MEM700 MEM701 MEM702; do
    cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
last_verified: 2026-04-25
---

# ${id}: SC-2 case 1 fixture
EOF
  done
}
case1_setup

if bash "$SCRIPT" --cluster Cint --rationale "merge - same assertion" \
       MEM700 MEM701 MEM702 >/dev/null 2>"$tmpdir/case1.err"; then
  s_canon="$(fm_get "$tmpdir/knowledge/patterns/MEM700.md" status)"
  s_701="$(fm_get "$tmpdir/knowledge/patterns/MEM701.md" status)"
  s_702="$(fm_get "$tmpdir/knowledge/patterns/MEM702.md" status)"
  ai_701="$(fm_get "$tmpdir/knowledge/patterns/MEM701.md" archived_into)"
  ai_702="$(fm_get "$tmpdir/knowledge/patterns/MEM702.md" archived_into)"

  [ "$s_canon" = "graduated" ] && pass "case1: MEM700 graduated" \
    || fail "case1: MEM700 status='$s_canon' (expected graduated)"
  [ "$s_701" = "archived" ] && pass "case1: MEM701 archived" \
    || fail "case1: MEM701 status='$s_701' (expected archived)"
  [ "$s_702" = "archived" ] && pass "case1: MEM702 archived" \
    || fail "case1: MEM702 status='$s_702' (expected archived)"
  [ "$ai_701" = "MEM700" ] && pass "case1: MEM701 archived_into=MEM700" \
    || fail "case1: MEM701 archived_into='$ai_701' (expected MEM700)"
  [ "$ai_702" = "MEM700" ] && pass "case1: MEM702 archived_into=MEM700" \
    || fail "case1: MEM702 archived_into='$ai_702' (expected MEM700)"

  for id in MEM700 MEM701 MEM702; do
    if fm_has_block_key "$tmpdir/knowledge/patterns/${id}.md" decision_history; then
      pass "case1: $id has decision_history block"
    else
      fail "case1: $id missing decision_history block"
    fi
    if grep -q 'merge - same assertion' "$tmpdir/knowledge/patterns/${id}.md"; then
      pass "case1: $id decision_history carries rationale"
    else
      fail "case1: $id decision_history missing rationale"
    fi
  done

  if [ -f "$LOG" ]; then
    g_count="$(grep -c '"event":"knowledge_graduate"' "$LOG" || echo 0)"
    a_count="$(grep -c '"event":"knowledge_archive"' "$LOG" || echo 0)"
    [ "$g_count" -ge 1 ] && pass "case1: knowledge_graduate JSONL emitted" \
      || fail "case1: knowledge_graduate JSONL missing (count=$g_count)"
    [ "$a_count" -ge 2 ] && pass "case1: 2 knowledge_archive JSONL emitted" \
      || fail "case1: knowledge_archive JSONL count=$a_count (expected >=2)"
  else
    fail "case1: execution-log.jsonl not created at $LOG"
  fi
else
  fail "case1: graduate.sh --cluster exited non-zero. stderr: $(cat "$tmpdir/case1.err" 2>/dev/null || true)"
fi

# =====================================================================
# Case 2: single-entry cluster graduate
# =====================================================================
> "$LOG"
cat >"$tmpdir/knowledge/patterns/MEM710.md" <<'EOF'
---
id: MEM710
status: candidate
last_verified: 2026-04-25
---

# MEM710: case 2 fixture
EOF

if bash "$SCRIPT" --cluster Csingle --rationale "lone candidate" \
       MEM710 >/dev/null 2>"$tmpdir/case2.err"; then
  s="$(fm_get "$tmpdir/knowledge/patterns/MEM710.md" status)"
  ai="$(fm_get "$tmpdir/knowledge/patterns/MEM710.md" archived_into)"
  [ "$s" = "graduated" ] && pass "case2: MEM710 graduated (single-entry cluster)" \
    || fail "case2: MEM710 status='$s' (expected graduated)"
  [ -z "$ai" ] && pass "case2: MEM710 has no archived_into (canonical)" \
    || fail "case2: MEM710 archived_into='$ai' (expected empty)"
  if fm_has_block_key "$tmpdir/knowledge/patterns/MEM710.md" decision_history; then
    pass "case2: MEM710 has decision_history block"
  else
    fail "case2: MEM710 missing decision_history block"
  fi

  g_count="$(grep -c '"event":"knowledge_graduate"' "$LOG" || echo 0)"
  a_count="$(grep -c '"event":"knowledge_archive"' "$LOG" || echo 0)"
  [ "$g_count" -eq 1 ] && pass "case2: 1 knowledge_graduate JSONL" \
    || fail "case2: knowledge_graduate count=$g_count (expected 1)"
  [ "$a_count" -eq 0 ] && pass "case2: 0 knowledge_archive JSONL" \
    || fail "case2: knowledge_archive count=$a_count (expected 0)"
else
  fail "case2: graduate.sh --cluster Csingle exited non-zero. stderr: $(cat "$tmpdir/case2.err" 2>/dev/null || true)"
fi

# =====================================================================
# Case 3: cluster reject
# =====================================================================
> "$LOG"
for id in MEM720 MEM721; do
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
last_verified: 2026-04-25
---

# ${id}: case 3 reject fixture
EOF
done

if bash "$SCRIPT" --reject --cluster Crej --rationale "superseded by M021" \
       MEM720 MEM721 >/dev/null 2>"$tmpdir/case3.err"; then
  for id in MEM720 MEM721; do
    s="$(fm_get "$tmpdir/knowledge/patterns/${id}.md" status)"
    [ "$s" = "archived" ] && pass "case3: $id archived (reject)" \
      || fail "case3: $id status='$s' (expected archived)"
    if grep -q '^archived_into:' "$tmpdir/knowledge/patterns/${id}.md"; then
      fail "case3: $id has archived_into (rejection should not write it)"
    else
      pass "case3: $id has no archived_into (rejection)"
    fi
    if grep -q 'superseded by M021' "$tmpdir/knowledge/patterns/${id}.md"; then
      pass "case3: $id decision_history carries rejection rationale"
    else
      fail "case3: $id decision_history missing rationale"
    fi
  done

  g_count="$(grep -c '"event":"knowledge_graduate"' "$LOG" || echo 0)"
  a_count="$(grep -c '"event":"knowledge_archive"' "$LOG" || echo 0)"
  [ "$g_count" -eq 0 ] && pass "case3: 0 knowledge_graduate (reject)" \
    || fail "case3: knowledge_graduate count=$g_count (expected 0 on reject)"
  [ "$a_count" -eq 2 ] && pass "case3: 2 knowledge_archive (reject)" \
    || fail "case3: knowledge_archive count=$a_count (expected 2 on reject)"
else
  fail "case3: graduate.sh --reject exited non-zero. stderr: $(cat "$tmpdir/case3.err" 2>/dev/null || true)"
fi

# =====================================================================
# Case 4: cluster-membership-drift abort (zero file mutations)
# =====================================================================
> "$LOG"
cat >"$tmpdir/knowledge/patterns/MEM730.md" <<'EOF'
---
id: MEM730
status: candidate
last_verified: 2026-04-25
---

# MEM730: drift fixture (candidate)
EOF

cat >"$tmpdir/knowledge/patterns/MEM731.md" <<'EOF'
---
id: MEM731
status: graduated
last_verified: 2026-04-25
---

# MEM731: drift fixture (already graduated -> drift)
EOF

md5_pre_730="$(md5_of "$tmpdir/knowledge/patterns/MEM730.md")"
md5_pre_731="$(md5_of "$tmpdir/knowledge/patterns/MEM731.md")"

set +e
out4="$(bash "$SCRIPT" --cluster Cdrift --rationale "test" MEM730 MEM731 2>&1)"
rc4=$?
set -e

[ "$rc4" -ne 0 ] && pass "case4: drift abort returned non-zero" \
  || fail "case4: drift abort returned 0 (expected non-zero). out=$out4"

case "$out4" in
  *"cluster-membership-drift"*) pass "case4: 'cluster-membership-drift' diagnostic emitted" ;;
  *) fail "case4: missing 'cluster-membership-drift' diagnostic. Got: $out4" ;;
esac

md5_post_730="$(md5_of "$tmpdir/knowledge/patterns/MEM730.md")"
md5_post_731="$(md5_of "$tmpdir/knowledge/patterns/MEM731.md")"

[ "$md5_pre_730" = "$md5_post_730" ] && pass "case4: MEM730 byte-identical (atomic abort)" \
  || fail "case4: MEM730 mutated despite drift abort"
[ "$md5_pre_731" = "$md5_post_731" ] && pass "case4: MEM731 byte-identical (atomic abort)" \
  || fail "case4: MEM731 mutated despite drift abort"

if [ ! -s "$LOG" ]; then
  pass "case4: no JSONL records emitted on drift abort"
else
  drift_records="$(grep -c 'Cdrift' "$LOG" || echo 0)"
  [ "$drift_records" -eq 0 ] && pass "case4: zero Cdrift JSONL records" \
    || fail "case4: $drift_records JSONL records emitted on drift (expected 0)"
fi

# =====================================================================
# Summary
# =====================================================================
total=$(( pass_count + fail_count ))
printf '\n--- Summary: %d/%d cases PASS ---\n' "$pass_count" "$total"

if [ "$fail_count" -gt 0 ]; then
  printf 'FAIL: %d test cases failed\n' "$fail_count" >&2
  exit 1
fi

printf 'SC-2 + drift abort: all %d cases PASS\n' "$total"
exit 0
```

`chmod +x tests/test-graduate-workflow.sh`.

## Must-Haves

- `tests/test-graduate-workflow.sh` exists, is executable, and exits 0.
- Test covers four cases: three-entry cluster graduate, single-entry cluster graduate, cluster reject, cluster-membership-drift abort.
- Test asserts `decision_history:` block presence + rationale text on every mutated entry.
- Test asserts JSONL record counts per case (1 graduate + 2 archive on case 1; 1 graduate + 0 archive on case 2; 0 graduate + 2 archive on case 3; 0 records on case 4 drift abort).
- Test uses tempdir + `PROJECT_ROOT` + `ORCH_ROOT` env overrides — no live `knowledge/**` or `.orchestrator/execution-log.jsonl` mutation.
- MEM002 conventions: `pass()` / `fail()` with parallel-indexed scalars, summary count at end, MEM001 prefixed output (`PASS:` / `FAIL:`).
- Bash 3.2 + AD-19 conventions throughout.

## Verification

```
bash tests/test-graduate-workflow.sh
```

Must print one or more `PASS:` lines (one per assertion), end with a summary line, and exit 0. Cross-task verifiers (per-truth Tier-1 verifiers from T01..T03) live in their own task plans; this task's verification is the integration test alone.

## Inputs

### From Previous Tasks

- `scripts/knowledge/graduate.sh` (T02)
  - Key API: `graduate.sh --cluster <id> --rationale <text> <id1> [<id2> ...]` (multi-entry graduate); `graduate.sh --reject --cluster <id> --rationale <text> <id1> ...` (cluster reject); `graduate.sh --rationale <text> <entry-id>` (P01 single-entry, preserved).
  - Behavioral contract: cluster modes are atomic; pre-flight drift gate emits `cluster-membership-drift` and writes zero files on abort. Each successful invocation emits N JSONL records (1 graduate + N-1 archive on graduate; N archive on reject).
- `scripts/knowledge/lib/decision-history.sh` (T01)
  - Key API: `dh_emit_jsonl <event> <kv>...` writes to `${ORCH_ROOT:-.orchestrator}/execution-log.jsonl`. The integration test asserts the JSONL log via `grep -c '"event":"knowledge_graduate"'` and `grep -c '"event":"knowledge_archive"'` — does not call `dh_emit_jsonl` directly.
- `scripts/knowledge/lib/frontmatter.sh` (P01)
  - Field shape: `decision_history:` is a YAML list under the frontmatter; each record is a flow-style map with `rationale`, `timestamp`, `operator`, `cluster_id`. The test reads via `grep -q '^decision_history:'` and `grep -q '<rationale-text>'` rather than full YAML parsing.

### From Disk (Pre-existing)

- `tests/` directory hosts integration tests; existing tests use the `pass()` / `fail()` parallel-indexed scalar pattern (MEM002).
- `scripts/knowledge/lib/index-utils.sh` — `find_detail_file` honors `PROJECT_ROOT` env override; the integration test relies on this for fixture isolation.

## Constraints

- **MEM002 (test conventions)**: `pass()` / `fail()` with parallel-indexed scalars (Bash 3.2 safe — no `declare -A`). Summary count at end. Self-diagnostic — `fail()` messages name actionable file paths and contract identifiers.
- **MEM001 (script conventions)**: prefixed output (`PASS:` / `FAIL:`). Errors to stderr. Exit 0 on all-pass; exit 1 on any fail.
- **AD-19 / single-script-file shape**: the test file ITSELF uses internal pipes / `<<EOF` heredocs / process redirections, but the Verification Check command is a single `bash tests/test-graduate-workflow.sh` invocation. The harness shape-guard inspects only the directly-invoked command.
- **Bash 3.2**: no associative arrays, no `mapfile`, no `<<<` here-strings inside command-substitution-with-pipes. The test file uses parallel-indexed scalars + `< <(...)` process substitution ONLY inside the script body if needed (no Check-line process subs).
- **CON-1 / FR-8 (read-only-during-dispatch)**: the test does not call any operator-only mutation path against the live tree. Every fixture lives under `$tmpdir`; `PROJECT_ROOT` + `ORCH_ROOT` env overrides ensure isolation.
- **Portability**: macOS + linux md5 portability via `command -v md5sum || md5 -q` fallback (P02 convention).
- **jq optional (MEM001)**: integration test does not require jq; structural assertions use `grep -c` against canonical key strings.

## Expected Output

After this task:

1. `tests/test-graduate-workflow.sh` exists, is executable, and exits 0 with a summary line `SC-2 + drift abort: all <N> cases PASS`.
2. `git status knowledge/` is clean (test uses tempdir; live tree never touched).
3. `git status .orchestrator/execution-log.jsonl` shows no change (test uses ORCH_ROOT override).

**Done when**: `bash tests/test-graduate-workflow.sh` exits 0; `git status knowledge/` and `git status .orchestrator/` are clean.
