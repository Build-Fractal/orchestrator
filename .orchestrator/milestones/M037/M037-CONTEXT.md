---
schema_version: "1.0"
type: context-draft
milestone: "M037"
status: finalized
created_at: "2026-05-06"
finalized_at: "2026-05-06"
---

## Architectural Decisions

### AD-1 — Two-phase split: P01 ship-it minimum, P02 PBJ-feedback-gated polish

**Decision**: M037 ships in two phases. P01 (US-1..US-5) is the load-bearing slice — homepage card grid + `version:`→nav title + DR-### heading-shape pivot + mkdocs.yml polish bundle + install-template `config.yml` clobber fix. P02 (US-6..US-9) is round-3.5 polish — tag-driven nav subgrouping + GitHub source-link rewrite + knowledge card grid + three plugin additions.

**Rationale**: The minimum surface that closes the dogfood-contamination loop is US-1+US-2+US-4 (the "minimal slice" in the spec). US-3 + US-5 ride P01 because they share template-territory cost and address operator pain PBJ-central has already filed. P02 is gated on first PBJ feedback signal landing — bucket-mapping (US-6) and section-shape choices (US-8) benefit from real reader feedback before being locked. P02 trigger condition is captured as `#Q-6` for planning to confirm.

### AD-2 — Card-grid template is the load-bearing P01 primitive (P02 reuses it)

**Decision**: The mkdocs-material `grid cards` block (`templates/wiki-index-cards.md.tmpl`, FR-1) lands once in P01 for US-1, then US-8 (P02 `/knowledge/` card grid) reuses the template against a different surface. Zero new mkdocs plugin dependencies (CON-1) — the template uses `attr_list` + `md_in_html`, both already enabled.

**Rationale**: Builds the primitive once and pays the design cost on US-1 first impressions where it has highest impact. US-8 then becomes a config + section-scoping change rather than a new template authoring effort.

### AD-3 — Projection-time transforms only; source-side schemas remain authoritative (CON-2)

**Decision**: All M037 transformations run at projection time. `version:` → nav title (FR-5), GitHub source-link rewrite (FR-13), `topic_tags:` → `tags:` adapter (FR-15) read source-side frontmatter and emit projected output without mutating the source. Source chunks remain authoritative; the projection layer is rebuildable from source on every run.

**Rationale**: Knowledge-graph schema and chunk taxonomy are owned by M020/M036a. M037 is a presentation-layer milestone. Touching the source schema for projection-layer convenience would cross the M020/M036a boundary unnecessarily and create migration debt.

### AD-4 — DR-### heading-shape pivot is content + authoring-convention work, not a renderer change

**Decision**: US-3 lands as a content migration of this repo's `.orchestrator/DECISIONS.md` (FR-7) plus a `references/` doc promoting the convention (FR-8) plus a `commands/dispatch.md` payload-guidance reference. No renderer plugin, no theme override — the shape is `### Title { #dr-code-nnn }` using `attr_list` (already enabled).

**Rationale**: Smallest possible surface that produces the cascading readability win. Codes remain load-bearing for cross-reference and grep-ability (per Non-Goals); only the heading shape changes. Inbound permalink stability (`#dr-code-nnn`) is preserved by `attr_list` anchoring (US-3 Acceptance Scenario 1).

### AD-5 — Operator-authored content survives every template-emit path (CON-3)

**Decision**: The install-template emission for `.orchestrator/config.yml` (FR-10) and `mkdocs.yml` (FR-9, MIT-03 P0 back-reference) preserves operator-authored top-level keys byte-identical across `orchestrator:update` refreshes. Orchestrator-managed keys are scoped under explicit framework-managed namespaces; operator-authored keys outside those namespaces are read but never overwritten.

**Rationale**: The PBJ-central pain point that motivated US-5 is re-authoring the `wiki:` block on every update. Bundling the clobber fix into M037 (rather than deferring to M035) is justified because US-1 introduces a new `wiki.landing_cards:` schema operators will customize — landing US-1 without US-5 would ship a schema operators would lose on first update, surfacing exactly the operator pain US-5 fixes. Critical-path coupling pulls US-5 into P01.

### AD-6 — DISP-1 planning gate (arbiter-ruled): managed-key namespace list is an explicit planning artifact

**Decision**: Per FR-10's DISP-1 planning gate (resolved by `conversus/arbiter/resolution.md`), the planning phase for the FR-10 work MUST produce the managed-key namespace list as a named cross-reference in the phase plan, NOT as implicit working notes. The list MUST be cross-referenced against the top-level keys present in at least one live consumer project's `.orchestrator/config.yml` (PBJ-central is the available reference). Any consumer-config key proposed for orchestrator-managed classification MUST be flagged as a potential CON-3 conflict requiring operator confirmation before classification is finalized.

**Rationale**: Arbiter ruling. The conversus deliberation surfaced that an under-specified namespace list at plan time is the most likely failure mode for FR-10 — operators would lose keys silently on update because the namespace classification was wrong. Making the artifact explicit is the cheap insurance.

### AD-7 — `default_branch` derivation falls back to `main` on detached/no-remote/shallow-clone (CON-4)

**Decision**: FR-9 (`edit_uri:`) and FR-13 (GitHub source-link rewrite) read default branch from `git symbolic-ref refs/remotes/origin/HEAD` and fall back to `main` on failure. A debug-level diagnostic surfaces the fallback; no warning escalation.

**Rationale**: Test fixtures are commonly shallow-clone or no-remote. Failing closed on default-branch derivation would block the `wiki-init.sh` happy-path for fixtures that don't carry a remote. `main` is the modern default and produces working outputs even on degenerate fixtures.

## Scope Boundaries

### In Scope (P01)

- `templates/wiki-index-cards.md.tmpl` (new) — card-grid template (FR-1)
- `.orchestrator/config.yml` `wiki.landing_cards:` schema (new, FR-2/FR-3/FR-4)
- `wiki/docs/index.md` projected from card-grid template (FR-4)
- `scripts/wiki/wiki-generate-stubs.sh` — `version:` → stub `title:` projection (FR-5, MIT-01 P0 conditional-overwrite)
- `scripts/wiki/wiki-generate-nav.sh` — honor stub `title:` (FR-6)
- `.orchestrator/DECISIONS.md` — heading-shape migration (FR-7)
- `references/` authoring-convention doc (new or extension; placement is `#Q-3`) — FR-8
- `commands/dispatch.md` — payload-guidance reference to convention (FR-8)
- `mkdocs.yml` template — `navigation.tabs` + `navigation.tabs.sticky` + `toc.toc_depth: 2` + `content.action.edit` + `content.action.view` + `edit_uri` (FR-9, MIT-03 P0 CON-3 back-reference)
- Install-template emission logic for `.orchestrator/config.yml` — operator-authored-key preservation (FR-10, DISP-1 planning gate)
- Install-template fail-closed-on-malformed-YAML behavior (FR-11)

### In Scope (P02, gated on first PBJ feedback)

- `wiki.nav_buckets:` schema + tag-driven nav subgrouping in `wiki-generate-nav.sh` (FR-12)
- GitHub source-link rewrite in stub generator + Tier 1 chunk-projection pass (FR-13)
- `wiki.knowledge_cards:` schema (or scoped reuse of `wiki.landing_cards:`; final shape `#Q-6`) — `/knowledge/` card grid (FR-14)
- `wiki/requirements.txt` — `mkdocs-tags`, `mkdocs-redirects`, `mkdocs-git-revision-date-localized-plugin` (FR-15)
- `topic_tags:` → `tags:` projection-time adapter (FR-15)

### Out of Scope (Non-Goals)

- Knowledge-graph viewer / faceted search / AI Q&A widget (`wiki-ux-deep` post-launch proposal owns)
- External-tool adapters — Jira / Notion / Obsidian sync (`external-tool-adapters` post-launch proposal owns)
- Validator-audience polish (round 4, post first PBJ feedback signal)
- `include-markdown` redesign (round-2 settled it; commits `e4c3c8f7` + `90c18f07`)
- Eliminating `DR-### / MEM-### / BG-###` codes from source content (codes are load-bearing for cross-reference)
- Source-side `version:` → `title:` field rename (read at projection time)
- mkdocs theme swap (stay on mkdocs-material, M012 commitment)
- Custom theme build
- `mkdocs-awesome-pages-plugin` adoption (defer until tag-driven grouping tested against PBJ feedback)
- P02 work before first PBJ feedback signal lands

### Knowledge-Layer Boundary (M037 vs. M020/M036a)

M037 claims: `wiki/` template files, `templates/wiki-*.tmpl` (new), `scripts/wiki/wiki-generate-*.sh` (modifications), the new `wiki.*_cards:` and `wiki.nav_buckets:` config schemas, this repo's `.orchestrator/DECISIONS.md`, `references/` authoring-convention doc.

M037 does NOT touch: `knowledge/<category>/MEM*.md` content, `.orchestrator/knowledge/KNOWLEDGE-INDEX.md`, chunk frontmatter schema (`version:`, `topic_tags:`, `external_pointer:` are read but not written), edge-type catalogue (`cites`, `derived_from`, `applies_to_field`), spec-chunk metrics, tier-0/1/2 extraction adapters.

Crossing the boundary requires a new spec.

## Design Constraints

### CON-1 — Zero new mkdocs plugin dependencies in P01

P01 (US-1..US-5) MUST land with zero new mkdocs plugin dependencies. The card-grid template uses `attr_list` + `md_in_html` (already enabled). New plugins (`mkdocs-tags`, `mkdocs-redirects`, `mkdocs-git-revision-date-localized-plugin`) ride P02 (US-9). Guards against P01 surface bloat and operator toolchain churn.

### CON-2 — Projection-not-source-mutation

All M037 transformations run at projection time. Source chunks remain authoritative.

### CON-3 — Operator-authored keys survive every template-emit path

Hard contract. Any template-emit path that violates is a P0 bug. Applies to `.orchestrator/config.yml` (FR-10) and `mkdocs.yml` (FR-9 MIT-03 back-reference). The exact scope of merge logic across template files is `#Q-4`.

### CON-4 — Default-branch fallback to `main`

FR-9 + FR-13 fall back to `main` on `git symbolic-ref` failure. Working defaults on detached / no-remote / shallow-clone fixtures.

### MIT-01 P0 — Conditional-overwrite escape hatch (FR-5 / SC-2)

The `version:` → stub `title:` projection MUST NOT overwrite stubs carrying `auto_generated: false`. Operator escape hatch. SC-2 fixture MUST exercise this case (fourth fixture: pre-existing stub with `auto_generated: false` and operator-edited `title:` value; assert byte-identical preservation across re-runs).

### MIT-02 P0 — Escape-hatch fixture (SC-2)

The SC-2 acceptance fixture is augmented with the MIT-01 escape-hatch case. Lifted to a P0 mitigation by conversus arbitration.

### MIT-03 P0 — CON-3 back-reference in FR-9

FR-9's mkdocs.yml template-emit path is in the scope of CON-3. `#Q-4` resolves whether FR-10 merge logic explicitly extends to `mkdocs.yml` or whether `mkdocs.yml` retains a separate (but equivalent-shape) merge mechanism.

### Upstream Dependencies (Hard)

- **M032 (closed 2026-05-05)** — provides `scripts/wiki/`, `mkdocs.yml` template, install-template plumbing, `wiki-init.sh`. M037 modifies these surfaces.
- **M036a (closed 2026-05-02)** — produces chunk corpus with `version:` + `topic_tags:` + `external_pointer:` frontmatter. FR-5 / FR-12 / FR-13 read these at projection time.
- **Papercut-sweep rounds 1+2** (commits `e4c3c8f7` + `90c18f07`) — closed `mkdocs build --strict` blockers. M037 starts from a clean baseline. SC-10 tests for *no new warnings* introduced by M037, not for absolute zero-warning state.

### No Hard Dependency

- M033, M035, M036b. M037 P01 ships standalone.

### Pre-Launch Urgency

M037 jumps queue ahead of M035 because PBJ-central is the live dogfood signal for the entire orchestrator process and opens the wiki this week. Wiki-quality noise would contaminate the validation loop M035-launch is supposed to ride into release. Sequencing rationale captured in CLAUDE.md and `.orchestrator/proposals/launch-sequencing-amendment-2026-05-03.md`.

## Open Questions

These are the seven `#Q-*` items the spec defers to planning. Each must be resolved (or explicitly re-deferred) during `/orchestrator-plan-phase` for the phase that owns the FR they touch.

### #Q-1 (P01) — `wiki.landing_cards:` schema: minimal-viable vs extended

Should the schema be minimal-viable for P01 (icon + title + blurb + section, no advanced features like cards-per-row, card-color, badge-overlay) with extensions deferred to P02 / round 4? **Brief leans minimal-viable.** Planning confirms based on first-pass implementation cost.

### #Q-2 (P01) — Default-landing-card content shape

When a project has not customized `wiki.landing_cards:`, what generic blurbs ship? Auto-generated from section name (`"Constitution"` → `"Project constitution. <section_count> principles."`) or hand-authored generic strings keyed on section name? Planning decides based on defaults' readability.

### #Q-3 (P01) — DR-### heading-convention rollout strategy + `references/` doc placement

(a) Does the FR-7 heading-shape pivot apply retroactively to existing `.orchestrator/DECISIONS.md` content across consumer projects (operator runs a one-shot rewriter), or only to new entries authored after the convention lands? **P01 commits to retroactive migration on this repo only**; consumer-project rollout strategy decided at planning.

**(b) Resolved (2026-05-06)**: The convention doc lands as a new `references/authoring-conventions.md`, not an extension of `references/architecture.md`. Reasoning: `architecture.md` covers *how the orchestrator works* (state machine, dispatch, knowledge graph); authoring conventions cover *how to write content the orchestrator consumes* — different audience (artifact authors, including LLM-dispatched task agents reading via `commands/dispatch.md` payload guidance per FR-8) and different growth trajectory (chunk-frontmatter conventions, spec-shape conventions will accrete over time). Co-locating in `architecture.md` would make it a kitchen sink.

### #Q-4 (P01) — Clobber-fix scope: config.yml only vs all template files

**Resolved (2026-05-06)**: A single shared merge primitive applies to both `.orchestrator/config.yml` (FR-10) and `mkdocs.yml` (FR-9 MIT-03 P0 back-reference). Reasoning: MIT-03 P0 already mandates byte-identical preservation for `mkdocs.yml`; two separate merge mechanisms would create drift. The merge primitive is YAML-key-preservation against a managed-namespace-list — file-agnostic by design, parameterized over (file path, managed-namespace list). Marginal complexity of parameterization is much smaller than maintaining two parallel implementations. **Implementation note for plan-phase**: FR-9 + FR-10 collapse into a single shared-primitive task with two consumers, not two independent tasks. Plan-phase's task decomposition should reflect this.

### #Q-5 (P01) — Wiki config schema versioning

Once `wiki.landing_cards:` lands as a real schema, do we owe schema-evolution handling for projects on older configs? Or accept "missing key = use defaults" as the forward-compat strategy? **P01 ships forward-compat-by-default**; explicit schema-evolution handling deferred to a future schema-evolution milestone.

### #Q-6 (P02) — P02 trigger condition + knowledge-card final config shape

**(a) Resolved (2026-05-06)**: P02 entry is gated on a concrete threshold — **≥3 nav-or-section-shape feedback items filed by PBJ team against the P01 wiki**. Reasoning: calendar triggers risk shipping P02 before signal arrives (defeats the deferral); pure operator-judgment is too easy to retroactively justify when momentum builds. N=3 is small enough to fire fast on any active dogfood, large enough to weed out one-off complaints, and concrete enough to audit. Operator override available if PBJ review is unexpectedly quiet — concrete defaults are reversible.

**(b) Deferred to P02 plan-phase**: US-8's final config shape (`wiki.knowledge_cards:` standalone vs. `wiki.landing_cards:` reused with section scoping) and the power-user URL (`/knowledge/_index/` vs. alternative) remain gated on the first PBJ signal informing the choice.

### #Q-7 (P01) — Verifier surface for DR-heading-shape

Does FR-3-shape verification belong in `scripts/verify/spec-shape-lint.sh`, a new `scripts/verify/decisions-shape-lint.sh`, or a pre-merge wiki-build smoke gate? Planning decides based on where the verification cost is best amortized.

### Operator-driven (resolved cadence)

- **#Q-OP-1 — DISP-1 managed-key namespace list cross-reference (Resolved 2026-05-06)**: Operator-confirmation gate fires at **plan-time**, not implementation-time. The plan-phase output for the FR-10/FR-9 shared-primitive task carries a `## Managed-Key Namespace Cross-Reference` section listing each proposed orchestrator-managed namespace alongside the PBJ-central `.orchestrator/config.yml` (and `mkdocs.yml`) keys it covers, with collision flags. Operator approves the plan (or pushes back on specific classifications) before any implementation begins. Reasoning: arbiter ruling specifies "named cross-reference in the phase plan" — by implementation-time the artifact already exists and operator pushback creates rework. Plan-time gates also pair naturally with `commands/plan-checker.md` for retroactive auditability.
