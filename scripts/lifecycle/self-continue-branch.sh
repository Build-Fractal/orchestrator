#!/usr/bin/env bash
# self-continue-branch.sh — deterministic self-continue decision (M045 FR-3).
# Given the rotation-monitor status + armed flag + headless_reentry capability,
# emit exactly one directive:
#   AUTO:SELF_CONTINUE          — rotation AND armed AND headless-capable
#   AUTO:ROTATE_EXIT reason=... — rotation but not(armed AND capable) → legacy exit
#   AUTO:NO_ROTATION            — monitor did not report rotation
# Substrate-agnostic: the caller (commands/auto.md, wired in P03) turns
# AUTO:SELF_CONTINUE into a process-fresh `claude -p` re-entry (decision D015).
#
# Usage: self-continue-branch.sh --monitor-status "<CONTEXT:OK...|CONTEXT:ROTATE...>"
#          --armed <true|false> [--headless <true|false>]
#          [--capabilities-file <path>]
# If --headless is omitted, the capability is read from detect-capabilities.sh
# (or from --capabilities-file if provided, a key=value dump for tests).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MONITOR_STATUS=""; ARMED="false"; HEADLESS=""; CAP_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --monitor-status) MONITOR_STATUS="$2"; shift 2 ;;
    --armed) ARMED="$2"; shift 2 ;;
    --headless) HEADLESS="$2"; shift 2 ;;
    --capabilities-file) CAP_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Resolve headless capability if not explicitly provided.
if [[ -z "$HEADLESS" ]]; then
  if [[ -n "$CAP_FILE" && -f "$CAP_FILE" ]]; then
    HEADLESS="$(grep -E '^headless_reentry=' "$CAP_FILE" | head -n1 | sed 's/^headless_reentry=//')"
  else
    HEADLESS="$(bash "$REPO_ROOT/dispatch/detect-capabilities.sh" 2>/dev/null | grep -E '^headless_reentry=' | head -n1 | sed 's/^headless_reentry=//')"
  fi
  [[ -n "$HEADLESS" ]] || HEADLESS="false"
fi

# Decide.
case "$MONITOR_STATUS" in
  *CONTEXT:ROTATE*)
    if [[ "$ARMED" == "true" && "$HEADLESS" == "true" ]]; then
      echo "AUTO:SELF_CONTINUE substrate=process-fresh"
    elif [[ "$ARMED" != "true" ]]; then
      echo "AUTO:ROTATE_EXIT reason=not-armed"
    else
      echo "AUTO:ROTATE_EXIT reason=headless-unavailable"
    fi
    ;;
  *)
    echo "AUTO:NO_ROTATION"
    ;;
esac
