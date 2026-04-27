#!/usr/bin/env bash
# scripts/verify/m027-p03-config-drift-shape.sh -- M027/P03 Truth #2.
#
# Asserts the shape + behavioral contract of
# scripts/diagnostics/check-config-drift.sh: file presence, size,
# sourceable-CLI guard, title literal, render function, and read-config.sh
# delegation.
#
# Behavioral checks (live invocation):
#   - --keys efficiency_footer -> stdout contains title + key= + effective=
#   - --no-config-check -> empty stdout, exit 0
#   - default keys -> stdout contains all six M027 knob names
#
# Bash 3.2 compatible. MEM004 carve-out -- pipes / grep used internally.

set -u

NAME="m027-p03-config-drift-shape.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

HELPER="scripts/diagnostics/check-config-drift.sh"

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
if [ "$lines" -lt 80 ]; then
  fail "$HELPER too short ($lines lines, expected >= 80)"
fi

grep -q "Config Drift (M027 knobs)" "$HELPER" \
  || fail "$HELPER missing title literal"
grep -q "check_config_drift_render" "$HELPER" \
  || fail "$HELPER missing check_config_drift_render function"
grep -q "BASH_SOURCE" "$HELPER" \
  || fail "$HELPER missing BASH_SOURCE sourceable-CLI guard"
grep -q "read-config.sh" "$HELPER" \
  || fail "$HELPER missing read-config.sh delegation"

# Behavioral: single-key invocation surfaces the title + key= + effective=.
out1="$(bash "$HELPER" --keys efficiency_footer 2>/dev/null)"
rc1=$?
if [ "$rc1" -ne 0 ]; then
  fail "--keys efficiency_footer exited non-zero ($rc1)"
fi
printf '%s' "$out1" | grep -q "Config Drift (M027 knobs)" \
  || fail "single-key output missing title"
printf '%s' "$out1" | grep -q "key=efficiency_footer" \
  || fail "single-key output missing key=efficiency_footer"
printf '%s' "$out1" | grep -q "effective=" \
  || fail "single-key output missing effective= line"

# Behavioral: --no-config-check suppresses to empty stdout, exit 0.
out2="$(bash "$HELPER" --no-config-check 2>/dev/null)"
rc2=$?
if [ "$rc2" -ne 0 ]; then
  fail "--no-config-check exited non-zero ($rc2)"
fi
if [ -n "$out2" ]; then
  fail "--no-config-check produced non-empty stdout: $(printf '%s' "$out2" | head -c 80)"
fi

# Behavioral: default keys list contains all six M027 knobs.
out3="$(bash "$HELPER" 2>/dev/null)"
rc3=$?
if [ "$rc3" -ne 0 ]; then
  fail "default-keys exited non-zero ($rc3)"
fi
for k in efficiency_footer predictive_cost_surface anomaly_cost_multiplier anomaly_retry_threshold anomaly_pass_rate_threshold anomaly_check_enabled; do
  if ! printf '%s' "$out3" | grep -q "key=$k"; then
    fail "default-keys output missing key=$k"
  fi
done

echo "PASS: $NAME"
exit 0
