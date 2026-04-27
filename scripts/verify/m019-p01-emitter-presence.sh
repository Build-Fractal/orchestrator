#!/usr/bin/env bash
# scripts/verify/m019-p01-emitter-presence.sh — M019/P01 emitter presence gate.
#
# Runs build-context + dispatch-interface (stub backend) + write-summary
# against the M999 fixture milestone, then counts the three record_type
# values in the fixture's execution-log.jsonl. Asserts:
#   - exactly one payload_breakdown record for the dispatched task
#   - exactly one dispatch_usage record for the dispatched task
#   - exactly one unit_close record at granularity=task
#   - every unit_close record carries both cost and quality keys (schema
#     validator enforces this — invoked at the end).
#
# Emits one PASS: or FAIL: summary line on stdout. Exit 0 on green, 1 otherwise.
#
# MEM004 carve-out: verification-script-internal; pipes/$()/awk permitted.
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_CONTEXT="$REPO_ROOT/scripts/dispatch/build-context.sh"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"
WRITE_SUMMARY="$REPO_ROOT/scripts/knowledge/write-summary.sh"
SCHEMA="$REPO_ROOT/scripts/verify/m019-schema.sh"
STUB_ADAPTER="$REPO_ROOT/scripts/dispatch/adapters/backend/stub.sh"
FIXTURE_MILESTONE="$REPO_ROOT/tests/fixtures/m019-p01/fixture-milestone"

for p in "$BUILD_CONTEXT" "$DISPATCH" "$WRITE_SUMMARY" "$SCHEMA" "$STUB_ADAPTER" "$FIXTURE_MILESTONE"; do
  if [ ! -e "$p" ]; then
    printf 'FAIL: m019-p01-emitter-presence.sh prerequisite-missing path=%s\n' "$p"
    exit 1
  fi
done

TMPDIR_G="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_G"' EXIT INT TERM

# Isolated snapshot of the fixture milestone — writes land in TMPDIR_G, not
# in the on-disk fixture.
ROOT="$TMPDIR_G/M999"
cp -R "$FIXTURE_MILESTONE" "$ROOT"

# Reset the execution log.
: > "$ROOT/execution-log.jsonl"

TASK_PLAN="$ROOT/phases/P01/tasks/T01-PLAN.md"
PAYLOAD="$TMPDIR_G/payload.md"
INTENSITY="$TMPDIR_G/intensity.yml"

printf 'model: claude-opus-4-7\n' > "$INTENSITY"

fail_count=0

# --- Step 1: build-context.sh emits one payload_breakdown ---
bash "$BUILD_CONTEXT" "$ROOT" M999 P01 T01 > "$PAYLOAD" 2>/dev/null || {
  printf 'FAIL: m019-p01-emitter-presence.sh build-context-nonzero\n'
  fail_count=$(( fail_count + 1 ))
}

# --- Step 2: dispatch-interface.sh emits one dispatch_usage via stub backend ---
ORCHESTRATOR_ROOT="$ROOT" bash "$DISPATCH" \
  --task-plan "$TASK_PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY" \
  --backend stub \
  >/dev/null 2>&1 || {
  printf 'FAIL: m019-p01-emitter-presence.sh dispatch-nonzero\n'
  fail_count=$(( fail_count + 1 ))
}

# --- Step 3: write-summary.sh (task) emits one unit_close ---
SUMMARY_OUT="$TMPDIR_G/T01-SUMMARY.md"
ORCHESTRATOR_ROOT="$ROOT" bash "$WRITE_SUMMARY" task "$SUMMARY_OUT" \
  --id=T01 --parent=P01 --milestone=M999 \
  --provides="fixture" --requires="none" --affects="none" \
  --key_files="fixture" --key_decisions="none" \
  --patterns_established="fixture" --drill_down_paths="fixture" \
  --duration=10s --verification_result=pass \
  --body="fixture-body" \
  >/dev/null 2>&1 || {
  printf 'FAIL: m019-p01-emitter-presence.sh write-summary-nonzero\n'
  fail_count=$(( fail_count + 1 ))
}

LOG="$ROOT/execution-log.jsonl"
if [ ! -s "$LOG" ]; then
  printf 'FAIL: m019-p01-emitter-presence.sh log-empty file=%s\n' "$LOG"
  exit 1
fi

# --- Step 4: count record_type values ---
count_records() {
  # grep -c exits 1 on zero matches; we treat that as "0". `|| true` preserves
  # the count path. tr strips newlines so the caller sees a clean integer.
  local n
  n="$(grep -c "\"record_type\":\"$1\"" "$LOG" 2>/dev/null || printf '0')"
  printf '%s' "$n" | tr -d '\n\r '
}

pb_count="$(count_records payload_breakdown)"
du_count="$(count_records dispatch_usage)"
uc_count="$(count_records unit_close)"

# M018/P00/T01: dispatch_usage now emits at TWO points per full pipeline run:
#   - emission_point="build-context"     (co-located with payload_breakdown)
#   - emission_point="dispatch-interface" (post-adapter happy/failure path)
# The fixture pipeline exercises both, so dispatch_usage-count=2 is expected.
# Each emission_point must appear exactly once.
count_emission_point() {
  local n
  n="$(grep -c "\"emission_point\":\"$1\"" "$LOG" 2>/dev/null || printf '0')"
  printf '%s' "$n" | tr -d '\n\r '
}
ep_bc="$(count_emission_point build-context)"
ep_di="$(count_emission_point dispatch-interface)"

[ "$pb_count" -eq 1 ] || {
  printf 'FAIL: m019-p01-emitter-presence.sh payload_breakdown-count=%s expected=1\n' "$pb_count"
  fail_count=$(( fail_count + 1 ))
}
[ "$du_count" -eq 2 ] || {
  printf 'FAIL: m019-p01-emitter-presence.sh dispatch_usage-count=%s expected=2 (build-context + dispatch-interface)\n' "$du_count"
  fail_count=$(( fail_count + 1 ))
}
[ "$ep_bc" -eq 1 ] || {
  printf 'FAIL: m019-p01-emitter-presence.sh emission_point=build-context count=%s expected=1\n' "$ep_bc"
  fail_count=$(( fail_count + 1 ))
}
[ "$ep_di" -eq 1 ] || {
  printf 'FAIL: m019-p01-emitter-presence.sh emission_point=dispatch-interface count=%s expected=1\n' "$ep_di"
  fail_count=$(( fail_count + 1 ))
}
[ "$uc_count" -eq 1 ] || {
  printf 'FAIL: m019-p01-emitter-presence.sh unit_close-count=%s expected=1\n' "$uc_count"
  fail_count=$(( fail_count + 1 ))
}

# --- Step 5: schema validation enforces cost+quality pairing ---
if ! bash "$SCHEMA" "$LOG" >/dev/null 2>&1; then
  printf 'FAIL: m019-p01-emitter-presence.sh schema-validation-failed file=%s\n' "$LOG"
  fail_count=$(( fail_count + 1 ))
fi

if [ "$fail_count" -gt 0 ]; then
  printf 'FAIL: m019-p01-emitter-presence.sh %d assertion(s) failed\n' "$fail_count"
  exit 1
fi

printf 'PASS: m019-p01-emitter-presence.sh 1 payload_breakdown + 2 dispatch_usage (build-context + dispatch-interface) + 1 unit_close, schema green\n'
exit 0
