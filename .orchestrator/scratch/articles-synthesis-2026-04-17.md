# Articles → Orchestrator Synthesis (scratch)

Date: 2026-04-17
Articles parsed: (A1) Anthropic — "Using Opus 4.7 in Claude Code"; (A2) Shann — "AI Knowledge Layer"; (A3) Rohit — "Claude Code Harness Teardown"

Purpose: identify cross-article signals; map each to existing orchestrator code, planned milestones, or new-milestone candidates. Conservative bias per Constitution XIV (no speculative complexity) and XV (surgical precision).

---

## Per-article extraction (compact)

### A1 — Opus 4.7 in Claude Code
- Default effort is now `xhigh`; toggle between levels mid-task.
- Extended thinking with fixed budget is **gone**; replaced by adaptive thinking (model decides per step). You can nudge up/down via prompt text.
- Opus 4.7 behavioral deltas vs 4.6: shorter default responses, fewer tool calls, fewer subagents, reasons more after each user turn.
- Treat Claude like a senior engineer you delegate to: front-load intent, constraints, acceptance criteria, file locations in the **first** turn. Every user turn adds reasoning overhead.
- Parallel subagents must be spelled out explicitly now ("spawn multiple subagents in the same turn when fanning out").
- Prefer positive examples over "don't do X" in prompts.

### A2 — AI Knowledge Layer (LLM Wikid)
- Two-layer architecture: **KBL** (dynamic, agent-maintained, wiki pages with cross-links + master index with TLDRs) + **BF** (static, human-only, voice/rules/positioning).
- Compile-once beats RAG past ~100 sources. Graphify reports 71.5× fewer tokens/query vs raw-file search.
- Raw inbox → classified sources → cross-referenced wiki pages → append-only log. Every query answer is **filed back** as a new page; next query is richer.
- Quality controls: `explored: false` validation gate on every generated page; confidence levels (high/medium/low/uncertain); bias check forcing counter-arguments + data gaps.
- Scheduled ingest (cron/Claude Dispatch) runs overnight; clippings become wiki pages by morning.
- Scales from personal → team (shared brain) → org (role-tuned agents sharing one central wiki).

### A3 — Claude Code Harness Teardown
Four-layer framing: weights / context / **harness** / **infrastructure**. Layer 4 is where most products die.

Concrete patterns:
- **Async-generator agent loop**, not while-loop. Five phases per iteration: setup → invoke → error recover → tool exec → continuation decision. Error recovery is a first-class state, not an outer try/catch.
- **Concurrency classification per tool**: read-only parallel, mutating serial. 2–5× turn speedup with zero races.
- **Streaming tool executor**: start tool call the instant its input JSON is complete, not after full model response.
- **Tool result budgeting**: large results persist to disk; model sees `file_path + preview`. Applied before each API call.
- **System prompt cache boundary**: static content (≈80%) above, volatile below. Context injected as first **user** message with `<system-reminder>` wrapper to keep system cache stable.
- **CLAUDE.md hierarchy**: enterprise → project → user → local, with `@include` composition.
- **Four compaction strategies** ordered cheapest→expensive: microcompact (tool-result cache ref) → snip (drop head, protect tail) → auto-compact (summarize) → context collapse (staged multi-phase).
- **Seven-stage permission pipeline**; rules use glob-like patterns; modes create progressive trust; hooks are the escape hatch.
- **823-line retry system** with per-error-class recovery: 429, 529, 400-context-overflow, 401/403, network errors each have specific strategies. Streaming layer runs idle-timeout watchdog + stall detection + streaming→non-streaming fallback.
- **Sub-agent isolation**: git worktrees per agent, `siblingAbortController` so one tool failure doesn't cascade, symlinked `node_modules` to prevent disk bloat.
- **Disk-backed task list with file locks** + high-water-mark for ID reuse prevention.
- **Four extension mechanisms** (skills, hooks, MCP, plugins) — all composition-over-modification.

---

## Cross-article convergence (strongest signals)

**C1. Compile-once knowledge over retrieve-on-query.**
A2 wiki vs RAG. A3 CLAUDE.md hierarchy as composable memory, system-prompt cache boundary. A1 Opus 4.7 "carries context across sessions more reliably" + "specify task up front."
→ Invest in pre-compiled context over lookup-time retrieval.

**C2. Tiered compaction.**
A3 four-tier compaction (microcompact→snip→auto→collapse). A2 wiki itself is a compaction of raw/. A1 adaptive thinking is compute-side compaction.
→ Compression is a hierarchy, not a flag. Cheapest strategy runs first; expensive only when cheap fails.

**C3. Validation / trust gates with confidence metadata.**
A2 `explored: false` + confidence levels + bias checks. A3 seven-stage permission pipeline + progressive trust modes. A1 auto-mode spectrum, not binary.
→ Trust is a gradient, tracked per artifact.

**C4. Long-running agent survival needs error-recovery as first-class state.**
A1 4.7 designed for supervision-less long runs. A3 823-line per-error retry state machine + streaming watchdogs. A2 overnight ingest = autonomous multi-hour session.
→ Retry logic is state-machine work, not try/catch.

**C5. First-turn payload completeness.**
A1 explicit: intent+constraints+acceptance+file-locations in turn 1. A3 system prompt designed for cache+caller-completeness. A2 BF gives agents the static anchor every run.
→ Front-loading context is the cheapest quality lever.

**C6. Parallel fan-out with isolation.**
A1 "spawn multiple subagents for fan-out — spell it out." A3 git worktree isolation + concurrency classification + `siblingAbortController`. A2 role-tuned agents reading from shared brain.
→ Parallelism needs explicit design; safety via isolation, not coordination.

**C7. Big artifacts → disk, pass references.**
A3 tool-result budgeting (`file_path + preview`). A2 wiki `sources/` folder (summaries, not raw). Implicit in A1's terser defaults.
→ Context window is expensive; files are cheap.

---

## Mapping to orchestrator

The orchestrator already embodies several of these patterns. This section separates **validated-existing** (patterns we can cite as evidence the architecture is sound), **layer-ins** (small, targeted edits to existing code/plans), **milestone enrichments** (concrete additions to M019/M018/M010/M009 scope), and **new-milestone candidates** (only when scope justifies it).

### Validated-existing (don't re-litigate, but reference)
- Constitution VI "State On Disk Is Truth" ↔ A3 disk-backed task list + file locks.
- Principle IV "Plans Assume Zero Context" ↔ A1 front-loaded task spec, A3 cache-stable system prompt.
- Principle V "Fresh Context Per Unit" ↔ A3 sub-agent isolation, A1 subagent guidance.
- MEM007 Autonomy Permission Pipeline ↔ A3 seven-stage permission pipeline.
- Git worktree isolation (FR-075, already shipped) ↔ A3 worktree pattern.
- Confidence-scored `KNOWLEDGE-INDEX.md` with MEM IDs + scope tags + hit counts ↔ A2 master index with TLDRs.
- Three-Temperature Knowledge Architecture (MEM019) ↔ A2 KBL + BF split (constitution = BF; knowledge/ = KBL).
- Intensity gate (Quick/Standard/Full) ↔ A1 effort-level toggling (medium/high/xhigh/max).

These aren't action items — they're evidence the architecture has been tracking these ideas.

### Layer-ins (small, do-now-or-soon)

| # | Change | Touchpoint | Source | Est |
|---|--------|-----------|--------|-----|
| L1 | Audit dispatch payloads for first-turn completeness: intent, constraints, acceptance criteria, file paths, fan-out directives if parallel. | `scripts/dispatch/build-context.sh`, `templates/dispatch-prompt.md` | A1, A3, C5 | S |
| L2 | Restructure dispatch payload for cache boundary: stable sections (constitution excerpt, phase truths, conventions) first, volatile (task-specific state, current git status) last. Explicit `<system-reminder>`-style wrapper for volatile block. | `build-context.sh`, `templates/context-recipe.yaml` | A3, C1 | S |
| L3 | Replace fixed thinking hints with adaptive-thinking nudges in templates ("Think carefully — this problem is harder than it looks" vs "Prioritize responding quickly"). Remove any `thinking_budget` references that assume fixed budget. | `templates/*.md`, `scripts/engine/intensity-gate.sh` | A1 | S |
| L4 | Add explicit "spawn subagents in parallel when fanning out across independent files/tasks" directive to dispatch payloads that can parallelize (Opus 4.7 spawns fewer by default). | `templates/dispatch-prompt.md` | A1, C6 | S |
| L5 | Convert any "don't do X" instructions in templates/commands to positive examples of desired behavior. | sweep `templates/`, `commands/` | A1 | S |
| L6 | Tool-result budgeting for `build-context.sh`: when a section exceeds N chars, persist the full artifact under `.orchestrator/scratch/payload-assets/<dispatch-id>/` and replace in-payload with `path + first-N-chars preview`. | `build-context.sh`, new `scripts/dispatch/lib/budget.sh` | A3, C7 | M |
| L7 | Add wikilink-style cross-refs between MEM entries (`[[MEM007]]`) so the knowledge index graph becomes traversable. `rebuild-index.sh` already computes hits; extend to emit back-references. | `scripts/knowledge/rebuild-index.sh`, `knowledge/**/MEM*.md` | A2 | M |
| L8 | Add `explored:` / `verified:` + confidence to auto-generated knowledge entries (humans mark reviewed); surface unreviewed entries in `orchestrator-doctor`. Currently `verified:date` exists but there's no explicit "unreviewed" state distinct from "recently generated." | `scripts/knowledge/create-entry.sh`, `scripts/diagnostics/doctor.sh` | A2, C3 | M |

### Milestone enrichments

**M019 Tier 1 emitter (next up):**
- Pair token cost with *quality metric* — already planned per D009, but A3's emphasis on multi-error-class retry motivates adding `retry_count_by_class` (rate-limit / context-overflow / network / other) to each `dispatch_usage` record so retry storms are visible in rollup.
- Add `payload_cache_boundary_hit_ratio` if feasible (from Claude Code session-end usage data) — directly measures C1 leverage.
- Emit `artifact_size_bytes` + `persisted_to_disk: bool` on each dispatch to measure L6's impact.

**M018 Context Compression Layer (sketch → plan):**
- Adopt A3's four-tier compaction as the **compression hierarchy**, not a single "caveman" knob:
  - Tier 1 microcompact = reuse existing tool-call results that haven't changed (free).
  - Tier 2 snip = head-drop with protected tail (no LLM call).
  - Tier 3 auto-compact = summarize (existing caveman-style).
  - Tier 4 collapse = staged (tool results first, then reasoning, then sections).
- This reshapes M018's phase outline: P01 grammar stays, P02 becomes "implement tier ladder" rather than "optional filter," P03 intensity mapping becomes "choose highest tier per intensity" rather than "on/off." Stronger answer than single-mode compression.
- Fold L6 (tool-result budgeting) into M018/P01 scope — it's the cheapest compaction tier.

**M010 Cloud Dispatch:**
- Retry state-machine (A3 §823-line) is a hard dependency for unsupervised multi-hour parallel runs, not a nice-to-have. Bake in from M010/P01 rather than retrofitting.
- Streaming watchdog + idle-timeout + stall detection patterns become concrete design requirements.
- Seven-stage permission pipeline generalizes MEM007 for multi-tenant scenarios; relevant if M010 ever supports team deployments. Probably a later phase.

**M012 Spec Wiki (MkDocs + Giscus):**
- A2's validation gate (`explored: false`) maps directly to wiki review state. Generated pages start unreviewed; human promotes to reviewed. MkDocs can render state via frontmatter.
- A2's master-index-with-TLDRs pattern: ensure the wiki generator produces a scannable top-level index, not just a generated sidebar.

**M009 Launch:**
- A3 reframes "harness" as cheaper-than-model advantage (Princeton SWE-agent 64% from interface alone). M009 launch narrative can lean on this: orchestrator is layer-3/4 investment, not another prompt library. Measured receipts from M019 close the loop ("M011 shipped in X phases, $Y spend, Z% first-try pass").

### New-milestone candidates

I only see one plausible candidate; the rest are layer-ins or enrichments.

**M020 (candidate) — Knowledge Wiki Layer.**
Promote `knowledge/` from scoped-MEM-registry to queryable cross-linked wiki with bias checks, confidence promotion workflow, and a `/wiki-query` command that files answers back as new entries.
- Scope signals: L7 + L8 + query command + doctor integration.
- Gate on M012 dogfooding: if M012's MkDocs wiki + Giscus comment loop already provides "queryable cross-linked knowledge" for stakeholder-facing spec artifacts, a separate internal wiki for engineer knowledge may be redundant — just extend M012's patterns internally.
- Recommendation: **defer naming/committing until after M012 P01-P02**. If knowledge/ tooling still feels like "flat indexed files" after M012 lands, promote. Otherwise fold improvements into knowledge-tooling maintenance.

Other candidates considered and **rejected**:
- "Opus 4.7 adaptation milestone" — all the deltas are layer-ins (L1–L5). A milestone here would be speculative bundling. Do as a single PR sweep.
- "Permissions 2.0 (seven-stage)" — MEM007 already codifies the pipeline at orchestrator's scale. Upgrade inside M010 if team/multi-tenant emerges.
- "Streaming agent loop" — bash + single-shot subagent dispatch is architecturally different. The async-generator benefits (backpressure, streaming cancel) don't translate. Not worth a port.

---

## Suggested next actions

Ordered by leverage/effort ratio:

1. **Do L1–L5 as a single PR** (template + payload sweep for Opus 4.7 adaptation). Small, high value, affects every future dispatch. Probably 1 session. **Ship before M019/Tier 1** so measured dispatches post-fix are the baseline.
2. **Fold L6 (tool-result budgeting) into M018 planning** — add it to the sketch/plan now so P01 grammar covers it.
3. **Reshape M018 sketch** to four-tier compaction model per above. Update `DECISIONS.md` D008 phase outline.
4. **Add retry-class metrics to M019 Tier 1 schema** before it ships (cheap to add up front, expensive to retrofit once logs accumulate).
5. **Defer M020 knowledge-wiki decision** to post-M012/P02.
6. **L7 + L8 (knowledge-layer cross-refs + review state)** as a standalone small PR when M019 Tier 1 is in flight; low risk of conflict.

Open questions for user:
- Should "Opus 4.7 adaptation sweep" (L1–L5) be inserted as M019/P00 or shipped as loose maintenance PR before M019 kickoff? Argument for M019/P00: it affects the token-cost baseline Tier 1 will record. Argument for maintenance PR: small enough not to warrant milestone scaffolding.
- M018 reshape significant enough to re-run `orchestrator:discuss`, or just amend D008 in place?

---

## Addendum — Agentic-Stack (codejunkie99/agentic-stack)

Added 2026-04-17. Repo: `.agent/` portable brain (memory + skills + protocols), 7-harness adapters, candidate-review workflow.

### Key patterns observed

- **Four-layer memory with distinct retention**: `working/` (volatile, 2-day), `episodic/` (JSONL, salience-scored), `semantic/` (distilled), `personal/` (user prefs).
- **"Harness is dumb, knowledge is in files"** — portable `.agent/` folder plugs into any runtime via a thin adapter.
- **Progressive-disclosure skills**: `_index.md` + `_manifest.jsonl` always in context (small); full `SKILL.md` loads only when triggers match.
- **Candidate → graduate workflow**: `auto_dream.py` mechanically stages candidates (cluster + prefilter + decay); host agent reviews via `graduate.py` / `reject.py` / `reopen.py` with **required `--rationale`** (structurally blocks rubber-stamping).
- **Structured `lessons.jsonl` as source of truth**; `LESSONS.md` re-rendered from it. Hand-curated content above a sentinel preserved.
- **Review queue surfaced at session start** (`REVIEW_QUEUE.md`); `AGENTS.md` tells the agent what to read in what order.
- **`on_failure.py`**: flags skills that fail 3+ times in 14 days for rewrite.
- **Content clustering**: single-linkage Jaccard with bridge merging; pattern IDs stable across cluster-membership changes.
- **Onboarding wizard** writes `PREFERENCES.md` (6 questions: name, languages, explanation style, test strategy, commit style, review depth).
- **Permissions protocol**: allow / approval-required / never-allowed, enforced by pre-tool-call hook.
- **Self-rewrite hook at the bottom of every skill.**

### Mapping to orchestrator (validated vs adopt vs reject)

**Already present (don't re-litigate):**
- Multi-runtime packaging → orchestrator has 3-runtime packaging (Claude Code / Codex / Cursor) with `packaging/install/install-<runtime>.sh`.
- "Harness is dumb, knowledge is in files" → Constitution VI "State On Disk Is Truth."
- Permissions enforcement → `.claude/settings.json` + M016 anti-pattern linter + MEM007 permission pipeline.
- Layered memory → MEM019 Three-Temperature Knowledge Architecture covers the same territory (hot/warm/cold vs working/episodic/semantic/personal). Different naming, same pattern.
- Structured knowledge with confidence → `KNOWLEDGE-INDEX.md` has MEM IDs, scope tags, confidence, verified dates, hits.

**Genuine gaps worth adopting:**

| # | Pattern | Orchestrator gap | Effort | Priority |
|---|---------|-----------------|--------|----------|
| A1 | Personal-preference layer (`PREFERENCES.md`) + onboarding wizard | `orchestrator:init` captures project shape but no user-personal prefs (explanation style, commit style, test strategy, review depth). Would survive across sessions/projects via `~/.orchestrator/preferences.md` or similar. | S | Med |
| A2 | Candidate → graduate workflow with **required rationale** | `orchestrator:consolidate` generates knowledge entries but has no "candidate → reviewed" gate. Entries land directly. Adding a staging layer + explicit promote-with-rationale prevents rubber-stamping and makes "what changed my mind" legible. Fits with L8 (explored state) from main synthesis. | M | High |
| A3 | Review queue surfaced in `orchestrator:status` | Status is currently pure progress. Adding "N candidates pending review, oldest X days" surface closes the consolidate→review loop at session start. | S | Med |
| A4 | `AGENTS.md`-style read-order map | Orchestrator's `CLAUDE.md` is instructions, but there's no explicit "read these files in this order at session start" manifest that travels with runtime-neutral adapters. Useful for Codex/Cursor where runtime doesn't auto-load as aggressively as Claude Code. | S | Med |
| A5 | `on_failure` flagging from execution-log | After M019 Tier 1 ships `execution-log.jsonl` with retry-class data, a simple "script/template that failed ≥3 times in N dispatches → flag for rewrite" helper becomes feasible. Hard dependency on M019 data. | M | Med (post-M019) |
| A6 | Jaccard clustering in consolidate | `consolidate-artifacts.sh` already compresses; adding proper clustering (single-linkage Jaccard) for pattern detection would improve quality of auto-generated KNOWLEDGE.md at milestone close. Refinement, not rewrite. | M | Low |

**Reject as adoption (more cost than value):**

- **Nightly `auto_dream` cycle.** Orchestrator's consolidation unit is the milestone boundary (Constitution VII). A nightly cron cycle introduces a competing unit-of-work rhythm. Milestone-boundary consolidation is more aligned with orchestrator's model. Skip the cron, keep the clustering (see A6).
- **JSONL-as-truth, `.md` rendered (for MEM files).** Orchestrator's MEM files are authored as `.md` directly with frontmatter, and `KNOWLEDGE-INDEX.md` already provides the queryable layer. Re-architecting to JSONL-source-of-truth would be invasive with marginal gain at orchestrator's scale (~30 entries, not 3000).
- **FTS5 memory search.** Overkill at current knowledge-base size. Orchestrator already has `rebuild-index.sh` + `scripts/knowledge/lib/`. If `knowledge/` ever exceeds ~200 entries, revisit.
- **Progressive-disclosure skill manifest (`_manifest.jsonl`).** This is the exact pattern Claude Code's own harness implements (per Article 3: "path-based discovery means a skill specifying paths activates when the agent touches matching files"). Re-implementing inside orchestrator would duplicate Claude Code's loader. Rely on runtime-native skill discovery; add explicit trigger metadata only if Codex/Cursor adapters show a gap.

### Key tension with orchestrator's design

Agentic-stack's candidate-review workflow assumes an **interactive REPL** where the host agent makes decisions in-session. Orchestrator's `orchestrator:auto` mode explicitly targets zero prompts (M016 autonomous hardening). Grafting the candidate-review workflow onto `auto` mode would require:

- Candidates accumulate silently during `auto` runs.
- Review happens at consolidate time or in an interactive `orchestrator:review-candidates` command — never mid-run.
- `auto` mode's success criteria should include "candidates staged, not promoted" so autonomous runs don't rubber-stamp their own learnings.

This tension is worth calling out: **orchestrator's autonomy requirement means rationale-gated promotion cannot happen inside the autonomous loop**. The workflow is: auto run produces staged candidates → interactive review session promotes with rationale → next auto run reads graduated lessons.

### Mapping to existing milestones / new candidates

**Fold into existing work:**
- A3 (review queue in status) → fits M019/P06 (status + doctor integration) if it reaches Tier 3 scope. Or standalone small PR.
- A5 (on_failure flagging) → natural Tier 3 enrichment (depends on Tier 1 data).
- A6 (clustering in consolidate) → standalone maintenance PR; no milestone dependency.

**New-milestone candidate reconsideration:**

Earlier I deferred "M020 Knowledge Wiki Layer" until post-M012. Agentic-stack's patterns (A1 + A2 + A3 + A4) plus the earlier L7 (wikilinks) + L8 (explored state) now cohere into a more defensible milestone theme:

**M020 (reframed candidate) — Knowledge Layer Maturation.**

Scope candidates if pursued: L7 (wikilinks), L8 (explored state), A1 (preferences layer + init wizard extension), A2 (candidate→graduate workflow with required rationale), A3 (review queue in status), A4 (AGENTS.md read-order map for cross-runtime agents), A6 (clustering in consolidate).

Theme: orchestrator's knowledge layer stops being "a structured append-only log" and becomes "a genuine learning system with explicit graduation gates."

**Still recommend deferring commitment until after M012/P02.** M012's spec wiki may cover enough of this surface (wikilinks, indexing, rendering) to change the scope calculus. If post-M012 the knowledge/ tooling still feels like "flat registry of MEM files," promote M020 as a real milestone. If M012 patterns generalize, fold A1–A6 as layer-ins to knowledge-tooling maintenance.

### Updated suggested next actions

Merging agentic-stack findings into the earlier action list. Re-ordered by leverage/effort:

1. **L1–L5 Opus 4.7 adaptation sweep as M019/P00** — ✅ already specced.
2. **Fold L6 tool-result budgeting into M018 planning** — pending D008 amend.
3. **Reshape M018 sketch to four-tier compaction** — pending D008 amend.
4. **Add retry-class + payload-cache fields to M019 Tier 1 schema** — pending; spec update.
5. **Amend D008 for M018 four-tier reframe** (user just confirmed this is next).
6. **A4 (AGENTS.md read-order map)** as small standalone PR layered into `orchestrator:init` output — low risk, useful for Codex/Cursor runtimes especially. Worth doing before M019/P00 sweep so P00's payload-shape changes include the read-order directive.
7. **L7 + L8 + A2 + A3 as a cohesive small PR sequence** — candidate-review workflow is the glue that makes wikilinks + explored-state actually compound. Could ship as a knowledge-tooling maintenance sequence, or deferred to M020 scope decision post-M012.
8. **A1 (preferences layer)** — fits better in M009 Launch scope (part of "what a new user sets up") than as pre-launch layer-in. Park it for M009.
9. **A5 (on_failure flagging)** — M019 Tier 2/3 territory. Revisit after Tier 1 data exists.
10. **A6 (clustering in consolidate)** — opportunistic maintenance; no milestone dependency.
11. **Defer M020 decision** to post-M012/P02.

### Open questions — resolved 2026-04-17

All open questions from this analysis resolved. See `DECISIONS.md` D010 and D011 for the authoritative record.

- ✅ **Q1 (original) — Opus 4.7 L1–L5 placement**: inserted as M019/P00 per `specs/019-observability-metrics/spec.md` User Story 5 + SC-11–15. Ships before P01 emitter so baseline records are post-adaptation.
- ✅ **Q2 (original) — M018 reshape to four-tier ladder**: sequenced approach. D010 amends D008 framing now (four-tier ladder replaces single-filter model); fresh `orchestrator:discuss` runs at M018 kickoff once M019 Tier 1 data exists.
- ✅ **Q3 (new) — A2 candidate-review workflow placement**: split. Minimum-viable guard (L8 explored state + `graduate.sh --rationale`) ships as standalone maintenance PR now (per D011). Full workflow (clustering, staging layer, review queue UI, decision history) waits for M020 decision at M012/P02 close.
- ✅ **Q4 (new) — A4 read-order map timing**: ships as separate small PR before M019/P00, not bundled. P00 remains scoped to dispatch-facing payload adaptation only.
- ✅ **Q5 (new) — M020 trigger**: logged as D011 with mechanical 2-of-3 criteria evaluated at M012/P02 close. Avoids subjective deferral.

### Near-term PR sequence (target order, as of 2026-04-17)

Derived from resolved questions:

1. **A4 read-order map** — standalone small PR; adds `.orchestrator/AGENTS.md` (or equivalent) for non-Claude-Code runtimes. No milestone scaffolding.
2. **L8 + A2 minimal guard** — standalone maintenance PR; `status: candidate`/`graduated` on auto-generated MEM entries + `scripts/knowledge/graduate.sh --rationale`. No milestone scaffolding.
3. **M019/P00 (Opus 4.7 adaptation sweep)** — L1–L5 per spec US5.
4. **M019/P01 (Tier 1 emitter)** — US1–US4 per spec, with retry-class metrics baked into schema.
5. **M012 kickoff** (discuss → plan → execute).
6. **At M012/P02 close**: apply D011 decision rule; promote or dissolve M020.

Items deferred per D011: L7 wikilinks, A1 preferences layer, A3 review queue in status, A6 clustering in consolidate, A5 on_failure flagging. These flow into either M020 (if promoted) or knowledge-tooling maintenance PRs (if M020 dissolves).

