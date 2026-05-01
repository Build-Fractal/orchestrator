#!/usr/bin/env bash
# scripts/diagnostics/efficiency-footer.sh -- M027/P02/T01 efficiency footer helper.
#
# Sourceable as a library (function efficiency_footer_render) AND runnable as
# a CLI. CLI emits a one-block efficiency footer (<=6 lines) titled
# "Efficiency (Tier 1 rollup)" summarizing milestone-to-date cost + quality
# paired metrics. Under --quiet (or config.efficiency_footer=false), emits
# exactly zero stdout, exit 0 -- load-bearing CON-3/SC-3 byte-identity
# contract.
#
# Read-only (FR-12/CON-1): never writes to execution-log.jsonl or config.
# Zero-LLM-token (FR-21/CON-6): bash + invocation of metrics-rollup.sh only.
# Bash 3.2 (CON-7): parallel scalars only; no associative arrays; no
# herestring redirection; no process substitution; no case-folding parameter
# expansion; no merged stdout-stderr shorthand.
#
# AD-19 (single-script-file Check shape): this helper IS that single script
# referenced by the T01 task plan Verification block (via the T01-scoped
# precheck wrapper); its body uses pipes / command substitution / grep
# internally per the MEM004 emitter-internal carve-out.

set -u

# Re-source guard -- mirrors pricing.sh _PRICING_SH_SOURCED + cost-estimate.sh
# _COST_ESTIMATE_SH_SOURCED. Lets downstream scripts source this file from
# multiple sites without re-defining the function or the script-dir scalars.
if [ -n "${_EFFICIENCY_FOOTER_SH_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
_EFFICIENCY_FOOTER_SH_SOURCED=1

_EFF_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_EFF_PROJECT_ROOT="$(cd "$_EFF_SCRIPT_DIR/../.." && pwd)"

# M031/P04/T03 — AD-19 QUICK_BUDGET_DRIFT informational warning.
#
# Reads payload_breakdown JSONL records (knowledge_section_tokens field,
# AD-11 sidecar schema from M031/P01) and, when the rolling median of
# knowledge_section_tokens across the most-recent 7 Quick-profile dispatches
# exceeds quick_knowledge_token_budget * 1.1, emits one informational JSONL
# record carrying the literal substring QUICK_BUDGET_DRIFT. Non-blocking;
# always returns 0; preserves the script's existing exit-code contract.
#
# Test-only seam: ORCH_EFFICIENCY_FOOTER_INPUT env override resolves the
# JSONL stream path (acceptance fixture in tests/m031-acceptance/). When
# unset, the production path under .orchestrator/observability/ is used.

# m031_quick_budget — resolve quick_knowledge_token_budget via the standard
# 4-layer fallback: env-var implicit / .orchestrator/config.yml / template
# default / hardcoded P00 default 800. Mirrors the M031/P02/P03 config-knob
# resolution pattern. Bash 3.2 compatible.
m031_quick_budget() {
  local cfg_path="${ORCH_CONFIG_PATH:-$_EFF_PROJECT_ROOT/.orchestrator/config.yml}"
  local val
  if [ -f "$cfg_path" ]; then
    val=$(grep -E '^quick_knowledge_token_budget:' "$cfg_path" | head -n 1 | awk '{print $2}')
    if [ -n "$val" ]; then
      printf '%s\n' "$val"
      return 0
    fi
  fi
  local tpl_path="$_EFF_PROJECT_ROOT/templates/orchestrator-config-default.yml"
  if [ -f "$tpl_path" ]; then
    val=$(grep -E '^quick_knowledge_token_budget:' "$tpl_path" | head -n 1 | awk '{print $2}')
    if [ -n "$val" ]; then
      printf '%s\n' "$val"
      return 0
    fi
  fi
  printf '800\n'
}

# m031_quick_window_median — median knowledge_section_tokens across the most
# recent 7 quick-profile records in the JSONL stream at $1. Emits empty
# stdout when the window holds fewer than 7 quick records (AD-19 trigger
# does not fire on a half-full window). Bash 3.2 compatible.
m031_quick_window_median() {
  local input="$1"
  if [ ! -f "$input" ]; then
    return 0
  fi
  local tmp_quick
  tmp_quick=$(mktemp)
  grep -F '"profile":"quick"' "$input" 2>/dev/null | tail -n 7 >"$tmp_quick" || true
  local count
  count=$(wc -l <"$tmp_quick" | awk '{print $1}')
  if [ "$count" -lt 7 ]; then
    rm -f "$tmp_quick"
    return 0
  fi
  local median
  median=$(grep -oE '"knowledge_section_tokens":[0-9]+' "$tmp_quick" | awk -F: '{print $2}' | sort -n | sed -n '4p')
  rm -f "$tmp_quick"
  printf '%s\n' "$median"
}

# m031_quick_budget_drift_check — emit one JSONL record carrying the
# QUICK_BUDGET_DRIFT literal when median > budget * 1.1; silent otherwise.
# Always returns 0 (informational; never gates exit). Bash 3.2 compatible.
m031_quick_budget_drift_check() {
  local input="$1"
  local budget median threshold
  budget=$(m031_quick_budget)
  median=$(m031_quick_window_median "$input")
  if [ -z "$median" ]; then
    return 0
  fi
  threshold=$(awk -v b="$budget" 'BEGIN{printf "%d\n", b * 11 / 10}')
  if [ "$median" -gt "$threshold" ]; then
    printf '{"warning":"QUICK_BUDGET_DRIFT","window":7,"median":%s,"budget":%s,"threshold":%s}\n' "$median" "$budget" "$threshold"
  fi
  return 0
}

# efficiency_footer_render <milestone-or-empty> <quiet-flag>
#   When <quiet-flag> = 1, emits zero stdout (and returns 0). This is the
#   load-bearing CON-3/SC-3 invariant -- the T02 baseline fixture + T04
#   byte-identity verifier gate this path.
#   When <milestone-or-empty> = empty, falls back to project-granularity
#   rollup so the footer still has something useful to print outside an
#   active milestone.
#   Always returns exit 0 (never aborts; degraded inputs surface as text per
#   CON-5 carry-forward from the rollup engine).
efficiency_footer_render() {
  local milestone="$1"
  local quiet="$2"
  if [ "$quiet" = "1" ]; then
    return 0
  fi
  local rollup_out
  if [ -n "$milestone" ]; then
    rollup_out="$(bash "$_EFF_PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
      --granularity milestone --milestone "$milestone" 2>/dev/null || true)"
  else
    rollup_out="$(bash "$_EFF_PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
      --granularity project 2>/dev/null || true)"
  fi
  # Empty-log path -- US-3 AS-3: still emit the header + the canonical
  # "no Tier 1 records yet" line so callers see a stable footer shape even
  # when M019 emission hasn't happened on this milestone yet.
  if [ -z "$rollup_out" ] || printf '%s\n' "$rollup_out" | grep -qE 'no Tier 1 records yet'; then
    printf '%s\n' "Efficiency (Tier 1 rollup)"
    printf '%s\n' "Efficiency: no Tier 1 records yet"
    return 0
  fi
  # Extract a small, fixed set of lines for the footer (<=6 total):
  # title + scope + cost + quality + dispatch-count + pricing-warning.
  # The metrics-rollup.sh CLI emits a tabular shape (header row + data row);
  # we extract paired cost + quality cells from the data row by column,
  # falling back to key=value patterns if a future rollup shape switches.
  # See US-3 AS-1 -- paired cost + quality + count.
  local header_line data_line
  header_line="$(printf '%s\n' "$rollup_out" | grep -E '^GRANULARITY' | head -n 1)"
  data_line="$(printf '%s\n' "$rollup_out" | grep -vE '^GRANULARITY|^NORMALIZE_COUNTS|^$' | head -n 1)"
  local scope_text="" cost_text="" qual_text="" count_text="" warn_text=""
  if [ -n "$data_line" ]; then
    # Tabular shape -- pull a few columns by awk index. Columns are
    # whitespace-separated and stable across the M019/P00 rollup contract:
    # 1=GRANULARITY 2=SCOPE 3=DISPATCHES 4=EST_COST_USD 9=PASS_RATE.
    scope_text="scope=$(printf '%s\n' "$data_line" | awk '{printf "%s/%s", $1, $2}')"
    count_text="dispatches=$(printf '%s\n' "$data_line" | awk '{print $3}')"
    cost_text="estimated_cost_usd=$(printf '%s\n' "$data_line" | awk '{print $4}')"
    qual_text="verification_pass_rate=$(printf '%s\n' "$data_line" | awk '{print $9}')"
  fi
  # Pricing-warning passthrough -- the rollup engine annotates the cost
  # column with "(N missing)" or "(stale)" when pricing.yml degrades; surface
  # only the short parenthesized annotation (or an explicit pricing_warning=
  # key=value line if a future rollup shape adopts that form) so the footer
  # stays compact.
  if printf '%s\n' "$rollup_out" | grep -qE '\([0-9]+ missing\)|\(stale\)'; then
    warn_text="$(printf '%s\n' "$rollup_out" | grep -oE '\([0-9]+ missing\)|\(stale\)' | head -n 1)"
  else
    warn_text="$(printf '%s\n' "$rollup_out" | grep -E '^pricing_warning' | head -n 1)"
  fi
  printf '%s\n' "Efficiency (Tier 1 rollup)"
  [ -n "$scope_text" ] && printf '  %s\n' "$scope_text"
  [ -n "$cost_text" ]  && printf '  %s\n' "$cost_text"
  [ -n "$qual_text" ]  && printf '  %s\n' "$qual_text"
  [ -n "$count_text" ] && printf '  %s\n' "$count_text"
  [ -n "$warn_text" ]  && printf '  pricing: %s\n' "$warn_text"

  # M018/P05/T02 — compression savings line ("Compressed: <pct>% reduction
  # over baseline" tail per the P05 truth contract; emitted as the lower-case
  # `compression:` form in stdout for the M027 efficiency-footer body, both
  # forms acceptable per the truth wording). Reads the four new columns
  # (FILTER_DROPPED=$13, TIER1_SAVINGS=$14, TIER2_SAVINGS=$15) and
  # TOKENS_EST=$5 from the same data row, computes
  # pct = (sum_savings) * 100 / tokens, and emits
  #   compression: <pct>% reduction over baseline (filter+tier1+tier2 / payload_tokens)
  # when (a) tokens > 0, (b) pct >= 0.5 (rounding-noise floor), and
  # (c) the compression.efficiency_footer.enabled config knob is not falsy.
  # Suppressed entirely when all savings are zero (the awk pct >= 0.5 guard
  # also covers pct == 0). The line is INDEPENDENT of the parent
  # efficiency_footer suppressor — that gate already short-circuited above.
  cfg_compression_footer="${ORCH_COMPRESSION_FOOTER:-}"
  if [ -z "$cfg_compression_footer" ] && [ -x "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
    cfg_compression_footer="$(bash "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" compression.efficiency_footer.enabled 2>/dev/null || true)"
  fi
  case "$cfg_compression_footer" in
    false|FALSE|False|0|no|NO|No)
      : # suppressed
      ;;
    *)
      if [ -n "$data_line" ]; then
        _eff_savings_line="$(printf '%s\n' "$data_line" | awk '
          {
            # Whitespace-split columns; col 5 = TOKENS_EST,
            # cols 13-15 = FILTER_DROPPED + TIER1_SAVINGS + TIER2_SAVINGS,
            # col 17 = TIER3_SAVINGS (M018/P06/T02 additive carry-forward).
            # Note: when EST_COST_USD carries the "(N missing)" annotation
            # the cost cell occupies cols 4-6 ("0.00000000 (N missing)"),
            # which shifts all subsequent columns by +2 — read TOKENS_EST
            # at $7 and savings at $15-$17 / $19 in that case. Detect by
            # checking whether $5 begins with "(".
            if ($5 ~ /^\(/) {
              tokens = $7 + 0;
              fdrop  = $15 + 0; t1s = $16 + 0; t2s = $17 + 0; t3s = $19 + 0;
            } else {
              tokens = $5 + 0;
              fdrop  = $13 + 0; t1s = $14 + 0; t2s = $15 + 0; t3s = $17 + 0;
            }
            if (tokens > 0) {
              pct = (fdrop + t1s + t2s + t3s) * 100.0 / tokens;
              if (pct >= 0.5) {
                printf "compression: %.1f%% reduction over baseline (filter+tier1+tier2+tier3 / payload_tokens)", pct;
              }
            }
          }
        ' || true)"
        if [ -n "$_eff_savings_line" ]; then
          printf '  %s\n' "$_eff_savings_line"
        fi
      fi
      ;;
  esac

  # M030/P05/T02 — model_mix: line. Invokes metrics-rollup.sh --by-model
  # against the same milestone the parent footer is rendering. Suppressed
  # when the corpus has zero shadow-on records (zero `model_routed` fields).
  # This is the SC-11 byte-equality preservation mechanism — pre-M030
  # fixtures emit zero new bytes through the footer.
  cfg_model_mix_footer="${ORCH_MODEL_MIX_FOOTER:-}"
  if [ -z "$cfg_model_mix_footer" ] && [ -x "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
    cfg_model_mix_footer="$(bash "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" model_routing.efficiency_footer.enabled 2>/dev/null || true)"
  fi
  case "$cfg_model_mix_footer" in
    false|FALSE|False|0|no|NO|No)
      : # suppressed by config
      ;;
    *)
      _eff_by_model_out=""
      if [ -n "$milestone" ]; then
        _eff_by_model_out="$(bash "$_EFF_PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
          --by-model --milestone "$milestone" 2>/dev/null || true)"
      fi
      _eff_mm_line="$(printf '%s\n' "$_eff_by_model_out" | grep -E '^[0-9]+ dispatches:' | head -n 1)"
      if [ -n "$_eff_mm_line" ]; then
        _eff_mm_total="$(printf '%s\n' "$_eff_mm_line" | awk '{print $1}')"
        _eff_mm_fast="$(printf '%s\n' "$_eff_mm_line" | awk -F'[: /]+' '{for(i=1;i<=NF;i++) if($i=="fast") print $(i-1)}' | head -n 1)"
        _eff_mm_bal="$(printf '%s\n' "$_eff_mm_line" | awk -F'[: /]+' '{for(i=1;i<=NF;i++) if($i=="balanced") print $(i-1)}' | head -n 1)"
        _eff_mm_smart="$(printf '%s\n' "$_eff_mm_line" | awk -F'[: /]+' '{for(i=1;i<=NF;i++) if($i=="smart") print $(i-1)}' | head -n 1)"
        # Suppress when total == 0 (no shadow-on records — SC-11 contract).
        if [ -n "$_eff_mm_total" ] && [ "$_eff_mm_total" != "0" ] && [ "$_eff_mm_total" -gt 0 ] 2>/dev/null; then
          printf '  model_mix: fast=%s balanced=%s smart=%s\n' \
            "${_eff_mm_fast:-0}" "${_eff_mm_bal:-0}" "${_eff_mm_smart:-0}"
        fi
      fi
      ;;
  esac
  return 0
}

# CLI entry point -- only when invoked as a script (not sourced). Mirrors the
# BASH_SOURCE-zero == zero-arg sourceable-CLI duality pattern established by
# scripts/engine/cost-estimate.sh and scripts/lib/pricing.sh.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  MILESTONE=""
  PROJECT_FALLBACK=0
  QUIET=0
  CONFIG_DEFAULTS=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --milestone)
        MILESTONE="${2:-}"; shift 2 ;;
      --project)
        PROJECT_FALLBACK=1; shift ;;
      --quiet)
        QUIET=1; shift ;;
      --config-defaults)
        CONFIG_DEFAULTS="${2:-}"; shift 2 ;;
      --help|-h)
        printf '%s\n' "Usage: efficiency-footer.sh [--milestone <Mxxx>] [--project] [--quiet] [--config-defaults <path>]"
        printf '%s\n' "  --milestone <Mxxx>      Scope rollup to this milestone."
        printf '%s\n' "  --project               Force project-granularity rollup (default when no active milestone)."
        printf '%s\n' "  --quiet                 Suppress all stdout (CON-3/SC-3 byte-identity contract)."
        printf '%s\n' "  --config-defaults <p>   Optional defaults file forwarded to scripts/state/read-config.sh."
        printf '%s\n' "  --help, -h              Show this help and exit 0."
        exit 0 ;;
      *)
        # Unknown flag -- swallow rather than abort (CON-5 never-abort posture
        # extended to this transient diagnostic surface).
        shift ;;
    esac
  done

  # Resolve the efficiency_footer config knob -- env var overrides (matches
  # the SPECKIT_ORCHESTRATOR_<KEY> precedence rule that read-config.sh already
  # implements as layer 1), then read-config.sh as the fallback for project /
  # local / defaults layers. When the resolved value is a recognized falsy
  # token, force quiet so we honor the operator's suppression intent.
  if [ "$QUIET" -eq 0 ]; then
    cfg_val="${ORCH_EFFICIENCY_FOOTER:-}"
    if [ -z "$cfg_val" ] && [ -x "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
      if [ -n "$CONFIG_DEFAULTS" ]; then
        cfg_val="$(bash "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" efficiency_footer --defaults "$CONFIG_DEFAULTS" 2>/dev/null || true)"
      else
        cfg_val="$(bash "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" efficiency_footer 2>/dev/null || true)"
      fi
    fi
    case "$cfg_val" in
      false|FALSE|False|0|no|NO|No) QUIET=1 ;;
    esac
  fi

  # Resolve active milestone if neither --milestone nor --project given. The
  # find-active-milestone.sh helper takes orchestrator-root as its first arg;
  # the project root resolved above is the right value here. Failure or empty
  # output silently degrades to the project-granularity rollup path.
  if [ -z "$MILESTONE" ] && [ "$PROJECT_FALLBACK" -eq 0 ]; then
    if [ -x "$_EFF_PROJECT_ROOT/scripts/state/find-active-milestone.sh" ]; then
      _eff_active="$(bash "$_EFF_PROJECT_ROOT/scripts/state/find-active-milestone.sh" "$_EFF_PROJECT_ROOT/.orchestrator" 2>/dev/null || true)"
      # find-active-milestone.sh prints "M### <state> <tier>" -- take field 1.
      MILESTONE="$(printf '%s\n' "$_eff_active" | awk 'NR==1 {print $1}')"
    fi
  fi

  efficiency_footer_render "$MILESTONE" "$QUIET"

  # M031/P04/T03 — AD-19 QUICK_BUDGET_DRIFT informational warning.
  # Resolution: env override ORCH_EFFICIENCY_FOOTER_INPUT first, then the
  # canonical .orchestrator/observability/ payload_breakdown JSONL stream.
  # Suppressed when --quiet is in effect (preserves the CON-3/SC-3
  # byte-identity contract that gates zero-stdout under quiet).
  if [ "$QUIET" -eq 0 ]; then
    if [ -n "${ORCH_EFFICIENCY_FOOTER_INPUT:-}" ]; then
      INPUT_PATH="$ORCH_EFFICIENCY_FOOTER_INPUT"
    else
      INPUT_PATH="$_EFF_PROJECT_ROOT/.orchestrator/observability/payload_breakdown.jsonl"
    fi
    m031_quick_budget_drift_check "$INPUT_PATH"
  fi

  exit 0
fi
