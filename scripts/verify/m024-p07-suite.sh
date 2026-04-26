#!/usr/bin/env bash
# scripts/verify/m024-p07-suite.sh
# M024/P07 phase suite — runs every per-task verify + every phase test.
# MEM002 parallel-array tracker.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Parallel arrays (bash 3.2 portable — no associative arrays).
i=0
add() { eval "name_$i=\"\$1\""; eval "cmd_$i=\"\$2\""; i=$((i + 1)); }

add "test-design-gate-degradation"        "bash $ROOT/tests/test-design-gate-degradation.sh"
add "test-design-gate-skip"               "bash $ROOT/tests/test-design-gate-skip.sh"
add "test-design-gate-manual"             "bash $ROOT/tests/test-design-gate-manual.sh"
add "m024-p07-design-gate-classify"       "bash $ROOT/scripts/verify/m024-p07-design-gate-classify.sh"
add "m024-p07-degradation-script"         "bash $ROOT/scripts/verify/m024-p07-degradation-script.sh"
add "m024-p07-pinned-message"             "bash $ROOT/scripts/verify/m024-p07-pinned-message.sh"
add "m024-p07-m023-probe"                 "bash $ROOT/scripts/verify/m024-p07-m023-probe.sh"
add "m024-p07-skip-branch"                "bash $ROOT/scripts/verify/m024-p07-skip-branch.sh"
add "m024-p07-manual-branch"              "bash $ROOT/scripts/verify/m024-p07-manual-branch.sh"
add "m024-p07-no-orphan-design-cmd"       "bash $ROOT/scripts/verify/m024-p07-no-orphan-design-cmd.sh"
add "m024-p07-approval-gate-design-verbs" "bash $ROOT/scripts/verify/m024-p07-approval-gate-design-verbs.sh"
add "m024-p07-write-confinement"          "bash $ROOT/scripts/verify/m024-p07-write-confinement.sh"
add "m024-p07-evaluate-md"                "bash $ROOT/scripts/verify/m024-p07-evaluate-md.sh"

n=$i
fail_count=0
j=0
while [ "$j" -lt "$n" ]; do
  eval "n_var=\$name_$j"
  eval "c_var=\$cmd_$j"
  if eval "$c_var" >/dev/null 2>&1; then
    echo "PASS: $n_var"
  else
    echo "FAIL: $n_var"
    fail_count=$((fail_count + 1))
  fi
  j=$((j + 1))
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: M024/P07 suite — design-gate degradation + skip/manual branches + no-orphan + write-confinement"
  exit 0
fi
echo "SUMMARY: $fail_count of $n P07 verifies failed"
exit 1
