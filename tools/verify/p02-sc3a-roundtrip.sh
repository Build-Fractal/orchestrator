#!/usr/bin/env bash
# tools/verify/p02-sc3a-roundtrip.sh — M030/P02/T03
#
# Validates SC-3a write-path correctness: for each shadow record in
# tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl, the recorded
# `model_routed` tier MUST equal the tier produced by an independent
# re-run of the classifier against the referenced PLAN.md plus a
# routing-table lookup (D-A7).
#
# Per-record steps:
#   1. Extract unitId from the record.
#   2. Resolve unitId (M###/P##/T##) to a PLAN.md path via canonical glob.
#   3. Run scripts/dispatch/classify-task.sh against that PLAN.md.
#   4. Look up routing.<character>.claude-code in templates/model-routing.yml.
#   5. Extract model_routed from the record.
#   6. Assert step-4 result == step-5 result.
#
# Bash 3.2 compatible. AD-19 single-script-file shape: per-record loop
# unrolled into 6 explicit blocks. Tmp-file intermediates throughout.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl"
CLASSIFIER="$REPO_ROOT/scripts/dispatch/classify-task.sh"
ROUTING_TABLE="$REPO_ROOT/templates/model-routing.yml"

pass=0
fail=0

# Helper: check one record. Args: record-index (1..6).
check_record() {
  i="$1"

  rec_tmp="/tmp/p02-sc3a-record-${i}.txt"
  uid_tmp="/tmp/p02-sc3a-uid-${i}.txt"
  path_tmp="/tmp/p02-sc3a-path-${i}.txt"
  cls_tmp="/tmp/p02-sc3a-classified-${i}.txt"
  char_tmp="/tmp/p02-sc3a-char-${i}.txt"
  expected_tmp="/tmp/p02-sc3a-expected-${i}.txt"
  routed_tmp="/tmp/p02-sc3a-routed-${i}.txt"

  rm -f "$rec_tmp" "$uid_tmp" "$path_tmp" "$cls_tmp" \
        "$char_tmp" "$expected_tmp" "$routed_tmp" 2>/dev/null

  # Step 1: extract i-th record.
  sed -n "${i}p" < "$FIXTURE" > "$rec_tmp"
  if [ ! -s "$rec_tmp" ]; then
    fail=$((fail + 1))
    printf 'FAIL: record %d — empty or missing line in %s\n' "$i" "$FIXTURE"
    return 0
  fi

  # Step 2: extract unitId.
  grep -oE '"unitId":"[^"]+"' < "$rec_tmp" | head -1 | sed 's/.*:"//; s/"$//' > "$uid_tmp"
  uid="$(cat "$uid_tmp")"
  if [ -z "$uid" ]; then
    fail=$((fail + 1))
    printf 'FAIL: record %d — unitId not extractable\n' "$i"
    return 0
  fi

  # Parse M###/P##/T## components.
  m_id="${uid%%/*}"
  rest="${uid#*/}"
  p_id="${rest%%/*}"
  t_id="${rest##*/}"

  # Step 3: resolve PLAN.md path.
  find "$REPO_ROOT/.orchestrator/milestones/${m_id}/phases/${p_id}/tasks" \
       -name "${t_id}-*-PLAN.md" -type f 2>/dev/null | head -1 > "$path_tmp"
  plan_path="$(cat "$path_tmp")"
  if [ -z "$plan_path" ]; then
    fail=$((fail + 1))
    printf 'FAIL: record %d (%s) — PLAN.md not resolvable under .orchestrator/milestones/%s/phases/%s/tasks/\n' "$i" "$uid" "$m_id" "$p_id"
    return 0
  fi

  # Step 4: classify the plan.
  bash "$CLASSIFIER" "$plan_path" > "$cls_tmp" 2>/dev/null
  grep -E '^character=' "$cls_tmp" | head -1 | sed 's/^character=//' > "$char_tmp"
  character="$(cat "$char_tmp")"
  if [ -z "$character" ]; then
    fail=$((fail + 1))
    printf 'FAIL: record %d (%s) — classifier did not emit character=\n' "$i" "$uid"
    return 0
  fi

  # Step 5: look up routing.<character>.claude-code.
  awk -v ch="$character" '
    BEGIN { in_routing = 0; in_class = 0 }
    /^routing:/                       { in_routing = 1; next }
    /^resolution:/                    { exit }
    in_routing && /^  [a-z_]+:$/      { in_class = ($1 == (ch ":")) ? 1 : 0; next }
    in_routing && in_class && /^    claude-code:/ {
      val = $2; gsub(/[",]/, "", val); print val; exit
    }
  ' "$ROUTING_TABLE" > "$expected_tmp"
  expected_tier="$(cat "$expected_tmp")"
  if [ -z "$expected_tier" ]; then
    fail=$((fail + 1))
    printf 'FAIL: record %d (%s) — routing-table lookup empty for character=%s\n' "$i" "$uid" "$character"
    return 0
  fi

  # Step 6: extract model_routed from record.
  grep -oE '"model_routed":"[^"]+"' < "$rec_tmp" | head -1 | sed 's/.*:"//; s/"$//' > "$routed_tmp"
  routed="$(cat "$routed_tmp")"
  if [ -z "$routed" ]; then
    fail=$((fail + 1))
    printf 'FAIL: record %d (%s) — model_routed not extractable\n' "$i" "$uid"
    return 0
  fi

  # Assertion.
  if [ "$expected_tier" = "$routed" ]; then
    pass=$((pass + 1))
    printf 'OK: record %d (%s) character=%s expected_tier=%s model_routed=%s\n' "$i" "$uid" "$character" "$expected_tier" "$routed"
  else
    fail=$((fail + 1))
    printf 'FAIL: record %d (%s) character=%s expected_tier=%s != model_routed=%s\n' "$i" "$uid" "$character" "$expected_tier" "$routed"
  fi

  rm -f "$rec_tmp" "$uid_tmp" "$path_tmp" "$cls_tmp" \
        "$char_tmp" "$expected_tmp" "$routed_tmp" 2>/dev/null
  return 0
}

if [ ! -f "$FIXTURE" ]; then
  printf 'FAIL: fixture missing at %s\n' "$FIXTURE"
  printf 'SUMMARY: p02-sc3a-roundtrip.sh pass=0 fail=1\n'
  exit 1
fi

# Unrolled per-record blocks (AD-19: no inline for loop).
check_record 1
check_record 2
check_record 3
check_record 4
check_record 5
check_record 6

printf 'SUMMARY: p02-sc3a-roundtrip.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
