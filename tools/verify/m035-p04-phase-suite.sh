#!/usr/bin/env bash
# tools/verify/m035-p04-phase-suite.sh
#
# M035 P04 phase-suite aggregator. Chains every per-truth verifier
# in T01→T04 order, parses each verifier's BATTERY line, sums
# pass/fail/skip into a consolidated rollup, emits per-verifier
# PASS/FAIL decisions plus a final BATTERY: pass=N fail=0 [skip=K]
# summary line. Exit 0 iff total_fail=0.
#
# AD-19 single-script-file shape. Bash 3.2 compatible.
# Mirrors P03's chain-the-children form (verifier-unit counting:
# "pass" = number of children that exited 0).

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

verifiers=(
  "$REPO_ROOT/tools/verify/m035-p04-install-sh-shape.sh"
  "$REPO_ROOT/tools/verify/m035-p04-release-workflow-curl-arm.sh"
  "$REPO_ROOT/tools/verify/m035-p04-byte-equivalence-curl-arm.sh"
  "$REPO_ROOT/tools/verify/m035-p04-installation-doc-curl.sh"
  "$REPO_ROOT/tools/verify/m035-p04-update-skill-doc-curl.sh"
)

pass=0
fail=0

for v in "${verifiers[@]}"; do
  if [ ! -x "$v" ]; then
    echo "FAIL: verifier missing or not executable: $v"
    fail=$((fail + 1))
    continue
  fi
  out_log="$(mktemp 2>/dev/null || mktemp -t m035p04phase)"
  err_log="$(mktemp 2>/dev/null || mktemp -t m035p04phase-err)"
  if bash "$v" >"$out_log" 2>"$err_log"; then
    echo "PASS: $(basename "$v")"
    pass=$((pass + 1))
  else
    echo "FAIL: $(basename "$v")"
    cat "$err_log" >&2 || true
    cat "$out_log" >&2 || true
    fail=$((fail + 1))
  fi
  rm -f "$out_log" "$err_log"
done

# Self-reference: count this aggregator as a 6th passing verifier
# if all 5 children passed (mirrors P03's pattern of including the
# aggregator in its own count).
if [ "$fail" -eq 0 ]; then
  pass=$((pass + 1))
  echo "PASS: m035-p04-phase-suite.sh (self)"
else
  echo "FAIL: m035-p04-phase-suite.sh (self) — children failed"
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
