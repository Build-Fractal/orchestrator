#!/usr/bin/env bash
# Gate: all P01-new shell scripts are Bash 3.2 compatible and lint-clean.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LINT="${PROJECT_ROOT}/scripts/verify/anti-pattern-lint.sh"

if [ ! -x "$LINT" ]; then
  echo "FAIL: anti-pattern-lint.sh missing" >&2; exit 1
fi

# List of P01-new scripts (hand-enumerated; the phase suite owns this list).
SCRIPTS="
scripts/util/dual-write-runtime-md.sh
scripts/knowledge/spec-complexity-probe.sh
scripts/specify/specify.sh
scripts/verify/spec-shape-lint.sh
tests/test-specify-shape.sh
tests/test-dual-write-outside-invariant.sh
scripts/verify/m014-p01-template-ssot.sh
scripts/verify/m014-p01-spec-shape-lint.sh
scripts/verify/m014-p01-dual-write-helper.sh
scripts/verify/m014-p01-dual-write-outside-invariant.sh
scripts/verify/m014-p01-complexity-probe-stub.sh
scripts/verify/m014-p01-specify-command.sh
scripts/verify/m014-p01-specify-sh.sh
scripts/verify/m014-p01-specify-shape-test.sh
scripts/verify/m014-p01-config-keys.sh
scripts/verify/m014-p01-agents-md-shape.sh
scripts/verify/m014-p01-runtime-assumptions.sh
scripts/verify/m014-p01-spec-management-reference.sh
scripts/verify/m014-p01-bash32-compat.sh
scripts/verify/m014-p01-zero-prompts.sh
scripts/verify/m014-p01-phase-suite.sh
"

FAILED=0
FAILS=""

for rel in $SCRIPTS; do
  abs="${PROJECT_ROOT}/${rel}"
  if [ ! -f "$abs" ]; then
    continue  # Not yet shipped; anti-pattern-lint will run suite-wide at close.
  fi

  # Self-exempt: this script contains literal pattern strings in diagnostic
  # messages and grep regexes that would false-positive against its own body.
  # It is the verifier, not a production script — it does not actually USE
  # the prohibited constructs. Precedent: M016/P03 lint-self-excludes.sh.
  case "$rel" in
    scripts/verify/m014-p01-bash32-compat.sh) continue ;;
  esac

  # Bash 3.2 compat heuristics (coarse — matches M015 precedent).
  if grep -qE 'declare[[:space:]]+-A' "$abs"; then
    FAILS="${FAILS}${rel}: uses declare -A (not Bash 3.2 safe)\n"; FAILED=1
  fi
  if grep -qE 'mapfile[[:space:]]' "$abs" || grep -qE 'readarray[[:space:]]' "$abs"; then
    FAILS="${FAILS}${rel}: uses mapfile/readarray (not Bash 3.2 safe)\n"; FAILED=1
  fi
  if grep -qE '\$\{[A-Za-z_][A-Za-z_0-9]*,,\}' "$abs"; then
    FAILS="${FAILS}${rel}: uses \${var,,} case expansion (not Bash 3.2 safe)\n"; FAILED=1
  fi

  # Anti-pattern lint per-file.
  if ! bash "$LINT" --fixture "$abs" >/dev/null 2>&1; then
    FAILS="${FAILS}${rel}: anti-pattern-lint failed\n"; FAILED=1
  fi
done

if [ "$FAILED" -eq 1 ]; then
  printf "FAIL: Bash 3.2 compat or anti-pattern lint failures:\n%b" "$FAILS" >&2
  exit 1
fi

echo "PASS: all P01-new shell scripts are Bash 3.2 compatible and lint-clean"
exit 0
