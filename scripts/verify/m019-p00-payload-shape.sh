#!/usr/bin/env bash
# scripts/verify/m019-p00-payload-shape.sh — M019/P00 payload-shape gate.
#
# Asserts L1–L5 Opus 4.7 adaptation invariants on dispatch payload sources
# plus required .orchestrator/config/pricing.yml presence.
#
# Gate 1 (L1): First-Turn Completeness block + 4 subsections in build-context.sh
# Gate 2 (L2): <dispatch-volatile> / </dispatch-volatile> markers in build-context.sh
# Gate 3 (L3): No "thinking_budget" / "thinking budget" in templates/ or intensity-gate.sh
# Gate 4 (L4): Parallel Fan-Out directive + trigger logic in build-context.sh
# Gate 5 (L5): dispatch-prompt.md rewritten to positive examples; whitelist exists
# Gate 6: pricing.yml exists with required keys
#
# Exit 0 on all-pass, 1 otherwise. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_CONTEXT="$REPO_ROOT/scripts/dispatch/build-context.sh"
DISPATCH_TEMPLATE="$REPO_ROOT/templates/dispatch-prompt.md"
INTENSITY_GATE="$REPO_ROOT/scripts/engine/intensity-gate.sh"
PRICING_YML="$REPO_ROOT/.orchestrator/config/pricing.yml"
NEG_WHITELIST="$REPO_ROOT/templates/.p00-negative-guidance-retained.txt"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# --- Gate 0: required files exist ---
for f in "$BUILD_CONTEXT" "$DISPATCH_TEMPLATE" "$INTENSITY_GATE"; do
  if [ ! -f "$f" ]; then
    fail "file exists" "$f"
  fi
done

# --- Gate 1 (L1): First-Turn Completeness emission in build-context.sh ---
if grep -q 'First-Turn Completeness' "$BUILD_CONTEXT" 2>/dev/null; then
  pass "L1 build-context.sh emits First-Turn Completeness"
else
  fail "L1 build-context.sh emits First-Turn Completeness" "marker missing"
fi
for sub in '### Intent' '### Constraints' '### Acceptance Criteria' '### Files To Touch'; do
  if grep -qF "$sub" "$BUILD_CONTEXT" 2>/dev/null; then
    pass "L1 subsection present: $sub"
  else
    fail "L1 subsection present" "$sub missing from build-context.sh"
  fi
done

# --- Gate 2 (L2): <dispatch-volatile> markers in build-context.sh ---
if grep -q '<dispatch-volatile>' "$BUILD_CONTEXT" 2>/dev/null && grep -q '</dispatch-volatile>' "$BUILD_CONTEXT" 2>/dev/null; then
  pass "L2 dispatch-volatile markers present in build-context.sh"
else
  fail "L2 dispatch-volatile markers" "open/close markers missing from build-context.sh"
fi

# --- Gate 3 (L3): no thinking_budget in templates/ or intensity-gate.sh ---
tb_count=0
if [ -d "$REPO_ROOT/templates" ]; then
  tb_count="$(grep -rlE 'thinking_budget|thinking budget' "$REPO_ROOT/templates" 2>/dev/null | wc -l | tr -d ' ')"
fi
if [ "$tb_count" = "0" ]; then
  pass "L3 no thinking_budget in templates/"
else
  fail "L3 no thinking_budget in templates/" "found in $tb_count files"
fi
if [ -f "$INTENSITY_GATE" ] && grep -qE 'thinking_budget|thinking budget' "$INTENSITY_GATE" 2>/dev/null; then
  fail "L3 no thinking_budget in intensity-gate.sh" "found in $INTENSITY_GATE"
else
  pass "L3 no thinking_budget in intensity-gate.sh"
fi

# --- Gate 4 (L4): Parallel Fan-Out directive implementation in build-context.sh ---
if grep -q 'Parallel Fan-Out' "$BUILD_CONTEXT" 2>/dev/null && grep -qE 'parallel_fan_out|parallelizable' "$BUILD_CONTEXT" 2>/dev/null; then
  pass "L4 parallel fan-out directive logic present"
else
  fail "L4 parallel fan-out directive" "marker or trigger logic missing"
fi

# --- Gate 5 (L5): positive-examples rewrite of dispatch-prompt.md ---
# Enumerate all "Don't/Do not/Never/Avoid" lines in dispatch-prompt.md.
# Each must either (a) be in a section containing "Constitution XV" or
# "anti-pattern" within 5 surrounding lines, OR (b) be listed in the
# exception whitelist file.
if [ ! -f "$NEG_WHITELIST" ]; then
  fail "L5 exception whitelist exists" "$NEG_WHITELIST not found"
else
  pass "L5 exception whitelist exists"
fi

neg_violations=0
if [ -f "$DISPATCH_TEMPLATE" ]; then
  tmpneg="$(mktemp)"
  grep -nE "^[[:space:]]*-?[[:space:]]*(Don't|Do not|Never|Avoid)[[:space:]]" "$DISPATCH_TEMPLATE" > "$tmpneg" 2>/dev/null || true
  while IFS=: read -r lno rest; do
    [ -z "$lno" ] && continue
    # (a) Is this line number whitelisted?
    if [ -f "$NEG_WHITELIST" ] && grep -qE "^dispatch-prompt\.md:${lno}[[:space:]]" "$NEG_WHITELIST" 2>/dev/null; then
      continue
    fi
    # (b) Is there a constitutional-anti-pattern marker within 5 lines?
    start=$((lno - 5))
    [ "$start" -lt 1 ] && start=1
    end=$((lno + 5))
    ctx="$(sed -n "${start},${end}p" "$DISPATCH_TEMPLATE" 2>/dev/null)"
    if printf '%s' "$ctx" | grep -qE 'Constitution XV|anti-pattern'; then
      continue
    fi
    neg_violations=$((neg_violations + 1))
    echo "  - dispatch-prompt.md:${lno}: $rest" >&2
  done < "$tmpneg"
  rm -f "$tmpneg"
fi
if [ "$neg_violations" = "0" ]; then
  pass "L5 no unwhitelisted negative guidance in dispatch-prompt.md"
else
  fail "L5 negative guidance violations" "$neg_violations unwhitelisted lines (see stderr)"
fi

# --- Gate 6: pricing.yml presence + required keys ---
if [ ! -f "$PRICING_YML" ]; then
  fail "pricing.yml exists" "$PRICING_YML not found"
else
  pass "pricing.yml exists"
  for key in 'last_updated:' 'opus' 'sonnet' 'haiku' 'input' 'output'; do
    if grep -q "$key" "$PRICING_YML" 2>/dev/null; then
      pass "pricing.yml contains $key"
    else
      fail "pricing.yml required key" "$key missing"
    fi
  done
fi

# --- Summary ---
if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m019-p00-payload-shape.sh"
  exit 0
else
  echo "FAIL: m019-p00-payload-shape.sh ($fail_count failures)"
  exit 1
fi
