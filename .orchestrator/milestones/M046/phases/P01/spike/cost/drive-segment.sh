#!/usr/bin/env bash
# drive-segment.sh — one "segment" (loop process) of the M046/P01/T02 #Q-4
# cost-cadence probe. Spike-grade / throwaway.
#
# Drives the REAL scripts/lifecycle/auto-loop.sh single-step driver repeatedly
# against the throwaway MFIX fixture with a STUBBED dispatch. auto-loop.sh has
# no internal loop and no --dispatch-stub flag (the M031 --dispatch-stub seam
# lives in scripts/intake/do-entry.sh, Tier A path only) — for the Tier C loop
# the "dispatch" is whatever happens between the pre-dispatch AUTO:READY step
# and the post-dispatch --step=G step. This driver stands in for the agent
# runtime there: it writes the task/phase summaries itself via the REAL
# scripts/knowledge/write-summary.sh, which is the production emission path
# for M019 unit_close records (the record family under measurement).
# Zero LLM spend.
#
# Environment isolation: ORCHESTRATOR_ROOT is exported to the fixture root so
# write-summary.sh's unit_close emitter resolves the FIXTURE execution log
# ($ORCHESTRATOR_ROOT/milestones/MFIX/execution-log.jsonl), never the repo's
# live .orchestrator/execution-log.jsonl. auto-loop.sh takes the fixture
# milestone dir positionally, so its EXECUTION_LOG and lock path also resolve
# inside the fixture (fixture/milestones/orchestrator.lock — which is never
# created, so no collision with the live lock an outer auto run may hold).
#
# Usage: drive-segment.sh    (no args; paths resolved relative to this file)
set -euo pipefail

SPIKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SPIKE_DIR/../../../../../../.." && pwd)"
FIXTURE_ROOT="$SPIKE_DIR/fixture"
MILESTONE_DIR="$FIXTURE_ROOT/milestones/MFIX"
AUTO_LOOP="$REPO_ROOT/scripts/lifecycle/auto-loop.sh"
WRITE_SUMMARY="$REPO_ROOT/scripts/knowledge/write-summary.sh"
OUT="$SPIKE_DIR/.segment-step-out.txt"

export ORCHESTRATOR_ROOT="$FIXTURE_ROOT"

# Portable in-place sed (BSD/GNU) — same shape as scripts/lifecycle/sync-roadmap.sh.
sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

tick_roadmap() {
  # Mark phase $1 complete in the fixture roadmap so the sync-roadmap drift
  # guard at the next pre-dispatch sees checkbox and disk in agreement.
  sed_i "s/^- \[ \] \*\*$1\*\*/- [x] **$1**/" "$MILESTONE_DIR/MFIX-ROADMAP.md"
}

stub_dispatch_task() {
  # Stand in for the dispatched agent: write the task summary via the real
  # write-summary.sh (emits the task-grain unit_close record).
  local p="$1"
  local t="$2"
  if [ "$p" = "P02" ]; then
    # SYNTHETIC dispatch_usage seed (P02 only): the real emitter lives in
    # scripts/dispatch/dispatch-interface.sh and only fires on real dispatch.
    # Seeding one clearly-labeled record here exercises the unit_close
    # estimated_cost_usd aggregation path with zero spend, so the probe
    # observes BOTH cost shapes (P01 = null, P02 = non-null).
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '{"record_type":"dispatch_usage","unitId":"MFIX/%s/%s","milestone":"MFIX","phase":"%s","task":"%s","backend":"synthetic-stub","input_tokens_estimate":1000,"output_tokens_estimate":0,"estimated_cost_usd":0.0123,"pricing_version":"synthetic-fixture","model":"stub","source":"estimate","emission_point":"cadence-probe-stub","timestamp":"%s"}\n' \
      "$p" "$t" "$p" "$t" "$ts" >> "$MILESTONE_DIR/execution-log.jsonl"
  fi
  bash "$WRITE_SUMMARY" task "$MILESTONE_DIR/phases/$p/tasks/${t}-SUMMARY.md" \
    --id="$t" --parent="$p" --milestone=MFIX \
    --provides="fixture task output" --requires="none" --affects="none" \
    --key_files="none" --key_decisions="none" --patterns_established="none" \
    --drill_down_paths="none" --duration=1s --verification_result=pass \
    --body="Stub dispatch result for the T02 cost-cadence probe." >/dev/null
}

close_phase() {
  # Stand in for the phase-close ceremony: verification report, phase summary
  # via write-summary.sh (emits the phase-grain unit_close record), roadmap tick.
  local p="$1"
  printf '# %s Verification (fixture stub)\n\nAll checks green (stub). Throwaway cadence-probe fixture.\n' "$p" \
    > "$MILESTONE_DIR/phases/$p/${p}-VERIFICATION.md"
  bash "$WRITE_SUMMARY" phase "$MILESTONE_DIR/phases/$p/${p}-SUMMARY.md" \
    --id="$p" --parent=MFIX --milestone=MFIX \
    --provides="fixture phase $p" --requires="none" --affects="none" \
    --key_files="none" --key_decisions="none" --patterns_established="none" \
    --drill_down_paths="none" --duration=2s --verification_result=pass \
    --observability_surfaces="none" \
    --body="Stub phase close for the T02 cost-cadence probe." >/dev/null
  tick_roadmap "$p"
}

i=0
while [ "$i" -lt 12 ]; do
  i=$((i+1))
  rc=0
  bash "$AUTO_LOOP" "$MILESTONE_DIR" --output-file="$OUT" || rc=$?
  line="$(head -n 1 "$OUT")"
  echo "SEGMENT step=$i rc=$rc line=$line"
  case "$line" in
    AUTO:READY*)
      phase="$(sed -n 's/.*phase=\([^ ]*\).*/\1/p' "$OUT")"
      task="$(sed -n 's/.* task=\([^ ]*\).*/\1/p' "$OUT")"
      stub_dispatch_task "$phase" "$task"
      bash "$AUTO_LOOP" "$MILESTONE_DIR" --step=V --phase="$phase" --task="$task" --output-file="$OUT" || true
      echo "SEGMENT verify=$(head -n 1 "$OUT")"
      bash "$AUTO_LOOP" "$MILESTONE_DIR" --step=G --task="$task" \
        --outcome=success --verification_result=pass --duration_s=1 \
        --model=stub --cost=0.01 --output-file="$OUT" || true
      echo "SEGMENT record=$(head -n 1 "$OUT")"
      ;;
    AUTO:PHASE_COMPLETE*)
      phase="$(sed -n 's/.*phase=\([^ ]*\).*/\1/p' "$OUT")"
      close_phase "$phase"
      echo "SEGMENT phase_closed=$phase"
      ;;
    AUTO:MILESTONE_VALIDATING*)
      echo "SEGMENT done=milestone_validating steps=$i"
      exit 0
      ;;
    *)
      echo "SEGMENT unexpected rc=$rc line=$line"
      exit 1
      ;;
  esac
done

echo "SEGMENT exhausted max steps without reaching validating"
exit 1
