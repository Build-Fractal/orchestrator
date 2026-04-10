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

# --- Defaults ---
archive_below=""
min_hits="10"
dry_run=false

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
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

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
