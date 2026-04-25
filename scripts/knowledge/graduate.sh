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
      if [ $# -lt 2 ]; then
        echo "FAIL: --rationale requires a value" >&2
        usage
      fi
      rationale="$2"
      shift 2
      ;;
    --cluster)
      if [ $# -lt 2 ]; then
        echo "FAIL: --cluster requires a value" >&2
        usage
      fi
      cluster_id="$2"
      shift 2
      ;;
    --reject)
      reject=1
      shift
      ;;
    --help|-h)
      usage
      ;;
    --*)
      echo "FAIL: unknown flag: $1" >&2
      usage
      ;;
    *)
      # Accumulate positionals as newline-separated to dodge IFS issues.
      if [ -z "$positionals" ]; then
        positionals="$1"
      else
        positionals="$positionals
$1"
      fi
      shift
      ;;
  esac
done

# --- Argument validation ---
if [ -z "$rationale" ]; then
  echo "FAIL: --rationale <text> is required" >&2
  usage
fi

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
# Bash 3.2: parallel newline-joined scalars, not associative arrays.
n_members=0
ids=""
files=""
while IFS= read -r id; do
  if [ -z "$id" ]; then
    continue
  fi
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
      exit 0
      ;;
    archived)
      echo "FAIL: $entry_id is archived; cannot graduate without --reanimate (not implemented)" >&2
      exit 1
      ;;
    candidate)
      fm_write_status "$file" graduated >/dev/null
      operator="$(dh_resolve_operator)"
      fm_append_decision_history "$file" "$rationale" "$operator" "" >/dev/null
      rationale_hash="$(printf '%s' "$rationale" | shasum -a 1 | awk '{print substr($1,1,8)}')"
      dh_emit_jsonl knowledge_graduate \
        "entry_id=$entry_id" "cluster_id=" "rationale_hash=$rationale_hash"
      echo "RATIONALE: $entry_id \"$rationale\""
      echo "GRADUATED: $entry_id from=candidate to=graduated"
      exit 0
      ;;
    *)
      echo "FAIL: $entry_id has unrecognized status '$current'" >&2
      exit 1
      ;;
  esac
fi

# --- Cluster path (graduate + reject share this prologue) ---

# Phase 1: drift gate. Read every member's status; abort if any non-candidate.
i=0
drift_detected=0
while IFS= read -r id; do
  if [ -z "$id" ]; then
    continue
  fi
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
    if [ -z "$id" ]; then
      continue
    fi
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
  if [ -z "$id" ]; then
    continue
  fi
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
