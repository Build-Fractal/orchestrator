#!/usr/bin/env bash
# scripts/intake/approval-gate.sh
# M024/P03/T02 — Operator approval gate for intake proposals (FR-4).
#
# Inputs:
#   --proposal <path>   The proposal.md to act on.
#   --verb <verb>       One of: approve | cancel | revise
#   --axis <name>       (revise only) Axis to override.
#   --value <value>     (revise only) New value.
#
# Outputs:
#   approve: stdout line "recommended_command_invoke=<value>"
#   cancel:  no stdout
#   revise:  stdout line "revision_pending=true axis=<a> value=<v>"
#
# Exit 0 on success, 1 on internal error, 2 on usage error.

set -u

usage() {
  cat >&2 <<'EOF'
usage: approval-gate.sh --proposal <path> --verb <approve|cancel|revise> [--axis <name> --value <value>] [--no-apply]
       approval-gate.sh --proposal <path> --mode check-fast-path

Verbs (mutate frontmatter):
  approve    set approved_at, set pending_approval=false, emit recommended_command_invoke
  cancel     set cancelled_at, set pending_approval=false
  revise     wired in P06 — invokes scripts/intake/revise.sh, emits revised_to=<new-path>
             (--no-apply is a test-only flag preserving the P03 surface)

Modes (read-only):
  check-fast-path   emit fast_path_eligible + reason for the four-condition gate
EOF
  exit 2
}

PROPOSAL=""
VERB=""
MODE=""        # NEW — for --mode check-fast-path
AXIS=""
VALUE=""
NO_APPLY="0"   # M024/P06/T03 — test-only flag preserving P03 stdout shape

while [ $# -gt 0 ]; do
  case "$1" in
    --proposal) PROPOSAL="$2"; shift 2 ;;
    --verb)     VERB="$2";     shift 2 ;;
    --mode)     MODE="$2";     shift 2 ;;
    --axis)     AXIS="$2";     shift 2 ;;
    --value)    VALUE="$2";    shift 2 ;;
    --no-apply) NO_APPLY="1";  shift 1 ;;
    -h|--help)  usage ;;
    *)          usage ;;
  esac
done

[ -n "$PROPOSAL" ] || usage
[ -n "$VERB" ] || [ -n "$MODE" ] || usage
[ -f "$PROPOSAL" ] || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }

# Read a frontmatter key value (single-script shape).
read_fm() {
  sed -n "s/^${1}: \"\\(.*\\)\"\$/\\1/p" "$PROPOSAL" | head -1
}

# Bare-value form (boolean fields are written without quotes).
read_fm_bare() {
  sed -n "s/^${1}: \\(.*\\)\$/\\1/p" "$PROPOSAL" | head -1
}

if [ -z "$MODE" ]; then
  REC_CMD=$(read_fm recommended_command)
  [ -n "$REC_CMD" ] || { echo "ERR: proposal missing recommended_command frontmatter at $PROPOSAL" >&2; exit 1; }

  PA=$(read_fm_bare pending_approval)
  if [ "$PA" = "false" ]; then
    echo "ERR: proposal already finalized (pending_approval=false) at $PROPOSAL" >&2
    exit 1
  fi
fi

# --mode check-fast-path: read-only verdict on the four fast-path conditions + low_confidence guard.
if [ "$MODE" = "check-fast-path" ]; then
  scope_tier=$(read_fm scope_tier)
  intensity=$(read_fm intensity)
  conversus_gate=$(read_fm conversus_gate)
  design_gate=$(read_fm design_gate)
  low_confidence=$(read_fm_bare low_confidence)

  # Evaluate conditions in fixed order — the first failing condition wins the reason slot.
  if [ "$scope_tier" != "A" ]; then
    echo "fast_path_eligible=false"
    echo "reason=tier-not-A"
    exit 0
  fi
  if [ "$intensity" != "Quick" ]; then
    echo "fast_path_eligible=false"
    echo "reason=intensity-not-Quick"
    exit 0
  fi
  if [ "$conversus_gate" != "none" ]; then
    echo "fast_path_eligible=false"
    echo "reason=conversus-gated"
    exit 0
  fi
  if [ "$design_gate" != "none" ]; then
    echo "fast_path_eligible=false"
    echo "reason=design-gated"
    exit 0
  fi
  if [ "$low_confidence" = "true" ]; then
    echo "fast_path_eligible=false"
    echo "reason=low-confidence"
    exit 0
  fi

  echo "fast_path_eligible=true"
  echo "reason=all-conditions-met"
  exit 0
fi

# Unknown mode (anything other than check-fast-path).
if [ -n "$MODE" ]; then
  echo "ERR: unknown mode '$MODE' — supported: check-fast-path" >&2
  exit 2
fi

# In-place line-replace helper, BSD/GNU portable.
swap_line() {
  local key="$1" newline="$2"
  local esc
  esc=$(printf '%s' "$newline" | sed 's/[\/&]/\\&/g')
  sed -i.bak "s/^${key}: .*\$/${esc}/" "$PROPOSAL"
  rm -f "${PROPOSAL}.bak"
}

now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

case "$VERB" in
  approve)
    ts=$(now_iso)
    swap_line approved_at "approved_at: \"$ts\""
    swap_line pending_approval "pending_approval: false"
    echo "recommended_command_invoke=$REC_CMD"
    exit 0
    ;;
  cancel)
    ts=$(now_iso)
    swap_line cancelled_at "cancelled_at: \"$ts\""
    swap_line pending_approval "pending_approval: false"
    exit 0
    ;;
  revise)
    [ -n "$AXIS" ]  || { echo "ERR: --axis required for revise" >&2; exit 2; }
    [ -n "$VALUE" ] || { echo "ERR: --value required for revise" >&2; exit 2; }
    case "$AXIS" in
      input_shape|scope_tier|decomposition|design_gate|conversus_gate|intensity) ;;
      *) echo "ERR: unsupported axis '$AXIS' — supported: input_shape scope_tier decomposition design_gate conversus_gate intensity" >&2; exit 2 ;;
    esac

    if [ "$NO_APPLY" = "1" ]; then
      # Legacy P03 surface — preserved for test backward-compat.
      echo "revision_pending=true axis=$AXIS value=$VALUE"
      exit 0
    fi

    # M024/P06/T03 — wired full re-emit via revise.sh.
    REVISE_SH="$(cd "$(dirname "$0")/../.." && pwd)/scripts/intake/revise.sh"
    [ -x "$REVISE_SH" ] || { echo "ERR: revise.sh not executable at $REVISE_SH" >&2; exit 1; }
    if rev_out=$(bash "$REVISE_SH" --proposal "$PROPOSAL" --axis "$AXIS" --value "$VALUE"); then
      echo "$rev_out"
      exit 0
    else
      echo "ERR: revise.sh failed for $AXIS=$VALUE on $PROPOSAL" >&2
      exit 1
    fi
    ;;
  manual|skip)
    # M024/P07/T03 — pre-M023 design-gate degradation verbs.
    # Validate proposal carries design_gate: "walkthrough".
    dg=$(read_fm design_gate)
    if [ "$dg" != "walkthrough" ]; then
      echo "ERR: '$VERB' verb requires design_gate=walkthrough on a pre-M023 checkout (got: design_gate=$dg)" >&2
      exit 2
    fi
    ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
    DEG="$ROOT_DIR/scripts/intake/design-gate-degradation.sh"
    if [ ! -x "$DEG" ]; then
      echo "ERR: $DEG not executable — required for manual/skip verbs" >&2
      exit 1
    fi
    bash "$DEG" --proposal "$PROPOSAL" --branch "$VERB"
    exit $?
    ;;
  *)
    usage
    ;;
esac
