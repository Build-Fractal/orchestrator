# tier2-oversized-section fixture (M018/P07/T01)

Exercises the Tier 2 snip (US-4 / FR-5) — section head-drop with
`protected_tail_ratio` preservation — across the three simulated
runtimes.

## Payload shape

`input/payload-input.txt` is a ~58 KB lorem-ipsum body the helper
copies verbatim into the staged task plan. After payload assembly,
the `## Task Plan` section's token count exceeds
`tier2.section_budget_tokens`, so the head-drop fires. The configured
tail ratio is preserved byte-identical, and the awk pass injects an
in-band `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=R -->`
marker.

The post-snip preservation self-check enforces strict multiplicity over
every preserved-pattern row in the cross-tier vocabulary. The injected
tier2 compression marker is itself a preserved-pattern row, so on a
marker-free pre payload the strict-multiplicity check is unsatisfied
and T2 rolls the snip back. Either outcome — successful snip or
boundary-refusal-rollback — is deterministic across runtimes; the
byte-equality contract this fixture proves holds in both cases.

## Config under test

`compression.tier2.section_budget_tokens: 200`,
`compression.tier2.protected_tail_ratio: 0.3`. Filter + Tier 1
disabled. Tier 3 short-circuits via the runner's intensity override
(`Quick`).

## Byte-equality contract

The post-Tier-2 payload bytes are SHA-256-hashed under each runtime
(`ORCH_BACKEND` ∈ {`claude-code`, `codex`, `cursor`}). The three hashes
are byte-identical because the snip + boundary-refusal logic is
rule-based, not LLM-based — the cut byte, the safe-boundary retreat,
the marker text, and the rollback path are pure functions of the
assembled payload bytes.
