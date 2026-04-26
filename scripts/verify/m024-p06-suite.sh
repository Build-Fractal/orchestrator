#!/usr/bin/env bash
# scripts/verify/m024-p06-suite.sh
# M024/P06 phase suite — runs the two phase tests + every per-task verify.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Parallel-array tracker (MEM002 — bash 3.2 safe).
suite_n_0=""
suite_r_0=""
i=0

run_one() {
  local name="$1"
  local cmd="$2"
  local rc
  if eval "$cmd" >/dev/null 2>&1; then
    rc="PASS"
  else
    rc="FAIL"
  fi
  eval "suite_n_${i}=\"\$name\""
  eval "suite_r_${i}=\"\$rc\""
  i=$((i+1))
}

run_one "test-revision-flow.sh"                 "bash $ROOT/tests/test-revision-flow.sh"
run_one "test-revision-version-preservation.sh" "bash $ROOT/tests/test-revision-version-preservation.sh"
run_one "m024-p06-axis-rederive"                "bash $ROOT/scripts/verify/m024-p06-axis-rederive.sh"
run_one "m024-p06-revise-script"                "bash $ROOT/scripts/verify/m024-p06-revise-script.sh"
run_one "m024-p06-version-suffix"               "bash $ROOT/scripts/verify/m024-p06-version-suffix.sh"
run_one "m024-p06-axes-from-flag"               "bash $ROOT/scripts/verify/m024-p06-axes-from-flag.sh"
run_one "m024-p06-approval-gate-revise-wired"   "bash $ROOT/scripts/verify/m024-p06-approval-gate-revise-wired.sh"
run_one "m024-p06-rederive-rationale"           "bash $ROOT/scripts/verify/m024-p06-rederive-rationale.sh"
run_one "m024-p06-write-confinement"            "bash $ROOT/scripts/verify/m024-p06-write-confinement.sh"
run_one "m024-p06-evaluate-md"                  "bash $ROOT/scripts/verify/m024-p06-evaluate-md.sh"

# Summarize.
total=$i
n=0
fails=0
while [ "$n" -lt "$total" ]; do
  name=$(eval echo "\$suite_n_${n}")
  rc=$(eval echo "\$suite_r_${n}")
  echo "${rc}: ${name}"
  [ "$rc" = "FAIL" ] && fails=$((fails+1))
  n=$((n+1))
done

if [ "$fails" -gt 0 ]; then
  echo "SUMMARY: ${fails}/${total} FAILED"
  exit 1
fi

echo "SUMMARY: ${total}/${total} PASS"
echo "PASS: M024/P06 suite — revision flow + version preservation + rationale + wired approval-gate"
exit 0
