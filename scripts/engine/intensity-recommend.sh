#!/usr/bin/env bash
# scripts/engine/intensity-recommend.sh — Intensity recommendation engine.
# Combines scope analysis (intensity-analyze.sh) + capability profile
# (detect-capabilities.sh --profile) into a final intensity recommendation
# with confidence and reasoning. Part of M008 Adaptive Intensity Engine
# (FR-001, FR-005, FR-025).
#
# M027/P01/T02 extension: appends a per-tier cost-annotation block in text
# mode (after the 8 byte-stable key=value lines), and adds --format json
# emitting a top-level cost_estimates object per D026.
#
# Usage: intensity-recommend.sh [--analyze-output "text"] [--profile-output "text"]
#                                [--description "text"]
#                                [--format text|json]
#                                [--no-cost-annotation]
#   --analyze-output:       pre-computed output from intensity-analyze.sh
#   --profile-output:       pre-computed output from detect-capabilities.sh --profile
#   --description:          task description (runs intensity-analyze.sh internally)
#   --format text|json:     output shape. Default: text. JSON emits a single-line
#                           object containing the 8 existing fields plus a top-level
#                           cost_estimates object (D026). Unknown values exit 2.
#   --no-cost-annotation:   in text mode, suppress the trailing cost-annotation
#                           block. The 8 byte-stable key=value lines are preserved.
#   If no flags given, reads description from stdin and runs both scripts.
#
# Output (text mode, stdout, key=value):
#   intensity=Quick|Standard|Full
#   confidence=high|medium|low
#   reasoning=<explanation>
#   scope=<from analyze>
#   risk_level=<from analyze>
#   complexity=<from analyze>
#   risk_signals=<from analyze>
#   cap_score=<from profile>
#   # cost estimates (M027/P01)
#   cost_quick_usd=<num-or-empty>
#   cost_quick_in_tokens=<int>
#   cost_quick_out_tokens=<int>
#   cost_standard_usd=<num-or-empty>
#   cost_standard_in_tokens=<int>
#   cost_standard_out_tokens=<int>
#   cost_full_usd=<num-or-empty>
#   cost_full_in_tokens=<int>
#   cost_full_out_tokens=<int>
#   cost_quick_quality=<str>
#   cost_standard_quality=<str>
#   cost_full_quality=<str>
#   cost_pricing_warning=<reason-or-empty>
#
# Output (json mode, single-line JSON, stdout):
#   {"intensity":"...","confidence":"...","reasoning":"...","scope":"...",
#    "risk_level":"...","complexity":"...","risk_signals":"...","cap_score":<int>,
#    "cost_estimates":{"quick":{"cost_usd":<num-or-null>,"input_tokens":<int>,
#                               "output_tokens":<int>,"pricing_warning":"<str>"},
#                      "standard":{...},"full":{...}}}
#
# Constraints:
#   CON-3 (back-compat): the first 8 key=value text lines are byte-identical
#       to pre-T02 output for the same inputs.
#   CON-4 / FR-20 (Goodhart): the cost-annotation block carries quality
#       semantics — every cost-bearing tier row is paired with a
#       cost_<tier>_quality= line in text mode (and a quality field in JSON).
#   CON-6 / FR-21 (zero-token): bash + sourced pricing.sh (transitive only).
#   CON-7 (bash 3.2): no associative-array declarations, no string-stdin
#       redirection, no inline process substitution, no bash-4 case-folding
#       parameter expansion. Comments deliberately avoid spelling the
#       forbidden tokens so the bash32-compat verifier regex stays clean.
#   CON-9 / FR-22 (latency): cost-annotation overhead < 50 ms.
#   D026 (JSON shape): cost_estimates keyed by quick/standard/full with
#       cost_usd, input_tokens, output_tokens, pricing_warning per tier.
#   No-recursion invariant: T02 sets _CE_RECOMMENDED before invoking
#       cost_estimate_per_tier so T01's library does not re-fork this script.
#
# MEM004 emitter-internal carve-out applies: pipes / $() / awk / sed are
# permitted *inside* this script. The AD-19 single-script-file shape rule
# binds only Check: commands in task and phase plans.
#
# Exit: 0 success, 1 error, 2 usage error (unknown --format value).
# Bash 3.2 compatible (NFR-200).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ANALYZE_OUTPUT=""
PROFILE_OUTPUT=""
DESCRIPTION=""
FORMAT="text"
NO_COST_ANNOTATION=0

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --analyze-output)
      ANALYZE_OUTPUT="$2"; shift 2 ;;
    --profile-output)
      PROFILE_OUTPUT="$2"; shift 2 ;;
    --description)
      DESCRIPTION="$2"; shift 2 ;;
    --format)
      FORMAT="$2"; shift 2 ;;
    --format=*)
      FORMAT="${1#--format=}"; shift ;;
    --no-cost-annotation)
      NO_COST_ANNOTATION=1; shift ;;
    *)
      shift ;;
  esac
done

# Validate --format value (text|json only).
case "$FORMAT" in
  text|json) ;;
  *)
    echo "ERROR: --format must be one of: text json (got: $FORMAT)" >&2
    exit 2
    ;;
esac

# If --analyze-output value is an existing file path, read its contents.
# Otherwise treat the value as inline text (as used by verification scripts).
if [[ -n "$ANALYZE_OUTPUT" ]] && [[ -f "$ANALYZE_OUTPUT" ]]; then
  ANALYZE_OUTPUT="$(cat "$ANALYZE_OUTPUT")"
fi
if [[ -n "$PROFILE_OUTPUT" ]] && [[ -f "$PROFILE_OUTPUT" ]]; then
  PROFILE_OUTPUT="$(cat "$PROFILE_OUTPUT")"
fi

# If no analyze output provided, run intensity-analyze.sh
if [[ -z "$ANALYZE_OUTPUT" ]]; then
  if [[ -z "$DESCRIPTION" ]]; then
    if [[ -t 0 ]]; then
      echo "ERROR: no description or analyze output provided." >&2
      exit 1
    fi
    DESCRIPTION="$(cat)"
  fi
  ANALYZE_OUTPUT="$(echo "$DESCRIPTION" | bash "$SCRIPT_DIR/intensity-analyze.sh" 2>/dev/null)"
fi

# If no profile output provided, run detect-capabilities.sh --profile
if [[ -z "$PROFILE_OUTPUT" ]]; then
  PROFILE_OUTPUT="$(bash "$REPO_ROOT/scripts/dispatch/detect-capabilities.sh" --profile 2>/dev/null)"
fi

# --- Parse analyze output ---
# Extract values using grep + cut (no associative arrays)
scope="$(echo "$ANALYZE_OUTPUT" | grep "^scope=" | head -1 | cut -d= -f2)"
risk_level="$(echo "$ANALYZE_OUTPUT" | grep "^risk_level=" | head -1 | cut -d= -f2)"
complexity="$(echo "$ANALYZE_OUTPUT" | grep "^complexity=" | head -1 | cut -d= -f2)"
risk_signals="$(echo "$ANALYZE_OUTPUT" | grep "^risk_signals=" | head -1 | cut -d= -f2-)"
base_intensity="$(echo "$ANALYZE_OUTPUT" | grep "^recommended_intensity=" | head -1 | cut -d= -f2)"

# --- Parse capability profile ---
cap_score="$(echo "$PROFILE_OUTPUT" | grep "^cap_score=" | head -1 | cut -d= -f2)"
cap_score="${cap_score:-0}"

# --- Apply decision matrix ---
intensity="$base_intensity"
confidence="high"

# Risk escalation: risk overrides convenience
if [[ "$risk_level" = "high" ]] && [[ "$intensity" = "Quick" ]]; then
  intensity="Standard"
fi

# Risk + complexity double-escalation
if [[ "$risk_level" = "high" ]] && [[ "$complexity" = "complex" ]]; then
  intensity="Full"
fi

# Specific risk signal escalation (migration, security, auth -> at least Standard)
if [[ "$risk_signals" != "none" ]]; then
  for escalation_signal in "migration" "security" "auth"; do
    if echo "$risk_signals" | grep -qF "$escalation_signal"; then
      if [[ "$intensity" = "Quick" ]]; then
        intensity="Standard"
      fi
      break
    fi
  done
fi

# Confidence adjustment based on capability score
if [[ "$intensity" = "Full" ]] && [[ "$cap_score" -le 1 ]]; then
  confidence="medium"
fi

# --- Build reasoning ---
signal_clause=""
if [[ "$risk_signals" != "none" ]]; then
  signal_clause=" with signals: $risk_signals"
fi

reasoning="${intensity} recommended: scope is ${scope}, risk is ${risk_level}${signal_clause}, complexity is ${complexity}, environment has ${cap_score}/5 capabilities."

# --- Source cost-estimate.sh (M027/P01/T02) ----------------------------------
# Sourced after all argument parsing and analysis is complete, before the
# output block. The library's re-source guard makes repeat loads a no-op.
# We set _CE_RECOMMENDED from our locally-computed intensity to short-circuit
# T01's intensity-recommend.sh fork (no-recursion invariant).
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/engine/cost-estimate.sh"

# Resolve description used for cost estimation. When the operator fed
# pre-computed --analyze-output / --profile-output without --description,
# the char-quartile estimate degrades to overhead-only. Emit a stderr
# WARN per task plan step 4.
cost_desc="$DESCRIPTION"
if [ -z "$cost_desc" ]; then
  echo "WARN: cost-estimate description=empty; estimates use recipe overhead only" >&2
fi

# Set the module-scope recommendation slot. T01's library reads this to skip
# re-recommending. Lowercase via tr (bash 3.2 compat — no bash-4 case-folding).
_CE_RECOMMENDED="$(printf '%s' "$intensity" | tr '[:upper:]' '[:lower:]')"
export _CE_RECOMMENDED
INTENSITY_RECOMMEND_FAST_PATH=1
export INTENSITY_RECOMMEND_FAST_PATH

# Compute per-tier estimates as JSON (T01 library returns a single-line
# self-contained JSON object). Capture stdout; on failure, install a safe
# fallback shell.
cost_json="$(cost_estimate_per_tier "$cost_desc" --format json 2>/dev/null || true)"
if [ -z "$cost_json" ]; then
  echo "WARN: cost-estimate fallback reason=empty-output" >&2
  cost_json='{"recommended":"standard","tiers":{"quick":{"cost_usd":null,"input_tokens":0,"output_tokens":0,"quality":"best-effort","pricing_warning":"fallback"},"standard":{"cost_usd":null,"input_tokens":0,"output_tokens":0,"quality":"self-review","pricing_warning":"fallback"},"full":{"cost_usd":null,"input_tokens":0,"output_tokens":0,"quality":"adversarial-gate","pricing_warning":"fallback"}}}'
fi

# --- Per-tier field extractor (bash 3.2 safe; sed + regex). ------------------
# Extracts a single field from one tier of cost_json. Returns the raw value
# (numeric / null / quoted-string-with-quotes) on stdout. Caller strips
# surrounding quotes for string fields. Empty stdout => no match.
_cj_field() {
  # $1 = json blob, $2 = tier name (quick|standard|full), $3 = field name.
  printf '%s' "$1" | sed -nE 's/.*"'"$2"'":\{[^{}]*"'"$3"'":(null|-?[0-9]+(\.[0-9]+)?|"([^"\\]|\\.)*")[^{}]*\}.*/\1/p'
}

# Strip leading and trailing double-quotes from a string field (bash 3.2 safe).
_cj_unquote() {
  local v="$1"
  v="${v#\"}"
  v="${v%\"}"
  printf '%s' "$v"
}

# Per-tier values from cost_json (always populated thanks to T01's contract).
q_cost_raw="$(_cj_field "$cost_json" "quick"    "cost_usd")"
s_cost_raw="$(_cj_field "$cost_json" "standard" "cost_usd")"
f_cost_raw="$(_cj_field "$cost_json" "full"     "cost_usd")"
q_in="$(_cj_field "$cost_json" "quick"    "input_tokens")"
s_in="$(_cj_field "$cost_json" "standard" "input_tokens")"
f_in="$(_cj_field "$cost_json" "full"     "input_tokens")"
q_out="$(_cj_field "$cost_json" "quick"    "output_tokens")"
s_out="$(_cj_field "$cost_json" "standard" "output_tokens")"
f_out="$(_cj_field "$cost_json" "full"     "output_tokens")"
q_quality_raw="$(_cj_field "$cost_json" "quick"    "quality")"
s_quality_raw="$(_cj_field "$cost_json" "standard" "quality")"
f_quality_raw="$(_cj_field "$cost_json" "full"     "quality")"
q_warn_raw="$(_cj_field "$cost_json" "quick"    "pricing_warning")"
s_warn_raw="$(_cj_field "$cost_json" "standard" "pricing_warning")"
f_warn_raw="$(_cj_field "$cost_json" "full"     "pricing_warning")"

q_quality="$(_cj_unquote "$q_quality_raw")"
s_quality="$(_cj_unquote "$s_quality_raw")"
f_quality="$(_cj_unquote "$f_quality_raw")"
q_warn="$(_cj_unquote "$q_warn_raw")"
s_warn="$(_cj_unquote "$s_warn_raw")"
f_warn="$(_cj_unquote "$f_warn_raw")"

# Default fallbacks for token counts (defensive — T01 always emits them).
q_in="${q_in:-0}"; s_in="${s_in:-0}"; f_in="${f_in:-0}"
q_out="${q_out:-0}"; s_out="${s_out:-0}"; f_out="${f_out:-0}"
q_quality="${q_quality:-best-effort}"
s_quality="${s_quality:-self-review}"
f_quality="${f_quality:-adversarial-gate}"

# Text-mode rendering: 'null' becomes empty value; unquoted numerics pass through.
text_cost() {
  case "$1" in
    null|"") printf '' ;;
    *) printf '%s' "$1" ;;
  esac
}
q_cost_text_v="$(text_cost "$q_cost_raw")"
s_cost_text_v="$(text_cost "$s_cost_raw")"
f_cost_text_v="$(text_cost "$f_cost_raw")"

# Aggregate pricing warning (the 3 tiers always carry the same warning in
# the current pricing.sh shape; pick the first non-empty for the rolled-up
# cost_pricing_warning= line).
combined_warn="${q_warn}"
if [ -z "$combined_warn" ]; then combined_warn="$s_warn"; fi
if [ -z "$combined_warn" ]; then combined_warn="$f_warn"; fi

# --- JSON-escape helper (bash 3.2 safe; sed only). ---------------------------
# Escapes \, ", and newlines for JSON string values.
_json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n' ' ' | sed -e 's/ *$//'
}

# --- Output ------------------------------------------------------------------
if [ "$FORMAT" = "json" ]; then
  # Compose a single-line JSON object with the 8 existing fields + the
  # cost_estimates object (D026 shape: quick/standard/full keys carrying
  # cost_usd / input_tokens / output_tokens / pricing_warning).
  i_intensity="$(_json_escape "$intensity")"
  i_confidence="$(_json_escape "$confidence")"
  i_reasoning="$(_json_escape "$reasoning")"
  i_scope="$(_json_escape "$scope")"
  i_risk_level="$(_json_escape "$risk_level")"
  i_complexity="$(_json_escape "$complexity")"
  i_risk_signals="$(_json_escape "$risk_signals")"

  # JSON cost cells: pass through 'null' verbatim, else bare numeric.
  json_cost() {
    case "$1" in
      null|"") printf 'null' ;;
      *) printf '%s' "$1" ;;
    esac
  }
  q_cost_json_v="$(json_cost "$q_cost_raw")"
  s_cost_json_v="$(json_cost "$s_cost_raw")"
  f_cost_json_v="$(json_cost "$f_cost_raw")"

  q_warn_esc="$(_json_escape "$q_warn")"
  s_warn_esc="$(_json_escape "$s_warn")"
  f_warn_esc="$(_json_escape "$f_warn")"

  printf '{"intensity":"%s","confidence":"%s","reasoning":"%s","scope":"%s","risk_level":"%s","complexity":"%s","risk_signals":"%s","cap_score":%s,"cost_estimates":{"quick":{"cost_usd":%s,"input_tokens":%s,"output_tokens":%s,"pricing_warning":"%s"},"standard":{"cost_usd":%s,"input_tokens":%s,"output_tokens":%s,"pricing_warning":"%s"},"full":{"cost_usd":%s,"input_tokens":%s,"output_tokens":%s,"pricing_warning":"%s"}}}\n' \
    "$i_intensity" "$i_confidence" "$i_reasoning" "$i_scope" "$i_risk_level" "$i_complexity" "$i_risk_signals" "$cap_score" \
    "$q_cost_json_v" "$q_in" "$q_out" "$q_warn_esc" \
    "$s_cost_json_v" "$s_in" "$s_out" "$s_warn_esc" \
    "$f_cost_json_v" "$f_in" "$f_out" "$f_warn_esc"
  exit 0
fi

# Text mode: emit the byte-stable 8 key=value lines unchanged.
echo "intensity=$intensity"
echo "confidence=$confidence"
echo "reasoning=$reasoning"
echo "scope=$scope"
echo "risk_level=$risk_level"
echo "complexity=$complexity"
echo "risk_signals=$risk_signals"
echo "cap_score=$cap_score"

# Cost-annotation block (suppressed by --no-cost-annotation).
if [ "$NO_COST_ANNOTATION" = "1" ]; then
  exit 0
fi

echo "# cost estimates (M027/P01)"
echo "cost_quick_usd=$q_cost_text_v"
echo "cost_quick_in_tokens=$q_in"
echo "cost_quick_out_tokens=$q_out"
echo "cost_standard_usd=$s_cost_text_v"
echo "cost_standard_in_tokens=$s_in"
echo "cost_standard_out_tokens=$s_out"
echo "cost_full_usd=$f_cost_text_v"
echo "cost_full_in_tokens=$f_in"
echo "cost_full_out_tokens=$f_out"
echo "cost_quick_quality=$q_quality"
echo "cost_standard_quality=$s_quality"
echo "cost_full_quality=$f_quality"
echo "cost_pricing_warning=$combined_warn"
