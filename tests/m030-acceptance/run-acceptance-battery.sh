#!/usr/bin/env bash
# tests/m030-acceptance/run-acceptance-battery.sh
# M030/P07/T02 — acceptance battery runner.
#
# Invokes every M030 SC verifier in literal sequence. 22 verifier
# invocations covering 14 SCs (SC-1..SC-11 plus SC-2a / SC-3a / SC-7a).
# Each verifier is invoked as `bash <path>` with rc captured per-call;
# no compound chains, no loops, no eval — AD-19 single-script-file shape.
#
# Final stdout line: `BATTERY: pass=N fail=M`. Exits 0 iff fail=0.
#
# Bash 3.2 compatible (parallel scalars, `local` inside the helper, no
# associative arrays). The runner only INVOKES existing P00–P06 verifier
# surfaces — zero modifications to dispatch-interface.sh, metrics-rollup.sh,
# efficiency-footer.sh, or check-anomalies.sh (CON-2 / FR-19 / SC-11
# preserved by construction).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

run_sc() {
  # $1 SC label  $2 verifier path
  local label="$1"
  local path="$2"
  bash "$path"
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    pass=$((pass + 1))
    echo "BATTERY-PASS: $label ($path)"
  else
    fail=$((fail + 1))
    echo "BATTERY-FAIL: $label ($path) exited $rc"
  fi
}

# ---------- SC-1: classifier determinism + no network ----------
run_sc "SC-1-determinism" "$PROJECT_ROOT/tools/verify/p01-classifier-determinism.sh"
run_sc "SC-1-no-network"  "$PROJECT_ROOT/tools/verify/p01-classifier-perf-and-network.sh"

# ---------- SC-2: 4-verdict shadow-compare (via T01's per-verdict gates) ----------
run_sc "SC-2-ready"                "$PROJECT_ROOT/tools/verify/p07-corpus-50-per-class-ready.sh"
run_sc "SC-2-evidence-insufficient" "$PROJECT_ROOT/tools/verify/p07-corpus-zero-evidence-insufficient.sh"
run_sc "SC-2-partially-ready"      "$PROJECT_ROOT/tools/verify/p07-corpus-2-class-partially-ready.sh"
run_sc "SC-2-block"                "$PROJECT_ROOT/tools/verify/p07-corpus-block.sh"

# ---------- SC-2a: programmatic flip-gate (shadow_gate_blocked) ----------
run_sc "SC-2a-shadow-gate-block" "$PROJECT_ROOT/tools/verify/p04-sc2a-shadow-gate-block.sh"

# ---------- SC-3: live mechanical ----------
run_sc "SC-3-live-mechanical" "$PROJECT_ROOT/tools/verify/p04-sc3-live-mechanical.sh"

# ---------- SC-3a: shadow-record write-path correctness ----------
run_sc "SC-3a-roundtrip" "$PROJECT_ROOT/tools/verify/p02-sc3a-roundtrip.sh"

# ---------- SC-4: escalation sequence ----------
run_sc "SC-4-escalation-sequence" "$PROJECT_ROOT/tools/verify/p04-sc4-escalation-sequence.sh"

# ---------- SC-5: escalation cap ----------
run_sc "SC-5-escalation-cap" "$PROJECT_ROOT/tools/verify/p04-sc5-escalation-cap.sh"

# ---------- SC-6: per-task override ----------
run_sc "SC-6-frontmatter-override" "$PROJECT_ROOT/tools/verify/p03-sc6-frontmatter-override.sh"

# ---------- SC-7: kill switch ----------
run_sc "SC-7-kill-switch" "$PROJECT_ROOT/tools/verify/p03-sc7-kill-switch.sh"

# ---------- SC-7a: compound kill+floor ----------
run_sc "SC-7a-compound" "$PROJECT_ROOT/tools/verify/p03-sc7a-compound.sh"

# ---------- SC-8: by-model rollup (cost_rates present + absent + counts) ----------
run_sc "SC-8-cost-rates-present" "$PROJECT_ROOT/tools/verify/p05-by-model-cost-rates-present.sh"
run_sc "SC-8-cost-rates-absent"  "$PROJECT_ROOT/tools/verify/p05-by-model-cost-rates-absent.sh"
run_sc "SC-8-dispatch-counts"    "$PROJECT_ROOT/tools/verify/p05-by-model-dispatch-counts.sh"

# ---------- SC-9: doctor config-check ----------
run_sc "SC-9-doctor-config-check" "$PROJECT_ROOT/tools/verify/p05-doctor-config-check.sh"

# ---------- SC-10: classifier ground-truth >=85% ----------
run_sc "SC-10-classifier-ground-truth" "$PROJECT_ROOT/tools/verify/p01-classifier-ground-truth.sh"

# ---------- SC-11: byte-equality across rollup + footer + check-anomalies ----------
run_sc "SC-11-rollup-byte-equality"          "$PROJECT_ROOT/tools/verify/p05-sc11-rollup-byte-equality.sh"
run_sc "SC-11-footer-byte-equality"          "$PROJECT_ROOT/tools/verify/p05-sc11-footer-byte-equality.sh"
run_sc "SC-11-check-anomalies-byte-equality" "$PROJECT_ROOT/tools/verify/p06-sc11-byte-equality.sh"

# ---------- Aggregate ----------
printf 'BATTERY: pass=%s fail=%s\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
