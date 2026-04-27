#!/usr/bin/env bash
# scripts/verify/m027-p01-cost-estimate-table.sh — M027/P01 Truth #3 (FR-20,
# FR-21, US-5 AS-1/AS-7).
#
# Asserts `bash scripts/engine/cost-estimate.sh --description ...`
# produces a three-row paired cost+quality table (Quick / Standard /
# Full), exactly one tier marked recommended (asterisk in RECOMMENDED
# column), and the verbatim D027 trailer.
#
# Bash 3.2 compatible. MEM004 emitter-internal carve-out: pipes / awk /
# $() permitted inside the verifier; the external Check shape is a
# single-script invocation.

set -u

NAME="m027-p01-cost-estimate-table.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CE="$PROJECT_ROOT/scripts/engine/cost-estimate.sh"

TRAILER='estimates +/-~20%; see commands/cost.md#accuracy'

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if [ ! -f "$CE" ]; then
  fail "scripts/engine/cost-estimate.sh missing"
fi

out="$(bash "$CE" --description "add a TypeScript rewrite of the parser" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s cost-estimate.sh exit %d\n%s\n' "$NAME" "$rc" "$out" >&2
  exit 1
fi

# 1. Three tier rows.
for tier in Quick Standard Full; do
  n=$(printf '%s\n' "$out" | grep -cE "^${tier}[[:space:]]" || true)
  if [ "$n" -lt 1 ]; then
    fail "missing tier row: $tier"
  fi
done

# 2. Exactly one recommended marker (asterisk in RECOMMENDED column —
#    a line that starts with a tier name and ends with '*' after
#    trailing whitespace).
recommended=$(printf '%s\n' "$out" | grep -cE '^(Quick|Standard|Full)[[:space:]].*\*[[:space:]]*$' || true)
if [ "$recommended" -ne 1 ]; then
  fail "expected exactly one recommended tier (got $recommended)"
fi

# 3. Verbatim D027 trailer.
if ! printf '%s\n' "$out" | grep -qF "$TRAILER"; then
  fail "missing verbatim D027 trailer: $TRAILER"
fi

# 4. Each tier row carries a numeric cost OR (unavailable) sentinel.
for tier in Quick Standard Full; do
  row=$(printf '%s\n' "$out" | grep -E "^${tier}[[:space:]]" | head -n 1)
  if ! printf '%s' "$row" | grep -qE '([0-9]+\.[0-9]+|\(unavailable\))'; then
    fail "$tier row missing cost cell (numeric or (unavailable))"
  fi
done

# 5. Each tier row carries a quality semantics token.
for tier in Quick Standard Full; do
  row=$(printf '%s\n' "$out" | grep -E "^${tier}[[:space:]]" | head -n 1)
  if ! printf '%s' "$row" | grep -qE 'best-effort|self-review|adversarial-gate'; then
    fail "$tier row missing quality semantics token"
  fi
done

printf 'PASS: %s 3-row paired table + recommendation + D027 trailer verified\n' "$NAME"
exit 0
