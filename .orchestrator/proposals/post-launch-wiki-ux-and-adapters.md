# Proposal: Post-Launch Arc — Wiki UX Deep + External Tool Adapters

**Captured**: 2026-04-29 during pbj-central-mono-repo wiki deployment session
**Shape**: Two demand-driven post-launch milestones, sequenced after M032 (wiki distribution) ships
**Status**: Stub — full briefs to be authored when arc enters the queue. Captured now so the thesis isn't lost between sessions.
**Source**: 2026-04-29 conversation with Brett during PBJ wiki bootstrap. See user-memory entry `project_knowledge_graph_vision.md` for the underlying product thesis.

## Thesis

The orchestrator's knowledge graph (`.orchestrator/knowledge/` + milestone/decision/spec tree, with graph relations per M020) is the **product core**, not a side artifact. Everything else is a view over it.

- **Wiki** (M012 dogfood, M032 distribution) — the lowest-friction view; lets the whole company read/scan/search/comment without opening raw markdown.
- **GitHub Issues/Milestones/Projects v2** (M013, closed) — the prototype external-tool adapter.
- **Future adapters** — Jira, Notion, Obsidian, Trello. Plugin-shaped, opt-in per project. Generalizes M013's pattern.

This arc is the post-launch *expansion of reach* once M032 has shipped the basic wiki to every consumer project. Two distinct milestones — splitting them keeps each one focused and demand-signals can sequence them independently.

## Milestone 1 — Wiki UX Deep / Knowledge Graph Viewer

**Goal**: take the wiki from "renders markdown" to "navigable knowledge graph" — adoptable for cross-company consumption without engineering training.

**Scope candidates** (for the eventual brief):
- **Code-to-title resolution layer** (Finding G in M032) — surface bare codes like `AN-011`, `M028`, `DR-STACK-001` as `AN-011 (Analyzer Trust Erosion)` with link to definition. May ship as part of M032 readability hardening; if not, consolidates here.
- **Scannable index pages** — section indexes show one-line summaries (frontmatter `description:` or first body line) per artifact, not bare nav lists. May ship as part of M032; if not, here.
- **Faceted search** — beyond mkdocs's built-in search: filter by milestone, decision-status, knowledge-category, date range.
- **Graph chips on every page** — render incoming/outgoing graph edges as inline chips ("Decided by: DR-CONSTITUTION-001", "Cited by: M001/P02 plan").
- **Related-entries sidebar** — auto-populate "see also" lists from graph relations.
- **AI Q&A widget** — "Ask the wiki" surface backed by the project's knowledge graph + LLM. Sits alongside Giscus comments; lower-friction than commenting for "how does this work?" questions. Composes with M033's onboarding-AI work.
- **Comment-driven engagement** — beyond Giscus presence: comment-prompts at section bottoms, comment-aggregation views ("recent comments across the wiki"), comment-to-issue conversion.

**Why post-launch**: launch must ship a wiki that's *usable* (M032 readability hardening covers that), but the deeper UX (graph chips, faceted search, AI Q&A) is differentiated polish. Real-user signal informs which features matter most. Pre-launch dogfooding exercises only synthetic shape; post-launch gives real diversity.

**Predecessors**: M032 (wiki distribution must ship first — every consumer project needs the basic wiki working before deeper UX matters); M020 (knowledge layer maturation, closed — graph relations exist); M033 (onboarding experience — composes with AI Q&A surface).

## Milestone 2 — External Tool Adapter Framework

**Goal**: generalize M013's GitHub-Issues/Milestones/Projects-v2 integration pattern into a plugin-shaped adapter framework. Ship Jira, Notion, Obsidian as the first three external adapters alongside the existing GitHub one.

**Scope candidates** (for the eventual brief):
- **Adapter contract** — formalize the M013 sidecar pattern (`<project>/.orchestrator/integrations/<tool>.json`) into a generic schema. Each adapter declares: push-direction (graph → tool) and pull-direction (tool → graph) capabilities, auth shape, identifier-mapping table.
- **Push direction, ship first** — orchestrator state changes propagate to the external tool. M013 does this for GitHub; same pattern for Jira issues, Notion pages, Obsidian vault entries.
- **Pull direction, phased** — comments / status changes / new tickets in the external tool reflect back into the orchestrator state. Harder; per-tool API maturity varies. Ship per adapter as the API surface allows.
- **Conflict resolution** — when state diverges between graph and external tool, what wins? Per-adapter config: `graph-wins | tool-wins | manual-resolve`. Defaults to `manual-resolve` (creates a `decision-needed` artifact in the orchestrator state).
- **Three first adapters**: Jira (the enterprise default), Notion (the team-knowledge default), Obsidian (the personal-graph default). Trello + Linear are obvious follow-ons.

**Why post-launch**: net-new capability, not launch readiness. Demand-driven — ships when first users arrive needing tool A or B. Each adapter is independent; can split into sub-milestones per tool.

**Predecessors**: M013 (proof of pattern, closed); M020 (graph maturity, closed); M032 (wiki as the canonical "render the graph" path — adapters are the "sync the graph" path; both consume the same underlying graph schema, so M032's polish reveals the schema's shape).

## Sequencing rationale

Both are post-launch because:
- M032 must ship first (basic wiki for every consumer).
- Wiki UX deep must precede external adapters because adapters consume the same graph schema that wiki UX exposes — building adapters first risks shipping abstractions over a schema that's still in flux.
- Real-user signal sequences which milestone gets attention. Broad adoption with friction → wiki UX deep first. Enterprise-customer adoption with tool-integration ask → adapters first.

Both compose with M033 (onboarding) — onboarding flow can suggest "wire this project to your team's Jira" as a post-init step.

## Out of scope (for both)

- Replacing the underlying knowledge-graph storage. M020 schema is the commitment.
- Real-time bidirectional sync with sub-second latency. Adapter sync is batch / on-demand.
- Multi-tool conflict resolution beyond simple per-pair (orchestrator + tool A, orchestrator + tool B; not "all three at once").
- Acting as a Jira/Notion/Obsidian replacement. The orchestrator stays a development-orchestration tool; adapters expose its state to external tools, don't replace them.

## Open questions for the eventual full brief

1. Wiki UX deep vs M032: how much readability work belongs in M032 (must ship for launch) vs deferred here (post-launch polish)? Today's recommendation: **code-to-title + scannable indexes ship in M032**; faceted-search + graph-chips + AI-Q&A ship here.
2. Adapter framework: introduce a top-level `commands/integrate.md` that dispatches to adapters, vs per-adapter commands (`commands/integrate-jira.md`, `commands/integrate-notion.md`)? Single command + subcommands is simpler; per-adapter is more discoverable.
3. AI-Q&A backing: which model gateway? Adopts whatever M030 (adaptive model selection) settles on. Predecessor.
4. Each adapter milestone size: full milestone per tool (Jira gets its own) or one milestone bundles three? Bundle-of-three lets the framework abstraction be tested by N=3; per-tool is cheaper to ship sequentially as demand surfaces.
