#!/usr/bin/env bash
# scripts/orchestrator/status.sh — Emit structured milestone summary for an
# orchestrator state root. Consumed by tests/integration/test-m003-e2e-migration.sh
# and by developers inspecting migrated or working state.
#
# Usage:
#   status.sh [--root <dir>]
#   ORCHESTRATOR_ROOT=<dir> status.sh
#
# Output (stdout):
#   MILESTONE: <ID>
#   STATE: <state-word>
#   PHASE: P01 <state>
#   PHASE: P02 <state>
#   ...
#
# Exit codes:
#   0 = success (at least one milestone found)
#   1 = no milestones found under resolved root
#   2 = resolver failed
#
# Bash 3.2 compatible. MEM001 (no declare -A, no ${var,,}, no |&).
# AD-19: invokes dependencies as subprocesses, never sources them.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Parse args ---
arg_root=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      if [ $# -lt 2 ]; then
        echo "status.sh: --root requires a directory argument" >&2
        exit 1
      fi
      arg_root="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,24p' "$0"
      exit 0
      ;;
    *)
      echo "status.sh: unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

# --- Resolve root ---
# Precedence: --root flag > ORCHESTRATOR_ROOT env > resolve-root.sh fallback
if [ -n "$arg_root" ]; then
  resolved_root="$arg_root"
elif [ -n "${ORCHESTRATOR_ROOT:-}" ]; then
  resolved_root="$ORCHESTRATOR_ROOT"
else
  resolved_root="$(bash "$REPO_ROOT/scripts/state/resolve-root.sh" --absolute 2>/dev/null || true)"
fi

if [ -z "$resolved_root" ] || [ ! -d "$resolved_root" ]; then
  echo "status.sh: could not resolve orchestrator root (tried --root, ORCHESTRATOR_ROOT, resolve-root.sh)" >&2
  exit 2
fi

# --- Find milestones ---
milestones_dir="$resolved_root/milestones"
if [ ! -d "$milestones_dir" ]; then
  echo "status.sh: no milestones/ directory under $resolved_root" >&2
  exit 1
fi

any_milestone=0
for m_dir in "$milestones_dir"/M*; do
  [ -d "$m_dir" ] || continue
  any_milestone=1
  m_id="$(basename "$m_dir")"
  # Milestone ID is directory name per MEM003 (detected from M###-*.md, but
  # directory basename is authoritative for this wrapper).
  m_state="$(bash "$REPO_ROOT/scripts/state/derive-phase.sh" "$m_dir" 2>/dev/null || echo unknown)"
  echo "MILESTONE: $m_id"
  echo "STATE: $m_state"
  if [ -d "$m_dir/phases" ]; then
    for p_dir in "$m_dir/phases"/P*; do
      [ -d "$p_dir" ] || continue
      p_id="$(basename "$p_dir")"
      if [ -f "$p_dir/$p_id-SUMMARY.md" ]; then
        p_state="complete"
      elif [ -f "$p_dir/$p_id-PLAN.md" ]; then
        p_state="executing"
      else
        p_state="pending"
      fi
      echo "PHASE: $p_id $p_state"
    done
  fi
done

if [ "$any_milestone" -eq 0 ]; then
  echo "status.sh: no milestones found under $milestones_dir" >&2
  exit 1
fi

exit 0
