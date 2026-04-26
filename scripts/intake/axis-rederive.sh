#!/usr/bin/env bash
# scripts/intake/axis-rederive.sh
# M024/P06/T01 — Pure decision emitter for dependent-axis recomputation (FR-12).
#
# Inputs:
#   --axis <name>      Primary override axis (closed enum).
#   --value <value>    Primary override value.
#   --proposal <path>  Parent proposal (read-only — used for input_shape lookup).
#
# Stdout (zero or more lines):
#   <dependent-axis>=<rederived-value>
#
# Stderr (advisory):
#   note=axis is independent — no dependents
#   WARN: input_shape revision is structural; consider re-running orchestrator:evaluate from scratch instead
#
# Exit 0 on success (including independent-axis no-op), 1 on internal error, 2 on usage error.

set -u

usage() {
  cat >&2 <<'EOF'
usage: axis-rederive.sh --axis <name> --value <value> --proposal <path>

Axes (closed enum):
  input_shape  scope_tier  decomposition  design_gate  conversus_gate  intensity

Emits dependent-axis recomputations as key=value stdout lines.
Independent axes (conversus_gate, intensity) emit no lines.
EOF
  exit 2
}

AXIS=""
VALUE=""
PROPOSAL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --axis)     AXIS="$2";     shift 2 ;;
    --value)    VALUE="$2";    shift 2 ;;
    --proposal) PROPOSAL="$2"; shift 2 ;;
    -h|--help)  usage ;;
    *)          usage ;;
  esac
done

[ -n "$AXIS" ]     || usage
[ -n "$VALUE" ]    || usage
[ -n "$PROPOSAL" ] || usage
[ -f "$PROPOSAL" ] || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }

# Read input_shape from the proposal frontmatter (single-pipeline shape).
read_fm() {
  sed -n "s/^${1}: \"\\(.*\\)\"\$/\\1/p" "$PROPOSAL" | head -1
}
SHAPE=$(read_fm input_shape)
[ -n "$SHAPE" ] || { echo "ERR: proposal missing input_shape frontmatter at $PROPOSAL" >&2; exit 1; }

# Axis enum check.
case "$AXIS" in
  input_shape|scope_tier|decomposition|design_gate|conversus_gate|intensity) ;;
  *) echo "ERR: unknown axis '$AXIS' — supported: input_shape scope_tier decomposition design_gate conversus_gate intensity" >&2; exit 2 ;;
esac

# Value enum check (per axis).
case "$AXIS" in
  scope_tier)
    case "$VALUE" in A|B|C) ;; *) echo "ERR: invalid value '$VALUE' for axis 'scope_tier' — supported: A B C" >&2; exit 2 ;; esac ;;
  decomposition)
    case "$VALUE" in single-task|single-phase|milestone-with-phases|multi-milestone) ;;
      *) echo "ERR: invalid value '$VALUE' for axis 'decomposition' — supported: single-task single-phase milestone-with-phases multi-milestone" >&2; exit 2 ;;
    esac ;;
  design_gate)
    case "$VALUE" in none|walkthrough) ;;
      *) echo "ERR: invalid value '$VALUE' for axis 'design_gate' — supported: none walkthrough" >&2; exit 2 ;;
    esac ;;
  intensity)
    case "$VALUE" in Quick|Standard|Full) ;;
      *) echo "ERR: invalid value '$VALUE' for axis 'intensity' — supported: Quick Standard Full" >&2; exit 2 ;;
    esac ;;
  input_shape)
    case "$VALUE" in idea|paragraph|fragment|spec|empty|empty_qa) ;;
      *) echo "ERR: invalid value '$VALUE' for axis 'input_shape' — supported: idea paragraph fragment spec empty empty_qa" >&2; exit 2 ;;
    esac ;;
  conversus_gate) ;;  # open-set passthrough
esac

# Rule dispatch.
case "$AXIS" in
  scope_tier)
    case "$VALUE" in
      A) echo "decomposition=single-task";          echo "recommended_command=orchestrator:dispatch" ;;
      B) echo "decomposition=single-phase";         echo "recommended_command=orchestrator:specify" ;;
      C) echo "decomposition=milestone-with-phases"; echo "recommended_command=orchestrator:specify" ;;
    esac
    exit 0 ;;
  decomposition)
    case "$VALUE" in
      single-task)            echo "recommended_command=orchestrator:dispatch" ;;
      single-phase)           echo "recommended_command=orchestrator:specify" ;;
      milestone-with-phases)  echo "recommended_command=orchestrator:specify" ;;
      multi-milestone)        echo "recommended_command=orchestrator:roadmap" ;;
    esac
    exit 0 ;;
  design_gate)
    # No rederives in P06; P07 owns the post-walkthrough manual/skip branch.
    exit 0 ;;
  conversus_gate|intensity)
    echo "note=axis is independent — no dependents" >&2
    exit 0 ;;
  input_shape)
    echo "WARN: input_shape revision is structural; consider re-running orchestrator:evaluate from scratch instead" >&2
    exit 0 ;;
esac
