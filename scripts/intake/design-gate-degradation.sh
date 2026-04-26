#!/usr/bin/env bash
# scripts/intake/design-gate-degradation.sh
# M024/P07/T02 — Invoke-time M023 probe + FR-7 pinned message + manual/skip branches.
#
# Modes:
#   Probe-only (no --branch):  emit m023_shipped=<bool> + recommended_command=<v> to stdout.
#   Branch mode (--branch manual|skip): emit FR-7 pinned message to stderr on probe-fail
#     for a walkthrough proposal; mutate proposal frontmatter; emit branch summary to stdout.
#
# Exit 0 on success, 1 on internal error (e.g. proposal frontmatter unreadable),
#        2 on usage error or validation failure.

set -u

# FR-7 byte-pinned message — DO NOT EDIT without updating the three pinned sites
# (this script, commands/evaluate.md, scripts/verify/m024-p07-pinned-message.sh).
FR7_MSG='design walkthrough lands in M023; author DESIGN.md manually or skip'

usage() {
  cat >&2 <<'EOF'
usage: design-gate-degradation.sh --proposal <path> [--branch manual|skip]

Probe-only mode (no --branch): emits m023_shipped=<true|false> + recommended_command=<v>.
Branch mode: requires --proposal carrying design_gate: "walkthrough" AND M023 probe failing.

  --branch skip    Records design_skipped=true; proceeds.
  --branch manual  Halts on first invocation; flips design_authored_manually=true on
                   follow-up invocation if DESIGN.md was authored at the expected path.

Env: M023_SHIPPED_PROBE_OVERRIDE=stub|live (test-only escape)
EOF
  exit 2
}

PROPOSAL=""
BRANCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --proposal)    PROPOSAL="$2"; shift 2 ;;
    --branch)      BRANCH="$2";   shift 2 ;;
    --probe-only)  BRANCH="";     shift ;;
    -h|--help)     usage ;;
    *)             usage ;;
  esac
done

[ -n "$PROPOSAL" ] || usage
[ -f "$PROPOSAL" ] || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }

# Validate --branch enum.
if [ -n "$BRANCH" ]; then
  case "$BRANCH" in manual|skip) ;; *) echo "ERR: --branch must be manual|skip (got: $BRANCH)" >&2; exit 2 ;; esac
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# --- M023 probe ---
m023_probe() {
  local override="${M023_SHIPPED_PROBE_OVERRIDE:-}"
  case "$override" in
    stub) echo "m023_shipped=false"; echo "reason=env-override"; return ;;
    live) echo "m023_shipped=true";  echo "reason=env-override"; return ;;
    "")   ;;
    *)    echo "WARN: M023_SHIPPED_PROBE_OVERRIDE='$override' not in {stub,live}; falling through to disk probe" >&2 ;;
  esac
  if [ -f "$ROOT/commands/design.md" ] && grep -qE '^Pass\.[0-9]+' "$ROOT/commands/design.md"; then
    echo "m023_shipped=true"; echo "reason=disk-probe"
  else
    echo "m023_shipped=false"; echo "reason=disk-probe-failed"
  fi
}

# --- proposal frontmatter helpers ---
read_fm() {
  # read_fm <key>; emits the value (un-quoted scalars only).
  sed -n "s/^${1}: \"\\(.*\\)\"\$/\\1/p" "$PROPOSAL" | head -1
}
read_fm_bool() {
  # bool keys are unquoted (true/false/null) per template.
  sed -n "s/^${1}: \\(.*\\)\$/\\1/p" "$PROPOSAL" | head -1
}
mutate_fm() {
  # mutate_fm <key> <value-with-or-without-quotes>; uses sed -i.bak then rm.
  local key="$1"; local val="$2"
  local esc
  esc=$(printf '%s' "$val" | sed 's/[\/&]/\\&/g')
  sed -i.bak "s/^${key}: .*/${key}: ${esc}/" "$PROPOSAL"
  rm -f "${PROPOSAL}.bak"
}

# --- expected DESIGN.md path ---
expected_design_md_path() {
  local feature_slug
  feature_slug=$(read_fm feature_slug)
  if [ -n "$feature_slug" ] && [ "$feature_slug" != "null" ] && [ -d "$ROOT/specs/$feature_slug" ]; then
    echo "$ROOT/specs/$feature_slug/DESIGN.md"
  else
    echo "$(dirname "$PROPOSAL")/DESIGN.md"
  fi
}

# --- run probe ---
probe_out=$(m023_probe)
m023_shipped=$(echo "$probe_out" | sed -n 's/^m023_shipped=//p' | head -1)

# --- probe-only mode ---
if [ -z "$BRANCH" ]; then
  # Decide recommended_command for design-gated proposals.
  design_gate=$(read_fm design_gate)
  scope_tier=$(read_fm scope_tier)
  rec_cmd="orchestrator:dispatch"
  case "$scope_tier" in
    A) rec_cmd="orchestrator:dispatch" ;;
    B|C) rec_cmd="orchestrator:specify" ;;
  esac
  if [ "$design_gate" = "walkthrough" ] && [ "$m023_shipped" = "true" ]; then
    rec_cmd="orchestrator:design"
  fi
  echo "$probe_out"
  echo "recommended_command=$rec_cmd"
  exit 0
fi

# --- branch mode validation ---
design_gate=$(read_fm design_gate)
if [ "$design_gate" != "walkthrough" ]; then
  echo "ERR: '$BRANCH' verb requires design_gate=walkthrough on a pre-M023 checkout (got: design_gate=$design_gate)" >&2
  exit 2
fi
if [ "$m023_shipped" = "true" ]; then
  echo "ERR: M023 has shipped — manual/skip branches are pre-M023-only; use 'approve' to invoke orchestrator:design" >&2
  exit 2
fi

# --- emit pinned message to stderr ---
echo "$FR7_MSG" >&2

# --- branch dispatch ---
case "$BRANCH" in
  skip)
    mutate_fm design_skipped "true"
    mutate_fm pending_approval "false"
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    mutate_fm proceeded_at "\"$now\""
    echo "branch=skip design_skipped=true proposal=$PROPOSAL"
    exit 0
    ;;
  manual)
    pending=$(read_fm_bool pending_design_authored_manually)
    authored=$(read_fm_bool design_authored_manually)
    design_md=$(expected_design_md_path)
    # First invocation OR follow-up where DESIGN.md still missing.
    if [ "$authored" = "true" ]; then
      # Already finalized — idempotent no-op.
      echo "branch=manual halt=false design_authored_manually=true design_md_path=$design_md"
      exit 0
    fi
    if [ -f "$design_md" ]; then
      mutate_fm design_authored_manually "true"
      mutate_fm pending_design_authored_manually "false"
      mutate_fm pending_approval "true"
      echo "branch=manual halt=false design_authored_manually=true design_md_path=$design_md"
      exit 0
    fi
    if [ "$pending" != "true" ]; then
      mutate_fm pending_design_authored_manually "true"
    fi
    echo "branch=manual halt=true design_authored_manually=false design_md_path=$design_md"
    exit 0
    ;;
esac
