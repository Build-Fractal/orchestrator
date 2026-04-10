#!/usr/bin/env bash
# scripts/knowledge/detect-overlap.sh — Content similarity detection for knowledge entries
# Usage: detect-overlap.sh [--threshold 0.70]
#
# Scans all detail files in knowledge/*/ (excluding archive/), groups by category,
# and computes word-level Jaccard similarity for each pair within the same category.
# Flags pairs exceeding the threshold (default 70%).
#
# Bash 3.2 compatible.

set -euo pipefail

# Resolve script directory and source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"

# --- Defaults ---
threshold="0.70"

# --- Argument parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --threshold)
      threshold="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# --- Resolve project root ---
root="$(get_project_root)"
knowledge_dir="$root/knowledge"

if [ ! -d "$knowledge_dir" ]; then
  echo "ERROR: knowledge/ directory not found at $root" >&2
  exit 1
fi

# --- Extract body text from a detail file (everything after the second ---) ---
# Normalizes to lowercase, strips punctuation, outputs one word per line.
extract_words_to_file() {
  local detail_file="$1"
  local output_file="$2"

  # Get everything after the second --- line
  awk '
    BEGIN { delim_count = 0 }
    /^---$/ { delim_count++; next }
    delim_count >= 2 { print }
  ' "$detail_file" | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9 ]/ /g' | \
    tr -s ' ' '\n' | \
    grep -v '^$' | \
    sort -u > "$output_file"
}

# --- Compute Jaccard similarity between two word files ---
jaccard_similarity() {
  local file_a="$1"
  local file_b="$2"

  # intersection = words in both; union = unique words in either
  local intersection union
  intersection=$(comm -12 "$file_a" "$file_b" | wc -l | tr -d ' ')
  union=$(sort -u "$file_a" "$file_b" | wc -l | tr -d ' ')

  if [ "$union" -eq 0 ]; then
    echo "0.00"
    return
  fi

  echo "$intersection $union" | awk '{ printf "%.2f\n", $1 / $2 }'
}

# --- Create temp directory for word files ---
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# --- Scan category directories ---
found_overlap=false

for cat_dir in "$knowledge_dir"/*/; do
  # Skip if not a directory
  if [ ! -d "$cat_dir" ]; then
    continue
  fi

  # Skip archive directory
  case "$cat_dir" in
    */archive/)
      continue
      ;;
  esac

  category="$(basename "$cat_dir")"

  # Collect MEM files in this category into a temp list
  file_list="$tmp_dir/filelist_${category}.txt"
  : > "$file_list"

  for mem_file in "$cat_dir"MEM*.md; do
    if [ -f "$mem_file" ]; then
      echo "$mem_file" >> "$file_list"
    fi
  done

  # Read file list into positional-style iteration (Bash 3.2 compatible)
  file_count=$(wc -l < "$file_list" | tr -d ' ')
  if [ "$file_count" -lt 2 ]; then
    continue
  fi

  # Pre-extract words for each file
  while IFS= read -r mem_file; do
    mem_id="$(basename "$mem_file" .md)"
    extract_words_to_file "$mem_file" "$tmp_dir/words_${mem_id}.txt"
  done < "$file_list"

  # Compare all pairs within category
  # Read file list into indexed approach via line numbers
  i=1
  while [ "$i" -le "$file_count" ]; do
    file_a=$(sed -n "${i}p" "$file_list")
    id_a="$(basename "$file_a" .md)"

    j=$((i + 1))
    while [ "$j" -le "$file_count" ]; do
      file_b=$(sed -n "${j}p" "$file_list")
      id_b="$(basename "$file_b" .md)"

      similarity=$(jaccard_similarity "$tmp_dir/words_${id_a}.txt" "$tmp_dir/words_${id_b}.txt")

      # Check if similarity exceeds threshold
      exceeds=$(echo "$similarity $threshold" | awk '{ if ($1 + 0 >= $2 + 0) print "yes"; else print "no" }')

      if [ "$exceeds" = "yes" ]; then
        echo "OVERLAP: $id_a and $id_b (category: $category, similarity: $similarity) — review suggested"
        found_overlap=true
      fi

      j=$((j + 1))
    done

    i=$((i + 1))
  done
done

if [ "$found_overlap" = false ]; then
  echo "NO_OVERLAPS: all entries have <70% similarity"
fi
