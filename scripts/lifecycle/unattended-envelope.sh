#!/usr/bin/env sh
# unattended-envelope.sh -- M046 P04 unattended-envelope function library.
#
# SOURCEABLE LIBRARY: sourcing this file defines functions only -- zero side
# effects at source time. The driver (self-continue-drive.sh, T02) sources it
# unconditionally; FR-17 requires the attended path byte-behavior unchanged,
# so nothing here may execute, read config, or write files at source time.
#
# Scope: FR-7 (mid-segment cost-derived watchdog), FR-8 (reserve-then-spend
# budget-lease ledger with segment-boundary true-up from the child's
# authoritative `claude -p --output-format json` total_cost_usd), FR-10
# (stop-file kill), FR-12 (thrash-halt support surfaces), FR-13 (fail-closed
# caps validation -- unset/invalid caps are a refusal, never a default), and
# the D016 wall-clock resolution (mid-segment wall-clock kill and the
# driver's pre-spawn ceiling check both derive from one deadline epoch).
#
# Cost-source split (P01 #Q-4, CADENCE-FINDINGS.md): JSONL unit_close records
# supply mid-segment GRAIN (estimated_cost_usd is a NULLABLE advisory
# estimate -- null contributes 0); the exiting child's JSON result supplies
# TRUTH (total_cost_usd) for the segment-boundary ledger true-up.
#
# Ledger line vocabulary (append-only; the ledger persists across runs and
# cumulative spend binds later runs, SC-4):
#   run_start ts=<ISO8601-UTC> cap_usd=<x> wall_clock_s=<n> max_continuations=<n>
#   reserve segment=<n> amount_usd=<x> ts=<ISO>
#   reconcile segment=<n> actual_usd=<x> source=<s> ts=<ISO>
#   forfeit segment=<n> amount_usd=<x> source=<s> ts=<ISO>
#
# Spend rule (FR-8, fail-closed): a reconcile or forfeit line for segment N
# OVERRIDES that segment's reserve; a bare reserve (no reconcile/forfeit yet)
# counts at its full reserve amount -- an unreconciled reserve is SPENT,
# never free.
#
# Side effects: all functions are side-effect-free (stdout-only) EXCEPT the
# explicitly-writing ones: envelope_ledger_init / envelope_reserve /
# envelope_reconcile / envelope_forfeit (single-line appends to the ledger;
# the safety property is the reserve-BEFORE-spawn ordering enforced by the
# driver call sequence, not append atomicity) and envelope_write_kill_reason
# (ATOMIC temp+rename, P02 discipline -- a SIGKILL can land at any instant,
# so the P02 torn-marker guarantee extends to the kill-reason file).
# envelope_watchdog writes ONLY the kill-reason file, and only via
# envelope_write_kill_reason, before SIGKILLing the child.
#
# Portability: POSIX sh (bash 3.2 and dash safe) -- no arrays, no declare -A,
# no process substitution, no jq. Float math via awk only; never shell
# arithmetic on decimals. No function reads config files -- the envelope is
# flag-driven only (FR-6).

# _envelope_ts
#   stdout: current UTC timestamp, ISO 8601 (MEM008 convention).
_envelope_ts() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# _envelope_csv_append <csv> <item>
#   stdout: <csv>,<item> (or just <item> when <csv> is empty).
_envelope_csv_append() {
  if [ -z "$1" ]; then
    printf '%s' "$2"
  else
    printf '%s,%s' "$1" "$2"
  fi
}

# _envelope_is_pos_decimal <value>
#   Returns 0 iff <value> is a positive decimal number (e.g. 5, 5.00, 0.30).
_envelope_is_pos_decimal() {
  printf '%s' "$1" | grep -Eq '^[0-9]+(\.[0-9]+)?$' || return 1
  awk -v v="$1" 'BEGIN { exit !(v + 0 > 0) }'
}

# _envelope_is_pos_int <value>
#   Returns 0 iff <value> is a positive integer (> 0).
_envelope_is_pos_int() {
  printf '%s' "$1" | grep -Eq '^[0-9]+$' || return 1
  awk -v v="$1" 'BEGIN { exit !(v + 0 > 0) }'
}

# envelope_caps_problems <budget_usd> <max_cont_set:true|false> <max_cont> <wall_s>
#   stdout exactly one line:
#     "ok"                                     -- all three caps present and valid
#     "caps-unset missing=<csv>"               -- csv from {budget,continuations,wall-clock}
#     "caps-invalid invalid=<csv>"             -- set but non-numeric or <= 0
#   Unset detection: budget_usd empty; max_cont_set != "true"; wall_s empty.
#   The max_cont VALUE is ignored unless max_cont_set is literally "true" --
#   a silent inherited default (e.g. MAX_CONT=20) is NOT an explicit cap (FR-13).
#   Numeric validation: positive decimal (budget) / positive integer (cont, wall).
#   caps-unset takes precedence over caps-invalid when both classes present.
envelope_caps_problems() {
  _ec_budget=$1
  _ec_cont_set=$2
  _ec_cont=$3
  _ec_wall=$4
  _ec_missing=""
  _ec_invalid=""
  [ -n "$_ec_budget" ] || _ec_missing=$(_envelope_csv_append "$_ec_missing" "budget")
  [ "$_ec_cont_set" = "true" ] || _ec_missing=$(_envelope_csv_append "$_ec_missing" "continuations")
  [ -n "$_ec_wall" ] || _ec_missing=$(_envelope_csv_append "$_ec_missing" "wall-clock")
  if [ -n "$_ec_missing" ]; then
    printf 'caps-unset missing=%s\n' "$_ec_missing"
    return 0
  fi
  _envelope_is_pos_decimal "$_ec_budget" || _ec_invalid=$(_envelope_csv_append "$_ec_invalid" "budget")
  _envelope_is_pos_int "$_ec_cont" || _ec_invalid=$(_envelope_csv_append "$_ec_invalid" "continuations")
  _envelope_is_pos_int "$_ec_wall" || _ec_invalid=$(_envelope_csv_append "$_ec_invalid" "wall-clock")
  if [ -n "$_ec_invalid" ]; then
    printf 'caps-invalid invalid=%s\n' "$_ec_invalid"
    return 0
  fi
  printf 'ok\n'
}

# envelope_ledger_init <ledger> <cap_usd> <wall_s> <max_cont>
#   Appends: run_start ts=<ISO8601-UTC> cap_usd=<x> wall_clock_s=<n> max_continuations=<n>
#   Creates the file if absent. Append-only -- never truncates (the ledger
#   persists across runs; cumulative spend binds later runs, SC-4).
envelope_ledger_init() {
  _el_ledger=$1
  _el_cap=$2
  _el_wall=$3
  _el_cont=$4
  printf 'run_start ts=%s cap_usd=%s wall_clock_s=%s max_continuations=%s\n' \
    "$(_envelope_ts)" "$_el_cap" "$_el_wall" "$_el_cont" >> "$_el_ledger"
}

# envelope_next_segment <ledger>
#   stdout: (count of lines starting with "reserve ") + 1. Missing file -> 1.
envelope_next_segment() {
  _en_ledger=$1
  _en_count=0
  if [ -f "$_en_ledger" ]; then
    _en_count=$(grep -c '^reserve ' "$_en_ledger" 2>/dev/null || true)
  fi
  [ -n "$_en_count" ] || _en_count=0
  printf '%d\n' $((_en_count + 1))
}

# envelope_reserve <ledger> <segment> <amount_usd>
#   Appends: reserve segment=<n> amount_usd=<x> ts=<ISO>
envelope_reserve() {
  _er_ledger=$1
  _er_segment=$2
  _er_amount=$3
  printf 'reserve segment=%s amount_usd=%s ts=%s\n' \
    "$_er_segment" "$_er_amount" "$(_envelope_ts)" >> "$_er_ledger"
}

# envelope_reconcile <ledger> <segment> <actual_usd> <source>
#   Appends: reconcile segment=<n> actual_usd=<x> source=<s> ts=<ISO>
envelope_reconcile() {
  _ec2_ledger=$1
  _ec2_segment=$2
  _ec2_actual=$3
  _ec2_source=$4
  printf 'reconcile segment=%s actual_usd=%s source=%s ts=%s\n' \
    "$_ec2_segment" "$_ec2_actual" "$_ec2_source" "$(_envelope_ts)" >> "$_ec2_ledger"
}

# envelope_forfeit <ledger> <segment> <amount_usd> <source>
#   Appends: forfeit segment=<n> amount_usd=<x> source=<s> ts=<ISO>
envelope_forfeit() {
  _ef_ledger=$1
  _ef_segment=$2
  _ef_amount=$3
  _ef_source=$4
  printf 'forfeit segment=%s amount_usd=%s source=%s ts=%s\n' \
    "$_ef_segment" "$_ef_amount" "$_ef_source" "$(_envelope_ts)" >> "$_ef_ledger"
}

# envelope_spent_total <ledger>
#   stdout: total spent USD as a decimal (e.g. "1.300000").
#   Per-segment rule (FR-8 fail-closed): a reconcile or forfeit line for
#   segment N OVERRIDES that segment's reserve; a bare reserve (no
#   reconcile/forfeit yet) counts at its full reserve amount -- an
#   unreconciled reserve is SPENT, never free.
#   Missing file -> 0. Implemented in one awk pass keyed by segment number.
envelope_spent_total() {
  _es_ledger=$1
  if [ ! -f "$_es_ledger" ]; then
    printf '0\n'
    return 0
  fi
  awk '
    function val(f) { sub(/^[^=]*=/, "", f); return f + 0 }
    function segkey(f) { sub(/^[^=]*=/, "", f); return f }
    $1 == "reserve"   { s = segkey($2); res[s] = val($3); seen[s] = 1 }
    $1 == "reconcile" { s = segkey($2); ovr[s] += val($3); has[s] = 1; seen[s] = 1 }
    $1 == "forfeit"   { s = segkey($2); ovr[s] += val($3); has[s] = 1; seen[s] = 1 }
    END {
      t = 0
      for (s in seen) {
        if (s in has) t += ovr[s]
        else t += res[s]
      }
      printf "%.6f\n", t
    }
  ' "$_es_ledger"
}

# envelope_observed_cost <log_file> <since_lines>
#   stdout: decimal sum of NUMERIC estimated_cost_usd values on lines with
#   NR > since_lines that contain "record_type":"unit_close".
#   "estimated_cost_usd":null contributes 0 (P01: nullable advisory estimates).
#   Missing or empty-path file -> 0. awk match: /"estimated_cost_usd":[0-9][0-9.]*/
#   Key names bound to the production emitter template in
#   scripts/knowledge/write-summary.sh (_ws_emit_unit_close printf).
envelope_observed_cost() {
  _eo_log=$1
  _eo_since=$2
  if [ -z "$_eo_log" ] || [ ! -f "$_eo_log" ]; then
    printf '0\n'
    return 0
  fi
  awk -v since="$_eo_since" '
    NR > since && index($0, "\"record_type\":\"unit_close\"") > 0 {
      if (match($0, /"estimated_cost_usd":[0-9][0-9.]*/)) {
        m = substr($0, RSTART, RLENGTH)
        sub(/^"estimated_cost_usd":/, "", m)
        total += m + 0
      }
    }
    END { printf "%.6f\n", total + 0 }
  ' "$_eo_log"
}

# envelope_parse_total_cost <result_json_file>
#   stdout: the numeric total_cost_usd value, or EMPTY on missing file /
#   missing key / non-numeric value (fail-closed: caller forfeits on empty).
envelope_parse_total_cost() {
  _ep_file=$1
  if [ -z "$_ep_file" ] || [ ! -f "$_ep_file" ]; then
    return 0
  fi
  grep -o '"total_cost_usd"[[:space:]]*:[[:space:]]*[0-9][0-9.]*' "$_ep_file" 2>/dev/null \
    | head -n 1 | sed 's/.*:[[:space:]]*//'
}

# envelope_write_kill_reason <reason_file> <reason_line>
#   ATOMIC write (P02 discipline): printf to "<reason_file>.tmp.$$" then
#   mv -f into place. Same-directory rename. No direct redirect to the target.
envelope_write_kill_reason() {
  _ek_file=$1
  _ek_line=$2
  _ek_tmp="$_ek_file.tmp.$$"
  printf '%s\n' "$_ek_line" > "$_ek_tmp"
  mv -f "$_ek_tmp" "$_ek_file"
}

# envelope_watchdog <child_pid> <poll_s> <stop_file> <deadline_epoch> \
#                   <cap_usd> <spent_before_usd> <cost_log> <cost_baseline_lines> \
#                   <reason_file> [<start_epoch>]
#   Foreground poll loop; returns 0 when the child is no longer alive.
#   Each tick, in order, while `kill -0 <pid>` succeeds:
#     1. stop-file: [ -n <stop_file> ] && [ -f <stop_file> ]
#          -> envelope_write_kill_reason <reason_file> "stop-file"
#     2. wall-clock: now_epoch >= deadline_epoch
#          -> "wall-clock-exceeded elapsed_s=<e> cap_s=<c>" when the optional
#             <start_epoch> is supplied (elapsed_s = now - start,
#             cap_s = deadline - start); without <start_epoch> the elapsed
#             values are not derivable, so the line degrades to
#             "wall-clock-exceeded now_epoch=<n> deadline_epoch=<d>" --
#             the "wall-clock-exceeded" prefix is the binding token either way.
#     3. budget (cost-derived, SC-3): obs = envelope_observed_cost;
#        awk float compare: spent_before + obs >= cap_usd
#          -> "budget-exceeded observed=<obs> spent_before=<s> cap=<c>"
#   On any trigger: write reason FIRST (atomic), then `kill -9 <pid>`, then
#   continue looping until kill -0 fails (the wait/reap happens in the caller).
#   Empty <cost_log> or missing file: budget check contributes obs=0 (the
#   pre-spawn reserve check in the driver is the backstop -- never crash).
#   sleep <poll_s> between ticks. The ONLY file this loop writes is the
#   kill-reason file, and only via envelope_write_kill_reason (atomic).
envelope_watchdog() {
  _ew_pid=$1
  _ew_poll=$2
  _ew_stop=$3
  _ew_deadline=$4
  _ew_cap=$5
  _ew_before=$6
  _ew_log=$7
  _ew_base=$8
  _ew_reason=$9
  _ew_start=${10:-}
  _ew_killed=0
  while kill -0 "$_ew_pid" 2>/dev/null; do
    if [ "$_ew_killed" -eq 0 ]; then
      _ew_trigger=""
      _ew_now=$(date +%s)
      if [ -n "$_ew_stop" ] && [ -f "$_ew_stop" ]; then
        _ew_trigger="stop-file"
      elif [ "$_ew_now" -ge "$_ew_deadline" ]; then
        if [ -n "$_ew_start" ]; then
          _ew_trigger="wall-clock-exceeded elapsed_s=$((_ew_now - _ew_start)) cap_s=$((_ew_deadline - _ew_start))"
        else
          _ew_trigger="wall-clock-exceeded now_epoch=$_ew_now deadline_epoch=$_ew_deadline"
        fi
      else
        _ew_obs=$(envelope_observed_cost "$_ew_log" "$_ew_base")
        if awk -v s="$_ew_before" -v o="$_ew_obs" -v c="$_ew_cap" \
             'BEGIN { exit !(s + 0 + o + 0 >= c + 0) }'; then
          _ew_trigger="budget-exceeded observed=$_ew_obs spent_before=$_ew_before cap=$_ew_cap"
        fi
      fi
      if [ -n "$_ew_trigger" ]; then
        envelope_write_kill_reason "$_ew_reason" "$_ew_trigger"
        kill -9 "$_ew_pid" 2>/dev/null || true
        _ew_killed=1
      fi
    fi
    sleep "$_ew_poll"
  done
  return 0
}
