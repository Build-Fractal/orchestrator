#!/usr/bin/env bash
# scripts/verify/m012-p04-summary-walkthrough.sh — M012/P04 phase-close gate.
#
# When P04-SUMMARY.md exists, asserts it:
#   - names each of US1..US5 (either "US1".."US5" or the literal
#     "User Story 1".."User Story 5" forms)
#   - lists each of SC-1..SC-11 with a verdict token
#     (`pass`, `fail`, or `skip`) on the same line
#
# When P04-SUMMARY.md is absent, emits `SKIP:` and exits 0. The summary
# is a phase-close artifact written during consolidation, not during
# task execution. The accept-on-absent behavior is explicit and logged
# so the phase-suite orchestrator treats it as PASS pre-close.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

SUMMARY="$ROOT/.orchestrator/milestones/M012/phases/P04/P04-SUMMARY.md"
if [ ! -f "$SUMMARY" ]; then
  printf 'SKIP: %s not yet written (phase-close artifact; accept-on-absent per T05-PLAN)\n' "$SUMMARY"
  exit 0
fi

# User stories: accept either `US<N>` or `User Story <N>` forms.
for n in 1 2 3 4 5; do
  if ! grep -qE "(US${n}\b|User Story ${n}\b)" "$SUMMARY"; then
    printf 'FAIL: %s missing US%d / "User Story %d"\n' "$SUMMARY" "$n" "$n" >&2
    exit 1
  fi
done

# Success criteria: each `SC-<N>` line must carry a verdict token.
# Match patterns (case-insensitive) `pass|fail|skip` somewhere on the
# same line as the SC-<N> reference. Word-boundary guard with [^0-9]
# prevents SC-1 from matching SC-10 / SC-11.
for i in 1 2 3 4 5 6 7 8 9 10 11; do
  line=$(grep -E "SC-${i}([^0-9]|$)" "$SUMMARY" | head -n 1)
  if [ -z "$line" ]; then
    printf 'FAIL: %s missing SC-%d reference\n' "$SUMMARY" "$i" >&2
    exit 1
  fi
  if ! printf '%s' "$line" | grep -qiE '\b(pass|fail|skip)\b'; then
    printf 'FAIL: %s SC-%d line missing verdict token (pass|fail|skip): %s\n' "$SUMMARY" "$i" "$line" >&2
    exit 1
  fi
done

printf 'PASS: P04-SUMMARY.md walks US1..US5 and SC-1..SC-11 with verdict tokens\n'
exit 0
