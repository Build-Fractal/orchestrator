# tier3-oversized-section fixture (M018/P07/T02)

Tier 3 routing-parity fixture — consumed by T02
(`scripts/diagnostics/m018-runtime-parity-tier3.sh`), not by the
T01 zero-LLM runner.

## Payload shape

`input/payload-input.txt` carries a single ~7.5 KB `## Knowledge`
section that survives Filter + Tier 1 + Tier 2 (all disabled in this
fixture's config) and reaches the Tier 3 helper. T02 wires
`tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` as
`ORCH_TIER3_LLM_BIN` so the LLM call is deterministic across runtimes.

## Config under test

Filter + Tier 1 + Tier 2 disabled. Tier 3 invocation is gated by the
T02 runner via `ORCH_TIER3_LLM_BIN` + the `tier3-llm-call.sh` shim.

## Note on T01 scope

T01 stages this directory but does not exercise the parity runner
against it (the runner skips the `tier3-oversized-section` slug). T02
ships the runner that does.
