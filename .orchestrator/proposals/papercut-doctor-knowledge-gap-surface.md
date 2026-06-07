# Paper-cut: Doctor — knowledge-graph gap-surface check

> **Reconciled into M044/FR-15 (2026-06-07).** M044 shipped the single consolidated `DOCTOR:KNOWLEDGE_ACTIVATION` doctor surface (`scripts/diagnostics/check-knowledge-activation.sh`) covering three *activation* symptoms (0-mem-on-mature / vestigial-index / runtime-memory-divergence). The negative-space `KNOWLEDGE_GAP` density check described below is a **distinct 4th symptom**; if it ships, it MUST land as an additional symptom under that same `DOCTOR:KNOWLEDGE_ACTIVATION` check — **never as a parallel doctor surface** (M044 CON-5: one knowledge-activation surface). Do not add a second `DOCTOR:KNOWLEDGE_*` check.

**Captured**: 2026-05-10
**Shape**: Single PR (~0.5–1 day). One new `doctor` check; no new commands; no schema changes.
**Predecessors**: M020 (knowledge-graph layer — `KNOWLEDGE-INDEX.md`, MEM frontmatter), M027 (cost+quality observability — doctor framework hosts the new check)
**Source**: 2026-05-10 README audit + adoption-pattern article on knowledge-system feedback loops. The article's *"what am I clearly not reading that I should be?"* question maps to a real orchestrator gap: the knowledge graph grows densely around dispatched topics and sparsely around un-dispatched topics, even when those gaps matter. Today's `doctor` detects orphans and drift; it does **not** detect *negative space*.

## TL;DR

Add one `doctor` check — `DOCTOR:KNOWLEDGE_GAP` — that compares MEM density across spec sections (or roadmap phases) and flags areas with `tasks_dispatched > 0 AND mem_count == 0`. Honest signal. Cheap. Would have caught at least two M036a gaps earlier (the live-LLM smoke gap, the wiki projection gap) — both surfaced retroactively in `launch-sequencing-amendment-2026-05-03.md`.

## Why a papercut, not a milestone

This is a single check inside the existing `doctor` framework. It reuses:

- `KNOWLEDGE-INDEX.md` parsing (already in `scripts/knowledge/`)
- Phase-plan walking (already in `scripts/state/`)
- The `DOCTOR:<NAME> status=ok|warn|fail` emission convention (already in `commands/doctor.md`)

No new primitives, no schema changes, no new commands. ~50-100 lines of shell + one new test.

## Behavior

For each closed phase in the active milestone:

1. Read the phase plan; extract the spec sections / FRs / SCs it claimed to address.
2. Count MEMs tagged with those section / FR / SC references in `KNOWLEDGE-INDEX.md`.
3. If `tasks_dispatched > 0 AND mem_count == 0` for a section, emit:

```
GAP: phase=M036/P03 section="Tier 2 LLM extraction" tasks=8 mems=0
DOCTOR:KNOWLEDGE_GAP status=warn phases=1 gaps=3
```

`warn`, not `fail` — sparse MEM coverage is sometimes legitimate (trivial implementation, fully covered by spec, etc.). The operator decides whether each gap is real or expected.

## What it would have caught

- **M036a P03 live-LLM smoke gap** — P03 closed with 8 tasks dispatched but no MEM capturing "what we learned from running Tier 2 LLM extraction against a real fixture." The gap surfaced retroactively at launch-sequencing-amendment time (2026-05-03) and a separate smoke-test was queued for 2026-05-07. `DOCTOR:KNOWLEDGE_GAP` would have surfaced this at M036a close.
- **M032 wiki projection ergonomics** — M032 closed with the wiki tooling shipping correctly but no MEM about "what does a non-author reader actually experience." That gap drove the M037 insertion ahead of M035. `DOCTOR:KNOWLEDGE_GAP` against the M032 user-stories slice would have surfaced this at M032 close.

## Suppression / config

Standard `doctor` shape applies:

- `doctor.knowledge_gap.exempt_sections: [...]` in config for sections operators have decided are intentionally MEM-free.
- `doctor.knowledge_gap.min_tasks: 3` — sections with fewer than N dispatched tasks don't surface (signal/noise tuning).
- `doctor.knowledge_gap: off` — full disable.

## Scope-clarification

This is **not** a coverage gate — nothing fails because of a gap. It's a *visibility surface* — operators see negative space they wouldn't otherwise notice. Closing a flagged gap is always an operator decision (add a MEM, exempt the section, or accept the warn).

This is **not** a replacement for `validate-milestone.sh` SC-coverage checks — those verify acceptance criteria are mechanically tested; this surfaces whether *learning* was captured alongside the implementation.

## Blast radius

- One new file: `scripts/diagnostics/check-knowledge-gap.sh` (~60-80 lines)
- One updated file: `commands/doctor.md` (new section under `## What It Checks`)
- One new fixture test: `tests/diagnostics/test-knowledge-gap-surface.sh`
- Zero changes to schema, dispatch, verify, or any non-doctor surface

## Trigger

Standalone — no demand-signal required. Ships any time post-launch in a normal paper-cut sweep window. Could even land as a tiny PR pre-launch if `doctor` work is opening anyway.
