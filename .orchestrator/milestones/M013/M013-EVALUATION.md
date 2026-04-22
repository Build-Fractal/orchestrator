---
schema_version: "1.0"
type: evaluation
milestone: "M013"
feature_ref: "023-github-native-integration"
feature_spec: "specs/023-github-native-integration/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-21T14:01:13Z"
---

# M013 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: orchestrator:discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 6 |
| Acceptance scenarios | 28 |
| Functional requirements | 15 |
| Estimated SDD flows | 2+ |

## Reasoning

M013 ships a new command surface (`orchestrator:github init|sync|status`), a sidecar config format with marker-based idempotency, a UAT issue template + knowledge-graph ingestion path, a post-verify hook wired for `on-transition` sync mode, and an invocation point for the M011/P07 conversus adapter. Six user stories (four at P1/P2 priority covering init, idempotent re-sync, UAT ingestion, reversibility, on-transition hook, and conversus gate) expand into 28 acceptance scenarios and 15 FRs spanning REST-first write paths, ≤2 GraphQL calls, sidecar schema, hook surface, template generation, knowledge-graph wiring, and reversibility guarantees. The work crosses multiple distinct subsystems that each require their own specify→plan→tasks cycle and cannot fit in a single context window — placing it firmly in Tier C, consistent with prior milestones of comparable surface (M011, M012).

## Complexity Factors

- **New command surface** (`commands/github.md` plus subcommand dispatch) requires its own design pass separate from the sync engine.
- **Two-leg write path** (REST via `gh` for ≥90% of writes; GraphQL only for `createProjectV2` + `addProjectV2ItemById`) with per-item retry boundaries and partial-failure recovery semantics (SC-3).
- **Idempotency contract** keyed on `<!-- orchestrator-id: ... -->` markers with search-before-create semantics across Issues, sub-issues, Milestones, and Project v2 items (FR-4, US-2).
- **Sidecar config format** (`.orchestrator/integrations/github.json`) defines the orchestrator-id → issue-number cache, sync mode, and custom-field mappings — requires a documented schema in `references/` (SC-11).
- **UAT ingestion path** crosses from GitHub Issues into the orchestrator knowledge graph (`spec/defect` entries with chunk → phase → test edges), and must survive `orchestrator:consolidate` (SC-4).
- **Reversibility contract** (FR-11, US-4) requires every orchestrator command path to no-op cleanly when the sidecar config is absent, including the post-verify hook.
- **Post-verify hook** for `on-transition` sync mode must not regress verify and must not introduce Claude Code approval prompts (SC-7), inheriting M016/M021 hardening.
- **Conversus gate invocation** at a configured hook point must respect the intensity engine's default enablement and error loudly when the adapter is absent (FR-13, US-6).
- **Dependencies on completed milestones** (M011 chunk IDs + `KNOWLEDGE-INDEX.md`; M012 wiki URLs; M011/P07 conversus adapter) require careful boundary handling so M013 does not duplicate their responsibilities.
- **10 open questions** deferred to planning (eager-vs-lazy task issue creation, Project v2 status field values, out-of-band deletion handling, hook install location, dry-run manifest format, conversus gate hook points, sub-issue fallback strategy, UAT ingestion trigger, custom-field mapping ergonomics, cross-milestone re-init) each shape a planning decision and reinforce the need for a discussion gate before roadmap.
- **Constitution XV (Surgical Precision) + M016/M021 zero-prompt baseline** apply across all shipped shell: Bash 3.2 compat, anti-pattern-lint clean, and zero approval prompts in auto mode.
