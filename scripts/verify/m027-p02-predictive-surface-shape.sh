#!/usr/bin/env bash
# scripts/verify/m027-p02-predictive-surface-shape.sh -- M027/P02 Truth #4.
#
# Asserts the predictive-surface helper's shape and behavior:
#   - file present, sourceable + executable, >= 80 lines
#   - predictive_cost_surface token (config knob name) present
#   - library function predictive_surface_render present
#   - sourceable / CLI dual via BASH_SOURCE guard
#   - intensity-recommend.sh referenced (cost-annotation hook)
#   - INTENSITY_RECOMMEND_FAST_PATH + _CE_RECOMMENDED fast-path used
#   - predictive_cost_surface config knob registered in read-config.sh
#   - default invocation renders the predictive_cost_surface block
#   - rendered output contains literal 'override:' (CON-10)
#
# Bash 3.2 compatible. MEM004 carve-out.

set -u

NAME="m027-p02-predictive-surface-shape.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

HELPER="scripts/dispatch/predictive-surface.sh"

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

if ! grep -q "predictive_cost_surface" "$HELPER"; then
  fail "$HELPER missing 'predictive_cost_surface' token"
fi

if ! grep -q "predictive_surface_render" "$HELPER"; then
  fail "$HELPER missing library function predictive_surface_render"
fi

if ! grep -q "BASH_SOURCE" "$HELPER"; then
  fail "$HELPER missing BASH_SOURCE guard (sourceable/CLI dual shape)"
fi

if ! grep -q "intensity-recommend.sh" "$HELPER"; then
  fail "$HELPER missing intensity-recommend.sh reference"
fi

if ! grep -q "INTENSITY_RECOMMEND_FAST_PATH" "$HELPER"; then
  fail "$HELPER missing INTENSITY_RECOMMEND_FAST_PATH fast-path env-var"
fi

if ! grep -q "_CE_RECOMMENDED" "$HELPER"; then
  fail "$HELPER missing _CE_RECOMMENDED fast-path env-var"
fi

if ! grep -q "predictive_cost_surface" scripts/state/read-config.sh; then
  fail "scripts/state/read-config.sh missing predictive_cost_surface in VALID_KEYS"
fi

# Run the default interactive invocation; capture stdout + exit.
out="$(bash "$HELPER" --description "test" --intensity standard 2>/dev/null)"
rc=$?
if [ "$rc" -ne 0 ]; then
  fail "default invocation exited non-zero ($rc)"
fi
if ! printf '%s\n' "$out" | grep -q "predictive_cost_surface"; then
  fail "rendered output missing predictive_cost_surface block"
fi
if ! printf '%s\n' "$out" | grep -q "override:"; then
  fail "rendered output missing 'override:' prompt (CON-10)"
fi

echo "PASS: $NAME"
exit 0
