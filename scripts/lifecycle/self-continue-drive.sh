#!/usr/bin/env sh
# self-continue-drive.sh <milestone-dir> [options]
# Outer process-fresh self-continue loop (M045 FR-2/4/5/5a/6, decision D015).
# Each iteration runs ONE fresh auto segment (default: claude -p), reads the
# segment's outcome marker, and re-spawns only while rotation continues under
# the safety envelope. The child auto MUST run single-segment (no --self-continue)
# so it does not nest a second driver.
#
# Outcome marker: <milestone-dir>/.self-continue-outcome, written by the auto
# segment as "<outcome> [<phase>]" where <outcome> is rotation|complete|blocked|
# budget|stuck|pause. Word 2 (phase) drives forward-progress (thrash detection).
#
# Emits (stdout):
#   SELF_CONTINUE:SCHEDULED continuation=<N> progress=<P> phase=<ph>
#   SELF_CONTINUE:TERMINAL outcome=<o> decision=<d> continuations=<N> progress=<P>
#   SELF_CONTINUE:CAP_REACHED continuations=<N> progress=<P>
#   SELF_CONTINUE:STOPPED reason=stop-file continuations=<N> progress=<P>
set -eu

MILESTONE_DIR="$1"; shift
MAX_CONT=20; MIN_INTERVAL=2; ARMED=true; STOP_FILE=""; AUTO_CMD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --max-continuations) MAX_CONT="$2"; shift 2 ;;
    --min-interval) MIN_INTERVAL="$2"; shift 2 ;;
    --armed) ARMED="$2"; shift 2 ;;
    --stop-file) STOP_FILE="$2"; shift 2 ;;
    --auto-cmd) AUTO_CMD="$2"; shift 2 ;;
    *) shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRANCH="$SCRIPT_DIR/self-continue-branch.sh"
OUTCOME_FILE="$MILESTONE_DIR/.self-continue-outcome"
[ -n "$AUTO_CMD" ] || AUTO_CMD="claude -p \"orchestrator:auto $MILESTONE_DIR\""

HEADLESS="$(bash "$REPO_ROOT/dispatch/detect-capabilities.sh" 2>/dev/null | grep -E '^headless_reentry=' | head -n1 | sed 's/^headless_reentry=//')"
[ -n "$HEADLESS" ] || HEADLESS=false

cont=0; progress=0; last_phase=""
while :; do
  if [ -n "$STOP_FILE" ] && [ -f "$STOP_FILE" ]; then
    echo "SELF_CONTINUE:STOPPED reason=stop-file continuations=$cont progress=$progress"; exit 0
  fi
  if [ "$cont" -ge "$MAX_CONT" ]; then
    echo "SELF_CONTINUE:CAP_REACHED continuations=$cont progress=$progress"; exit 0
  fi
  rm -f "$OUTCOME_FILE"
  sh -c "$AUTO_CMD" >/dev/null 2>&1 || true
  OUTCOME_RAW="$(cat "$OUTCOME_FILE" 2>/dev/null || echo unknown)"
  OUTCOME="$(printf '%s' "$OUTCOME_RAW" | awk '{print $1}')"
  PHASE="$(printf '%s' "$OUTCOME_RAW" | awk '{print $2}')"
  if [ "$OUTCOME" = "rotation" ]; then STATUS="CONTEXT:ROTATE"; else STATUS="CONTEXT:OK"; fi
  DECISION="$(bash "$BRANCH" --monitor-status "$STATUS" --armed "$ARMED" --headless "$HEADLESS")"
  case "$DECISION" in
    *AUTO:SELF_CONTINUE*)
      cont=$((cont+1))
      if [ -n "$PHASE" ] && [ "$PHASE" != "$last_phase" ]; then
        progress=$((progress+1)); last_phase="$PHASE"
      fi
      echo "SELF_CONTINUE:SCHEDULED continuation=$cont progress=$progress phase=$PHASE"
      [ "$MIN_INTERVAL" = "0" ] || sleep "$MIN_INTERVAL"
      ;;
    *)
      echo "SELF_CONTINUE:TERMINAL outcome=$OUTCOME decision=$DECISION continuations=$cont progress=$progress"
      exit 0
      ;;
  esac
done
