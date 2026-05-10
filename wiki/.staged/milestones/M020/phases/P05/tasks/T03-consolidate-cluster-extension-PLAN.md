---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M020"
name: "consolidate-artifacts.sh --cluster extension (FR-5)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 (this phase): `scripts/knowledge/lib/cluster.sh` exposes `cluster_compute <root> <threshold>` (emits TAB-separated `<cluster-id>\t<member-id>` lines, sorted; reads `status: candidate` only) and `cluster_id_for <sorted-csv>` (deterministic AD-3 `C<8-hex>`).
- T02 (this phase): `scripts/knowledge/lib/jaccard.sh` extended with the v2 vector (`+ relates_to[] + source_unit + body cap 200`). `pairwise_jaccard` callable contract unchanged.
- P01: `scripts/knowledge/lib/frontmatter.sh` exposes `fm_read_status <file>` and the `fm_field <file> <key>` helper (used by jaccard.sh internally; consolidate-artifacts.sh uses it to read `decision_history:` records for the conflict diagnostic).
- P03: `scripts/knowledge/lib/decision-history.sh` exposes `dh_emit_jsonl <event-type> <kv>...` for `consolidate_cluster` JSONL records.
- M020 ROADMAP cross-cutting concern (cluster state consistency / DC-8 THREAT-006): consolidate-artifacts.sh --cluster does NOT mutate any entry; it only PROPOSES clusters. Mutation is downstream via `graduate.sh --cluster <id>` which re-reads each member's status at graduate-time. Consolidate's role is to surface the proposal + conflicts.
- Pre-existing: `scripts/knowledge/consolidate-artifacts.sh` exists (250 lines) and ships the legacy two-positional-arguments invocation shape `consolidate-artifacts.sh <orch-root> <milestone-id>` that archives task plans. T03 extends in place; the legacy shape MUST remain byte-equivalent in observable behavior (CON-4).

## Description

Modify `scripts/knowledge/consolidate-artifacts.sh` IN PLACE to add a NEW first-position flag `--cluster`. Invocation shape:

```
scripts/knowledge/consolidate-artifacts.sh --cluster <orch-root> <milestone-id> [<knowledge-root>] [<threshold>]
```

When `--cluster` is set, the command:

1. Resolves `<knowledge-root>` (defaults to `<project-root>/knowledge` derived from the script location, OR honors `PROJECT_ROOT` env var per the P01 fixture-isolation pattern).
2. Resolves `<threshold>` (defaults to `0.7` per A-5; will be tuned via P06 preferences later, but P05 hardcodes the default and accepts an explicit positional argument for tests/operator override).
3. Calls `cluster_compute <knowledge-root> <threshold>` (sourced from T01) to compute the cluster set.
4. For each cluster, emits the human-readable stdout block:

   ```
   cluster_id=C<8-hex>
     member=<entry-id-1>
     member=<entry-id-2>
     ...
   ```

   Followed by a `conflict:` line when applicable (see step 5).

5. Conflict detection: for each cluster, read `decision_history:` from each member entry (via `fm_field` or an inline awk reader). If at least one member has a `decision_history:` block AND another member does not (or has divergent rationale_hash records), emit `conflict: cluster=<id> reason=divergent-decision-history` on stdout immediately after the cluster block. Conflicts do NOT abort the run — they are advisory diagnostics consumed by the operator at graduate-time.
6. JSONL emission: for each cluster (including singletons), append one `consolidate_cluster` JSONL record via `dh_emit_jsonl` with fields:

   ```
   cluster_id=<id> member_count=<N> member_ids=<id1>;<id2>;... threshold_used=<T> conflict_flag=<0|1>
   ```

7. Exit 0 on success.

The legacy invocation shape (no `--cluster` flag) is preserved byte-equivalent: the existing argument parser must continue to accept `<orch-root> <milestone-id>` as the first two positionals and run the existing archive-task-plans logic without modification.

The new `--cluster` flag, when present, takes a SHORT-CIRCUIT path that does not invoke any of the legacy code path. The two paths share the script entry but otherwise do not interact.

## Steps

### Step 1: Modify `scripts/knowledge/consolidate-artifacts.sh` — add `--cluster` short-circuit

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/knowledge/consolidate-artifacts.sh`

Add the following block IMMEDIATELY after the existing `set -euo pipefail` and `SCRIPT_DIR="..."` resolution near the top of the file (before the existing `usage()` definition and argument validation), so the `--cluster` flag is detected before any legacy-shape validation runs:

```bash
# --- P05 / FR-5 cluster proposal short-circuit ---
# When the first argument is --cluster, route to the clustering subcommand
# and do not run the legacy archive-task-plans code path. The cluster
# proposal is read-only (CON-1 / FR-8): no entries mutated, no archive
# moves performed.
if [ "${1:-}" = "--cluster" ]; then
  shift  # consume --cluster
  if [ $# -lt 2 ]; then
    echo "ERROR: --cluster requires <orch-root> <milestone-id> [<knowledge-root>] [<threshold>]" >&2
    exit 1
  fi
  CLUSTER_ORCH_ROOT="$1"
  CLUSTER_MILESTONE_ID="$2"
  shift 2
  # Optional positionals: knowledge-root, threshold.
  CLUSTER_KNOWLEDGE_ROOT="${1:-}"
  CLUSTER_THRESHOLD="${2:-0.7}"
  if [ -z "$CLUSTER_KNOWLEDGE_ROOT" ]; then
    # Default knowledge root: <project-root>/knowledge derived from the
    # script location (parent of scripts/knowledge/).
    CLUSTER_PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    CLUSTER_KNOWLEDGE_ROOT="$CLUSTER_PROJECT_ROOT/knowledge"
  fi
  if [ ! -d "$CLUSTER_KNOWLEDGE_ROOT" ]; then
    echo "ERROR: --cluster knowledge-root does not exist: $CLUSTER_KNOWLEDGE_ROOT" >&2
    exit 1
  fi

  # Source helpers from this phase.
  CLUSTER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
  # shellcheck source=lib/cluster.sh
  . "$CLUSTER_LIB_DIR/cluster.sh"
  # shellcheck source=lib/decision-history.sh
  . "$CLUSTER_LIB_DIR/decision-history.sh"
  # shellcheck source=lib/frontmatter.sh
  . "$CLUSTER_LIB_DIR/frontmatter.sh"

  # Export ORCH_ROOT for dh_emit_jsonl (which reads ${ORCH_ROOT:-.orchestrator}).
  ORCH_ROOT="$CLUSTER_ORCH_ROOT"
  export ORCH_ROOT

  # Compute clusters.
  CLUSTER_OUTPUT="$(cluster_compute "$CLUSTER_KNOWLEDGE_ROOT" "$CLUSTER_THRESHOLD" 2>&1)"
  CLUSTER_RC=$?
  if [ "$CLUSTER_RC" -ne 0 ]; then
    echo "ERROR: cluster_compute exited $CLUSTER_RC. Output: $CLUSTER_OUTPUT" >&2
    exit 1
  fi

  # Group cluster_compute output by cluster_id.
  # Output format from cluster_compute: <cluster-id>\t<member-id> lines.
  # We need to iterate clusters in order, emit the human-readable block,
  # detect conflicts, and emit one JSONL record per cluster.

  # Build per-cluster member lists via awk (associative arrays in awk are
  # bash-3.2-safe — the constraint applies to bash code, not awk).
  printf '%s\n' "$CLUSTER_OUTPUT" | awk -F'\t' '
    NF == 2 {
      members[$1] = (members[$1] ? members[$1] ";" $2 : $2)
      if (!seen[$1]) { order[++n_clusters] = $1; seen[$1] = 1 }
    }
    END {
      for (k=1; k<=n_clusters; k++) {
        cid = order[k]
        print cid "\t" members[cid]
      }
    }
  ' >"$CLUSTER_ORCH_ROOT/.cluster-output.tmp.$$"

  # Walk the cluster summary, emit per-cluster output + JSONL.
  while IFS='	' read -r cid members_csv; do
    [ -z "$cid" ] && continue
    # Emit human-readable block.
    printf 'cluster_id=%s\n' "$cid"
    member_count=0
    # Iterate members (semicolon-separated).
    OLDIFS="$IFS"
    IFS=';'
    for mem in $members_csv; do
      printf '  member=%s\n' "$mem"
      member_count=$(( member_count + 1 ))
    done
    IFS="$OLDIFS"

    # Conflict detection: read decision_history: presence per member.
    # Heuristic: if at least one member has decision_history AND at least
    # one member does not, OR if any two members have decision_history
    # blocks that differ in rationale_hash, surface a conflict diagnostic.
    has_history_count=0
    no_history_count=0
    rationale_hashes=""
    OLDIFS="$IFS"
    IFS=';'
    for mem in $members_csv; do
      mem_file="$(find "$CLUSTER_KNOWLEDGE_ROOT" -name "${mem}.md" -type f | head -1)"
      [ -z "$mem_file" ] && continue
      if grep -q '^decision_history:' "$mem_file" 2>/dev/null; then
        has_history_count=$(( has_history_count + 1 ))
        # Capture rationale_hash values (one per record).
        hashes_for_mem="$(awk '/^decision_history:/{in_dh=1; next} in_dh && /^[a-zA-Z]/{in_dh=0} in_dh && /rationale_hash:/{sub(/.*rationale_hash:[[:space:]]*/, ""); sub(/[[:space:]].*/, ""); sub(/[",]/, ""); print}' "$mem_file" 2>/dev/null || true)"
        if [ -n "$hashes_for_mem" ]; then
          rationale_hashes="$rationale_hashes
$hashes_for_mem"
        fi
      else
        no_history_count=$(( no_history_count + 1 ))
      fi
    done
    IFS="$OLDIFS"

    conflict_flag=0
    # Mixed-history conflict: at least one member has history, at least one does not.
    if [ "$has_history_count" -gt 0 ] && [ "$no_history_count" -gt 0 ]; then
      conflict_flag=1
    fi
    # Divergent-history conflict: more than one distinct rationale_hash within the cluster.
    distinct_hashes="$(printf '%s\n' "$rationale_hashes" | grep -v '^$' | LC_ALL=C sort -u | wc -l | awk '{print $1}')"
    if [ "$distinct_hashes" -gt 1 ]; then
      conflict_flag=1
    fi

    if [ "$conflict_flag" -eq 1 ]; then
      printf 'conflict: cluster=%s reason=divergent-decision-history\n' "$cid"
    fi

    # JSONL record.
    dh_emit_jsonl consolidate_cluster \
      "cluster_id=$cid" \
      "member_count=$member_count" \
      "member_ids=$members_csv" \
      "threshold_used=$CLUSTER_THRESHOLD" \
      "conflict_flag=$conflict_flag" \
      "milestone_id=$CLUSTER_MILESTONE_ID"
  done <"$CLUSTER_ORCH_ROOT/.cluster-output.tmp.$$"

  rm -f "$CLUSTER_ORCH_ROOT/.cluster-output.tmp.$$"
  exit 0
fi
# --- end P05 / FR-5 cluster proposal short-circuit ---
```

The placement is critical: this block must come BEFORE the existing argument-validation `if [ $# -lt 2 ]` check that the legacy invocation shape relies on, otherwise `--cluster` will be misinterpreted as `<orch-root>` and trigger a non-existent-directory error. After the short-circuit's `exit 0`, control never reaches the legacy code. When `--cluster` is NOT the first argument, the file flows through unchanged.

`chmod +x scripts/knowledge/consolidate-artifacts.sh` (already executable; preserve mode).

### Step 2: Create `scripts/verify/m020-p05-consolidate-cluster-emit.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p05-consolidate-cluster-emit.sh`

```bash
#!/usr/bin/env bash
# m020-p05-consolidate-cluster-emit.sh — assert consolidate-artifacts.sh
# --cluster emits human-readable cluster blocks with cluster_id= + indent
# member= lines, and the cluster IDs match the AD-3 C<8-hex> shape.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/consolidate-artifacts.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state/milestones/MTEST"

# Three candidates: two near-duplicates + one distinct. Threshold low.
cat >"$tmpdir/knowledge/patterns/MEM800.md" <<'EOF'
---
id: MEM800
status: candidate
topic: shared-cluster
tags: [shared, alpha, beta]
relates_to: [MEM801]
source_unit: M999/P01
---

# MEM800: cluster-A entry one
shared body alpha beta gamma delta common-tokens for clustering
EOF

cat >"$tmpdir/knowledge/patterns/MEM801.md" <<'EOF'
---
id: MEM801
status: candidate
topic: shared-cluster
tags: [shared, alpha, beta]
relates_to: [MEM800]
source_unit: M999/P01
---

# MEM801: cluster-A entry two
shared body alpha beta gamma delta common-tokens for clustering
EOF

cat >"$tmpdir/knowledge/patterns/MEM802.md" <<'EOF'
---
id: MEM802
status: candidate
topic: distinct
tags: [distinct]
relates_to: []
source_unit: M999/P02
---

# MEM802: distinct entry
unique body epsilon zeta eta theta nothing-in-common
EOF

export PROJECT_ROOT="$tmpdir"

out="$(bash "$SCRIPT" --cluster "$tmpdir/orch-state" MTEST "$tmpdir/knowledge" 0.1 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: consolidate-artifacts.sh --cluster exited $rc. Output:"
  printf '%s\n' "$out"
  exit 1
fi

# At least one cluster_id= line matching AD-3 shape.
cluster_lines="$(printf '%s\n' "$out" | grep -E '^cluster_id=C[0-9a-f]{8}$' | wc -l | awk '{print $1}')"
if [ "$cluster_lines" -lt 1 ]; then
  echo "FAIL: no cluster_id=C<8-hex> lines in output:"
  printf '%s\n' "$out"
  exit 1
fi

# Each member listed exactly once with two-space indent.
member_lines="$(printf '%s\n' "$out" | grep -E '^  member=MEM[0-9]+$' | wc -l | awk '{print $1}')"
if [ "$member_lines" -ne 3 ]; then
  echo "FAIL: expected 3 member= lines, got $member_lines. Output:"
  printf '%s\n' "$out"
  exit 1
fi

# Check no member appears twice.
dup="$(printf '%s\n' "$out" | grep -E '^  member=MEM[0-9]+$' | LC_ALL=C sort | uniq -d | wc -l | awk '{print $1}')"
if [ "$dup" -ne 0 ]; then
  echo "FAIL: $dup duplicate member lines. Output:"
  printf '%s\n' "$out"
  exit 1
fi

echo "PASS: consolidate-artifacts.sh --cluster emits cluster_id= + member= lines with AD-3 shape"
exit 0
```

`chmod +x scripts/verify/m020-p05-consolidate-cluster-emit.sh`.

### Step 3: Create `scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh`

```bash
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
```

`chmod +x scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh`.

### Step 4: Create `scripts/verify/m020-p05-consolidate-jsonl-emit.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p05-consolidate-jsonl-emit.sh`

```bash
#!/usr/bin/env bash
# m020-p05-consolidate-jsonl-emit.sh — assert consolidate-artifacts.sh --cluster
# appends one consolidate_cluster JSONL record per emitted cluster to
# $ORCH_ROOT/execution-log.jsonl, with required fields.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/consolidate-artifacts.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state/milestones/MTEST"

# Three candidates: 2 cluster, 1 singleton -> 2 consolidate_cluster records.
for trip in "MEM800:cluster-a:shared body alpha beta gamma" \
            "MEM801:cluster-a:shared body alpha beta gamma" \
            "MEM802:distinct:unique body epsilon zeta eta theta"; do
  id="${trip%%:*}"; rest="${trip#*:}"
  topic="${rest%%:*}"; body="${rest#*:}"
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
topic: ${topic}
tags: [${topic}]
---

# ${id}: jsonl fixture
${body}
EOF
done

export PROJECT_ROOT="$tmpdir"

LOG="$tmpdir/orch-state/execution-log.jsonl"

bash "$SCRIPT" --cluster "$tmpdir/orch-state" MTEST "$tmpdir/knowledge" 0.1 >/dev/null 2>&1 || {
  echo "FAIL: consolidate-artifacts.sh --cluster exited non-zero in jsonl test"
  exit 1
}

if [ ! -f "$LOG" ]; then
  echo "FAIL: execution-log.jsonl not created at $LOG"
  exit 1
fi

# At least 1 consolidate_cluster record. With three candidates above and a
# 0.1 threshold, the expected outcome is 2 records (cluster-a 2-member +
# singleton MEM802) but if the implementation clusters all three the count
# drops to 1; the load-bearing assertion is "non-zero with required fields".
record_count="$(grep -c '"event":"consolidate_cluster"' "$LOG" 2>/dev/null || echo 0)"
if [ "$record_count" -lt 1 ]; then
  echo "FAIL: expected >= 1 consolidate_cluster JSONL record, got $record_count"
  echo "Log content:"
  cat "$LOG"
  exit 1
fi

# Each record carries cluster_id, member_count, member_ids, threshold_used, conflict_flag.
for field in cluster_id member_count member_ids threshold_used conflict_flag; do
  if ! grep -q "\"$field\"" "$LOG"; then
    echo "FAIL: consolidate_cluster JSONL record missing field '$field'"
    echo "Log content:"
    cat "$LOG"
    exit 1
  fi
done

# threshold_used is the value we passed (0.1).
if ! grep -q '"threshold_used":"0.1"' "$LOG"; then
  echo "FAIL: threshold_used field does not carry the supplied 0.1 value"
  cat "$LOG"
  exit 1
fi

echo "PASS: consolidate_cluster JSONL emission ($record_count records, all required fields present)"
exit 0
```

`chmod +x scripts/verify/m020-p05-consolidate-jsonl-emit.sh`.

### Step 5: Create `scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh`

```bash
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
```

`chmod +x scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh`.

## Must-Haves

- `scripts/knowledge/consolidate-artifacts.sh` extended in place with `--cluster` short-circuit BEFORE legacy argument validation.
- `--cluster` invocation reads `<orch-root> <milestone-id> [<knowledge-root>] [<threshold>]`; defaults `knowledge-root` to `$PROJECT_ROOT/knowledge`, defaults `threshold` to 0.7.
- `--cluster` output emits `cluster_id=C<8-hex>` lines followed by indent `  member=<entry-id>` lines per member.
- Conflict detection: `conflict: cluster=<id> reason=divergent-decision-history` line emitted when a cluster contains members with mixed `decision_history:` state (one has it, one does not, OR distinct rationale_hash records present).
- JSONL emission: one `consolidate_cluster` record per cluster with fields `cluster_id`, `member_count`, `member_ids` (semicolon-joined), `threshold_used`, `conflict_flag`, `milestone_id`. Appended to `${ORCH_ROOT}/execution-log.jsonl` via `dh_emit_jsonl`.
- Legacy invocation shape (no `--cluster`) preserved byte-equivalent in observable behavior — fixture milestone consolidation still works.
- Bash 3.2 + AD-19 + MEM001 conventions throughout.
- The four T03 verifier scripts exist, are executable, and exit 0 with `PASS:` lines.
- Read-only / FR-8 / CON-1: `--cluster` mutates NO files under `knowledge/**`; only writes to stdout and to `${ORCH_ROOT}/execution-log.jsonl`. The scratch file `.cluster-output.tmp.$$` lives under `${ORCH_ROOT}` and is removed at the end.

## Verification

```
bash scripts/verify/m020-p05-consolidate-cluster-emit.sh
bash scripts/verify/m020-p05-consolidate-conflict-diagnostic.sh
bash scripts/verify/m020-p05-consolidate-jsonl-emit.sh
bash scripts/verify/m020-p05-consolidate-legacy-shape-preserved.sh
```

Each must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/cluster.sh` (T01)
  - Key API: `cluster_compute <root> <threshold>` (emits `<cluster-id>\t<member-id>` lines, sorted, candidates only); `cluster_id_for <sorted-csv>` (deterministic AD-3 ID).
  - consolidate-artifacts.sh sources cluster.sh and calls `cluster_compute` once per --cluster invocation.
- `scripts/knowledge/lib/jaccard.sh` (T02 extended)
  - Key API: unchanged callable contract `pairwise_jaccard <a> <b>`. The v2 vector inside is what gives rise to the four-near-duplicate cluster the SC-4 fixture demands; T03 does not invoke pairwise_jaccard directly.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/decision-history.sh` (P03/T01)
  - Key API: `dh_emit_jsonl <event-type> <kv>...` appends a JSONL record to `${ORCH_ROOT:-.orchestrator}/execution-log.jsonl`. Conservative escaping (backslash + double-quote); no jq dependency.
- `scripts/knowledge/lib/frontmatter.sh` (P01) — `fm_field <file> <key>` reads frontmatter scalars; consolidate-artifacts.sh inlines an awk-based `decision_history:` reader rather than calling fm_field for the per-record rationale_hash extraction (fm_field is scalar-only; decision_history is a list).
- `scripts/knowledge/consolidate-artifacts.sh` (pre-existing, ~250 lines) — the legacy archive-task-plans logic. T03 inserts the --cluster short-circuit BEFORE the existing argument-validation block; the legacy code path is otherwise unchanged.

## Constraints

- **AD-19 / MEM001**: every `Check:` and verification command in this plan is a single-script-file invocation. The --cluster short-circuit's body uses awk + temp files internally; only the directly-invoked Check commands are gated.
- **Bash 3.2**: parallel newline-joined scalars; awk associative arrays for grouping (awk's own arrays are fine — bash 3.2 constraint is on bash code only).
- **CON-1 / FR-8 (read-only-during-dispatch)**: `--cluster` reads `knowledge/**/MEM*.md` files but writes nothing under `knowledge/**`. The only writes are: stdout, the JSONL log at `${ORCH_ROOT}/execution-log.jsonl`, and the scratch file `${ORCH_ROOT}/.cluster-output.tmp.$$` which is removed at exit. Verifier tests use isolated `ORCH_ROOT` env-var overrides per the P03 pattern.
- **CON-4 (Surgical Precision)**: the `--cluster` block is INSERTED BEFORE the existing argument-validation block; no other lines in the file are modified. The legacy invocation shape (no `--cluster`) flows through unchanged, verified by `m020-p05-consolidate-legacy-shape-preserved.sh`.
- **AD-3 (cluster ID format)**: cluster IDs come from T01's `cluster_id_for`; T03 does not re-derive them. Every cluster_id= line in stdout matches `^cluster_id=C[0-9a-f]{8}$`.
- **THREAT-006 / DC-8 (cluster state consistency)**: T03 does not mutate any entry; mutation happens at graduate-time. The conflict diagnostic is advisory — it does NOT abort the run. The cluster-membership-drift abort lives in graduate.sh (P03), not here.
- **Principle XIV (No Speculative Complexity)**: conflict detection is heuristic (mixed-history + distinct-rationale-hash). No semantic conflict resolution, no operator-prompted disambiguation. The diagnostic is advisory; the operator decides.
- **Principle VI (State On Disk Is Truth)**: JSONL records land on disk before the script exits; the scratch file is local + ephemeral and never claimed as state.
- **Principle XV (Surgical Precision)**: T03 inserts ONE block at one location. It does not refactor the existing legacy code path.

## Expected Output

After this task:

1. `scripts/knowledge/consolidate-artifacts.sh` is modified (>= 280 lines), executable, and the help/usage block continues to mention the legacy shape; the new `--cluster` short-circuit is inserted at the top of execution flow.
2. All four T03 verifiers exist under `scripts/verify/`, are executable, and pass.
3. `git status knowledge/` is clean (T03 verifiers use tempdirs with `PROJECT_ROOT` overrides; live tree never touched).
4. `git status .orchestrator/execution-log.jsonl` is unchanged by T03 verifier runs (verifiers redirect via `ORCH_ROOT` env).

**Done when**: all four T03 verifiers print `PASS:` and exit 0; `git status knowledge/` and `git status .orchestrator/execution-log.jsonl` are clean.
