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
# M046 P04 unattended safety envelope (opt-in via --unattended; DEFAULT OFF,
# FR-6 — no config read may enable it). When --unattended is set, the driver
# sources scripts/lifecycle/unattended-envelope.sh and layers on:
#   --max-budget-usd <x>       hard cumulative $ ceiling (REQUIRED)
#   --max-continuations <n>    explicit continuation cap (REQUIRED; the silent
#                              MAX_CONT=20 default is NOT an implicit cap here)
#   --max-wall-clock-s <n>     hard wall-clock ceiling in seconds (REQUIRED)
#   --segment-reserve-usd <x>  per-segment lease reserved before spawn (def 1.00)
#   --thrash-threshold <n>     no-progress segments before THRASH halt (def 2)
#   --watchdog-poll-s <n>      watchdog poll interval in seconds (def 1)
#   --cost-log <path>          JSONL the watchdog reads for mid-segment cost
#                              (def <milestone-dir>/execution-log.jsonl)
# FR-13 fail-closed (SC-8): the driver ITSELF refuses to start (exit 2,
# SELF_CONTINUE:REFUSE, no ledger write, no spawn) when any of the three hard
# caps is unset or non-numeric — enforced here, not merely at a CLI layer.
# FR-7/FR-10/D016: under --unattended the child is BACKGROUNDED and a foreground
# envelope_watchdog polls it, SIGKILLing on the first of {stop-file,
# wall-clock-exceeded, cost-derived-budget}; the D016 wall-clock resolution
# derives both the mid-segment kill and the pre-spawn ceiling check from one
# DEADLINE_EPOCH. FR-8: a per-segment reserve is written to the ledger BEFORE
# the spawn (a crash between reserve and reconcile leaves the reserve SPENT),
# then trued-up at the segment boundary from the child's authoritative
# `claude -p --output-format json` total_cost_usd, or forfeited (max of reserve
# and observed JSONL cost) when the child died before flushing that record.
# FR-12: SELF_CONTINUE:THRASH halts after --thrash-threshold no-progress
# segments (unattended-only). The child inherits the hard limits as env vars
# (ORCHESTRATOR_UNATTENDED / _MAX_BUDGET_USD / _BUDGET_REMAINING_USD /
# _WALL_CLOCK_DEADLINE_EPOCH / _MAX_CONTINUATIONS) so it can self-abort; P07's
# instruments read the same names.
#
# Unattended dotfiles under <milestone-dir> (all atomic or append-only):
#   .self-continue-budget-ledger    append-only lease ledger (persists across
#                                   runs; cumulative spend binds later runs,
#                                   SC-4). OPERATOR NOTE: reset the budget by
#                                   DELETING this file — there is no reset flag.
#   .self-continue-kill-reason      watchdog's atomic kill-reason handoff
#   .self-continue-segment-result.json  the segment's captured stdout/stderr
#                                       (the child's JSON result is parsed here)
#
# Emits (stdout):
#   SELF_CONTINUE:SCHEDULED continuation=<N> progress=<P> phase=<ph>
#   SELF_CONTINUE:TERMINAL outcome=<o> decision=<d> continuations=<N> progress=<P>
#   SELF_CONTINUE:CHILD_ABORT rc=<rc> continuations=<N> progress=<P>
#   SELF_CONTINUE:CAP_REACHED continuations=<N> progress=<P>
#   SELF_CONTINUE:STOPPED reason=stop-file continuations=<N> progress=<P>
#   SELF_CONTINUE:REJECT reason=milestone-dir-charset
#   SELF_CONTINUE:REFUSE reason=caps-unset missing=<csv>       (unattended, FR-13)
#   SELF_CONTINUE:REFUSE reason=caps-invalid invalid=<csv>     (unattended, FR-13)
#   SELF_CONTINUE:BUDGET_EXCEEDED stage=<pre-spawn|mid-segment> ...  (unattended)
#   SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=<pre-spawn|mid-segment> ... (unattended)
#   SELF_CONTINUE:STOPPED reason=stop-file stage=mid-segment ...    (unattended)
#   SELF_CONTINUE:THRASH no_progress_segments=<n> threshold=<n> ... (unattended)
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
# M046 P04 unattended-envelope flags (all inert unless --unattended is set).
UNATTENDED=false; MAX_CONT_SET=false; BUDGET_USD=""; WALL_S=""
RESERVE_USD="1.00"; THRASH_N=2; POLL_S=1; COST_LOG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --max-continuations) MAX_CONT="$2"; MAX_CONT_SET=true; shift 2 ;;
    --min-interval) MIN_INTERVAL="$2"; shift 2 ;;
    --armed) ARMED="$2"; shift 2 ;;
    --stop-file) STOP_FILE="$2"; shift 2 ;;
    --auto-cmd) AUTO_CMD="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --unattended) UNATTENDED=true; shift ;;
    --max-budget-usd) BUDGET_USD="$2"; shift 2 ;;
    --max-wall-clock-s) WALL_S="$2"; shift 2 ;;
    --segment-reserve-usd) RESERVE_USD="$2"; shift 2 ;;
    --thrash-threshold) THRASH_N="$2"; shift 2 ;;
    --watchdog-poll-s) POLL_S="$2"; shift 2 ;;
    --cost-log) COST_LOG="$2"; shift 2 ;;
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
  elif [ "$UNATTENDED" = "true" ]; then
    # FR-8: the child emits its authoritative cost as JSON so the segment
    # boundary can true-up the ledger from total_cost_usd.
    set -- claude -p --output-format json "orchestrator:auto $MILESTONE_DIR"
  else
    set -- claude -p "orchestrator:auto $MILESTONE_DIR"
  fi
  if [ "$UNATTENDED" = "true" ]; then
    # FR-7/FR-10/D016: background the child, pass the hard limits in as env
    # (the child may self-abort; P07's instruments read the same names),
    # capture stdout+stderr into RESULT_FILE for the JSON true-up, and run a
    # foreground envelope_watchdog that SIGKILLs on stop-file / wall-clock /
    # cost-derived budget. The pre-spawn block set SEG_SPENT_BEFORE,
    # SEG_REMAINING_USD, and COST_BASELINE_LINES.
    : > "$RESULT_FILE"
    ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
    ORCHESTRATOR_UNATTENDED=1 \
    ORCHESTRATOR_MAX_BUDGET_USD="$BUDGET_USD" \
    ORCHESTRATOR_BUDGET_REMAINING_USD="$SEG_REMAINING_USD" \
    ORCHESTRATOR_WALL_CLOCK_DEADLINE_EPOCH="$DEADLINE_EPOCH" \
    ORCHESTRATOR_MAX_CONTINUATIONS="$MAX_CONT" \
      "$@" > "$RESULT_FILE" 2>&1 &
    CHILD_PID=$!
    envelope_watchdog "$CHILD_PID" "$POLL_S" "$STOP_FILE" "$DEADLINE_EPOCH" \
      "$BUDGET_USD" "$SEG_SPENT_BEFORE" "$COST_LOG" "$COST_BASELINE_LINES" \
      "$REASON_FILE" "$RUN_START_EPOCH"
    wait "$CHILD_PID" && CHILD_RC=0 || CHILD_RC=$?
  else
    ORCHESTRATOR_SELF_CONTINUE_MARKER=1 "$@" >/dev/null 2>&1 || CHILD_RC=$?
  fi
  return 0
}

log_event() { [ -n "$LOG" ] && printf '%s\n' "$1" >> "$LOG"; return 0; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRANCH="$SCRIPT_DIR/self-continue-branch.sh"
OUTCOME_FILE="$MILESTONE_DIR/.self-continue-outcome"

# M046 P04: source the unattended-envelope library (zero side effects at source
# time — defines functions only) and resolve the envelope's dotfile paths.
# shellcheck disable=SC1090
. "$SCRIPT_DIR/unattended-envelope.sh"
REASON_FILE="$MILESTONE_DIR/.self-continue-kill-reason"
LEDGER="$MILESTONE_DIR/.self-continue-budget-ledger"
RESULT_FILE="$MILESTONE_DIR/.self-continue-segment-result.json"
[ -n "$COST_LOG" ] || COST_LOG="$MILESTONE_DIR/execution-log.jsonl"

# FR-13 fail-closed refuse-to-start gate (SC-8): under --unattended the driver
# ITSELF (not a CLI wrapper) refuses to start unless all three hard caps are
# explicitly set and numeric. On refusal: exit 2, no ledger write, no spawn.
# Runs BEFORE the capability probe and BEFORE the loop.
if [ "$UNATTENDED" = "true" ]; then
  _caps="$(envelope_caps_problems "$BUDGET_USD" "$MAX_CONT_SET" "$MAX_CONT" "$WALL_S")"
  if [ "$_caps" != "ok" ]; then
    echo "SELF_CONTINUE:REFUSE reason=$_caps"
    echo "self-continue-drive.sh: --unattended requires explicit --max-budget-usd, --max-continuations, and --max-wall-clock-s (fail-closed, FR-13): $_caps" >&2
    exit 2
  fi
  RUN_START_EPOCH="$(date +%s)"
  DEADLINE_EPOCH=$((RUN_START_EPOCH + WALL_S))
  envelope_ledger_init "$LEDGER" "$BUDGET_USD" "$WALL_S" "$MAX_CONT"
  rm -f "$REASON_FILE"
fi

HEADLESS="$(bash "$REPO_ROOT/dispatch/detect-capabilities.sh" 2>/dev/null | grep -E '^headless_reentry=' | head -n1 | sed 's/^headless_reentry=//')"
[ -n "$HEADLESS" ] || HEADLESS=false

cont=0; progress=0; last_phase=""; no_prog=0
while :; do
  if [ -n "$STOP_FILE" ] && [ -f "$STOP_FILE" ]; then
    echo "SELF_CONTINUE:STOPPED reason=stop-file continuations=$cont progress=$progress"; exit 0
  fi
  if [ "$cont" -ge "$MAX_CONT" ]; then
    log_event "{\"type\":\"self_continue_cap_reached\",\"continuations\":$cont,\"progress\":$progress}"
    echo "SELF_CONTINUE:CAP_REACHED continuations=$cont progress=$progress"; exit 0
  fi
  # M046 P04 pre-spawn envelope checks (D016 between-segment ceiling + FR-8
  # reserve-then-spend). Reserve is written to disk BEFORE the spawn so a
  # driver crash between reserve and reconcile leaves the reserve SPENT.
  if [ "$UNATTENDED" = "true" ]; then
    _now="$(date +%s)"
    if [ "$_now" -ge "$DEADLINE_EPOCH" ]; then
      log_event "{\"type\":\"self_continue_wall_clock\",\"stage\":\"pre-spawn\",\"elapsed_s\":$((_now-RUN_START_EPOCH)),\"cap_s\":$WALL_S,\"continuations\":$cont,\"progress\":$progress}"
      echo "SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=pre-spawn elapsed_s=$((_now-RUN_START_EPOCH)) cap_s=$WALL_S continuations=$cont progress=$progress"
      exit 0
    fi
    SEG_SPENT_BEFORE="$(envelope_spent_total "$LEDGER")"
    if awk -v s="$SEG_SPENT_BEFORE" -v r="$RESERVE_USD" -v c="$BUDGET_USD" \
         'BEGIN { exit !(s + 0 + r + 0 > c + 0) }'; then
      log_event "{\"type\":\"self_continue_budget\",\"stage\":\"pre-spawn\",\"spent\":\"$SEG_SPENT_BEFORE\",\"reserve\":\"$RESERVE_USD\",\"cap\":\"$BUDGET_USD\",\"continuations\":$cont,\"progress\":$progress}"
      echo "SELF_CONTINUE:BUDGET_EXCEEDED stage=pre-spawn spent=$SEG_SPENT_BEFORE reserve=$RESERVE_USD cap=$BUDGET_USD continuations=$cont progress=$progress"
      exit 0
    fi
    SEG_ID="$(envelope_next_segment "$LEDGER")"
    envelope_reserve "$LEDGER" "$SEG_ID" "$RESERVE_USD"
    SEG_REMAINING_USD="$(awk -v c="$BUDGET_USD" -v s="$SEG_SPENT_BEFORE" 'BEGIN { printf "%.6f", c - s }')"
    COST_BASELINE_LINES=0
    if [ -f "$COST_LOG" ]; then COST_BASELINE_LINES="$(wc -l < "$COST_LOG" | tr -d ' ')"; fi
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
  # M046 P04 segment-boundary reconcile + envelope-kill terminals. Reconcile
  # FIRST (ledger complete at terminal time): true-up from the child's JSON
  # total_cost_usd, else forfeit max(reserve, observed JSONL cost). Then, BEFORE
  # the marker/STALLED/CHILD_ABORT emission path, map any watchdog kill-reason
  # to its distinct terminal so an envelope kill takes precedence over the
  # generic CHILD_ABORT line. The P02 CHILD_ABORT-marker block above is
  # untouched — only the driver's terminal line changes for envelope kills.
  if [ "$UNATTENDED" = "true" ]; then
    _actual="$(envelope_parse_total_cost "$RESULT_FILE")"
    if [ -n "$_actual" ]; then
      envelope_reconcile "$LEDGER" "$SEG_ID" "$_actual" "total_cost_usd"
    else
      _obs="$(envelope_observed_cost "$COST_LOG" "$COST_BASELINE_LINES")"
      _forfeit="$(awk -v r="$RESERVE_USD" -v o="$_obs" 'BEGIN { printf "%.6f", (o + 0 > r + 0 ? o + 0 : r + 0) }')"
      envelope_forfeit "$LEDGER" "$SEG_ID" "$_forfeit" "unreconciled"
    fi
    if [ -f "$REASON_FILE" ]; then
      _reason_line="$(cat "$REASON_FILE")"; rm -f "$REASON_FILE"
      _reason="$(printf '%s' "$_reason_line" | awk '{print $1}')"
      _rest="$(printf '%s' "$_reason_line" | awk '{$1=""; sub(/^ /,""); print}')"
      _spent_now="$(envelope_spent_total "$LEDGER")"
      case "$_reason" in
        budget-exceeded)
          log_event "{\"type\":\"self_continue_budget\",\"stage\":\"mid-segment\",\"spent\":\"$_spent_now\",\"detail\":\"$_rest\",\"cap\":\"$BUDGET_USD\",\"continuations\":$cont,\"progress\":$progress}"
          echo "SELF_CONTINUE:BUDGET_EXCEEDED stage=mid-segment spent=$_spent_now $_rest cap=$BUDGET_USD continuations=$cont progress=$progress"
          exit 0 ;;
        wall-clock-exceeded)
          log_event "{\"type\":\"self_continue_wall_clock\",\"stage\":\"mid-segment\",\"detail\":\"$_rest\",\"continuations\":$cont,\"progress\":$progress}"
          echo "SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=mid-segment $_rest continuations=$cont progress=$progress"
          exit 0 ;;
        stop-file)
          log_event "{\"type\":\"self_continue_stopped\",\"reason\":\"stop-file\",\"stage\":\"mid-segment\",\"continuations\":$cont,\"progress\":$progress}"
          echo "SELF_CONTINUE:STOPPED reason=stop-file stage=mid-segment continuations=$cont progress=$progress"
          exit 0 ;;
      esac
    fi
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
      _prog_before=$progress
      if [ -n "$PHASE" ] && [ "$PHASE" != "$last_phase" ]; then
        progress=$((progress+1)); last_phase="$PHASE"
      fi
      # M046 P04 FR-12 THRASH halt (unattended-only): a continue-class outcome
      # that did NOT advance the phase word is a no-progress segment; after
      # --thrash-threshold consecutive no-progress segments halt INSTEAD of
      # scheduling, well before the generous continuation/budget caps.
      if [ "$UNATTENDED" = "true" ]; then
        if [ "$progress" -ne "$_prog_before" ]; then no_prog=0; else no_prog=$((no_prog+1)); fi
        if [ "$no_prog" -ge "$THRASH_N" ]; then
          log_event "{\"type\":\"self_continue_thrash\",\"no_progress_segments\":$no_prog,\"threshold\":$THRASH_N,\"continuations\":$cont,\"progress\":$progress}"
          echo "SELF_CONTINUE:THRASH no_progress_segments=$no_prog threshold=$THRASH_N continuations=$cont progress=$progress"
          exit 0
        fi
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
