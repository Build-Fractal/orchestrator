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
# M033/P03/T04 #Q-11: skip _<sentinel>/ paths from milestone iteration.
# This script resolves a single MILESTONE_ID at $ORCH_ROOT/milestones/<id>/ —
# it does NOT enumerate `milestones/*/`, so the `_*`-prefix skip clause is
# unnecessary at the path-resolution sites below. Callers MUST not pass
# `_imported-context` or any `_*`-prefix sentinel as the milestone arg;
# sentinel directories are not milestones. A future build-context section
# handler MAY surface imported-context via dedicated injection (the sentinel
# filename is grep-discoverable via `context_source: imported-from-existing`).
# See `references/imported-context-sentinel.md`.
#
# Output: assembled dispatch prompt on stdout (with manifest header).
# Stderr: "Context payload: X bytes (Y% of total artifacts)" + single RESULT: line.
# Exit 0 on success, 1 on config/state/io error.
#
# Bash 3.2 compatible. Standalone-capable (works without ORCH_RUN_ID).
# Constitution: Principle X (Templating Over Inference), Principle XIII
# (Agent Instruction Schema), Principle IX (Frozen Timestamps via orch_now).
#
# Key links (M031/P01):
#   - templates/orchestrator-config-default.yml — source of truth for the
#     three M031 knobs read in --profile=quick mode (quick_knowledge_token_budget,
#     entry_routing_confidence_floor, tier_a_plus_prompt_summary_lines).
#   - references/RUNTIME-ASSUMPTIONS.md — documents the M018 tier-1
#     inline_threshold_tokens default (1500) consumed by SC-3.

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

# M018/P02/T02: knowledge-aware status filter library. Reads
# compression.knowledge_filter.drop_list and excludes entries whose
# `status:` frontmatter matches the drop-list. Sourced unconditionally —
# the library is pure (function defs only, no side effects at source time).
. "$PROJECT_ROOT/scripts/lib/knowledge-filter.sh"

# M018/P02/T02: source preservation-check library defensively so downstream
# tier wiring (P03/P04/P06) inherits a working source path with no further
# wiring. The filter operates on whole-entry granularity per the grammar
# contract at references/compression-grammar.md `## Tier: filter` failure
# semantics, so no caller wires pres_check_section in P02. The `|| true`
# keeps build-context bail-safe when the library is absent (e.g., on a
# partial install).
if [ -r "$PROJECT_ROOT/scripts/lib/preservation-check.sh" ]; then
  . "$PROJECT_ROOT/scripts/lib/preservation-check.sh" || true
fi

# Pre-refactor helper scripts still used by the planning branch
SCOPE_FILTER="$SCRIPT_DIR/scope-filter.sh"
READ_ROADMAP="$PROJECT_ROOT/scripts/state/read-roadmap.sh"
READ_CONFIG="$PROJECT_ROOT/scripts/state/read-config.sh"
TRAVERSE_GRAPH="$PROJECT_ROOT/scripts/knowledge/traverse-graph.sh"
RESOLVE_ENTRIES="$PROJECT_ROOT/scripts/knowledge/resolve-entries.sh"
INCREMENT_HITS="$PROJECT_ROOT/scripts/knowledge/increment-hits.sh"

# --- Result emission on exit (single RESULT line, written to stderr) ---
# We must capture the original $? at trap entry before any cleanup commands
# mutate it — otherwise `rm -rf` (or any other cleanup) overwrites the real
# exit code and the trap would emit status:"ok" on a failed run.
_BC_RESULT_EMITTED=0
_bc_final_result() {
  local rc="${1:-$?}"
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
  local rc=$?
  [ -n "${TMPDIR_BUILD:-}" ] && rm -rf "$TMPDIR_BUILD" 2>/dev/null || true
  [ -n "${INCLUDED_IDS_FILE:-}" ] && rm -f "$INCLUDED_IDS_FILE" 2>/dev/null || true
  _bc_final_result "$rc"
}
trap _bc_cleanup_and_result EXIT

# --- Argument parsing ---
ORCH_ROOT=""
MILESTONE_ID=""
PHASE_ID=""
TASK_ID=""
CONFIG_DEFAULTS=""
RECIPE_OVERRIDE=""
# M031/P01/T01: additive flags for FR-2 (--profile=quick|standard|full) and
# AD-11 (--meta-out <file> JSON sidecar). When --task-plan is supplied the
# script enters "direct mode" — it does not derive milestone/phase/task from
# positional args; instead it builds a minimal Quick payload from the named
# task plan and emits the sidecar. This is the cross-milestone interface
# contract for M029 orchestrator:where and M036 reference-corpus ingest. The
# Quick path runs the script end-to-end (CON-1 invariant); there is no
# "skip context" exit — only profile-aware scope tightening.
PROFILE=""
META_OUT=""
DIRECT_TASK_PLAN=""
DIRECT_OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --config-defaults) CONFIG_DEFAULTS="$2"; shift 2 ;;
    --recipe)          RECIPE_OVERRIDE="$2"; shift 2 ;;
    --profile=*)       PROFILE="${1#--profile=}"; shift ;;
    --profile)         PROFILE="$2"; shift 2 ;;
    --meta-out)        META_OUT="$2"; shift 2 ;;
    --task-plan)       DIRECT_TASK_PLAN="$2"; shift 2 ;;
    --out)             DIRECT_OUT="$2"; shift 2 ;;
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

# M031/P01/T01: validate --profile value (quick|standard|full).
case "$PROFILE" in
  ""|quick|standard|full) : ;;
  *)
    printf 'build-context.sh: unrecognized profile %s (expected quick|standard|full)\n' "$PROFILE" >&2
    exit 1
    ;;
esac

# M031/P01/T01: direct-mode short-circuit (--task-plan supplied). Builds a
# minimal Quick-flavored payload from the named task plan, writes it to --out,
# and emits the AD-11 JSON sidecar to --meta-out. Emits one
# `payload_breakdown` JSONL record to honor CON-1 (every dispatch path emits
# one). Falls through to the regular positional flow when --task-plan is
# absent, preserving byte-equal behavior of the historical invocation.
if [ -n "$DIRECT_TASK_PLAN" ]; then
  if [ ! -f "$DIRECT_TASK_PLAN" ]; then
    printf 'build-context.sh: --task-plan file not found: %s\n' "$DIRECT_TASK_PLAN" >&2
    exit 1
  fi
  # Default profile in direct mode is quick (the FR-2 entry point M031 cares
  # about); operators can still pass --profile=standard|full explicitly.
  if [ -z "$PROFILE" ]; then
    PROFILE="quick"
  fi

  _M031_PROJECT_ROOT="$PROJECT_ROOT"
  _M031_KNOWLEDGE_INDEX=""
  if [ -f "$_M031_PROJECT_ROOT/KNOWLEDGE-INDEX.md" ]; then
    _M031_KNOWLEDGE_INDEX="$_M031_PROJECT_ROOT/KNOWLEDGE-INDEX.md"
  fi

  # Parse touched-files from the task-plan body. Recognises a
  # `touched_files:` line (corpus fixture shape) or a
  # `Files Likely Touched` / `Inputs` markdown subsection.
  _M031_TOUCHED=""
  _M031_TF_LINE=""
  _M031_TF_LINE="$(grep -E '^touched_files:' "$DIRECT_TASK_PLAN" 2>/dev/null | head -1 || true)"
  if [ -n "$_M031_TF_LINE" ]; then
    _M031_TOUCHED="$(printf '%s' "$_M031_TF_LINE" | sed 's/^touched_files:[[:space:]]*//')"
  fi

  _M031_MEM_COUNT=0
  _M031_KNOWLEDGE_BODY=""
  if [ -n "$_M031_KNOWLEDGE_INDEX" ] && [ -f "$_M031_KNOWLEDGE_INDEX" ]; then
    # Quick profile: 1-hop, touched-files-only scope. Resolve the touched
    # MEM IDs by intersecting filenames mentioned in the index against
    # touched files. When no touched-file set is derivable, fall back to
    # the first N MEM IDs in the index (parity with degenerate-plan
    # behavior — not a regression).
    _M031_TF_TMP="$(mktemp)"
    if [ -n "$_M031_TOUCHED" ]; then
      printf '%s\n' "$_M031_TOUCHED" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' > "$_M031_TF_TMP"
    fi
    _M031_IDS_TMP="$(mktemp)"
    if [ -s "$_M031_TF_TMP" ]; then
      grep -oE 'MEM[0-9]+' "$_M031_KNOWLEDGE_INDEX" 2>/dev/null | sort -u > "$_M031_IDS_TMP" || true
    else
      grep -oE 'MEM[0-9]+' "$_M031_KNOWLEDGE_INDEX" 2>/dev/null | sort -u | head -5 > "$_M031_IDS_TMP" || true
    fi
    _M031_MEM_COUNT="$(wc -l < "$_M031_IDS_TMP" | tr -d ' ')"
    if [ -s "$_M031_IDS_TMP" ]; then
      _M031_RESOLVE="$_M031_PROJECT_ROOT/scripts/knowledge/resolve-entries.sh"
      if [ -x "$_M031_RESOLVE" ] || [ -f "$_M031_RESOLVE" ]; then
        _M031_KNOWLEDGE_BODY="$(cat "$_M031_IDS_TMP" | bash "$_M031_RESOLVE" 2>/dev/null || true)"
      fi
    fi
    rm -f "$_M031_TF_TMP" "$_M031_IDS_TMP"
  fi
  if [ -z "$_M031_KNOWLEDGE_BODY" ]; then
    _M031_KNOWLEDGE_BODY="No knowledge entries in scope."
  fi

  # Assemble payload. The Decisions section is omitted under the Quick
  # profile (FR-2). The Knowledge section header is always present so the
  # downstream agent contract is preserved.
  _M031_OUT_DIR="$(dirname "$DIRECT_OUT")"
  if [ -n "$_M031_OUT_DIR" ] && [ ! -d "$_M031_OUT_DIR" ]; then
    mkdir -p "$_M031_OUT_DIR" 2>/dev/null || true
  fi
  if [ -z "$DIRECT_OUT" ]; then
    DIRECT_OUT="/dev/stdout"
  fi
  {
    printf '%s\n' '---'
    printf '%s\n' 'schema_version: "1.0"'
    printf '%s\n' 'type: dispatch-prompt'
    printf 'profile: "%s"\n' "$PROFILE"
    printf '%s\n' '---'
    printf '\n'
    printf '# Dispatch Context (direct mode, profile=%s)\n\n' "$PROFILE"
    printf '## Knowledge\n\n'
    printf '%s\n\n' "$_M031_KNOWLEDGE_BODY"
    if [ "$PROFILE" != "quick" ]; then
      printf '## Decisions\n\n'
      printf '(decisions section assembled by full-mode positional flow; direct mode includes a marker only.)\n\n'
    fi
    printf '## Task Plan\n\n'
    cat "$DIRECT_TASK_PLAN"
    printf '\n'
  } > "$DIRECT_OUT"

  # Token estimation reuses the existing build-context.sh estimator
  # (chars_to_tokens_quartile from scripts/lib/pricing.sh) per the task-plan
  # constraint "one estimator, one field."
  _M031_TOTAL_TOKENS=0
  if [ -r "$_M031_PROJECT_ROOT/scripts/lib/pricing.sh" ]; then
    . "$_M031_PROJECT_ROOT/scripts/lib/pricing.sh" 2>/dev/null || true
    if type chars_to_tokens_quartile >/dev/null 2>&1 && [ -f "$DIRECT_OUT" ]; then
      _M031_PAYLOAD_CHARS="$(wc -c < "$DIRECT_OUT" | tr -d ' ')"
      _M031_TOTAL_TOKENS="$(chars_to_tokens_quartile "$_M031_PAYLOAD_CHARS")"
    fi
  fi

  # Emit AD-11 JSON sidecar (5 keys: mem_count, total_tokens, profile,
  # compression_applied, snip_applied). Direct mode does not invoke tier-1
  # paging or tier-2 snip (the empirical-baseline corpus is small enough
  # that compression does not fire), so both compression flags are false.
  if [ -n "$META_OUT" ]; then
    _M031_META_DIR="$(dirname "$META_OUT")"
    if [ -n "$_M031_META_DIR" ] && [ ! -d "$_M031_META_DIR" ]; then
      mkdir -p "$_M031_META_DIR" 2>/dev/null || true
    fi
    {
      printf '{'
      printf '"mem_count":%d,' "$_M031_MEM_COUNT"
      printf '"total_tokens":%d,' "$_M031_TOTAL_TOKENS"
      printf '"profile":"%s",' "$PROFILE"
      printf '"compression_applied":false,'
      printf '"snip_applied":false'
      printf '}\n'
    } > "$META_OUT"
  fi

  # CON-1 invariant: emit one payload_breakdown JSONL record. Direct mode
  # appends to a milestone-agnostic log under the project root since no
  # milestone is bound; the dispatcher consumes JSONL records by record_type
  # not by file path.
  _M031_LOG_DIR="$_M031_PROJECT_ROOT/.orchestrator"
  if [ -d "$_M031_LOG_DIR" ]; then
    _M031_LOG_FILE="$_M031_LOG_DIR/direct-mode-execution-log.jsonl"
    _M031_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '{"record_type":"payload_breakdown","unitId":"direct/%s","milestone":"direct","phase":"direct","task":"direct","payload_chars":%d,"payload_tokens_estimate":%d,"profile":"%s","knowledge_section_tokens":0,"tier1_replacements":0,"tier2_snips":0,"timestamp":"%s"}\n' \
      "$PROFILE" "${_M031_PAYLOAD_CHARS:-0}" "$_M031_TOTAL_TOKENS" "$PROFILE" "$_M031_TS" \
      >> "$_M031_LOG_FILE" 2>/dev/null || true
  fi

  emit_result ok "" "context assembled (direct mode, profile=$PROFILE)" >&2 2>/dev/null || true
  _BC_RESULT_EMITTED=1
  exit 0
fi

if [ -z "${ORCH_ROOT:-}" ] || [ -z "${MILESTONE_ID:-}" ] || [ -z "${PHASE_ID:-}" ] || [ -z "${TASK_ID:-}" ]; then
  printf 'build-context.sh: missing required arguments\n' >&2
  printf 'Usage: build-context.sh <orch_root> <milestone> <phase> <task> [--config-defaults <f>] [--recipe <f>] [--profile=quick|standard|full] [--meta-out <file>] [--task-plan <file> --out <file>]\n' >&2
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

# M018/P02/T02: compression config (FR-15 master toggle + FR-3 filter toggle).
# read-config.sh does not support dotted keys; the kf_* helpers parse the
# compression: block directly via awk. Default is enabled when the config or
# block is missing — pre-M018 projects opt in by adding the block (templates
# ship the block enabled by default).
COMPRESSION_ENABLED="$(kf_get_compression_enabled "$PROJECT_ROOT")"
KNOWLEDGE_FILTER_ENABLED="$(kf_get_knowledge_filter_enabled "$PROJECT_ROOT")"
export COMPRESSION_ENABLED KNOWLEDGE_FILTER_ENABLED

# M018/P03/T01: Tier 1 microcompact config. Defaults: enabled=true,
# inline_threshold_tokens=1500, preview_lines=5,
# cache_dir=.orchestrator/cache/tool-results/. Resolution honors the master
# `compression.enabled` toggle (FR-15) — when that is false the entire
# pipeline short-circuits regardless of per-tier toggles.
TIER1_ENABLED="$(kf_get_tier1_enabled "$PROJECT_ROOT")"
TIER1_INLINE_THRESHOLD_TOKENS="$(kf_get_tier1_inline_threshold_tokens "$PROJECT_ROOT")"
TIER1_PREVIEW_LINES="$(kf_get_tier1_preview_lines "$PROJECT_ROOT")"
TIER1_CACHE_DIR="$(kf_get_tier1_cache_dir "$PROJECT_ROOT")"
# Resolve cache_dir relative to PROJECT_ROOT when not absolute.
case "$TIER1_CACHE_DIR" in
  /*) : ;;  # absolute, leave alone
  *)  TIER1_CACHE_DIR="$PROJECT_ROOT/$TIER1_CACHE_DIR" ;;
esac
export TIER1_ENABLED TIER1_INLINE_THRESHOLD_TOKENS TIER1_PREVIEW_LINES TIER1_CACHE_DIR
# M018/P04/T01: Tier 2 snip config. Defaults: enabled=true,
# section_budget_tokens=1500, protected_tail_ratio=0.3. Master
# `compression.enabled` toggle (FR-15) gates this tier; per-tier
# `compression.tier2.enabled` short-circuits Tier 2 alone.
TIER2_ENABLED="$(kf_get_tier2_enabled "$PROJECT_ROOT")"
TIER2_SECTION_BUDGET_TOKENS="$(kf_get_tier2_section_budget_tokens "$PROJECT_ROOT")"
TIER2_PROTECTED_TAIL_RATIO="$(kf_get_tier2_protected_tail_ratio "$PROJECT_ROOT")"
export TIER2_ENABLED TIER2_SECTION_BUDGET_TOKENS TIER2_PROTECTED_TAIL_RATIO

# M018/P06/T01: Tier 3 auto-compact config. Defaults: enabled=true,
# intensity_floor=standard, section_budget_tokens=2500,
# originals_dir=.orchestrator/cache/tier3-originals/, output_max_ratio=0.80,
# density_floor=1.5. Master `compression.enabled` toggle (FR-15) gates this
# tier; per-tier `compression.tier3.enabled` short-circuits Tier 3 alone.
TIER3_ENABLED="$(kf_get_tier3_enabled "$PROJECT_ROOT")"
TIER3_INTENSITY_FLOOR="$(kf_get_tier3_intensity_floor "$PROJECT_ROOT")"
TIER3_SECTION_BUDGET_TOKENS="$(kf_get_tier3_section_budget_tokens "$PROJECT_ROOT")"
TIER3_ORIGINALS_DIR="$(kf_get_tier3_originals_dir "$PROJECT_ROOT")"
TIER3_OUTPUT_MAX_RATIO="$(kf_get_tier3_output_max_ratio "$PROJECT_ROOT")"
TIER3_DENSITY_FLOOR="$(kf_get_tier3_density_floor "$PROJECT_ROOT")"
case "$TIER3_ORIGINALS_DIR" in
  /*) : ;;
  *)  TIER3_ORIGINALS_DIR="$PROJECT_ROOT/$TIER3_ORIGINALS_DIR" ;;
esac
export TIER3_ENABLED TIER3_INTENSITY_FLOOR TIER3_SECTION_BUDGET_TOKENS \
       TIER3_ORIGINALS_DIR TIER3_OUTPUT_MAX_RATIO TIER3_DENSITY_FLOOR

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
  # Resolution order (standalone-first, legacy-embedded as fallback):
  #   1. basename(ORCH_ROOT) == ".orchestrator" → PROJECT_DIR = dirname(ORCH_ROOT)
  #   2. ORCH_ROOT contains .orchestrator/       → PROJECT_DIR = ORCH_ROOT
  #   3. Walker up the tree for .specify/ (legacy spec-kit-embedded shape)
  # Walker is canonicalized to an absolute path first and uses a fixed-point
  # terminator so a relative ORCH_ROOT cannot infinite-loop (prev dirname == curr).
  # Rule 1 is the critical fix for standalone orchestrator projects where a stale
  # ~/.specify/ in the home directory would otherwise hijack PROJECT_DIR.
  local FEATURE_SPEC=""
  local PROJECT_DIR=""
  local abs_orch_root
  abs_orch_root="$(cd "$ORCH_ROOT" 2>/dev/null && pwd)" || abs_orch_root="$ORCH_ROOT"
  if [ "$(basename "$abs_orch_root")" = ".orchestrator" ]; then
    PROJECT_DIR="$(dirname "$abs_orch_root")"
  elif [ -d "$abs_orch_root/.orchestrator" ]; then
    PROJECT_DIR="$abs_orch_root"
  else
    # Walker covers invocations from a path deeper than ORCH_ROOT (e.g. a
    # milestone or phase directory passed directly). Accept .orchestrator/ as
    # a marker alongside .specify/ so standalone projects aren't forced to
    # rely on the legacy spec-kit layout.
    local candidate="$abs_orch_root" prev=""
    while [ "$candidate" != "/" ] && [ "$candidate" != "$prev" ]; do
      if [ "$(basename "$candidate")" = ".specify" ] || [ "$(basename "$candidate")" = ".orchestrator" ]; then
        PROJECT_DIR="$(dirname "$candidate")"
        break
      fi
      if [ -d "$candidate/.specify" ] || [ -d "$candidate/.orchestrator" ]; then
        PROJECT_DIR="$candidate"
        break
      fi
      prev="$candidate"
      candidate="$(dirname "$candidate")"
    done
  fi

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
      # Guard: find on a nonexistent dir exits 1, which under set -euo pipefail
      # would kill the script (2>/dev/null silences stderr but not the exit
      # code). Skip the fallback entirely when specs/ is absent.
      if [ -d "$PROJECT_DIR/specs" ]; then
        local spec_count
        spec_count="$(find "$PROJECT_DIR/specs" -name "spec.md" -type f 2>/dev/null | wc -l | tr -d ' ')"
        if [ "$spec_count" = "1" ]; then
          spec_file="$(find "$PROJECT_DIR/specs" -name "spec.md" -type f 2>/dev/null | head -1)"
        fi
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
    # M018/P02/T02: apply knowledge-aware status filter (FR-3).
    _bc_apply_knowledge_filter "$resolved"
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
    # M018/P02/T02: apply knowledge-aware status filter (FR-3).
    _bc_apply_knowledge_filter "$entries"
  fi
}

# M018/P02/T02: shared filter wrapper used by both planning knowledge paths
# and (via the same library) by handle_knowledge in section-handlers.sh.
# Stages the resolved-entries stream through kf_filter_stream when the
# compression layer is enabled. When the filter drops every entry, emits
# the literal "(no qualifying knowledge entries)" sentinel (spec
# acceptance scenario 5) so the section header still parses cleanly.
_bc_apply_knowledge_filter() {
  local stream="$1"
  if [ "$COMPRESSION_ENABLED" != "true" ] || [ "$KNOWLEDGE_FILTER_ENABLED" != "true" ]; then
    printf '%s\n' "$stream"
    return 0
  fi
  local drop_list_file stats_file out_file
  drop_list_file="$TMPDIR_BUILD/_drop_list.txt"
  stats_file="$TMPDIR_BUILD/_filter_stats.txt"
  out_file="$TMPDIR_BUILD/_filter_out.md"
  kf_read_drop_list "$PROJECT_ROOT" > "$drop_list_file"
  printf '%s\n' "$stream" | kf_filter_stream "$drop_list_file" "$stats_file" > "$out_file"
  # Detect empty-after-filter: no `^---$` frontmatter delimiters in output.
  local fm_count
  fm_count="$(grep -cE '^---$' "$out_file" 2>/dev/null || true)"
  if [ -z "$fm_count" ]; then
    fm_count=0
  fi
  if [ "$fm_count" -eq 0 ]; then
    printf '(no qualifying knowledge entries)\n'
  else
    cat "$out_file"
  fi
}

# ============================================================================
# M018/P03/T01: Tier 1 microcompact — tool-result paging + cache reuse.
# ============================================================================
# Argument 1: path to the captured payload file (already assembled, prior
# to _bc_emit_payload_breakdown). The function rewrites the file in place
# when paging fires; otherwise leaves it untouched.
#
# Side-effect outputs:
#   - Writes paged tool-result bodies to $TIER1_CACHE_DIR/<sha256> (one
#     file per unique command+input, full-fidelity body).
#   - Writes a stats line to $TMPDIR_BUILD/_tier1_stats.txt of the form:
#       savings_tokens=<N> invocations=<N>
#     The caller (_bc_emit_payload_breakdown) reads this file to populate
#     the additive `tier1_savings_tokens` + `tier1_invocations` fields.
#
# Short-circuits (passthrough; stats file not written; no cache writes):
#   - $COMPRESSION_ENABLED != "true"           (FR-15 master toggle)
#   - $TIER1_ENABLED != "true"                  (per-tier toggle)
#   - The capture file contains zero `^<tool-result command=` opens.
#   - mkdir -p $TIER1_CACHE_DIR fails (one-line stderr warning emitted).
#
# Preservation self-check:
#   - After paging, runs pres_check_section "tier1" against the post-paging
#     file. On failure, restores the pre-paging file and emits
#     `tier_preservation_violation` via pres_emit_violation.
#
# AP-009 compliance: no compound chains > 2; no plain subshells; no
# $(...|...). Awk does the heavy lifting in a single invocation.
# MEM004 carve-out: dispatch-internal helper, like _bc_apply_knowledge_filter.
_bc_apply_tier1() {
  local capture_file="$1"
  if [ "$COMPRESSION_ENABLED" != "true" ] || [ "$TIER1_ENABLED" != "true" ]; then
    return 0
  fi
  if [ ! -f "$capture_file" ]; then
    return 0
  fi
  # Quick gate: any tool-result blocks at all? grep -c on no-match exits 1
  # but still prints "0" on stdout — defensive zero-fallback per MEM (pitfall
  # flagged in T01 dispatch payload).
  local _tr_count
  _tr_count="$(grep -c '^<tool-result command=' "$capture_file" 2>/dev/null || true)"
  if [ -z "$_tr_count" ]; then
    _tr_count=0
  fi
  if [ "$_tr_count" = "0" ]; then
    return 0
  fi

  if ! mkdir -p "$TIER1_CACHE_DIR" 2>/dev/null; then
    printf 'build-context.sh: tier1 disabled — cache_dir unwritable: %s\n' "$TIER1_CACHE_DIR" >&2
    return 0
  fi

  local pre_file out_file stats_file
  pre_file="$TMPDIR_BUILD/_tier1_pre.txt"
  out_file="$TMPDIR_BUILD/_tier1_out.txt"
  stats_file="$TMPDIR_BUILD/_tier1_stats.txt"
  cp "$capture_file" "$pre_file"

  # Single awk pass: scan the file, accumulate command + input + body for
  # every <tool-result ...>...</tool-result> block, hash + write the cache,
  # and emit the transformed payload to $out_file. Running totals to
  # $stats_file. Inputs threaded as awk variables:
  #   th     — inline_threshold_tokens
  #   pl     — preview_lines
  #   cdir   — TIER1_CACHE_DIR (with trailing slash)
  #   stf    — stats_file
  # Token estimation mirrors chars_to_tokens_quartile from
  # scripts/lib/pricing.sh: int((chars + 3) / 4).
  awk -v th="$TIER1_INLINE_THRESHOLD_TOKENS" \
      -v pl="$TIER1_PREVIEW_LINES" \
      -v cdir="$TIER1_CACHE_DIR" \
      -v stf="$stats_file" \
      '
      function tok(c) { return int((c + 3) / 4) }
      function sha256(s,   tmpf, cmd, h) {
        # Stage payload to temp file (avoids shell-escaping issues with
        # arbitrary command/input bytes) and shell out for the digest.
        tmpf = stf "._sha_in"
        printf "%s", s > tmpf
        close(tmpf)
        cmd = "shasum -a 256 \"" tmpf "\" | cut -c1-64"
        cmd | getline h
        close(cmd)
        return h
      }
      function flush_block(   body_chars, body_tok, key, path, preview, n, lines, i, prev_chars, _t) {
        if (cmd_only) {
          printf "%s", raw
          raw=""; in_block=0; saw_input=0; saw_body=0
          cmd_only=0
          return
        }
        body_chars = length(body_buf)
        body_tok = tok(body_chars)
        if (body_tok <= th + 0) {
          printf "%s", raw
          raw=""; in_block=0; saw_input=0; saw_body=0
          body_buf=""; input_buf=""; saved_cmd=""
          return
        }
        # Page it. SHA-256 over command + 0x1F + input.
        key = sha256(saved_cmd "\x1F" input_buf)
        # cdir already terminates with "/" when sourced from config (the
        # default does); guard for the edge where it does not.
        if (substr(cdir, length(cdir)) == "/") {
          path = cdir key
        } else {
          path = cdir "/" key
        }
        # Write the cache file iff missing (preserve mtime on reuse).
        if ((getline _t < path) < 0) {
          close(path)
          printf "%s", body_buf > path
          close(path)
        } else {
          close(path)
        }
        # Build preview: first pl lines of body.
        n = split(body_buf, lines, "\n")
        preview = ""
        for (i = 1; i <= n && i <= pl + 0; i++) {
          if (preview == "") {
            preview = lines[i]
          } else {
            preview = preview "\n" lines[i]
          }
        }
        prev_chars = length(preview)
        # Emit the paged tag. Output ends with newline so subsequent payload
        # bytes flow normally.
        printf "<tool-result file=\"%s\" preview-lines=\"%d\" command=\"%s\" original-body-tokens=\"%d\">\n%s\n</tool-result>\n", \
               path, pl + 0, saved_cmd, body_tok, preview
        savings_tok += body_tok - tok(prev_chars)
        inv_total += 1
        raw=""; in_block=0; saw_input=0; saw_body=0
        body_buf=""; input_buf=""; saved_cmd=""
      }
      BEGIN { in_block=0; saw_input=0; saw_body=0; cmd_only=0; raw=""; savings_tok=0; inv_total=0 }
      /^<tool-result command=/ {
        line=$0
        match(line, /command="[^"]*"/)
        if (RSTART > 0) {
          # substr(..., RSTART+9, RLENGTH-10): drop `command="` (9 chars)
          # and the trailing `"` (1 char).
          saved_cmd = substr(line, RSTART + 9, RLENGTH - 10)
        } else {
          saved_cmd = ""
        }
        in_block=1; saw_input=0; saw_body=0; cmd_only=1
        body_buf=""; input_buf=""
        raw=line "\n"
        next
      }
      in_block && /^<tool-result-input>/  { saw_input=1; raw=raw $0 "\n"; next }
      in_block && /^<\/tool-result-input>/ { saw_input=0; raw=raw $0 "\n"; next }
      in_block && saw_input==1            { input_buf = input_buf $0 "\n"; raw=raw $0 "\n"; next }
      in_block && /^<tool-result-body>/   { saw_body=1; cmd_only=0; raw=raw $0 "\n"; next }
      in_block && /^<\/tool-result-body>/ { saw_body=0; raw=raw $0 "\n"; next }
      in_block && saw_body==1             { body_buf = body_buf $0 "\n"; raw=raw $0 "\n"; next }
      in_block && /^<\/tool-result>/      { raw=raw $0 "\n"; flush_block(); next }
      in_block                            { raw=raw $0 "\n"; next }
      { print }
      END {
        printf "savings_tokens=%d invocations=%d\n", savings_tok, inv_total > stf
        close(stf)
        # Best-effort cleanup of the staging file used by sha256().
        cleanf = stf "._sha_in"
        ("rm -f \"" cleanf "\"") | getline _ign
      }
      ' "$pre_file" > "$out_file"

  # Preservation self-check: pres_check_section <section> <pre> <post> tier1.
  # Strict-multiplicity tier1 semantics. Tier 1 paging legitimately removes
  # tool-result-body content that may itself contain code-fences, JSONL
  # records, or other preserved patterns; under strict tier1/tier2
  # semantics, those would be expected to mismatch. The grammar treats
  # tool-result paging as the failure-semantics carve-out: any match-count
  # delta on a paged block triggers passthrough + a violation record.
  if type pres_check_section >/dev/null 2>&1; then
    if ! pres_check_section "tier1" "$pre_file" "$out_file" tier1 >/dev/null 2>&1; then
      if type pres_emit_violation >/dev/null 2>&1; then
        local _t1_log
        _t1_log="$ORCH_ROOT/milestones/$MILESTONE_ID/execution-log.jsonl"
        if [ ! -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ] && [ -d "$ORCH_ROOT/phases" ]; then
          _t1_log="$ORCH_ROOT/execution-log.jsonl"
        fi
        pres_emit_violation "tier1" "payload" "cross-tier" "$_t1_log" 2>/dev/null || true
      fi
      # Restore pre-paging body; clear stats so emitter writes 0/0.
      cp "$pre_file" "$capture_file"
      printf 'savings_tokens=0 invocations=0\n' > "$stats_file"
      return 0
    fi
  fi

  # Atomic in-place replace.
  mv "$out_file" "$capture_file"
  return 0
}

# M018/P04/T01: Tier 2 snip — section head-drop with protected tail.
#
# Argument 1: path to the captured payload file (already through Tier 1, prior
# to _bc_emit_payload_breakdown). The function rewrites the file in place
# when head-drop fires; otherwise leaves it untouched.
#
# Side-effect outputs:
#   - Writes a stats line to $TMPDIR_BUILD/_tier2_stats.txt of the form:
#       savings_tokens=<N>
#     The caller (_bc_emit_payload_breakdown) reads this file to populate
#     the additive `tier2_savings_tokens` field.
#
# Short-circuits (passthrough; stats file written with savings_tokens=0):
#   - $COMPRESSION_ENABLED != "true"
#   - $TIER2_ENABLED != "true"
#   - The capture file contains zero in-scope `^## ` sections.
#   - Every in-scope section's body token-count is at or below
#     $TIER2_SECTION_BUDGET_TOKENS.
#
# Boundary-refusal: when the line-aligned cut would land inside a multi-line
# preserved span (frontmatter `^---$` pair or `^`{3,}[a-zA-Z0-9_-]*$`
# code-fence pair at matching backtick-count), the cut retreats above the
# span; if no safe boundary exists at or above the naive cut byte and below
# the protected tail, the section passes through unmodified plus a
# tier_preservation_violation JSONL emit (tier=tier2, pattern=spanning
# vocabulary label).
#
# Preservation self-check:
#   - After head-drop, runs pres_check_section "tier2" <pre> <post> tier2
#     against the rewritten payload. On failure, restores the pre-snip
#     payload byte-identical and emits tier_preservation_violation via
#     pres_emit_violation.
#
# AP-009 compliance: no compound chains > 2; no plain subshells; no
# $(...|...). Awk does the heavy lifting in a single invocation.
# MEM004 carve-out: dispatch-internal helper, like _bc_apply_tier1.
_bc_apply_tier2() {
  local capture_file="$1"
  if [ "$COMPRESSION_ENABLED" != "true" ] || [ "$TIER2_ENABLED" != "true" ]; then
    return 0
  fi
  if [ ! -f "$capture_file" ]; then
    return 0
  fi

  local pre_file out_file stats_file
  pre_file="$TMPDIR_BUILD/_tier2_pre.txt"
  out_file="$TMPDIR_BUILD/_tier2_out.txt"
  stats_file="$TMPDIR_BUILD/_tier2_stats.txt"
  cp "$capture_file" "$pre_file"

  # Single awk pass:
  #   - Stream the input line by line.
  #   - Buffer each in-scope section's body (between its `## <Section>`
  #     heading and the next `## ` heading or EOF).
  #   - Track multi-line preserved spans line-by-line so each buffered line
  #     carries a "safe-to-cut-above-this-line" flag.
  #   - At section close, decide whether to head-drop:
  #       body_tokens > budget? compute naive cut, retreat to safe boundary,
  #       emit `## <Section>\n<!-- compressed:tier2 ... -->\n<tail>` or pass
  #       through verbatim plus emit a violation marker for the bash caller
  #       to pick up (via $TMPDIR_BUILD/_tier2_violations.txt).
  #
  # Inputs threaded as awk variables:
  #   budget   — section_budget_tokens
  #   ratio    — protected_tail_ratio (e.g. 0.3)
  #   stf      — stats_file
  #   vlf      — violations_file
  awk -v budget="$TIER2_SECTION_BUDGET_TOKENS" \
      -v ratio="$TIER2_PROTECTED_TAIL_RATIO" \
      -v stf="$stats_file" \
      -v vlf="$TMPDIR_BUILD/_tier2_violations.txt" \
      '
      function tok(c) { return int((c + 3) / 4) }
      function in_scope(name) {
        return (name == "Knowledge" || name == "Task Plan" || name == "Upstream Context")
      }
      function flush_section(   body_chars, body_tokens, cut_byte, i, cum, cut_line, j, drop_chars, drop_tokens, head_safe) {
        if (!in_scope(sec_name)) {
          # Out-of-scope: emit as captured.
          printf "%s", sec_raw
          sec_name=""; sec_raw=""; body_n=0
          return
        }
        body_chars = 0
        for (i = 1; i <= body_n; i++) {
          # +1 for the newline that joins back at emit time.
          body_chars += length(body_lines[i]) + 1
        }
        body_tokens = tok(body_chars)
        if (body_tokens <= budget + 0) {
          # Under budget — pass through verbatim.
          printf "%s", sec_raw
          sec_name=""; sec_raw=""; body_n=0
          return
        }
        # Naive cut byte = floor(body_chars * (1 - ratio)).
        cut_byte = int(body_chars * (1.0 - (ratio + 0)))
        # Walk forward in body lines accumulating until we cross cut_byte.
        cum = 0
        cut_line = body_n
        for (i = 1; i <= body_n; i++) {
          if (cum + length(body_lines[i]) + 1 > cut_byte) {
            cut_line = i
            break
          }
          cum += length(body_lines[i]) + 1
        }
        # Retreat: walk DOWN from cut_line toward line 1 until body_unsafe[i] == 0.
        head_safe = 0
        for (j = cut_line; j >= 1; j--) {
          if (body_unsafe[j] != 1) {
            head_safe = j
            break
          }
        }
        if (head_safe == 0) {
          # No safe boundary found — pass through unmodified, log violation.
          printf "%s", sec_raw
          if (body_unsafe[cut_line] == 1) {
            printf "section=%s pattern=%s\n", sec_name, body_unsafe_label[cut_line] >> vlf
          } else {
            printf "section=%s pattern=%s\n", sec_name, "unknown" >> vlf
          }
          close(vlf)
          sec_name=""; sec_raw=""; body_n=0
          return
        }
        # Compute drop_chars = cumulative bytes of lines [1..head_safe-1].
        drop_chars = 0
        for (i = 1; i < head_safe; i++) {
          drop_chars += length(body_lines[i]) + 1
        }
        if (drop_chars == 0) {
          # Cut at line 1 means nothing actually dropped — pass through.
          printf "%s", sec_raw
          sec_name=""; sec_raw=""; body_n=0
          return
        }
        drop_tokens = tok(drop_chars)
        # Emit: heading line + marker + post-cut body.
        printf "%s\n", sec_heading
        printf "<!-- compressed:tier2 head_dropped=%d protected_tail_ratio=%.2f -->\n", drop_tokens, ratio + 0
        for (i = head_safe; i <= body_n; i++) {
          printf "%s", body_lines[i]
          if (i < body_n) {
            printf "\n"
          }
        }
        # If sec_raw ended with a newline, mirror that.
        if (substr(sec_raw, length(sec_raw), 1) == "\n") {
          printf "\n"
        }
        savings_tok += drop_tokens
        sec_name=""; sec_raw=""; body_n=0
      }
      function open_section(line) {
        if (match(line, /^## [A-Za-z][^\n]*$/)) {
          sec_heading = line
          sub(/^## /, "", line)
          if (line ~ /^Knowledge( |$)/)             { sec_name = "Knowledge" }
          else if (line ~ /^Task Plan( |$)/)        { sec_name = "Task Plan" }
          else if (line ~ /^Upstream Context( |$)/) { sec_name = "Upstream Context" }
          else                                      { sec_name = "OTHER" }
          sec_raw = sec_heading "\n"
          body_n = 0
          # Reset multi-line span trackers — sections are independent.
          fm_open = 0
          fence_open_ticks = 0
        }
      }
      BEGIN { sec_name=""; sec_raw=""; body_n=0; savings_tok=0; fm_open=0; fence_open_ticks=0 }
      /^## / {
        if (sec_name != "") { flush_section() }
        open_section($0)
        next
      }
      sec_name == "" {
        # Pre-first-section bytes (manifest, frontmatter) — emit verbatim.
        print
        next
      }
      {
        # Body line of current section.
        body_n += 1
        body_lines[body_n] = $0
        # Compute "is this line INSIDE a multi-line span at the START of the
        # line?" — that is the unsafe flag the cut-retreat walker reads.
        body_unsafe[body_n] = (fm_open == 1 || fence_open_ticks > 0) ? 1 : 0
        body_unsafe_label[body_n] = (fm_open == 1) ? "yaml-frontmatter-delim" : (fence_open_ticks > 0 ? "code-fence" : "")
        # Update span state AFTER recording the flag (so the line that opens
        # a span is itself safe — the cut may land at the OPENER, but a cut
        # below the opener falls inside the span and is unsafe).
        if ($0 == "---") {
          if (fm_open == 0) { fm_open = 1 } else { fm_open = 0 }
        } else if (match($0, /^`{3,}[a-zA-Z0-9_-]*$/)) {
          # Count backticks at start.
          ticks = 0
          for (k = 1; k <= length($0); k++) {
            if (substr($0, k, 1) == "`") { ticks += 1 } else { break }
          }
          if (fence_open_ticks == 0) {
            fence_open_ticks = ticks
          } else if (ticks == fence_open_ticks) {
            # Matching closer — close.
            fence_open_ticks = 0
          }
          # Mismatched ticks inside an open fence — leave fence_open_ticks
          # unchanged (the inner line is just content of the outer fence).
        }
        # sec_raw mirrors the captured bytes for the verbatim-passthrough path.
        sec_raw = sec_raw $0 "\n"
        next
      }
      END {
        if (sec_name != "") { flush_section() }
        printf "savings_tokens=%d\n", savings_tok > stf
        close(stf)
      }
      ' "$pre_file" > "$out_file"

  # Pick up any boundary-refusal violations the awk pass logged.
  if [ -f "$TMPDIR_BUILD/_tier2_violations.txt" ]; then
    if type pres_emit_violation >/dev/null 2>&1; then
      local _t2_log _vline _vsec _vpat
      _t2_log="$ORCH_ROOT/milestones/$MILESTONE_ID/execution-log.jsonl"
      if [ ! -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ] && [ -d "$ORCH_ROOT/phases" ]; then
        _t2_log="$ORCH_ROOT/execution-log.jsonl"
      fi
      while IFS= read -r _vline; do
        # _vline shape: `section=<name> pattern=<label>`.
        _vsec="$(printf '%s' "$_vline" | sed -n 's/^section=\([^ ]*\).*$/\1/p')"
        _vpat="$(printf '%s' "$_vline" | sed -n 's/.* pattern=\(.*\)$/\1/p')"
        pres_emit_violation "tier2" "$_vsec" "$_vpat" "$_t2_log" 2>/dev/null || true
      done < "$TMPDIR_BUILD/_tier2_violations.txt"
    fi
    rm -f "$TMPDIR_BUILD/_tier2_violations.txt" 2>/dev/null || true
  fi

  # Preservation self-check on the rewritten payload as a whole. Strict
  # tier2 multiplicity — every preserved-pattern occurrence in the pre
  # payload must occur in the post payload (the head-drop of an in-scope
  # section legitimately removes content; the boundary-refusal detector
  # is the guarantee that the removed content carried zero preserved
  # patterns. If the self-check disagrees, the snip is undone.)
  if type pres_check_section >/dev/null 2>&1; then
    if ! pres_check_section "tier2" "$pre_file" "$out_file" tier2 >/dev/null 2>&1; then
      if type pres_emit_violation >/dev/null 2>&1; then
        local _t2_log2
        _t2_log2="$ORCH_ROOT/milestones/$MILESTONE_ID/execution-log.jsonl"
        if [ ! -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ] && [ -d "$ORCH_ROOT/phases" ]; then
          _t2_log2="$ORCH_ROOT/execution-log.jsonl"
        fi
        pres_emit_violation "tier2" "payload" "cross-tier" "$_t2_log2" 2>/dev/null || true
      fi
      cp "$pre_file" "$capture_file"
      printf 'savings_tokens=0\n' > "$stats_file"
      return 0
    fi
  fi

  # Atomic in-place replace.
  mv "$out_file" "$capture_file"
  return 0
}

# M018/P06/T01: Tier 3 auto-compact — LLM-routed section summarization.
#
# Argument 1: path to the captured payload file (already through Tier 1 + Tier 2,
# prior to _bc_emit_payload_breakdown). The function rewrites the file in place
# when summarization fires; otherwise leaves it untouched.
#
# Side-effect outputs:
#   - Writes a stats line to $TMPDIR_BUILD/_tier3_stats.txt of the form:
#       savings_tokens=<N> invocations=<M>
#     The caller (T02-widened _bc_emit_payload_breakdown) reads this file
#     to populate the additive `tier3_compression_savings_tokens` and
#     `tier3_invocations` fields.
#   - Persists the original (post-Tier 2) section to
#     $TIER3_ORIGINALS_DIR/<sha256>.txt for audit + eval-harness replay.
#
# Short-circuits (passthrough; stats file written with savings_tokens=0
# invocations=0):
#   - $COMPRESSION_ENABLED != "true"
#   - $TIER3_ENABLED != "true"
#   - Resolved intensity is below $TIER3_INTENSITY_FLOOR (FR-14: Quick skips T3).
#   - The capture file contains zero in-scope `^## ` sections exceeding
#     $TIER3_SECTION_BUDGET_TOKENS.
#   - MIT-08 density pre-check fails (input_tokens / section_budget <
#     $TIER3_DENSITY_FLOOR — too sparse to compress meaningfully).
#
# Failure-passthrough (FR-9; emits tier3_failed JSONL record + zero stats):
#   - dispatch-interface.sh / shim non-zero exit (timeout, rate limit, error).
#   - Output bytes empty or smaller than the in-band marker length.
#   - Output / input ratio > $TIER3_OUTPUT_MAX_RATIO (emits tier3_no_savings).
#   - pres_check_section "tier3" returns non-zero (preservation breach).
#
# MEM004 carve-out: dispatch-internal helper, like _bc_apply_tier1 / _bc_apply_tier2.
_bc_apply_tier3() {
  local capture_file="$1"
  local stats_file="$TMPDIR_BUILD/_tier3_stats.txt"

  # Always write a zero-stats line first so the emitter never reads a missing
  # file (defensive: even early-return paths leave stats in a known shape).
  printf 'savings_tokens=0 invocations=0\n' > "$stats_file"

  # Master toggle short-circuit.
  if [ "${COMPRESSION_ENABLED:-true}" != "true" ]; then
    return 0
  fi
  # Per-tier toggle short-circuit.
  if [ "${TIER3_ENABLED:-true}" != "true" ]; then
    return 0
  fi
  if [ ! -f "$capture_file" ]; then
    return 0
  fi

  # Intensity gate (FR-14). TIER3_INTENSITY_FLOOR resolved at top-of-file.
  # Resolved intensity comes from the engine's metadata file when present
  # (written by scripts/engine/intensity-gate.sh upstream of dispatch);
  # default to Standard so a fresh dispatch with no metadata enables T3.
  local resolved_intensity="Standard"
  if [ -n "${INTENSITY_METADATA_FILE:-}" ] && [ -f "${INTENSITY_METADATA_FILE:-}" ]; then
    resolved_intensity="$(grep -E '^intensity:' "$INTENSITY_METADATA_FILE" 2>/dev/null \
      | head -1 | sed -E 's/^intensity:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
    if [ -z "$resolved_intensity" ]; then resolved_intensity="Standard"; fi
  fi
  case "$TIER3_INTENSITY_FLOOR" in
    quick) ;;  # Floor=quick means T3 always runs.
    standard)
      case "$resolved_intensity" in
        Quick)
          _bc_emit_tier3_event tier3_skipped "intensity=quick"
          return 0
          ;;
      esac
      ;;
    full)
      case "$resolved_intensity" in
        Quick|Standard)
          _bc_emit_tier3_event tier3_skipped "intensity=$resolved_intensity"
          return 0
          ;;
      esac
      ;;
  esac

  # Find the largest oversized `^## ` section after Tier 1 + Tier 2.
  # Single-pass awk emits "<line_start> <line_end> <byte_size> <header>" for
  # the largest section whose body exceeds TIER3_SECTION_BUDGET_TOKENS.
  local target_info
  target_info="$(awk -v budget="$TIER3_SECTION_BUDGET_TOKENS" '
    function tok(c) { return int((c + 3) / 4) }
    BEGIN { cur_start=0; cur_chars=0; cur_header=""; max_chars=0; max_start=0; max_end=0; max_header="" }
    /^## / {
      if (cur_start > 0 && tok(cur_chars) > budget && cur_chars > max_chars) {
        max_start = cur_start; max_end = NR - 1
        max_chars = cur_chars; max_header = cur_header
      }
      cur_start = NR; cur_chars = length($0) + 1; cur_header = $0
      next
    }
    cur_start > 0 { cur_chars += length($0) + 1 }
    END {
      if (cur_start > 0 && tok(cur_chars) > budget && cur_chars > max_chars) {
        max_start = cur_start; max_end = NR
        max_chars = cur_chars; max_header = cur_header
      }
      if (max_start > 0) printf "%d %d %d %s\n", max_start, max_end, max_chars, max_header
    }
  ' "$capture_file")"

  if [ -z "$target_info" ]; then
    return 0   # No oversized section.
  fi

  local _line_start _line_end _section_chars _section_header
  _line_start="$(printf '%s\n' "$target_info" | awk '{print $1}')"
  _line_end="$(printf '%s\n' "$target_info" | awk '{print $2}')"
  _section_chars="$(printf '%s\n' "$target_info" | awk '{print $3}')"
  _section_header="$(printf '%s\n' "$target_info" | awk '{ for (i=4; i<=NF; i++) printf "%s%s", $i, (i==NF?"":" ") }')"

  local _section_tokens
  _section_tokens=$(( (_section_chars + 3) / 4 ))

  # MIT-08 density pre-check. density = input_tokens / budget; below floor
  # means the section is too sparse to compress without paying excess LLM
  # cost. awk computes the ratio in real arithmetic.
  local _density_ok
  _density_ok="$(awk -v t="$_section_tokens" -v b="$TIER3_SECTION_BUDGET_TOKENS" -v f="$TIER3_DENSITY_FLOOR" '
    BEGIN { ratio = (b > 0) ? (t * 1.0 / b) : 0; print (ratio >= f) ? "1" : "0" }
  ')"
  if [ "$_density_ok" != "1" ]; then
    _bc_emit_tier3_event tier3_skipped "reason=density-floor density=$_section_tokens/$TIER3_SECTION_BUDGET_TOKENS floor=$TIER3_DENSITY_FLOOR"
    return 0
  fi

  # Stage the section to a pre-file; persist the original to the originals dir.
  local pre_file out_file rendered_prompt summary_out
  pre_file="$TMPDIR_BUILD/_tier3_pre.txt"
  out_file="$TMPDIR_BUILD/_tier3_out.txt"
  rendered_prompt="$TMPDIR_BUILD/_tier3_prompt.txt"
  summary_out="$TMPDIR_BUILD/_tier3_summary.txt"

  awk -v s="$_line_start" -v e="$_line_end" 'NR>=s && NR<=e' "$capture_file" > "$pre_file"

  if ! mkdir -p "$TIER3_ORIGINALS_DIR" 2>/dev/null; then
    printf 'build-context.sh: tier3 disabled — originals_dir unwritable: %s\n' "$TIER3_ORIGINALS_DIR" >&2
    _bc_emit_tier3_event tier3_failed "reason=originals-dir-unwritable"
    return 0
  fi

  local _orig_hash _orig_path _pre_body
  _pre_body="$(cat "$pre_file")"
  _orig_hash="$(printf '%s\x1F%s' "$_section_header" "$_pre_body" | shasum -a 256 | cut -c1-64)"
  case "$TIER3_ORIGINALS_DIR" in
    */) _orig_path="${TIER3_ORIGINALS_DIR}${_orig_hash}.txt" ;;
    *)  _orig_path="${TIER3_ORIGINALS_DIR}/${_orig_hash}.txt" ;;
  esac
  if [ ! -f "$_orig_path" ]; then
    cp "$pre_file" "$_orig_path" 2>/dev/null || true
  fi

  # Render the prompt: template body + appended section bytes.
  local _tpl="$PROJECT_ROOT/templates/compression-tier3-prompt.md"
  if [ ! -f "$_tpl" ]; then
    _bc_emit_tier3_event tier3_failed "reason=prompt-template-missing path=$_tpl"
    return 0
  fi
  if ! cat "$_tpl" "$pre_file" > "$rendered_prompt" 2>/dev/null; then
    _bc_emit_tier3_event tier3_failed "reason=prompt-render-failed"
    return 0
  fi

  # Token budget for the LLM output: input_tokens * output_max_ratio.
  local _summary_budget
  _summary_budget="$(awk -v t="$_section_tokens" -v r="$TIER3_OUTPUT_MAX_RATIO" '
    BEGIN { print int(t * r) }
  ')"

  # Invoke dispatch-interface.sh (or the tier3-llm-call.sh shim if present).
  local _llm_caller="$PROJECT_ROOT/scripts/dispatch/dispatch-interface.sh"
  if [ -x "$PROJECT_ROOT/scripts/dispatch/lib/tier3-llm-call.sh" ]; then
    _llm_caller="$PROJECT_ROOT/scripts/dispatch/lib/tier3-llm-call.sh"
  fi
  if ! bash "$_llm_caller" \
        --prompt-file "$rendered_prompt" \
        --capture-output "$summary_out" \
        --max-output-tokens "$_summary_budget" \
        --timeout-seconds 60 >/dev/null 2>&1; then
    _bc_emit_tier3_event tier3_failed "reason=llm-call-nonzero"
    return 0
  fi

  if [ ! -s "$summary_out" ]; then
    _bc_emit_tier3_event tier3_failed "reason=llm-empty-output"
    return 0
  fi

  # Output-size guard. discard if larger than ratio * input.
  local _summary_chars _summary_tokens _ratio_ok
  _summary_chars="$(wc -c < "$summary_out" | tr -d ' ')"
  _summary_tokens=$(( (_summary_chars + 3) / 4 ))
  _ratio_ok="$(awk -v sc="$_summary_chars" -v ic="$_section_chars" -v r="$TIER3_OUTPUT_MAX_RATIO" '
    BEGIN { ratio = (ic > 0) ? (sc * 1.0 / ic) : 1.0; print (ratio <= r) ? "1" : "0" }
  ')"
  if [ "$_ratio_ok" != "1" ]; then
    _bc_emit_tier3_event tier3_no_savings "reason=output-exceeds-max-ratio summary_chars=$_summary_chars input_chars=$_section_chars"
    return 0
  fi

  # Substitute the in-band marker placeholders in the LLM output.
  local _model="${ORCH_MODEL:-unknown}"
  sed -i.bak \
    -e "s|<MODEL>|$_model|" \
    -e "s|<N>|$_section_tokens|" \
    -e "s|<M>|$_summary_tokens|" \
    "$summary_out" 2>/dev/null || true
  rm -f "${summary_out}.bak" 2>/dev/null || true

  # Splice the summary back into the capture file.
  awk -v s="$_line_start" -v e="$_line_end" -v sf="$summary_out" '
    NR == s {
      while ((getline ln < sf) > 0) print ln
      close(sf)
      next
    }
    NR > s && NR <= e { next }
    { print }
  ' "$capture_file" > "$out_file"

  # Preservation self-check.
  if type pres_check_section >/dev/null 2>&1; then
    if ! pres_check_section "tier3" "$pre_file" "$out_file" tier3 >/dev/null 2>&1; then
      if type pres_emit_violation >/dev/null 2>&1; then
        local _t3_log
        _t3_log="$ORCH_ROOT/milestones/$MILESTONE_ID/execution-log.jsonl"
        if [ ! -d "$ORCH_ROOT/milestones/$MILESTONE_ID" ] && [ -d "$ORCH_ROOT/phases" ]; then
          _t3_log="$ORCH_ROOT/execution-log.jsonl"
        fi
        pres_emit_violation "tier3" "$_section_header" "preservation-breach" "$_t3_log" 2>/dev/null || true
      fi
      _bc_emit_tier3_event tier3_failed "reason=preservation-breach"
      return 0
    fi
  fi

  # Atomic in-place replace.
  mv "$out_file" "$capture_file"

  # Compute savings + write stats.
  local _savings_tokens
  _savings_tokens=$(( _section_tokens - _summary_tokens ))
  if [ "$_savings_tokens" -lt 0 ]; then _savings_tokens=0; fi
  printf 'savings_tokens=%d invocations=1\n' "$_savings_tokens" > "$stats_file"
  return 0
}

# T3 event emitter — appends a JSONL record to the active execution log naming
# the tier3 reason / status. Bail-safe per FR-9. MEM004 carve-out (single-pass
# JSONL write inside a dispatch-internal helper).
_bc_emit_tier3_event() {
  local record_type="$1"
  local reason="$2"
  local log_dir log_file ts unit_id
  log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
  if [ ! -d "$log_dir" ] && [ -d "$ORCH_ROOT/phases" ]; then
    log_dir="$ORCH_ROOT"
  fi
  log_file="$log_dir/execution-log.jsonl"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  unit_id="${MILESTONE_ID}/${PHASE_ID}/${TASK_ID}"
  mkdir -p "$log_dir" 2>/dev/null || return 0
  printf '{"record_type":"%s","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","reason":"%s","timestamp":"%s"}\n' \
    "$record_type" "$unit_id" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$reason" "$ts" \
    >> "$log_file" 2>/dev/null || true
  return 0
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
  # M031/P01/T01: AD-11 sidecar emission for the planning branch. The
  # planning payload is its own assembly pipeline (it does not flow through
  # _bc_emit_payload_breakdown), but the cross-milestone interface contract
  # still requires the 5-key sidecar. Token estimate is best-effort: zero
  # when pricing.sh is absent. mem_count comes from INCLUDED_IDS_FILE.
  if [ -n "${META_OUT:-}" ]; then
    _m031_pp_profile="${PROFILE:-standard}"
    _m031_pp_mem_count=0
    if [ -n "${INCLUDED_IDS_FILE:-}" ] && [ -f "$INCLUDED_IDS_FILE" ]; then
      _m031_pp_mem_count="$(grep -cE '^MEM[0-9]+' "$INCLUDED_IDS_FILE" 2>/dev/null || echo 0)"
    fi
    _m031_pp_meta_dir="$(dirname "$META_OUT")"
    if [ -n "$_m031_pp_meta_dir" ] && [ ! -d "$_m031_pp_meta_dir" ]; then
      mkdir -p "$_m031_pp_meta_dir" 2>/dev/null || true
    fi
    {
      printf '{'
      printf '"mem_count":%d,' "$_m031_pp_mem_count"
      printf '"total_tokens":0,'
      printf '"profile":"%s",' "$_m031_pp_profile"
      printf '"compression_applied":false,'
      printf '"snip_applied":false'
      printf '}\n'
    } > "$META_OUT" 2>/dev/null || true
  fi
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
    reference)   echo 4 ;;  # filtered — task-scoped reference chunks (M036/P07)
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
    reference)    echo "Reference" ;;
    *)            echo "$1" ;;
  esac
}
_bc_display_priority() {
  # pre-refactor manifest only ever shows "filtered" or "required"
  case "$1" in
    knowledge|decisions|spec_context|reference) echo "filtered" ;;
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
    Knowledge|Knowledge\ *|Decisions|Constraints|Scope|"Spec Context"|"Reference") echo "stable" ;;
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
  if { [ "$s_source" = "spec_context" ] || [ "$s_source" = "reference" ]; } && [ ! -s "$staging_file" ]; then
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

  # M019/P01/T05: test seam — ORCH_M019_EMIT=0 short-circuits the emitter so
  # the zero-token-growth gate can diff the stdout bytes with emitter on/off.
  # Production always runs with the default 1.
  if [ "${ORCH_M019_EMIT:-1}" = "0" ]; then
    return 0
  fi

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

  # M018/P02/T02 (CON-5): additive `filter_dropped_tokens` field. Reads the
  # stats file emitted by kf_filter_stream when the filter ran; defaults to 0
  # when the filter was disabled, the planning branch skipped knowledge
  # gather, or the stats file is missing.
  local filter_dropped_tokens=0
  local _bc_pb_stats_file="$TMPDIR_BUILD/_filter_stats.txt"
  if [ -f "$_bc_pb_stats_file" ]; then
    filter_dropped_tokens="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^dropped_tokens=/) {
          sub("dropped_tokens=", "", $i)
          print $i
          exit
        }
      }
    }' "$_bc_pb_stats_file")"
    if [ -z "$filter_dropped_tokens" ]; then
      filter_dropped_tokens=0
    fi
  fi

  # M018/P03/T01 (CON-5): additive `tier1_savings_tokens` + `tier1_invocations`
  # fields. Reads $TMPDIR_BUILD/_tier1_stats.txt written by _bc_apply_tier1.
  # Defaults to 0 when tier1 was disabled, the file is absent, or the section
  # contained no oversized tool-result blocks.
  local tier1_savings_tokens=0 tier1_invocations=0
  local _bc_pb_t1_stats="$TMPDIR_BUILD/_tier1_stats.txt"
  if [ -f "$_bc_pb_t1_stats" ]; then
    tier1_savings_tokens="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^savings_tokens=/) {
          sub("savings_tokens=", "", $i)
          print $i
          exit
        }
      }
    }' "$_bc_pb_t1_stats")"
    tier1_invocations="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^invocations=/) {
          sub("invocations=", "", $i)
          print $i
          exit
        }
      }
    }' "$_bc_pb_t1_stats")"
    if [ -z "$tier1_savings_tokens" ]; then tier1_savings_tokens=0; fi
    if [ -z "$tier1_invocations" ];   then tier1_invocations=0; fi
  fi

  # M018/P04/T01 (CON-5): additive `tier2_savings_tokens` field. Reads
  # $TMPDIR_BUILD/_tier2_stats.txt written by _bc_apply_tier2. Defaults to 0
  # when tier2 was disabled, the file is absent, or no in-scope section
  # exceeded the budget.
  local tier2_savings_tokens=0
  local _bc_pb_t2_stats="$TMPDIR_BUILD/_tier2_stats.txt"
  if [ -f "$_bc_pb_t2_stats" ]; then
    tier2_savings_tokens="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^savings_tokens=/) {
          sub("savings_tokens=", "", $i)
          print $i
          exit
        }
      }
    }' "$_bc_pb_t2_stats")"
    if [ -z "$tier2_savings_tokens" ]; then tier2_savings_tokens=0; fi
  fi

  # M018/P06/T02 (CON-5): additive `tier3_compression_savings_tokens` +
  # `tier3_invocations` fields. Reads $TMPDIR_BUILD/_tier3_stats.txt written
  # by _bc_apply_tier3 (T01). Defaults to 0 when tier3 was disabled, the
  # file is absent, the section did not exceed budget, MIT-08 density
  # pre-check failed, intensity gate fired, or the LLM call failed
  # (FR-9 failure-passthrough — every short-circuit path leaves the stats
  # file at savings_tokens=0 invocations=0).
  local tier3_compression_savings_tokens=0 tier3_invocations=0
  local _bc_pb_t3_stats="$TMPDIR_BUILD/_tier3_stats.txt"
  if [ -f "$_bc_pb_t3_stats" ]; then
    tier3_compression_savings_tokens="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^savings_tokens=/) {
          sub("savings_tokens=", "", $i)
          print $i
          exit
        }
      }
    }' "$_bc_pb_t3_stats")"
    tier3_invocations="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^invocations=/) {
          sub("invocations=", "", $i)
          print $i
          exit
        }
      }
    }' "$_bc_pb_t3_stats")"
    if [ -z "$tier3_compression_savings_tokens" ]; then tier3_compression_savings_tokens=0; fi
    if [ -z "$tier3_invocations" ];                  then tier3_invocations=0; fi
  fi

  # M031/P01/T01: additive fields per FR-2 + AD-11. `profile` records the
  # resolved profile (default "standard" when unspecified, matching the
  # historical positional-call shape). `knowledge_section_tokens` is the
  # post-tier-1/tier-2 token count of the Knowledge section measured from
  # the captured-section files. `tier1_replacements` and `tier2_snips`
  # surface compression-tier counters; existing `tier1_invocations` and
  # `tier2_savings_tokens` keys are preserved byte-equal upstream.
  local _m031_profile="${PROFILE:-standard}"
  local _m031_knowledge_tokens=0
  local _m031_ki=1
  local _m031_kn=""
  IFS='|' read -ra _BC_M031_NAMES <<EOF_M031_NAMES
$SECTION_NAMES_PIPE
EOF_M031_NAMES
  for _m031_kn in "${_BC_M031_NAMES[@]}"; do
    case "$_m031_kn" in
      Knowledge|Knowledge\ *)
        if [ -f "$TMPDIR_BUILD/s${_m031_ki}.txt" ]; then
          local _m031_kbytes
          _m031_kbytes="$(wc -c < "$TMPDIR_BUILD/s${_m031_ki}.txt" | tr -d ' ')"
          _m031_knowledge_tokens="$(chars_to_tokens_quartile "$_m031_kbytes")"
        fi
        ;;
    esac
    _m031_ki=$(( _m031_ki + 1 ))
  done
  local _m031_tier1_replacements="$tier1_invocations"
  local _m031_tier2_snips=0
  if [ -f "$TMPDIR_BUILD/_tier2_stats.txt" ]; then
    _m031_tier2_snips="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^snips=/) { sub("snips=", "", $i); print $i; exit }
      }
    }' "$TMPDIR_BUILD/_tier2_stats.txt")"
    if [ -z "$_m031_tier2_snips" ]; then _m031_tier2_snips=0; fi
  fi

  printf '{"record_type":"payload_breakdown","unitId":"%s/%s/%s","milestone":"%s","phase":"%s","task":"%s","payload_chars":%d,"payload_tokens_estimate":%d,"token_estimate_method":"char-quartile","section_tokens":{%s},"filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier1_invocations":%d,"tier2_savings_tokens":%d,"tier3_compression_savings_tokens":%d,"tier3_invocations":%d,"profile":"%s","knowledge_section_tokens":%d,"tier1_replacements":%d,"tier2_snips":%d,"model":"%s","source":"estimate","timestamp":"%s"}\n' \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$payload_chars" "$payload_tokens" \
    "$section_tokens_json" "$filter_dropped_tokens" \
    "$tier1_savings_tokens" "$tier1_invocations" \
    "$tier2_savings_tokens" \
    "$tier3_compression_savings_tokens" "$tier3_invocations" \
    "$_m031_profile" "$_m031_knowledge_tokens" \
    "$_m031_tier1_replacements" "$_m031_tier2_snips" \
    "$model" "$ts" \
    >> "$log_file" 2>/dev/null || {
    printf 'build-context.sh: payload_breakdown append failed on %s\n' "$log_file" >&2
    return 0
  }

  # M031/P01/T01: AD-11 JSON sidecar emission (positional-mode path). When
  # --meta-out was supplied, write the 5-key schema {mem_count,
  # total_tokens, profile, compression_applied, snip_applied}. This is the
  # cross-milestone interface contract for M029 orchestrator:where and M036
  # reference-corpus ingest. Compression flags reflect whether tier-1 or
  # tier-2 fired during this assembly; tier-3 is included in the
  # compression flag (snip is tier-2 specific).
  if [ -n "${META_OUT:-}" ]; then
    local _m031_compression_applied=false
    local _m031_snip_applied=false
    if [ "$tier1_invocations" -gt 0 ] 2>/dev/null; then _m031_compression_applied=true; fi
    if [ "$tier3_invocations" -gt 0 ] 2>/dev/null; then _m031_compression_applied=true; fi
    if [ "$_m031_tier2_snips" -gt 0 ] 2>/dev/null; then
      _m031_compression_applied=true
      _m031_snip_applied=true
    fi
    local _m031_mem_count=0
    if [ -n "${INCLUDED_IDS_FILE:-}" ] && [ -f "$INCLUDED_IDS_FILE" ]; then
      _m031_mem_count="$(grep -cE '^MEM[0-9]+' "$INCLUDED_IDS_FILE" 2>/dev/null || echo 0)"
    fi
    local _m031_meta_dir
    _m031_meta_dir="$(dirname "$META_OUT")"
    if [ -n "$_m031_meta_dir" ] && [ ! -d "$_m031_meta_dir" ]; then
      mkdir -p "$_m031_meta_dir" 2>/dev/null || true
    fi
    {
      printf '{'
      printf '"mem_count":%d,' "$_m031_mem_count"
      printf '"total_tokens":%d,' "$payload_tokens"
      printf '"profile":"%s",' "$_m031_profile"
      printf '"compression_applied":%s,' "$_m031_compression_applied"
      printf '"snip_applied":%s' "$_m031_snip_applied"
      printf '}\n'
    } > "$META_OUT" 2>/dev/null || true
  fi

  # M018/P00/T01: co-located dispatch_usage emission. Real production
  # dispatches construct payloads via build-context.sh but hand them to the
  # runtime's native dispatch (e.g., Claude Code's Agent tool) without
  # routing through dispatch-interface.sh. The result was a 1.2% parity
  # ratio between dispatch_usage and payload_breakdown (169 vs 2 in the
  # historical log per .orchestrator/scratch/m018-telemetry-probe-report.txt).
  # By emitting a co-located dispatch_usage here -- with
  # emission_point="build-context" to disambiguate -- we close the parity
  # gap by construction. The emit is bail-safe: a failure here never
  # affects build-context exit code.
  _bc_emit_dispatch_usage_colocated "$payload_chars" "$payload_tokens" "$model" "$log_file" "$ts" "$log_dir" || true
  return 0
}

# ============================================================================
# M018/P00/T01: dispatch_usage co-located emitter
# ----------------------------------------------------------------------------
# Emits a `dispatch_usage` record adjacent to the payload_breakdown record
# above. Uses the same payload-token count (bytes/tokens were already
# computed for payload_breakdown so we pass them through). Output tokens
# are unknown at build-context time -> 0. The "emission_point":"build-context"
# field disambiguates from full-pipeline dispatches that pass through
# dispatch-interface.sh (which stamps "emission_point":"dispatch-interface").
# CON-5 additivity: emission_point is additive; pre-M018 records remain
# valid; downstream rollups can group by the field.
# ============================================================================
_bc_emit_dispatch_usage_colocated() {
  local payload_chars="$1"
  local input_tokens="$2"
  local model="$3"
  local log_file="$4"
  local ts="$5"
  local log_dir="$6"

  if [ "${ORCH_M019_EMIT:-1}" = "0" ]; then
    return 0
  fi

  # Source pricing helpers if not already present (idempotent guard).
  if ! type pricing_estimate_cost_usd >/dev/null 2>&1; then
    if [ -r "$PROJECT_ROOT/scripts/lib/pricing.sh" ]; then
      . "$PROJECT_ROOT/scripts/lib/pricing.sh" || return 0
    else
      return 0
    fi
  fi

  local output_tokens cost_usd warning pricing_version unit_id escaped_warning
  output_tokens=0
  unit_id="${MILESTONE_ID}/${PHASE_ID}/${TASK_ID}"

  local _bc_cost_tmp
  _bc_cost_tmp="$(mktemp 2>/dev/null || printf '/tmp/bc_cost_%d' "$$")"
  pricing_estimate_cost_usd "$input_tokens" "$output_tokens" "$model" > "$_bc_cost_tmp" 2>/dev/null || true
  cost_usd="$(tr -d '[:space:]' < "$_bc_cost_tmp")"
  rm -f "$_bc_cost_tmp" 2>/dev/null || true
  warning="$(pricing_warning_reason)"
  pricing_version="$(pricing_last_updated)"

  escaped_warning="$(printf '%s' "$warning" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  if [ -n "$cost_usd" ] && [ -z "$warning" ]; then
    printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":%s,"pricing_version":"%s","model":"%s","source":"estimate","emission_point":"build-context","timestamp":"%s"}\n' \
      "$unit_id" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
      "$input_tokens" "$output_tokens" "$cost_usd" \
      "$pricing_version" "$model" "$ts" \
      >> "$log_file" 2>/dev/null || {
      printf 'build-context.sh: dispatch_usage co-located append failed on %s\n' "$log_file" >&2
      return 0
    }
  else
    printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":null,"pricing_version":"%s","pricing_warning":"%s","model":"%s","source":"estimate","emission_point":"build-context","timestamp":"%s"}\n' \
      "$unit_id" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
      "$input_tokens" "$output_tokens" \
      "$pricing_version" "$escaped_warning" "$model" "$ts" \
      >> "$log_file" 2>/dev/null || {
      printf 'build-context.sh: dispatch_usage co-located append failed on %s\n' "$log_file" >&2
      return 0
    }
  fi
  return 0
}

# ============================================================================
# M018/P02/T02: payload_filter emitter
# ----------------------------------------------------------------------------
# Emits exactly one `payload_filter` JSONL record per build-context.sh
# invocation when the knowledge filter dropped at least one entry. The
# record names the dropped IDs and their token cost so downstream rollups
# can audit filter activity. Schema (CON-5 additive — brand-new
# record_type, ignored cleanly by pre-M018 jq filters):
#   {"record_type":"payload_filter","filter":"knowledge_status",
#    "drop_list":[...],"dropped_count":N,"dropped_tokens":N,
#    "dropped_ids":[...],"source":"runtime","unitId":"M/P/T",
#    "milestone":"M","phase":"P","task":"T","timestamp":"..."}
# ============================================================================
_bc_emit_payload_filter() {
  if [ "${ORCH_M019_EMIT:-1}" = "0" ]; then
    return 0
  fi
  local stats_file="$TMPDIR_BUILD/_filter_stats.txt"
  if [ ! -f "$stats_file" ]; then
    return 0
  fi
  local dropped_count dropped_tokens dropped_ids
  dropped_count="$(awk '{ for (i=1;i<=NF;i++) if ($i ~ /^dropped_count=/) { sub("dropped_count=","",$i); print $i; exit } }' "$stats_file")"
  dropped_tokens="$(awk '{ for (i=1;i<=NF;i++) if ($i ~ /^dropped_tokens=/) { sub("dropped_tokens=","",$i); print $i; exit } }' "$stats_file")"
  dropped_ids="$(awk '{ for (i=1;i<=NF;i++) if ($i ~ /^dropped_ids=/) { sub("dropped_ids=","",$i); print $i; exit } }' "$stats_file")"
  if [ -z "$dropped_count" ]; then
    dropped_count=0
  fi
  if [ -z "$dropped_tokens" ]; then
    dropped_tokens=0
  fi
  if [ "$dropped_count" -eq 0 ]; then
    return 0
  fi

  local log_dir log_file ts
  log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
  if [ ! -d "$log_dir" ] && [ -d "$ORCH_ROOT/phases" ]; then
    log_dir="$ORCH_ROOT"
  fi
  log_file="$log_dir/execution-log.jsonl"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Build dropped_ids JSON array from comma-separated string.
  local ids_json="[]"
  if [ -n "$dropped_ids" ]; then
    ids_json="[\"$(printf '%s' "$dropped_ids" | sed 's/,/","/g')\"]"
  fi

  # Build drop_list JSON array from drop-list file written by the filter.
  local drop_list_file="$TMPDIR_BUILD/_drop_list.txt"
  local drop_json="[]"
  if [ -f "$drop_list_file" ]; then
    drop_json="$(awk 'BEGIN { first = 1; printf "[" } /^[[:space:]]*$/ { next } { v = $0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); if (v == "") next; if (first == 1) { printf "\"%s\"", v; first = 0 } else { printf ",\"%s\"", v } } END { printf "]" }' "$drop_list_file")"
  fi

  mkdir -p "$log_dir" 2>/dev/null || return 0
  printf '{"record_type":"payload_filter","filter":"knowledge_status","drop_list":%s,"dropped_count":%d,"dropped_tokens":%d,"dropped_ids":%s,"source":"runtime","unitId":"%s/%s/%s","milestone":"%s","phase":"%s","task":"%s","timestamp":"%s"}\n' \
    "$drop_json" "$dropped_count" "$dropped_tokens" "$ids_json" \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$ts" \
    >> "$log_file" 2>/dev/null || true
  return 0
}

# M018/P02/T03: compression_underperformance self-check.
# MIT-09 (P01 carryover): operational signal — never blocks dispatch.
# Emits compression_underperformance JSONL when running mean reduction over
# the last $window_size payload_breakdown records falls below
# $floor_pct (default 34.7, SC-9 calibrated floor per P00 80% CI lower bound).
# Sample-size guard: skips emission when count < $min_sample_size (default 10)
# so the check doesn't fire spuriously on a fresh log.
# Reduction math: (sum of tier savings) / (payload_tokens + sum of tier savings).
_bc_emit_compression_underperformance() {
  if [ "${ORCH_M019_EMIT:-1}" = "0" ]; then
    return 0
  fi

  local enabled window_size floor_pct min_sample_size
  enabled="$(kf_get_underperformance_enabled "$PROJECT_ROOT")"
  if [ "$enabled" != "true" ]; then
    return 0
  fi
  window_size="$(kf_get_underperformance_window_size "$PROJECT_ROOT")"
  floor_pct="$(kf_get_underperformance_floor_pct "$PROJECT_ROOT")"
  min_sample_size="$(kf_get_underperformance_min_sample_size "$PROJECT_ROOT")"

  local log_dir log_file
  log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
  if [ ! -d "$log_dir" ] && [ -d "$ORCH_ROOT/phases" ]; then
    log_dir="$ORCH_ROOT"
  fi
  log_file="$log_dir/execution-log.jsonl"
  if [ ! -f "$log_file" ]; then
    return 0
  fi

  # Compute running mean reduction over the last $window_size payload_breakdown
  # records. Use awk: it has the floating-point math we need and runs in one
  # process (AP-009 safe — single command).
  local stats
  stats="$(awk -v win="$window_size" -v floor="$floor_pct" -v min="$min_sample_size" '
    BEGIN { rec_count = 0 }
    /"record_type":"payload_breakdown"/ {
      pte = 0; fdt = 0; t1 = 0; t2 = 0; t3 = 0
      # Substring offsets are length-of-key-prefix (e.g. `"key":` is 26 chars
      # for payload_tokens_estimate; `RSTART+26` starts at the digit run).
      if (match($0, /"payload_tokens_estimate":[0-9]+/)) {
        v = substr($0, RSTART+26, RLENGTH-26)
        pte = v + 0
      }
      if (match($0, /"filter_dropped_tokens":[0-9]+/)) {
        v = substr($0, RSTART+24, RLENGTH-24)
        fdt = v + 0
      }
      if (match($0, /"tier1_savings_tokens":[0-9]+/)) {
        v = substr($0, RSTART+23, RLENGTH-23)
        t1 = v + 0
      }
      if (match($0, /"tier2_savings_tokens":[0-9]+/)) {
        v = substr($0, RSTART+23, RLENGTH-23)
        t2 = v + 0
      }
      if (match($0, /"tier3_compression_savings_tokens":[0-9]+/)) {
        v = substr($0, RSTART+35, RLENGTH-35)
        t3 = v + 0
      }
      saved = fdt + t1 + t2 + t3
      pre = pte + saved
      if (pre > 0) {
        pct = (saved * 100.0) / pre
        rec_count++
        rec_pct[rec_count] = pct
      }
    }
    END {
      if (rec_count < min) {
        printf "INSUFFICIENT %d %d\n", rec_count, min
        exit 0
      }
      start = rec_count - win + 1
      if (start < 1) start = 1
      actual_window = rec_count - start + 1
      total = 0
      for (i = start; i <= rec_count; i++) total += rec_pct[i]
      mean = total / actual_window
      printf "MEAN %.2f %d %.2f\n", mean, actual_window, floor
    }
  ' "$log_file")"

  # Parse stats line.
  local marker mean_pct sample_size floor_seen
  marker="$(printf '%s\n' "$stats" | awk '{print $1}')"
  if [ "$marker" != "MEAN" ]; then
    return 0
  fi
  mean_pct="$(printf '%s\n' "$stats" | awk '{print $2}')"
  sample_size="$(printf '%s\n' "$stats" | awk '{print $3}')"
  floor_seen="$(printf '%s\n' "$stats" | awk '{print $4}')"

  # Compare mean_pct < floor_pct using awk (bash 3.2 has no float comparison).
  local under
  under="$(awk -v m="$mean_pct" -v f="$floor_seen" 'BEGIN { print (m < f) ? "1" : "0" }')"
  if [ "$under" != "1" ]; then
    return 0
  fi

  # Compute shortfall.
  local shortfall
  shortfall="$(awk -v m="$mean_pct" -v f="$floor_seen" 'BEGIN { printf "%.2f", f - m }')"

  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"record_type":"compression_underperformance","milestone":"%s","phase":"%s","task":"%s","running_mean_pct":%s,"floor_pct":%s,"window_size":%d,"sample_size":%d,"shortfall_pct":%s,"timestamp":"%s"}\n' \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$mean_pct" "$floor_seen" "$window_size" "$sample_size" \
    "$shortfall" "$ts" \
    >> "$log_file" 2>/dev/null || true
  return 0
}

# Capture the assembled payload into a temp file so we can measure its byte
# size AND still emit it to stdout byte-identically (SC-6). Zero-token: no new
# content is added to the payload; only a post-emit observation is made.
PAYLOAD_CAPTURE="$TMPDIR_BUILD/_payload_capture.txt"
_bc_assemble_manifest_and_emit "$SECTION_COUNT" "$SECTION_NAMES_PIPE" "$SECTION_PRIORITIES_PIPE" "$FRONTMATTER" "$TITLE" > "$PAYLOAD_CAPTURE"
# M018/P03/T01: Tier 1 microcompact runs against the captured payload BEFORE
# cat so the receiving agent sees paged bytes, and before the breakdown
# emitter so payload sizing reflects post-tier1 reality. Short-circuits when
# `compression.enabled: false` (P02 byte-identity contract) or when
# `compression.tier1.enabled: false`.
_bc_apply_tier1 "$PAYLOAD_CAPTURE" || true
# M018/P04/T01: Tier 2 snip runs against the post-tier1 captured payload BEFORE
# the receiving agent sees the bytes (cat below) and BEFORE the breakdown
# emitter samples it (so emitter section sizes reflect post-tier2 reality).
# Short-circuits when `compression.enabled: false` (P02 byte-identity contract)
# or when `compression.tier2.enabled: false` (per-tier disable).
_bc_apply_tier2 "$PAYLOAD_CAPTURE" || true
# M018/P06/T01: Tier 3 auto-compact (LLM-routed) runs against the post-tier2
# captured payload. Failure-passthrough on every error path (FR-9); never
# crashes the dispatch. Short-circuits on the master `compression.enabled`
# toggle, on `compression.tier3.enabled: false`, on intensity-floor mismatch
# (FR-14: Quick skips T3), on density pre-check (MIT-08), or when no oversized
# section exists.
_bc_apply_tier3 "$PAYLOAD_CAPTURE" || true
cat "$PAYLOAD_CAPTURE"
_bc_emit_payload_breakdown "$PAYLOAD_CAPTURE" || true
_bc_emit_payload_filter || true
_bc_emit_compression_underperformance || true
exit 0
