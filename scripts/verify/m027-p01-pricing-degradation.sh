#!/usr/bin/env bash
# scripts/verify/m027-p01-pricing-degradation.sh — M027/P01 Truth #7
# (FR-11, CON-5).
#
# Asserts cost-estimate.sh and intensity-recommend.sh degrade gracefully
# when ORCH_PRICING_FILE points at a non-existent path: exit 0, three
# tier rows, cost cells show `(unavailable)` (text) or `null` (json),
# pricing_warning surfaced.
#
# Bash 3.2 compatible. MEM004 emitter-internal carve-out — pipes /
# python3 / `env` permitted internally.

set -u

NAME="m027-p01-pricing-degradation.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CE="$PROJECT_ROOT/scripts/engine/cost-estimate.sh"
IR="$PROJECT_ROOT/scripts/engine/intensity-recommend.sh"

NONEXISTENT="${TMPDIR:-/tmp}/m027-p01-pricing-nonexistent-$$.yml"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

[ -f "$CE" ] || fail "scripts/engine/cost-estimate.sh missing"
[ -f "$IR" ] || fail "scripts/engine/intensity-recommend.sh missing"

# Just in case: ensure path doesn't exist.
rm -f "$NONEXISTENT" 2>/dev/null || true

# --- cost-estimate.sh text mode ---
text_out="$(env ORCH_PRICING_FILE="$NONEXISTENT" bash "$CE" --description "test" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s cost-estimate text exit %d\n%s\n' "$NAME" "$rc" "$text_out" >&2
  exit 1
fi
# Three tier rows.
for tier in Quick Standard Full; do
  if ! printf '%s\n' "$text_out" | grep -qE "^${tier}[[:space:]]"; then
    fail "text mode: missing tier $tier"
  fi
done
# At least one (unavailable) cell.
if ! printf '%s\n' "$text_out" | grep -qF '(unavailable)'; then
  fail "text mode: expected (unavailable) cost cell on missing pricing"
fi
# Recommendation marker still present.
if ! printf '%s\n' "$text_out" | grep -qE '^(Quick|Standard|Full)[[:space:]].*\*[[:space:]]*$'; then
  fail "text mode: recommendation marker absent"
fi

# --- cost-estimate.sh json mode ---
json_out="$(env ORCH_PRICING_FILE="$NONEXISTENT" bash "$CE" --description "test" --format json 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s cost-estimate json exit %d\n%s\n' "$NAME" "$rc" "$json_out" >&2
  exit 1
fi
if command -v python3 >/dev/null 2>&1; then
  py_out="$(printf '%s' "$json_out" | python3 -c 'import json,sys
d=json.loads(sys.stdin.read())
for k in ("quick","standard","full"):
    t=d["tiers"][k]
    assert t["cost_usd"] is None, k+" cost_usd not null"
    assert t.get("pricing_warning",""), k+" pricing_warning empty"
print("OK")
' 2>&1)"
  if [ "$py_out" != "OK" ]; then
    fail "cost-estimate json degradation: $py_out"
  fi
else
  if ! printf '%s' "$json_out" | grep -qE '"quick":\{[^}]*"cost_usd":null'; then
    fail "cost-estimate json: quick.cost_usd not null"
  fi
fi

# --- intensity-recommend.sh json mode ---
ir_json="$(env ORCH_PRICING_FILE="$NONEXISTENT" bash "$IR" --description "test" --format json 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s intensity-recommend json exit %d\n%s\n' "$NAME" "$rc" "$ir_json" >&2
  exit 1
fi
if command -v python3 >/dev/null 2>&1; then
  py_out="$(printf '%s' "$ir_json" | python3 -c 'import json,sys
d=json.loads(sys.stdin.read())
ce=d.get("cost_estimates",{})
for k in ("quick","standard","full"):
    t=ce[k]
    assert t["cost_usd"] is None, k+" cost_usd not null"
    assert t.get("pricing_warning",""), k+" pricing_warning empty"
print("OK")
' 2>&1)"
  if [ "$py_out" != "OK" ]; then
    fail "intensity-recommend json degradation: $py_out"
  fi
else
  if ! printf '%s' "$ir_json" | grep -qE '"quick":\{[^}]*"cost_usd":null'; then
    fail "intensity-recommend json: quick.cost_usd not null"
  fi
fi

printf 'PASS: %s graceful pricing-missing degradation verified (text + json)\n' "$NAME"
exit 0
