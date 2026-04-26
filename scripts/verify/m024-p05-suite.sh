#!/usr/bin/env bash
# scripts/verify/m024-p05-suite.sh
# M024/P05 suite runner — invokes every per-claim verify and the two phase tests.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VDIR="$ROOT/scripts/verify"

verifies="
  m024-p05-qa-questions-template.sh
  m024-p05-qa-loop-script.sh
  m024-p05-qa-loop-cap.sh
  m024-p05-qa-loop-shortcircuit.sh
  m024-p05-proposal-emit-empty-qa.sh
  m024-p05-empty-qa-full.sh
  m024-p05-empty-qa-shortcircuit.sh
  m024-p05-write-confinement.sh
  m024-p05-evaluate-md.sh
"

pass_count=0
fail_count=0
failures=""

for v in $verifies; do
  vp="$VDIR/$v"
  if [ ! -x "$vp" ]; then
    echo "FAIL: $v not executable"
    fail_count=$((fail_count + 1))
    failures="$failures $v"
    continue
  fi
  if bash "$vp" >/dev/null 2>&1; then
    pass_count=$((pass_count + 1))
    echo "  ok: $v"
  else
    fail_count=$((fail_count + 1))
    failures="$failures $v"
    echo "  FAIL: $v"
  fi
done

echo ""
echo "M024/P05 suite — pass=$pass_count fail=$fail_count"
if [ "$fail_count" -gt 0 ]; then
  echo "FAIL: M024/P05 suite — failures:$failures"
  exit 1
fi
echo "PASS: M024/P05 suite — all $pass_count verifies green"
exit 0
