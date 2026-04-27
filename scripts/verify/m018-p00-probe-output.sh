#!/usr/bin/env bash
# scripts/verify/m018-p00-probe-output.sh
#
# M018/P00/T02 verifier — runs the section-distribution probe in JSON mode
# and asserts the savings_ceiling output shape:
#
#   - per_section[] contains the eight canonical section names.
#   - per_tier{} carries the four tiers (filter, tier1, tier2, tier3),
#     each with low_tokens / mean_tokens / high_tokens keys.
#   - top-level aggregate_ceiling block exists with low_pct / mean_pct /
#     high_pct / low_tokens / mean_tokens / high_tokens.
#   - aggregate_ceiling.high_pct - aggregate_ceiling.low_pct < 50 (sanity:
#     the bootstrap CI band is finite and not pathological).
#
# Exits 0 on PASS, 1 on FAIL with diagnostic.

set -euo pipefail

PROBE="scripts/diagnostics/m018-section-distribution.sh"

if [ ! -x "$PROBE" ] && [ ! -r "$PROBE" ]; then
  echo "FAIL: $PROBE not found" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq required" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
JSON_FILE="$TMP/probe.json"

# Run the probe with a small bootstrap iteration count for verifier speed.
bash "$PROBE" --format json --bootstrap-iterations 100 --seed 42 > "$JSON_FILE"

# Validate it parses as JSON
if ! jq -e '.' "$JSON_FILE" >/dev/null 2>&1; then
  echo "FAIL: probe output is not valid JSON" >&2
  exit 1
fi

# 1. Eight canonical sections present.
EXPECTED_SECTIONS="Knowledge|Task Plan|Upstream Context|First-Turn Completeness|Scope|Constraints|State Context|Decisions"
ACTUAL_SECTIONS=$(jq -r '.per_section[].section' "$JSON_FILE" | tr '\n' '|' | sed 's/|$//')

# Check each expected section appears
missing_sections=""
IFS='|' read -ra EXPECTED_ARR <<< "$EXPECTED_SECTIONS"
for sec in "${EXPECTED_ARR[@]}"; do
  if ! jq -e --arg s "$sec" '.per_section[] | select(.section == $s)' "$JSON_FILE" >/dev/null 2>&1; then
    missing_sections="$missing_sections $sec"
  fi
done

if [ -n "$missing_sections" ]; then
  echo "FAIL: missing per_section entries:$missing_sections" >&2
  exit 1
fi

# 2. Four tiers present in per_tier{} with the required keys.
EXPECTED_TIERS="filter tier1 tier2 tier3"
for tier in $EXPECTED_TIERS; do
  if ! jq -e --arg t "$tier" '.per_tier[$t]' "$JSON_FILE" >/dev/null 2>&1; then
    echo "FAIL: per_tier.$tier missing" >&2
    exit 1
  fi
  for key in low_tokens mean_tokens high_tokens; do
    if ! jq -e --arg t "$tier" --arg k "$key" '.per_tier[$t][$k]' "$JSON_FILE" >/dev/null 2>&1; then
      echo "FAIL: per_tier.$tier.$key missing" >&2
      exit 1
    fi
  done
done

# 3. aggregate_ceiling block exists with all required keys.
for key in low_tokens mean_tokens high_tokens low_pct mean_pct high_pct; do
  if ! jq -e --arg k "$key" '.aggregate_ceiling[$k]' "$JSON_FILE" >/dev/null 2>&1; then
    echo "FAIL: aggregate_ceiling.$key missing" >&2
    exit 1
  fi
done

# 4. CI band is finite: high_pct - low_pct < 50.
BAND=$(jq -r '.aggregate_ceiling.high_pct - .aggregate_ceiling.low_pct' "$JSON_FILE")
if awk -v b="$BAND" 'BEGIN { exit !(b >= 50) }'; then
  echo "FAIL: aggregate_ceiling CI band is pathological: high - low = $BAND" >&2
  exit 1
fi

# 5. savings_ceiling alias also present (load-bearing string for grep checks).
if ! jq -e '.savings_ceiling' "$JSON_FILE" >/dev/null 2>&1; then
  echo "FAIL: top-level savings_ceiling field missing" >&2
  exit 1
fi

MEAN_PCT=$(jq -r '.aggregate_ceiling.mean_pct' "$JSON_FILE")
echo "PASS: m018-section-distribution probe output validates"
echo "  records_analyzed=$(jq -r '.records_analyzed' "$JSON_FILE")"
echo "  aggregate_ceiling: mean_pct=$MEAN_PCT  CI_band=$BAND"
exit 0
