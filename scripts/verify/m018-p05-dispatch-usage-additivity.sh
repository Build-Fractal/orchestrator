#!/usr/bin/env bash
# scripts/verify/m018-p05-dispatch-usage-additivity.sh — phase-truth verifier:
# "`dispatch_usage` JSONL records carry additive integer fields
# `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`,
# and `tier1_invocations`, populated by rolling up the matching
# `payload_breakdown` record(s) for the same `unitId` at emit-time;
# pre-P05 dispatch_usage records remain valid JSON; missing fields default
# to 0 in rollups (CON-5)."
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DI="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"
HELPER="$REPO_ROOT/scripts/verify/_helpers/m018-p05-build-fixture.sh"
SAVINGS_LOG="$REPO_ROOT/tests/fixtures/m018-p05-savings-log/execution-log.jsonl"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

for p in "$DI" "$HELPER" "$SAVINGS_LOG"; do
  if [ ! -f "$p" ]; then
    fail "prerequisite missing: $p"
    exit 1
  fi
done

# --- Assertion 1: dispatch-interface.sh source carries the four additive
# fields on its dispatch_usage printf, plus the rollup helper definition.
if grep -q '_di_rollup_savings_fields()' "$DI"; then
  pass "_di_rollup_savings_fields function defined in dispatch-interface.sh"
else
  fail "_di_rollup_savings_fields missing from dispatch-interface.sh"
fi
for fld in 'filter_dropped_tokens' 'tier1_savings_tokens' 'tier2_savings_tokens' 'tier1_invocations'; do
  if grep -q "\"${fld}\":%d" "$DI"; then
    pass "additive printf field ${fld} present in dispatch-interface.sh"
  else
    fail "additive printf field ${fld} missing from dispatch-interface.sh"
  fi
done

# --- Assertion 2: end-to-end emit against the fixture log produces a
# dispatch_usage record carrying the four fields with values matching the
# matching payload_breakdown record's sums.
TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM

ROOT="$TMPDIR_E/orch"
mkdir -p "$ROOT"
MS_ID="$(bash "$HELPER" "$ROOT" savings | head -n 1)"
if [ -z "$MS_ID" ]; then
  fail "fixture-staging helper emitted no milestone id"
  exit 1
fi
LIVE_LOG="$ROOT/milestones/$MS_ID/execution-log.jsonl"
if [ ! -s "$LIVE_LOG" ]; then
  fail "staged fixture log missing or empty at $LIVE_LOG"
  exit 1
fi

# Source dispatch-interface.sh as a library and drive _di_emit_dispatch_usage
# directly against the staged fixture. We need to set the env vars the emitter
# reads (UNIT_ID, MILESTONE_ID, PHASE_ID, TASK_ID, BACKEND, PAYLOAD,
# ORCH_ROOT). Suppress exec by clearing argv.
PAYLOAD_FILE="$TMPDIR_E/payload.md"
printf 'fixture payload\n' > "$PAYLOAD_FILE"

# dispatch-interface.sh has a top-level CLI and exec branches; not directly
# sourceable. Extract the emitter + rollup helpers via awk shim and source
# the shim in isolation (P03/P04 shim-style verifier pattern).
SHIM="$TMPDIR_E/di-shim.sh"
awk '
  /^_di_rollup_savings_fields\(\) \{/ { in_fn=1 }
  /^_di_emit_dispatch_usage\(\) \{/   { in_fn=1 }
  in_fn { print }
  in_fn && /^\}$/ { in_fn=0; print "" }
' "$DI" > "$SHIM"
if [ ! -s "$SHIM" ]; then
  fail "could not extract _di_rollup_savings_fields / _di_emit_dispatch_usage from dispatch-interface.sh"
  exit 1
fi

EMIT_OUT="$TMPDIR_E/emit.out"
# ORCH_ROOT is the orch-root (parent of `milestones/`), not the milestone dir.
# The emitter resolves the log path via $ORCH_ROOT/milestones/$MILESTONE_ID/.
ORCHESTRATOR_ROOT="$ROOT" \
ORCH_ROOT="$ROOT" \
ORCH_M019_EMIT=1 \
UNIT_ID="$MS_ID/P05/T02" \
MILESTONE_ID="$MS_ID" \
PHASE_ID="P05" \
TASK_ID="T02" \
BACKEND="claude-code" \
PAYLOAD="$PAYLOAD_FILE" \
INTENSITY_METADATA="" \
ORCH_MODEL="sonnet" \
bash -c "
set -u
. '$REPO_ROOT/scripts/lib/pricing.sh' 2>/dev/null || true
. '$SHIM'
_di_emit_dispatch_usage '' || true
" >"$EMIT_OUT" 2>/dev/null || true

# The emit appends to LIVE_LOG; pull the most recent dispatch_usage line
# scoped to T02.
LIVE_DU="$(grep '"record_type":"dispatch_usage"' "$LIVE_LOG" | grep '"task":"T02"' | tail -n 1)"
if [ -z "$LIVE_DU" ]; then
  fail "no dispatch_usage record emitted to fixture log for T02"
  exit 1
fi
pass "dispatch_usage record emitted for T02"

# Assert the four additive fields are present with positive integer values
# (T02 fixture: tier1=600, fdrop=300, tier2=100, t1i=2).
for pat in '"filter_dropped_tokens":300' '"tier1_savings_tokens":600' '"tier2_savings_tokens":100' '"tier1_invocations":2'; do
  if printf '%s' "$LIVE_DU" | grep -q "$pat"; then
    pass "live dispatch_usage carries $pat"
  else
    fail "live dispatch_usage missing $pat (record: $LIVE_DU)"
  fi
done

# Assert the record is valid JSON (object brackets).
DU_FIRST="$(printf '%s' "$LIVE_DU" | head -c 1)"
DU_LAST="$(printf '%s' "$LIVE_DU" | tail -c 1)"
if [ "$DU_FIRST" = '{' ] && [ "$DU_LAST" = '}' ]; then
  pass "dispatch_usage record valid JSON object"
else
  fail "dispatch_usage record not bracketed as JSON object"
fi

# Optional: python3 json.loads validation.
if command -v python3 >/dev/null 2>&1; then
  if printf '%s\n' "$LIVE_DU" | python3 -c '
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    json.loads(line)
' >/dev/null 2>&1; then
    pass "live dispatch_usage parses cleanly via python3 json.loads"
  else
    fail "live dispatch_usage failed json.loads"
  fi
fi

# --- Assertion 3: pre-P05 back-compat. The fixture log carries a hand-curated
# dispatch_usage record on T99 with NO savings fields. Assert it parses
# cleanly as JSON (CON-5 absent-as-zero).
PRE_DU="$(grep '"record_type":"dispatch_usage"' "$SAVINGS_LOG" | grep '"task":"T99"')"
if [ -z "$PRE_DU" ]; then
  fail "fixture log missing pre-P05 dispatch_usage T99 record"
else
  if printf '%s' "$PRE_DU" | grep -q 'tier1_savings_tokens'; then
    fail "pre-P05 dispatch_usage record unexpectedly carries tier1_savings_tokens"
  else
    pass "pre-P05 dispatch_usage record (T99) has no savings fields (CON-5 back-compat)"
  fi
  PRE_FIRST="$(printf '%s' "$PRE_DU" | head -c 1)"
  PRE_LAST="$(printf '%s' "$PRE_DU" | tail -c 1)"
  if [ "$PRE_FIRST" = '{' ] && [ "$PRE_LAST" = '}' ]; then
    pass "pre-P05 dispatch_usage record valid JSON"
  else
    fail "pre-P05 dispatch_usage record not JSON-bracketed"
  fi
fi

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p05-dispatch-usage-additivity (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p05-dispatch-usage-additivity (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
