#!/usr/bin/env bash
# scripts/verify/m027-p01-predictive-goodhart-pairing.sh — M027/P01 Truth #4
# (FR-20, CON-4, SC-18).
#
# Goodhart pairing for the predictive surface: every tier row of
# `cost-estimate.sh --description ...` that carries a cost cell MUST
# carry a quality-semantics cell on the same row. The verifier scans
# both text and JSON output shapes.
#
# Bash 3.2 compatible. MEM004 emitter-internal carve-out — pipes /
# python3 / $() permitted internally.

set -u

NAME="m027-p01-predictive-goodhart-pairing.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CE="$PROJECT_ROOT/scripts/engine/cost-estimate.sh"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if [ ! -f "$CE" ]; then
  fail "scripts/engine/cost-estimate.sh missing"
fi

# --- Text mode ---
text_out="$(bash "$CE" --description "test prompt" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s cost-estimate.sh text exit %d\n%s\n' "$NAME" "$rc" "$text_out" >&2
  exit 1
fi

for tier in Quick Standard Full; do
  row=$(printf '%s\n' "$text_out" | grep -E "^${tier}[[:space:]]" | head -n 1)
  if [ -z "$row" ]; then
    fail "text mode: tier row missing: $tier"
  fi
  has_cost=0
  has_quality=0
  if printf '%s' "$row" | grep -qE '([0-9]+\.[0-9]+|\(unavailable\))'; then
    has_cost=1
  fi
  if printf '%s' "$row" | grep -qE 'best-effort|self-review|adversarial-gate'; then
    has_quality=1
  fi
  if [ "$has_cost" -eq 1 ] && [ "$has_quality" -eq 0 ]; then
    fail "text mode: $tier row has cost but no quality (Goodhart violation)"
  fi
  if [ "$has_cost" -eq 0 ]; then
    fail "text mode: $tier row missing cost cell entirely"
  fi
done

# --- JSON mode ---
json_out="$(bash "$CE" --description "test prompt" --format json 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s cost-estimate.sh json exit %d\n%s\n' "$NAME" "$rc" "$json_out" >&2
  exit 1
fi

# Use python3 (standard on macOS) for JSON validation. Falls back to
# regex if python3 missing.
if command -v python3 >/dev/null 2>&1; then
  py_check="$(printf '%s' "$json_out" | python3 -c 'import json,sys
d=json.loads(sys.stdin.read())
tiers=d.get("tiers",{})
for k in ("quick","standard","full"):
    t=tiers.get(k)
    if t is None:
        print("MISSING:"+k); sys.exit(1)
    if "cost_usd" not in t:
        print("NO_COST:"+k); sys.exit(1)
    if "quality" not in t or not isinstance(t.get("quality"),str) or t["quality"]=="":
        print("NO_QUALITY:"+k); sys.exit(1)
print("OK")
' 2>&1)"
  if [ "$py_check" != "OK" ]; then
    fail "json mode: Goodhart pairing violation: $py_check"
  fi
else
  for tier in quick standard full; do
    if ! printf '%s' "$json_out" | grep -qE "\"${tier}\":\\{[^}]*\"cost_usd\""; then
      fail "json mode: $tier missing cost_usd"
    fi
    if ! printf '%s' "$json_out" | grep -qE "\"${tier}\":\\{[^}]*\"quality\""; then
      fail "json mode: $tier missing quality"
    fi
  done
fi

printf 'PASS: %s text + JSON Goodhart pairing verified for 3 tiers\n' "$NAME"
exit 0
