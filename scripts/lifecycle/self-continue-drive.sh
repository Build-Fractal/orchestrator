#!/usr/bin/env sh
# self-continue-drive.sh <milestone-dir> [options]
# Outer process-fresh self-continue loop (M045 FR-2/4/5/5a/6, decision D015;
# hardened M046 FR-14/FR-15). Each iteration runs ONE fresh auto segment
# (default: claude -p), reads the segment's outcome marker, and re-spawns only
# while a continue-class outcome holds under the safety envelope. The child
# auto MUST run single-segment (no --self-continue) so it does not nest a
# second driver.
#
# Outcome marker: <milestone-dir>/.self-continue-outcome, written by the auto
# segment as "<outcome> [<phase>]" where <outcome> is one of:
#   continue-class (re-spawn): rotation|planning|phase_complete|validating
#   terminal: complete|blocked|budget|stuck|pause|error|unexpected_state|
#             planning_failed|child_abort
# child_abort is DRIVER-owned (M046 FR-14): written when the child is
# signal-killed (rc>=128 — overwrites any mid-segment stale marker) or crashes
# with rc 1..127 leaving no marker. rc=0 with no marker preserves the M045
# unknown->STALLED path. Word 2 (phase) drives forward-progress (thrash
# detection).
#
# M046 FR-15 hardening:
#   - <milestone-dir> is validated against a strict charset allowlist
#     (A-Za-z0-9 _ . / -; no empty, no leading '-', no '..') BEFORE it
#     reaches any command line; violations exit 2 with SELF_CONTINUE:REJECT.
#   - --auto-cmd is whitespace-split verbatim into an argv array with
#     globbing disabled and executed WITHOUT shell re-parse (no sh -c).
#     SEMANTIC CHANGE from M045: quoting, expansion, and metacharacters in
#     --auto-cmd are NOT interpreted — pass a simple "cmd arg ..." form
#     (e.g. "sh /path/stub.sh").
#
# Emits (stdout):
#   SELF_CONTINUE:SCHEDULED continuation=<N> progress=<P> phase=<ph>
#   SELF_CONTINUE:TERMINAL outcome=<o> decision=<d> continuations=<N> progress=<P>
#   SELF_CONTINUE:CHILD_ABORT rc=<rc> continuations=<N> progress=<P>
#   SELF_CONTINUE:CAP_REACHED continuations=<N> progress=<P>
#   SELF_CONTINUE:STOPPED reason=stop-file continuations=<N> progress=<P>
#   SELF_CONTINUE:REJECT reason=milestone-dir-charset
set -eu

MILESTONE_DIR="$1"; shift
# M046 FR-15: strict charset allowlist — the milestone dir reaches a child
# command line, so reject shell metacharacters, leading '-', and '..' outright.
case "$MILESTONE_DIR" in
  ''|-*|*..*|*[!A-Za-z0-9_./-]*)
    echo "SELF_CONTINUE:REJECT reason=milestone-dir-charset"
    echo "self-continue-drive.sh: milestone-dir contains disallowed characters (allowed: A-Za-z0-9 _ . / -): $MILESTONE_DIR" >&2
    exit 2 ;;
esac
MAX_CONT=20; MIN_INTERVAL=2; ARMED=true; STOP_FILE=""; AUTO_CMD=""; LOG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --max-continuations) MAX_CONT="$2"; shift 2 ;;
    --min-interval) MIN_INTERVAL="$2"; shift 2 ;;
    --armed) ARMED="$2"; shift 2 ;;
    --stop-file) STOP_FILE="$2"; shift 2 ;;
    --auto-cmd) AUTO_CMD="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# M046 FR-15/FR-14: spawn the child via an argv array (no sh -c string
# re-parse). A custom --auto-cmd is whitespace-split verbatim with globbing
# disabled — metacharacters become inert argv bytes, never shell syntax.
# Captures the child's real exit status in CHILD_RC (previously discarded).
CHILD_RC=0
run_child() {
  CHILD_RC=0
  if [ -n "$AUTO_CMD" ]; then
    set -f
    # shellcheck disable=SC2086
    set -- $AUTO_CMD
    set +f
  else
    set -- claude -p "orchestrator:auto $MILESTONE_DIR"
  fi
  ORCHESTRATOR_SELF_CONTINUE_MARKER=1 "$@" >/dev/null 2>&1 || CHILD_RC=$?
  return 0
}

log_event() { [ -n "$LOG" ] && printf '%s\n' "$1" >> "$LOG"; return 0; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRANCH="$SCRIPT_DIR/self-continue-branch.sh"
OUTCOME_FILE="$MILESTONE_DIR/.self-continue-outcome"

HEADLESS="$(bash "$REPO_ROOT/dispatch/detect-capabilities.sh" 2>/dev/null | grep -E '^headless_reentry=' | head -n1 | sed 's/^headless_reentry=//')"
[ -n "$HEADLESS" ] || HEADLESS=false

cont=0; progress=0; last_phase=""
while :; do
  if [ -n "$STOP_FILE" ] && [ -f "$STOP_FILE" ]; then
    echo "SELF_CONTINUE:STOPPED reason=stop-file continuations=$cont progress=$progress"; exit 0
  fi
  if [ "$cont" -ge "$MAX_CONT" ]; then
    log_event "{\"type\":\"self_continue_cap_reached\",\"continuations\":$cont,\"progress\":$progress}"
    echo "SELF_CONTINUE:CAP_REACHED continuations=$cont progress=$progress"; exit 0
  fi
  pend=$((cont+1))
  log_event "{\"type\":\"self_continue_unconfirmed\",\"continuation\":$pend}"
  rm -f "$OUTCOME_FILE"
  run_child
  # M046 FR-14: deterministic CHILD_ABORT terminal for killed/crashed children.
  # rc>=128 (signal-killed): any marker present may be mid-segment stale — overwrite.
  # 1<=rc<=127 with no marker: child crashed before reporting — write child_abort.
  # 1<=rc<=127 with a marker: keep it (auto-loop's exit-keyed report is authoritative).
  # rc=0 with no marker: leave absent — the M045 unknown->STALLED path is preserved.
  if [ "$CHILD_RC" -ge 128 ] || { [ "$CHILD_RC" -ne 0 ] && [ ! -f "$OUTCOME_FILE" ]; }; then
    _abort_tmp="$OUTCOME_FILE.tmp.$$"
    printf 'child_abort\n' > "$_abort_tmp"
    mv -f "$_abort_tmp" "$OUTCOME_FILE"
  fi
  OUTCOME_RAW="$(cat "$OUTCOME_FILE" 2>/dev/null || echo unknown)"
  OUTCOME="$(printf '%s' "$OUTCOME_RAW" | awk '{print $1}')"
  PHASE="$(printf '%s' "$OUTCOME_RAW" | awk '{print $2}')"
  if [ "$OUTCOME" = "unknown" ]; then
    echo "SELF_CONTINUE:STALLED continuation=$pend continuations=$cont progress=$progress"
    exit 0
  fi
  if [ "$OUTCOME" = "child_abort" ]; then
    log_event "{\"type\":\"self_continue_child_abort\",\"rc\":$CHILD_RC,\"continuations\":$cont,\"progress\":$progress}"
    echo "SELF_CONTINUE:CHILD_ABORT rc=$CHILD_RC continuations=$cont progress=$progress"
    exit 0
  fi
  case "$OUTCOME" in
    rotation|planning|phase_complete|validating) STATUS="CONTEXT:ROTATE" ;;
    *) STATUS="CONTEXT:OK" ;;
  esac
  DECISION="$(bash "$BRANCH" --monitor-status "$STATUS" --armed "$ARMED" --headless "$HEADLESS")"
  case "$DECISION" in
    *AUTO:SELF_CONTINUE*)
      cont=$((cont+1))
      if [ -n "$PHASE" ] && [ "$PHASE" != "$last_phase" ]; then
        progress=$((progress+1)); last_phase="$PHASE"
      fi
      log_event "{\"type\":\"self_continue_scheduled\",\"continuation\":$cont,\"progress\":$progress,\"phase\":\"$PHASE\"}"
      echo "SELF_CONTINUE:SCHEDULED continuation=$cont progress=$progress phase=$PHASE"
      [ "$MIN_INTERVAL" = "0" ] || sleep "$MIN_INTERVAL"
      ;;
    *)
      case "$DECISION" in
        *headless-unavailable*) log_event "{\"type\":\"self_continue_unavailable\",\"reason\":\"headless-unavailable\"}" ;;
        *) log_event "{\"type\":\"self_continue_terminal\",\"outcome\":\"$OUTCOME\",\"continuations\":$cont,\"progress\":$progress}" ;;
      esac
      echo "SELF_CONTINUE:TERMINAL outcome=$OUTCOME decision=$DECISION continuations=$cont progress=$progress"
      exit 0
      ;;
  esac
done
