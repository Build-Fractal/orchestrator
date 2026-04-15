#!/usr/bin/env bash
# run-parity.sh — End-to-end parity verification for P05 refactored dispatch scripts.
# Runs from repo root. Exits 0 iff every check passes.
#
# Checks (6 groups per P05/T05-PLAN):
#   1. build-context.sh output vs golden-payload-M004-P04-T04.md (normalized)
#   2. compress-payload.sh output vs golden-compressed-budget2000.md (normalized)
#   3. select-model.sh default-mode output for all 3 tiers (heavy/standard/light)
#   4. select-model.sh --list-fallback for all 3 tiers
#   5. select-model.sh --next-fallback chain walk
#      (opus->sonnet, sonnet->haiku, haiku->chain-exhausted-nonzero)
#   6. Event + RESULT emission audit on all 3 refactored scripts
#      (each emits >=1 EVENT: line and exactly 1 RESULT: line)
#
# Known P06 XFAIL (reported, does NOT count toward failure tally):
#   - build-context.sh emit_event calls in the recipe branch redirect their
#     output to /dev/null 2>&1 (pre-existing pre-refactor bug carried through
#     T02 byte-for-byte-parity refactor). This causes the check-6 EVENT count
#     for build-context.sh to be 0. Fixing this is P06 scope ("fix dispatch
#     scripts to uniformly route emit_event to stderr"); this harness reports
#     the condition as XFAIL: so the regression surface remains visible.
#
# Self-cleaning: every mktemp is removed via trap EXIT. The harness does NOT
# write to the real execution log, does NOT modify any production script, and
# does NOT initialise the run context (it sources errors.sh only, for
# emit_result, to avoid the run-context SIGPIPE issue queued for P06).
#
# Bash 3.2 compatible (NFR-200). No jq, no assoc arrays, no array-read
# builtins, no inline `date`, no proc-sub in while-read loops (AP-001).

set -u

# --- cd to repo root so all relative paths resolve ---
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || { printf 'run-parity.sh: cannot cd to repo root\n' >&2; exit 1; }

# --- Source errors.sh for emit_result on exit (no run-context/events) ---
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/errors.sh"

FIXTURES_DIR=".specify/orchestrator/milestones/M004/phases/P05/fixtures"
GOLDEN_PAYLOAD="$FIXTURES_DIR/golden-payload-M004-P04-T04.md"
GOLDEN_COMPRESS="$FIXTURES_DIR/golden-compressed-budget2000.md"

# --- Private temp directory — every mktemp allocates inside it so the
# EXIT trap can wipe the entire tree regardless of subshell scoping. This
# avoids the classic bash pitfall where a tracking variable mutated inside
# a command-substitution subshell does not propagate to the parent.
_RP_TMPDIR="$(mktemp -d -t run-parity-XXXXXX)" \
  || { printf 'run-parity.sh: mktemp -d failed\n' >&2; exit 2; }
_track_tmp() {
  mktemp "$_RP_TMPDIR/slot.XXXXXX"
}
_cleanup() {
  [ -n "${_RP_TMPDIR:-}" ] && [ -d "$_RP_TMPDIR" ] && rm -rf "$_RP_TMPDIR" 2>/dev/null || true
}
trap '_cleanup' EXIT INT TERM HUP

FAIL=0
XFAIL_COUNT=0
PASS_COUNT=0

pass()  { printf 'PASS:  %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail()  { printf 'FAIL:  %s\n' "$1"; FAIL=$((FAIL + 1)); }
xfail() { printf 'XFAIL: %s  (P06 scope — not counted)\n' "$1"; XFAIL_COUNT=$((XFAIL_COUNT + 1)); }

# --- Normalisation: strip volatile manifest columns ---
# * line ranges (shift with upstream file growth)
# * token estimates (round to nearest 100)
# * knowledge entry counts
normalize() {
  sed -E \
    -e 's/\| ([0-9]+)-([0-9]+) \|/| LINES |/g' \
    -e 's/~[0-9]+/~TOKENS/g' \
    -e 's/\(([0-9]+) entries\)/(N entries)/g'
}

printf '=== P05 Parity Harness ===\n'

# --- Check 1: build-context.sh parity vs golden payload ---
if [ -f "$GOLDEN_PAYLOAD" ]; then
  tmp_refactored="$(_track_tmp)"
  tmp_golden_norm="$(_track_tmp)"
  tmp_refactored_norm="$(_track_tmp)"
  if bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 \
       > "$tmp_refactored" 2>/dev/null; then
    normalize < "$GOLDEN_PAYLOAD"   > "$tmp_golden_norm"
    normalize < "$tmp_refactored"   > "$tmp_refactored_norm"
    if diff -q "$tmp_golden_norm" "$tmp_refactored_norm" >/dev/null 2>&1; then
      pass "build-context.sh parity (M004/P04/T04)"
    else
      fail "build-context.sh parity (M004/P04/T04)"
      printf '       --- golden (normalized) / +++ refactored (normalized)\n' >&2
      diff -u "$tmp_golden_norm" "$tmp_refactored_norm" | head -60 >&2
    fi
  else
    fail "build-context.sh failed to run"
  fi
else
  fail "golden payload fixture missing at $GOLDEN_PAYLOAD"
fi

# --- Check 2: compress-payload.sh parity vs golden compressed ---
if [ -f "$GOLDEN_COMPRESS" ]; then
  tmp_in="$(_track_tmp)"
  tmp_out="$(_track_tmp)"
  tmp_gold_norm="$(_track_tmp)"
  tmp_out_norm="$(_track_tmp)"
  if bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 \
       > "$tmp_in" 2>/dev/null; then
    if bash scripts/dispatch/compress-payload.sh --budget 2000 --input "$tmp_in" \
         > "$tmp_out" 2>/dev/null; then
      normalize < "$GOLDEN_COMPRESS" > "$tmp_gold_norm"
      normalize < "$tmp_out"         > "$tmp_out_norm"
      if diff -q "$tmp_gold_norm" "$tmp_out_norm" >/dev/null 2>&1; then
        pass "compress-payload.sh parity (budget 2000)"
      else
        fail "compress-payload.sh parity (budget 2000)"
        diff -u "$tmp_gold_norm" "$tmp_out_norm" | head -60 >&2
      fi
    else
      fail "compress-payload.sh failed to run"
    fi
  else
    fail "build-context.sh failed to produce input for compress test"
  fi
else
  fail "golden compressed fixture missing at $GOLDEN_COMPRESS"
fi

# --- Check 3: select-model.sh default-mode parity for all 3 tiers ---
check_model() {
  local tier="$1" expected="$2" actual
  actual="$(bash scripts/dispatch/select-model.sh "$tier" \
             --routing-config templates/routing.yaml 2>/dev/null)"
  if [ "$actual" = "$expected" ]; then
    pass "select-model.sh $tier -> $expected"
  else
    fail "select-model.sh $tier got '$actual' expected '$expected'"
  fi
}
check_model heavy    "claude-opus-4-6 200000"
check_model standard "claude-sonnet-4-6 150000"
check_model light    "claude-haiku-4-5 80000"

# --- Check 4: --list-fallback for all 3 tiers ---
check_list_fallback() {
  local tier="$1" expected="$2" actual
  actual="$(bash scripts/dispatch/select-model.sh "$tier" \
             --routing-config templates/routing.yaml --list-fallback 2>/dev/null)"
  if [ "$actual" = "$expected" ]; then
    pass "select-model.sh $tier --list-fallback -> '$expected'"
  else
    fail "select-model.sh $tier --list-fallback got '$actual' expected '$expected'"
  fi
}
check_list_fallback heavy    "claude-sonnet-4-6,claude-haiku-4-5"
check_list_fallback standard "claude-haiku-4-5"
check_list_fallback light    ""

# --- Check 5: --next-fallback chain walk ---
next1="$(bash scripts/dispatch/select-model.sh heavy \
          --routing-config templates/routing.yaml \
          --next-fallback claude-opus-4-6 2>/dev/null)"
if [ "$next1" = "claude-sonnet-4-6" ]; then
  pass "next-fallback opus->sonnet"
else
  fail "next-fallback opus->(?) got '$next1'"
fi

next2="$(bash scripts/dispatch/select-model.sh heavy \
          --routing-config templates/routing.yaml \
          --next-fallback claude-sonnet-4-6 2>/dev/null)"
if [ "$next2" = "claude-haiku-4-5" ]; then
  pass "next-fallback sonnet->haiku"
else
  fail "next-fallback sonnet->(?) got '$next2'"
fi

if bash scripts/dispatch/select-model.sh heavy \
     --routing-config templates/routing.yaml \
     --next-fallback claude-haiku-4-5 >/dev/null 2>&1; then
  fail "next-fallback haiku should exit non-zero (chain exhausted)"
else
  pass "next-fallback chain exhausted exits non-zero"
fi

# --- Check 6: event + RESULT emission audit ---
# check_emissions <label> <expect_event_ge_1:yes|xfail> <cmd...>
check_emissions() {
  local label="$1" expect_event="$2"
  shift 2
  local out ev_count rc_count
  out="$("$@" 2>&1 >/dev/null)"
  ev_count="$(printf '%s\n' "$out" | grep -c '^EVENT:' || true)"
  rc_count="$(printf '%s\n' "$out" | grep -c '^RESULT:' || true)"
  # Normalize accidental whitespace from grep -c (some BSD variants)
  ev_count="$(printf '%s' "$ev_count" | tr -d ' \n')"
  rc_count="$(printf '%s' "$rc_count" | tr -d ' \n')"

  if [ "$expect_event" = "xfail" ] && [ "$ev_count" -lt 1 ]; then
    xfail "$label emits 0 EVENT: lines (pre-existing emit_event>/dev/null bug)"
  elif [ "$ev_count" -ge 1 ]; then
    pass "$label emits EVENT: lines ($ev_count)"
  else
    fail "$label emits no EVENT: lines"
  fi

  if [ "$rc_count" = "1" ]; then
    pass "$label emits exactly one RESULT: line"
  else
    fail "$label emits $rc_count RESULT: lines (expected 1)"
  fi
}

# build-context.sh: EVENT emission currently swallowed by >/dev/null in the
# recipe-resolved path (see header XFAIL note). Queued for P06.
check_emissions "build-context.sh" xfail \
  bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04

tmp_compress_in="$(_track_tmp)"
bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 \
  > "$tmp_compress_in" 2>/dev/null
check_emissions "compress-payload.sh" yes \
  bash scripts/dispatch/compress-payload.sh --budget 2000 --input "$tmp_compress_in"

check_emissions "select-model.sh" yes \
  bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml

# --- Summary ---
printf '\n=== P05 Parity Harness Summary ===\n'
printf 'pass=%d fail=%d xfail=%d\n' "$PASS_COUNT" "$FAIL" "$XFAIL_COUNT"

if [ "$FAIL" -eq 0 ]; then
  emit_result ok "" "p05 parity harness: ${PASS_COUNT} pass / ${XFAIL_COUNT} xfail"
  exit 0
else
  emit_result error VERIFY "p05 parity harness: ${FAIL} failure(s)"
  exit 1
fi
