#!/usr/bin/env bash
# scripts/verify/m014-p03-phase-suite.sh
# M014/P03 phase suite — runs every per-truth verifier and emits a single
# PASS/FAIL line. Exit 0 only if every gate is green.
#
# Order matches P03-PLAN.md Truths + T05 phase-close additions:
#   T01: m014-p03-fetch.sh
#   T02: m014-p03-classify.sh
#   T03: m014-p03-commands-md.sh, m014-p03-apply.sh,
#        m014-p03-reject-triage.sh, m014-p03-spec-amendment-human-gate.sh
#   T04: m014-p03-pipeline.sh, m014-p03-auto-apply.sh, m014-p03-observability.sh
#   T05: m014-p03-config-keys.sh, m014-p03-references-section.sh,
#        m014-p03-dogfood-capture.sh, m014-p03-bash32-and-lint.sh,
#        m014-p03-zero-prompts.sh
#
# AD-19 single-script-file shape; CON-6 / MEM001 Bash 3.2.
# Mirrors m026-p03-phase-suite.sh + m014-p04-phase-suite.sh shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

GATES="
m014-p03-fetch.sh
m014-p03-classify.sh
m014-p03-commands-md.sh
m014-p03-apply.sh
m014-p03-reject-triage.sh
m014-p03-spec-amendment-human-gate.sh
m014-p03-pipeline.sh
m014-p03-auto-apply.sh
m014-p03-observability.sh
m014-p03-config-keys.sh
m014-p03-references-section.sh
m014-p03-dogfood-capture.sh
m014-p03-bash32-and-lint.sh
m014-p03-zero-prompts.sh
"

passed=0
failed=0
FAILED_GATES=""

IFS='
'
for g in $GATES; do
  IFS=' '
  [ -n "$g" ] || continue
  gpath="${SCRIPT_DIR}/${g}"
  if [ ! -f "$gpath" ]; then
    failed=$((failed + 1))
    echo "FAIL: ${g} (missing)"
    FAILED_GATES="${FAILED_GATES}
  - $g (missing)"
    IFS='
'
    continue
  fi
  if bash "$gpath" >/dev/null 2>&1; then
    passed=$((passed + 1))
    echo "PASS: ${g}"
  else
    rc=$?
    failed=$((failed + 1))
    echo "FAIL: ${g} (rc=${rc})"
    FAILED_GATES="${FAILED_GATES}
  - $g (rc=${rc})"
  fi
  IFS='
'
done
IFS=' '

echo "----"
echo "SUMMARY: $(basename "$0") pass=${passed} fail=${failed}"

if [ "$failed" -eq 0 ]; then
  echo "PASS: $(basename "$0")"
  exit 0
fi
echo "FAIL: $(basename "$0") — ${failed} gate(s) failed:${FAILED_GATES}" >&2
exit 1
