#!/usr/bin/env bash
# scripts/verify/m019-p01-pricing-degradation.sh — M019/P01 pricing degradation gate.
#
# Renames .orchestrator/config/pricing.yml aside, runs a fixture dispatch,
# asserts the emitted dispatch_usage record has `"estimated_cost_usd":null`
# and a `"pricing_warning":` field, and dispatch exits 0. Restores
# pricing.yml via an EXIT/INT/TERM trap so a failed run never leaves the
# workspace degraded.
#
# Emits one PASS: or FAIL: line on stdout. Exit 0 on green, 1 otherwise.
#
# MEM004 carve-out: verification-script-internal; pipes/$()/awk permitted.
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_CONTEXT="$REPO_ROOT/scripts/dispatch/build-context.sh"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"
PRICING="$REPO_ROOT/.orchestrator/config/pricing.yml"
PRICING_BACKUP="${PRICING}.m019-p01-degradation-backup"
FIXTURE_MILESTONE="$REPO_ROOT/tests/fixtures/m019-p01/fixture-milestone"

TMPDIR_G="$(mktemp -d)"
# Trap fires on any exit path (normal, error, signal) and always restores
# pricing.yml — never leaves the workspace in a degraded state.
cleanup() {
  if [ -f "$PRICING_BACKUP" ]; then
    mv "$PRICING_BACKUP" "$PRICING" 2>/dev/null || true
  fi
  rm -rf "$TMPDIR_G" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if [ ! -f "$PRICING" ]; then
  printf 'FAIL: m019-p01-pricing-degradation.sh pricing-yml-missing-precondition file=%s\n' "$PRICING"
  exit 1
fi

# Snapshot fixture milestone into TMPDIR so writes don't touch the on-disk fixture.
ROOT="$TMPDIR_G/M999"
cp -R "$FIXTURE_MILESTONE" "$ROOT"
: > "$ROOT/execution-log.jsonl"

TASK_PLAN="$ROOT/phases/P01/tasks/T01-PLAN.md"
PAYLOAD="$TMPDIR_G/payload.md"
INTENSITY="$TMPDIR_G/intensity.yml"
printf 'model: claude-opus-4-7\n' > "$INTENSITY"

# Build the payload BEFORE renaming pricing.yml so the build-context run does
# not itself trigger degradation (it's fine either way, but we isolate the
# degradation assertion to the dispatch_usage record).
bash "$BUILD_CONTEXT" "$ROOT" M999 P01 T01 > "$PAYLOAD" 2>/dev/null || {
  printf 'FAIL: m019-p01-pricing-degradation.sh build-context-failed\n'
  exit 1
}

# Reset the log so the dispatch record is the only post-rename record.
: > "$ROOT/execution-log.jsonl"

# --- Rename pricing.yml aside ---
mv "$PRICING" "$PRICING_BACKUP" 2>/dev/null || {
  printf 'FAIL: m019-p01-pricing-degradation.sh pricing-rename-failed\n'
  exit 1
}

# --- Run dispatch with pricing file missing ---
dispatch_rc=0
ORCHESTRATOR_ROOT="$ROOT" bash "$DISPATCH" \
  --task-plan "$TASK_PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY" \
  --backend stub \
  >/dev/null 2>&1 || dispatch_rc=$?

fail_count=0

if [ "$dispatch_rc" -ne 0 ]; then
  printf 'FAIL: m019-p01-pricing-degradation.sh dispatch-nonzero rc=%d\n' "$dispatch_rc"
  fail_count=$(( fail_count + 1 ))
fi

LOG="$ROOT/execution-log.jsonl"
if ! grep -q '"record_type":"dispatch_usage"' "$LOG" 2>/dev/null; then
  printf 'FAIL: m019-p01-pricing-degradation.sh no-dispatch_usage-record\n'
  fail_count=$(( fail_count + 1 ))
fi

if ! grep -q '"estimated_cost_usd":null' "$LOG" 2>/dev/null; then
  printf 'FAIL: m019-p01-pricing-degradation.sh estimated_cost_usd-not-null\n'
  fail_count=$(( fail_count + 1 ))
fi

if ! grep -q '"pricing_warning":' "$LOG" 2>/dev/null; then
  printf 'FAIL: m019-p01-pricing-degradation.sh pricing_warning-absent\n'
  fail_count=$(( fail_count + 1 ))
fi

if [ "$fail_count" -gt 0 ]; then
  printf 'FAIL: m019-p01-pricing-degradation.sh %d assertion(s) failed\n' "$fail_count"
  exit 1
fi

printf 'PASS: m019-p01-pricing-degradation.sh pricing-missing -> cost=null + warning present, dispatch exit 0\n'
exit 0
