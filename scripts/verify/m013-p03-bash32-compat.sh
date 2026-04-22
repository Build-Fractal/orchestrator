#!/usr/bin/env bash
# scripts/verify/m013-p03-bash32-compat.sh — Bash 3.2 compatibility gate for P03 files.
#
# For each P03-touched or P03-created shell file:
#   1. bash -n parse check
#   2. grep for forbidden tokens (assoc-arrays, array-from-stdin builtins,
#      process substitution, combined-redirect shorthand, case-conversion
#      expansion)
#   3. scripts/verify/anti-pattern-lint.sh per-file invocation
#
# Self-exclusion: this gate's own file contains the forbidden-token comments
# (assoc-arrays, array-from-stdin, case-conversion expansion, combined-redirect
# shorthand). The scanner excludes its own filename via a case-branch.
#
# Invariant: MEM001, Constitution IX, Constitution XV, SC-6.
# Bash 3.2 compatible.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

passed=0
failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# Files to scan. Mix of modified P02 files (github-common.sh, github-init.sh)
# and P03-new files. The modified P02 files are included because T01/T02
# touched them additively — the gate re-verifies post-touch cleanliness.
P03_FILES="
scripts/integrations/github-common.sh
scripts/integrations/github-init.sh
scripts/verify/graphql-call-shape.sh
scripts/verify/m013-p03-re-init-fixture.sh
scripts/verify/m013-p03-github-common-readopt.sh
scripts/verify/m013-p03-re-init-adoption.sh
scripts/verify/m013-p03-re-init-auto-mode.sh
scripts/verify/m013-p03-graphql-call-shape-selftest.sh
scripts/verify/m013-p03-reference-extensions.sh
scripts/verify/m013-p03-bash32-compat.sh
scripts/verify/m013-p03-phase-suite.sh
"

IFS='
'
for f in $P03_FILES; do
  IFS=' '
  [ -n "$f" ] || continue
  path="${REPO_ROOT}/${f}"
  if [ ! -f "$path" ]; then
    fail "${f} missing"
    IFS='
'
    continue
  fi

  # bash -n parse check.
  if bash -n "$path" 2>/dev/null; then
    pass "bash -n: ${f}"
  else
    fail "bash -n: ${f}"
  fi

  # Forbidden-token scan. Self-exclusion: skip this very file.
  case "$f" in
    scripts/verify/m013-p03-bash32-compat.sh)
      pass "forbidden-token scan: ${f} (self-excluded)"
      ;;
    *)
      # assoc-arrays synonym; array-from-stdin synonym; process substitution;
      # case-conversion expansion; combined-redirect shorthand.
      if grep -nE '\bdeclare[[:space:]]+-A\b|\b(mapfile|readarray)\b|<\(|>\(|&>|\|&|\$\{[A-Za-z_][A-Za-z_0-9]*\^\^?\}|\$\{[A-Za-z_][A-Za-z_0-9]*,,?\}' "$path" >/dev/null 2>&1; then
        fail "forbidden-token scan: ${f} (see grep output above)"
      else
        pass "forbidden-token scan: ${f}"
      fi
      ;;
  esac

  # anti-pattern-lint per-file. --fixture scopes the scan to a single file
  # (mirror of P02/T07 convention); without it the lint scans the whole repo
  # and trips on M013 PAYLOAD fenced examples (expected operator payloads).
  if bash "${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh" --fixture "$path" >/dev/null 2>&1; then
    pass "anti-pattern-lint: ${f}"
  else
    fail "anti-pattern-lint: ${f}"
  fi

  IFS='
'
done
IFS=' '

echo "SUMMARY: m013-p03-bash32-compat.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-bash32-compat.sh"
  exit 0
fi
echo "FAIL: m013-p03-bash32-compat.sh" >&2
exit 1
