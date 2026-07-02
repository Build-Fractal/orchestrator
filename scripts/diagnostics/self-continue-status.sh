#!/usr/bin/env sh
# self-continue-status.sh <log-path>
# Reports the self-continue run health from its FR-9/FR-10 JSONL log (M045).
# Consumes the log written by scripts/lifecycle/self-continue-drive.sh --log <path>.
#   SELF_CONTINUE:STALLED     — last record is self_continue_unconfirmed (segment never resolved)
#   SELF_CONTINUE:OK          — last record is scheduled/terminal/cap/unavailable
#   SELF_CONTINUE:NO_LOG      — log missing or empty
set -eu
LOG="${1:-}"
if [ -z "$LOG" ] || [ ! -s "$LOG" ]; then
  echo "SELF_CONTINUE:NO_LOG"; exit 0
fi
LAST="$(tail -n 1 "$LOG")"
SCHED="$(grep -c 'self_continue_scheduled' "$LOG" 2>/dev/null || echo 0)"
case "$LAST" in
  *self_continue_unconfirmed*)
    echo "SELF_CONTINUE:STALLED scheduled=$SCHED (last segment never resolved)"; exit 0 ;;
  *)
    echo "SELF_CONTINUE:OK scheduled=$SCHED last=$(printf '%s' "$LAST" | sed -n 's/.*\"type\":\"\([a-z_]*\)\".*/\1/p')"; exit 0 ;;
esac
