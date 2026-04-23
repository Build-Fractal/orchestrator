#!/usr/bin/env bash
# scripts/verify/m025-p01-bash32-compat.sh -- M025/P01/T03 gate:
# Bash 3.2 compatibility scan for every new or modified .sh file in P01.
#
# Per-file:
#   1. bash -n parse check
#   2. forbidden-token grep:
#        assoc-arrays declaration, array-from-stdin builtins, process
#        substitution, combined-redirect shorthand, case-conversion
#        expansion
#   3. anti-pattern-lint per-file (--fixture scope)
#
# Self-exclusion: this gate's own file contains the forbidden-token
# comments for audit readability; the scanner excludes its own filename
# via a case-branch (mirrors M013/P04/T06 convention).
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

# P01-touched / P01-created shell files.
P01_FILES="
scripts/dispatch/adapters/runtime/claude-code.sh
packaging/install/install-claude-code.sh
scripts/util/settings-merge.sh
scripts/verify/m025-p01-hook-schema.sh
scripts/verify/m025-p01-merge-preservation.sh
scripts/verify/m025-p01-idempotency.sh
scripts/verify/m025-p01-coexistence.sh
scripts/verify/m025-p01-uninstall-reversibility.sh
scripts/verify/m025-p01-runtime-scope-guard.sh
scripts/verify/m025-p01-bash32-compat.sh
scripts/verify/m025-p01-docs.sh
scripts/verify/m025-p01-knowledge-entries.sh
scripts/verify/m025-p01-recent-changes.sh
scripts/verify/m025-p01-phase-suite.sh
"

IFS='
'
for f in $P01_FILES; do
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
    scripts/verify/m025-p01-bash32-compat.sh)
      pass "forbidden-token scan: ${f} (self-excluded)"
      ;;
    *)
      # assoc-arrays synonym; array-from-stdin synonym; process substitution;
      # case-conversion expansion; combined-redirect shorthand.
      # Strip full-line comments (lines whose first non-whitespace char is #)
      # before scanning. Comment-discipline synonyms exist to let reference
      # blocks name the forbidden tokens for audit readability; the scanner
      # excludes those whole-comment lines but still catches live uses.
      # Inline comments on code lines are rare in this repo; if they appear,
      # the author should paraphrase per M013/P04/T06 convention.
      if grep -v -E '^[[:space:]]*#' "$path" | grep -nE '\bdeclare[[:space:]]+-A\b|\b(mapfile|readarray)\b|<\(|>\(|&>|\|&|\$\{[A-Za-z_][A-Za-z_0-9]*\^\^?\}|\$\{[A-Za-z_][A-Za-z_0-9]*,,?\}' >/dev/null 2>&1; then
        fail "forbidden-token scan: ${f} (see grep output above)"
      else
        pass "forbidden-token scan: ${f}"
      fi
      ;;
  esac

  # anti-pattern-lint per-file.
  if bash "${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh" --fixture "$path" >/dev/null 2>&1; then
    pass "anti-pattern-lint: ${f}"
  else
    fail "anti-pattern-lint: ${f}"
  fi

  IFS='
'
done
IFS=' '

echo "SUMMARY: m025-p01-bash32-compat.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m025-p01-bash32-compat.sh"
  exit 0
fi
echo "FAIL: m025-p01-bash32-compat.sh" >&2
exit 1
