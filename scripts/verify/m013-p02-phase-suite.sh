#!/usr/bin/env bash
# scripts/verify/m013-p02-phase-suite.sh — Orchestrate all M013/P02 gate scripts.
#
# Invokes every phase-P02 gate script in dependency-respecting order
# (T01 -> T02 -> T03 -> T04 -> T05 -> T06 -> T07), captures each gate's
# exit code + stdout/stderr to a per-gate capture file under /tmp, and
# emits a consolidated summary with PASS/FAIL counts.
#
# Exits 0 only when every gate passes. Failing gates are reported with
# gate name, exit code, and capture-file path (no silent-success paths).
#
# Bash 3.2 compatible (no assoc-arrays, no array-from-stdin builtins,
# no process substitution). The bash32-compat gate self-checks this file.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VDIR="${REPO_ROOT}/scripts/verify"

# Ordered gate list. Order mirrors the phase dependency graph:
#   T01 (github-common helper library)       ->
#   T02 (github-init fixture dry-run + preflight diagnostics) ->
#   T03 (FR-15 dry-run manifest format)      ->
#   T04 (commands/github-init.md doc)        ->
#   T05 (references/github-integration.md extensions) ->
#   T02+T06 (auto-mode pending-sentinel + sub_issue_mode schema) ->
#   T07 (bash-3.2 compat + anti-pattern-lint sweep).
# Eight gates total.
GATES="
m013-p02-github-common.sh
m013-p02-github-init-fixture.sh
m013-p02-github-init-preflight.sh
m013-p02-dry-run-manifest.sh
m013-p02-github-init-command.sh
m013-p02-reference-extensions.sh
m013-p02-auto-mode-pending.sh
m013-p02-bash32-compat.sh
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
  capture="/tmp/m013-p02-${g}.out"

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

echo "SUMMARY: m013-p02-phase-suite.sh pass=${passed} fail=${failed}"

if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p02-phase-suite.sh"
  exit 0
fi

echo "FAIL: m013-p02-phase-suite.sh" >&2
printf '%s\n' "$failures" >&2
exit 1
