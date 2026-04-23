#!/usr/bin/env bash
# Gate: T07 — Bash 3.2 compat + anti-pattern-lint for all P04 scripts.
# Self-exempts from its own regex scan (precedent: m014-p01-bash32-compat.sh).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LINT="${PROJECT_ROOT}/scripts/verify/anti-pattern-lint.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x "$LINT" ] || fail "anti-pattern-lint.sh not executable"

# Enumerate P04 scripts. Includes T02 probe body, T04-T06 specify.sh, all gate verifiers.
SCRIPTS="
${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh
${PROJECT_ROOT}/scripts/specify/specify.sh
${PROJECT_ROOT}/scripts/verify/m014-p04-complexity-thresholds-pinned.sh
${PROJECT_ROOT}/scripts/verify/m014-p04-complexity-probe-full.sh
${PROJECT_ROOT}/scripts/verify/m014-p04-pressure-test-preset.sh
${PROJECT_ROOT}/scripts/verify/m014-p04-specify-command-wiring.sh
${PROJECT_ROOT}/scripts/verify/m014-p04-three-way-prompt.sh
${PROJECT_ROOT}/scripts/verify/m014-p04-split-subcommand.sh
${PROJECT_ROOT}/scripts/verify/m014-p04-amend-three-case.sh
${PROJECT_ROOT}/scripts/verify/m014-p04-runtime-assumptions-fr5-fr7.sh
${PROJECT_ROOT}/scripts/verify/m014-p04-spec-management-reference-complete.sh
${PROJECT_ROOT}/scripts/verify/m014-p04-zero-prompts.sh
${PROJECT_ROOT}/scripts/verify/m014-p04-observability-records.sh
${PROJECT_ROOT}/scripts/verify/m014-p04-phase-suite.sh
"

SELF="$(basename "${BASH_SOURCE[0]}")"

# Bash 3.2 compat regex scan. Bash 4+ tokens that must not appear:
#   declare -A   (associative arrays)
#   mapfile      (readarray)
#   ${var,,}     (lowercase expansion)
#   ${var^^}     (uppercase expansion)
#   <(...)       (process substitution)
#   &>           (combined redirect, bash 4+ semantics)
PATTERNS='declare -A|mapfile|readarray|\$\{[A-Za-z_][A-Za-z0-9_]*,,|\$\{[A-Za-z_][A-Za-z0-9_]*\^\^|<\(|&>'

for s in $SCRIPTS; do
  [ -f "$s" ] || fail "script missing: $s"
  # Self-exemption: skip the scanner itself.
  if [ "$(basename "$s")" = "$SELF" ]; then continue; fi
  # Strip full-line comments (^#...) before scanning — diagnostic strings and
  # "no <pattern>" comments that reference forbidden tokens must not trip the gate.
  STRIPPED="$(grep -vE '^[[:space:]]*#' "$s" || true)"
  if printf '%s\n' "$STRIPPED" | grep -qE "$PATTERNS"; then
    MATCHES="$(printf '%s\n' "$STRIPPED" | grep -nE "$PATTERNS" | head -n 3)"
    fail "bash32-incompatible pattern in $s:
$MATCHES"
  fi
  # Anti-pattern-lint.
  bash "$LINT" --fixture "$s" >/dev/null 2>&1 || fail "anti-pattern-lint failed on $s"
done

echo "PASS: bash32 + anti-pattern-lint clean across all P04 scripts"
exit 0
