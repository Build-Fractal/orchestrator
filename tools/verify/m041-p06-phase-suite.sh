#!/usr/bin/env bash
# tools/verify/m041-p06-phase-suite.sh
# P06 phase suite aggregator — runs all m041-p06 verifiers.
set -u
cd "$(git rev-parse --show-toplevel)"
pass=0
fail=0
for v in tools/verify/m041-p06-*.sh; do
  [ "$v" = "tools/verify/m041-p06-phase-suite.sh" ] && continue
  name="$(basename "$v" .sh)"
  if bash "$v"; then
    echo "OK: $name"
    pass=$((pass + 1))
  else
    echo "FAILED: $name"
    fail=$((fail + 1))
  fi
done
echo "---"
echo "SUITE: pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
