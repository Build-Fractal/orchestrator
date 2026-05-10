# Proposal — Shell-to-LLM Bridge for Tier 2 Extraction Live: Branch

**Status:** Deferred — post-launch fast-follow.
**Authored:** 2026-05-06.
**Surfaced by:** M036a P03 live-LLM smoke test (see
`tests/fixtures/m036-live-llm-smoke/`).

## Background

M036a P03 shipped the Tier 2 LLM extraction pipeline with three
dispatch modes in `scripts/knowledge/lib/extract-tier-2-llm.sh`:

- `stub:pass` — copies a canned high-fidelity fixture (CI).
- `stub:block` — copies a canned low-fidelity fixture (CI).
- `live` — **unimplemented**, errors out with `live mode not yet
  implemented` (line 56). Deferred under CON-3 (no live LLM in CI).

The `live` branch was always P03-scope but deferred for CI determinism.
Implementing it is non-trivial because of MEM018:

> Per MEM018, the Agent tool cannot be invoked directly from a shell
> script; it is an in-process capability of the orchestrating agent
> runtime.

So the live branch needs **a designed shell-to-LLM bridge** — not just
a one-line API call.

## Pre-launch interim — what M036a's live-smoke does today

The live-LLM smoke harness at
`tests/m036-acceptance/live-llm-smoke/run-smoke.sh` works around the
constraint by having the orchestrating Claude Code session do the
extraction in-session (via the Agent tool), pre-stage the result at
`tests/fixtures/m036-live-llm-smoke/extracted-structured.md`, then
exercise the production conversus fidelity gate + promote/retain +
unit_close shell pipeline against it.

This is **fine for smoke insurance** — it validates the
architecturally-fragile gate pipeline against real LLM input. It is
**not fine for production** — it requires manual two-step operation
(extract in agent session, run harness) instead of a one-shot
`orchestrator:extract` invocation against a tier-2 manifest.

## Goal

Make `EXTRACT_TIER_2_DISPATCH=live` work end-to-end as a single shell
invocation. Operator runs `orchestrator:extract` against a tier-2
manifest; the extraction LLM call happens transparently; structured
Markdown lands in the chunk store; gate runs; promote/retain happens;
unit_close emits. No two-step dance.

## Three implementation paths

### Path A1 — `claude -p` shellout (CC-only)

Invoke the Claude Code CLI in non-interactive mode with the source
markdown + the prompt template at
`templates/extraction-prompts/tier-2-structured-md.md` piped to stdin
or passed as a flag. Parse stdout as the structured-md output.

**Pros:**
- Simplest implementation. ~20-line addition to the live: branch.
- Zero new dependencies (CC is already required for the launch
  posture).
- Auth posture mirrors the rest of the orchestrator (OAuth via
  `~/.claude/`).

**Cons:**
- `claude -p` doesn't expose token counts or per-call cost in a
  structured way (last-checked 2026-05-06). The unit_close record's
  `tokens_in` / `tokens_out` / `cost_usd` fields would have to be
  estimated from char-count quartiles via `scripts/lib/pricing.sh`.
  Functional for budgeting but less precise than [M030](../milestones/M030/index.md) ideal.
- CC-only by definition. Codex CLI / Cursor users would need a
  parallel adapter (Path A2 covers that).

### Path A2 — Backend-adapter parity (multi-runtime)

Extend `scripts/dispatch/adapters/backend/` with a new adapter type:
not just dispatch backends, but **direct-call backends** that bypass
the MEM018 in-process-Agent boundary because they target external
LLM CLIs (claude, codex, anthropic-direct) rather than the Agent tool.

The live: branch would resolve the appropriate direct-call adapter
based on runtime detection (`scripts/dispatch/detect-runtime.sh`) and
shell out to it.

**Pros:**
- Multi-runtime by design — fits M009's parity story.
- Token/cost accounting could be more precise (per-adapter pricing
  resolution).
- Architecturally consistent with the rest of the dispatch layer.

**Cons:**
- ~1-2 days of work — bigger than a simple shellout.
- Probably wants to wait for M009 (multi-runtime parity audit)
  anyway, since runtime-detection invariants will firm up there.

### Path A3 — Conversus single-agent extraction preset

Author a conversus preset `tier-2-extract.yml` with one agent (the
extractor). The live: branch invokes
`scripts/dispatch/adapters/tool/conversus.sh run tier-2-extract
<input>` and reads the output.

**Pros:**
- Reuses the existing conversus shell-to-LLM bridge (already proven
  by the M036a fidelity gate).
- Auth/runtime posture identical to the gate path — same operator
  setup.
- Cost/token visibility comes from conversus's own JSONL emission.

**Cons:**
- Heavier than A1 — the orchestrator pays for a second conversus
  invocation per Tier 2 doc (extract + gate, instead of just gate).
- Conversus is an OSS dependency — adds coupling to a project the
  orchestrator already depends on, but more deeply.
- Conversus currently shapes itself around deliberation, not raw
  text-generation. A "single-agent extraction" preset is feasible
  (`classify-comment.yml` is the existing precedent) but stretches
  the tool's intent.

## Recommendation

**Start with A1 (`claude -p` shellout) as the post-launch fast-follow,
then evaluate A2 if M009 lands and Codex/Cursor users arrive.**

A1 is small enough to ship as a single phase (P10 of M036b, or a
standalone post-launch ticket). It unlocks `orchestrator:extract` as
a one-shot Tier 2 ingest path for CC users — which is everyone at
launch posture. A2 graduates to the right shape when there's actual
multi-runtime demand.

A3 is interesting but premature — it loads up the conversus
dependency for a job that doesn't need deliberation. If A1 hits
unexpected friction (e.g., `claude -p` token-output stability turns
out to be poor), A3 becomes a useful fallback.

## Scope sketch (for A1)

Single phase (~½ day):

1. **Live branch implementation.** Replace the error-out at
   `extract-tier-2-llm.sh:50-58` with:
   - Read source markdown.
   - Resolve model id via the model-routing.yml `routing.extraction`
     row + `resolution:` block (same awk pattern dispatch-interface.sh
     uses).
   - Compose prompt = `templates/extraction-prompts/tier-2-structured-md.md`
     contract + manifest metadata + source content.
   - Shell out to `claude -p --model <id>` with the prompt.
   - Capture stdout, write to out path.
   - Estimate tokens via `chars_to_tokens_quartile`; compute cost via
     `pricing_estimate_cost_usd`.
   - Emit MODEL/TOKENS_IN/TOKENS_OUT/COST_USD/QUALITY_SCORE to stderr
     in the existing NAME=VALUE format.

2. **Plan-time discipline check.** Add a `live` mode regression test
   under `tests/m036-acceptance/` that runs the full pipeline once
   live (gated by `LIVE_LLM_SMOKE=1` env, off by default in CI per
   CON-3). Reuse the `tests/fixtures/m036-live-llm-smoke/` fixture.

3. **Documentation.** Update `commands/extract.md` to document the
   live mode (auth setup, expected cost-per-Tier-2-doc estimate, what
   to do when a doc gets BLOCKED).

4. **Sibling fix.** Fix the `mode: cooperative` field in
   `templates/conversus-presets/normalize-fidelity.yml` ([M011](../milestones/M011/index.md)'s
   preset) — same bug as `tier-2-fidelity.yml`, same one-line fix. M036a P03 live-smoke surfaced it; not fixed in the smoke pass to
   keep that scope tight.

## Slot in the roadmap

Best fit: **M036b P10** (post-launch fast-follow for the reference-
corpus pipeline). M036b's P08–P09 are wiki projection + scale UX.
P10 would be "complete the live: branch" — directly extends M036a's
core deliverable, ships when validator-pilot signal informs whether
this is the right LLM-bridge shape.

Alternative: standalone post-launch ticket at the same priority as
the friendly-tester pass. A1 is small enough that it doesn't need a
milestone of its own.

## Open questions

- **Q1.** Does `claude -p` reliably emit token-count metadata in
  some discoverable form? If yes (even via stderr or a sidecar log),
  A1's cost-accounting weakness disappears. If no, A1 + char-count
  estimation is acceptable but suboptimal.
- **Q2.** Is the M030 `task_type=extraction` routing-table entry
  actually plumbed to anywhere that reads it today? P03 added the
  row at `templates/model-routing.yml::routing.extraction:` (T01) but
  the only consumer is the unimplemented live: branch we're now
  implementing. Worth checking that the row is shaped correctly
  before A1 codes against it.
- **Q3.** Should the prompt template path be configurable? Operators
  ingesting domain-specific reference materials (medical, legal,
  financial) may want to swap in domain-tuned prompts. A
  `manifest.tier_2_prompt` field per document is a small addition
  that makes the bridge more durable.
