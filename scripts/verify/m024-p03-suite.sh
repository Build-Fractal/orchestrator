#!/usr/bin/env bash
# scripts/verify/m024-p03-suite.sh
# P03 suite — paragraph + approval-gate + routes + evaluate.md + write-confinement.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

run() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    "$@"
    return 1
  fi
}

rc=0
run "test-paragraph-intake.sh"          bash "$ROOT/tests/test-paragraph-intake.sh"          || rc=1
run "test-approval-gate.sh"             bash "$ROOT/tests/test-approval-gate.sh"             || rc=1
run "m024-p03-paragraph-classify"       bash "$ROOT/scripts/verify/m024-p03-paragraph-classify.sh"       || rc=1
run "m024-p03-approval-gate"            bash "$ROOT/scripts/verify/m024-p03-approval-gate.sh"            || rc=1
run "m024-p03-approval-gate-verbs"      bash "$ROOT/scripts/verify/m024-p03-approval-gate-verbs.sh"      || rc=1
run "m024-p03-route-to-specify"         bash "$ROOT/scripts/verify/m024-p03-route-to-specify.sh"         || rc=1
run "m024-p03-route-to-dispatch"        bash "$ROOT/scripts/verify/m024-p03-route-to-dispatch.sh"        || rc=1
run "m024-p03-evaluate-md"              bash "$ROOT/scripts/verify/m024-p03-evaluate-md.sh"              || rc=1
run "m024-p03-write-confinement"        bash "$ROOT/scripts/verify/m024-p03-write-confinement.sh"        || rc=1

if [ $rc -eq 0 ]; then
  echo "PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md"
fi
exit $rc
