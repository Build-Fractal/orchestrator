#!/usr/bin/env bash
# scripts/engine/cost-estimate.sh — M027 P01/T01 predictive cost estimator.
#
# Sourceable bash library + CLI. Given a task description, emits a per-tier
# (Quick / Standard / Full) paired cost+quality table in well under 100 ms
# with zero LLM tokens. The library function cost_estimate_per_tier is the
# load-bearing entry point used by both this script's CLI and by P01/T02's
# intensity-recommend.sh cost-annotation hook.
#
# Library contract:
#   cost_estimate_resolve_model
#       Prints the model id used for cost estimation. Honors
#       ORCH_COST_ESTIMATE_MODEL env override; else asks pricing.sh to
#       resolve the alias 'default'; else falls back to the hard-coded
#       project primary 'claude-opus-4-7' (matches CLAUDE.md Opus 4.7).
#
#   cost_estimate_recommend "<description>"
#       Prints exactly one of: quick | standard | full. Forks
#       scripts/engine/intensity-recommend.sh, parses its 'intensity='
#       line, lowercases it via tr (no bash 4 lowercase op per CON-7).
#       On any failure (script absent, parse miss) prints 'standard' as
#       safe default and emits a structured WARN: line to stderr.
#       Honors INTENSITY_RECOMMEND_FAST_PATH=1 to short-circuit when
#       callers (e.g. T02's recommendation hook) already have the value.
#
#   cost_estimate_per_tier "<description>" [--format text|json]
#       Emits a per-tier cost+quality block for Quick / Standard / Full.
#       Reads the module-scope variable _CE_RECOMMENDED to mark the
#       recommended row. Library callers that already have a recommendation
#       (e.g. T02) set _CE_RECOMMENDED themselves to skip the inner
#       intensity-recommend.sh fork. CLI mode sets it via
#       cost_estimate_recommend before calling.
#
# Predictive Goodhart pairing (FR-20 / CON-4 / SC-18):
#   Every output row that carries a cost cell also carries a quality-
#   semantics cell on the same row. The text renderer refuses to drop
#   the QUALITY column. When pricing data is unavailable, cost cells
#   render '(unavailable)' but the QUALITY column still renders.
#
# Char-quartile token approximation (M019 AD-1):
#   input_tokens  = chars_to_tokens_quartile( description_chars + per_tier_overhead )
#   output_tokens = per-tier hard-coded budget
#   Per-tier constants are tuned by eye against the M019 baseline and
#   may be revisited once Tier 3 runtime-actuals lands. See D027 for
#   the +/-20% accuracy disclaimer.
#
# Latency budget (FR-22 / CON-9 / SC-15): < 100 ms wall-clock.
#   - pricing.sh sourced once at the top, re-source guard prevents repeats.
#   - per-tier loop calls pricing_estimate_cost_usd directly (bash function,
#     no fork, no jq, no yq).
#   - text output emitted via a single printf block.
#   - the optional intensity-recommend.sh fork is the dominant cost; T04
#     perf verifier scripts the call with _CE_RECOMMENDED=standard pre-set
#     so the inner fork is bypassed.
#
# Zero-LLM-token discipline (FR-21 / CON-6):
#   bash + sourced pricing.sh only. No LLM-call markers, dispatch-adapter
#   filename references, dispatch-task helper invocations, or sub-agent
#   spawn primitives appear anywhere in this file. The T04 zero-LLM-token
#   verifier greps the whole file body; literal tokens are intentionally
#   not spelled out here so the verifier regex stays clean. See M027/P00
#   T01 for the precedent of neutralizing forbidden-construct prose.
#
# bash 3.2 compat (CON-7):
#   No associative-array declarations, no array-from-stdin builtins, no
#   string-stdin redirection, no inline process redirection, no merged
#   stdout-stderr shorthand, no bash-4 case-folding parameter expansion.
#   Parallel indexed arrays are used wherever associative arrays would
#   otherwise be the natural fit. Comments deliberately avoid spelling
#   the forbidden tokens so the T04 verifier regex stays clean — see
#   M027/P00 T01 for the precedent.
#
# Read-only invariant (CON-1 / FR-12):
#   The estimator emits to stdout only; it does not write to any project
#   file, including execution-log.jsonl. The T04 read-only verifier runs
#   git diff --quiet after invocation.
#
# MEM004 emitter-internal carve-out applies: pipes / $() / awk are
# permitted *inside* this script. The AD-19 single-script-file shape
# rule binds only Check: commands in task and phase plans.

set -u

# --- Re-source guard -------------------------------------------------------
[ -n "${_COST_ESTIMATE_SH_SOURCED:-}" ] && return 0 2>/dev/null || true
_COST_ESTIMATE_SH_SOURCED=1

# --- Project root resolution ----------------------------------------------
# Mirrors pricing.sh _pricing_project_root pattern. Bash 3.2 safe.
_ce_script_src="${BASH_SOURCE[0]}"
_ce_script_dir="$(cd "$(dirname "$_ce_script_src")" && pwd)"
_CE_REPO_ROOT="$(cd "$_ce_script_dir/../.." && pwd)"

# --- Source pricing.sh once ------------------------------------------------
# Bare '.' builtin with absolute path. No subshell wrapping. The pricing.sh
# re-source guard makes this a no-op on subsequent loads.
. "$_CE_REPO_ROOT/scripts/lib/pricing.sh"

# --- Per-tier constants ----------------------------------------------------
# Parallel indexed arrays (bash 3.2: no associative arrays). Index 0/1/2
# correspond to Quick/Standard/Full. Overhead char counts are the prompt
# scaffolding the orchestrator wraps around the user description (recipe
# template + frontmatter + boilerplate). Output token budgets reflect the
# typical per-tier completion size observed in M019 runtime samples.
# Tuned by eye against M019 baseline; see D027 +/-20% disclaimer. Output
# token approximation method is the M019 AD-1 char-quartile model.
_CE_TIERS_NAME_0="quick";    _CE_TIERS_LABEL_0="Quick";    _CE_TIERS_OVERHEAD_0=800;   _CE_TIERS_OUT_0=1500;   _CE_TIERS_QUALITY_0="best-effort"
_CE_TIERS_NAME_1="standard"; _CE_TIERS_LABEL_1="Standard"; _CE_TIERS_OVERHEAD_1=2400;  _CE_TIERS_OUT_1=4000;   _CE_TIERS_QUALITY_1="self-review"
_CE_TIERS_NAME_2="full";     _CE_TIERS_LABEL_2="Full";     _CE_TIERS_OVERHEAD_2=6800;  _CE_TIERS_OUT_2=12000;  _CE_TIERS_QUALITY_2="adversarial-gate"

# Module-scope recommendation slot. Library callers (T02) set this directly
# to skip the inner intensity-recommend.sh fork. CLI mode sets it via
# cost_estimate_recommend.
_CE_RECOMMENDED="${_CE_RECOMMENDED:-}"

# --- Library: model resolver ----------------------------------------------
cost_estimate_resolve_model() {
  if [ -n "${ORCH_COST_ESTIMATE_MODEL:-}" ]; then
    printf '%s\n' "$ORCH_COST_ESTIMATE_MODEL"
    return 0
  fi
  local resolved
  resolved="$(pricing_resolve_alias "default" 2>/dev/null || true)"
  # pricing_resolve_alias prints the input verbatim when no alias matches;
  # treat that as a miss (we asked for 'default' specifically).
  if [ -n "$resolved" ] && [ "$resolved" != "default" ]; then
    printf '%s\n' "$resolved"
    return 0
  fi
  printf '%s\n' "claude-opus-4-7"
}

# --- Library: intensity recommender ---------------------------------------
cost_estimate_recommend() {
  local description="${1:-}"
  if [ -z "$description" ]; then
    printf 'WARN: cost-estimate fallback recommendation=standard reason=empty-description\n' >&2
    printf '%s\n' "standard"
    return 0
  fi

  # Fast-path: caller has already classified and is just sourcing us for
  # cost numbers. Prevents recursive forks from T02's recommendation hook.
  if [ "${INTENSITY_RECOMMEND_FAST_PATH:-}" = "1" ] && [ -n "${_CE_RECOMMENDED:-}" ]; then
    printf '%s\n' "$_CE_RECOMMENDED"
    return 0
  fi

  local script="$_CE_REPO_ROOT/scripts/engine/intensity-recommend.sh"
  if [ ! -r "$script" ]; then
    printf 'WARN: cost-estimate fallback recommendation=standard reason=script-missing\n' >&2
    printf '%s\n' "standard"
    return 0
  fi

  local raw line lower
  raw="$(bash "$script" --description "$description" 2>/dev/null || true)"
  if [ -z "$raw" ]; then
    printf 'WARN: cost-estimate fallback recommendation=standard reason=empty-output\n' >&2
    printf '%s\n' "standard"
    return 0
  fi

  line="$(printf '%s\n' "$raw" | grep -E '^intensity=' | head -n 1 | sed -E 's/^intensity=//')"
  if [ -z "$line" ]; then
    printf 'WARN: cost-estimate fallback recommendation=standard reason=parse-failed\n' >&2
    printf '%s\n' "standard"
    return 0
  fi

  # bash 3.2: lowercase via tr (no bash-4 case-folding parameter expansion).
  lower="$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    quick|standard|full)
      printf '%s\n' "$lower"
      return 0
      ;;
  esac

  printf 'WARN: cost-estimate fallback recommendation=standard reason=unknown-tier:%s\n' "$lower" >&2
  printf '%s\n' "standard"
  return 0
}

# --- Library: per-tier estimator ------------------------------------------
cost_estimate_per_tier() {
  local description="${1:-}"
  shift || true

  local format="text"
  while [ $# -gt 0 ]; do
    case "$1" in
      --format)
        format="${2:-text}"
        shift 2 || break
        ;;
      --format=*)
        format="${1#--format=}"
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
  case "$format" in
    text|json) ;;
    *) format="text" ;;
  esac

  local desc_chars=${#description}
  local model
  model="$(cost_estimate_resolve_model)"

  local recommended="${_CE_RECOMMENDED:-standard}"
  case "$recommended" in
    quick|standard|full) ;;
    *) recommended="standard" ;;
  esac

  # Per-tier token counts via bash arithmetic — chars_to_tokens_quartile is
  # a tiny wrapper around int division so we inline it here to avoid 3
  # function-call frames inside the loop body.
  local quick_in std_in full_in
  local quick_out="$_CE_TIERS_OUT_0"
  local std_out="$_CE_TIERS_OUT_1"
  local full_out="$_CE_TIERS_OUT_2"
  quick_in=$(( (desc_chars + _CE_TIERS_OVERHEAD_0) / 4 ))
  std_in=$(( (desc_chars + _CE_TIERS_OVERHEAD_1) / 4 ))
  full_in=$(( (desc_chars + _CE_TIERS_OVERHEAD_2) / 4 ))

  # CON-9 latency optimization: the naive shape calls
  # pricing_estimate_cost_usd 3 times (each forks awk twice — alias
  # resolve + rates lookup — plus one final awk multiply). On the bash
  # interpreter that is ~33 ms/tier == ~100 ms just for cost math, well
  # over the FR-22 100 ms budget. We collapse this into:
  #   1. One pricing_resolve_alias call (single awk pass over YAML).
  #   2. One pricing_lookup_rates call (single awk pass over YAML).
  #   3. One awk BEGIN block that computes + formats all 3 costs.
  # Net: 3 awk forks total instead of 9.
  local quick_cost="" std_cost="" full_cost=""
  local quick_cost_text="" std_cost_text="" full_cost_text=""
  local quick_warn="" std_warn="" full_warn=""

  local has_pricing=1
  if ! pricing_file_present; then
    has_pricing=0
  fi
  local is_stale=0
  if pricing_is_stale; then
    is_stale=1
  fi

  if [ "$has_pricing" = "0" ]; then
    quick_warn="pricing-missing"; std_warn="pricing-missing"; full_warn="pricing-missing"
  elif [ "$is_stale" = "1" ]; then
    quick_warn="pricing-stale"; std_warn="pricing-stale"; full_warn="pricing-stale"
  else
    local resolved rates in_rate out_rate
    resolved="$(pricing_resolve_alias "$model" 2>/dev/null || true)"
    [ -n "$resolved" ] || resolved="$model"
    rates="$(pricing_lookup_rates "$resolved" 2>/dev/null || true)"
    if [ -z "$rates" ]; then
      local nr="no-rate:${model}"
      quick_warn="$nr"; std_warn="$nr"; full_warn="$nr"
    else
      in_rate="${rates%% *}"
      out_rate="${rates##* }"
      # Single awk pass: emit 6 lines (3 raw 8-decimal + 3 6-decimal text).
      # Bash 3.2: parse the 6-line block via a positional read loop.
      local awk_out
      awk_out="$(awk -v qi="$quick_in" -v qo="$quick_out" \
                     -v si="$std_in"   -v so="$std_out" \
                     -v fi="$full_in"  -v fo="$full_out" \
                     -v ir="$in_rate"  -v or="$out_rate" \
        'BEGIN {
           q = (qi*ir + qo*or) / 1000000
           s = (si*ir + so*or) / 1000000
           f = (fi*ir + fo*or) / 1000000
           printf "%.8f\n", q
           printf "%.8f\n", s
           printf "%.8f\n", f
           printf "%.6f\n", q
           printf "%.6f\n", s
           printf "%.6f\n", f
         }')"
      # Parallel-array unpack via positional read (bash 3.2 safe; no
      # bash-4 array-from-stdin builtin).
      local _ce_line _ce_idx=0
      while IFS= read -r _ce_line; do
        case "$_ce_idx" in
          0) quick_cost="$_ce_line" ;;
          1) std_cost="$_ce_line" ;;
          2) full_cost="$_ce_line" ;;
          3) quick_cost_text="$_ce_line" ;;
          4) std_cost_text="$_ce_line" ;;
          5) full_cost_text="$_ce_line" ;;
        esac
        _ce_idx=$(( _ce_idx + 1 ))
      done <<EOF_AWKOUT
$awk_out
EOF_AWKOUT
    fi
  fi

  if [ "$format" = "json" ]; then
    # Single-line JSON. Hand-built printf — no jq dependency. cost_usd
    # renders as bare numeric when present, JSON null when unavailable
    # (Goodhart: pricing_warning carries the reason; quality always
    # renders).
    local q_cost_json s_cost_json f_cost_json
    if [ -n "$quick_cost" ]; then q_cost_json="$quick_cost"; else q_cost_json="null"; fi
    if [ -n "$std_cost" ];   then s_cost_json="$std_cost";   else s_cost_json="null"; fi
    if [ -n "$full_cost" ];  then f_cost_json="$full_cost";  else f_cost_json="null"; fi
    printf '{"recommended":"%s","tiers":{' "$recommended"
    printf '"quick":{"cost_usd":%s,"input_tokens":%s,"output_tokens":%s,"quality":"%s","pricing_warning":"%s"},' \
      "$q_cost_json" "$quick_in" "$quick_out" "$_CE_TIERS_QUALITY_0" "$quick_warn"
    printf '"standard":{"cost_usd":%s,"input_tokens":%s,"output_tokens":%s,"quality":"%s","pricing_warning":"%s"},' \
      "$s_cost_json" "$std_in" "$std_out" "$_CE_TIERS_QUALITY_1" "$std_warn"
    printf '"full":{"cost_usd":%s,"input_tokens":%s,"output_tokens":%s,"quality":"%s","pricing_warning":"%s"}' \
      "$f_cost_json" "$full_in" "$full_out" "$_CE_TIERS_QUALITY_2" "$full_warn"
    printf '}}\n'
    return 0
  fi

  # --- Text format: 3-row Goodhart-paired table, one printf block ---------
  # Columns: TIER  COST_USD  INPUT_TOK  OUTPUT_TOK  QUALITY  RECOMMENDED.
  # Cost cell renders '(unavailable)' when raw is empty; the QUALITY
  # column ALWAYS renders (CON-4: predictive Goodhart pairing — predictive
  # renderer refuses to drop the quality column even on degraded input).
  # The 6-decimal text values were emitted by the single awk pass above;
  # we just substitute the unavailable sentinel where the raw cost is empty.
  local q_cost_text s_cost_text f_cost_text
  if [ -n "$quick_cost" ]; then q_cost_text="$quick_cost_text"; else q_cost_text="(unavailable)"; fi
  if [ -n "$std_cost" ];   then s_cost_text="$std_cost_text";   else s_cost_text="(unavailable)"; fi
  if [ -n "$full_cost" ];  then f_cost_text="$full_cost_text";  else f_cost_text="(unavailable)"; fi

  local q_marker s_marker f_marker
  q_marker=" "; s_marker=" "; f_marker=" "
  case "$recommended" in
    quick) q_marker="*" ;;
    standard) s_marker="*" ;;
    full) f_marker="*" ;;
  esac

  # Single printf block — no per-row fork.
  printf '%-10s %-14s %10s %10s %-18s %s\n' "TIER" "COST_USD" "INPUT_TOK" "OUTPUT_TOK" "QUALITY" "RECOMMENDED"
  printf '%-10s %-14s %10s %10s %-18s %s\n' "$_CE_TIERS_LABEL_0" "$q_cost_text" "$quick_in" "$quick_out" "$_CE_TIERS_QUALITY_0" "$q_marker"
  printf '%-10s %-14s %10s %10s %-18s %s\n' "$_CE_TIERS_LABEL_1" "$s_cost_text" "$std_in"   "$std_out"   "$_CE_TIERS_QUALITY_1" "$s_marker"
  printf '%-10s %-14s %10s %10s %-18s %s\n' "$_CE_TIERS_LABEL_2" "$f_cost_text" "$full_in"  "$full_out"  "$_CE_TIERS_QUALITY_2" "$f_marker"

  # If any tier degraded, emit a one-line override hint before the trailer.
  # FR-24: recommendation still flows even on pricing degradation.
  if [ -n "$quick_warn$std_warn$full_warn" ]; then
    printf 'override: pass --intensity quick|standard|full to dispatch with explicit tier (pricing degraded: %s)\n' \
      "${std_warn:-${quick_warn:-${full_warn}}}"
  fi

  # D027 verbatim accuracy trailer. Last line of the text output.
  printf 'estimates +/-~20%%; see commands/cost.md#accuracy\n'
  return 0
}

# --- CLI mode --------------------------------------------------------------
_ce_print_help() {
  cat <<'HELP'
Usage: cost-estimate.sh --description "<text>" [--format text|json] [--help]

  --description "<text>"   Required. The task description used for the
                           predictive cost+quality table.
  --format text|json       Output format. Default: text.
  --help, -h               Print this help and exit 0.

Output (text format):
  3-row Goodhart-paired table — one row per Quick/Standard/Full tier with
  COST_USD, INPUT_TOK, OUTPUT_TOK, QUALITY, RECOMMENDED columns. Cost
  cells render '(unavailable)' on pricing degradation; the QUALITY column
  always renders (FR-20 / CON-4 predictive Goodhart pairing). The trailer
  'estimates +/-~20%; see commands/cost.md#accuracy' is the last line.

Output (json format):
  Single-line JSON object: {"recommended":"<tier>","tiers":{...}} where
  each tier carries cost_usd / input_tokens / output_tokens / quality /
  pricing_warning. cost_usd is JSON null when pricing is unavailable.

Environment variables:
  ORCH_COST_ESTIMATE_MODEL    Override the model id used for cost
                              calculation. Default: pricing.sh alias
                              'default', else 'claude-opus-4-7'.
  ORCH_PRICING_FILE           Forwarded to pricing.sh. Pointing at a
                              missing path triggers graceful degradation.
  INTENSITY_RECOMMEND_FAST_PATH=1
                              Skip the intensity-recommend.sh fork when
                              the caller already supplies _CE_RECOMMENDED
                              (used by P01/T02 hook to bound latency).

Exit codes:
  0   Success (including pricing-degraded paths — never abort, CON-5).
  2   Usage error (missing --description, unknown flag).
HELP
}

_ce_main() {
  local description=""
  local format="text"

  while [ $# -gt 0 ]; do
    case "$1" in
      --description)
        description="${2:-}"
        shift 2 || break
        ;;
      --description=*)
        description="${1#--description=}"
        shift
        ;;
      --format)
        format="${2:-text}"
        shift 2 || break
        ;;
      --format=*)
        format="${1#--format=}"
        shift
        ;;
      -h|--help)
        _ce_print_help
        return 0
        ;;
      *)
        printf 'ERROR: unknown flag: %s\n' "$1" >&2
        _ce_print_help >&2
        return 2
        ;;
    esac
  done

  if [ -z "$description" ]; then
    printf 'ERROR: --description "<text>" is required\n' >&2
    _ce_print_help >&2
    return 2
  fi

  case "$format" in
    text|json) ;;
    *)
      printf 'ERROR: --format must be one of: text json (got: %s)\n' "$format" >&2
      return 2
      ;;
  esac

  # Resolve recommended tier (forks intensity-recommend.sh; bounded by
  # INTENSITY_RECOMMEND_FAST_PATH for downstream callers).
  _CE_RECOMMENDED="$(cost_estimate_recommend "$description")"

  cost_estimate_per_tier "$description" --format "$format"
  return 0
}

# --- CLI entry-point guard -------------------------------------------------
# Sourceable: when the file is sourced, BASH_SOURCE[0] != $0 and we return
# 0 with no output. CLI: when invoked directly, run _ce_main with the
# caller's argv.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  _ce_main "$@"
  exit $?
fi
