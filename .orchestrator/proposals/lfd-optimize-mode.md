# Proposal: LFD-mode — optimize-toward-a-private-eval (a fourth auto posture)

**Status**: Draft proposal, demand-driven, NOT scheduled. Captured 2026-07-03.
**Source**: "/goal + Loss Functions: How to Distill a Product in 30 Hours with One Prompt" — Elvis Sun (`github.com/elvisun/loss-function-development`, `/lfd-design`). Analysis folded into M046 as FR-18/FR-19/FR-20; this brief captures the *paradigm* piece deliberately kept out of M046 scope.
**Relationship**: composes ON TOP of M046 (auto-v2b serial safety envelope) and the auto-v2 arc (M045 → M046 → v2c-fanout → Posture-3). This would be a distinct **Posture 4**.

## The distinction that motivates this

The orchestrator's `auto` mode — and every posture in the current auto-v2 arc — is **spec-driven development (SDD)**: *"build this, make the tests pass."* A **finite** target, done the moment it is green. `auto-loop.sh` is exactly this: derive → dispatch → verify → record → advance until the milestone completes.

The article names a genuinely different loop — **loss-function development (LFD)**: *"build this, make the tests pass, **then descend toward this 1,000-case eval at 95%**."* A target you **optimize toward** across many cycles — no exit short of the bar. This is what `/goal` is actually for, and it is why we correctly **rejected `/goal` as an M046 substrate**: `/goal` is an optimization tool; our serial core is an execution tool. Different loops.

- **SDD / our auto mode** — finite, binary done, escalate-on-stall. Inner loop.
- **LFD / this proposal** — gradient descent toward an outcome metric, sparse feedback, many cycles. Outer loop. The months of a product team's ship-measure-iterate soak compressed into one run.

Posture 3 (until-verified) is still SDD — binary pass/fail on a verification. LFD is categorically different: *descend toward a score*.

## What LFD-mode would be for the orchestrator

An `orchestrator:auto --optimize <loss-function>` (or a sibling command) that drives the system toward a measurable target across many process-fresh cycles, scoring against a **private eval the target artifact never contained**. Use cases are product/data-shaped, not milestone-shaped: match/exceed a reference output at scale, optimize a benchmark, close a quality gap measured against ground truth.

### The loss function = 4 parts (the adoptable structure)

1. **Target** — large enough that enumeration doesn't pay; the agent is **blinded** to the answer key (eval exists only for post-hoc scoring). A small/visible eval gets memorized in one cycle (the article's 3-cheats saga).
2. **Constraints** — time (wall-clock budget — *"the constraint the agent always forgets"*), money (hard caps per paid call + a disposable-key ceiling), surface (providers/models/concurrency/sandbox), methodology (LLM vs deterministic; allowed data sources).
3. **Instruments (the harness)** — *"a constraint without an instrument is a vibe."* For every constraint, a CLI the agent can query: target measurement at the right resolution (pixel-diff, not LLM-rate-a-screenshot), time accounting, provider budget, LLM spend, self-token-spend.
4. **Forced entropy** — because each cycle continues from prior context, local maxima are the default. Overfit-reflection every cycle (generalizing or memorizing?), force a non-obvious jump on stall (not "same idea harder"), keep an iteration log.

## What M046 already banks for this (composition)

M046's serial safety envelope IS the constraints+instruments layer LFD needs:
- **Constraints** — FR-7 budget ceiling + watchdog, CON-4 wall-clock always-on, FR-9 tool/MCP sandbox → the article's time/money/surface constraints.
- **Instruments** — FR-19 agent-queryable constraint introspection → the article's "ship a CLI for every constraint."
- **Iteration log** — FR-18 attempts-ledger → the article's iteration log (and MORE load-bearing under our process-fresh model, which wipes context totally).
- **Anti-gaming** — FR-20/CON-7 verification-integrity → the fences that stop the agent cheating its target.

So LFD-mode would add only the genuinely LFD-specific pieces on top: the **target+blind-eval** machinery, the **scoring/gradient** loop, and **forced-entropy-on-stall** (which M046 deliberately does NOT adopt, because in deterministic execution a stall means escalate-to-human, not inject randomness — forced entropy is an optimization construct only).

## The paradigm/identity question (why this is a proposal, not a milestone)

Is metric-descent execution within the orchestrator's identity? The orchestrator is a **dev-milestone executor**; LFD/product-distillation is a **different tool** (the article's own examples are cloning a competitor's public output). Two honest framings:
- **Yes** — the safety-envelope + harness-discipline overlap is large; LFD-mode is a natural fourth posture that reuses ~80% of the auto-v2 substrate, and "author the thing that drives the loop" is already the orchestrator's philosophy (`specify` authors specs; an `lfd-design`-style flow would author target+constraints+instruments+entropy).
- **No / not yet** — it broadens the tool's identity from "execute my milestone" to "optimize toward my metric," which is a product decision, not an execution one; demand-driven only.

## Security framing (noted, not scoped)
The article's closing — public artifacts are cheaply distillable, information asymmetry is the new moat, cal.com went closed-source, *"/goal read source and enumerate attack surface until something works"* — is a reminder that unattended optimization loops are dual-use and dangerous. It reinforces (does not change) M046's default-DENY sandbox (FR-9) and BLOCK-on-ambiguity (FR-11). Any LFD-mode MUST inherit that envelope; an unfenced optimizer is exactly the hazard.

## Open questions
- **#L-1** — is metric-descent execution in-identity for the orchestrator, or a sibling tool? (paradigm decision, blocks scheduling)
- **#L-2** — does LFD-mode reuse `orchestrator:auto --optimize` or a distinct command/skill?
- **#L-3** — target/eval authoring: a `/lfd-design`-style generator flow (compose with `orchestrator:specify`)?
- **#L-4** — forced-entropy mechanics under our process-fresh model (which already breaks the "walking up the same hill" trap differently than `/goal`'s in-session continuation) — does forced entropy even behave the same for us?
- **#L-5** — scoring/gradient persistence across process-fresh rotations (extends FR-18 attempts-ledger toward a metric-gradient ledger).

## Disposition
Demand-driven. Promote via `orchestrator:specify` only when a concrete optimize-toward-metric need arrives (and after the #L-1 identity question is answered). Until then: M046 has already harvested the directly-applicable safety/harness insights; this brief preserves the paradigm piece so it is not lost to context-expiry.
