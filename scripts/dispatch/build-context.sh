#!/usr/bin/env bash
# scripts/dispatch/build-context.sh — Assemble dispatch payload for task execution
# Builds a pre-inlined dispatch payload with manifest header from orchestrator state,
# using the knowledge index architecture (P04).
#
# Usage: build-context.sh <orchestrator-root> <milestone-id> <phase-id> <task-id> [--config-defaults <file>]
#   orchestrator-root: the .specify/orchestrator/ directory (or fixture milestone dir)
#   milestone-id: M### (e.g., M001)
#   phase-id: P## (e.g., P02)
#   task-id: T## (e.g., T01) or PHASE_PLAN for planning payload
#   --config-defaults: optional config file for context_verbosity etc.
#
# When task-id is PHASE_PLAN, assembles a planning context payload instead of
# a task execution payload. Includes roadmap phase section, upstream summaries,
# feature spec references, context draft, decisions, and knowledge.
#
# Section ordering (static first for prompt caching):
#   1. Project context (project-level knowledge) — STATIC
#   2. Architectural decisions — STATIC
#   3. Project-wide knowledge — STATIC
#   4. Phase Goal & Must-Haves — SEMI-STATIC
#   5. Upstream Summaries — DYNAMIC
#   6. Task Plan — DYNAMIC
#
# Output: assembled dispatch prompt to stdout (with manifest header)
# Stderr: "Context payload: X bytes (Y% of total artifacts)" — budget monitoring
# Exit 0 on success. Exit 1 on missing arguments or required files.
#
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCOPE_FILTER="$SCRIPT_DIR/scope-filter.sh"
READ_ROADMAP="$PROJECT_ROOT/scripts/state/read-roadmap.sh"
READ_CONFIG="$PROJECT_ROOT/scripts/state/read-config.sh"

# Knowledge scripts
TRAVERSE_GRAPH="$PROJECT_ROOT/scripts/knowledge/traverse-graph.sh"
RESOLVE_ENTRIES="$PROJECT_ROOT/scripts/knowledge/resolve-entries.sh"
INCREMENT_HITS="$PROJECT_ROOT/scripts/knowledge/increment-hits.sh"

# --- Argument parsing ---
ORCH_ROOT=""
MILESTONE_ID=""
PHASE_ID=""
TASK_ID=""
CONFIG_DEFAULTS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-defaults)
      CONFIG_DEFAULTS="$2"; shift 2 ;;
    -*)
      echo "build-context.sh: unknown option '$1'" >&2; exit 1 ;;
    *)
      if [[ -z "$ORCH_ROOT" ]]; then
        ORCH_ROOT="$1"
      elif [[ -z "$MILESTONE_ID" ]]; then
        MILESTONE_ID="$1"
      elif [[ -z "$PHASE_ID" ]]; then
        PHASE_ID="$1"
      elif [[ -z "$TASK_ID" ]]; then
        TASK_ID="$1"
      fi
      shift ;;
  esac
done

# Validate required arguments
if [[ -z "$ORCH_ROOT" || -z "$MILESTONE_ID" || -z "$PHASE_ID" || -z "$TASK_ID" ]]; then
  echo "build-context.sh: missing required arguments" >&2
  echo "Usage: build-context.sh <orchestrator-root> <milestone-id> <phase-id> <task-id> [--config-defaults <file>]" >&2
  exit 1
fi

# --- Resolve paths ---
# Support both .specify/orchestrator/milestones/M001 and fixture dirs where ORCH_ROOT is the milestone
# Try: <root>/milestones/<M###>/ first, then treat <root> as the milestone dir itself
MILESTONE_DIR=""
if [[ -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ]]; then
  MILESTONE_DIR="$ORCH_ROOT/milestones/$MILESTONE_ID"
elif [[ -d "$ORCH_ROOT/phases" ]]; then
  # Fixture mode: root IS the milestone directory
  MILESTONE_DIR="$ORCH_ROOT"
else
  echo "build-context.sh: milestone directory not found at '$ORCH_ROOT/milestones/$MILESTONE_ID' or '$ORCH_ROOT'" >&2
  exit 1
fi

PHASE_DIR="$MILESTONE_DIR/phases/$PHASE_ID"
ROADMAP="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"
IS_PLANNING=false
if [[ "$TASK_ID" = "PHASE_PLAN" ]]; then
  IS_PLANNING=true
fi

if [[ ! -f "$ROADMAP" ]]; then
  echo "build-context.sh: roadmap not found: $ROADMAP" >&2
  exit 1
fi

if [[ "$IS_PLANNING" = "false" ]]; then
  TASK_PLAN="$PHASE_DIR/tasks/${TASK_ID}-PLAN.md"
  PHASE_PLAN="$PHASE_DIR/${PHASE_ID}-PLAN.md"

  if [[ ! -f "$TASK_PLAN" ]]; then
    echo "build-context.sh: task plan not found: $TASK_PLAN" >&2
    exit 1
  fi

  if [[ ! -f "$PHASE_PLAN" ]]; then
    echo "build-context.sh: phase plan not found: $PHASE_PLAN" >&2
    exit 1
  fi
fi

# --- Read config values ---
config_read() {
  local key="$1"
  local default="$2"
  local value=""
  if [[ -n "$CONFIG_DEFAULTS" && -f "$CONFIG_DEFAULTS" ]]; then
    value=$(bash "$READ_CONFIG" "$key" --defaults "$CONFIG_DEFAULTS" 2>/dev/null) || true
  fi
  if [[ -z "$value" || "$value" = "null" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

CONTEXT_VERBOSITY=$(config_read "context_verbosity" "standard")
DURATION_BUDGET=$(config_read "duration_budget" "2h")
DISPATCH_BUDGET=$(config_read "dispatch_budget" "3")
BUDGET_ENFORCEMENT=$(config_read "budget_enforcement" "warn")

# --- Read tier from roadmap ---
TIER=$(bash "$READ_ROADMAP" "$ROADMAP" tier 2>/dev/null) || TIER="unknown"

# --- Read phase dependencies ---
PHASE_DATA=$(bash "$READ_ROADMAP" "$ROADMAP" phase "$PHASE_ID" 2>/dev/null) || PHASE_DATA=""
DEPENDS="none"
if [[ -n "$PHASE_DATA" ]]; then
  DEPENDS=$(echo "$PHASE_DATA" | awk '{print $4}')
fi

# ============================================================================
# Knowledge index-based context gathering
# ============================================================================

# Locate the knowledge index (try project root via index-utils, then milestone dir)
KNOWLEDGE_INDEX=""
if [[ -f "$PROJECT_ROOT/KNOWLEDGE-INDEX.md" ]]; then
  KNOWLEDGE_INDEX="$PROJECT_ROOT/KNOWLEDGE-INDEX.md"
elif [[ -f "$MILESTONE_DIR/KNOWLEDGE-INDEX.md" ]]; then
  KNOWLEDGE_INDEX="$MILESTONE_DIR/KNOWLEDGE-INDEX.md"
fi

# Temp file for passing included entry IDs from subshell back to parent
INCLUDED_IDS_FILE="$(mktemp)"

# --- Gather knowledge via index pipeline ---
# Note: this function runs in a subshell via $(...), so it writes entry IDs
# to INCLUDED_IDS_FILE instead of setting a variable.
gather_knowledge_from_index() {
  local entries=""
  if [[ "$CONTEXT_VERBOSITY" = "minimal" ]]; then
    echo "No knowledge entries in scope."
    return
  fi

  if [[ -z "$KNOWLEDGE_INDEX" ]]; then
    # Fall back to flat KNOWLEDGE.md
    gather_knowledge_flat
    return
  fi

  # Step 1: Run scope-filter on the index to get matching entry lines
  local dep_flag=""
  if [[ "$DEPENDS" != "none" ]]; then
    dep_flag="--depends $DEPENDS"
  fi

  local filtered_lines
  filtered_lines=$(bash "$SCOPE_FILTER" "$KNOWLEDGE_INDEX" "$MILESTONE_ID/$PHASE_ID" --type knowledge $dep_flag 2>/dev/null) || true

  if [[ -z "$filtered_lines" ]]; then
    echo "No knowledge entries in scope."
    return
  fi

  # Step 2: Extract entry IDs from filtered lines
  local matched_ids=""
  while IFS= read -r line; do
    local eid
    eid=$(echo "$line" | grep -oE '^MEM[0-9]+' || true)
    if [[ -n "$eid" ]]; then
      if [[ -z "$matched_ids" ]]; then
        matched_ids="$eid"
      else
        matched_ids="$matched_ids
$eid"
      fi
    fi
  done <<EOF_FILTERED
$filtered_lines
EOF_FILTERED

  if [[ -z "$matched_ids" ]]; then
    echo "No knowledge entries in scope."
    return
  fi

  # Step 3: For each matched entry, traverse graph for related entries (1-hop, max 5)
  local related_ids=""
  while IFS= read -r mid; do
    [[ -z "$mid" ]] && continue
    local traversed
    traversed=$(bash "$TRAVERSE_GRAPH" --id "$mid" --max-depth 1 --max-entries 5 2>/dev/null) || true
    if [[ -n "$traversed" ]]; then
      if [[ -z "$related_ids" ]]; then
        related_ids="$traversed"
      else
        related_ids="$related_ids
$traversed"
      fi
    fi
  done <<EOF_MATCHED
$matched_ids
EOF_MATCHED

  # Step 4: Combine matched + related IDs (deduplicate)
  local all_ids="$matched_ids"
  if [[ -n "$related_ids" ]]; then
    all_ids="$all_ids
$related_ids"
  fi
  # Deduplicate
  all_ids=$(echo "$all_ids" | sort -u)

  # Write IDs to temp file for hit counting (survives subshell)
  echo "$all_ids" > "$INCLUDED_IDS_FILE"

  # Step 5: Resolve entries to get actual content
  local resolved
  resolved=$(echo "$all_ids" | bash "$RESOLVE_ENTRIES" 2>/dev/null) || true

  if [[ -z "$resolved" ]]; then
    echo "No knowledge entries in scope."
  else
    # Count entries
    local entry_count
    entry_count=$(echo "$all_ids" | grep -c 'MEM' || echo "0")
    echo "<!-- $entry_count knowledge entries resolved from index -->"
    echo ""
    echo "$resolved"
  fi
}

# Fallback: flat KNOWLEDGE.md (original behavior)
gather_knowledge_flat() {
  local entries=""
  local knowledge_file="$MILESTONE_DIR/KNOWLEDGE.md"
  if [[ -f "$knowledge_file" ]]; then
    local dep_flag=""
    if [[ "$DEPENDS" != "none" ]]; then
      dep_flag="--depends $DEPENDS"
    fi
    entries=$(bash "$SCOPE_FILTER" "$knowledge_file" "$MILESTONE_ID/$PHASE_ID" --type knowledge $dep_flag 2>/dev/null) || true
  fi
  if [[ -z "$entries" ]]; then
    echo "No knowledge entries in scope."
  else
    echo "$entries"
  fi
}

# --- Scope-filtered decisions ---
gather_decisions() {
  local entries=""
  if [[ "$CONTEXT_VERBOSITY" != "minimal" ]]; then
    local decisions_file="$MILESTONE_DIR/DECISIONS.md"
    if [[ -f "$decisions_file" ]]; then
      local dep_flag=""
      if [[ "$DEPENDS" != "none" ]]; then
        dep_flag="--depends $DEPENDS"
      fi
      entries=$(bash "$SCOPE_FILTER" "$decisions_file" "$MILESTONE_ID/$PHASE_ID" --type decisions $dep_flag 2>/dev/null) || true
    fi
  fi
  if [[ -z "$entries" ]]; then
    echo "No decision entries in scope."
  else
    echo "$entries"
  fi
}

# --- Gather upstream summaries ---
gather_upstream_summaries() {
  local summaries=""
  if [[ "$DEPENDS" != "none" && "$CONTEXT_VERBOSITY" != "minimal" ]]; then
    IFS=',' read -ra dep_list <<< "$DEPENDS"
    for dep in "${dep_list[@]}"; do
      dep=$(echo "$dep" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      local summary_file="$MILESTONE_DIR/phases/$dep/${dep}-SUMMARY.md"
      if [[ -f "$summary_file" ]]; then
        summaries="${summaries}
### ${dep} Summary
$(cat "$summary_file")
"
      fi
    done
  fi
  if [[ -z "$summaries" ]]; then
    echo "No upstream summaries available."
  else
    echo "$summaries"
  fi
}

# --- Gather content ---
KNOWLEDGE_ENTRIES=$(gather_knowledge_from_index)
DECISION_ENTRIES=$(gather_decisions)
UPSTREAM_SUMMARIES=$(gather_upstream_summaries)

# ============================================================================
# Assemble sections into ordered list for manifest generation
# ============================================================================

# We build each section as a named block, then assemble with accurate line counting.
# Temp file approach: write each section to temp files, then concatenate with manifest.

TMPDIR_BUILD="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BUILD"; rm -f "$INCLUDED_IDS_FILE"' EXIT

# --- Estimate tokens: chars / 4, rounded to nearest 100 ---
estimate_tokens() {
  local text="$1"
  local chars
  chars=$(printf '%s' "$text" | wc -c | tr -d ' ')
  local raw_tokens=$((chars / 4))
  # Round to nearest 100
  local rounded=$(( ((raw_tokens + 50) / 100) * 100 ))
  if [[ "$rounded" -eq 0 && "$raw_tokens" -gt 0 ]]; then
    rounded=100
  fi
  echo "$rounded"
}

# ============================================================================
# PHASE_PLAN mode — planning context payload
# ============================================================================
if [[ "$IS_PLANNING" = "true" ]]; then

  # --- Extract roadmap section for this phase ---
  ROADMAP_SECTION=""
  if [[ -f "$ROADMAP" ]]; then
    ROADMAP_SECTION=$(sed -n "/\\*\\*${PHASE_ID}\\*\\*/,/\\*\\*P[0-9]/p" "$ROADMAP" | sed '$d' || true)
    if [[ -z "$ROADMAP_SECTION" ]]; then
      ROADMAP_SECTION=$(sed -n "/\\*\\*${PHASE_ID}\\*\\*/,\$p" "$ROADMAP" || true)
    fi
  fi
  if [[ -z "$ROADMAP_SECTION" ]]; then
    ROADMAP_SECTION="Phase section not found in roadmap."
  fi

  # --- Read context draft if it exists ---
  CONTEXT_DRAFT=""
  CONTEXT_FILE="$ORCH_ROOT/CONTEXT.md"
  if [[ -f "$CONTEXT_FILE" ]]; then
    CONTEXT_DRAFT=$(cat "$CONTEXT_FILE")
  fi
  if [[ -z "$CONTEXT_DRAFT" && -f "$MILESTONE_DIR/CONTEXT.md" ]]; then
    CONTEXT_DRAFT=$(cat "$MILESTONE_DIR/CONTEXT.md")
  fi
  if [[ -z "$CONTEXT_DRAFT" ]]; then
    CONTEXT_DRAFT="No context draft available."
  fi

  # --- Find feature spec ---
  # Resolve the correct spec for THIS milestone via roadmap frontmatter, not
  # via `find ... -name spec.md | head -1` (which is non-deterministic in repos
  # with multiple feature specs — see AP-00x: wrong feature spec in payload).
  FEATURE_SPEC=""
  PROJECT_DIR=""
  candidate="$ORCH_ROOT"
  while [[ "$candidate" != "/" ]]; do
    if [[ "$(basename "$candidate")" = ".specify" ]]; then
      PROJECT_DIR="$(dirname "$candidate")"
      break
    fi
    if [[ -d "$candidate/.specify" ]]; then
      PROJECT_DIR="$candidate"
      break
    fi
    candidate="$(dirname "$candidate")"
  done

  spec_file=""
  if [[ -n "$PROJECT_DIR" ]]; then
    # 1. Prefer explicit feature_spec from roadmap frontmatter
    fm_feature_spec=$(bash "$READ_ROADMAP" "$ROADMAP" frontmatter 2>/dev/null \
      | grep '^feature_spec=' | head -1 | sed 's/^feature_spec=//')
    if [[ -n "$fm_feature_spec" && "$fm_feature_spec" != "null" ]]; then
      # Resolve relative paths against the project dir
      if [[ "$fm_feature_spec" = /* ]]; then
        spec_file="$fm_feature_spec"
      else
        spec_file="$PROJECT_DIR/$fm_feature_spec"
      fi
    fi

    # 2. Fall back to feature_ref -> specs/<feature_ref>/spec.md
    if [[ -z "$spec_file" || ! -f "$spec_file" ]]; then
      fm_feature_ref=$(bash "$READ_ROADMAP" "$ROADMAP" frontmatter 2>/dev/null \
        | grep '^feature_ref=' | head -1 | sed 's/^feature_ref=//')
      if [[ -n "$fm_feature_ref" && "$fm_feature_ref" != "null" ]]; then
        spec_file="$PROJECT_DIR/specs/$fm_feature_ref/spec.md"
      fi
    fi

    # 3. Last-resort fallback: scan specs dir only if exactly one spec.md exists
    #    (multi-spec repos must set feature_spec or feature_ref in the roadmap)
    if [[ -z "$spec_file" || ! -f "$spec_file" ]]; then
      spec_count=$(find "$PROJECT_DIR/specs" -name "spec.md" -type f 2>/dev/null | wc -l | tr -d ' ')
      if [[ "$spec_count" = "1" ]]; then
        spec_file=$(find "$PROJECT_DIR/specs" -name "spec.md" -type f 2>/dev/null | head -1)
      fi
    fi

    if [[ -n "$spec_file" && -f "$spec_file" ]]; then
      FEATURE_SPEC=$(cat "$spec_file")
    fi
  fi
  if [[ -z "$FEATURE_SPEC" ]]; then
    FEATURE_SPEC="Feature spec not found."
  fi

  # --- Build sections in cache-friendly order ---
  # Section 1: Knowledge (STATIC — project-level)
  SEC_KNOWLEDGE="## Knowledge

$KNOWLEDGE_ENTRIES"

  # Section 2: Decisions (STATIC)
  SEC_DECISIONS="## Decisions

$DECISION_ENTRIES"

  # Section 3: Context Draft (SEMI-STATIC)
  SEC_CONTEXT="## Context Draft

$CONTEXT_DRAFT"

  # Section 4: Feature Spec (SEMI-STATIC)
  SEC_FEATURE="## Feature Spec

$FEATURE_SPEC"

  # Section 5: Upstream Context (DYNAMIC)
  SEC_UPSTREAM="## Upstream Context

$UPSTREAM_SUMMARIES"

  # Section 6: Phase Roadmap Section (DYNAMIC)
  SEC_ROADMAP="## Phase Roadmap

$ROADMAP_SECTION"

  # Section 7: State Context + Instructions (DYNAMIC)
  SEC_STATE="## State Context

- **Current State**: planning
- **Milestone**: $MILESTONE_ID
- **Phase**: $PHASE_ID
- **Tier**: $TIER"

  SEC_INSTRUCTIONS="## Instructions

Plan phase $PHASE_ID for milestone $MILESTONE_ID following the speckit.orchestrator.plan-phase command.
Produce a phase plan (${PHASE_ID}-PLAN.md) with goal, demo, must-haves, and task breakdown.
Each task plan should be self-contained with zero-context assumptions."

  # --- Build the frontmatter ---
  FRONTMATTER="---
schema_version: \"1.0\"
type: planning-prompt
---"

  # --- Assemble sections array (name|content|priority) ---
  SECTION_NAMES="Knowledge|Decisions|Context Draft|Feature Spec|Upstream Context|Phase Roadmap|State Context|Instructions"
  SECTION_PRIORITIES="filtered|filtered|optional|optional|required|required|required|required"

  # Write sections to temp files for line counting
  echo "$SEC_KNOWLEDGE" > "$TMPDIR_BUILD/s1.txt"
  echo "$SEC_DECISIONS" > "$TMPDIR_BUILD/s2.txt"
  echo "$SEC_CONTEXT" > "$TMPDIR_BUILD/s3.txt"
  echo "$SEC_FEATURE" > "$TMPDIR_BUILD/s4.txt"
  echo "$SEC_UPSTREAM" > "$TMPDIR_BUILD/s5.txt"
  echo "$SEC_ROADMAP" > "$TMPDIR_BUILD/s6.txt"
  echo "$SEC_STATE" > "$TMPDIR_BUILD/s7.txt"
  echo "$SEC_INSTRUCTIONS" > "$TMPDIR_BUILD/s8.txt"

  SECTION_COUNT=8

else
# ============================================================================
# Normal task dispatch mode
# ============================================================================

  # --- Read task plan content ---
  TASK_PLAN_CONTENT=$(cat "$TASK_PLAN")

  # --- Read phase plan excerpt (goal, demo, must-haves) ---
  PHASE_EXCERPT=""
  if [[ -f "$PHASE_PLAN" ]]; then
    goal_line=$(grep -E '^## Goal' "$PHASE_PLAN" -A 2 | tail -n +2 | head -2 || true)
    demo_line=$(grep -E '^## Demo' "$PHASE_PLAN" -A 2 | tail -n +2 | head -2 || true)
    must_haves=$(sed -n '/^## Must-Haves/,/^## [^M]/p' "$PHASE_PLAN" | head -20 || true)

    PHASE_EXCERPT="### Goal
$goal_line

### Demo
$demo_line

### Must-Haves
$must_haves"
  fi

  # --- Derive current state ---
  CURRENT_STATE="executing"

  # --- Read verification criteria from phase plan ---
  VERIFICATION_CRITERIA=""
  verification_cmds=$(config_read "verification_commands" "")
  if [[ -n "$verification_cmds" && "$verification_cmds" != "null" ]]; then
    VERIFICATION_CRITERIA="$verification_cmds"
  else
    VERIFICATION_CRITERIA="See phase plan must-haves"
  fi

  # --- Build sections in cache-friendly order (static first) ---

  # Section 1: Knowledge (STATIC — project-level entries)
  SEC_KNOWLEDGE="## Knowledge

$KNOWLEDGE_ENTRIES"

  # Section 2: Decisions (STATIC)
  SEC_DECISIONS="## Decisions

$DECISION_ENTRIES"

  # Section 3: Phase Goal & Must-Haves (SEMI-STATIC)
  SEC_SCOPE="## Scope

$PHASE_EXCERPT"

  # Section 4: Upstream Summaries (DYNAMIC)
  SEC_UPSTREAM="## Upstream Context

$UPSTREAM_SUMMARIES"

  # Section 5: Task Plan (DYNAMIC)
  SEC_TASK="## Task Plan

$TASK_PLAN_CONTENT"

  # Section 6: State + Constraints (DYNAMIC)
  SEC_STATE="## State Context

- **Current State**: $CURRENT_STATE
- **Milestone**: $MILESTONE_ID
- **Phase**: $PHASE_ID
- **Task**: $TASK_ID
- **Tier**: $TIER"

  SEC_CONSTRAINTS="## Constraints

- **Verification Criteria**: $VERIFICATION_CRITERIA
- **Duration Budget**: $DURATION_BUDGET
- **Dispatch Budget**: $DISPATCH_BUDGET
- **Budget Enforcement**: $BUDGET_ENFORCEMENT"

  # --- Build the frontmatter ---
  FRONTMATTER="---
schema_version: \"1.0\"
type: dispatch-prompt
---"

  SECTION_NAMES="Knowledge|Decisions|Scope|Upstream Context|Task Plan|State Context|Constraints"
  SECTION_PRIORITIES="filtered|filtered|required|required|required|required|required"

  # Write sections to temp files for line counting
  echo "$SEC_KNOWLEDGE" > "$TMPDIR_BUILD/s1.txt"
  echo "$SEC_DECISIONS" > "$TMPDIR_BUILD/s2.txt"
  echo "$SEC_SCOPE" > "$TMPDIR_BUILD/s3.txt"
  echo "$SEC_UPSTREAM" > "$TMPDIR_BUILD/s4.txt"
  echo "$SEC_TASK" > "$TMPDIR_BUILD/s5.txt"
  echo "$SEC_STATE" > "$TMPDIR_BUILD/s6.txt"
  echo "$SEC_CONSTRAINTS" > "$TMPDIR_BUILD/s7.txt"

  SECTION_COUNT=7

fi  # end IS_PLANNING branch

# ============================================================================
# Build manifest and final payload
# ============================================================================

# Count lines in frontmatter
FM_LINES=$(echo "$FRONTMATTER" | wc -l | tr -d ' ')

# Build the title line
if [[ "$IS_PLANNING" = "true" ]]; then
  TITLE="# Dispatch Context -- PHASE_PLAN (Phase $PHASE_ID, Milestone $MILESTONE_ID)"
else
  TITLE="# Dispatch Context -- $TASK_ID (Phase $PHASE_ID, Milestone $MILESTONE_ID)"
fi

# We need to calculate the manifest size first (chicken-and-egg problem).
# Strategy: build manifest with placeholder line numbers, count manifest lines,
# then rebuild with correct offsets.

# Count lines in each section
section_line_counts=""
section_token_counts=""
IFS='|' read -ra S_NAMES <<< "$SECTION_NAMES"
IFS='|' read -ra S_PRIORITIES <<< "$SECTION_PRIORITIES"

total_tokens=0
for i in $(seq 1 "$SECTION_COUNT"); do
  sec_file="$TMPDIR_BUILD/s${i}.txt"
  sec_lines=$(wc -l < "$sec_file" | tr -d ' ')
  sec_content=$(cat "$sec_file")
  sec_tokens=$(estimate_tokens "$sec_content")
  section_line_counts="$section_line_counts $sec_lines"
  section_token_counts="$section_token_counts $sec_tokens"
  total_tokens=$((total_tokens + sec_tokens))
done

# Calculate manifest table lines: header(1) + title(1) + blank(1) + "## Manifest"(1) + table_header(3) + data_rows(N) + total_row(1) + blank(1)
# = 9 + SECTION_COUNT
MANIFEST_HEADER_LINES=$((9 + SECTION_COUNT))

# Frontmatter lines + blank line after frontmatter
OFFSET=$((FM_LINES + 1))
# Add title + blank + "## Manifest" + blank + table header (3 lines: header, separator, blank implied)
# Actually: title(1) + blank(1) + "## Manifest"(1) + table_header_row(1) + separator_row(1) = 5
# Then data rows (SECTION_COUNT) + total row(1) + blank(1) = SECTION_COUNT + 2
MANIFEST_LINES=$((5 + SECTION_COUNT + 2))
CONTENT_START=$((OFFSET + MANIFEST_LINES))

# Build manifest table
MANIFEST_TABLE="| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|"

current_line=$CONTENT_START
idx=0
for i in $(seq 1 "$SECTION_COUNT"); do
  sec_lc=$(echo "$section_line_counts" | awk -v n="$i" '{print $n}')
  sec_tc=$(echo "$section_token_counts" | awk -v n="$i" '{print $n}')
  sec_name="${S_NAMES[$idx]}"
  sec_pri="${S_PRIORITIES[$idx]}"

  # Add knowledge entry count to name if applicable
  if [[ "$sec_name" = "Knowledge" && -s "$INCLUDED_IDS_FILE" ]]; then
    entry_ct=$(grep -c 'MEM' "$INCLUDED_IDS_FILE" || echo "0")
    sec_name="Knowledge ($entry_ct entries)"
  fi

  end_line=$((current_line + sec_lc - 1))
  MANIFEST_TABLE="$MANIFEST_TABLE
| $sec_name | ${current_line}-${end_line} | ~${sec_tc} | $sec_pri |"
  current_line=$((end_line + 2))  # +1 for blank line between sections
  idx=$((idx + 1))
done

MANIFEST_TABLE="$MANIFEST_TABLE
| **Total** | | **~${total_tokens}** | |"

# --- Assemble final payload ---
PAYLOAD="$FRONTMATTER

$TITLE
## Manifest
$MANIFEST_TABLE
"

# Append all sections with blank line separators
for i in $(seq 1 "$SECTION_COUNT"); do
  sec_file="$TMPDIR_BUILD/s${i}.txt"
  PAYLOAD="$PAYLOAD
$(cat "$sec_file")
"
done

# --- Output payload ---
echo "$PAYLOAD"

# --- Increment hit counts for included knowledge entries ---
if [[ -s "$INCLUDED_IDS_FILE" ]]; then
  while IFS= read -r eid; do
    [[ -z "$eid" ]] && continue
    bash "$INCREMENT_HITS" --id "$eid" 2>/dev/null || true
  done < "$INCLUDED_IDS_FILE"
fi
rm -f "$INCLUDED_IDS_FILE"

# --- Report context budget to stderr ---
PAYLOAD_BYTES=$(echo "$PAYLOAD" | wc -c | tr -d ' ')

# Calculate total artifact bytes (all files under milestone dir)
TOTAL_BYTES=0
_tmp_filelist="$(mktemp)"
find "$MILESTONE_DIR" -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" \) 2>/dev/null > "$_tmp_filelist"
while IFS= read -r f; do
  if [[ -f "$f" ]]; then
    file_size=$(wc -c < "$f" | tr -d ' ')
    TOTAL_BYTES=$((TOTAL_BYTES + file_size))
  fi
done < "$_tmp_filelist"
rm -f "$_tmp_filelist"

if [[ "$TOTAL_BYTES" -gt 0 ]]; then
  BUDGET_PCT=$((PAYLOAD_BYTES * 100 / TOTAL_BYTES))
else
  BUDGET_PCT=0
fi

echo "Context payload: $PAYLOAD_BYTES bytes (${BUDGET_PCT}% of total artifacts)" >&2
