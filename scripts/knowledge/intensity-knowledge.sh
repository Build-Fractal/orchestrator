#!/usr/bin/env bash
# scripts/knowledge/intensity-knowledge.sh -- Intensity-aware knowledge
# generation gate.
#
# Reads intensity from a metadata file and invokes the matching subset
# of the knowledge pipeline:
#
#   Quick    -> write-summary.sh
#   Standard -> write-summary.sh, append-decision.sh
#   Full     -> write-summary.sh, append-decision.sh,
#               append-knowledge.sh, rebuild-index.sh
#
# The underlying M007 knowledge scripts are NOT modified. This wrapper
# is the pipeline gate; they remain the source of truth for their own
# behavior.
#
# Usage:
#   intensity-knowledge.sh --intensity-metadata <path> [--dry-run]
#                          [-- <args forwarded to each sub-script>]
#
#   intensity-knowledge.sh --intensity <Quick|Standard|Full> [--dry-run]
#                          [-- <forwarded args>]
#
# Explicit-decision capture (M044/FR-8): pass one or more --decision-arg <value>
# to run append-decision.sh with that argv at ANY intensity — including Quick —
# independent of the intensity-gated steps. Argv order matches append-decision.sh:
#   --decision-arg <decisions-file> --decision-arg <when> --decision-arg <scope>
#   --decision-arg <decision> --decision-arg <choice> --decision-arg <rationale>
#   [--decision-arg <revisable>]
#
# In --dry-run mode, the script prints `WOULD_RUN: <script-path> <args>`
# lines for each step that would execute, then exits 0. No sub-scripts
# are invoked.
#
# Output (normal mode): the interleaved stdout of each sub-script.
# Errors from any sub-script cause this wrapper to stop and exit with
# the sub-script's exit code.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METADATA_FILE=""
INTENSITY=""
DRY_RUN=0
FORWARD_ARGS=""
# M044/P04/T01 (FR-8/G-1): explicit-decision capture. A repeatable --decision-arg
# accumulates the positional argv for append-decision.sh. When ≥1 is present, the
# legacy decision primitive runs at ANY intensity (incl Quick) — independent of the
# intensity-gated auto steps. No net-new capture verb (DQ-7).
decision_argv=()
has_explicit_decision=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --intensity-metadata)
      METADATA_FILE="${2:-}"; shift 2 ;;
    --intensity)
      INTENSITY="${2:-}"; shift 2 ;;
    --decision-arg)
      decision_argv+=("${2:-}"); has_explicit_decision=1; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --)
      shift
      # Remaining args are forwarded verbatim.
      FORWARD_ARGS="$*"
      break
      ;;
    *)
      shift ;;
  esac
done

# Resolve intensity
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

case "$INTENSITY" in
  Quick|Standard|Full) ;;
  *)
    echo "ERROR: invalid intensity '$INTENSITY' (expected Quick|Standard|Full)" >&2
    exit 2 ;;
esac

# Define the pipeline steps per intensity. Parallel indexed arrays per
# MEM001 (no associative arrays in bash 3.2).

step_count=0
step_0=""
step_1=""
step_2=""
step_3=""

case "$INTENSITY" in
  Quick)
    step_0="$SCRIPT_DIR/write-summary.sh"
    step_count=1
    ;;
  Standard)
    step_0="$SCRIPT_DIR/write-summary.sh"
    step_1="$SCRIPT_DIR/append-decision.sh"
    step_count=2
    ;;
  Full)
    step_0="$SCRIPT_DIR/write-summary.sh"
    step_1="$SCRIPT_DIR/append-decision.sh"
    step_2="$SCRIPT_DIR/append-knowledge.sh"
    step_3="$SCRIPT_DIR/rebuild-index.sh"
    step_count=4
    ;;
esac

run_step() {
  local script="$1"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "WOULD_RUN: $script $FORWARD_ARGS"
    return 0
  fi
  if [[ ! -f "$script" ]]; then
    echo "ERROR: knowledge script missing: $script" >&2
    return 1
  fi
  # Forward args. Using $FORWARD_ARGS unquoted is intentional -- the
  # caller's args re-split on whitespace. Callers that need to pass
  # arguments containing spaces should invoke the sub-scripts directly.
  # shellcheck disable=SC2086
  bash "$script" $FORWARD_ARGS
}

# M044/P04/T01: the intensity-gated auto steps (write-summary.sh et al.) consume
# $FORWARD_ARGS. A DECISION-ONLY capture (explicit decision + no `--` forwarded
# args) must NOT run the auto steps — they require args and would fail. This is
# strictly additive: a no-explicit-decision run is unchanged, and a full close-flow
# run (forwarded args present) still runs both the auto steps and the decision.
run_auto=1
if [[ "$has_explicit_decision" -eq 1 ]] && [[ -z "$FORWARD_ARGS" ]]; then
  run_auto=0
fi

i=0
while [[ $run_auto -eq 1 ]] && [[ $i -lt $step_count ]]; do
  case "$i" in
    0) step="$step_0" ;;
    1) step="$step_1" ;;
    2) step="$step_2" ;;
    3) step="$step_3" ;;
  esac
  run_step "$step" || {
    rc=$?
    echo "ERROR: step '$step' exited $rc" >&2
    exit "$rc"
  }
  i=$((i + 1))
done

# M044/P04/T01 (FR-8/G-1): explicit-decision capture runs at ANY intensity — even
# Quick — so a Quick project never silently drops an operator's explicit decision.
# Uses append-decision.sh's own argv (NOT $FORWARD_ARGS), independent of the
# intensity-gated steps above.
if [[ "$has_explicit_decision" -eq 1 ]]; then
  decision_script="$SCRIPT_DIR/append-decision.sh"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "WOULD_RUN: $decision_script ${decision_argv[*]}"
  else
    if [[ ! -f "$decision_script" ]]; then
      echo "ERROR: knowledge script missing: $decision_script" >&2
      exit 1
    fi
    bash "$decision_script" "${decision_argv[@]}" || {
      rc=$?
      echo "ERROR: explicit decision capture (append-decision.sh) exited $rc" >&2
      exit "$rc"
    }
  fi
fi

echo "INTENSITY_KNOWLEDGE: completed intensity=$INTENSITY steps=$step_count"
exit 0
