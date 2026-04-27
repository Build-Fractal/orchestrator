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
  exit 0
fi
