#!/usr/bin/env bash
# scripts/verify/m027-p01-intensity-json-cost-estimates.sh — M027/P01
# Truth #9 (D026).
#
# Asserts intensity-recommend.sh --format json emits a single-line JSON
# document carrying the D026-mandated keys: `intensity`, `confidence`,
# `reasoning`, `scope`, `risk_level`, `complexity`, `risk_signals`,
# `cap_score`, and `cost_estimates` keyed by `quick`/`standard`/`full`,
# each with `cost_usd` (number-or-null), `input_tokens` (int),
# `output_tokens` (int), `pricing_warning` (string).
#
# Bash 3.2 compatible. MEM004 emitter-internal carve-out — python3
# permitted internally.

set -u

NAME="m027-p01-intensity-json-cost-estimates.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
IR="$PROJECT_ROOT/scripts/engine/intensity-recommend.sh"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

[ -f "$IR" ] || fail "intensity-recommend.sh missing"

out="$(bash "$IR" --description "test" --format json 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s intensity-recommend.sh exit %d\n%s\n' "$NAME" "$rc" "$out" >&2
  exit 1
fi

# Single-line JSON document.
nlines=$(printf '%s' "$out" | awk 'END { print NR }')
if [ "$nlines" -ne 1 ]; then
  printf 'FAIL: %s expected single-line JSON output (got %d lines)\n' "$NAME" "$nlines" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  py_out="$(printf '%s' "$out" | python3 -c 'import json,sys
d=json.loads(sys.stdin.read())
top=("intensity","confidence","reasoning","scope","risk_level","complexity","risk_signals","cap_score","cost_estimates")
for k in top:
    if k not in d:
        print("MISSING_TOP:"+k); sys.exit(1)
ce=d["cost_estimates"]
for tier in ("quick","standard","full"):
    if tier not in ce:
        print("MISSING_TIER:"+tier); sys.exit(1)
    t=ce[tier]
    for sub in ("cost_usd","input_tokens","output_tokens","pricing_warning"):
        if sub not in t:
            print("MISSING_SUB:"+tier+"."+sub); sys.exit(1)
    if not (t["cost_usd"] is None or isinstance(t["cost_usd"],(int,float))):
        print("BAD_COST:"+tier); sys.exit(1)
    if not isinstance(t["input_tokens"],int):
        print("BAD_IN_TOK:"+tier); sys.exit(1)
    if not isinstance(t["output_tokens"],int):
        print("BAD_OUT_TOK:"+tier); sys.exit(1)
    if not isinstance(t["pricing_warning"],str):
        print("BAD_WARNING:"+tier); sys.exit(1)
print("OK")
' 2>&1)"
  if [ "$py_out" != "OK" ]; then
    fail "JSON shape violation: $py_out"
  fi
else
  # Regex fallback (best-effort — does not validate types).
  for k in intensity confidence reasoning scope risk_level complexity risk_signals cap_score cost_estimates; do
    if ! printf '%s' "$out" | grep -qF "\"$k\""; then
      fail "missing top-level key: $k"
    fi
  done
  for tier in quick standard full; do
    if ! printf '%s' "$out" | grep -qE "\"${tier}\":\\{"; then
      fail "missing tier: $tier"
    fi
  done
fi

printf 'PASS: %s D026 JSON shape verified (cost_estimates per tier)\n' "$NAME"
exit 0
