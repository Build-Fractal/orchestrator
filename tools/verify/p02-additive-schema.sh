#!/usr/bin/env bash
# tools/verify/p02-additive-schema.sh — M030 P02 SC-11 byte-equality gate.
#
# Stages a controlled invocation of scripts/dispatch/dispatch-interface.sh
# against a committed fixture stage, captures the appended dispatch_usage
# record, and asserts byte-identical match against the corresponding
# pre-M030 fixture record (modulo the dynamic timestamp field, which is
# normalized on both sides before diff).
#
# Pre-amendment (T01): passes today against the unmodified emitter — this
# is the baseline. Post-amendment (T02): MUST continue to pass — new
# fields (model_routed, model_used, partial_flip_active, withheld_classes)
# may NOT appear when M030_SHADOW_MODE=0/unset. That is the additive-only
# contract per CON-2 / FR-19 / SC-11.
#
# Round-trip coverage: 1 happy-path round-trip (M001/P01/T01,
# claude-opus-4-7, payload=4096B → input_tokens=1024). Pricing-warning and
# adapter-failed shapes are exercised via fixture-presence grep only —
# reproducing those branches from a clean environment requires either a
# stale-pricing-rate setup or a crashing adapter, both out of scope for
# the byte-equality verifier.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. No `for` loops, no
# compound chains beyond two-link cap, no $(...) containing pipes.
#
# Exit 0 iff fail == 0. Emits SUMMARY: line at end.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl"
STAGE="$REPO_ROOT/tests/fixtures/m030-p02/round-trip-stage"
PLAN="$STAGE/phases/P01/tasks/M001-T01-stage-PLAN.md"
PAYLOAD="$STAGE/phases/P01/tasks/T01-stage-PAYLOAD.md"
INTENSITY_META="$STAGE/intensity-metadata.txt"
LOG_FILE="$STAGE/execution-log.jsonl"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

# ---------- Gate 1: prerequisites exist ----------

ok=1
if [ ! -f "$FIXTURE" ]; then
  ok=0
  printf 'FAIL: fixture missing at %s\n' "$FIXTURE"
fi
if [ ! -f "$PLAN" ]; then
  ok=0
  printf 'FAIL: stage plan missing at %s\n' "$PLAN"
fi
if [ ! -f "$PAYLOAD" ]; then
  ok=0
  printf 'FAIL: stage payload missing at %s\n' "$PAYLOAD"
fi
if [ ! -f "$INTENSITY_META" ]; then
  ok=0
  printf 'FAIL: stage intensity-metadata missing at %s\n' "$INTENSITY_META"
fi
if [ ! -f "$DISPATCH" ]; then
  ok=0
  printf 'FAIL: dispatch-interface.sh missing at %s\n' "$DISPATCH"
fi
if [ "$ok" -eq 1 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 2: payload size is exactly 4096 bytes ----------
# 4096 / 4 = 1024 input_tokens_estimate via chars_to_tokens_quartile —
# load-bearing for byte-equality with fixture record 1.

PSIZE_TMP="/tmp/p02-additive-psize.txt"
rm -f "$PSIZE_TMP" 2>/dev/null
wc -c < "$PAYLOAD" > "$PSIZE_TMP" 2>/dev/null
psize="$(tr -d '[:space:]' < "$PSIZE_TMP")"
rm -f "$PSIZE_TMP" 2>/dev/null
if [ "$psize" = "4096" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: stage payload size %s != 4096 bytes (would change input_tokens_estimate)\n' "$psize"
fi

# ---------- Gate 3: round-trip happy-path record ----------
# Stage env: unset CLAUDECODE + M030_SHADOW_MODE; export ORCHESTRATOR_ROOT
# so the emitter's ORCH_ROOT/phases/ carve-out routes the log to the stage.

unset CLAUDECODE
unset M030_SHADOW_MODE
unset ORCH_MODEL
export ORCHESTRATOR_ROOT="$STAGE"

# Empty the log file before invocation.
rm -f "$LOG_FILE" 2>/dev/null
: > "$LOG_FILE"

# Invoke dispatch-interface.sh; discard stdout (adapter result is irrelevant).
bash "$DISPATCH" \
  --task-plan "$PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" \
  --backend stub \
  > /dev/null 2>&1
dispatch_rc=$?

# dispatch_rc is informational only — emitter is bail-safe; even on
# non-zero dispatch exit, the dispatch_usage line should be appended IF
# the dispatch reached the post-BACKEND emit point. We assert presence of
# the line directly rather than gating on dispatch_rc.

# Capture the dispatch_usage line from the staged log.
ACTUAL_TMP="/tmp/p02-additive-actual.jsonl"
rm -f "$ACTUAL_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$ACTUAL_TMP" 2>/dev/null

ACTUAL_LINECOUNT_TMP="/tmp/p02-additive-actual-lc.txt"
rm -f "$ACTUAL_LINECOUNT_TMP" 2>/dev/null
wc -l < "$ACTUAL_TMP" > "$ACTUAL_LINECOUNT_TMP" 2>/dev/null
actual_lc="$(tr -d '[:space:]' < "$ACTUAL_LINECOUNT_TMP")"
rm -f "$ACTUAL_LINECOUNT_TMP" 2>/dev/null
if [ -z "$actual_lc" ]; then
  actual_lc=0
fi

if [ "$actual_lc" -lt 1 ]; then
  fail=$((fail + 1))
  printf 'FAIL: no dispatch_usage record appended to %s (dispatch_rc=%d)\n' "$LOG_FILE" "$dispatch_rc"
else
  # Normalize timestamp on both sides before diff. Fixture record 1
  # corresponds to M001/P01/T01 happy-path with model=claude-opus-4-7.
  EXPECTED_TMP="/tmp/p02-additive-expected.jsonl"
  EXPECTED_NORM_TMP="/tmp/p02-additive-expected-norm.jsonl"
  ACTUAL_NORM_TMP="/tmp/p02-additive-actual-norm.jsonl"
  rm -f "$EXPECTED_TMP" "$EXPECTED_NORM_TMP" "$ACTUAL_NORM_TMP" 2>/dev/null

  # Extract the first happy-path fixture record (M001/P01/T01).
  grep -F '"unitId":"M001/P01/T01"' "$FIXTURE" > "$EXPECTED_TMP" 2>/dev/null

  # Normalize timestamps on both sides to the same sentinel string.
  sed 's/"timestamp":"[^"]*"/"timestamp":"<NORMALIZED>"/' "$EXPECTED_TMP" > "$EXPECTED_NORM_TMP" 2>/dev/null
  sed 's/"timestamp":"[^"]*"/"timestamp":"<NORMALIZED>"/' "$ACTUAL_TMP" > "$ACTUAL_NORM_TMP" 2>/dev/null

  diff "$EXPECTED_NORM_TMP" "$ACTUAL_NORM_TMP" > /dev/null 2>&1
  diff_rc=$?

  if [ "$diff_rc" -eq 0 ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: round-trip happy-path byte-equality diff non-empty\n'
    printf '  expected (normalized): '
    cat "$EXPECTED_NORM_TMP"
    printf '  actual   (normalized): '
    cat "$ACTUAL_NORM_TMP"
  fi

  rm -f "$EXPECTED_TMP" "$EXPECTED_NORM_TMP" "$ACTUAL_NORM_TMP" 2>/dev/null
fi

rm -f "$ACTUAL_TMP" 2>/dev/null

# ---------- Gate 4: forbidden P02 fields absent from emitted record ----------
# Even before T02 amends the emitter, this gate asserts that the round-trip
# log line contains NONE of the new M030 fields. Post-T02, this gate must
# still pass under M030_SHADOW_MODE=0/unset — the additive-only contract.

forbidden_present=0
grep -q -F '"model_routed"' "$LOG_FILE" 2>/dev/null
if [ $? -eq 0 ]; then
  forbidden_present=1
  printf 'FAIL: forbidden token "model_routed" present in non-shadow round-trip\n'
fi
grep -q -F '"model_used"' "$LOG_FILE" 2>/dev/null
if [ $? -eq 0 ]; then
  forbidden_present=1
  printf 'FAIL: forbidden token "model_used" present in non-shadow round-trip\n'
fi
grep -q -F '"partial_flip_active"' "$LOG_FILE" 2>/dev/null
if [ $? -eq 0 ]; then
  forbidden_present=1
  printf 'FAIL: forbidden token "partial_flip_active" present in non-shadow round-trip\n'
fi
grep -q -F '"withheld_classes"' "$LOG_FILE" 2>/dev/null
if [ $? -eq 0 ]; then
  forbidden_present=1
  printf 'FAIL: forbidden token "withheld_classes" present in non-shadow round-trip\n'
fi

if [ "$forbidden_present" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# ---------- Gate 5: pricing-warning + cost-null shapes present in fixture ----------
# These shapes are out-of-scope for full round-trip (require stale-pricing
# or crashing-adapter setups). Verified via grep-presence on the fixture.

grep -q -F '"pricing_warning"' "$FIXTURE"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: fixture missing pricing_warning record(s) (CON-2 degradation shape)\n'
fi

grep -q -F '"estimated_cost_usd":null' "$FIXTURE"
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: fixture missing estimated_cost_usd:null record(s) (CON-2 degradation shape)\n'
fi

printf 'WARN: pricing-warning + adapter-failed round-trip not exercised — fixture-presence grep only (see verifier doc-block)\n'

# ---------- Cleanup ----------

rm -f "$LOG_FILE" 2>/dev/null

printf 'SUMMARY: p02-additive-schema.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
