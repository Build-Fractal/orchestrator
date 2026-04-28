#!/usr/bin/env bash
# scripts/verify/m018-p05-unit-close-additivity.sh — phase-truth verifier:
# "`unit_close` JSONL records carry additive integer fields
# `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`,
# and `tier1_invocations`, computed by aggregating the per-task
# `payload_breakdown` records on the same milestone/phase/task scope at
# unit_close emit-time; pre-P05 unit_close records remain valid JSON;
# missing fields default to 0 in rollups (CON-5)."
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

WS="$REPO_ROOT/scripts/knowledge/write-summary.sh"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p05-build-fixture.sh"
SAVINGS_LOG="$REPO_ROOT/tests/fixtures/m018-p05-savings-log/execution-log.jsonl"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

for p in "$WS" "$HELPER" "$SAVINGS_LOG"; do
  if [ ! -f "$p" ]; then
    fail "prerequisite missing: $p"
    exit 1
  fi
done

# --- Assertion 1: write-summary.sh source carries the four additive fields
# on its unit_close printf, plus the rollup helper definition.
if grep -q '_ws_rollup_savings_fields()' "$WS"; then
  pass "_ws_rollup_savings_fields function defined in write-summary.sh"
else
  fail "_ws_rollup_savings_fields missing from write-summary.sh"
fi
for fld in 'filter_dropped_tokens' 'tier1_savings_tokens' 'tier2_savings_tokens' 'tier1_invocations'; do
  if grep -q "\"${fld}\":%d" "$WS"; then
    pass "additive printf field ${fld} present in write-summary.sh"
  else
    fail "additive printf field ${fld} missing from write-summary.sh"
  fi
done

# --- Assertion 2: rollup helper sums multiple records on the same scope.
TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM

ROOT="$TMPDIR_E/orch"
mkdir -p "$ROOT"
MS_ID="$(bash "$HELPER" "$ROOT" savings | head -n 1)"
LIVE_LOG="$ROOT/milestones/$MS_ID/execution-log.jsonl"

if [ ! -s "$LIVE_LOG" ]; then
  fail "fixture log missing or empty"
  exit 1
fi

# write-summary.sh is a CLI script (set -euo pipefail + arg-parsing at top),
# not directly sourceable. Extract the rollup helper via awk and source it
# in isolation (shim-style verifier per the P03/P04 pattern).
SHIM="$TMPDIR_E/ws-shim.sh"
awk '
  /^_ws_rollup_savings_fields\(\) \{/ { in_fn=1 }
  in_fn { print }
  in_fn && /^\}$/ { in_fn=0 }
' "$WS" > "$SHIM"
if [ ! -s "$SHIM" ]; then
  fail "could not extract _ws_rollup_savings_fields from write-summary.sh"
  exit 1
fi
ROLLUP_OUT="$TMPDIR_E/rollup.out"
bash -c "
set -u
. '$SHIM'
_ws_rollup_savings_fields '$LIVE_LOG' phase '$MS_ID' P05 '' || true
" >"$ROLLUP_OUT" 2>/dev/null || true

# Phase rollup expected (sum across T01..T05 payload_breakdown):
# fdrop = 100+300+0+200+0 = 600
# t1s   = 200+600+0+800+0 = 1600
# t2s   = 0+100+0+200+0   = 300
# t1i   = 1+2+0+3+0       = 6
EXP_FDROP=600
EXP_T1S=1600
EXP_T2S=300
EXP_T1I=6
GOT_FDROP="$(sed -n '1p' "$ROLLUP_OUT" | tr -d ' \n')"
GOT_T1S="$(sed -n '2p' "$ROLLUP_OUT" | tr -d ' \n')"
GOT_T2S="$(sed -n '3p' "$ROLLUP_OUT" | tr -d ' \n')"
GOT_T1I="$(sed -n '4p' "$ROLLUP_OUT" | tr -d ' \n')"
[ "$GOT_FDROP" = "$EXP_FDROP" ] && pass "phase-scope rollup filter_dropped_tokens=$GOT_FDROP" || fail "phase-scope filter_dropped_tokens=$GOT_FDROP (expected $EXP_FDROP)"
[ "$GOT_T1S"   = "$EXP_T1S"   ] && pass "phase-scope rollup tier1_savings_tokens=$GOT_T1S"   || fail "phase-scope tier1_savings_tokens=$GOT_T1S (expected $EXP_T1S)"
[ "$GOT_T2S"   = "$EXP_T2S"   ] && pass "phase-scope rollup tier2_savings_tokens=$GOT_T2S"   || fail "phase-scope tier2_savings_tokens=$GOT_T2S (expected $EXP_T2S)"
[ "$GOT_T1I"   = "$EXP_T1I"   ] && pass "phase-scope rollup tier1_invocations=$GOT_T1I"     || fail "phase-scope tier1_invocations=$GOT_T1I (expected $EXP_T1I)"

# --- Assertion 3: Drive write-summary.sh as a CLI on phase-scope and assert
# the appended unit_close record carries the four additive fields summing the
# in-scope payload_breakdown records.
SUM_OUT="$TMPDIR_E/P05-SUMMARY.md"
ORCHESTRATOR_ROOT="$ROOT" \
ORCH_M019_EMIT=1 \
bash "$WS" phase "$SUM_OUT" \
  --id=P05 --parent=M018F --milestone="$MS_ID" \
  --provides="fixture phase summary" \
  --requires="fixture" \
  --affects="none" \
  --key_files="none" \
  --key_decisions="none" \
  --patterns_established="none" \
  --drill_down_paths="none" \
  --duration=10m \
  --verification_result=pass \
  --observability_surfaces="none" \
  --body="fixture body" \
  --completed_at=2026-04-28T05:10:00Z \
  >/dev/null 2>&1 || true

LIVE_UC="$(grep '"record_type":"unit_close"' "$LIVE_LOG" | grep '"granularity":"phase"' | grep "\"phase\":\"P05\"" | tail -n 1)"
if [ -z "$LIVE_UC" ]; then
  fail "no phase-scope unit_close record emitted to fixture log"
else
  pass "phase-scope unit_close record emitted"
  for pat in "\"filter_dropped_tokens\":$EXP_FDROP" "\"tier1_savings_tokens\":$EXP_T1S" "\"tier2_savings_tokens\":$EXP_T2S" "\"tier1_invocations\":$EXP_T1I"; do
    if printf '%s' "$LIVE_UC" | grep -q "$pat"; then
      pass "live unit_close carries $pat"
    else
      fail "live unit_close missing $pat (record: $LIVE_UC)"
    fi
  done
  UC_FIRST="$(printf '%s' "$LIVE_UC" | head -c 1)"
  UC_LAST="$(printf '%s' "$LIVE_UC" | tail -c 1)"
  if [ "$UC_FIRST" = '{' ] && [ "$UC_LAST" = '}' ]; then
    pass "live unit_close record valid JSON object"
  else
    fail "live unit_close record not JSON-bracketed"
  fi
fi

# --- Assertion 4: pre-P05 back-compat. The fixture log carries a unit_close
# record on T99 with NO savings fields. Assert it parses cleanly as JSON.
PRE_UC="$(grep '"record_type":"unit_close"' "$SAVINGS_LOG" | grep '"task":"T99"')"
if [ -z "$PRE_UC" ]; then
  fail "fixture log missing pre-P05 unit_close T99 record"
else
  if printf '%s' "$PRE_UC" | grep -q 'tier1_savings_tokens'; then
    fail "pre-P05 unit_close record unexpectedly carries tier1_savings_tokens"
  else
    pass "pre-P05 unit_close record (T99) has no savings fields (CON-5 back-compat)"
  fi
  PRE_FIRST="$(printf '%s' "$PRE_UC" | head -c 1)"
  PRE_LAST="$(printf '%s' "$PRE_UC" | tail -c 1)"
  if [ "$PRE_FIRST" = '{' ] && [ "$PRE_LAST" = '}' ]; then
    pass "pre-P05 unit_close record valid JSON"
  else
    fail "pre-P05 unit_close record not JSON-bracketed"
  fi
  if command -v python3 >/dev/null 2>&1; then
    if printf '%s\n' "$PRE_UC" | python3 -c '
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    json.loads(line)
' >/dev/null 2>&1; then
      pass "pre-P05 unit_close record parses via python3 json.loads"
    else
      fail "pre-P05 unit_close record failed json.loads"
    fi
  fi
fi

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p05-unit-close-additivity (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p05-unit-close-additivity (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
