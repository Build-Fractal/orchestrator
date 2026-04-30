#!/usr/bin/env bash
# tools/verify/p04-additive-schema.sh -- Pass-through wrapper over P02 SC-11 gate.
#
# T01 deliverable. Thin delegation to tools/verify/p02-additive-schema.sh
# so the P04 phase-suite aggregator can invoke a single per-phase script
# while still re-checking the SC-11 byte-equality contract under HEAD.
# If P02's gate regresses, this wrapper FAILs with the same exit code.
#
# Pre-T02 (HEAD): passes against the unmodified emitter.
# Post-T02 + T03: must continue to pass -- amendments may NOT add fields
# to the shadow-off branch (additive-only-when-shadow-on per CON-2 / FR-19
# / SC-11). The wrapper enforces this transitively via the P02 gate.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
p02_gate="$PROJECT_ROOT/tools/verify/p02-additive-schema.sh"

if [ ! -f "$p02_gate" ]; then
  printf 'FAIL: p02-additive-schema.sh missing at %s (P02 gate not on disk)\n' "$p02_gate"
  printf 'SUMMARY: p04-additive-schema.sh pass=0 fail=1\n'
  exit 1
fi

bash "$p02_gate"
rc=$?

if [ "$rc" -eq 0 ]; then
  printf 'PASS: p02-additive-schema.sh delegated check (SC-11 byte-equality)\n'
  printf 'SUMMARY: p04-additive-schema.sh pass=1 fail=0\n'
  exit 0
fi

printf 'FAIL: p02-additive-schema.sh exited %d\n' "$rc"
printf 'SUMMARY: p04-additive-schema.sh pass=0 fail=1\n'
exit 1
