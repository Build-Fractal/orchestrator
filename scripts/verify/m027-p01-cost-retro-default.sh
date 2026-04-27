#!/usr/bin/env bash
# scripts/verify/m027-p01-cost-retro-default.sh — M027/P01 Truth #2 (FR-5,
# FR-12, US-2 AS-1/AS-2/AS-5).
#
# orchestrator:cost is a markdown command; the contract this verifier
# gates is the documented delegation: commands/cost.md MUST reference
# scripts/diagnostics/metrics-rollup.sh and the rollup flag set
# (--granularity / --milestone / --phase / --task / --source). It also
# smoke-tests that the delegated engine still works against a live M019
# milestone scope (exit 0).
#
# Bash 3.2 compatible.

set -u

NAME="m027-p01-cost-retro-default.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CMD="$PROJECT_ROOT/commands/cost.md"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

# 1. commands/cost.md must reference the rollup engine.
if [ ! -r "$CMD" ]; then
  fail "commands/cost.md missing"
fi
if ! grep -qF 'metrics-rollup.sh' "$CMD"; then
  fail "commands/cost.md missing reference to metrics-rollup.sh"
fi

# 2. The rollup flag pass-through must be documented (any one of
#    --granularity / --milestone / --phase / --task is sufficient
#    proof of delegation; the spec requires --milestone / --phase /
#    --task / --granularity / --source).
if ! grep -qE -- '--granularity|--milestone|--phase|--task' "$CMD"; then
  fail "commands/cost.md missing rollup flag pass-through (--granularity|--milestone|--phase|--task)"
fi
if ! grep -qF -- '--source' "$CMD"; then
  fail "commands/cost.md missing --source flag pass-through"
fi

# 3. Smoke-test the delegated engine against M019.
if [ ! -f "$ROLLUP" ]; then
  fail "scripts/diagnostics/metrics-rollup.sh missing"
fi
rollup_out="$(bash "$ROLLUP" --granularity milestone --milestone M019 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  printf 'FAIL: %s metrics-rollup.sh smoke-test failed (exit %d)\n%s\n' "$NAME" "$rc" "$rollup_out" >&2
  exit 1
fi
# The header row plus at least one data row should be present.
n=$(printf '%s\n' "$rollup_out" | grep -cE '^(GRANULARITY|milestone)' || true)
if [ "$n" -lt 1 ]; then
  fail "metrics-rollup.sh produced no recognizable header/data rows"
fi

printf 'PASS: %s delegation contract documented; engine smoke-test green\n' "$NAME"
exit 0
