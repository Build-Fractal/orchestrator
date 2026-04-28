# Proposal: M031 — Right-Sized Entry

**Captured**: 2026-04-28
**Shape**: Milestone (4 phases), one of which is doc reconciliation
**Source**: User direction — "the orchestrator should work for any size task; small tasks should still get knowledge + compression; entry should be one quick command, not a ceremony"

## Goal

Restore a load-bearing promise of the orchestrator that quietly leaks at exactly the size where it matters most: **every task, regardless of size, runs on the orchestrator's knowledge graph + compression pipeline**. Plus reshape the entry experience so a user with a one-line bug-fix can invoke the orchestrator with the same low friction as `git commit` — and get the full benefit of the project's accumulated knowledge.

## Why this is load-bearing, not polish

The orchestrator's value proposition is *agents always run on fresh, knowledge-rich context, efficiently*. The graph-searchable knowledge layer is the core delivery mechanism for that promise. Any execution path that bypasses the graph violates the promise.

Today's `commands/dispatch.md:21` for Quick intensity:

> **Quick** | sequential | Skip payload assembly (`build-context.sh`). Invoke `dispatch-interface.sh` with a minimal payload containing only the task plan.

This skips the knowledge graph "to save tokens." That logic is backwards. Knowledge graph access *is* the compression mechanism — a scope-filtered MEM lookup ships ~500-2000 tokens of high-leverage context. The alternative (agent rediscovering via grep/read) typically burns 5-15k tokens of exploration plus quality regression. Skipping knowledge to save payload bytes ends up costing more total task tokens, not fewer.

The constitutional read: **Principle I (Context Minimization)** means *minimize total task tokens via efficient context delivery*, not *minimize payload bytes by sending less*. **Principle VII (Knowledge Compounds)** explicitly requires that the knowledge layer benefit every dispatch. The pre-M031 Quick implementation conflated payload minimization with task minimization and broke VII for marginal compliance with a misread of I.

The relative impact is highest at the small end. A Tier C run amortizes exploration cost across many dispatches; a Tier A user fixing a one-line bug pays the full cost of "no knowledge" against a small task budget. The smaller the task, the more the orchestrator's knowledge promise should bite — and today it's exactly inverted.

## Strict scope

This is **flow shape + entry UX**, not:
- Knowledge layer redesign (graph schema, indexer, traversal logic) — that's M020's territory and is closed
- Cost surface redesign — M027 already shipped
- Model selection — M030's job
- Auto-loop hardening — M028's job

M031 asks: *does every dispatch path get knowledge + compression, and is the entry experience appropriately small for small tasks?*

## Findings

### F1. Quick intensity skips the knowledge pipeline

**Current**: `commands/dispatch.md:21` — Quick mode skips `build-context.sh`. Standard (line 22) and Full (line 23) inject knowledge.

**Fix**: knowledge + compression are unconditional. What scales with intensity is *traversal aggressiveness*, not *whether knowledge ships*:

| Intensity | Knowledge scope | Traversal | Decisions | Compression |
|---|---|---|---|---|
| **Quick** | Touched files only | 1-hop direct hits | Excluded by default | M018 tier-1 + tier-2 |
| **Standard** | Phase scope | 2-hop graph traversal | Phase-relevant included | M018 tier-1 + tier-2 |
| **Full** | Milestone + dependencies | Full provenance chain | All milestone + cross-refs | M018 tier-1 + tier-2 |

Implementation: `build-context.sh` gains `--profile=quick|standard|full` flag. Quick profile sets `--scope=touched-files-only --traversal=1-hop --no-decisions`. The "skip" branch in dispatch.md is removed entirely.

Token economics: a Quick-profile knowledge inject is typically ~800 tokens (1-hop graph hits, scope-filtered, compressed). The agent saves the 5-15k of exploration tokens it would otherwise burn, and ships higher-quality output that's less likely to need re-dispatch.

### F2. No middle flow — Tier A is one dispatch, Tier B is full SDD

**Current**: nothing between "single dispatch" and "full SDD with roadmap, phases, auto loop, consolidate."

**Fix**: introduce a **Tier A+ middle flow** — three single-context dispatches in sequence:
- **research** — agent reads codebase + knowledge graph, produces a tight findings doc (no PLAN.md)
- **plan** — agent reads research + knowledge, produces a single PLAN.md with explicit steps + verifiers
- **build** — agent reads plan + knowledge, executes; verifiers run inline

No roadmap, no phase decomposition, no auto loop, no consolidate, no lock. Each dispatch gets full knowledge + compression per F1. Composes with M030 model routing (likely defaults all three to Sonnet/Haiku — surgical-character tasks).

Triggered by:
- M024 input-shape classifier emitting `tier_a_plus` for medium-complexity inputs (currently routed to either Tier A single-shot or Tier B full ceremony)
- Operator override `--tier=A+` on `orchestrator:evaluate`

### F3. Entry UX: too many commands, too much choice for small tasks

**Current** entry surface (a new user faces all of these):
- `orchestrator:evaluate` (canonical entry per CLAUDE.md SDD workflow)
- `orchestrator:specify` (M014-extended spec authoring)
- `orchestrator:dispatch` (single task)
- `orchestrator:auto` (autonomous full flow)
- `orchestrator:status`, `orchestrator:doctor`, `orchestrator:cost`, `orchestrator:resume`, `orchestrator:where` (proposed M029)…

For someone who just wants to fix a one-line bug, the choice paralysis is real. Even M024's degenerate fast-path requires the user to know it exists and to have `auto_proceed: true` in config.

**Fix**: a single universal entry — `orchestrator <task>` (or `orchestrator:do <task>`) — that:
1. Auto-routes via `evaluate`'s classifier (already exists from M024)
2. For Tier A degenerate fast-path: dispatches immediately with full knowledge access (per F1) and a one-line "doing X — knowledge from N MEMs" stderr message. No approval prompt.
3. For Tier A+ middle flow: chains research → plan → build with one approval prompt before plan (so user can sanity-check direction) and zero between plan and build.
4. For Tier B/C: routes to `specify` / full SDD as today.
5. Confidence-gated: low-confidence classifications still ask "is this Tier A or Tier B?" — never silently picks the wrong shape.

Result: small-task entry is one command, one keystroke, full knowledge access. The user doesn't have to know about `evaluate` vs `dispatch` vs `auto` for the small case.

### F4. evaluate.md internal drift

**Current**: `commands/evaluate.md` has two contradicting Tier A definitions:
- Lines 18 (post-M024 input-shape table): "Tier A → orchestrator:dispatch"
- Lines 101-140 (pre-M024 Tier A Result section): "**No orchestrator overhead — route directly to standard spec-kit commands**" and "Do NOT create any orchestrator directory structure"

M024 closed but didn't reconcile the older section. New users reading the doc top-to-bottom get whiplash.

**Fix**: drop the pre-M024 "route to standard spec-kit" section entirely. Tier A always uses `orchestrator:dispatch` with knowledge + compression per F1. Update FR-003 reference (no orchestrator dir for Tier A) to clarify it means *no `.orchestrator/milestones/M###/` scaffolding* — `.orchestrator/` itself (config, knowledge, integrations) is always present.

## Phase shape

| Phase | Goal | Key artifact | Verifies |
|---|---|---|---|
| P01 | Knowledge + compression unconditional across intensities | `build-context.sh --profile=quick\|standard\|full`. Strip the skip branch in `dispatch.md`. M018 compression always applies. Quick-profile traversal contract documented. | Empirical: a fixture Quick-task runs through the pipeline and gets ~800 tokens of knowledge injection. M018 tier-1/tier-2 stats appear in JSONL for Quick. |
| P02 | Tier A+ middle flow | Three new dispatch shapes: `dispatch --role=research`, `dispatch --role=plan`, `dispatch --role=build`. M024 classifier extension to emit `tier_a_plus`. Templates for each role's payload. | Fixture: a 30-word feature request routes to Tier A+, completes through three dispatches, no roadmap/auto/consolidate triggered. |
| P03 | Universal entry experience | New `orchestrator:do <task>` skill (or rename `evaluate` to `do` — pick during specify). Confidence-gated routing. Degenerate fast-path enabled by default for trivial Tier A inputs (no config knob required). | Fixture: `orchestrator:do "fix typo in foo.md"` completes end-to-end with one stderr line + final diff. Zero prompts. |
| P04 | evaluate.md reconciliation + verifiers + summary | Drop pre-M024 Tier A section in `commands/evaluate.md`. Update `references/tier-definitions.md` to match. Replace `auto_proceed` config knob default to `true` (was `false`). Verifier suite + summary. | All P01-P03 verifiers pass. Doc-drift verifier confirms no contradicting Tier A definitions remain. |

## Empirical baseline

Before flipping anything in P01, capture a baseline: run a 20-task fixture corpus through current Quick (no knowledge) vs proposed Quick (with `--profile=quick` knowledge). Compare:
- Total tokens per task
- Verifier pass rate
- Re-dispatch rate

Hypothesis: proposed Quick uses ~30-50% fewer total tokens *and* has higher pass rate. If empirical data contradicts, M031 P01 needs redesign before shipping. This validation phase can be P00 if needed.

## Dependencies & sequencing

**Requires (all shipped or active)**: M020 (knowledge layer maturation), M027 (cost+quality observability — for empirical validation), M018 (active — compression must be in place when M031 ships).

**Plays beautifully with**:
- **M030 (adaptive model selection)** — Tier A+ middle flow defaults all three roles to Sonnet/Haiku via M030's routing. M031 + M030 = the cheapest, fastest path the orchestrator can offer.
- **M029 (roadmap visibility)** — `orchestrator:where` should render Tier A+ flows as 3-row mini-trees so users can see research/plan/build progress.

**Independent of**: M028 (auto hardening), M023 (design layer), M009, M010.

**Slot recommendation** (per `.orchestrator/proposals/README.md`): immediately after M030. M030 makes individual dispatches cheap; M031 ensures they're knowledge-rich and ergonomically invokable. M030 + M031 ship as a thrift-and-ergonomics pair.

## Out of scope

- Wiki/GitHub knowledge sync redesign — orthogonal; existing M012/M013 paths remain
- A "no-orchestrator-state" mode — `.orchestrator/` is always present (config, knowledge, integrations); only milestone scaffolding is conditional
- Auto-tuning of intensity from past task data — premature; ship static heuristics first
- A long-running interactive shell — the orchestrator stays one-shot per command

## Open questions for `orchestrator:specify`

1. **Quick-profile knowledge budget**: target 800 tokens? 1500? Empirical baseline (P00) sets the number; ship a default, make it configurable via `quick_knowledge_token_budget` knob.
2. **Naming**: `orchestrator:do <task>` vs renaming `orchestrator:evaluate` to `orchestrator:do` vs `orchestrator <task>` (no subcommand). User-facing UX decision; recommendation: `orchestrator <task>` if runtime supports verbless invocation; `orchestrator:do <task>` otherwise.
3. **Tier A+ approval flow**: one prompt before plan? Or zero prompts (pure auto)? Recommendation: one prompt, with `--yes` flag to skip — matches user intuition that medium tasks deserve a sanity check, small tasks don't.
4. **`auto_proceed` default flip**: today defaults `false`; M031 P04 flips to `true`. Backwards-compat concern? Existing projects' `.orchestrator/config.yml` files might not have the key — `read-config.sh` returns empty, and the new fast-path default kicks in. Probably fine; flag explicitly in CHANGELOG.
5. **Role-specific templates for Tier A+**: how prescriptive are the research/plan/build payloads? Recommendation: very prescriptive — each role gets a tight template that says "produce N findings / steps / verifications," no exploration. Tier A+ is for surgical work; ceremony belongs in Tier B.

## Source evidence (file paths)

- `commands/dispatch.md:21-23` (the broken Quick branch)
- `commands/evaluate.md:14-23, 101-140` (M024 + pre-M024 drift)
- `scripts/dispatch/build-context.sh` (gains `--profile` flag)
- `scripts/intake/route-to-dispatch.sh` (M024 — extends to handle `tier_a_plus`)
- `scripts/intake/paragraph-classify.sh` (M024 — extends classifier output)
- `scripts/intake/shape-detect.sh` (M024 — surfaces `tier_a_plus` shape)
- `templates/orchestrator-config-default.yml` (`auto_proceed` default flip; new `quick_knowledge_token_budget` knob)
- Existing M018 compression — `_bc_apply_tier1` and `_bc_apply_tier2` in `build-context.sh` — must run on Quick-profile payloads (currently irrelevant because Quick skips build-context entirely; this becomes relevant after P01)
