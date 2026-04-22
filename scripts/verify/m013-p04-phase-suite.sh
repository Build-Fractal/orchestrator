#!/usr/bin/env bash
# scripts/verify/m013-p04-phase-suite.sh — P04 phase-suite orchestrator.
#
# Runs every P04 gate + FR-5 GraphQL call-shape lint + P01/P03 phase-suite
# regression guards. Mirror of the P03/T05 phase-suite shape.
#
# Single-script-file (AD-19) invocation. Bash 3.2 compatible. AP-009 compliant.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VDIR="${REPO_ROOT}/scripts/verify"

# All P04 gates. The ordering mirrors the task emission order (T01..T06).
GATES="
m013-p04-sync-fixture.sh
m013-p04-github-common-p04.sh
m013-p04-github-sync.sh
m013-p04-dry-run-manifest.sh
m013-p04-rate-limit.sh
m013-p04-observability.sh
m013-p04-post-verify-hook.sh
m013-p04-conversus-gate.sh
m013-p04-verify-cache.sh
m013-p04-github-sync-command.sh
m013-p04-reference-extensions.sh
m013-p04-bash32-compat.sh
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
  capture="/tmp/m013-p04-${g}.out"

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

# FR-5 lint regression guard.
if bash "${VDIR}/graphql-call-shape.sh" > /tmp/m013-p04-graphql-lint.out 2>&1; then
  echo "PASS: graphql-call-shape.sh (FR-5 regression guard)"
  passed=$((passed + 1))
else
  echo "FAIL: graphql-call-shape.sh (FR-5 regression guard)"
  failed=$((failed + 1))
  failures="${failures}${failures:+
}  graphql-call-shape.sh: non-zero rc"
fi

# P03 phase-suite regression guard. Known baseline failures propagate through:
# m013-p02-github-init-command.sh carries a pre-existing renaming miss
# (Title heading convention), and m013-p03-reference-extensions.sh inherits
# that failure via its P02 regression assertion. Per the dispatch brief both
# are expected to persist identically across P04. The phase-suite reports
# PASS/FAIL accordingly and surfaces the output log for triage.
if bash "${VDIR}/m013-p03-phase-suite.sh" > /tmp/m013-p04-p03-regression.out 2>&1; then
  echo "PASS: m013-p03-phase-suite.sh (regression guard)"
  passed=$((passed + 1))
else
  echo "FAIL: m013-p03-phase-suite.sh (regression guard — see /tmp/m013-p04-p03-regression.out)"
  failed=$((failed + 1))
  failures="${failures}${failures:+
}  m013-p03-phase-suite.sh: non-zero rc (known baseline failures expected)"
fi

# P01 phase-suite regression guard.
if bash "${VDIR}/m013-p01-phase-suite.sh" > /tmp/m013-p04-p01-regression.out 2>&1; then
  echo "PASS: m013-p01-phase-suite.sh (regression guard)"
  passed=$((passed + 1))
else
  echo "FAIL: m013-p01-phase-suite.sh (regression guard — see /tmp/m013-p04-p01-regression.out)"
  failed=$((failed + 1))
  failures="${failures}${failures:+
}  m013-p01-phase-suite.sh: non-zero rc"
fi

echo "SUMMARY: m013-p04-phase-suite.sh pass=${passed} fail=${failed}"

if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-phase-suite.sh"
  exit 0
fi

echo "FAIL: m013-p04-phase-suite.sh" >&2
printf '%s\n' "$failures" >&2
exit 1
