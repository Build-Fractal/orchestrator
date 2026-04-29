#!/usr/bin/env bash
# scripts/verify/m028/p05-regression-gate.sh -- M028 close-out regression
# gate. Sequences four sub-gates and emits a consolidated PASS/FAIL
# summary.
#
# Sub-gates (in stable, dependency-aligned order):
#   1. install-roundtrip (P02/T05)        -- SC-2
#   2. corpus replay     (P03/T05)        -- SC-1, SC-8
#   3. per-finding run-all (P03/T05+P04)  -- SC-4
#   4. downstream fixture (P05/T02)       -- SC-3, SC-5
#
# Every sub-gate runs (no short-circuit on failure) so the operator sees
# all four states. Per-sub-gate output is captured to a log file under
# ${TMPDIR:-/tmp}/m028-p05-regression-gate-$$/ for post-hoc inspection.
#
# Exits 0 on all-PASS; exits 1 on any sub-gate FAIL; emits
#   "M028 close-out: <pass>/4 sub-gates clean"
# as the final line.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"

INSTALL_ROUNDTRIP="${script_dir}/install-roundtrip.sh"
CORPUS_REPLAY="${REPO_ROOT}/tests/run-prompt-corpus-replay.sh"
RUN_ALL="${script_dir}/run-all.sh"
DOWNSTREAM_FIXTURE="${REPO_ROOT}/tests/run-downstream-fixture.sh"

tmp_dir="${TMPDIR:-/tmp}/m028-p05-regression-gate-$$"
mkdir -p "$tmp_dir"

pass_count=0
fail_count=0
total=4

# run_sub_gate: invoke a sub-gate script with its captured output written
# to a named log file under tmp_dir. Reports PASS/FAIL with rc and a
# one-line tail.
run_sub_gate() {
  local label="$1"
  local script="$2"
  local log="${tmp_dir}/${label}.log"
  if [ ! -f "$script" ]; then
    echo "FAIL: ${label} (script missing: $script)"
    fail_count=$((fail_count + 1))
    return
  fi
  bash "$script" > "$log" 2>&1
  local rc=$?
  local tail_line
  tail_line=$(tail -n 1 "$log")
  if [ "$rc" -eq 0 ]; then
    echo "PASS: ${label} (rc=0; tail: ${tail_line})"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: ${label} (rc=${rc}; tail: ${tail_line}; log: ${log})"
    fail_count=$((fail_count + 1))
  fi
}

echo "M028 close-out regression gate -- 4 sub-gates"
echo "tmp logs at: ${tmp_dir}"
echo

run_sub_gate "install-roundtrip" "$INSTALL_ROUNDTRIP"
run_sub_gate "corpus-replay-27-entry" "$CORPUS_REPLAY"
run_sub_gate "per-finding-run-all" "$RUN_ALL"
run_sub_gate "downstream-fixture-replay" "$DOWNSTREAM_FIXTURE"

echo
echo "M028 close-out: ${pass_count}/${total} sub-gates clean"
if [ "$fail_count" -eq 0 ]; then
  # Cleanup tmp logs on full pass.
  rm -rf "$tmp_dir"
  exit 0
fi
echo "Failed sub-gate logs preserved at ${tmp_dir} for inspection."
exit 1
