#!/usr/bin/env bash
# scripts/knowledge/create-entry.sh — Create a knowledge detail file and update the index
# Usage: create-entry.sh [options]
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
ENTRY_ID=""
CATEGORY=""
CONFIDENCE="0.90"
SCOPE_TAGS=""
SOURCE_UNIT=""
SOURCE_TYPE="execution"
DESCRIPTION=""
BODY=""
SUPERSEDES=""
RELATES_TO=""

# --- Argument parsing (Bash 3.2 compatible while/case) ---
while [ $# -gt 0 ]; do
  case "$1" in
    --id) ENTRY_ID="$2"; shift 2 ;;
    --category) CATEGORY="$2"; shift 2 ;;
    --confidence) CONFIDENCE="$2"; shift 2 ;;
    --scope-tags) SCOPE_TAGS="$2"; shift 2 ;;
    --source-unit) SOURCE_UNIT="$2"; shift 2 ;;
    --source-type) SOURCE_TYPE="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    --supersedes) SUPERSEDES="$2"; shift 2 ;;
    --relates-to) RELATES_TO="$2"; shift 2 ;;
    *) echo "ERROR: unknown option '$1'" >&2; exit 1 ;;
  esac
done

# --- Validate required fields ---
missing=""
if [ -z "$CATEGORY" ]; then missing="$missing --category"; fi
if [ -z "$SCOPE_TAGS" ]; then missing="$missing --scope-tags"; fi
if [ -z "$SOURCE_UNIT" ]; then missing="$missing --source-unit"; fi
if [ -z "$DESCRIPTION" ]; then missing="$missing --description"; fi
if [ -z "$BODY" ]; then missing="$missing --body"; fi

if [ -n "$missing" ]; then
  echo "ERROR: Missing required arguments:$missing" >&2
  exit 1
fi

# --- Auto-generate ID if not provided ---
if [ -z "$ENTRY_ID" ]; then
  ENTRY_ID="$(next_entry_id)"
fi

# --- Resolve project root and detail file path ---
root="$(get_project_root)"
detail_dir="$root/knowledge/$CATEGORY"
detail_file="$detail_dir/$ENTRY_ID.md"

# --- Idempotency check ---
if [ -f "$detail_file" ]; then
  echo "EXISTS: $ENTRY_ID already exists at knowledge/$CATEGORY/$ENTRY_ID.md, skipping"
  exit 0
fi

# --- Format relates_to as YAML list ---
relates_to_yaml="[]"
if [ -n "$RELATES_TO" ]; then
  # Convert comma-separated IDs to YAML inline list: [MEM001, MEM002]
  relates_to_yaml="[$(echo "$RELATES_TO" | sed 's/,/, /g')]"
fi

# --- Get today's date ---
today="$(date +%Y-%m-%d)"

# --- Create detail file ---
mkdir -p "$detail_dir"

cat > "$detail_file" <<EOF
---
id: $ENTRY_ID
scope_tags: "$SCOPE_TAGS"
category: $CATEGORY
confidence: $CONFIDENCE
created_at: $today
last_verified: $today
hit_count: 0
source_unit: "$SOURCE_UNIT"
source_type: $SOURCE_TYPE
supersedes: "$SUPERSEDES"
superseded_by: ""
relates_to: $relates_to_yaml
---

# $ENTRY_ID: $DESCRIPTION

$BODY
EOF

# --- Update the index ---
index_line="$(format_index_entry "$ENTRY_ID" "$SCOPE_TAGS" "$CATEGORY" "$CONFIDENCE" "$today" "$today" "0" "$DESCRIPTION")"
index_add_entry "$index_line"

echo "CREATED: $ENTRY_ID at knowledge/$CATEGORY/$ENTRY_ID.md"
