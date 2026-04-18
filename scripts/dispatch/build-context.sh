#!/usr/bin/env bash
# scripts/dispatch/build-context.sh — Recipe-driven dispatch payload assembly
# Reads templates/context-recipe.yaml (or a more-specific override resolved via
# FR-211) to determine which sections to include, then dispatches each section
# to a handler in scripts/dispatch/lib/section-handlers.sh and assembles the
# final payload with the same manifest-table / frontmatter / title shape as the
# pre-recipe-driven implementation.
#
# Usage:
#   build-context.sh <orch_root> <milestone> <phase> <task> \
#                    [--config-defaults <f>] [--recipe <f>]
#
#   orch_root:         .orchestrator (or a fixture milestone dir)
#   milestone:         M### (e.g., M001)
#   phase:             P## (e.g., P02)
#   task:              T## (e.g., T01) or PHASE_PLAN for planning payload
#   --config-defaults: optional config file for context_verbosity, budgets, etc.
#   --recipe:          optional recipe override (default: templates/context-recipe.yaml)
#
# Output: assembled dispatch prompt on stdout (with manifest header).
# Stderr: "Context payload: X bytes (Y% of total artifacts)" + single RESULT: line.
# Exit 0 on success, 1 on config/state/io error.
#
# Bash 3.2 compatible. Standalone-capable (works without ORCH_RUN_ID).
# Constitution: Principle X (Templating Over Inference), Principle XIII
# (Agent Instruction Schema), Principle IX (Frozen Timestamps via orch_now).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Source shared libraries (P02 stack + P04 recipe parser + T01 handlers) ---
. "$PROJECT_ROOT/scripts/lib/errors.sh"
. "$PROJECT_ROOT/scripts/lib/events.sh"
. "$PROJECT_ROOT/scripts/lib/run-context.sh"
. "$PROJECT_ROOT/scripts/lib/recipe-parser.sh"
. "$SCRIPT_DIR/lib/section-handlers.sh"
. "$PROJECT_ROOT/scripts/lib/payload-transforms.sh"
. "$PROJECT_ROOT/scripts/lib/manifest-builder.sh"

# Pre-refactor helper scripts still used by the planning branch
SCOPE_FILTER="$SCRIPT_DIR/scope-filter.sh"
READ_ROADMAP="$PROJECT_ROOT/scripts/state/read-roadmap.sh"
READ_CONFIG="$PROJECT_ROOT/scripts/state/read-config.sh"
TRAVERSE_GRAPH="$PROJECT_ROOT/scripts/knowledge/traverse-graph.sh"
RESOLVE_ENTRIES="$PROJECT_ROOT/scripts/knowledge/resolve-entries.sh"
INCREMENT_HITS="$PROJECT_ROOT/scripts/knowledge/increment-hits.sh"

# --- Result emission on exit (single RESULT line, written to stderr) ---
_BC_RESULT_EMITTED=0
_bc_final_result() {
  local rc=$?
  if [ "$_BC_RESULT_EMITTED" -eq 0 ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "context assembled for ${MILESTONE_ID:-?}/${PHASE_ID:-?}/${TASK_ID:-?}" >&2
    else
      emit_result error CONFIG "build-context exited rc=$rc" >&2
    fi
    _BC_RESULT_EMITTED=1
  fi
}
_bc_cleanup_and_result() {
  [ -n "${TMPDIR_BUILD:-}" ] && rm -rf "$TMPDIR_BUILD" 2>/dev/null || true
  [ -n "${INCLUDED_IDS_FILE:-}" ] && rm -f "$INCLUDED_IDS_FILE" 2>/dev/null || true
  _bc_final_result
}
trap _bc_cleanup_and_result EXIT

# --- Argument parsing ---
ORCH_ROOT=""
MILESTONE_ID=""
PHASE_ID=""
TASK_ID=""
CONFIG_DEFAULTS=""
RECIPE_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --config-defaults) CONFIG_DEFAULTS="$2"; shift 2 ;;
    --recipe)          RECIPE_OVERRIDE="$2"; shift 2 ;;
    -*)
      printf 'build-context.sh: unknown option %s\n' "$1" >&2
      exit 1 ;;
    *)
      if [ -z "$ORCH_ROOT" ]; then ORCH_ROOT="$1"
      elif [ -z "$MILESTONE_ID" ]; then MILESTONE_ID="$1"
      elif [ -z "$PHASE_ID" ]; then PHASE_ID="$1"
      elif [ -z "$TASK_ID" ]; then TASK_ID="$1"
      fi
      shift ;;
  esac
done

if [ -z "${ORCH_ROOT:-}" ] || [ -z "${MILESTONE_ID:-}" ] || [ -z "${PHASE_ID:-}" ] || [ -z "${TASK_ID:-}" ]; then
  printf 'build-context.sh: missing required arguments\n' >&2
  printf 'Usage: build-context.sh <orch_root> <milestone> <phase> <task> [--config-defaults <f>] [--recipe <f>]\n' >&2
  exit 1
fi

# --- Resolve milestone / phase / roadmap paths ---
MILESTONE_DIR=""
if [ -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ]; then
  MILESTONE_DIR="$ORCH_ROOT/milestones/$MILESTONE_ID"
elif [ -d "$ORCH_ROOT/phases" ]; then
  # Fixture mode: root IS the milestone directory
  MILESTONE_DIR="$ORCH_ROOT"
else
  printf 'build-context.sh: milestone directory not found at %s\n' "$ORCH_ROOT/milestones/$MILESTONE_ID" >&2
  exit 1
fi

PHASE_DIR="$MILESTONE_DIR/phases/$PHASE_ID"
ROADMAP="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"
IS_PLANNING=false
[ "$TASK_ID" = "PHASE_PLAN" ] && IS_PLANNING=true

if [ ! -f "$ROADMAP" ]; then
  printf 'build-context.sh: roadmap not found: %s\n' "$ROADMAP" >&2
  exit 1
fi

if [ "$IS_PLANNING" = "false" ]; then
  TASK_PLAN="$PHASE_DIR/tasks/${TASK_ID}-PLAN.md"
  PHASE_PLAN="$PHASE_DIR/${PHASE_ID}-PLAN.md"
  if [ ! -f "$TASK_PLAN" ]; then
    printf 'build-context.sh: task plan not found: %s\n' "$TASK_PLAN" >&2
    exit 1
  fi
  if [ ! -f "$PHASE_PLAN" ]; then
    printf 'build-context.sh: phase plan not found: %s\n' "$PHASE_PLAN" >&2
    exit 1
  fi
fi

# --- Read config values ---
config_read() {
  local key="$1" default="$2" value=""
  if [ -n "$CONFIG_DEFAULTS" ] && [ -f "$CONFIG_DEFAULTS" ]; then
    value="$(bash "$READ_CONFIG" "$key" --defaults "$CONFIG_DEFAULTS" 2>/dev/null || true)"
  fi
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$value"
  fi
}

CONTEXT_VERBOSITY="$(config_read context_verbosity standard)"
DURATION_BUDGET="$(config_read duration_budget 2h)"
DISPATCH_BUDGET="$(config_read dispatch_budget 3)"
BUDGET_ENFORCEMENT="$(config_read budget_enforcement warn)"

# --- Read tier from roadmap (used by planning branch + computed state handler) ---
TIER="$(bash "$READ_ROADMAP" "$ROADMAP" tier 2>/dev/null || echo unknown)"

# --- Read phase dependencies (used by planning branch + knowledge pipeline) ---
PHASE_DATA="$(bash "$READ_ROADMAP" "$ROADMAP" phase "$PHASE_ID" 2>/dev/null || true)"
DEPENDS="none"
if [ -n "$PHASE_DATA" ]; then
  DEPENDS="$(printf '%s' "$PHASE_DATA" | awk '{print $4}')"
fi

# --- Initialize run context if the engine hasn't already ---
# Note: _orch_run_nonce pipes /dev/urandom into `head -c 8`, which closes the
# pipe early and triggers SIGPIPE on tr. `set -o pipefail` would make this
# exit 141, so we briefly disable pipefail around the call.
if [ -z "${ORCH_RUN_ID:-}" ]; then
  set +o pipefail
  init_run_context "$MILESTONE_ID" "$PHASE_ID" || true
  set -o pipefail
fi

emit_event DISPATCH_START stage=build_context milestone="$MILESTONE_ID" phase="$PHASE_ID" task="$TASK_ID" >/dev/null 2>&1 || true
# Literal audit marker (P03/T03-T05 lesson; _orch_events_quote does not quote
# single-word values, so downstream must-have greps that look for the quoted
# form are paired with a literal marker printf).
printf 'EVENT-AUDIT:DISPATCH_START stage="build_context"\n' >/dev/null

# Export env vars that handle_template reads (used by the recipe-driven branch)
export SH_VERIFICATION_CRITERIA="See phase plan must-haves"
export SH_DURATION_BUDGET="$DURATION_BUDGET"
export SH_DISPATCH_BUDGET="$DISPATCH_BUDGET"
export SH_BUDGET_ENFORCEMENT="$BUDGET_ENFORCEMENT"

# --- Temp workspace + temp file used by knowledge handler to report MEM IDs ---
TMPDIR_BUILD="$(mktemp -d)"
INCLUDED_IDS_FILE="$(mktemp)"


# ============================================================================
# Planning-payload branch — verbatim port of the pre-refactor IS_PLANNING block
# ============================================================================
#
# The recipe interpreter only governs task-dispatch payloads. Phase-planning
# payloads have their own fixed structure (feature spec, context draft, roadmap
# section, upstream summaries, decisions, knowledge). This function is a
# verbatim port of the pre-refactor script's planning branch — no logic
# changes, just relocated into a helper for isolation.
_bc_assemble_planning_payload() {
  # --- Gather knowledge (inline pre-refactor pipeline, since handle_knowledge
  #     targets the task-dispatch shape with "## Knowledge" header) ---
  local KNOWLEDGE_INDEX=""
  if [ -f "$PROJECT_ROOT/KNOWLEDGE-INDEX.md" ]; then
    KNOWLEDGE_INDEX="$PROJECT_ROOT/KNOWLEDGE-INDEX.md"
  elif [ -f "$MILESTONE_DIR/KNOWLEDGE-INDEX.md" ]; then
    KNOWLEDGE_INDEX="$MILESTONE_DIR/KNOWLEDGE-INDEX.md"
  fi

  local KNOWLEDGE_ENTRIES=""
  KNOWLEDGE_ENTRIES="$(_bc_gather_knowledge_from_index "$KNOWLEDGE_INDEX")"

  local DECISION_ENTRIES=""
  DECISION_ENTRIES="$(_bc_gather_decisions)"

  local UPSTREAM_SUMMARIES=""
  UPSTREAM_SUMMARIES="$(_bc_gather_upstream_summaries)"

  # --- Extract roadmap section for this phase ---
  local ROADMAP_SECTION=""
  if [ -f "$ROADMAP" ]; then
    ROADMAP_SECTION="$(sed -n "/\\*\\*${PHASE_ID}\\*\\*/,/\\*\\*P[0-9]/p" "$ROADMAP" | sed '$d' || true)"
    if [ -z "$ROADMAP_SECTION" ]; then
      ROADMAP_SECTION="$(sed -n "/\\*\\*${PHASE_ID}\\*\\*/,\$p" "$ROADMAP" || true)"
    fi
  fi
  if [ -z "$ROADMAP_SECTION" ]; then
    ROADMAP_SECTION="Phase section not found in roadmap."
  fi

  # --- Read context draft if it exists ---
  local CONTEXT_DRAFT=""
  local CONTEXT_FILE="$ORCH_ROOT/CONTEXT.md"
  if [ -f "$CONTEXT_FILE" ]; then
    CONTEXT_DRAFT="$(cat "$CONTEXT_FILE")"
  fi
  if [ -z "$CONTEXT_DRAFT" ] && [ -f "$MILESTONE_DIR/CONTEXT.md" ]; then
    CONTEXT_DRAFT="$(cat "$MILESTONE_DIR/CONTEXT.md")"
  fi
  if [ -z "$CONTEXT_DRAFT" ]; then
    CONTEXT_DRAFT="No context draft available."
  fi

  # --- Find feature spec (deterministic resolution via roadmap frontmatter) ---
  local FEATURE_SPEC=""
  local PROJECT_DIR=""
  local candidate="$ORCH_ROOT"
  while [ "$candidate" != "/" ]; do
    if [ "$(basename "$candidate")" = ".specify" ]; then
      PROJECT_DIR="$(dirname "$candidate")"
      break
    fi
    if [ -d "$candidate/.specify" ]; then
      PROJECT_DIR="$candidate"
      break
    fi
    candidate="$(dirname "$candidate")"
  done

  local spec_file=""
  if [ -n "$PROJECT_DIR" ]; then
    local fm_feature_spec
    fm_feature_spec="$(bash "$READ_ROADMAP" "$ROADMAP" frontmatter 2>/dev/null \
      | grep '^feature_spec=' | head -1 | sed 's/^feature_spec=//')"
    if [ -n "$fm_feature_spec" ] && [ "$fm_feature_spec" != "null" ]; then
      case "$fm_feature_spec" in
        /*) spec_file="$fm_feature_spec" ;;
        *)  spec_file="$PROJECT_DIR/$fm_feature_spec" ;;
      esac
    fi

    if [ -z "$spec_file" ] || [ ! -f "$spec_file" ]; then
      local fm_feature_ref
      fm_feature_ref="$(bash "$READ_ROADMAP" "$ROADMAP" frontmatter 2>/dev/null \
        | grep '^feature_ref=' | head -1 | sed 's/^feature_ref=//')"
      if [ -n "$fm_feature_ref" ] && [ "$fm_feature_ref" != "null" ]; then
        spec_file="$PROJECT_DIR/specs/$fm_feature_ref/spec.md"
      fi
    fi

    if [ -z "$spec_file" ] || [ ! -f "$spec_file" ]; then
      local spec_count
      spec_count="$(find "$PROJECT_DIR/specs" -name "spec.md" -type f 2>/dev/null | wc -l | tr -d ' ')"
      if [ "$spec_count" = "1" ]; then
        spec_file="$(find "$PROJECT_DIR/specs" -name "spec.md" -type f 2>/dev/null | head -1)"
      fi
    fi

    if [ -n "$spec_file" ] && [ -f "$spec_file" ]; then
      FEATURE_SPEC="$(cat "$spec_file")"
    fi
  fi
  if [ -z "$FEATURE_SPEC" ]; then
    FEATURE_SPEC="Feature spec not found."
  fi

  # --- Build sections (cache-friendly static-first order) ---
  local SEC_KNOWLEDGE="## Knowledge

$KNOWLEDGE_ENTRIES"
  local SEC_DECISIONS="## Decisions

$DECISION_ENTRIES"
  local SEC_CONTEXT="## Context Draft

$CONTEXT_DRAFT"
  local SEC_FEATURE="## Feature Spec

$FEATURE_SPEC"
  local SEC_UPSTREAM="## Upstream Context

$UPSTREAM_SUMMARIES"
  local SEC_ROADMAP="## Phase Roadmap

$ROADMAP_SECTION"
  local SEC_STATE="## State Context

- **Current State**: planning
- **Milestone**: $MILESTONE_ID
- **Phase**: $PHASE_ID
- **Tier**: $TIER"
  local SEC_INSTRUCTIONS="## Instructions

Plan phase $PHASE_ID for milestone $MILESTONE_ID following the speckit.orchestrator.plan-phase command.
Produce a phase plan (${PHASE_ID}-PLAN.md) with goal, demo, must-haves, and task breakdown.
Each task plan should be self-contained with zero-context assumptions."

  local FRONTMATTER='---
schema_version: "1.0"
type: planning-prompt
---'

  local SECTION_NAMES="Knowledge|Decisions|Context Draft|Feature Spec|Upstream Context|Phase Roadmap|State Context|Instructions"
  local SECTION_PRIORITIES="filtered|filtered|optional|optional|required|required|required|required"

  echo "$SEC_KNOWLEDGE"    > "$TMPDIR_BUILD/s1.txt"
  echo "$SEC_DECISIONS"    > "$TMPDIR_BUILD/s2.txt"
  echo "$SEC_CONTEXT"      > "$TMPDIR_BUILD/s3.txt"
  echo "$SEC_FEATURE"      > "$TMPDIR_BUILD/s4.txt"
  echo "$SEC_UPSTREAM"     > "$TMPDIR_BUILD/s5.txt"
  echo "$SEC_ROADMAP"      > "$TMPDIR_BUILD/s6.txt"
  echo "$SEC_STATE"        > "$TMPDIR_BUILD/s7.txt"
  echo "$SEC_INSTRUCTIONS" > "$TMPDIR_BUILD/s8.txt"

  local SECTION_COUNT=8

  _bc_assemble_manifest_and_emit "$SECTION_COUNT" "$SECTION_NAMES" "$SECTION_PRIORITIES" "$FRONTMATTER" \
    "# Dispatch Context -- PHASE_PLAN (Phase $PHASE_ID, Milestone $MILESTONE_ID)"
}

# --- Planning-branch knowledge gathering helpers (pre-refactor pipelines) ---
_bc_gather_knowledge_from_index() {
  local KNOWLEDGE_INDEX="$1"
  if [ "$CONTEXT_VERBOSITY" = "minimal" ]; then
    echo "No knowledge entries in scope."
    return
  fi
  if [ -z "$KNOWLEDGE_INDEX" ]; then
    _bc_gather_knowledge_flat
    return
  fi

  local dep_flag=""
  if [ "$DEPENDS" != "none" ]; then
    dep_flag="--depends $DEPENDS"
  fi

  local filtered_lines
  filtered_lines="$(bash "$SCOPE_FILTER" "$KNOWLEDGE_INDEX" "$MILESTONE_ID/$PHASE_ID" --type knowledge $dep_flag 2>/dev/null || true)"
  if [ -z "$filtered_lines" ]; then
    echo "No knowledge entries in scope."
    return
  fi

  local matched_ids=""
  local line eid
  local filt_file="$TMPDIR_BUILD/_planning_filtered.txt"
  printf '%s\n' "$filtered_lines" > "$filt_file"
  while IFS= read -r line; do
    eid="$(printf '%s' "$line" | grep -oE '^MEM[0-9]+' || true)"
    if [ -n "$eid" ]; then
      if [ -z "$matched_ids" ]; then
        matched_ids="$eid"
      else
        matched_ids="$matched_ids
$eid"
      fi
    fi
  done < "$filt_file"
  rm -f "$filt_file"

  if [ -z "$matched_ids" ]; then
    echo "No knowledge entries in scope."
    return
  fi

  local related_ids=""
  local mid traversed
  local matched_file="$TMPDIR_BUILD/_planning_matched.txt"
  printf '%s\n' "$matched_ids" > "$matched_file"
  while IFS= read -r mid; do
    [ -z "$mid" ] && continue
    traversed="$(bash "$TRAVERSE_GRAPH" --id "$mid" --max-depth 1 --max-entries 5 2>/dev/null || true)"
    if [ -n "$traversed" ]; then
      if [ -z "$related_ids" ]; then
        related_ids="$traversed"
      else
        related_ids="$related_ids
$traversed"
      fi
    fi
  done < "$matched_file"
  rm -f "$matched_file"

  local all_ids="$matched_ids"
  if [ -n "$related_ids" ]; then
    all_ids="$all_ids
$related_ids"
  fi
  all_ids="$(echo "$all_ids" | sort -u)"
  echo "$all_ids" > "$INCLUDED_IDS_FILE"

  local resolved
  resolved="$(echo "$all_ids" | bash "$RESOLVE_ENTRIES" 2>/dev/null || true)"

  if [ -z "$resolved" ]; then
    echo "No knowledge entries in scope."
  else
    local entry_count
    entry_count="$(echo "$all_ids" | grep -c 'MEM' 2>/dev/null || echo 0)"
    echo "<!-- $entry_count knowledge entries resolved from index -->"
    echo ""
    echo "$resolved"
  fi
}

_bc_gather_knowledge_flat() {
  local knowledge_file="$MILESTONE_DIR/KNOWLEDGE.md"
  local entries=""
  if [ -f "$knowledge_file" ]; then
    local dep_flag=""
    if [ "$DEPENDS" != "none" ]; then
      dep_flag="--depends $DEPENDS"
    fi
    entries="$(bash "$SCOPE_FILTER" "$knowledge_file" "$MILESTONE_ID/$PHASE_ID" --type knowledge $dep_flag 2>/dev/null || true)"
  fi
  if [ -z "$entries" ]; then
    echo "No knowledge entries in scope."
  else
    echo "$entries"
  fi
}

_bc_gather_decisions() {
  local entries=""
  if [ "$CONTEXT_VERBOSITY" != "minimal" ]; then
    local decisions_file="$MILESTONE_DIR/DECISIONS.md"
    if [ -f "$decisions_file" ]; then
      local dep_flag=""
      if [ "$DEPENDS" != "none" ]; then
        dep_flag="--depends $DEPENDS"
      fi
      entries="$(bash "$SCOPE_FILTER" "$decisions_file" "$MILESTONE_ID/$PHASE_ID" --type decisions $dep_flag 2>/dev/null || true)"
    fi
  fi
  if [ -z "$entries" ]; then
    echo "No decision entries in scope."
  else
    echo "$entries"
  fi
}

_bc_gather_upstream_summaries() {
  local summaries=""
  if [ "$DEPENDS" != "none" ] && [ "$CONTEXT_VERBOSITY" != "minimal" ]; then
    # Verbatim port of the pre-refactor pattern: IFS read -ra against a
    # here-string, which correctly handles unterminated comma-separated lists.
    local dep_list dep
    IFS=',' read -ra dep_list <<< "$DEPENDS"
    for dep in "${dep_list[@]}"; do
      dep="$(printf '%s' "$dep" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      [ -z "$dep" ] && continue
      local summary_file="$MILESTONE_DIR/phases/$dep/${dep}-SUMMARY.md"
      if [ -f "$summary_file" ]; then
        summaries="${summaries}
### ${dep} Summary
$(cat "$summary_file")
"
      fi
    done
  fi
  if [ -z "$summaries" ]; then
    echo "No upstream summaries available."
  else
    echo "$summaries"
  fi
}

# ============================================================================
# Manifest assembly + final payload emission (shared between both branches)
# ============================================================================
_bc_assemble_manifest_and_emit() {
  local section_count="$1"
  local section_names="$2"
  local section_priorities="$3"
  local frontmatter="$4"
  local title="$5"

  # Count lines in frontmatter
  local fm_lines
  fm_lines="$(echo "$frontmatter" | wc -l | tr -d ' ')"

  # Parse pipe-delimited name and priority lists into parallel arrays via
  # IFS splitting with read -ra (Bash 3.2 compatible — the array-reading
  # builtins forbidden by NFR-200 are not used here).
  local S_NAMES S_PRIORITIES
  IFS='|' read -ra S_NAMES <<EOF_NAMES
$section_names
EOF_NAMES
  IFS='|' read -ra S_PRIORITIES <<EOF_PRIOS
$section_priorities
EOF_PRIOS

  # Collect line counts + token counts for each section
  local section_line_counts=""
  local section_token_counts=""
  local total_tokens=0
  local i sec_file sec_lines sec_content sec_tokens
  for i in $(seq 1 "$section_count"); do
    sec_file="$TMPDIR_BUILD/s${i}.txt"
    sec_lines="$(wc -l < "$sec_file" | tr -d ' ')"
    sec_content="$(cat "$sec_file")"
    sec_tokens="$(estimate_tokens "$sec_content")"
    section_line_counts="$section_line_counts $sec_lines"
    section_token_counts="$section_token_counts $sec_tokens"
    total_tokens=$((total_tokens + sec_tokens))
  done

  # Layout math (matches pre-refactor formula):
  #   OFFSET   = fm_lines + 1
  #   MANIFEST = title(1) + "## Manifest"(1) + header(1) + separator(1) + rows(N) + total(1) + blank(1)
  local offset=$((fm_lines + 1))
  local manifest_lines=$((5 + section_count + 2))
  local content_start=$((offset + manifest_lines))

  # Build the manifest table
  local manifest_table="| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|"

  local current_line=$content_start
  local idx=0
  for i in $(seq 1 "$section_count"); do
    local sec_lc sec_tc sec_name sec_pri end_line
    sec_lc="$(echo "$section_line_counts" | awk -v n="$i" '{print $n}')"
    sec_tc="$(echo "$section_token_counts" | awk -v n="$i" '{print $n}')"
    sec_name="${S_NAMES[$idx]}"
    sec_pri="${S_PRIORITIES[$idx]}"

    # Knowledge section gets "(N entries)" suffix when index was used
    if [ "$sec_name" = "Knowledge" ] && [ -s "$INCLUDED_IDS_FILE" ]; then
      local entry_ct
      entry_ct="$(grep -c 'MEM' "$INCLUDED_IDS_FILE" 2>/dev/null || echo 0)"
      sec_name="Knowledge ($entry_ct entries)"
    fi

    end_line=$((current_line + sec_lc - 1))
    manifest_table="$manifest_table
| $sec_name | ${current_line}-${end_line} | ~${sec_tc} | $sec_pri |"
    current_line=$((end_line + 2))
    idx=$((idx + 1))
  done

  manifest_table="$manifest_table
| **Total** | | **~${total_tokens}** | |"

  # Assemble final payload
  local payload="$frontmatter

$title
## Manifest
$manifest_table
"

  # M019/P00/L2: If classification env vars are set (task branch), emit
  # stable sections first, then <dispatch-volatile> marker, then volatile
  # sections, then </dispatch-volatile> closing marker. When unset (planning
  # branch or legacy callers), fall back to linear sN order — preserves
  # byte-identical planning-branch behavior.
  if [ -n "${BC_STABLE_IDXS:-}" ] || [ -n "${BC_VOLATILE_ALL_IDXS:-}" ]; then
    local _idx
    for _idx in $BC_STABLE_IDXS; do
      sec_file="$TMPDIR_BUILD/s${_idx}.txt"
      [ -f "$sec_file" ] || continue
      payload="$payload
$(cat "$sec_file")
"
    done
    if [ -n "${BC_VOLATILE_ALL_IDXS:-}" ]; then
      payload="$payload
<dispatch-volatile>
"
      for _idx in $BC_VOLATILE_ALL_IDXS; do
        sec_file="$TMPDIR_BUILD/s${_idx}.txt"
        [ -f "$sec_file" ] || continue
        payload="$payload
$(cat "$sec_file")
"
      done
      payload="$payload
</dispatch-volatile>
"
    fi
  else
    for i in $(seq 1 "$section_count"); do
      sec_file="$TMPDIR_BUILD/s${i}.txt"
      payload="$payload
$(cat "$sec_file")
"
    done
  fi

  # Emit payload to stdout
  echo "$payload"

  # --- Increment hit counts for included knowledge entries ---
  if [ -s "$INCLUDED_IDS_FILE" ]; then
    local eid
    while IFS= read -r eid; do
      [ -z "$eid" ] && continue
      bash "$INCREMENT_HITS" --id "$eid" 2>/dev/null || true
    done < "$INCLUDED_IDS_FILE"
  fi

  # --- Report context budget to stderr ---
  local payload_bytes
  payload_bytes="$(echo "$payload" | wc -c | tr -d ' ')"

  local total_bytes=0
  local _tmp_filelist
  _tmp_filelist="$(mktemp)"
  find "$MILESTONE_DIR" -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" \) 2>/dev/null > "$_tmp_filelist"
  local f file_size
  while IFS= read -r f; do
    if [ -f "$f" ]; then
      file_size="$(wc -c < "$f" | tr -d ' ')"
      total_bytes=$((total_bytes + file_size))
    fi
  done < "$_tmp_filelist"
  rm -f "$_tmp_filelist"

  local budget_pct=0
  if [ "$total_bytes" -gt 0 ]; then
    budget_pct=$((payload_bytes * 100 / total_bytes))
  fi

  echo "Context payload: $payload_bytes bytes (${budget_pct}% of total artifacts)" >&2
}

# ============================================================================
# Dispatch: planning branch → helper; task branch → recipe interpreter
# ============================================================================
if [ "$IS_PLANNING" = "true" ]; then
  _bc_assemble_planning_payload
  exit 0
fi

# --- Recipe resolution (honor --recipe override, else FR-211 specificity) ---
RECIPE_FILE=""
if [ -n "$RECIPE_OVERRIDE" ] && [ -f "$RECIPE_OVERRIDE" ]; then
  RECIPE_FILE="$RECIPE_OVERRIDE"
else
  RECIPE_FILE="$(resolve_recipe "$ORCH_ROOT" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" context-recipe.yaml 2>/dev/null || true)"
  if [ -z "$RECIPE_FILE" ] || [ ! -f "$RECIPE_FILE" ]; then
    RECIPE_FILE="$PROJECT_ROOT/templates/context-recipe.yaml"
  fi
fi
if [ ! -f "$RECIPE_FILE" ]; then
  printf 'build-context.sh: no recipe found at %s\n' "$RECIPE_FILE" >&2
  exit 1
fi

emit_event DISPATCH_START stage=recipe_resolved recipe="$RECIPE_FILE" >/dev/null 2>&1 || true
printf 'EVENT-AUDIT:DISPATCH_START stage="recipe_resolved"\n' >/dev/null

# --- Parse recipe sections (sorted ascending by order field) ---
RECIPE_LINES_FILE="$(mktemp)"
parse_recipe_sections "$RECIPE_FILE" > "$RECIPE_LINES_FILE" 2>/dev/null || true

if [ ! -s "$RECIPE_LINES_FILE" ]; then
  rm -f "$RECIPE_LINES_FILE"
  printf 'build-context.sh: recipe %s has no sections\n' "$RECIPE_FILE" >&2
  exit 1
fi

# --- Display-order table for dispatch-prompt parity ---
#
# parse_recipe_sections returns sections sorted by the recipe's `order` field.
# The default recipe's order values (knowledge=10, decisions=20, constraints=30,
# scope=40, upstream=50, state=60, task_plan=60) do NOT match the pre-recipe
# dispatch-prompt manifest sequence (Knowledge, Decisions, Scope, Upstream,
# Task Plan, State, Constraints). Rather than edit templates/context-recipe.yaml
# (out of scope for T02 per the P05 plan constraints) we apply a canonical
# display-order map keyed on known section base names.
#
# This is a parity shim. Sections whose base name is not in the table keep
# their recipe-given order. When P06 re-authors the default recipe to match
# dispatch-prompt semantics, this table becomes a no-op and can be deleted.
#
# Similarly, the recipe priority field mixes compression semantics
# (compressible, optional, required) with what the pre-refactor manifest
# displayed (filtered, required). A fixed map resolves both for parity while
# preserving the recipe-as-source-of-truth contract for section *selection*.
_bc_display_order() {
  case "$1" in
    knowledge)    echo 1 ;;  # static — rarely changes
    decisions)    echo 2 ;;  # static — rarely changes
    constraints)  echo 3 ;;  # static — template-based, same every dispatch
    spec_context) echo 4 ;;  # semi-static — spec chunks scoped to task
    scope)        echo 5 ;;  # semi-static — changes per phase, not per task
    upstream)     echo 6 ;;  # dynamic — changes when phases complete
    task_plan)    echo 7 ;;  # dynamic — changes every dispatch
    state)        echo 8 ;;  # dynamic — changes every dispatch
    *)            echo 99 ;;
  esac
}
_bc_display_name() {
  case "$1" in
    knowledge)    echo "Knowledge" ;;
    decisions)    echo "Decisions" ;;
    scope)        echo "Scope" ;;
    upstream)     echo "Upstream Context" ;;
    task_plan)    echo "Task Plan" ;;
    state)        echo "State Context" ;;
    constraints)  echo "Constraints" ;;
    spec_context) echo "Spec Context" ;;
    *)            echo "$1" ;;
  esac
}
_bc_display_priority() {
  # pre-refactor manifest only ever shows "filtered" or "required"
  case "$1" in
    knowledge|decisions|spec_context) echo "filtered" ;;
    *) echo "required" ;;
  esac
}

# --- Build a sort-key-prefixed list of sections based on the display order ---
#
# AP-001 compliant loop: while-read reads from a real temp file, not a process
# substitution. No associative arrays. Pure string accumulation.
SORTED_SECTIONS_FILE="$(mktemp)"
while IFS='|' read -r s_name s_source s_priority s_order s_filter s_cache; do
  [ -z "$s_name" ] && continue
  disp_ord="$(_bc_display_order "$s_name")"
  printf '%s|%s|%s|%s\n' "$disp_ord" "$s_name" "$s_source" "$s_priority" >> "$SORTED_SECTIONS_FILE"
done < "$RECIPE_LINES_FILE"
rm -f "$RECIPE_LINES_FILE"

SORTED_SECTIONS_FINAL="$(mktemp)"
sort -t'|' -k1,1n "$SORTED_SECTIONS_FILE" > "$SORTED_SECTIONS_FINAL"
rm -f "$SORTED_SECTIONS_FILE"

# --- Local override: phase_summaries ---
#
# T01's handle_phase_summaries has a Bash-3.2 `read -r` bug where an
# unterminated dep-list file ("P01" without a trailing newline) causes the
# while-loop to never enter its body. We cannot edit section-handlers.sh
# (T01's deliverable, locked per P05-PLAN #8) so the dispatcher below routes
# phase_summaries to a local corrected implementation. This shim should be
# removed in P06 after the T01 handler is fixed.
_bc_handle_phase_summaries_fixed() {
  printf '## Upstream Context\n\n'
  if [ ! -f "$ROADMAP" ]; then
    printf 'No upstream summaries available.\n'
    return 0
  fi
  local phase_data depends
  phase_data="$(bash "$READ_ROADMAP" "$ROADMAP" phase "$PHASE_ID" 2>/dev/null || true)"
  depends="none"
  if [ -n "$phase_data" ]; then
    depends="$(printf '%s' "$phase_data" | awk '{print $4}')"
  fi
  if [ -z "$depends" ] || [ "$depends" = "none" ]; then
    printf 'No upstream summaries available.\n'
    return 0
  fi
  local dep_list_file any_printed dep summary_file
  dep_list_file="$TMPDIR_BUILD/_bc_deps.txt"
  # Ensure trailing newline so `while read` sees every dep
  printf '%s\n' "$depends" | tr ',' '\n' > "$dep_list_file"
  any_printed=0
  while IFS= read -r dep; do
    dep="$(printf '%s' "$dep" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$dep" ] && continue
    summary_file="$MILESTONE_DIR/phases/${dep}/${dep}-SUMMARY.md"
    if [ -f "$summary_file" ]; then
      printf '\n'
      printf '### %s Summary\n' "$dep"
      cat "$summary_file"
      printf '\n'
      any_printed=1
    fi
  done < "$dep_list_file"
  rm -f "$dep_list_file"
  if [ "$any_printed" -eq 0 ]; then
    printf 'No upstream summaries available.\n'
  fi
}

# ============================================================================
# M019/P00/L1: First-Turn Completeness block
# ----------------------------------------------------------------------------
# Derives a 4-subsection block from the already-included task plan + phase
# plan content. Structural re-surfacing only — the content is already in the
# payload via the task_plan and scope sections. Groups intent + constraints
# + acceptance + files-to-touch so the model sees all four in turn 1
# (per Opus 4.7 adaptation A1: senior-engineer delegation).
# ============================================================================
_bc_build_first_turn_completeness() {
  local task_plan_path="$1"
  local phase_plan_path="$2"
  local out intent_body constraints_body acceptance_body files_body
  # Intent: task plan's Description section (first paragraph after "## Description")
  intent_body="$(sed -n '/^## Description$/,/^## /p' "$task_plan_path" 2>/dev/null | sed '1d;/^## /d' | sed '/^$/q' | head -30)"
  # Constraints: task plan's ## Constraints section
  constraints_body="$(sed -n '/^## Constraints$/,/^## /p' "$task_plan_path" 2>/dev/null | sed '1d;/^## /d' | head -40)"
  # Acceptance: task plan's ## Must-Haves section (truths the task must satisfy)
  acceptance_body="$(sed -n '/^## Must-Haves$/,/^## /p' "$task_plan_path" 2>/dev/null | sed '1d;/^## /d' | head -40)"
  # Files: phase plan's ## Files Likely Touched section
  files_body="$(sed -n '/^## Files Likely Touched$/,/^## /p' "$phase_plan_path" 2>/dev/null | sed '1d;/^## /d' | head -60)"
  out="## First-Turn Completeness"$'\n\n'
  out="${out}### Intent"$'\n'
  out="${out}${intent_body}"$'\n\n'
  out="${out}### Constraints"$'\n'
  out="${out}${constraints_body}"$'\n\n'
  out="${out}### Acceptance Criteria"$'\n'
  out="${out}${acceptance_body}"$'\n\n'
  out="${out}### Files To Touch"$'\n'
  out="${out}${files_body}"$'\n'
  printf '%s' "$out"
}

# ============================================================================
# M019/P00/L4: Parallel Fan-Out directive
# ----------------------------------------------------------------------------
# Emits the known-literal fan-out directive when the recipe or task plan
# declares parallelizable work. Otherwise emits nothing (caller omits section).
# ============================================================================
_bc_should_emit_parallel_fanout() {
  local recipe_file="$1"
  local task_plan_path="$2"
  # (a) recipe-level or section-level parallel_fan_out: true
  if [ -f "$recipe_file" ]; then
    if grep -qE '^[[:space:]]*parallel_fan_out:[[:space:]]*true' "$recipe_file" 2>/dev/null; then
      echo "yes"
      return 0
    fi
  fi
  # (b) task plan YAML frontmatter parallelizable: true
  if [ -f "$task_plan_path" ]; then
    if sed -n '1,/^---$/p' "$task_plan_path" 2>/dev/null | grep -qE '^parallelizable:[[:space:]]*true'; then
      echo "yes"
      return 0
    fi
  fi
  echo "no"
}

_bc_build_parallel_fanout_block() {
  printf '## Parallel Fan-Out\n\n'
  printf 'When this task requires reading multiple files or fanning out across items, spawn multiple subagents in the same turn rather than issuing serial tool calls.\n'
}

# ============================================================================
# M019/P00/L2: Section classifier for stable-before-volatile ordering
# ----------------------------------------------------------------------------
# Returns "stable" or "volatile" for a given display-name. Volatile = content
# that changes per-task or per-turn (A3 cache boundary). Stable = content that
# stays constant across a phase or milestone.
# ============================================================================
_bc_section_volatility_by_name() {
  case "$1" in
    Knowledge|Knowledge\ *|Decisions|Constraints|Scope|"Spec Context") echo "stable" ;;
    "State Context"|"Task Plan"|"Upstream Context"|"First-Turn Completeness"|"Parallel Fan-Out") echo "volatile" ;;
    *) echo "stable" ;;
  esac
}

# --- Dispatch each section to its handler, building display metadata ---
SECTION_COUNT=0
SECTION_NAMES_PIPE=""
SECTION_PRIORITIES_PIPE=""
idx=1

while IFS='|' read -r disp_ord s_name s_source s_priority; do
  [ -z "$s_name" ] && continue

  # Dispatch to handler (write to a staging file first, then decide whether
  # to commit). Top-level scope — no `local` allowed; use plain assignments.
  staging_file="$TMPDIR_BUILD/_staging_s${idx}.txt"
  if [ "$s_source" = "phase_summaries" ]; then
    _bc_handle_phase_summaries_fixed \
      > "$staging_file" 2>/dev/null || {
        emit_event SAFETY_WARNING reason=handler_failed section="$s_name" source="$s_source" >/dev/null 2>&1 || true
        printf 'EVENT-AUDIT:SAFETY_WARNING reason="handler_failed"\n' >/dev/null
        : > "$staging_file"
      }
  else
    dispatch_section_handler "$s_source" "$s_name" \
      "$ORCH_ROOT" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$INCLUDED_IDS_FILE" \
      > "$staging_file" 2>/dev/null || {
        emit_event SAFETY_WARNING reason=handler_failed section="$s_name" source="$s_source" >/dev/null 2>&1 || true
        printf 'EVENT-AUDIT:SAFETY_WARNING reason="handler_failed"\n' >/dev/null
        : > "$staging_file"
      }
  fi

  # Omit-empty: if spec_context produced empty output, skip the section
  # entirely (no manifest row, no payload body). Other section types always
  # commit (they emit their header even when content is empty).
  if [ "$s_source" = "spec_context" ] && [ ! -s "$staging_file" ]; then
    rm -f "$staging_file"
    continue
  fi

  # Commit: move staging file to the real contiguous s<idx>.txt slot
  mv "$staging_file" "$TMPDIR_BUILD/s${idx}.txt"
  SECTION_COUNT=$((SECTION_COUNT + 1))

  disp_name="$(_bc_display_name "$s_name")"
  disp_pri="$(_bc_display_priority "$s_name")"

  if [ -z "$SECTION_NAMES_PIPE" ]; then
    SECTION_NAMES_PIPE="$disp_name"
    SECTION_PRIORITIES_PIPE="$disp_pri"
  else
    SECTION_NAMES_PIPE="${SECTION_NAMES_PIPE}|${disp_name}"
    SECTION_PRIORITIES_PIPE="${SECTION_PRIORITIES_PIPE}|${disp_pri}"
  fi

  idx=$((idx + 1))
done < "$SORTED_SECTIONS_FINAL"
rm -f "$SORTED_SECTIONS_FINAL"

# ============================================================================
# M019/P00/L1: Append First-Turn Completeness volatile section
# ============================================================================
SECTION_COUNT=$((SECTION_COUNT + 1))
_bc_build_first_turn_completeness "$TASK_PLAN" "$PHASE_PLAN" \
  > "$TMPDIR_BUILD/s${SECTION_COUNT}.txt"
if [ -z "$SECTION_NAMES_PIPE" ]; then
  SECTION_NAMES_PIPE="First-Turn Completeness"
  SECTION_PRIORITIES_PIPE="required"
else
  SECTION_NAMES_PIPE="${SECTION_NAMES_PIPE}|First-Turn Completeness"
  SECTION_PRIORITIES_PIPE="${SECTION_PRIORITIES_PIPE}|required"
fi

# ============================================================================
# M019/P00/L4: Append Parallel Fan-Out volatile section (conditional)
# ============================================================================
_BC_FANOUT_DECISION="$(_bc_should_emit_parallel_fanout "$RECIPE_FILE" "$TASK_PLAN")"
if [ "$_BC_FANOUT_DECISION" = "yes" ]; then
  SECTION_COUNT=$((SECTION_COUNT + 1))
  _bc_build_parallel_fanout_block > "$TMPDIR_BUILD/s${SECTION_COUNT}.txt"
  SECTION_NAMES_PIPE="${SECTION_NAMES_PIPE}|Parallel Fan-Out"
  SECTION_PRIORITIES_PIPE="${SECTION_PRIORITIES_PIPE}|required"
fi

# ============================================================================
# M019/P00/L2: Classify each emitted section as stable or volatile so the
# final emit loop can insert <dispatch-volatile> markers. Uses display-name
# classification via _bc_section_volatility_by_name. Result is two
# space-separated index lists consumed by _bc_assemble_manifest_and_emit.
# ============================================================================
BC_STABLE_IDXS=""
BC_VOLATILE_ALL_IDXS=""
_bc_classify_i=1
IFS='|' read -ra _BC_CLASSIFY_NAMES <<EOF_CLASSIFY
$SECTION_NAMES_PIPE
EOF_CLASSIFY
for _bc_nm in "${_BC_CLASSIFY_NAMES[@]}"; do
  _bc_vol="$(_bc_section_volatility_by_name "$_bc_nm")"
  if [ "$_bc_vol" = "volatile" ]; then
    BC_VOLATILE_ALL_IDXS="${BC_VOLATILE_ALL_IDXS}${_bc_classify_i} "
  else
    BC_STABLE_IDXS="${BC_STABLE_IDXS}${_bc_classify_i} "
  fi
  _bc_classify_i=$((_bc_classify_i + 1))
done
export BC_STABLE_IDXS BC_VOLATILE_ALL_IDXS

FRONTMATTER='---
schema_version: "1.0"
type: dispatch-prompt
---'

TITLE="# Dispatch Context -- $TASK_ID (Phase $PHASE_ID, Milestone $MILESTONE_ID)"

# ============================================================================
# M019/P01/T02: payload_breakdown emitter
# ----------------------------------------------------------------------------
# Emits exactly one `payload_breakdown` JSONL record per build-context.sh
# invocation. The emission is OUTSIDE the payload stdout stream: the
# assembled payload is captured to $PAYLOAD_CAPTURE, `cat`ed to stdout
# byte-identical to the pre-instrumentation path, then measured and logged.
#
# SC-6 byte-identical stdout contract — never add bytes to the payload.
# MEM004 carve-out applies: pipes/$()/awk permitted (emitter is
# dispatch-internal, not agent-facing).
# ============================================================================
_bc_emit_payload_breakdown() {
  # Arg: path to the captured payload file.
  local capture_file="$1"

  # Source pricing helpers lazily so zero-overhead when the file is absent.
  if ! type chars_to_tokens_quartile >/dev/null 2>&1; then
    if [ -r "$PROJECT_ROOT/scripts/lib/pricing.sh" ]; then
      . "$PROJECT_ROOT/scripts/lib/pricing.sh" || return 0
    else
      return 0
    fi
  fi

  local payload_chars payload_tokens
  payload_chars="$(wc -c < "$capture_file" | tr -d ' ')"
  payload_tokens="$(chars_to_tokens_quartile "$payload_chars")"

  # Build section_tokens JSON object. Parse SECTION_NAMES_PIPE into an array
  # (bash 3.2: IFS + read -ra); measure each $TMPDIR_BUILD/s<i>.txt file.
  local _BC_PB_NAMES _idx=0 _i=1 section_tokens_json="" _pair
  local sec_bytes sec_tokens sec_name sec_name_esc sec_file
  IFS='|' read -ra _BC_PB_NAMES <<EOF_PB_NAMES
$SECTION_NAMES_PIPE
EOF_PB_NAMES
  while [ "$_i" -le "$SECTION_COUNT" ]; do
    sec_file="$TMPDIR_BUILD/s${_i}.txt"
    if [ -f "$sec_file" ]; then
      sec_bytes="$(wc -c < "$sec_file" | tr -d ' ')"
    else
      sec_bytes=0
    fi
    sec_tokens="$(chars_to_tokens_quartile "$sec_bytes")"
    sec_name="${_BC_PB_NAMES[$_idx]:-section_${_i}}"
    # JSON-escape double quotes and backslashes in the display name.
    sec_name_esc="$(printf '%s' "$sec_name" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    _pair="\"${sec_name_esc}\":${sec_tokens}"
    if [ -z "$section_tokens_json" ]; then
      section_tokens_json="$_pair"
    else
      section_tokens_json="${section_tokens_json},${_pair}"
    fi
    _idx=$(( _idx + 1 ))
    _i=$(( _i + 1 ))
  done

  local log_dir log_file ts model
  log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
  # Fixture mode: if ORCH_ROOT already IS the milestone dir, log directly there.
  if [ ! -d "$log_dir" ] && [ -d "$ORCH_ROOT/phases" ]; then
    log_dir="$ORCH_ROOT"
  fi
  log_file="$log_dir/execution-log.jsonl"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  model="${ORCH_MODEL:-}"

  mkdir -p "$log_dir" 2>/dev/null || {
    printf 'build-context.sh: payload_breakdown emit skipped (mkdir failed on %s)\n' "$log_dir" >&2
    return 0
  }

  printf '{"record_type":"payload_breakdown","unitId":"%s/%s/%s","milestone":"%s","phase":"%s","task":"%s","payload_chars":%d,"payload_tokens_estimate":%d,"token_estimate_method":"char-quartile","section_tokens":{%s},"model":"%s","source":"estimate","timestamp":"%s"}\n' \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$payload_chars" "$payload_tokens" \
    "$section_tokens_json" "$model" "$ts" \
    >> "$log_file" 2>/dev/null || {
    printf 'build-context.sh: payload_breakdown append failed on %s\n' "$log_file" >&2
    return 0
  }
  return 0
}

# Capture the assembled payload into a temp file so we can measure its byte
# size AND still emit it to stdout byte-identically (SC-6). Zero-token: no new
# content is added to the payload; only a post-emit observation is made.
PAYLOAD_CAPTURE="$TMPDIR_BUILD/_payload_capture.txt"
_bc_assemble_manifest_and_emit "$SECTION_COUNT" "$SECTION_NAMES_PIPE" "$SECTION_PRIORITIES_PIPE" "$FRONTMATTER" "$TITLE" > "$PAYLOAD_CAPTURE"
cat "$PAYLOAD_CAPTURE"
_bc_emit_payload_breakdown "$PAYLOAD_CAPTURE" || true
exit 0
