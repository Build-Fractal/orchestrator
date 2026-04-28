# m018-p06-tier3-failed-log

Hand-crafted execution-log.jsonl fixture for the FR-9 failure-passthrough
scenario: Tier 3 LLM call returned a non-zero exit (or preservation-check
violated), so `_bc_apply_tier3` emitted a `tier3_failed` JSONL record and
returned 0 — the dispatch still received Tier 2's output unchanged and
completed successfully.

## Record mix (6 records on M018G/P06)

`payload_breakdown` rows (2):

- T01: `tier3_compression_savings_tokens=0 tier3_invocations=0` — Tier 3
  did not produce savings (LLM call failed).
- T02: `tier3_compression_savings_tokens=0 tier3_invocations=0` — Tier 3
  did not produce savings (preservation breach).

`tier3_failed` events (2):

- T01: `reason=llm-call-nonzero` — LLM call returned non-zero exit code.
- T02: `reason=preservation-breach` — post-call preservation self-check
  rejected the summary.

`unit_close` rows at granularity=task (2): both `verification_pass_rate=1.0`
— the dispatches succeeded on the Tier 2 output. Failure-passthrough
means the agent never saw the Tier 3 attempt.

## Use via fixture-staging helper

`bash scripts/verify/_helpers/m018-p06-build-fixture.sh <root> tier3-failed`
copies this log to `<root>/milestones/M018G/execution-log.jsonl` and
emits `M018G` on stdout.
