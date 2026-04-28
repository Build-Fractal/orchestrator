# Future-Milestone Proposals

Captured 2026-04-27, refreshed 2026-04-28 after a milestone-status reconciliation pass against `.orchestrator/milestone-summary.md`.

These docs are inputs for `orchestrator:specify` (and downstream `orchestrator:evaluate` / `orchestrator:roadmap`) when each milestone enters the planning queue. They are *not* themselves specs — they are briefs intended to give specify enough context to produce a tight spec without re-doing the analysis.

## Proposals

| ID | Title | Shape | Standalone? |
|---|---|---|---|
| `constitution-amendment-inclusion-criteria.md` | Inclusion-criteria gate + governance log + distribution-surface integrity | Constitution PR (~50 LOC + 1 new doc) | Yes — no milestone needed |
| `M028-autonomous-hardening-v3.md` | Hook portability + 4 new shape classes + investigation-pattern wrappers | Milestone (5 phases) or 2 quick PRs | Some phases standalone |
| `M029-roadmap-visibility-and-cli-ux.md` | `orchestrator:where` tree + invocation-context resolver + headline status (embeds M027 surfaces) | Milestone (3 phases) | No — coherent feature |
| `M030-adaptive-model-selection.md` | Task-character classifier + model routing table + verifier-fail escalation; surface savings via M027 | Milestone (4 phases) or 2-3 quick PRs depending on classifier complexity | Yes — independent feature |
| `M031-right-sized-entry.md` | Knowledge + compression unconditional across all intensities; Tier A+ middle flow (research → plan → build); universal `orchestrator <task>` entry; evaluate.md drift reconciliation | Milestone (4 phases + optional P00 baseline) | No — coherent feature |

## Reality check vs CLAUDE.md (2026-04-28)

`CLAUDE.md`'s "Forward Roadmap" paragraph is stale. Authoritative source is `.orchestrator/milestone-summary.md`. Several milestones listed there as "next up" or "in queue" are actually closed:

| Milestone | CLAUDE.md said | Actually |
|---|---|---|
| M014 (extended) | "next up" | Closed 2026-04-25 |
| M020 | in forward queue | Closed 2026-04-25 |
| M024 | in forward queue | Closed |
| M019 Tier 2+3 | in forward queue | Closed |
| M026 (in CLAUDE.md not yet listed) | — | Closed 2026-04-25 (Conversus-OSS Migration) |
| M027 (in CLAUDE.md not yet listed) | — | Closed 2026-04-27 (Cost+Quality Observability Surfaces) |

A separate small PR should refresh `CLAUDE.md` from `milestone-summary.md` to prevent future drift confusion. Out of scope for these proposal commits.

## Sequencing recommendation

Forward queue, after the staleness correction:

```
[constitution-amendment]    ← any time, single PR, no dependencies
M018  ← currently active (Context Compression Layer)
M028 (autonomous hardening v3)        ← INSERT — stabilizes autonomous runs
M030 (adaptive model selection)       ← INSERT — makes runs cheaper
M031 (right-sized entry)              ← INSERT — restores knowledge promise + tightens UX
M023 (design layer)
M029 (roadmap visibility + CLI UX)    ← INSERT — launch polish
M009 (extended)
M010 (adjusted)
```

### Why M028 first (after M018 finishes)

The 7 auto-interruption screenshots from 2026-04-25/26 reveal the M021 shape guard fails-open in *consumer* projects (script path resolved via `$CLAUDE_PROJECT_DIR` lands outside the orchestrator repo). Any future autonomous-run-heavy milestone (M030's shadow mode, M023's design-agent dispatching, M009's runtime-parity audit) re-incurs the same prompt interruptions M021 already classified. Hook portability is the load-bearing fix.

### Why M030 right after M028

M030 (adaptive model selection) needs M027's cost+quality observability for empirical validation — and M027 is already shipped. M030's shadow-mode validation phase needs autonomous runs to be uninterrupted (M028). Land M028 → land M030 → reap accumulated savings on every subsequent milestone (M023 design dispatching, M009 audits, M010 Managed Agents). Earlier M030 ships, more compounding savings.

### Why M031 right after M030

M031 closes a load-bearing gap — Quick intensity today skips the knowledge graph entirely (`commands/dispatch.md:21`), violating the orchestrator's core promise that every dispatch runs on knowledge-rich context. The smaller the task, the more the knowledge layer should bite, and today it's exactly inverted. M031 also adds a Tier A+ middle flow (research → plan → build, no ceremony) and a universal `orchestrator <task>` entry that lowers adoption friction for users with small tasks.

M031 composes with M030: M030 routes the dispatching agent to a cheap model; M031 ensures that cheap agent has knowledge access. Together they're the thrift-and-ergonomics pair — small tasks become both fast/cheap *and* knowledge-rich. Constitution amendment Change 5 (clarification of Principle I) lands with M031 to prevent re-derivation of the wrong "skip-to-save-tokens" logic in future work.

Earlier M031 ships, sooner adoption barrier drops. Best for launch.

### Why M029 between M023 and M009

M029 is launch-polish — `orchestrator:where` and the headline status block. It composes existing M027 cost surfaces into the work-hierarchy tree (no new infrastructure, just new rendering). It wants to ship *with* the launch experience, not before. M023 produces design contracts; M029 makes the runtime visible; M009 audits parity. Natural order.

### Why constitution amendment any time

Doc-only, self-contained. The inclusion-criteria gate is forward-only (grandfathers I-XV). Cheapest, earliest land. No dependencies.

## Active-milestone safety note

M018 (Context Compression Layer) is currently executing under `orchestrator:auto` on branch `feat/m018-context-compression` (lock held). These proposal docs are isolated under `.orchestrator/proposals/` and do not touch:
- `.orchestrator/milestones/M018/**`
- `.orchestrator/orchestrator.lock`
- `.orchestrator/execution-log.jsonl`
- `knowledge/**` (M018 consolidation pass is rewriting these)
- Any file currently `M` in `git status`

The proposals can be committed at any time without affecting M018's autonomous run.

## Source material

- Session transcripts: 2026-04-27 (initial capture), 2026-04-28 (renumber + M030 add)
- Conversus reference: `~/Sites/conversus-oss` (CONSTITUTION.md, engine/cli/, docs/user-guide/)
- Auto-interruption screenshots: 7 screenshots dated 2026-04-25 to 2026-04-26 — patterns extracted into `M028-autonomous-hardening-v3.md` §3
- Existing infrastructure to extend:
  - M021 corpus (`tests/fixtures/m021-prompt-corpus.txt`), classifier (`scripts/verify/lib/shape-classifier.sh`), hook (`scripts/hooks/pre-bash-shape-guard.sh`), antipattern register (`ANTIPATTERNS.md` AP-001 through AP-009) — for M028
  - M027 cost surfaces (`scripts/diagnostics/efficiency-footer.sh`, `metrics-rollup.sh`, `scripts/dispatch/predictive-surface.sh`, `check-anomalies.sh`) — for M029 + M030
  - M013 GitHub sidecar (`.orchestrator/integrations/github.json`) — for M029
  - M019 Tier 1+2+3 JSONL emitters — for M030's routing decisions and M029's tree column
  - M020 knowledge layer (graph schema, indexer, traversal) — for M031's `--profile=quick` traversal contract
  - M024 intake (`scripts/intake/`, `commands/evaluate.md` input-shape table) — for M031's Tier A+ classifier extension and `orchestrator:do` routing
