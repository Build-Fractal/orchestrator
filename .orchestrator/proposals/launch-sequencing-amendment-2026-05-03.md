---
schema_version: "1.0"
type: proposal
status: active
created_at: 2026-05-03
amends: "Forward Roadmap in CLAUDE.md (revised 2026-05-01)"
---

# Launch Sequencing Amendment — 2026-05-03

## Context

M036a (P00–P07) closed 2026-05-02 in the parallel pre-launch workstream. With the M036a critical path proven, this amendment formalizes the recommended sequencing for the linear launch queue based on **risk profile** rather than dependency order alone.

## Headline Change

Published order (2026-05-01): **M031 → M032 → M033 → M029 → M035 → launch**

Amended order (2026-05-03): **M031 → (M032 + M033 paired) → M029 → M035 P02–P06**, with **M036a live-LLM smoke test** as a parallel pre-pilot insurance step.

## Rationale (risk-ranked, not dependency-ranked)

The published order is dependency-correct but does not surface where the *blast radius* concentrates. Risk-ranked, the pre-launch milestones cluster as:

1. **M035 P02–P06** — highest blast radius. Broken package publishing = no users can install. Curl-pipe-bash specifically has supply-chain implications. Multi-channel version skew is reported as broken.
2. **M033** — highest "won't know it's bad until users try" risk. The four init branches (greenfield-empty / greenfield-with-materials / existing-codebase / migrating) cannot be dogfooded against this repo, so synthetic test fixtures are weak signal. Cold-start UX only resolves with warm bodies.
3. **M032 ↔ M033 coupling** — M033/P05 calls into M032's `--with-wiki` gate. Sequential build leaves the seam unexercised until late; pairing exposes it under realistic conditions earlier.
4. **M036a (parallel)** — Tier 2 LLM extraction has been proven against stubs only. The PBJ pilot (2026-05-15) is the first real-user end-to-end test.
5. **M029** — low technical risk, but launch-polish-critical. Install experience must feel finished when packages drop.
6. **M031** — well-scoped, low risk. Fixes a specific known bug (Quick-flow knowledge-graph leak at `commands/dispatch.md:21`).

## Amended Sequence

1. **M031 first** — small, low-risk, banks a quick win and exits with light context. Proves the post-amendment plan-phase invariants in flight before harder milestones bet on them.

2. **M036a live-LLM smoke test (parallel, before 2026-05-08)** — run at least one *real* LLM extraction end-to-end (not stub) against a tiny PBJ fixture. Cheap insurance against arriving at the 2026-05-15 pilot with a path that's only ever been exercised mocked. Owner: parallel sub-agent; budget ~30 min.

3. **M032 + M033 as a paired unit** — diverges from published sequential order. M033/P05 calls into M032's `--with-wiki` gate, so build them with that integration live the whole time. Treat as one workstream with internal phases that interleave: M032's templating ships → M033 starts wiring it → M032 rough edges surface immediately, not three weeks later.

4. **Friendly-tester pass on M033 before locking** — *new*, not in published order. Recruit 1–2 outsiders to walk all four init branches (greenfield-empty / greenfield-with-materials / existing-codebase / migrating). 30 minutes each. Blocks M033 close. Adds ~1 week buffer.

5. **M029 (polish)** — before M035 P02–P06 publishing. Install experience feels finished when packages drop, not after.

6. **M035 P00 + P01 (pre-launch dev-ergonomics)** — already-staged early in the published order; ship anytime; unblocks symlink-mode dogfooding + version-drift warning.

7. **M035 P02–P06 (the launch event)** — last. One coordinated drop: stage npm + homebrew + curl-pipe-bash builds together, publish in lockstep, rollback runbook ready for each channel. No spreading across days; version-skew risk is real.

## Tradeoffs (named explicitly)

- **+~1 week vs. published sequence** — M032/M033 pairing overhead + friendly-tester buffer. Tight against the 2026-05-15 PBJ deadline but the deadline is M036a's, not the launch queue's.
- **Pairing M032+M033 increases cognitive load** — one workstream needing both contexts in head simultaneously. Reduces seam-bug risk; less optimal for parallel sub-agent dispatch.
- **M036a smoke test pulls focus** from the launch queue — if skipped, the pilot becomes the smoke test (higher-stakes alternative).
- **The friendly-tester pass requires recruiting** — 1–2 people, 30 minutes each. If unavailable, fall back to the published sequence and accept the cold-start risk.

## Single Biggest Risk

**M035 (publishing) and M033 (cold start)** are the two milestones where extra eyes / extra time pays off most. M031 / M032 / M036a / M029 are well-scoped and low-uncertainty.

## Status

- Active. Supersedes the headline-sequence-only line in CLAUDE.md `Forward Roadmap`.
- M036a P04 / P06 / P07 closed 2026-05-02 — dependency unblock is real, not aspirational.
- Standalone constitution amendment remains independent (no sequencing dependency).
- Post-launch fast-follows unchanged (M009 → M023 → M034 → M036b → wiki-ux-deep + external-tool-adapters → M010).

## Open Questions

- **Q1**: Friendly-tester recruiting — who, by when?
- **Q2**: M036a live-LLM smoke test fixture choice — pick a single representative PBJ document or use the existing tier-2 fixture?
- **Q3**: M032/M033 pairing — single dispatcher running both, or two dispatchers with explicit synchronization handoffs?

These do not block M031 start. Resolve when M032/M033 enter the queue.
