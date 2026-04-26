#!/usr/bin/env bash
# scripts/verify/m024-p04-suite.sh
# P04 suite — fast-path check + emit wiring + condition-violation + config-disable + write-confinement.

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
run "test-fast-path-auto-proceed.sh"          bash "$ROOT/tests/test-fast-path-auto-proceed.sh"          || rc=1
run "test-fast-path-condition-violation.sh"   bash "$ROOT/tests/test-fast-path-condition-violation.sh"   || rc=1
run "m024-p04-config-auto-proceed-key"        bash "$ROOT/scripts/verify/m024-p04-config-auto-proceed-key.sh"        || rc=1
run "m024-p04-config-template"                bash "$ROOT/scripts/verify/m024-p04-config-template.sh"                || rc=1
run "m024-p04-fast-path-check"                bash "$ROOT/scripts/verify/m024-p04-fast-path-check.sh"                || rc=1
run "m024-p04-proposal-emit-fast-path"        bash "$ROOT/scripts/verify/m024-p04-proposal-emit-fast-path.sh"        || rc=1
run "m024-p04-fast-path-auto-proceed"         bash "$ROOT/scripts/verify/m024-p04-fast-path-auto-proceed.sh"         || rc=1
run "m024-p04-fast-path-condition-violation"  bash "$ROOT/scripts/verify/m024-p04-fast-path-condition-violation.sh"  || rc=1
run "m024-p04-config-disable"                 bash "$ROOT/scripts/verify/m024-p04-config-disable.sh"                 || rc=1
run "m024-p04-write-confinement"              bash "$ROOT/scripts/verify/m024-p04-write-confinement.sh"              || rc=1

if [ $rc -eq 0 ]; then
  echo "PASS: M024/P04 suite — fast-path + config + condition-violation + write-confinement"
fi
exit $rc
