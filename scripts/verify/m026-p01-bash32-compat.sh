#!/usr/bin/env bash
# scripts/verify/m026-p01-bash32-compat.sh -- M026/P01/T04 gate:
# Bash 3.2 compatibility scan for every M026/P01 verifier shipped under
# scripts/verify/m026-p01-*.sh (and any helpers under scripts/verify/lib/
# named m026-p01-*).
#
# Per-file:
#   1. bash -n parse check
#   2. forbidden-token grep:
#        assoc-arrays declaration, array-from-stdin builtins, process
#        substitution, combined-redirect shorthand, case-conversion
#        expansion
#
# Self-exclusion: this gate's own file carries the forbidden-token
# enumeration inside a case-branch for audit readability; the scanner
# excludes its own filename via a case-branch (mirrors the M025/P01/T03
# convention from scripts/verify/m025-p01-bash32-compat.sh).
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

# P01 shell files scanned by this gate. Enumerated explicitly to keep the
# audit trail readable (as opposed to shell-globbing, which changes across
# runs). Add any new M026/P01 verifier to this list.
P01_FILES="
scripts/verify/m026-p01-parity-matrix-shape.sh
scripts/verify/m026-p01-parity-matrix-coverage.sh
scripts/verify/m026-p01-spike-note-shape.sh
scripts/verify/m026-p01-spike-gate-file.sh
scripts/verify/m026-p01-ollama-probe.sh
scripts/verify/m026-p01-pipx-venv-inventory.sh
scripts/verify/m026-p01-upstream-readonly.sh
scripts/verify/m026-p01-bash32-compat.sh
scripts/verify/m026-p01-summary-shape-when-present.sh
scripts/verify/m026-p01-recent-changes.sh
scripts/verify/m026-p01-phase-suite.sh
scripts/verify/lib/m026-p01-recent-changes-region.sh
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
    scripts/verify/m026-p01-bash32-compat.sh)
      pass "forbidden-token scan: ${f} (self-excluded)"
      ;;
    *)
      # assoc-arrays synonym; array-from-stdin synonym; process substitution;
      # case-conversion expansion; combined-redirect shorthand. Strip
      # full-line comments (lines whose first non-whitespace char is #) before
      # scanning. Comment-discipline synonyms exist to let reference blocks
      # name the forbidden tokens for audit readability; the scanner excludes
      # whole-comment lines but still catches live uses.
      if grep -v -E '^[[:space:]]*#' "$path" | grep -nE '\bdeclare[[:space:]]+-A\b|\b(mapfile|readarray)\b|<\(|>\(|&>|\|&|\$\{[A-Za-z_][A-Za-z_0-9]*\^\^?\}|\$\{[A-Za-z_][A-Za-z_0-9]*,,?\}' >/dev/null 2>&1; then
        fail "forbidden-token scan: ${f} (see grep output above)"
      else
        pass "forbidden-token scan: ${f}"
      fi
      ;;
  esac

  IFS='
'
done
IFS=' '

echo "SUMMARY: m026-p01-bash32-compat.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m026-p01-bash32-compat.sh"
  exit 0
fi
echo "FAIL: m026-p01-bash32-compat.sh" >&2
exit 1
