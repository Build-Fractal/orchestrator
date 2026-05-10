# Proposal: M039 — Theme-Leveraged Process Primitives (post-launch, demand-driven)

**Captured**: 2026-05-06 during `/orchestrator-plan-phase` for [M037](../milestones/M037/index.md) P01
**Shape**: Post-launch milestone, demand-driven, scope absorbs portions of multiple existing post-launch proposals
**Predecessors**: M037 (P01 + P02 closed — Tier 1 + Tier 2 mkdocs-material features in service of team-feedback-readiness), [M035](../milestones/M035/index.md) (closed — packaging & distribution; v1.0 launched), validator-pilot signal (≥ N feedback items filed against M037-shipped wiki indicating where macro-driven primitives would help)
**Source**: M037 P01 plan-phase research surfaced the **mkdocs-material force-multiplier insight** — many of our post-launch wiki/process proposals (knowledge-graph viewer, supersede chain UI, REVIEW queue, change-over-time queries, decision packets, living documents) collapse from "custom Python plugin code" to "Jinja2 macros + Mermaid + theme features" once `mkdocs-macros-plugin` + `pymdownx.critic` + git-history plugins are adopted. Order-of-magnitude cost reduction for the affected scopes.

## Why this is post-launch (not pre-launch)

The Tier 1 + Tier 2 mkdocs-material adoptions ride M037 P01/P02 because they're cheap-and-additive (single-line config changes, built-in plugins, no dep churn). M039's Tier 3 adoptions are heavier: `mkdocs-macros-plugin` is a Python build-time execution surface (security review needed, not "free"), `mike` versioning has a publishing pipeline implication (post-M035), `pymdownx.critic` adoption requires authoring conventions (more like FR-8 + dispatch.md guidance work, not a single config line). All four Tier 3 adoptions land more cleanly when:

1. M035 has shipped and the launch publishing pipeline is stable — adding `mike` to a stable pipeline is safer than during launch turbulence.
2. PBJ and validator-pilot feedback signal informs WHICH macros are highest-value (e.g., is the knowledge-graph viewer the first macro, or the REVIEW queue?).
3. We have at least one downstream consumer beyond PBJ-central exercising the full surface, so we can validate macro patterns generalize.

## Goal

After M039 ships, the orchestrator's wiki layer carries a **macro-driven dynamic-content capability** that collapses three post-launch milestone scopes into theme-and-template work:

1. **Knowledge-graph viewer**: Mermaid diagram auto-generated from `.orchestrator/knowledge/KNOWLEDGE-INDEX.md` via macros — replaces the custom-graph-UI plan in `wiki-ux-deep`.
2. **Supersede chain visualization**: chunk pages auto-render their supersede chain (chip badges + linked predecessors/successors) via macros reading `supersedes:` / `superseded_by:` frontmatter — replaces M036b P09's custom supersede-chain UI scope.
3. **REVIEW queue page**: dynamically generated from chunks tagged `status: needs-review` via Material's built-in `tags` plugin + macros walking the corpus — replaces M036b P09's REVIEW queue scope.
4. **Change-over-time queries**: `mkdocs-git-revision-date-localized-plugin` + `mkdocs-git-committers-2` + macros emit Mermaid timeline diagrams + per-page contributor lists — replaces M036b P09's change-over-time scope.
5. **Decision-packet markup**: `pymdownx.critic` (track changes) + built-in `tags` for status filtering enable M034's interactive-review-gates primitive without bespoke schema authoring — strong primitive overlap with M034.
6. **Living-document section binding**: `attr_list` (already enabled, used for chips) + git-committers + macros emit "what code references this section" lists — strong primitive overlap with M038.
7. **Multi-version docs**: `mike` versions the docs site so v0.9 / v1.0 / v1.x readers see version-appropriate orchestrator docs — load-bearing once M035 has launched and v1.0+ exists.
8. **Change-feed RSS**: `mkdocs-rss-plugin` emits subscribable RSS feeds for any section (REVIEW queue, validator signal capture, milestone-history changes) — solves the "quietly surface signal to subscribers" loop.

## Why this is a single milestone (vs many small fast-follows)

Each Tier 3 adoption individually is small (1-3 days). The case for bundling:

- **Shared install-bundle territory**: all Tier 3 plugins land in `wiki/requirements.txt` + `mkdocs.yml`. Bundling avoids touching the install-bundle 5+ times.
- **Shared authoring-conventions surface**: `mkdocs-macros-plugin` adoption requires authoring patterns (security, idempotency, state-file contracts) that overlap with `pymdownx.critic` authoring patterns and `mike` per-version conventions. Document once.
- **Shared verification surface**: a macro-driven knowledge-graph render + supersede chain render + REVIEW queue all need the same kind of "macro evaluates against frozen state, output asserts shape" verifier. Build the verifier-shape once.
- **Shared scope-collapse argument**: this milestone's value proposition is "we adopted theme/plugin primitives and collapsed M036b P08-P09 + parts of M034 + M038 + `wiki-ux-deep`". Splitting into fast-follows obscures the cost-collapse story and risks each fast-follow being judged in isolation.

## Scope-collapse map

What M039 absorbs vs leaves:

| Pre-M039 scope | M039 absorbs | M039 leaves |
|---|---|---|
| **M036b P08** (wiki projection of reference-corpus operator-facing UX) | YES — wiki projection is exactly what macros do | (P08 closes via M039) |
| **M036b P09** (REVIEW queue + change-over-time + supersede chain at scale) | YES — all three are macro-driven | (P09 closes via M039) |
| **`wiki-ux-deep` post-launch proposal** | PARTIAL — knowledge-graph viewer absorbed (Mermaid + macros), faceted search absorbed (built-in tags + tag-pivot pages from M037 P02) | LEAVES: AI Q&A widget (custom integration, no theme/plugin solution), lifecycle-stage badges (could absorb if scope allows) |
| **M034 (interactive review gates)** | PARTIAL — decision-packet markup primitive absorbed via `pymdownx.critic` | LEAVES: the orchestrator-side interactive-walkthrough engine consuming the markup (M034 P02 still needs to ship as the consumer of M039's primitive) |
| **M038 (living documents)** | PARTIAL — section-binding primitive absorbed via attr_list + git-committers + macros | LEAVES: framework-side detection / registration / planner injection / verifier auto-generation (M038's heavy lifting still needs to ship) |
| **`external-tool-adapters` post-launch proposal** | NO — orthogonal surface (Jira/Notion/Obsidian sync); macros could mirror the same data but the adapter surface is its own concern | LEAVES intact |

Net effect: M036b closes via M039 (no separate M036b ship needed). M034 + M038 ship lighter (consumer side only — primitive comes from M039). `wiki-ux-deep` narrows further (only AI Q&A + custom polish remain).

## Tier 3 adoption detail

### Adopt `mkdocs-macros-plugin`

- **Why**: Jinja2 macros at build time. Read state files (YAML, JSON, JSONL, markdown frontmatter), emit dynamic content (Mermaid blocks, tables, lists, chips). The single highest-leverage adoption.
- **What it costs**: + 1 external pip dep (version-pinned). Authoring conventions doc (security: no shell-out from macros, idempotency: macros must be deterministic given same inputs, state-file contracts: which files macros may read). `wiki-init.sh` plugin probe.
- **What it enables**: knowledge-graph viewer (Mermaid auto-generated from KNOWLEDGE-INDEX.md), supersede chain visualization (chunk pages auto-render their chain), REVIEW queue page (walks chunks by status tag), operator-facing dashboards (cost+quality from JSONL stats), per-chunk "related chunks" list, per-section "what code references this" list (M038 primitive).
- **Risk**: Python execution at build time = security review required for macros that read untrusted content. Mitigate with a curated macro library (orchestrator ships the macros, consumer projects reuse).

### Adopt `pymdownx.critic`

- **Why**: Track-changes markup IN docs. The natural primitive for M034's decision-packet schema. Authors mark `{++added++}` / `{--deleted--}` / `{~~old~>new~~}` / `{>>comment<<}` directly in markdown.
- **What it costs**: + 1 markdown_extension (`pymdownx.critic`, already in pymdownx — no new pip dep). Authoring conventions doc (when to use which markup, how to scope a "decision packet" via critic markup + a tag).
- **What it enables**: M034's interactive-review-gates primitive (decision packets are critic-marked sections of docs, the interactive engine reads them and presents them to the operator). Audit-trail for any document where "what changed" matters.

### Adopt `mkdocs-git-revision-date-localized-plugin` + `mkdocs-git-committers-2`

- **Why**: M038's living-documents primitive needs "when was this last touched, and by whom". Both plugins read git history at build time and emit per-page metadata.
- **What it costs**: + 2 external pip deps (version-pinned). Optional: `wiki-init.sh` probes. (`mkdocs-git-revision-date-localized` already lands in M037 P02 FR-15 — only `mkdocs-git-committers-2` is net-new in M039.)
- **What it enables**: M038's "what code references this section" UI (binds via attr_list anchors), per-page contributor list (knowledge attribution surface — who knows about what), change-over-time queries.

### Adopt `mike` for versioning

- **Why**: Once v1.0 ships (M035), operators on v0.9 vs v1.0 vs v1.x see version-appropriate orchestrator docs. Standard Material adoption pattern.
- **What it costs**: + 1 external pip dep (version-pinned). Publishing pipeline change in M035's GH release automation: each release tag triggers a mike deploy. Authoring conventions for version-pinning sections that change between versions.
- **What it enables**: launch-aware docs (v0.x readers don't see v1.0 features as "available", v1.0 readers don't see deprecated v0.x patterns), backward-compat documentation (older versions stay live).

### Adopt `mkdocs-rss-plugin`

- **Why**: Subscribable change feeds for sections. Validator pilots subscribe to "what's changed in the validator-pilot space"; REVIEW queue subscribers get notified on new items; milestone-history watchers see closures land.
- **What it costs**: + 1 external pip dep (version-pinned). Per-section RSS config in mkdocs.yml. Authoring conventions for "this section emits an RSS feed".
- **What it enables**: reduce the polling burden on validators / SMEs — they subscribe to feeds in their reader of choice rather than checking the wiki manually.

## Open Questions (for queue-entry plan-phase to resolve)

- **#Q-1 (absorption decision)**: Does M039 absorb M036b entirely (closing M036b via M039 P0X), or does M036b retain its identity and M039 lists it as a hard predecessor? Brief leans absorption (cleaner closure narrative); confirmed at queue-entry.
- **#Q-2 (M034/M038 absorption)**: Same question for M034 + M038 — do they absorb the consumer-side scopes (interactive walkthrough engine, framework-side detection/registration/planner-injection) or do they ship as siblings consuming M039's primitive? Brief leans sibling (M039 is a primitive-ship; consumer-side work is its own milestone). Decision deferred to queue-entry.
- **#Q-3 (macro security review)**: What is the trust boundary for `mkdocs-macros-plugin`? Orchestrator-shipped macros only (consumer projects reuse but cannot author)? Or consumer-authored macros allowed with a curated allow-list? Decision shapes the authoring-conventions doc.
- **#Q-4 (pymdownx.critic adoption shape)**: Does the orchestrator dictate critic-markup conventions for decision-packets (M034 binding) or leave the markup author-discretionary? Brief leans dictate-via-FR-8-style-doc (analogous to DR-### heading-shape pivot).
- **#Q-5 (mike versioning trigger)**: Does mike adoption land at M035 launch (v1.0) or wait for v1.1+? Brief leans wait-for-v1.1 (avoids pipeline turbulence at v1.0; v1.0 ships single-version, v1.1 introduces versioning).

## Trigger condition

M039 fires when **at least one** of the following lands:

1. **Validator pilot signal**: ≥ 3 concrete pieces of feedback from validator pilots indicate they want any of {knowledge-graph viewer, REVIEW queue, change feeds, supersede chain UI, decision packets, version-appropriate docs}.
2. **Second downstream consumer**: a project beyond PBJ-central + the orchestrator's own dogfood begins exercising the wiki at scale, validating that macro patterns generalize.
3. **M035 has shipped and stabilized** (v1.0 in npm + homebrew + curl-pipe-bash, ≥ 30 days post-launch with no major publishing-pipeline incidents).

Without all three, M039 is over-eager — fewer downstream consumers means we'd build macros against a single-consumer assumption, AND publishing-pipeline turbulence at launch makes adding mike risky.

## Blast radius

- **Wiki layer only** — no changes to dispatch / build-context / payload-assembly / classifier / verifier ladder.
- **Operator-facing surfaces** — orchestrator's wiki + every consumer-project's wiki. CON-3 hard contract on operator-authored content preservation extends to all M039 plugin/extension additions (just like M037 P01 FR-9/FR-10).
- **Knowledge-layer boundary preserved** — M039 reads `.orchestrator/knowledge/KNOWLEDGE-INDEX.md` + chunk frontmatter at build time but does not mutate the schema, taxonomy, or extraction adapters owned by [M020](../milestones/M020/index.md) / M036a.
- **Backward compat** — existing wiki content remains valid markdown. Macros opt-in (sections without macros render as today). Critic markup opt-in. mike opt-in (single-version sites pre-v1.1 unaffected). No breaking changes to consumer projects on M037-baseline wiki.

## Notes for queue-entry

- **Sequencing**: M039 cannot precede M035 launch (mike adoption requires stable publishing pipeline). M039 cannot precede M037 P02 closure (built-in `tags` plugin + `mkdocs-git-revision-date-localized` are M037 P02 deliverables that M039 builds on).
- **Spec authoring**: a single spec covers all 5 plugin adoptions + the absorption decisions. Tier C complexity. Conversus gate likely (multiple cross-coupled FRs, M034/M038 absorption decisions are non-trivial).
- **Roadmap**: 3-4 phases — P01 macro-plugin + critic adoption + authoring conventions; P02 macro-driven knowledge-graph + supersede chain + REVIEW queue (absorbing M036b P08-P09); P03 git-committers + RSS + change-feed surfaces; P04 mike versioning (gated on v1.1+).
- **Rough budget**: Tier C, 4 phases at Standard intensity, predicted ~$80-120 LLM cost (Quick/Standard mix) + 2-3 weeks engineering effort. Order-of-magnitude smaller than the equivalent custom-plugin work it replaces.
