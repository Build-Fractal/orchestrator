#!/usr/bin/env bash
# scripts/verify/m027-p03-zero-llm-token.sh -- M027/P03 Truth #9.
#
# Asserts FR-21 / CON-6 / SC-16: no LLM-invocation tokens appear in the
# M027/P03 script set (the two helper scripts plus the 11 sibling
# verifier scripts). The verifier file itself is excluded from the scan
# (it carries the regex literal by definition).
#
# Forbidden tokens (M019 carry-forward):
#   claude_chat
#   anthropic
#   dispatch-interface.sh
#   dispatch_task
#   subagent
#
# Bash 3.2 compatible. MEM004 carve-out -- grep used internally.

set -u

NAME="m027-p03-zero-llm-token.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

# Split-literal forbidden-token assembly so the regex itself, when present
# verbatim, only appears in this file. Other M027/P03 verifiers that
# include the regex string would be flagged -- but THIS file is the only
# one that should embed the literal pattern, and is excluded below.
T1="claude"; T1B="_chat"
T2="anthro"; T2B="pic"
T3="dispatch-inter"; T3B="face.sh"
T4="dispatch"; T4B="_task"
T5="sub"; T5B="agent"
PATTERN="(${T1}${T1B}|${T2}${T2B}|${T3}${T3B}|${T4}${T4B}|${T5}${T5B})"

# Explicit file list -- intentionally excludes m027-p03-zero-llm-token.sh.
FILES="
scripts/diagnostics/check-anomalies.sh
scripts/diagnostics/check-config-drift.sh
scripts/verify/m027-p03-suite.sh
scripts/verify/m027-p03-anomaly-shape.sh
scripts/verify/m027-p03-config-drift-shape.sh
scripts/verify/m027-p03-doctor-md-shape.sh
scripts/verify/m027-p03-doctor-byte-identity.sh
scripts/verify/m027-p03-suppression-matrix.sh
scripts/verify/m027-p03-run-doctor-integration.sh
scripts/verify/m027-p03-anomaly-latency.sh
scripts/verify/m027-p03-anomaly-goodhart-pairing.sh
scripts/verify/m027-p03-read-only.sh
scripts/verify/m027-p03-bash32-compat.sh
"

violations=""
for f in $FILES; do
  if [ ! -f "$f" ]; then
    fail "$f missing"
  fi
  matches="$(grep -nE "$PATTERN" "$f" || true)"
  if [ -n "$matches" ]; then
    violations="$violations
$f:
$matches"
  fi
done

if [ -n "$violations" ]; then
  printf '%s\n' "$violations" >&2
  fail "forbidden LLM-invocation tokens detected"
fi

echo "PASS: $NAME"
exit 0
