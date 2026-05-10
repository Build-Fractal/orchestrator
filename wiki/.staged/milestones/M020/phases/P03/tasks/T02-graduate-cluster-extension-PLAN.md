---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M020"
name: "graduate.sh extension — cluster, multi-entry atomicity, archived_into, decision_history, JSONL"
depends_on: ["T01"]
---

## Prerequisites

- P01: `scripts/knowledge/graduate.sh` ships the minimum-viable single-entry path (`--rationale <text> <entry-id>` flips `candidate` -> `graduated` via `fm_write_status`; idempotent NO-OP on graduated; FAIL on archived).
- P01: `scripts/knowledge/lib/frontmatter.sh` exposes `fm_read_status`, `fm_write_status`, `fm_write_archived_into`, `fm_append_decision_history`.
- T01 (this phase): `scripts/knowledge/lib/decision-history.sh` exposes `dh_resolve_operator` (operator-identity resolver) and `dh_emit_jsonl <event> <kv>...` (JSONL appender to `$ORCH_ROOT/execution-log.jsonl`).
- Cross-cutting concern (M020 ROADMAP "Cluster state consistency"): `--cluster` must re-read each member's current `status:` at graduate-time and abort with a `cluster-membership-drift` diagnostic when any member has changed state since clustering. Verifies THREAT-006 disposition from M020-CONTEXT.md DC-8.

## Description

Extend `scripts/knowledge/graduate.sh` IN PLACE to add:

1. New flag `--cluster <id>`. When set, the trailing positional arguments are interpreted as a list of N entry-ids belonging to the cluster. The first listed id is the **canonical entry** that flips to `graduated`; the remaining ids flip to `archived` with `archived_into: <canonical-id>`. All N entries gain a `decision_history:` record carrying the supplied `--rationale`.

2. New flag `--reject`. Requires `--cluster`. Inverts the flip semantics: every member of the cluster (canonical and siblings) flips to `archived`, and NO `archived_into:` field is written (rejection has no canonical replacement). All N entries gain a `decision_history:` record. T03 covers `--reject` per-task semantics; T02 must NOT pre-implement the reject body — T02's argument parser MAY accept `--reject` and shunt to a stub function that T03 fills in.

   **CON-4 / scope-discipline note**: this T02 plan limits the `--reject` deliverable to "argument parser accepts the flag and routes to a stub `_graduate_reject` function". The stub MUST exit non-zero with a diagnostic so accidental T02-time invocations don't silently land malformed data. T03 replaces the stub body. The seam-only-in-T02 split keeps T02's verifier set focused on the graduate path; T03's verifier set focuses on the reject path.

3. Cluster atomicity. Before any frontmatter mutation:
   - Read every member's current `status:` via `fm_read_status`.
   - If ANY member's status is not `candidate`, abort with `FAIL: cluster-membership-drift entry=<id> status=<observed-status>` on stderr, exit 1, write zero files. The single existing P01 invocation shape (`--rationale <text> <entry-id>` with no `--cluster`) MUST continue to work byte-equivalently — the drift gate runs only when `--cluster` is set.
   - On the all-candidate happy path, perform writes in a deterministic order: canonical `fm_write_status graduated` first, then for each sibling: `fm_write_status archived`, then `fm_write_archived_into <canonical-id>`, then `fm_append_decision_history <rationale> <operator> <cluster-id>` for every member (canonical included). Each `fm_*` write is itself atomic (tempfile + rename), so the failure surface for partial-application is bounded to one entry; the pre-flight drift gate guarantees that all N writes will succeed under FR-9 closed-enum constraints.

4. JSONL emission. After all writes succeed, emit one `knowledge_graduate` record (canonical id) and N-1 `knowledge_archive` records (siblings) via `dh_emit_jsonl`. Record shape per the M020 ROADMAP cross-cutting concern + T01 helper:
   - `knowledge_graduate`: `event=knowledge_graduate entry_id=<canonical> cluster_id=<id> rationale_hash=<sha1-of-rationale-first-8>`
   - `knowledge_archive`:  `event=knowledge_archive entry_id=<sibling> cluster_id=<id> archived_into=<canonical> rationale_hash=<sha1-of-rationale-first-8>`

5. Help text update. `--help` (and bare-misuse) prints the extended usage covering `--cluster`, `--reject`, and the multi-entry positional shape.

Out of scope (deferred):
- `--reject` body (T03).
- Schema-authority lint (T03 / actually T03 in original plan was schema-lint — corrected: T03 in this phase plan is schema-authority-lint per P03-PLAN.md). Re-read: phase plan T03 IS the schema-authority lint, NOT the reject body. **Correction**: per the phase plan, T03 IS `scripts/verify/knowledge-schema-lint.sh` (independent of graduate.sh extensions). Therefore `--reject` body lands in T02 — see Reconciliation note below.

### Reconciliation note (T02 vs T03 split per P03-PLAN.md)

The P03 phase plan defines exactly four tasks:
- T01: decision-history helper
- T02: graduate.sh extension (cluster, multi-entry, archived_into, decision_history, JSONL)
- T03: schema-authority lint (`scripts/verify/knowledge-schema-lint.sh`)
- T04: integration test (`tests/test-graduate-workflow.sh`)

There is no separate task for `--reject`. **T02 owns BOTH the cluster-graduate path AND the cluster-reject path** in `graduate.sh` — they share the argument parser, the drift gate, and the decision-history append. The earlier paragraph above mentioning a stub-only `_graduate_reject` is incorrect — T02 must implement the full reject body as well. The drift-gate's pre-flight read remains identical for both paths; the only divergence is the per-member write loop:

- graduate path: canonical -> graduated; siblings -> archived + archived_into; all -> decision_history; emit `knowledge_graduate` + N-1 `knowledge_archive` JSONL records.
- reject path: every member -> archived; no archived_into; all -> decision_history; emit N `knowledge_archive` JSONL records (with `cluster_id` carried but `archived_into` empty / omitted).

### Reverification of phase-plan must-haves vs T02 scope

T02 must address these phase-level truths:
- multi-entry cluster graduation flow (covered).
- reject-path archive flow (covered).
- cluster-atomicity drift abort (covered).
- JSONL `knowledge_graduate` + `knowledge_archive` emission (covered).
- preserved P01 single-entry surface (covered — drift gate is gated on `--cluster`).

The schema-authority lint (T03) and integration test (T04) are NOT T02 deliverables.

## Steps

### Step 1: Replace `scripts/knowledge/graduate.sh` with the extended implementation

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/knowledge/graduate.sh`

Reference implementation:

```bash
#!/usr/bin/env bash
# scripts/knowledge/graduate.sh — Knowledge entry candidate->graduated/archived
# workflow. P03 extension of the P01 minimum-viable scaffold.
#
# Usage:
#   graduate.sh --rationale <text> <entry-id>
#       Single-entry candidate->graduated flip (P01 path; preserved byte-equiv).
#
#   graduate.sh --cluster <id> --rationale <text> <id1> [<id2> ...]
#       Cluster graduation. First positional is the canonical entry (flips to
#       graduated); remaining are siblings (flip to archived with
#       archived_into: <canonical-id>). All members gain a decision_history:
#       record. Emits one knowledge_graduate + N-1 knowledge_archive JSONL
#       records to .orchestrator/execution-log.jsonl (M019 Tier 1 contract).
#
#   graduate.sh --reject --cluster <id> --rationale <text> <id1> [<id2> ...]
#       Cluster rejection. EVERY member flips to archived; no archived_into
#       written. All members gain a decision_history: record. Emits N
#       knowledge_archive JSONL records (cluster_id carried; archived_into
#       empty / omitted).
#
# Cluster atomicity (THREAT-006 mitigation): --cluster modes pre-read every
# member's status and abort with `cluster-membership-drift` if any member is
# not in `candidate` state. Zero file mutations land on drift-abort.
#
# Operator-invoked only (CON-1 read-only-during-dispatch). Dispatched task
# agents MUST NOT call this script directly; it mutates knowledge/ on disk.
#
# FR-9 (schema authority): only mutates {status, decision_history, archived_into}
# fields via the P01 frontmatter helpers. No new fields, no field renames.
#
# Bash 3.2 compatible. AD-19 single-script-invocation shape.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
. "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/detail-utils.sh
. "$SCRIPT_DIR/lib/detail-utils.sh"
# shellcheck source=lib/frontmatter.sh
. "$SCRIPT_DIR/lib/frontmatter.sh"
# shellcheck source=lib/decision-history.sh
. "$SCRIPT_DIR/lib/decision-history.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  graduate.sh --rationale <text> <entry-id>
      Single-entry candidate->graduated flip (P01 path).

  graduate.sh --cluster <id> --rationale <text> <id1> [<id2> ...]
      Cluster graduation: first id is canonical (graduated); rest archived
      with archived_into back-references. All gain a decision_history record.

  graduate.sh --reject --cluster <id> --rationale <text> <id1> [<id2> ...]
      Cluster rejection: every member archived; no archived_into; all gain
      a decision_history record.

  Cluster modes pre-read each member's status and abort with
  `cluster-membership-drift` if any member is not in `candidate` state.

EOF
  exit 1
}

# --- Argument parser ---
rationale=""
cluster_id=""
reject=0
positionals=""

while [ $# -gt 0 ]; do
  case "$1" in
    --rationale)
      [ $# -lt 2 ] && { echo "FAIL: --rationale requires a value" >&2; usage; }
      rationale="$2"; shift 2 ;;
    --cluster)
      [ $# -lt 2 ] && { echo "FAIL: --cluster requires a value" >&2; usage; }
      cluster_id="$2"; shift 2 ;;
    --reject)
      reject=1; shift ;;
    --help|-h)
      usage ;;
    --*)
      echo "FAIL: unknown flag: $1" >&2; usage ;;
    *)
      # Accumulate positionals as newline-separated to dodge IFS issues.
      if [ -z "$positionals" ]; then
        positionals="$1"
      else
        positionals="$positionals
$1"
      fi
      shift ;;
  esac
done

# --- Argument validation ---
[ -z "$rationale" ] && { echo "FAIL: --rationale <text> is required" >&2; usage; }

if [ "$reject" -eq 1 ] && [ -z "$cluster_id" ]; then
  echo "FAIL: --reject requires --cluster <id>" >&2
  usage
fi

if [ -z "$positionals" ]; then
  echo "FAIL: at least one entry-id positional argument is required" >&2
  usage
fi

# --- Resolve positionals to (id, file) pairs and verify existence ---
# Index 0 is canonical when --cluster is set without --reject.
# Bash 3.2: parallel indexed scalars, not associative arrays.
n_members=0
ids=""
files=""
while IFS= read -r id; do
  [ -z "$id" ] && continue
  file="$(find_detail_file "$id" 2>/dev/null || true)"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    echo "FAIL: entry $id not found in knowledge/" >&2
    exit 1
  fi
  if [ "$n_members" -eq 0 ]; then
    ids="$id"
    files="$file"
  else
    ids="$ids
$id"
    files="$files
$file"
  fi
  n_members=$(( n_members + 1 ))
done <<EOF
$positionals
EOF

# --- P01 single-entry path (preserved byte-equivalent surface) ---
if [ -z "$cluster_id" ]; then
  if [ "$n_members" -ne 1 ]; then
    echo "FAIL: only one entry-id positional is accepted without --cluster (got $n_members)" >&2
    usage
  fi

  entry_id="$ids"
  file="$files"

  current="$(fm_read_status "$file")"
  case "$current" in
    graduated)
      echo "NO-OP: $entry_id already graduated"
      exit 0 ;;
    archived)
      echo "FAIL: $entry_id is archived; cannot graduate without --reanimate (not implemented)" >&2
      exit 1 ;;
    candidate)
      fm_write_status "$file" graduated >/dev/null
      operator="$(dh_resolve_operator)"
      fm_append_decision_history "$file" "$rationale" "$operator" "" >/dev/null
      rationale_hash="$(printf '%s' "$rationale" | shasum -a 1 | awk '{print substr($1,1,8)}')"
      dh_emit_jsonl knowledge_graduate \
        "entry_id=$entry_id" "cluster_id=" "rationale_hash=$rationale_hash"
      echo "RATIONALE: $entry_id \"$rationale\""
      echo "GRADUATED: $entry_id from=candidate to=graduated"
      exit 0 ;;
    *)
      echo "FAIL: $entry_id has unrecognized status '$current'" >&2
      exit 1 ;;
  esac
fi

# --- Cluster path (graduate + reject share this prologue) ---

# Phase 1: drift gate. Read every member's status; abort if any non-candidate.
i=0
drift_detected=0
while IFS= read -r id; do
  [ -z "$id" ] && continue
  i=$(( i + 1 ))
  file="$(printf '%s\n' "$files" | awk -v n="$i" 'NR == n { print }')"
  status="$(fm_read_status "$file")"
  if [ "$status" != "candidate" ]; then
    echo "FAIL: cluster-membership-drift entry=$id status=$status cluster=$cluster_id" >&2
    drift_detected=1
  fi
done <<EOF
$ids
EOF

if [ "$drift_detected" -ne 0 ]; then
  echo "FAIL: cluster $cluster_id aborted; no files mutated" >&2
  exit 1
fi

# Phase 2: write loop. Operator + rationale_hash resolved once for the cluster.
operator="$(dh_resolve_operator)"
rationale_hash="$(printf '%s' "$rationale" | shasum -a 1 | awk '{print substr($1,1,8)}')"

# canonical = first member; only relevant when reject=0.
canonical="$(printf '%s\n' "$ids" | sed -n '1p')"

if [ "$reject" -eq 0 ]; then
  # --- Graduate path ---
  i=0
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    i=$(( i + 1 ))
    file="$(printf '%s\n' "$files" | awk -v n="$i" 'NR == n { print }')"
    if [ "$id" = "$canonical" ]; then
      fm_write_status "$file" graduated >/dev/null
      fm_append_decision_history "$file" "$rationale" "$operator" "$cluster_id" >/dev/null
      dh_emit_jsonl knowledge_graduate \
        "entry_id=$id" "cluster_id=$cluster_id" "rationale_hash=$rationale_hash"
      echo "GRADUATED: $id from=candidate to=graduated cluster=$cluster_id"
    else
      fm_write_status "$file" archived >/dev/null
      fm_write_archived_into "$file" "$canonical" >/dev/null
      fm_append_decision_history "$file" "$rationale" "$operator" "$cluster_id" >/dev/null
      dh_emit_jsonl knowledge_archive \
        "entry_id=$id" "cluster_id=$cluster_id" "archived_into=$canonical" \
        "rationale_hash=$rationale_hash"
      echo "ARCHIVED: $id from=candidate to=archived archived_into=$canonical cluster=$cluster_id"
    fi
  done <<EOF
$ids
EOF
  echo "RATIONALE: cluster=$cluster_id \"$rationale\""
  exit 0
fi

# --- Reject path ---
i=0
while IFS= read -r id; do
  [ -z "$id" ] && continue
  i=$(( i + 1 ))
  file="$(printf '%s\n' "$files" | awk -v n="$i" 'NR == n { print }')"
  fm_write_status "$file" archived >/dev/null
  fm_append_decision_history "$file" "$rationale" "$operator" "$cluster_id" >/dev/null
  dh_emit_jsonl knowledge_archive \
    "entry_id=$id" "cluster_id=$cluster_id" "archived_into=" \
    "rationale_hash=$rationale_hash"
  echo "ARCHIVED: $id from=candidate to=archived rejection cluster=$cluster_id"
done <<EOF
$ids
EOF
echo "REJECTED: cluster=$cluster_id rationale=\"$rationale\""
exit 0
```

`chmod +x scripts/knowledge/graduate.sh`.

### Step 2: Create `scripts/verify/m020-p03-graduate-cluster-multi-entry.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p03-graduate-cluster-multi-entry.sh`

```bash
#!/usr/bin/env bash
# m020-p03-graduate-cluster-multi-entry.sh — assert --cluster three-entry
# graduate flips canonical=graduated, siblings=archived w/ archived_into,
# and decision_history appended on every entry.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state"

for id in MEM900 MEM901 MEM902; do
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
last_verified: 2026-04-25
---

# ${id}: cluster fixture
EOF
done

export PROJECT_ROOT="$tmpdir"
export ORCH_ROOT="$tmpdir/orch-state"

if ! bash "$SCRIPT" --cluster Ctest --rationale "merge - same assertion" \
       MEM900 MEM901 MEM902 >/dev/null 2>"$tmpdir/err"; then
  echo "FAIL: graduate.sh --cluster exited non-zero. stderr:"
  cat "$tmpdir/err"
  exit 1
fi

# Canonical (MEM900) -> graduated.
status_canon="$(awk '/^---$/{n++; if (n>=2) exit; next} n==1 && /^status:/{sub(/^status:[[:space:]]*/,""); print; exit}' "$tmpdir/knowledge/patterns/MEM900.md")"
if [ "$status_canon" != "graduated" ]; then
  echo "FAIL: canonical MEM900 status='$status_canon', expected graduated"
  exit 1
fi

# Siblings (MEM901, MEM902) -> archived + archived_into=MEM900.
for sib in MEM901 MEM902; do
  status_sib="$(awk '/^---$/{n++; if (n>=2) exit; next} n==1 && /^status:/{sub(/^status:[[:space:]]*/,""); print; exit}' "$tmpdir/knowledge/patterns/${sib}.md")"
  if [ "$status_sib" != "archived" ]; then
    echo "FAIL: sibling $sib status='$status_sib', expected archived"
    exit 1
  fi
  archived_into="$(awk '/^---$/{n++; if (n>=2) exit; next} n==1 && /^archived_into:/{sub(/^archived_into:[[:space:]]*/,""); print; exit}' "$tmpdir/knowledge/patterns/${sib}.md")"
  if [ "$archived_into" != "MEM900" ]; then
    echo "FAIL: sibling $sib archived_into='$archived_into', expected MEM900"
    exit 1
  fi
done

# All three -> decision_history block present with rationale text.
for id in MEM900 MEM901 MEM902; do
  if ! grep -q '^decision_history:' "$tmpdir/knowledge/patterns/${id}.md"; then
    echo "FAIL: $id missing decision_history block"
    exit 1
  fi
  if ! grep -q 'merge - same assertion' "$tmpdir/knowledge/patterns/${id}.md"; then
    echo "FAIL: $id decision_history missing rationale text"
    exit 1
  fi
done

echo "PASS: --cluster multi-entry graduate flow (canonical+siblings+archived_into+decision_history)"
exit 0
```

`chmod +x` the script.

### Step 3: Create `scripts/verify/m020-p03-graduate-cluster-drift-abort.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p03-graduate-cluster-drift-abort.sh`

```bash
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
  id="${trip%%:*}"; st="${trip##*:}"
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
snap_pre="$(find "$tmpdir/knowledge" -name 'MEM*.md' -type f -exec md5sum {} \; 2>/dev/null \
            || find "$tmpdir/knowledge" -name 'MEM*.md' -type f -exec md5 -r {} \;)"

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
snap_post="$(find "$tmpdir/knowledge" -name 'MEM*.md' -type f -exec md5sum {} \; 2>/dev/null \
             || find "$tmpdir/knowledge" -name 'MEM*.md' -type f -exec md5 -r {} \;)"

if [ "$snap_pre" != "$snap_post" ]; then
  echo "FAIL: drift abort mutated files (atomicity violation):"
  diff <(printf '%s\n' "$snap_pre") <(printf '%s\n' "$snap_post") || true
  exit 1
fi

echo "PASS: cluster-membership-drift abort is atomic (zero file mutations)"
exit 0
```

`chmod +x` the script.

### Step 4: Create `scripts/verify/m020-p03-graduate-reject-path.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p03-graduate-reject-path.sh`

```bash
#!/usr/bin/env bash
# m020-p03-graduate-reject-path.sh — assert --reject --cluster archives every
# member without writing archived_into and emits decision_history on each.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state"

for id in MEM920 MEM921; do
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
last_verified: 2026-04-25
---

# ${id}: reject fixture
EOF
done

export PROJECT_ROOT="$tmpdir"
export ORCH_ROOT="$tmpdir/orch-state"

if ! bash "$SCRIPT" --reject --cluster Crej --rationale "superseded by M021" \
       MEM920 MEM921 >/dev/null 2>"$tmpdir/err"; then
  echo "FAIL: graduate.sh --reject exited non-zero. stderr:"
  cat "$tmpdir/err"
  exit 1
fi

for id in MEM920 MEM921; do
  status="$(awk '/^---$/{n++; if (n>=2) exit; next} n==1 && /^status:/{sub(/^status:[[:space:]]*/,""); print; exit}' "$tmpdir/knowledge/patterns/${id}.md")"
  if [ "$status" != "archived" ]; then
    echo "FAIL: $id status='$status' after reject, expected archived"
    exit 1
  fi
  if grep -q '^archived_into:' "$tmpdir/knowledge/patterns/${id}.md"; then
    echo "FAIL: $id has archived_into after reject (expected absent)"
    exit 1
  fi
  if ! grep -q '^decision_history:' "$tmpdir/knowledge/patterns/${id}.md"; then
    echo "FAIL: $id missing decision_history after reject"
    exit 1
  fi
  if ! grep -q 'superseded by M021' "$tmpdir/knowledge/patterns/${id}.md"; then
    echo "FAIL: $id decision_history missing rationale text"
    exit 1
  fi
done

echo "PASS: --reject --cluster archives every member without archived_into"
exit 0
```

`chmod +x` the script.

### Step 5: Create `scripts/verify/m020-p03-graduate-jsonl-emit.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p03-graduate-jsonl-emit.sh`

```bash
#!/usr/bin/env bash
# m020-p03-graduate-jsonl-emit.sh — assert graduate.sh emits one
# knowledge_graduate + N-1 knowledge_archive records on a cluster graduate,
# and N knowledge_archive records on a cluster reject.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/graduate.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state"

for id in MEM930 MEM931 MEM932; do
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
last_verified: 2026-04-25
---

# ${id}: jsonl fixture
EOF
done

export PROJECT_ROOT="$tmpdir"
export ORCH_ROOT="$tmpdir/orch-state"

LOG="$ORCH_ROOT/execution-log.jsonl"

bash "$SCRIPT" --cluster Cjsonl --rationale "test" MEM930 MEM931 MEM932 >/dev/null 2>&1 || {
  echo "FAIL: graduate.sh --cluster exited non-zero in jsonl test"
  exit 1
}

if [ ! -f "$LOG" ]; then
  echo "FAIL: execution-log.jsonl not created at $LOG"
  exit 1
fi

graduate_count="$(grep -c '"event":"knowledge_graduate"' "$LOG" 2>/dev/null || echo 0)"
archive_count="$(grep -c '"event":"knowledge_archive"' "$LOG" 2>/dev/null || echo 0)"

if [ "$graduate_count" -ne 1 ]; then
  echo "FAIL: expected 1 knowledge_graduate record, got $graduate_count"
  exit 1
fi
if [ "$archive_count" -ne 2 ]; then
  echo "FAIL: expected 2 knowledge_archive records, got $archive_count"
  exit 1
fi

# Reject path: 2 entries -> 2 knowledge_archive records, 0 graduate.
> "$LOG"
mkdir -p "$tmpdir/knowledge/patterns2"
for id in MEM940 MEM941; do
  cat >"$tmpdir/knowledge/patterns2/${id}.md" <<EOF
---
id: ${id}
status: candidate
last_verified: 2026-04-25
---

# ${id}: reject jsonl fixture
EOF
done

bash "$SCRIPT" --reject --cluster Cjr --rationale "test" MEM940 MEM941 >/dev/null 2>&1 || {
  echo "FAIL: graduate.sh --reject exited non-zero in jsonl test"
  exit 1
}

reject_archive_count="$(grep -c '"event":"knowledge_archive"' "$LOG" 2>/dev/null || echo 0)"
reject_graduate_count="$(grep -c '"event":"knowledge_graduate"' "$LOG" 2>/dev/null || echo 0)"

if [ "$reject_archive_count" -ne 2 ]; then
  echo "FAIL: expected 2 knowledge_archive records on reject, got $reject_archive_count"
  exit 1
fi
if [ "$reject_graduate_count" -ne 0 ]; then
  echo "FAIL: expected 0 knowledge_graduate records on reject, got $reject_graduate_count"
  exit 1
fi

echo "PASS: JSONL emission counts match cluster + reject contracts"
exit 0
```

`chmod +x` the script.

### Step 6: Create `scripts/verify/m020-p03-graduate-p01-shape-preserved.sh`

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/verify/m020-p03-graduate-p01-shape-preserved.sh`

```bash
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
out1="$(bash "$SCRIPT" --rationale "p01-shape" MEM950 2>&1)"
rc1=$?
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
out2="$(bash "$SCRIPT" --rationale "p01-shape" MEM951 2>&1)"
rc2=$?
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
```

`chmod +x` the script.

## Must-Haves

- `scripts/knowledge/graduate.sh` extended in place with `--cluster <id>` + `--reject` flags + multi-entry positional shape.
- `--cluster` graduate path: canonical (first id) -> `graduated`; siblings -> `archived` with `archived_into: <canonical-id>`; ALL -> `decision_history:` record via T01 helpers.
- `--reject --cluster` path: every member -> `archived`; no `archived_into:`; ALL -> `decision_history:`.
- Cluster atomicity: pre-flight `fm_read_status` on every member; abort with `cluster-membership-drift` and ZERO file mutations if any member is not `candidate`.
- JSONL emission: one `knowledge_graduate` per graduate path; one `knowledge_archive` per archive (siblings on graduate, all members on reject); records appended to `${ORCH_ROOT}/execution-log.jsonl`.
- P01 single-entry path (`graduate.sh --rationale <text> <entry-id>` with no `--cluster`) preserved byte-equivalently in observable behavior — candidate flip works, NO-OP on graduated works, FAIL on archived works.
- Bash 3.2 + AD-19 + MEM001 conventions throughout.
- The five T02 verifier scripts exist, are executable, and exit 0 with `PASS:` lines.

## Verification

```
bash scripts/verify/m020-p03-graduate-cluster-multi-entry.sh
bash scripts/verify/m020-p03-graduate-cluster-drift-abort.sh
bash scripts/verify/m020-p03-graduate-reject-path.sh
bash scripts/verify/m020-p03-graduate-jsonl-emit.sh
bash scripts/verify/m020-p03-graduate-p01-shape-preserved.sh
```

Each must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/decision-history.sh` (T01)
  - Key API: `dh_resolve_operator` (echoes operator identity); `dh_emit_jsonl <event-type> <kv>...` (appends one JSONL record to `$ORCH_ROOT/execution-log.jsonl`).
  - graduate.sh sources both helpers verbatim.
- `scripts/knowledge/lib/frontmatter.sh` (P01)
  - Key API: `fm_read_status <file>` -> `candidate|graduated|archived`; `fm_write_status <file> <new>` (atomic); `fm_write_archived_into <file> <canonical-id>` (atomic); `fm_append_decision_history <file> <rationale> <operator> <cluster_id>` (atomic).
  - graduate.sh calls each helper directly; cluster atomicity is composed from the per-helper atomicity guarantees.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/index-utils.sh` — `find_detail_file <id>` resolves entry-id to a `knowledge/**/MEM*.md` path. Honors `PROJECT_ROOT` env override per the 4-rule resolver, used by every T02 verifier for fixture isolation.
- `scripts/knowledge/lib/detail-utils.sh` — sourced for `find_detail_file` adjacency (P01 convention).

## Constraints

- **AD-19 / MEM001**: every `Check:` and verification command in this plan is a single-script-file invocation. graduate.sh internals use pipes and heredocs but those live inside the script body, not on Check lines.
- **Bash 3.2**: no associative arrays, no `mapfile`. Use parallel newline-joined scalars (`ids` and `files` accumulated as `$'\n'`-separated strings; iterated via `awk -v n=$i 'NR==n'`).
- **CON-1 / FR-8 (read-only-during-dispatch)**: graduate.sh is operator-invoked; CON-1 is preserved by the existing P01 header comment, retained in the extended version.
- **CON-4 (Surgical Precision)**: The P01 single-entry surface is preserved byte-equivalently in observable behavior. `m020-p03-graduate-p01-shape-preserved.sh` enforces this contract — three cases (candidate flip, idempotent NO-OP, archived FAIL).
- **THREAT-006 mitigation (DC-8)**: pre-flight `fm_read_status` on every cluster member; abort with `cluster-membership-drift` if any non-candidate; zero file mutations on abort. Verified by `m020-p03-graduate-cluster-drift-abort.sh`.
- **Principle XIV (No Speculative Complexity)**: rationale_hash is `sha1(rationale)[0..8]` — no full-rationale duplication into JSONL, no compaction. NG-6 (decision-history compaction) is explicitly out of scope.
- **Principle VI (State On Disk Is Truth)**: every state transition lands on disk via `fm_*` helpers' tempfile+rename pattern before the next operation begins.
- **FR-9 (schema authority)**: graduate.sh only mutates `{status, decision_history, archived_into}` fields — the closed set authorized by D024 + MEM031 + the P03 archive-companion-field schema-evolution note. No new fields.

## Expected Output

After this task:

1. `scripts/knowledge/graduate.sh` is extended (>=200 lines), executable, and the help text documents `--cluster` + `--reject`.
2. All five T02 verifiers exist under `scripts/verify/`, are executable, and pass.
3. `git status knowledge/` is clean (T02 verifiers use tempdirs with `PROJECT_ROOT` overrides; live tree never touched).
4. `git status .orchestrator/execution-log.jsonl` shows no change from T02 verifier runs (verifiers redirect via `ORCH_ROOT` env).

**Done when**: all five verifiers print `PASS:` and exit 0; `git status knowledge/` and `git status .orchestrator/` are clean.
