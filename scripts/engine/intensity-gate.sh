#!/usr/bin/env bash
# scripts/engine/intensity-gate.sh — Stage-level intensity gate.
#
# Given a pipeline stage and an intensity level, emit the set of
# substeps to execute and the set to skip. The matrix is hardcoded
# here to guarantee a single source of truth across all command docs
# (discuss, research, plan-phase, dispatch, verify, knowledge, auto).
#
# Usage:
#   intensity-gate.sh --stage <name> --intensity <Quick|Standard|Full>
#   intensity-gate.sh --stage <name> --intensity-metadata <path-to-md>
#
# Output (stdout, key=value):
#   execute_substeps=<csv>
#   skip_substeps=<csv>
#
# Exit: 0 success, 1 invalid arguments, 2 unknown stage/intensity.
# Bash 3.2 compatible (NFR-200, MEM001).

set -u

STAGE=""
INTENSITY=""
METADATA_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage)
      STAGE="${2:-}"; shift 2 ;;
    --intensity)
      INTENSITY="${2:-}"; shift 2 ;;
    --intensity-metadata)
      METADATA_FILE="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

if [[ -z "$STAGE" ]]; then
  echo "ERROR: --stage is required" >&2
  exit 1
fi

# Resolve intensity from metadata file if --intensity not given
if [[ -z "$INTENSITY" ]] && [[ -n "$METADATA_FILE" ]]; then
  if [[ ! -f "$METADATA_FILE" ]]; then
    echo "ERROR: metadata file not found: $METADATA_FILE" >&2
    exit 1
  fi
  INTENSITY="$(grep -E '^intensity:' "$METADATA_FILE" | head -n 1 | sed -E 's/^intensity:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
fi

if [[ -z "$INTENSITY" ]]; then
  echo "ERROR: --intensity or --intensity-metadata required" >&2
  exit 1
fi

# Normalize intensity to canonical Title-Case. Accept any case from operator
# input, config.yml (lowercase convention), or upstream commands (Title-Case
# convention). Convention-divergence between the two surfaces is itself the
# friction this gate's caller hits — see PBJ Stage 3 dogfood, 2026-05-08.
case "$(printf '%s' "$INTENSITY" | tr '[:upper:]' '[:lower:]')" in
  quick)    INTENSITY="Quick" ;;
  standard) INTENSITY="Standard" ;;
  full)     INTENSITY="Full" ;;
  *)
    echo "ERROR: unknown intensity '$INTENSITY' (expected quick|standard|full)" >&2
    exit 2 ;;
esac

# --- P00/L3 Adaptive Thinking Contract (Opus 4.7) ---
# The intensity gate does NOT set a fixed reasoning allotment. Opus 4.7 uses
# adaptive thinking — the model decides per step how much reasoning to apply.
# Prompt-level nudges are the only lever: "think carefully; this is harder
# than it looks" for hard-effort tasks vs. "prioritize responding quickly"
# for easy-effort tasks. Intensity level (Quick/Standard/Full) affects which
# substeps execute, not how much reasoning is allocated per substep.

# --- Hardcoded stage x intensity matrix ---
# Substep vocabulary (stage-scoped; meaning documented in command docs):
#   discuss:    all | none | optional | required
#   research:   all | none | on-demand | pre-planning
#   plan-phase: single-task | basic-decomp | full-decomp, boundary-map
#   dispatch:   sequential | standard-payload | full-context, knowledge-inject
#   verify:     tier1 | tier2 | tier3 | tier4
#   knowledge:  summary | decision | graph-entry | rebuild-index
#   auto:       dispatch | no-pause | standard-pause | strict-pause | human-review

execute=""
skip=""

case "$STAGE" in
  discuss)
    case "$INTENSITY" in
      Quick)    execute="none";     skip="all" ;;
      Standard) execute="optional"; skip="none" ;;
      Full)     execute="required"; skip="none" ;;
    esac
    ;;
  research)
    case "$INTENSITY" in
      Quick)    execute="none";         skip="all" ;;
      Standard) execute="on-demand";    skip="pre-planning" ;;
      Full)     execute="pre-planning"; skip="none" ;;
    esac
    ;;
  plan-phase)
    case "$INTENSITY" in
      Quick)    execute="single-task";                  skip="boundary-map,full-decomp" ;;
      Standard) execute="basic-decomp,boundary-map";    skip="full-decomp" ;;
      Full)     execute="full-decomp,boundary-map";     skip="none" ;;
    esac
    ;;
  dispatch)
    case "$INTENSITY" in
      Quick)    execute="sequential";                        skip="standard-payload,full-context,knowledge-inject" ;;
      Standard) execute="standard-payload";                  skip="full-context,knowledge-inject" ;;
      Full)     execute="full-context,knowledge-inject";     skip="none" ;;
    esac
    ;;
  verify)
    case "$INTENSITY" in
      Quick)    execute="tier1";                   skip="tier2,tier3,tier4" ;;
      Standard) execute="tier1,tier2";             skip="tier3,tier4" ;;
      Full)     execute="tier1,tier2,tier3,tier4"; skip="none" ;;
    esac
    ;;
  knowledge)
    case "$INTENSITY" in
      Quick)    execute="summary";                                skip="decision,graph-entry,rebuild-index" ;;
      Standard) execute="summary,decision";                       skip="graph-entry,rebuild-index" ;;
      Full)     execute="summary,decision,graph-entry,rebuild-index"; skip="none" ;;
    esac
    ;;
  auto)
    case "$INTENSITY" in
      Quick)    execute="dispatch,no-pause";                    skip="standard-pause,strict-pause,human-review" ;;
      Standard) execute="dispatch,standard-pause";              skip="strict-pause,human-review" ;;
      Full)     execute="dispatch,strict-pause,human-review";   skip="no-pause" ;;
    esac
    ;;
  roadmap)
    # Substep vocabulary:
    #   single-pass | basic-decomp | rationale | collaborative-loop
    case "$INTENSITY" in
      Quick)    execute="single-pass";                          skip="basic-decomp,rationale,collaborative-loop" ;;
      Standard) execute="basic-decomp,rationale";               skip="collaborative-loop" ;;
      Full)     execute="basic-decomp,rationale,collaborative-loop"; skip="single-pass" ;;
    esac
    ;;
  ingest)
    # Substep vocabulary:
    #   normalize | fidelity-gate | force-chunker
    # Policy: Quick skips the fidelity gate (fast path);
    # Standard+ runs both normalize and fidelity-gate.
    # The --review flag on orchestrator:ingest promotes fidelity-gate
    # into execute_substeps regardless of resolved intensity; --no-review
    # forces it into skip_substeps. Those overrides are applied by the
    # calling command (commands/ingest.md), not by this gate.
    case "$INTENSITY" in
      Quick)    execute="normalize";               skip="fidelity-gate" ;;
      Standard) execute="normalize,fidelity-gate"; skip="none" ;;
      Full)     execute="normalize,fidelity-gate"; skip="none" ;;
    esac
    ;;
  *)
    echo "ERROR: unknown stage '$STAGE' (expected discuss|research|plan-phase|dispatch|verify|knowledge|auto|roadmap|ingest)" >&2
    exit 2
    ;;
esac

echo "execute_substeps=$execute"
echo "skip_substeps=$skip"
