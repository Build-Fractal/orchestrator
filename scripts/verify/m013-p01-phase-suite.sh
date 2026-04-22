#!/usr/bin/env bash
# scripts/verify/m013-p01-phase-suite.sh — Orchestrate all M013/P01 gate scripts.
#
# Invokes every phase-P01 gate script in dependency-respecting order
# (T01 -> T02 -> T03 -> T04 -> T05 -> T06 -> T07), captures each gate's
# exit code + stdout/stderr to a per-gate capture file under /tmp, and
# emits a consolidated summary with PASS/FAIL counts.
#
# Exits 0 only when every gate passes. Failing gates are reported with
# gate name, exit code, and capture-file path (no silent-success paths).
#
# Bash 3.2 compatible (no associative arrays, no array-from-stdin
# builtins, no process substitution). The bash32-compat gate self-checks
# this file.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VDIR="${REPO_ROOT}/scripts/verify"

# Ordered gate list. Order mirrors the phase dependency graph:
#   T01 (sidecar schema) -> T02 (github-status + command) ->
#   T03 (UAT template)   -> T04 (rebuild-index additive)  ->
#   T05 (defect schema + uat-ingest) -> T06 (reference skeleton) ->
#   T07 (bash32-compat).
# Nine gates total.
GATES="
m013-p01-sidecar-schema.sh
m013-p01-github-status.sh
m013-p01-github-status-command.sh
m013-p01-uat-template.sh
m013-p01-rebuild-index-additive.sh
m013-p01-defect-schema.sh
m013-p01-uat-ingest.sh
m013-p01-reference-skeleton.sh
m013-p01-bash32-compat.sh
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
  capture="/tmp/m013-p01-${g}.out"

  if [ ! -f "$path" ]; then
    echo "GATE-FAIL: ${g} (missing)"
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
    echo "GATE-PASS: ${g}"
    passed=$((passed + 1))
  else
    echo "GATE-FAIL: ${g} (rc=${rc})"
    failed=$((failed + 1))
    failures="${failures}${failures:+
}  ${g}: rc=${rc} (see ${capture})"
  fi
  IFS='
'
done
IFS=' '

echo ""
echo "SUMMARY: passed=${passed} failed=${failed}"

if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p01-phase-suite.sh"
  exit 0
fi

echo "FAIL: m013-p01-phase-suite.sh" >&2
printf '%s\n' "$failures" >&2
exit 1
