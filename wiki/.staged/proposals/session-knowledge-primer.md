# Proposal — Session Knowledge Primer (ambient knowledge-graph injection for ad-hoc Claude sessions)

**Status:** Soft-proposed — captured for later milestone consideration. Not active, not blocking anything.
**Authored:** 2026-05-06.
**Surfaced by:** Operator question during [M032](../milestones/M032/index.md) paper-cut sweep round 2 — "is there something already in Orchestrator that would let me leverage the knowledge base when I'm not working in the orchestrator flow?"
**Operator's interim answer:** `orchestrator:do <prompt>` covers immediate needs (Quick-profile knowledge inject before dispatch). This proposal is for the *ambient* case — fresh `claude` sessions in the project that don't go through any orchestrator command.

## Problem

When an operator opens a fresh Claude Code session in an orchestrator-managed project and just talks to Claude (no `/orchestrator-*` command invoked), the main context starts cold relative to the project's accumulated knowledge:

- `.orchestrator/knowledge/` (MEMs, reference corpus from M036a) — not surfaced.
- [`.orchestrator/KNOWLEDGE.md`](../knowledge.md) consolidation — not surfaced.
- `KNOWLEDGE-INDEX.md` graph entry points — not surfaced.
- Active milestone state, recent decisions, in-flight phase truths — not surfaced beyond the one-line `# >>> orchestrator:recent-changes >>>` marker in CLAUDE.md.

So Claude re-discovers everything via grep/Read against raw files. The orchestrator's investment in structured knowledge (which is *better-organized than what Claude would dig up cold*) goes unused. Token-wasteful and accuracy-lossy when the user is doing planning, design discussion, ad-hoc Q&A, or pasting a prompt generated elsewhere into a fresh agent.

## What partially closes the gap today

- **`orchestrator:do <prompt>`** (M031/P03, closed) — explicit one-shot entry with Quick-profile knowledge inject. The right tool when the operator remembers to use it. Doesn't help when they don't, or when the session is conversational rather than task-shaped.
- **`# >>> orchestrator:recent-changes >>>`** marker in CLAUDE.md — always-on but minimal (one-line digest of recent changes only). Not a knowledge-graph query.
- **`build-context.sh --profile=quick|standard|full`** (M031/P00) — the right primer plumbing, but invoked only by orchestrator commands.

## Proposed shape (sketch — do not over-design until milestone enters queue)

A **SessionStart-time knowledge primer**. Three layers, increasingly opt-in:

### Layer 1 — Always-on Quick primer (SessionStart hook)

A `scripts/lifecycle/prime-session.sh` (or similar) wired as a Claude Code SessionStart hook in the per-project `.claude/settings.json`. Emits a compact digest as a system reminder at session start:

- Active milestone + phase summary (1–2 lines).
- Top 3–5 recent decisions from [`.orchestrator/DECISIONS.md`](../decisions.md) by recency.
- Top N MEMs by recency or by globbing recent git activity.
- Pointer to KNOWLEDGE-INDEX.md and the [M036](../milestones/M036/index.md) reference corpus root.

Token-cheap target: ≤ 1.5K tokens. Quick-profile-shaped (reuses `build-context.sh --profile=quick` with a session-primer mode flag, ideally).

### Layer 2 — Explicit on-demand re-primer

A `/orchestrator-prime` slash command (or extend `orchestrator:context`) for mid-session injection. Useful when the operator switches focus areas and wants a different cross-section of the graph (e.g., "I'm now thinking about wiki tooling, prime me on M012/M032/wiki-related MEMs").

Could take optional args: `/orchestrator-prime wiki` → filter primer to wiki-domain knowledge.

### Layer 3 (stretch) — Lazy re-primer on domain-term match

Hook on UserMessage that scans the user's turn for domain terms matching unseen MEM headers; quietly pulls those MEMs into context as a system reminder. Risks: over-injection, signal-to-noise. Defer until layers 1+2 prove value.

## Why this is small, not a big milestone

The bones are all already there:

- Knowledge graph is structured (MEMs, KNOWLEDGE-INDEX.md, reference corpus).
- Profile system exists (`--profile=quick|standard|full`).
- `build-context.sh` is the right primer engine.
- Claude Code SessionStart hooks are an existing harness mechanism.
- The orchestrator already writes to CLAUDE.md (the `recent-changes` marker block), so the precedent for ambient injection exists.

What's missing is **glue**: a hook script + settings.json wiring + maybe a `--session-primer` mode on `build-context.sh`. Estimable as 1–3 phases (P01: hook + script + settings.json registration; P02: `/orchestrator-prime` slash command + filter args; P03 optional: lazy re-primer + tuning). Tier A or small Tier B.

## Composition with [M035](../milestones/M035/index.md)

M035 P00 ships `--mode=symlink` install for dogfooding velocity. The session-primer hook script lives in the bundle and gets installed/symlinked alongside everything else, so M035 P00 is a natural prerequisite (no extra packaging work). M035 P02–P06 (npm/homebrew/curl-pipe-bash publishing) would need to know about the hook registration for fresh installs.

So the natural slot is **post-M035, demand-driven**. Promote when:

- An operator other than the author of this brief asks for it.
- Or: the existing `recent-changes` marker proves insufficient signal during ad-hoc sessions in actual practice.
- Or: a downstream consumer reports re-discovering project knowledge from scratch in ad-hoc sessions and asks for a fix.

## Open questions to resolve at milestone-entry time

1. **Token budget:** what's the right cap on the always-on primer? Too small = useless; too large = burns context every session start.
2. **Scope of "active milestone":** state-from-disk via `find-active-milestone.sh`, or is there a need for operator-overridable focus?
3. **Per-project opt-out:** some projects might not want SessionStart injection (CI sessions, ephemeral worktrees). `.orchestrator/config.yml` opt-out flag?
4. **Multi-runtime:** SessionStart hooks are CC-specific. Codex CLI / Cursor would need equivalent integration points. M009 multi-runtime parity audit territory if/when those land.
5. **Interaction with [M018](../milestones/M018/index.md) compression layer:** primer output is itself a candidate for compression — should it route through the M018 tier-3 path?
6. **Conflict with `orchestrator:do`:** if operator runs `/orchestrator-do` after SessionStart primer fired, do they double-inject? Detect-and-skip, or accept the overlap?

## Status

Soft-proposed. Operator's stated needs are met by `orchestrator:do` for now. This brief exists so future-us doesn't re-derive the analysis from scratch — append findings here as more sessions surface evidence about whether ambient injection is actually load-bearing or whether explicit `do` invocation is enough.

Per project-memory (`project_proposals_lifecycle.md`): "Proposals are living docs; promotion to formal milestone is deliberate, not automatic; append findings to pending proposals as you learn." Treat this brief as a parking spot, not a commitment.
