#!/usr/bin/env bash
# scripts/dispatch/select-model.sh — Routing with fallback-chain support
[ -n "${_SELECT_MODEL_SOURCED:-}" ] && return 0
_SELECT_MODEL_SOURCED=1
#
# Maps a complexity tier to a model ID + context budget using
# templates/routing.yaml, with optional fallback-chain lookups for
# engine retry-on-failure. Implements FR-213 + US10.
#
# Usage:
#   select-model.sh <tier> [--routing-config <file>]
#       → default: print "<model-id> <context-budget>"
#   select-model.sh <tier> [--routing-config <file>] --list-fallback
#       → print comma-separated fallback chain (or empty string)
#   select-model.sh <tier> [--routing-config <file>] --next-fallback <current-model-id>
#       → print the next model in the chain after <current-model-id>,
#         or exit 1 if the chain is exhausted / current is unknown.
#
# Arguments:
#   tier:              heavy | standard | light
#   --routing-config:  optional path to routing.yaml
#   --list-fallback:   print the fallback chain for the tier
#   --next-fallback:   walk the chain from <current-model-id>
#
# Output contract (default mode): "<model-id> <context-budget>" on stdout.
# Output contract (list):         "<model1>,<model2>,..." on stdout.
# Output contract (next):         "<next-model-id>" on stdout, or exit 1.
# Stderr: one RESULT: line + EVENT: lines.
#
# When no routing config is provided or the file is missing, returns the
# built-in defaults (heavy → opus, standard → sonnet, light → haiku).
#
# Bash 3.2 compatible. Standalone-capable. No jq.
# Constitution: Principle X (Templating Over Inference).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=/dev/null
. "$PROJECT_ROOT/scripts/lib/errors.sh"
# shellcheck source=/dev/null
. "$PROJECT_ROOT/scripts/lib/events.sh"
# shellcheck source=/dev/null
. "$PROJECT_ROOT/scripts/lib/run-context.sh"
# shellcheck source=/dev/null
. "$PROJECT_ROOT/scripts/lib/recipe-parser.sh"

# --- Result emission on exit (stderr, not stdout) ---
_SM_RESULT_EMITTED=0
_sm_final_result() {
  local rc=$?
  if [ "$_SM_RESULT_EMITTED" -eq 0 ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "model selection ok" >&2
    else
      emit_result error DISPATCH "select-model rc=$rc" >&2
    fi
    _SM_RESULT_EMITTED=1
  fi
}
trap _sm_final_result EXIT

# --- Argument parsing ---
COMPLEXITY=""
ROUTING_CONFIG=""
MODE="default"
CURRENT_MODEL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --routing-config)
      ROUTING_CONFIG="${2:-}"
      if [ -z "$ROUTING_CONFIG" ]; then
        printf 'select-model.sh: --routing-config requires an argument\n' >&2
        exit 1
      fi
      shift 2
      ;;
    --list-fallback)
      MODE="list_fallback"
      shift
      ;;
    --next-fallback)
      MODE="next_fallback"
      CURRENT_MODEL="${2:-}"
      if [ -z "$CURRENT_MODEL" ]; then
        printf 'select-model.sh: --next-fallback requires an argument\n' >&2
        exit 1
      fi
      shift 2
      ;;
    -*)
      printf 'select-model.sh: unknown option %s\n' "$1" >&2
      exit 1
      ;;
    *)
      if [ -z "$COMPLEXITY" ]; then
        COMPLEXITY="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$COMPLEXITY" ]; then
  printf 'Usage: select-model.sh <tier> [--routing-config <file>] [--list-fallback | --next-fallback <model-id>]\n' >&2
  exit 1
fi

case "$COMPLEXITY" in
  heavy|standard|light) ;;
  *)
    printf 'select-model.sh: invalid tier %s (expected heavy, standard, or light)\n' "$COMPLEXITY" >&2
    exit 1
    ;;
esac

# --- Run context (standalone-safe) ---
# init_run_context uses /dev/urandom | head -c 8 under the hood; head closing
# its pipe can trip pipefail in the enclosing shell (P06-deferred bug). Defuse
# it locally so select-model.sh never aborts from a harmless SIGPIPE.
if [ -z "${ORCH_RUN_ID:-}" ]; then
  set +o pipefail
  init_run_context || true
  set -o pipefail
fi

emit_event DISPATCH_START stage=select_model tier="$COMPLEXITY" mode="$MODE" >&2
printf 'EVENT-AUDIT:DISPATCH_START stage="select_model"\n' >&2

# --- Built-in defaults (used when no routing config is available) ---
_sm_default_model() {
  case "$1" in
    heavy)    printf 'claude-opus-4-6 200000\n' ;;
    standard) printf 'claude-sonnet-4-6 150000\n' ;;
    light)    printf 'claude-haiku-4-5 80000\n' ;;
  esac
}

_sm_default_fallback() {
  case "$1" in
    heavy)    printf 'claude-sonnet-4-6,claude-haiku-4-5\n' ;;
    standard) printf 'claude-haiku-4-5\n' ;;
    light)    printf '\n' ;;
  esac
}

# --- Mode: default — print "<model-id> <context-budget>" ---
if [ "$MODE" = "default" ]; then
  if [ -z "$ROUTING_CONFIG" ] || [ ! -f "$ROUTING_CONFIG" ]; then
    _sm_default_model "$COMPLEXITY"
    exit 0
  fi
  model_id="$(read_recipe_field "$ROUTING_CONFIG" "models.${COMPLEXITY}.id" 2>/dev/null || true)"
  budget="$(read_recipe_field "$ROUTING_CONFIG" "models.${COMPLEXITY}.context_budget" 2>/dev/null || true)"
  if [ -z "$model_id" ] || [ -z "$budget" ]; then
    _sm_default_model "$COMPLEXITY"
    exit 0
  fi
  printf '%s %s\n' "$model_id" "$budget"
  exit 0
fi

# --- Mode: --list-fallback — print comma-separated chain ---
if [ "$MODE" = "list_fallback" ]; then
  if [ -z "$ROUTING_CONFIG" ] || [ ! -f "$ROUTING_CONFIG" ]; then
    _sm_default_fallback "$COMPLEXITY"
    exit 0
  fi
  chain="$(parse_recipe_fallback "$ROUTING_CONFIG" "$COMPLEXITY" 2>/dev/null || true)"
  if [ -z "$chain" ]; then
    printf '\n'
  else
    printf '%s\n' "$chain"
  fi
  exit 0
fi

# --- Mode: --next-fallback <current> — walk the chain ---
if [ "$MODE" = "next_fallback" ]; then
  # Build full_chain = primary,<fallback-chain> (skip empty segments).
  if [ -z "$ROUTING_CONFIG" ] || [ ! -f "$ROUTING_CONFIG" ]; then
    primary="$(_sm_default_model "$COMPLEXITY" | awk '{print $1}')"
    chain="$(_sm_default_fallback "$COMPLEXITY")"
  else
    primary="$(read_recipe_field "$ROUTING_CONFIG" "models.${COMPLEXITY}.id" 2>/dev/null || true)"
    chain="$(parse_recipe_fallback "$ROUTING_CONFIG" "$COMPLEXITY" 2>/dev/null || true)"
    if [ -z "$primary" ]; then
      primary="$(_sm_default_model "$COMPLEXITY" | awk '{print $1}')"
      chain="$(_sm_default_fallback "$COMPLEXITY")"
    fi
  fi

  if [ -n "$chain" ]; then
    full_chain="${primary},${chain}"
  else
    full_chain="$primary"
  fi

  # Split on comma and find the first entry AFTER CURRENT_MODEL.
  found=0
  next=""
  OLDIFS="$IFS"
  IFS=','
  # shellcheck disable=SC2086
  set -- $full_chain
  IFS="$OLDIFS"
  for m in "$@"; do
    if [ "$found" -eq 1 ]; then
      next="$m"
      break
    fi
    if [ "$m" = "$CURRENT_MODEL" ]; then
      found=1
    fi
  done

  if [ "$found" -eq 0 ]; then
    emit_event SAFETY_WARNING reason=current_model_not_in_chain current="$CURRENT_MODEL" tier="$COMPLEXITY" >&2
    printf 'EVENT-AUDIT:SAFETY_WARNING reason="current_model_not_in_chain"\n' >&2
    exit 1
  fi

  if [ -z "$next" ]; then
    emit_event DISPATCH_FALLBACK tier="$COMPLEXITY" from="$CURRENT_MODEL" to="" exhausted=1 >&2
    printf 'EVENT-AUDIT:DISPATCH_FALLBACK exhausted=1\n' >&2
    exit 1
  fi

  emit_event DISPATCH_FALLBACK tier="$COMPLEXITY" from="$CURRENT_MODEL" to="$next" exhausted=0 >&2
  printf 'EVENT-AUDIT:DISPATCH_FALLBACK from="%s"\n' "$CURRENT_MODEL" >&2
  printf '%s\n' "$next"
  exit 0
fi

# Unknown mode (defensive — should be unreachable).
printf 'select-model.sh: internal error: unknown mode %s\n' "$MODE" >&2
exit 1
