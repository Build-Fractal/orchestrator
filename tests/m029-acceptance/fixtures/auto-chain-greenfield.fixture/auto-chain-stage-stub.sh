#!/usr/bin/env bash
# tests/m029-acceptance/fixtures/auto-chain-greenfield.fixture/auto-chain-stage-stub.sh
#
# M029 / P03 / T04 / SC-10 fixture stub.
#
# AUTO_CHAIN_STAGE_STUB target: the start.sh chain-driver invokes this
# script with the stage name as $1. The stub is a no-op that prints a
# diagnostic and returns 0 so the chain-driver records the .complete
# marker for that stage.
#
# Real-mode chain invocations (no AUTO_CHAIN_STAGE_STUB env var) skip
# the stub entirely and assume the orchestrator harness invokes the
# deep skill between successive start.sh --auto-chain calls. The stub
# is fixture-only.

STAGE="${1:-unknown}"
printf 'STUB: stage=%s\n' "$STAGE"
exit 0
