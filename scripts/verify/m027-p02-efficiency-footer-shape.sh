#!/usr/bin/env bash
# scripts/verify/m027-p02-efficiency-footer-shape.sh -- M027/P02 Truth #1.
#
# Asserts the efficiency-footer helper's shape and behavior:
#   - file present, sourceable + executable, >= 80 lines
#   - title literal "Efficiency (Tier 1 rollup)" present
#   - library function efficiency_footer_render present
#   - sourceable / CLI dual via BASH_SOURCE guard
#   - --quiet flag accepted
#   - reads via metrics-rollup.sh (sourced or forked)
#   - efficiency_footer config knob registered in scripts/state/read-config.sh
#   - --quiet emits zero stdout / exit 0
#   - --milestone M019 smoke-test exits 0 (helper does not crash)
#
# Bash 3.2 compatible. MEM004 carve-out -- pipes / $() / awk allowed in
# verifier body since AD-19 binds Check: invocations, not script internals.

set -u

NAME="m027-p02-efficiency-footer-shape.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

HELPER="scripts/diagnostics/efficiency-footer.sh"

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

if ! grep -q "Efficiency (Tier 1 rollup)" "$HELPER"; then
  fail "$HELPER missing literal title 'Efficiency (Tier 1 rollup)'"
fi

if ! grep -q "efficiency_footer_render" "$HELPER"; then
  fail "$HELPER missing library function efficiency_footer_render"
fi

if ! grep -q "BASH_SOURCE" "$HELPER"; then
  fail "$HELPER missing BASH_SOURCE guard (sourceable/CLI dual shape)"
fi

if ! grep -q -- "--quiet" "$HELPER"; then
  fail "$HELPER missing --quiet flag handling"
fi

if ! grep -q "metrics-rollup.sh" "$HELPER"; then
  fail "$HELPER missing reference to scripts/diagnostics/metrics-rollup.sh"
fi

if ! grep -q "efficiency_footer" scripts/state/read-config.sh; then
  fail "scripts/state/read-config.sh missing efficiency_footer in VALID_KEYS"
fi

# --quiet emits zero stdout / exit 0
quiet_out="$(bash "$HELPER" --quiet)"
quiet_rc=$?
if [ "$quiet_rc" -ne 0 ]; then
  fail "--quiet exited non-zero ($quiet_rc)"
fi
if [ -n "$quiet_out" ]; then
  fail "--quiet emitted non-empty stdout"
fi

# --milestone M019 smoke test (helper must not crash)
bash "$HELPER" --milestone M019 >/dev/null 2>&1
ms_rc=$?
if [ "$ms_rc" -ne 0 ]; then
  fail "--milestone M019 exited non-zero ($ms_rc)"
fi

echo "PASS: $NAME"
exit 0
