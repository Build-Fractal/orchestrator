#!/usr/bin/env bash
# scripts/dispatch/scope-filter.sh — Filter knowledge/decision entries by scope
# Prevents unbounded knowledge/decision injection into dispatch payloads (FR-062, FR-063).
#
# Usage: scope-filter.sh <file-path> <scope-context> [--type knowledge|decisions] [--depends P01,P03]
#                        [--min-confidence CONF] [--category CAT] [--graph]
#   scope-context: M###/P## format (e.g., M001/P02)
#   --type: auto-detected from filename if not specified
#   --depends: comma-separated list of upstream dependency phase IDs
#   --min-confidence: filter entries with confidence >= threshold (knowledge index only)
#   --category: filter entries by category name (knowledge index only)
#   --use-effective-confidence: apply staleness decay before confidence filtering (knowledge index only)
#   --graph: query knowledge.db directly via SQLite instead of parsing flat files
#
# Output: filtered entries to stdout (same format as input, just filtered)
# Exit 0 on success or if file doesn't exist (empty output).
# Exit 1 on missing arguments.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Argument parsing ---
FILE_PATH=""
SCOPE_CONTEXT=""
FILE_TYPE=""
DEPENDS=""
MIN_CONFIDENCE=""
FILTER_CATEGORY=""
USE_EFFECTIVE_CONFIDENCE=false
GRAPH_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      FILE_TYPE="$2"; shift 2 ;;
    --depends)
      DEPENDS="$2"; shift 2 ;;
    --min-confidence)
      MIN_CONFIDENCE="$2"; shift 2 ;;
    --category)
      FILTER_CATEGORY="$2"; shift 2 ;;
    --use-effective-confidence)
      USE_EFFECTIVE_CONFIDENCE=true; shift ;;
    --graph)
      GRAPH_MODE=true; shift ;;
    -*)
      echo "scope-filter.sh: unknown option '$1'" >&2; exit 1 ;;
    *)
      if [[ -z "$FILE_PATH" ]]; then
        FILE_PATH="$1"
      elif [[ -z "$SCOPE_CONTEXT" ]]; then
        SCOPE_CONTEXT="$1"
      fi
      shift ;;
  esac
done

# Validate required arguments
if [[ -z "$FILE_PATH" || -z "$SCOPE_CONTEXT" ]]; then
  echo "scope-filter.sh: missing required arguments" >&2
  echo "Usage: scope-filter.sh <file-path> <scope-context> [--type knowledge|decisions] [--depends P01,P03]" >&2
  exit 1
fi

# If file doesn't exist and not in graph mode, exit 0 with empty output
if [[ "$GRAPH_MODE" != true && ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Auto-detect type from filename if not specified (skip in graph mode)
if [[ "$GRAPH_MODE" != true && -z "$FILE_TYPE" ]]; then
  basename_lower=$(basename "$FILE_PATH" | tr '[:upper:]' '[:lower:]')
  case "$basename_lower" in
    knowledge*) FILE_TYPE="knowledge" ;;
    decisions*) FILE_TYPE="decisions" ;;
    *)
      echo "scope-filter.sh: cannot auto-detect type for '$FILE_PATH', use --type" >&2
      exit 1
      ;;
  esac
fi

# Parse scope context: M###/P##
MILESTONE_ID=$(echo "$SCOPE_CONTEXT" | cut -d/ -f1)
PHASE_ID=$(echo "$SCOPE_CONTEXT" | cut -d/ -f2)

# --- Lazy source graph-db.sh when --graph mode is active ---
if [ "$GRAPH_MODE" = true ]; then
  # shellcheck source=../knowledge/lib/graph-db.sh
  source "$SCRIPT_DIR/../knowledge/lib/graph-db.sh"
fi

# Build dependency set: current phase + explicit depends
# deps_match checks if a phase ID is in scope
deps_match() {
  local check_phase="$1"
  # Current phase always matches
  if [[ "$check_phase" = "$PHASE_ID" ]]; then
    return 0
  fi
  # Check explicit depends
  if [[ -n "$DEPENDS" ]]; then
    # IFS=',' is local to read -ra (bash built-in) — safe, does not leak
    IFS=',' read -ra dep_list <<< "$DEPENDS"
    for dep in "${dep_list[@]}"; do
      dep=$(echo "$dep" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      if [[ "$dep" = "$check_phase" ]]; then
        return 0
      fi
    done
  fi
  return 1
}

# ========================================================================
# Knowledge filtering
# ========================================================================
filter_knowledge() {
  local include=false
  local in_entry=false
  local entry_lines=""
  local entry_scope=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Detect entry header: ## K###: Title [scope-tag]
    if echo "$line" | grep -qE '^## [A-Z][A-Za-z0-9]+:'; then
      # Output previous entry if it was included
      if [[ "$in_entry" = true && "$include" = true ]]; then
        printf '%s\n' "$entry_lines"
      fi

      in_entry=true
      entry_lines="$line"
      include=false

      # Extract scope tag from the line: [project], [milestone:M001], [phase:M001/P02]
      local scope_tag
      scope_tag=$(echo "$line" | grep -oE '\[[a-z]+:[A-Za-z0-9/]+\]|\[project\]' || true)

      if [[ -z "$scope_tag" ]]; then
        # No scope tag — include by default (project-level)
        include=true
      elif [[ "$scope_tag" = "[project]" ]]; then
        include=true
      elif echo "$scope_tag" | grep -qE '^\[milestone:'; then
        # Extract milestone from tag
        local tag_milestone
        tag_milestone=$(echo "$scope_tag" | sed 's/\[milestone://' | sed 's/\]//')
        if [[ "$tag_milestone" = "$MILESTONE_ID" ]]; then
          include=true
        fi
      elif echo "$scope_tag" | grep -qE '^\[phase:'; then
        # Extract phase scope: phase:M001/P02
        local tag_scope
        tag_scope=$(echo "$scope_tag" | sed 's/\[phase://' | sed 's/\]//')
        local tag_milestone tag_phase
        tag_milestone=$(echo "$tag_scope" | cut -d/ -f1)
        tag_phase=$(echo "$tag_scope" | cut -d/ -f2)
        if [[ "$tag_milestone" = "$MILESTONE_ID" && "$tag_phase" = "$PHASE_ID" ]]; then
          include=true
        fi
      fi
    elif [[ "$in_entry" = true ]]; then
      # Continuation of current entry
      entry_lines="$entry_lines
$line"
    else
      # Lines before any entry (e.g., top-level heading "# Knowledge")
      echo "$line"
    fi
  done < "$FILE_PATH"

  # Output last entry if included
  if [[ "$in_entry" = true && "$include" = true ]]; then
    printf '%s\n' "$entry_lines"
  fi
}

# ========================================================================
# Knowledge INDEX filtering (pipe-delimited KNOWLEDGE-INDEX.md format)
# Format: MEM### | [scope_tags] | category | confidence | created_at | verified:date | hits:N | description
# ========================================================================
filter_knowledge_index() {
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Pass through comment/header lines (# headings, <!-- comments -->, blank lines)
    if echo "$line" | grep -qE '^(#|<!--|$)'; then
      echo "$line"
      continue
    fi

    # Skip lines that don't look like data entries (MEM### |)
    if ! echo "$line" | grep -qE '^MEM[0-9]+ \|'; then
      echo "$line"
      continue
    fi

    # Parse pipe-delimited fields:
    # 1=id, 2=scope_tags, 3=category, 4=confidence, 5=created_at, 6=verified, 7=hits, 8=description
    local entry_id scope_tag category confidence
    entry_id=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); print $1}')
    scope_tag=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
    category=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')
    confidence=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4}')

    # --- Category filter ---
    if [[ -n "$FILTER_CATEGORY" && "$category" != "$FILTER_CATEGORY" ]]; then
      continue
    fi

    # --- Confidence filter ---
    if [[ -n "$MIN_CONFIDENCE" ]]; then
      local effective_conf="$confidence"

      # When --use-effective-confidence is set, compute staleness-decayed confidence
      if [[ "$USE_EFFECTIVE_CONFIDENCE" = true ]]; then
        # Source staleness library (lazy, only when needed)
        if [[ -z "${_STALENESS_SOURCED:-}" ]]; then
          # shellcheck source=../knowledge/lib/staleness.sh
          source "$SCRIPT_DIR/../knowledge/lib/staleness.sh"
          _STALENESS_SOURCED=1
        fi
        # Extract last_verified date from field 6 (strip "verified:" prefix)
        local verified_raw
        verified_raw=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $6); print $6}')
        local verified_date
        verified_date=$(echo "$verified_raw" | sed 's/^verified://')
        if [[ -n "$verified_date" ]]; then
          effective_conf=$(compute_effective_confidence "$confidence" "$verified_date")
        fi
      fi

      # Compare as integers (multiply by 100 to avoid float issues in bash)
      local conf_int min_int
      conf_int=$(echo "$effective_conf" | awk '{printf "%d", $1 * 100}')
      min_int=$(echo "$MIN_CONFIDENCE" | awk '{printf "%d", $1 * 100}')
      if [[ "$conf_int" -lt "$min_int" ]]; then
        continue
      fi
    fi

    # --- Scope tag filter (reuse existing matching logic) ---
    local include=false

    if [[ -z "$scope_tag" ]]; then
      # No scope tag — include by default (project-level)
      include=true
    elif [[ "$scope_tag" = "[project]" ]]; then
      include=true
    elif echo "$scope_tag" | grep -qE '^\[milestone:'; then
      # Extract milestone from tag
      local tag_milestone
      tag_milestone=$(echo "$scope_tag" | sed 's/\[milestone://' | sed 's/\]//')
      if [[ "$tag_milestone" = "$MILESTONE_ID" ]]; then
        include=true
      fi
    elif echo "$scope_tag" | grep -qE '^\[phase:'; then
      # Extract phase scope: phase:M###/P##
      local tag_scope tag_milestone tag_phase
      tag_scope=$(echo "$scope_tag" | sed 's/\[phase://' | sed 's/\]//')
      tag_milestone=$(echo "$tag_scope" | cut -d/ -f1)
      tag_phase=$(echo "$tag_scope" | cut -d/ -f2)
      if [[ "$tag_milestone" = "$MILESTONE_ID" ]]; then
        if deps_match "$tag_phase"; then
          include=true
        fi
      fi
    fi

    if [[ "$include" = true ]]; then
      echo "$line"
    fi
  done < "$FILE_PATH"
}

# ========================================================================
# Decisions filtering
# ========================================================================
filter_decisions() {
  local header_done=false

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Pass through header lines (# heading, blank lines, table header, separator)
    if [[ "$header_done" = false ]]; then
      # Table header row starts with | ID or |---
      if echo "$line" | grep -qE '^\|[[:space:]]*-'; then
        echo "$line"
        header_done=true
        continue
      fi
      echo "$line"
      continue
    fi

    # Data rows: | D### | Decision | Choice | Scope | When | Rationale |
    if ! echo "$line" | grep -qE '^\|[[:space:]]*D[0-9]'; then
      # Not a data row — pass through (e.g., trailing blank lines)
      echo "$line"
      continue
    fi

    # Parse the row — extract Scope and When columns
    # Column positions: 1=ID, 2=Decision, 3=Choice, 4=Scope, 5=When, 6=Rationale
    local scope_col when_col
    scope_col=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $5); print $5}')
    when_col=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $6); print $6}')

    # Determine inclusion
    local include=false

    # Extract milestone and phase from When column (M###/P## format)
    local when_milestone when_phase
    when_milestone=$(echo "$when_col" | grep -oE 'M[0-9]+' | head -1 || true)
    when_phase=$(echo "$when_col" | grep -oE 'P[0-9]+' | head -1 || true)

    # Include if: same milestone and (current phase, upstream dep, or arch scope)
    if [[ "$when_milestone" = "$MILESTONE_ID" ]]; then
      # Architectural scope — include milestone-wide
      if echo "$scope_col" | grep -qi 'arch'; then
        include=true
      # Current phase
      elif [[ -n "$when_phase" ]] && deps_match "$when_phase"; then
        include=true
      fi
    fi

    if [[ "$include" = true ]]; then
      echo "$line"
    fi
  done < "$FILE_PATH"
}

# ========================================================================
# Graph-mode knowledge filtering (SQLite-based)
# ========================================================================
filter_knowledge_graph() {
  local db_path
  db_path="$(get_db_path)"

  if [ ! -f "$db_path" ]; then
    echo "scope-filter.sh: knowledge.db not found — run rebuild-index.sh first" >&2
    exit 0
  fi

  # --- Build scope WHERE clause ---
  local scope_clause=""
  if [ -n "$SCOPE_CONTEXT" ]; then
    scope_clause="AND (st.tag IS NULL OR st.tag = '[project]'"
    if [ -n "$MILESTONE_ID" ]; then
      scope_clause="${scope_clause} OR st.tag = '[milestone:${MILESTONE_ID}]'"
    fi
    if [ -n "$MILESTONE_ID" ] && [ -n "$PHASE_ID" ]; then
      scope_clause="${scope_clause} OR st.tag = '[phase:${MILESTONE_ID}/${PHASE_ID}]'"
    fi
    if [ -n "$DEPENDS" ] && [ -n "$MILESTONE_ID" ]; then
      old_ifs="$IFS"
      IFS=','
      for dep in $DEPENDS; do
        dep="$(printf '%s' "$dep" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
        if [ -n "$dep" ]; then
          scope_clause="${scope_clause} OR st.tag = '[phase:${MILESTONE_ID}/${dep}]'"
        fi
      done
      IFS="$old_ifs"
    fi
    scope_clause="${scope_clause})"
  fi

  # --- Build confidence WHERE clause ---
  local conf_clause=""
  if [ -n "$MIN_CONFIDENCE" ]; then
    conf_clause="AND e.confidence >= ${MIN_CONFIDENCE}"
  fi

  # --- Build category WHERE clause ---
  local cat_clause=""
  if [ -n "$FILTER_CATEGORY" ]; then
    local safe_cat
    safe_cat="$(printf '%s' "$FILTER_CATEGORY" | sed "s/'/''/g")"
    cat_clause="AND e.category = '${safe_cat}'"
  fi

  # --- Exclude superseded entries ---
  local superseded_clause="AND (e.superseded_by = '' OR e.superseded_by IS NULL)"

  # --- Build and execute query ---
  # GROUP BY e.id to produce exactly one row per entry even when multiple
  # scope_tags match the WHERE clause (e.g. [project] AND [milestone:M005]).
  local sql="
SELECT e.id, GROUP_CONCAT(st.tag, ', ') AS scope_tag, e.category,
       e.confidence, e.created_at,
       'verified:' || e.last_verified AS verified,
       'hits:' || e.hit_count AS hits,
       e.description
FROM entries e
LEFT JOIN scope_tags st ON e.id = st.entry_id
WHERE 1=1
  ${scope_clause}
  ${conf_clause}
  ${cat_clause}
  ${superseded_clause}
GROUP BY e.id
ORDER BY e.confidence DESC;
"

  # --- Execute and format output ---
  local raw_results
  raw_results="$(db_query "$db_path" "$sql")" || true

  if [ -z "$raw_results" ]; then
    return 0
  fi

  # --- Print header ---
  echo "# Knowledge Index"
  echo "<!-- Generated via --graph mode from knowledge.db -->"
  echo "<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->"

  # --- Format each row as pipe-delimited ---
  # sqlite3 default separator is |, so parse and reformat with spaces around pipes
  while IFS='|' read -r id tag cat conf created verified hits desc; do
    echo "${id} | ${tag} | ${cat} | ${conf} | ${created} | ${verified} | ${hits} | ${desc}"
  done <<EOF_RESULTS
$raw_results
EOF_RESULTS
}

# ========================================================================
# Main dispatch
# ========================================================================

# --- Graph mode bypasses file-based filtering ---
if [ "$GRAPH_MODE" = true ]; then
  filter_knowledge_graph
  exit 0
fi

case "$FILE_TYPE" in
  knowledge)
    # Auto-detect: KNOWLEDGE-INDEX.md (pipe-delimited) vs flat KNOWLEDGE.md (markdown sections)
    is_index=false
    if echo "$FILE_PATH" | grep -qiE 'INDEX\.md$'; then
      is_index=true
    elif head -10 "$FILE_PATH" 2>/dev/null | grep -qE '^MEM[0-9]+ \|'; then
      is_index=true
    fi
    if [[ "$is_index" = true ]]; then
      filter_knowledge_index
    else
      filter_knowledge
    fi
    ;;
  decisions)
    filter_decisions
    ;;
  *)
    echo "scope-filter.sh: unknown file type '$FILE_TYPE' (use knowledge or decisions)" >&2
    exit 1
    ;;
esac
