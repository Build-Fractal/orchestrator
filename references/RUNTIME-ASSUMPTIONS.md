# Runtime Assumptions

This document records cross-runtime divergences and assumptions consumed
by the M009 launch-gate runtime-parity audit. Each block names a
milestone-scoped origin; each row inside a block names one divergence
with rationale and an M009 audit-row link.

The orchestrator targets three runtimes: `claude-code`, `codex`, and
`cursor`. Wherever runtime behavior diverges by design (because a
runtime exposes its own native model, CLI, or environment surface),
that divergence is captured here so M009 auditors can confirm each
case is intentional and verified.

## Compression (M018)

P07 (multi-runtime parity audit) exercised the M018 compression
pipeline under three simulated runtime environments — `claude-code`,
`codex`, `cursor` — against the fixture corpus at
`tests/compression-runtime-parity/`.

### Divergences

| ID | Surface | Divergence | Rationale | M009 Audit Row |
|----|---------|------------|-----------|-----------------|
| RA-M018-01 | Tier 3 model name + pricing | Each runtime's native model is invoked by `dispatch-interface.sh` for production T3 calls; pricing fields in `dispatch_usage.estimated_cost_usd` differ accordingly. | Per CON-3 / FR-13: T3 routes through `tier3-llm-call.sh` so each runtime calls its native model; the in-band marker schema is normalized but the model name + cost vary by runtime. | M009-RP-01 (compression-tier-3-pricing) |
| RA-M018-02 | `claude` CLI presence on PATH | `tier3-llm-call.sh`'s second-priority provider path requires the `claude` CLI on PATH when `ORCH_BACKEND=claude-code` and `ORCH_TIER3_LLM_BIN` is unset; absent that, the shim exits 1 and FR-9 failure-passthrough fires. | Operator-environment dependency outside the orchestrator's control; documented so M009 auditors can confirm the failure-passthrough path is operational under each runtime's expected install posture. | M009-RP-02 (claude-cli-path-presence) |

### Bash-only tier parity (filter + T1 + T2)

P07's parity runner asserts SHA-256 byte-equality of post-pipeline
payload bytes across `ORCH_BACKEND` ∈ {`claude-code`, `codex`, `cursor`}
for every fixture in the corpus. As of P07 close, **no divergence was
observed** — the bash-only tiers ignore `ORCH_BACKEND` (consistent with
their bash-only nature). The parity runner emits
`regression_flag: none` against the live `tests/compression-runtime-parity/`
corpus on a clean checkout.

Any future divergence should land here as a new RA-M018-NN row with
the fixture name, divergent runtime, and rationale; the P07 verifier
accepts `regression_flag: divergence` only when the corresponding
RA-M018-NN row exists (the "documented divergence" carve-out).

### Tier 3 routing parity

P07's Tier 3 routing-parity runner
(`scripts/diagnostics/m018-runtime-parity-tier3.sh`) confirms T3
routes through `scripts/dispatch/lib/tier3-llm-call.sh` under every
runtime via the deterministic stub at
`tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh`. The
`--fail-stub` mode confirms FR-9 failure-passthrough (Tier 2 bytes
pass through unchanged on stub-fail) is preserved across runtimes.

### M009 launch-gate handoff

The `M009 Audit Row` column above is consumed by M009's runtime-parity
audit. P07 uses placeholder IDs (`M009-RP-01`, `M009-RP-02`); M009
will assign real audit-row IDs at audit time. The verifier asserts the
column header exists and at least one RA-M018-NN row is present, not
specific row IDs.
