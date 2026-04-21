---
schema_version: "1.0"
type: evaluation
milestone: "M012"
feature_ref: "022-spec-wiki"
feature_spec: "specs/022-spec-wiki/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-18T00:00:00Z"
---

# M012 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: orchestrator:discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 5 |
| Acceptance scenarios | 18 |
| Functional requirements | 10 |
| Estimated SDD flows | 2 |

## Reasoning

M012 is a Tier C milestone. The spec decomposes into multiple distinct concerns that do not fit a single SDD flow:

1. **Content sourcing and navigation** — deciding which `.orchestrator/` artifacts render, the nav structure, symlink/include strategy so `.orchestrator/` remains the single source of truth (FR-1, FR-2, FR-8, FR-9).
2. **Comment surface (Giscus) integration** — mapping strategy selection, deploy-time config, failure-when-misconfigured behavior, comment-thread survival across renames (US2, US5, FR-3, FR-4).
3. **Deploy pipeline** — one-command `mkdocs gh-deploy`, local preview, clear failure modes, first-time setup docs (US3, FR-5, FR-7, SC-4, SC-9).
4. **Cross-link rewriting** — internal markdown links between `.orchestrator/` artifacts resolve to rendered routes; out-of-scope link handling documented (US4, FR-6, SC-6).
5. **D011 trigger evaluation** — at close of the phase that would ship M020's trigger criteria, a mechanical check runs against what shipped (cross-refs to `knowledge/**/MEM*.md`, reviewed/unreviewed state, dispatch-callable query surface). The spec deliberately does not pre-commit; planning decides which of the three land, and the trigger evaluates whatever does.

Each of these concerns is a separate SDD cycle with its own acceptance criteria, its own cross-phase dependencies (cross-link rewriting depends on content sourcing; D011 trigger eval depends on whichever optional criteria shipped), and its own verification surface. Roadmap decomposition is required — planning cannot reduce this to a single task list without losing the sequencing.

The spec explicitly references coordination with downstream milestones (M013 reads Giscus threads, M014 ingests comment corpus, M020 decision runs off M012 outcomes), which is the Tier C signal: cross-milestone coupling that a single SDD flow cannot hold.

## Complexity Factors

- **Multi-concern scope**: content scope, navigation, comment system, deploy pipeline, link rewriting — each a distinct concern.
- **External system integration**: GitHub Pages (hosting), GitHub Discussions + Giscus (commenting) — deploy-time prerequisites that must be handled.
- **D011 branching**: the spec's planning-phase decision about which M020 criteria to include changes the roadmap shape. Planning must choose, and the evaluation trigger runs against that choice.
- **Archive policy**: `.orchestrator/archive/**` milestones and whether/how they render is a planning decision with downstream consequences for nav volume and link rewriting.
- **Single-source-of-truth discipline**: orchestrator artifacts must stay at canonical `.orchestrator/` paths; the wiki references them via MkDocs configuration. This rules out the simplest "copy into docs/" approach and requires planning to choose between symlinks, MkDocs plugin includes, or equivalent.
- **Dogfood timing**: the milestone ships before M013/M014 begin dogfooding their own features against this wiki's output, so cross-milestone coupling (comment threads must be functional before M014 planning) is load-bearing.
- **Bash 3.2 + no-compound-bash constraints** apply to any shipped helper scripts (link checker, deploy wrapper, Giscus smoke test).
