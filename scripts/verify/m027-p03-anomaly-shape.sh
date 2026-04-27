#!/usr/bin/env bash
# scripts/verify/m027-p03-anomaly-shape.sh -- M027/P03 Truth #1.
#
# Asserts the shape + behavioral contract of
# scripts/diagnostics/check-anomalies.sh: file presence, size,
# sourceable-CLI guard, title literal, render function, --no-anomaly
# arg-parse, metrics-rollup.sh delegation, and the four anomaly config
# knobs registered in scripts/state/read-config.sh VALID_KEYS.
#
# Behavioral checks (live invocation):
#   - --no-anomaly --milestone M013 -> empty stdout, exit 0
#   - --milestone M013 -> stdout starts with "Anomaly Detection (Tier 1 baseline)"
#   - --milestone M021 --sample-floor 5 -> stdout contains "insufficient sample"
#
# Bash 3.2 compatible. MEM004 carve-out -- pipes / grep used internally.

set -u

NAME="m027-p03-anomaly-shape.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

HELPER="scripts/diagnostics/check-anomalies.sh"
RC_SH="scripts/state/read-config.sh"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if [ ! -f "$HELPER" ]; then
  fail "$HELPER missing"
fi
if [ ! -x "$HELPER" ]; then
  fail "$HELPER not executable"
fi
lines="$(wc -l < "$HELPER" | tr -d ' ')"
if [ "$lines" -lt 120 ]; then
  fail "$HELPER too short ($lines lines, expected >= 120)"
fi

# Source-shape literals.
grep -q "Anomaly Detection (Tier 1 baseline)" "$HELPER" \
  || fail "$HELPER missing title literal"
grep -q "check_anomalies_render" "$HELPER" \
  || fail "$HELPER missing check_anomalies_render function"
grep -q "BASH_SOURCE" "$HELPER" \
  || fail "$HELPER missing BASH_SOURCE sourceable-CLI guard"
grep -q -- "--no-anomaly" "$HELPER" \
  || fail "$HELPER missing --no-anomaly flag handling"
grep -q "metrics-rollup.sh" "$HELPER" \
  || fail "$HELPER missing metrics-rollup.sh delegation"

# read-config.sh registers all four anomaly knobs in VALID_KEYS.
if [ ! -f "$RC_SH" ]; then
  fail "$RC_SH missing"
fi
grep -q "anomaly_cost_multiplier" "$RC_SH" \
  || fail "$RC_SH missing anomaly_cost_multiplier"
grep -q "anomaly_retry_threshold" "$RC_SH" \
  || fail "$RC_SH missing anomaly_retry_threshold"
grep -q "anomaly_pass_rate_threshold" "$RC_SH" \
  || fail "$RC_SH missing anomaly_pass_rate_threshold"
grep -q "anomaly_check_enabled" "$RC_SH" \
  || fail "$RC_SH missing anomaly_check_enabled"

# Behavioral: suppressed mode emits zero stdout, exit 0.
out_supp="$(bash "$HELPER" --no-anomaly --milestone M013 2>/dev/null)"
rc_supp=$?
if [ "$rc_supp" -ne 0 ]; then
  fail "--no-anomaly exited non-zero ($rc_supp)"
fi
if [ -n "$out_supp" ]; then
  fail "--no-anomaly produced non-empty stdout: $(printf '%s' "$out_supp" | head -c 80)"
fi

# Behavioral: default mode emits the title literal as the first line.
out_def="$(bash "$HELPER" --milestone M013 2>/dev/null)"
rc_def=$?
if [ "$rc_def" -ne 0 ]; then
  fail "default-mode exited non-zero ($rc_def)"
fi
first_line="$(printf '%s\n' "$out_def" | head -1)"
case "$first_line" in
  "Anomaly Detection (Tier 1 baseline)") : ;;
  *) fail "default-mode first line mismatch: '$first_line'" ;;
esac

# Behavioral: below-floor path emits "insufficient sample".
out_floor="$(bash "$HELPER" --milestone M021 --sample-floor 5 2>/dev/null)"
rc_floor=$?
if [ "$rc_floor" -ne 0 ]; then
  fail "below-floor exited non-zero ($rc_floor)"
fi
if ! printf '%s' "$out_floor" | grep -q "insufficient sample"; then
  fail "below-floor missing 'insufficient sample' literal"
fi

echo "PASS: $NAME"
exit 0
