#!/usr/bin/env bash
# scripts/verify/m013-p03-phase-suite.sh — Orchestrate all M013/P03 gate scripts.
#
# Invokes every phase-P03 gate script in dependency-respecting order
# (T01 fixture → T01 helper → T02 adoption → T02 auto-mode → T03 lint →
#  T04 reference → T05 bash32-compat), captures each gate's exit code +
# stdout/stderr to a per-gate capture file under /tmp, and emits a
# consolidated summary with PASS/FAIL counts.
#
# Exits 0 only when every gate passes. Failing gates are reported with
# gate name, exit code, and capture-file path.
#
# Also re-runs the P02 phase suite as a regression guard — P02 byte-identity
# is load-bearing for P03's additive extension claim.
#
# Bash 3.2 compatible.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VDIR="${REPO_ROOT}/scripts/verify"

GATES="
m013-p03-re-init-fixture.sh
m013-p03-github-common-readopt.sh
m013-p03-re-init-adoption.sh
m013-p03-re-init-auto-mode.sh
m013-p03-graphql-call-shape-selftest.sh
m013-p03-reference-extensions.sh
m013-p03-bash32-compat.sh
"

passed=0
failed=0
failures=""

IFS='
'
for g in $GATES; do
  IFS=' '
  [ -n "$g" ] || continue
  path="${VDIR}/${g}"
  capture="/tmp/m013-p03-${g}.out"

  if [ ! -f "$path" ]; then
    echo "FAIL: ${g} (missing)"
    failed=$((failed + 1))
    failures="${failures}${failures:+
}  ${g}: missing at ${path}"
    IFS='
'
    continue
  fi

  bash "$path" > "$capture" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "PASS: ${g}"
    passed=$((passed + 1))
  else
    echo "FAIL: ${g} (rc=${rc}, see ${capture})"
    failed=$((failed + 1))
    failures="${failures}${failures:+
}  ${g}: rc=${rc} (see ${capture})"
  fi
  IFS='
'
done
IFS=' '

# P02 regression guard.
p02_suite="${VDIR}/m013-p02-phase-suite.sh"
p02_capture="/tmp/m013-p03-p02-regression.out"
if [ -f "$p02_suite" ]; then
  bash "$p02_suite" > "$p02_capture" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "PASS: m013-p02-phase-suite.sh (regression guard)"
    passed=$((passed + 1))
  else
    echo "FAIL: m013-p02-phase-suite.sh (regression guard, rc=${rc}, see ${p02_capture})"
    failed=$((failed + 1))
    failures="${failures}${failures:+
}  m013-p02-phase-suite.sh: REGRESSION rc=${rc}"
  fi
fi

echo "SUMMARY: m013-p03-phase-suite.sh pass=${passed} fail=${failed}"

if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-phase-suite.sh"
  exit 0
fi

echo "FAIL: m013-p03-phase-suite.sh" >&2
printf '%s\n' "$failures" >&2
exit 1
