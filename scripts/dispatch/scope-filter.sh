#!/usr/bin/env bash
# scripts/dispatch/scope-filter.sh — Filter knowledge/decision entries by scope
# Prevents unbounded knowledge/decision injection into dispatch payloads (FR-062, FR-063).
#
# Usage: scope-filter.sh <file-path> <scope-context> [--type knowledge|decisions] [--depends P01,P03]
#                        [--min-confidence CONF] [--category CAT]
#   scope-context: M###/P## format (e.g., M001/P02)
#   --type: auto-detected from filename if not specified
#   --depends: comma-separated list of upstream dependency phase IDs
#   --min-confidence: filter entries with confidence >= threshold (knowledge index only)
#   --category: filter entries by category name (knowledge index only)
#   --use-effective-confidence: apply staleness decay before confidence filtering (knowledge index only)
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

# If file doesn't exist, exit 0 with empty output
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Auto-detect type from filename if not specified
if [[ -z "$FILE_TYPE" ]]; then
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
# Main dispatch
# ========================================================================
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
