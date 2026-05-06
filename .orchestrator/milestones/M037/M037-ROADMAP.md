---
schema_version: "1.0"
type: roadmap
milestone: "M037"
feature_ref: "038-wiki-team-feedback-ready"
feature_spec: "specs/038-wiki-team-feedback-ready/spec.md"
vision: "Orchestrator-managed wikis render as usable reader surfaces for non-author SMEs by P01 merge, with PBJ-team feedback signal driving P02 polish — wiki-quality noise does not contaminate the M035-launch validation loop."
tier: "C"
created_at: "2026-05-06"
updated_at: "2026-05-06"
revised: "2026-05-06 (theme-leverage amendment — P01 boundary map extended with FR-9 polish-bundle additions (navigation.prune + pymdownx.details + pymdownx.tasklist), FR-8 expanded with already-enabled-features authoring conventions section, FR-15 swapped external mkdocs-tags for Material built-in tags. P02 boundary map extended with Tier 2 candidates FR-16 social-cards + FR-17 meta-folder-defaults gated on PBJ feedback. Tier 3 captured separately at .orchestrator/proposals/M039-theme-leveraged-process-primitives.md.)"
---

## Phases

- [ ] **P01**: Wiki team-feedback-ready ship-it minimum — "A non-author reader (PBJ domain SME) opens an orchestrator-managed wiki and lands on a card-grid homepage, scans a reference nav of human-readable strings (not slug-soup), reads a decisions TOC of human concepts (not codes), sees top-level sections in a sticky tab header with a 2-level TOC and an edit-this-page affordance, and the operator's `wiki:` block in `.orchestrator/config.yml` survives `orchestrator:update` byte-identical."
  - Risk: high
  - Depends: none
  - Blocked by: M032 closed (2026-05-05), M036a closed (2026-05-02), papercut-sweep rounds 1+2 (commits e4c3c8f7 + 90c18f07)
  - Boundary Map:
    - Produces: `templates/wiki-index-cards.md.tmpl` (new card-grid template, FR-1) | `wiki.landing_cards:` config schema (FR-2/3/4) | projected `wiki/docs/index.md` (FR-4) | `wiki-generate-stubs.sh` `version:`→`title:` projection with MIT-01 conditional-overwrite + Typeset-evaluation gate per US-2 AS-5 theme-leverage amendment (FR-5) | `wiki-generate-nav.sh` honoring stub `title:` (FR-6) | restructured `.orchestrator/DECISIONS.md` from 7-column markdown table to ~150 `### Title { #dr-code-nnn }` heading entries with code-chip body markup, preserving every legacy permalink (FR-7 — scope expanded per /orchestrator-plan-phase plan-time discovery: file is a markdown table not heading-shape today, operator confirmed Option 1 "restructure now") | `references/authoring-conventions.md` covering (a) DR-/BG-/AN-/MEM-/Q-### code conventions and (b) **already-enabled-but-undocumented mkdocs-material features** per theme-leverage amendment: Mermaid via superfences, snippets, admonition variants, attr_list chips, content tabs, and the new `pymdownx.details` + `pymdownx.tasklist` extensions added in FR-9 (FR-8) | `commands/dispatch.md` payload-guidance reference to convention (FR-8) | `mkdocs.yml` template additions: `navigation.tabs` + `navigation.tabs.sticky` + **`navigation.prune`** + `toc.toc_depth: 2` + **`pymdownx.details`** + **`pymdownx.tasklist` (custom_checkbox: true)** + `content.action.edit` + `content.action.view` + `edit_uri:` derived from `repo_url:` (FR-9 — three additions in **bold** folded in via theme-leverage amendment) | shared YAML-key-preservation merge primitive parameterized over (file path, managed-namespace list) consumed by FR-9 + FR-10 (resolves #Q-4) | install-template emission logic for `.orchestrator/config.yml` + `mkdocs.yml` honoring CON-3 byte-identical preservation, with DISP-1 plan-time managed-key namespace cross-reference artifact against PBJ-central live config (FR-10) | fail-closed-on-malformed-YAML behavior in install-template refresh (FR-11) | acceptance battery aggregator stub at `tests/m037-acceptance/run-acceptance-battery.sh` (SC-12 scaffold)
    - Consumes: M032 wiki tooling baseline (`scripts/wiki/`, `mkdocs.yml` template, `wiki-init.sh`, install-template plumbing) | M036a chunk corpus with `version:` + `topic_tags:` + `external_pointer:` frontmatter | papercut-sweep clean `mkdocs build --strict` baseline | this repo's `.orchestrator/DECISIONS.md` (heading-shape migration target) | PBJ-central `.orchestrator/config.yml` as live cross-reference target for DISP-1 namespace classification (read-only)

- [ ] **P02**: Round-3.5 polish — tag-driven nav + GitHub source-link + knowledge card grid + 3 plugins — "After ≥3 PBJ-team nav-or-section-shape feedback items land against P01, a non-author reader navigating the reference nav sees entries grouped under deterministic config-driven buckets (QSO letters, policy manuals & FAQs, etc.) instead of a flat 70-entry list, every Tier 0/1 chunk page carries a working GitHub source-link affordance, `/knowledge/` renders as a card grid surfacing major knowledge areas, and content pages carry tag-pivot pages + last-modified timestamps."
  - Risk: medium
  - Depends: P01
  - Blocked by: ≥3 nav-or-section-shape feedback items filed by PBJ team against P01 wiki (per #Q-6 (a) resolution; operator override available if PBJ review unexpectedly quiet)
  - Boundary Map:
    - Produces: `wiki.nav_buckets:` config schema (FR-12) | `wiki-generate-nav.sh` tag-driven subgrouping with deterministic config-declaration order + "Uncategorized" sibling bucket for tag-less chunks (FR-12) | GitHub source-link rewrite at projection time in stub generator metadata-table emission (Tier 0) + Tier 1 chunk-projection pass, with default-branch fallback to `main` per CON-4 (FR-13) | `wiki.knowledge_cards:` config schema OR scoped reuse of `wiki.landing_cards:` (final shape decided at P02 plan-phase from PBJ signal per #Q-6 (b)) (FR-14) | `/knowledge/` projection via card-grid template + power-user URL `/knowledge/_index/` for legacy auto-projected content (FR-14) | `wiki/requirements.txt` with version-pinned `mkdocs-redirects` + `mkdocs-git-revision-date-localized-plugin` **(only two external deps — Material's built-in `tags` plugin replaces the originally-planned external `mkdocs-tags` per theme-leverage amendment)** (FR-15) | `mkdocs.yml` template plugin entries for the three plugin capabilities — `tags` (built-in), `redirects` (external), `git-revision-date-localized` (external) (FR-15) | `topic_tags:` → `tags:` projection-time adapter preserving operator-authored `tags:` when both fields present per Edge-Case rule (FR-15) | **theme-leverage Tier 2 candidates (gated on first PBJ feedback signal per #Q-6 (a))**: Material built-in `social` plugin auto-OG-cards with `mkdocs-material[imaging]` system-deps probe in `wiki-init.sh` (FR-16) | Material built-in `meta` plugin folder-frontmatter-defaults pattern with `wiki/docs/<section>/.meta.yml` example (FR-17) | acceptance battery completion (SC-6..SC-9 + SC-10 strict-build smoke + SC-11 PBJ-update evidence + SC-12 aggregator + optional SC-9 extensions for FR-16/FR-17 if shipped)
    - Consumes: P01 card-grid template primitive (`templates/wiki-index-cards.md.tmpl`) for FR-14 reuse | P01 `wiki.landing_cards:` schema as section-scoping precedent for FR-14 final shape | P01 shared YAML-merge primitive for `wiki.nav_buckets:` + `wiki.knowledge_cards:` operator-authored-key preservation | P01 `wiki-generate-nav.sh` baseline for FR-12 modifications | P01 `wiki-generate-stubs.sh` baseline for FR-13 metadata-table-emission modifications | M036a chunk corpus `topic_tags:` + `external_pointer:` frontmatter | `mkdocs.yml` `repo_url:` for FR-13 source-link rewrite

## Cross-Cutting Concerns

- **CON-3 — Operator-authored content preservation across `orchestrator:update` refreshes**: P01, P02. P01 establishes the shared YAML-key-preservation merge primitive (consumed by FR-9 mkdocs.yml + FR-10 config.yml) and the DISP-1 plan-time managed-key namespace cross-reference artifact. P02's new schemas (`wiki.nav_buckets:` for FR-12, `wiki.knowledge_cards:` or scoped `wiki.landing_cards:` for FR-14) MUST be classified through the same primitive — operator-authored values for these keys survive byte-identical, orchestrator-managed defaults merge underneath. Hard contract; any violation is a P0 bug.
- **CON-2 — Projection-not-source-mutation**: P01, P02. P01 establishes the pattern with FR-5 (`version:` → stub `title:` at projection time, source frontmatter unchanged). P02's FR-13 (GitHub source-link rewrite) and FR-15 (`topic_tags:` → `tags:` adapter) MUST conform — both operate at projection time and preserve source chunks byte-identical.
- **CON-4 — Default-branch derivation falls back to `main`**: P01 (FR-9 `edit_uri:`), P02 (FR-13 source-link rewrite). Single helper script (`scripts/wiki/resolve-default-branch.sh` or equivalent) produced in P01, consumed in P02. Debug-level diagnostic on fallback; no warning escalation.
- **CON-1 — Zero new mkdocs plugin dependencies in P01**: P01 only. The card-grid template (FR-1) uses `attr_list` + `md_in_html` already enabled. New plugins ride P02 (FR-15). Guards against P01 surface bloat and operator toolchain churn.
- **Card-grid template primitive**: P01 establishes (`templates/wiki-index-cards.md.tmpl`, FR-1); P02 reuses for `/knowledge/` (FR-14). Template authoring cost paid once. Consuming phase (P02) MUST NOT reinvent the template — config-only customization via the `wiki.knowledge_cards:` (or scoped `wiki.landing_cards:`) schema.
- **MIT-01/MIT-02 P0 — Conditional-overwrite escape hatch + escape-hatch fixture**: P01 (FR-5 + SC-2). The `version:` → `title:` projection MUST NOT overwrite stubs carrying `auto_generated: false` frontmatter; SC-2 fixture MUST exercise this case (fourth fixture: pre-existing stub with `auto_generated: false` and operator-edited `title:` value; assert byte-identical preservation across re-runs). Lifted to P0 by conversus arbitration.
- **MIT-03 P0 — CON-3 back-reference in FR-9**: P01. The mkdocs.yml template-emit path is in scope of CON-3. Resolved via the shared YAML-merge primitive (#Q-4 resolution) — FR-9 + FR-10 collapse into a single shared-primitive task with two file-path consumers.
- **DISP-1 plan-time gate (arbiter-ruled)**: P01. The plan-phase output for the FR-9/FR-10 shared-primitive task carries a `## Managed-Key Namespace Cross-Reference` section listing each proposed orchestrator-managed namespace alongside the PBJ-central `.orchestrator/config.yml` (and `mkdocs.yml`) keys it covers, with collision flags. Operator approves the plan (or pushes back on specific classifications) before any FR-9/FR-10 implementation begins.
- **Knowledge-Layer Boundary (M037 vs. M020/M036a)**: P01, P02. Both phases are presentation-layer changes only. NEITHER phase touches `knowledge/<category>/MEM*.md` content, `.orchestrator/knowledge/KNOWLEDGE-INDEX.md`, chunk frontmatter schema (read-only), edge-type catalogue, spec-chunk metrics, or tier-0/1/2 extraction adapters. Crossing the boundary requires a new spec.
- **Acceptance battery aggregator**: P01 scaffolds `tests/m037-acceptance/run-acceptance-battery.sh` covering SC-1..SC-5; P02 extends it to cover SC-6..SC-9 + SC-10 strict-build smoke + SC-11 PBJ-update evidence; SC-12 closure gate fires only after P02. Verification ladder applies at the milestone boundary, not per phase.

## Dependency Graph

```
            [ M032 closed ]
            [ M036a closed ]
            [ papercut-sweep R1+R2 ]
                    │
                    ▼
                  P01
                    │
                    │  (gated: ≥3 PBJ nav-or-section-shape feedback items)
                    ▼
                  P02
```

Linear P01 → P02 with an external feedback-signal gate between them. No internal cycles. No concurrent execution lanes.

## Execution Order

1. **P01** — no phase dependencies; depends only on closed upstream milestones (M032 + M036a) and the papercut-sweep clean baseline. Ships first as the load-bearing slice (US-1+US-2+US-4 minimal slice, US-3 + US-5 sharing template-territory cost). High-risk phase per FR-043 — multiple cross-coupled FRs (FR-9 + FR-10 shared-primitive task with MIT-03 P0 + DISP-1 plan-time gate, FR-5 + MIT-01/MIT-02 P0, FR-7 retroactive content migration on `.orchestrator/DECISIONS.md`).
2. **P02** — gated on (P01 merged) AND (≥3 PBJ nav-or-section-shape feedback items filed). Operator override path available if PBJ review unexpectedly quiet. Cannot execute concurrently with P01 (template-primitive + schema dependency from FR-1 → FR-14 and shared YAML-merge primitive consumption). Medium-risk — smaller scope, plugin additions introduce toolchain-conflict risk.

## Validation

- **No conflicting producers**: PASS. Each FR maps cleanly to exactly one phase. Card-grid template primitive (FR-1) is produced by P01 and reused (consumed) by P02 via FR-14 — reuse, not re-production. Shared YAML-merge primitive is produced by P01 (FR-9/FR-10 collapse) and consumed by P02 for new schema keys.
- **All consumed items have producers**: PASS. P01 consumes from closed upstream milestones (M032, M036a, papercut-sweep) and PBJ-central live config (read-only); all external producers exist. P02 consumes only from P01 — every P02 consume entry maps to a named P01 produces entry.
- **DAG is acyclic**: PASS. Linear P01 → P02; no cycles.
- **Demo sentence coverage**: PASS. P01's demo sentence is concrete and observable (homepage card grid + reference nav human strings + decisions TOC concepts + tabbed header + 2-level TOC + edit affordance + `orchestrator:update` survives `wiki:` block byte-identical). P02's demo sentence is concrete and observable (tag-driven nav buckets + GitHub source-link affordance + `/knowledge/` card grid + tag-pivot pages + last-modified timestamps).
