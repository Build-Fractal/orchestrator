#!/usr/bin/env bash
# scripts/knowledge/create-entry.sh — Create a knowledge detail file and update the index
# Usage: create-entry.sh --category CAT --scope-tags TAGS --source-unit UNIT --description DESC --body BODY [options]
#
# Creates knowledge/{category}/{id}.md with YAML frontmatter and atomically
# updates KNOWLEDGE-INDEX.md. Idempotent: if the detail file already exists,
# prints EXISTS and exits 0.
#
# Bash 3.2 compatible.

set -euo pipefail

# Resolve script directory and source shared utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
source "$SCRIPT_DIR/lib/index-utils.sh"

# --- Defaults ---
entry_id=""
category=""
confidence="0.90"
scope_tags=""
source_unit=""
source_type="execution"
description=""
body=""
supersedes=""
relates_to=""

# --- Argument parsing (Bash 3.2 compatible while/case) ---
while [ $# -gt 0 ]; do
  case "$1" in
    --id)
      entry_id="$2"
      shift 2
      ;;
    --category)
      category="$2"
      shift 2
      ;;
    --confidence)
      confidence="$2"
      shift 2
      ;;
    --scope-tags)
      scope_tags="$2"
      shift 2
      ;;
    --source-unit)
      source_unit="$2"
      shift 2
      ;;
    --source-type)
      source_type="$2"
      shift 2
      ;;
    --description)
      description="$2"
      shift 2
      ;;
    --body)
      body="$2"
      shift 2
      ;;
    --supersedes)
      supersedes="$2"
      shift 2
      ;;
    --relates-to)
      relates_to="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# --- Validate required fields ---
missing=""
if [ -z "$category" ]; then missing="$missing --category"; fi
if [ -z "$scope_tags" ]; then missing="$missing --scope-tags"; fi
if [ -z "$source_unit" ]; then missing="$missing --source-unit"; fi
if [ -z "$description" ]; then missing="$missing --description"; fi
if [ -z "$body" ]; then missing="$missing --body"; fi

if [ -n "$missing" ]; then
  echo "ERROR: Missing required arguments:$missing" >&2
  exit 1
fi

# --- Auto-generate ID if not provided ---
if [ -z "$entry_id" ]; then
  entry_id="$(next_entry_id)"
fi

# --- Resolve project root and detail file path ---
root="$(get_project_root)"
detail_dir="$root/knowledge/$category"
detail_file="$detail_dir/$entry_id.md"

# --- Idempotency check ---
if [ -f "$detail_file" ]; then
  echo "EXISTS: $entry_id already exists"
  exit 0
fi

# --- Format relates_to as YAML list ---
relates_to_yaml="[]"
if [ -n "$relates_to" ]; then
  # Convert comma-separated IDs to YAML inline list: [MEM001, MEM002]
  relates_to_yaml="[$(echo "$relates_to" | sed 's/,/, /g')]"
fi

# --- Get today's date ---
today="$(date +%Y-%m-%d)"

# --- Create detail file ---
mkdir -p "$detail_dir"

cat > "$detail_file" <<EOF
---
id: $entry_id
scope_tags: "$scope_tags"
category: $category
confidence: $confidence
created_at: $today
last_verified: $today
hit_count: 0
source_unit: "$source_unit"
source_type: $source_type
supersedes: "$supersedes"
superseded_by: ""
relates_to: $relates_to_yaml
---

# $entry_id: $description

$body
EOF

# --- Update the index ---
index_line="$(format_index_entry "$entry_id" "$scope_tags" "$category" "$confidence" "$today" "$today" "0" "$description")"
index_add_entry "$index_line"

echo "CREATED: $entry_id at knowledge/$category/$entry_id.md"
