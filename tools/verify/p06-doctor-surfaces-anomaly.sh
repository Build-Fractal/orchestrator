#!/usr/bin/env bash
# tools/verify/p06-doctor-surfaces-anomaly.sh — doctor end-to-end gate.
#
# Confirms the new check-anomalies output flows through scripts/diagnostics/
# run-doctor.sh without any run-doctor amendment (acceptance: "the anomaly
# surfaces through orchestrator:doctor per existing M027 conventions").
#
# Strategy: run-doctor invokes check-anomalies WITHOUT --milestone, so
# check-anomalies' find-active-milestone resolves the REAL repo's active
# milestone. We dynamically detect that, then stage the regression-mechanical
# fixture as that milestone's execution-log under a tmp ORCHESTRATOR_ROOT
# carve-out. The regression check resolves log_path =
# $ORCHESTRATOR_ROOT/milestones/$active/execution-log.jsonl which matches
# the staged fixture. Asserts the FLAGGED line surfaces in doctor stdout.
#
# AD-19 single-script-file shape. Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p06/regression-mechanical.jsonl"

pass=0
fail=0

# Detect the real-repo active milestone (find-active-milestone is hardcoded
# to read from $_CA_PROJECT_ROOT/.orchestrator inside check-anomalies, so
# the verifier must stage the carve-out at the SAME milestone id).
ACTIVE_OUT="$(bash "$PROJECT_ROOT/scripts/state/find-active-milestone.sh" "$PROJECT_ROOT/.orchestrator" 2>/dev/null || true)"
ACTIVE_MILESTONE="$(printf '%s\n' "$ACTIVE_OUT" | awk 'NR==1 { print $1 }')"
if [ -z "$ACTIVE_MILESTONE" ]; then
  ACTIVE_MILESTONE="M030"
fi

tmp_root="$(mktemp -d -t p06-doctor.XXXXXX)"
mkdir -p "$tmp_root/.orchestrator/milestones/$ACTIVE_MILESTONE"
cp "$FIXTURE" "$tmp_root/.orchestrator/milestones/$ACTIVE_MILESTONE/execution-log.jsonl"

ANOMALIES_JSONL="$tmp_root/.orchestrator/anomalies.jsonl"
ACTUAL="$(mktemp -t p06-doctor-actual.XXXXXX)"
trap 'rm -rf "$tmp_root"; rm -f "$ACTUAL"' EXIT

ORCHESTRATOR_ROOT="$tmp_root/.orchestrator" \
  M030_ANOMALIES_JSONL_PATH="$ANOMALIES_JSONL" \
  bash "$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh" --root "$tmp_root" \
  > "$ACTUAL" 2>&1

if grep -qE '^--- Anomaly Detection ---' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: Anomaly Detection section header present"
else
  fail=$((fail + 1))
  echo "FAIL: Anomaly Detection section header missing"
fi

if grep -qE 'FLAGGED model_routing_regression class=mechanical' "$ACTUAL"; then
  pass=$((pass + 1))
  echo "OK: FLAGGED model_routing_regression class=mechanical surfaced through doctor"
else
  fail=$((fail + 1))
  echo "FAIL: FLAGGED model_routing_regression class=mechanical NOT surfaced through doctor"
  echo "Active milestone resolved as: $ACTIVE_MILESTONE"
  echo "Actual doctor output (last 60 lines):"
  tail -n 60 "$ACTUAL"
fi

echo "SUMMARY: p06-doctor-surfaces-anomaly.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
