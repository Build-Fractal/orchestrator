#!/usr/bin/env bash
# scripts/verify/m014-p03-bash32-and-lint.sh
# Gate: M014/P03/T05 — bash32 + anti-pattern-lint omnibus across
# scripts/comments/*.sh and scripts/verify/m014-p03-*.sh (excluding self).
# Self-exempts diagnostic-string lines in this file (precedent:
# m014-p01-bash32-compat.sh, m014-p04-bash32-and-lint.sh).
# AD-19 single-script-file shape; CON-6 / MEM001 Bash 3.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LINT="${PROJECT_ROOT}/scripts/verify/anti-pattern-lint.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x "$LINT" ] || fail "anti-pattern-lint.sh not executable at $LINT"

SELF="$(basename "${BASH_SOURCE[0]}")"

# Enumerate target scripts:
#   - every scripts/comments/*.sh introduced by T01-T04
#   - every scripts/verify/m014-p03-*.sh (excluding self)
COMMENTS_SCRIPTS=""
for f in "${PROJECT_ROOT}"/scripts/comments/*.sh; do
  [ -f "$f" ] || continue
  COMMENTS_SCRIPTS="${COMMENTS_SCRIPTS} ${f}"
done

VERIFIERS=""
for f in "${PROJECT_ROOT}"/scripts/verify/m014-p03-*.sh; do
  [ -f "$f" ] || continue
  if [ "$(basename "$f")" = "$SELF" ]; then continue; fi
  VERIFIERS="${VERIFIERS} ${f}"
done

SCRIPTS="${COMMENTS_SCRIPTS} ${VERIFIERS}"

# Bash 4+ tokens that must not appear (self-exempted via comment-stripping):
#   declare -A   (associative arrays)
#   mapfile      (readarray)
#   ${var,,}     (lowercase expansion)
#   ${var^^}     (uppercase expansion)
#   <(...)       (process substitution)
#   &>           (combined redirect, bash 4+ semantics)
PATTERNS='declare -A|mapfile|readarray|\$\{[A-Za-z_][A-Za-z0-9_]*,,|\$\{[A-Za-z_][A-Za-z0-9_]*\^\^|<\(|&>'

scanned=0
for s in $SCRIPTS; do
  [ -f "$s" ] || fail "script missing: $s"
  scanned=$((scanned + 1))
  # Strip full-line comments (^#...) before scanning — diagnostic strings and
  # pattern documentation in comment lines must not trip the gate.
  STRIPPED="$(grep -vE '^[[:space:]]*#' "$s" || true)"
  if printf '%s\n' "$STRIPPED" | grep -qE "$PATTERNS"; then
    MATCHES="$(printf '%s\n' "$STRIPPED" | grep -nE "$PATTERNS" | head -n 3)"
    fail "bash32-incompatible pattern in $s:
$MATCHES"
  fi
  # Anti-pattern-lint.
  bash "$LINT" --fixture "$s" >/dev/null 2>&1 \
    || fail "anti-pattern-lint failed on $s"
done

if [ "$scanned" -lt 1 ]; then
  fail "no scripts scanned — enumeration produced empty set"
fi

echo "PASS: $(basename "$0") — bash32 + anti-pattern-lint clean across ${scanned} scripts"
exit 0
