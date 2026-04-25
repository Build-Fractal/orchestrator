#!/usr/bin/env bash
# scripts/knowledge/compute-staleness.sh — Batch staleness report for knowledge entries
# Usage: compute-staleness.sh [--archive-below 0.50] [--min-hits 10] [--dry-run]
#
# Walks all entries in KNOWLEDGE-INDEX.md, computes effective confidence via
# staleness decay, and outputs a report. Optionally auto-archives entries whose
# effective confidence drops below a threshold AND whose hit_count is below min-hits.
#
# Bash 3.2 compatible.

set -euo pipefail

# Resolve script directory and source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/staleness.sh
source "$SCRIPT_DIR/lib/staleness.sh"
# P04: review-queue mode helpers
# shellcheck source=lib/detail-utils.sh
source "$SCRIPT_DIR/lib/detail-utils.sh"
# shellcheck source=lib/frontmatter.sh
source "$SCRIPT_DIR/lib/frontmatter.sh"
# shellcheck source=lib/cluster.sh
source "$SCRIPT_DIR/lib/cluster.sh"

# --- P04 review-queue helpers (FR-4) ---

# Resolve project knowledge root (used when --knowledge-root not supplied).
_p04_default_knowledge_root() {
  local repo_root
  repo_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
  printf '%s\n' "$repo_root/knowledge"
}

# Read .orchestrator/preferences.yml::<key> as a single scalar; echoes empty
# string when the file or key is absent. Reads ONLY the project-level
# preferences file ($PWD/.orchestrator/preferences.yml). User-level cascade
# is deferred to P06.
_p04_read_pref_scalar() {
  local key="$1"
  local prefs_file=".orchestrator/preferences.yml"
  if [ ! -f "$prefs_file" ]; then
    printf '%s\n' ""
    return 0
  fi
  awk -v k="$key" '
    {
      pat = "^" k ":[[:space:]]"
      if ($0 ~ pat) {
        sub(pat, "")
        sub(/[[:space:]]+$/, "")
        sub(/^"/, ""); sub(/"$/, "")
        sub(/^'\''/, ""); sub(/'\''$/, "")
        print
        exit
      }
    }
  ' "$prefs_file" 2>/dev/null || true
}

# Resolve staleness threshold (positive integer, default 14 per OQ-1).
# Malformed scalar -> stderr WARN + default.
_p04_resolve_staleness_threshold() {
  local raw
  raw="$(_p04_read_pref_scalar staleness_threshold)"
  if [ -z "$raw" ]; then
    printf '%s\n' "14"
    return 0
  fi
  case "$raw" in
    ''|*[!0-9]*)
      printf 'WARN: malformed staleness_threshold=%s — using default=14\n' "'$raw'" >&2
      printf '%s\n' "14"
      return 0
      ;;
  esac
  if [ "$raw" -le 0 ]; then
    printf 'WARN: malformed staleness_threshold=%s — using default=14\n' "'$raw'" >&2
    printf '%s\n' "14"
    return 0
  fi
  printf '%s\n' "$raw"
}

# Resolve similarity threshold (positive decimal in (0,1), default 0.7).
# Malformed scalar -> silent default (P05 convention).
_p04_resolve_similarity_threshold() {
  local raw
  raw="$(_p04_read_pref_scalar similarity_threshold)"
  if [ -z "$raw" ]; then
    printf '%s\n' "0.7"
    return 0
  fi
  case "$raw" in
    [0-9].[0-9]*|[0-9]|.[0-9]*) printf '%s\n' "$raw" ;;
    *) printf '%s\n' "0.7" ;;
  esac
}

# Read first non-empty value across the listed keys for a given file.
_p04_first_field() {
  local file="$1"
  shift
  local key val
  for key in "$@"; do
    val="$(fm_field "$file" "$key" 2>/dev/null || true)"
    if [ -n "$val" ]; then
      printf '%s\n' "$val"
      return 0
    fi
  done
  printf '%s\n' ""
}

# Flush one cluster's summary line to stdout.
_p04_flush_one() {
  local cid="$1" can_file="$2" cnt="$3" stale_threshold="$4" today="$5"
  if [ -z "$cid" ] || [ -z "$can_file" ] || [ "$cnt" -eq 0 ]; then
    return 0
  fi
  local topic age stale created
  topic="$(fm_field "$can_file" topic 2>/dev/null || true)"
  if [ -z "$topic" ]; then
    topic=""
  else
    # Collapse whitespace to single underscore so awk-on-whitespace parses ok.
    topic="$(printf '%s' "$topic" | tr -s '[:space:]' '_' )"
  fi
  created="$(_p04_first_field "$can_file" created_at last_verified)"
  if [ -z "$created" ]; then
    age=0
  else
    age="$(days_since "$created" "$today" 2>/dev/null || printf '%s\n' "0")"
  fi
  if [ "$age" -ge "$stale_threshold" ]; then
    stale="true"
  else
    stale="false"
  fi
  printf 'cluster_id=%s topic=%s count=%s oldest_age=%s stale=%s\n' \
    "$cid" "$topic" "$cnt" "$age" "$stale"
}

# Emit the review-queue lines (one per cluster) on stdout, or EMPTY on empty.
_p04_review_queue_emit() {
  local k_root="$knowledge_root"
  if [ -z "$k_root" ]; then
    k_root="$(_p04_default_knowledge_root)"
  fi
  if [ ! -d "$k_root" ]; then
    printf 'WARN: knowledge root not found: %s\n' "$k_root" >&2
    printf '%s\n' "EMPTY"
    return 0
  fi

  local sim_threshold stale_threshold
  sim_threshold="$(_p04_resolve_similarity_threshold)"
  stale_threshold="$(_p04_resolve_staleness_threshold)"

  # cluster_compute emits TAB-separated <cluster-id>\t<member-id> lines
  # sorted by cluster-id asc then member-id asc. Capture into a tempfile so
  # we can iterate without subshell scope issues.
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  local cluster_lines="$tmpdir/clusters.tsv"
  cluster_compute "$k_root" "$sim_threshold" >"$cluster_lines" 2>/dev/null || true

  if [ ! -s "$cluster_lines" ]; then
    printf '%s\n' "EMPTY"
    return 0
  fi

  # Build a member-id -> file-path map for the candidate-filtered tree.
  local id_path_map="$tmpdir/id_paths.tsv"
  : >"$id_path_map"
  local f mid
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    local s
    s="$(fm_read_status "$f" 2>/dev/null || printf '%s\n' "graduated")"
    [ "$s" = "candidate" ] || continue
    mid="$(fm_field "$f" id 2>/dev/null || true)"
    if [ -z "$mid" ]; then
      mid="$(basename "$f" .md)"
    fi
    printf '%s\t%s\n' "$mid" "$f" >>"$id_path_map"
  done < <(find "$k_root" -type f -name 'MEM*.md' 2>/dev/null | sort)

  # Today reference date.
  local today
  today="$(date -u +%Y-%m-%d)"

  # Group cluster_lines by cluster-id, sort by cluster-id, emit one line each.
  local current_cid="" canonical_file="" count=0

  # cluster_compute output is already sorted by cluster-id; iterate streaming.
  local cid mid_local file_path
  while IFS=$'\t' read -r cid mid_local; do
    [ -n "$cid" ] || continue
    if [ "$cid" != "$current_cid" ]; then
      # Flush the previous cluster.
      _p04_flush_one "$current_cid" "$canonical_file" "$count" "$stale_threshold" "$today"
      # Reset.
      current_cid="$cid"
      file_path="$(awk -F '\t' -v id="$mid_local" '$1==id{print $2; exit}' "$id_path_map")"
      canonical_file="$file_path"
      count=1
    else
      count=$(( count + 1 ))
      # Lexicographically-smallest member-id is canonical; cluster_compute
      # already sorts members within a cluster ascending by member-id, so
      # the first member encountered is canonical.
    fi
  done <"$cluster_lines"

  # Flush the last cluster.
  _p04_flush_one "$current_cid" "$canonical_file" "$count" "$stale_threshold" "$today"
}

# --- Defaults ---
archive_below=""
min_hits="10"
dry_run=false
review_queue_mode=false
knowledge_root=""

# --- Argument parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --archive-below)
      archive_below="$2"
      shift 2
      ;;
    --min-hits)
      min_hits="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    --review-queue)
      review_queue_mode=true
      shift
      ;;
    --knowledge-root)
      knowledge_root="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# --- P04 review-queue short-circuit ---
if [ "$review_queue_mode" = "true" ]; then
  _p04_review_queue_emit
  exit 0
fi

# --- Locate the index ---
index_path="$(get_index_path)"

if [ ! -f "$index_path" ]; then
  echo "ERROR: Index not found at $index_path" >&2
  exit 1
fi

# --- Reference date (today) ---
ref_date="$(date +%Y-%m-%d)"

# --- Report header ---
echo "STALENESS REPORT (as of $ref_date)"
echo "=================================================================="
printf "%-8s  %-6s  %-10s  %-5s  %-5s  %s\n" "ID" "RAW" "EFFECTIVE" "DAYS" "HITS" "DESCRIPTION"
echo "------------------------------------------------------------------"

# --- Walk index entries ---
archive_count=0
entry_count=0

while IFS= read -r line; do
  # Skip header lines (comments, blank, format lines)
  case "$line" in
    "#"*|"<"*|""|" "*)
      continue
      ;;
  esac

  # Skip lines that don't start with MEM
  case "$line" in
    MEM*)
      ;;
    *)
      continue
      ;;
  esac

  # Parse pipe-delimited fields using awk
  entry_id=$(echo "$line" | awk -F ' \\| ' '{print $1}' | sed 's/[[:space:]]*$//')
  raw_confidence=$(echo "$line" | awk -F ' \\| ' '{print $4}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  verified_field=$(echo "$line" | awk -F ' \\| ' '{print $6}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  hits_field=$(echo "$line" | awk -F ' \\| ' '{print $7}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  description=$(echo "$line" | awk -F ' \\| ' '{print $8}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Strip "verified:" prefix
  last_verified=$(echo "$verified_field" | sed 's/^verified://')
  # Strip "hits:" prefix
  hit_count=$(echo "$hits_field" | sed 's/^hits://')

  # Default fallbacks
  if [ -z "$last_verified" ] || [ "$last_verified" = "" ]; then
    last_verified="$ref_date"
  fi
  if [ -z "$hit_count" ]; then
    hit_count="0"
  fi

  # Compute effective confidence
  effective=$(compute_effective_confidence "$raw_confidence" "$last_verified" "$ref_date")
  days=$(days_since "$last_verified" "$ref_date")

  entry_count=$((entry_count + 1))

  printf "%-8s  %-6s  %-10s  %-5s  %-5s  %s\n" "$entry_id" "$raw_confidence" "$effective" "$days" "$hit_count" "$description"

  # --- Auto-archive logic ---
  if [ -n "$archive_below" ]; then
    # Check if effective confidence is below threshold AND hit_count is below min_hits
    should_archive=$(echo "$effective $archive_below $hit_count $min_hits" | awk '{
      if ($1 + 0 < $2 + 0 && $3 + 0 < $4 + 0) print "yes"
      else print "no"
    }')

    if [ "$should_archive" = "yes" ]; then
      archive_count=$((archive_count + 1))
      if [ "$dry_run" = true ]; then
        echo "  >> DRY-RUN: Would archive $entry_id (effective=$effective, hits=$hit_count)"
      else
        echo "  >> ARCHIVING: $entry_id (effective=$effective, hits=$hit_count)"
        bash "$SCRIPT_DIR/archive-entry.sh" --id "$entry_id"
      fi
    fi
  fi

done < "$index_path"

echo "=================================================================="
echo "Total entries: $entry_count"
if [ -n "$archive_below" ]; then
  if [ "$dry_run" = true ]; then
    echo "Would archive: $archive_count (threshold=$archive_below, min-hits=$min_hits, dry-run)"
  else
    echo "Archived: $archive_count (threshold=$archive_below, min-hits=$min_hits)"
  fi
fi
