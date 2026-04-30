#!/usr/bin/env bash
# tools/verify/p02-fixture-shape.sh — M030 P02 fixture-shape gate.
#
# Asserts that tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl is
# well-formed: at least 5 records, every record contains the canonical
# pre-M030 dispatch_usage field tokens, and NO record contains the new
# P02 fields (model_routed, model_used, partial_flip_active,
# withheld_classes). Pairs with tools/verify/p02-additive-schema.sh —
# this gate verifies the fixture; that gate verifies the round-trip.
#
# Bash 3.2 compatible. AD-19 single-script-file shape: no inline `for`
# loops over Bash arrays, no compound &&/|| chains beyond the two-link
# cap, no $(...) containing pipes.
#
# Exit 0 iff fail == 0. Emits SUMMARY: line at end.

set -u

FIXTURE="tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl"

pass=0
fail=0

# ---------- Gate 1: fixture file exists ----------

if [ -f "$FIXTURE" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: fixture missing at %s\n' "$FIXTURE"
fi

# ---------- Gate 2: line count >= 5 ----------
# Write line count through a tmp file to avoid AP-009 compound shapes.

LINECOUNT_TMP="/tmp/p02-fixture-linecount.txt"
rm -f "$LINECOUNT_TMP" 2>/dev/null
wc -l < "$FIXTURE" > "$LINECOUNT_TMP" 2>/dev/null
linecount="$(tr -d '[:space:]' < "$LINECOUNT_TMP")"
rm -f "$LINECOUNT_TMP" 2>/dev/null
if [ -z "$linecount" ]; then
  linecount=0
fi
if [ "$linecount" -ge 5 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: fixture line count %s < 5\n' "$linecount"
fi

# ---------- Gate 3: required pre-M030 field tokens present ----------
# 15 load-bearing tokens from dispatch-interface.sh:283 / :298 printf
# templates. Each MUST appear at least once in the fixture.

check_present() {
  token="$1"
  grep -q -F "\"${token}\"" "$FIXTURE"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: required token "%s" missing from fixture\n' "$token"
  fi
}

check_present "unitId"
check_present "backend"
check_present "input_tokens_estimate"
check_present "output_tokens_estimate"
check_present "estimated_cost_usd"
check_present "pricing_version"
check_present "filter_dropped_tokens"
check_present "tier1_savings_tokens"
check_present "tier1_invocations"
check_present "tier3_compression_savings_tokens"
check_present "tier3_invocations"
check_present "model"
check_present "source"
check_present "emission_point"
check_present "timestamp"

# ---------- Gate 4: forbidden P02 field tokens absent ----------
# New M030 fields must NOT appear in the pre-M030 fixture — that is the
# additive-only contract's golden state.

check_absent() {
  token="$1"
  grep -q -F "\"${token}\"" "$FIXTURE"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: forbidden P02 token "%s" present in pre-M030 fixture\n' "$token"
  fi
}

check_absent "model_routed"
check_absent "model_used"
check_absent "partial_flip_active"
check_absent "withheld_classes"

# ---------- Gate 5: every record starts with record_type:dispatch_usage ----------

bad_start_tmp="/tmp/p02-fixture-bad-start.txt"
rm -f "$bad_start_tmp" 2>/dev/null
grep -v -c -F '{"record_type":"dispatch_usage"' "$FIXTURE" > "$bad_start_tmp" 2>/dev/null
bad_start="$(tr -d '[:space:]' < "$bad_start_tmp")"
rm -f "$bad_start_tmp" 2>/dev/null
if [ -z "$bad_start" ]; then
  bad_start=0
fi
if [ "$bad_start" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: %s line(s) do not start with {"record_type":"dispatch_usage"\n' "$bad_start"
fi

# ---------- Gate 6: every record ends with closing brace ----------

bad_end_tmp="/tmp/p02-fixture-bad-end.txt"
rm -f "$bad_end_tmp" 2>/dev/null
grep -v -c -E '\}$' "$FIXTURE" > "$bad_end_tmp" 2>/dev/null
bad_end="$(tr -d '[:space:]' < "$bad_end_tmp")"
rm -f "$bad_end_tmp" 2>/dev/null
if [ -z "$bad_end" ]; then
  bad_end=0
fi
if [ "$bad_end" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: %s line(s) do not end with closing brace\n' "$bad_end"
fi

printf 'SUMMARY: p02-fixture-shape.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
