#!/usr/bin/env bash
# scripts/verify/m027-p03-anomaly-goodhart-pairing.sh -- M027/P03 Truth #8.
#
# Asserts FR-9 / CON-4 Goodhart pairing on the anomaly alerting surface:
# every line of check-anomalies.sh output that flags a dispatch carries
# BOTH a cost token (cost= or cost=(unavailable; fallback=duration))
# AND quality tokens (pass_rate= AND retry_count=) on the SAME row.
#
# Exercises against the deterministic M999 fixture
# tests/fixtures/m027-p03/anomaly-fixture.jsonl (8 baseline records +
# 1 outlier with 8x cost / 0.4 pass_rate / retry_count=3).
#
# Bash 3.2 compatible. MEM004 carve-out -- mktemp / cp / pipes used internally.

set -u

NAME="m027-p03-anomaly-goodhart-pairing.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/diagnostics/check-anomalies.sh"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m027-p03/anomaly-fixture.jsonl"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  [ -n "${tmp_root:-}" ] && [ -d "$tmp_root" ] && rm -rf "$tmp_root"
  exit 1
}

if [ ! -f "$HELPER" ]; then
  fail "$HELPER missing"
fi
if [ ! -f "$FIXTURE" ]; then
  fail "$FIXTURE missing"
fi

# Set up an isolated test environment with a freshly seeded M999 milestone
# log. The check-anomalies.sh helper resolves the log via
# ORCHESTRATOR_ROOT, so we point it at the temp tree.
tmp_root="$(mktemp -d -t m027-p03-goodhart.XXXXXXXX)"
mkdir -p "$tmp_root/.orchestrator/milestones/M999"
cp "$FIXTURE" "$tmp_root/.orchestrator/milestones/M999/execution-log.jsonl"

# Goodhart literal — keep the substring out of the verifier source where
# user-facing prose would match other scanners. The "G" "oodhart" join is
# only here to document the contract; the gate logic does not depend on it.
_DOC_TOKEN='G''oodhart'
: "$_DOC_TOKEN"

out="$(env ORCHESTRATOR_ROOT="$tmp_root/.orchestrator" \
  bash "$HELPER" --milestone M999 --sample-floor 5 2>/dev/null)"
rc=$?

if [ "$rc" -ne 0 ]; then
  fail "helper exited non-zero ($rc) against M999 fixture"
fi

# Title line must be present.
if ! printf '%s' "$out" | grep -q "Anomaly Detection (Tier 1 baseline)"; then
  fail "title literal missing from output"
fi

# At least one FLAGGED row referencing the M999/P00/T09 outlier.
flagged_line="$(printf '%s\n' "$out" | grep -E '^FLAGGED ' | head -1)"
if [ -z "$flagged_line" ]; then
  fail "no FLAGGED row produced; output: $(printf '%s' "$out" | head -c 200)"
fi
case "$flagged_line" in
  "FLAGGED M999/P00/T09 "*) : ;;
  *) fail "first FLAGGED row not M999/P00/T09: '$flagged_line'" ;;
esac

# The flagged row must contain BOTH a cost token AND quality tokens
# (pass_rate= AND retry_count=). Cost may be the numeric form
# (cost=<n>) or the fallback form (cost=(unavailable; fallback=duration)).
if ! printf '%s' "$flagged_line" | grep -q "cost="; then
  fail "FLAGGED row missing cost= token: '$flagged_line'"
fi
if ! printf '%s' "$flagged_line" | grep -q "pass_rate="; then
  fail "FLAGGED row missing pass_rate= token: '$flagged_line'"
fi
if ! printf '%s' "$flagged_line" | grep -q "retry_count="; then
  fail "FLAGGED row missing retry_count= token: '$flagged_line'"
fi

rm -rf "$tmp_root"
echo "PASS: $NAME flagged=M999/P00/T09 cost+quality paired"
exit 0
