---
schema_version: "1.0"
type: roadmap
milestone: "M012"
feature_ref: "022-spec-wiki"
feature_spec: "specs/022-spec-wiki/spec.md"
vision: "Dogfood-only MkDocs + Giscus site that renders `.orchestrator/` artifacts as a navigable, commentable wiki with one-command deploy."
tier: "C"
created_at: "2026-04-18T00:00:00Z"
updated_at: "2026-04-18T00:00:00Z"
---

## Phases

- [x] **P01**: Wiki scaffold & content rendering — "Running `mkdocs serve` from the repo root renders every in-scope `.orchestrator/**.md` artifact at localhost with a navigable Material sidebar."
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces:
      - `wiki/mkdocs.yml` — site config (theme, plugins, navigation, include-plugin configuration)
      - `wiki/requirements.txt` — pinned MkDocs + Material + `mkdocs-include-markdown-plugin` versions
      - `wiki/docs/index.md` — placeholder home page (finalized in P04)
      - `wiki/docs/**.md` — include-plugin stub files that reference `.orchestrator/**.md` by path
      - Nav structure: Constitution, Decisions, Knowledge, Milestone Summary, Milestones (expandable per-milestone), Archive (labeled)
      - Exclusion policy documented and enforced: `.orchestrator/scratch/`, `.orchestrator/tmp/`, `.orchestrator/config/`, non-markdown files are not rendered
      - Local preview via `mkdocs serve` produces a browsable site with all in-scope content
    - Consumes:
      - `.orchestrator/memory/constitution.md`, [`.orchestrator/DECISIONS.md`](../../decisions.md), [`.orchestrator/KNOWLEDGE.md`](../../knowledge.md), `.orchestrator/milestone-summary.md`
      - `.orchestrator/milestones/**/M###-CONTEXT.md`, `M###-EVALUATION.md`, `M###-ROADMAP.md`, `M###-SUMMARY.md`, `phases/**/*.md`, `tasks/**/*.md`
      - `.orchestrator/archive/**.md` (labeled Archive section)

- [x] **P02**: Cross-link rewriting, MEM resolution, link-checker — "Clicking an internal markdown link on the rendered site navigates to the rendered target (including KNOWLEDGE MEM entries like `MEM-0012`); the build-time link-checker reports zero broken in-scope links."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces:
      - Internal markdown link rewriting working for all in-scope `.orchestrator/**.md` targets (FR-6, SC-6)
      - KNOWLEDGE MEM-entry anchor resolution (D011 criterion (a) from AD-1) — relative references like `[MEM-0012](KNOWLEDGE.md#mem-0012)` resolve to rendered anchors
      - `scripts/diagnostics/wiki-link-check.sh` — Bash 3.2 compatible script that walks `site/` (or `_site/`), extracts all internal links, reports broken-in-scope with non-zero exit, enumerates out-of-scope targets
      - Build-time integration: link-check runs as a pre-deploy hook; local `mkdocs build --strict` mode honored
      - Documented resolution policy in `wiki/README.md`: what is in-scope vs out-of-scope for link resolution, and how out-of-scope targets (e.g., `scripts/foo.sh`) are handled (resolve to GitHub source or flag-and-enumerate)
      - The D011 mechanical evaluation for M012 runs at the close of this phase: 1 of 3 criteria shipped (cross-refs ✓, review-state ✗, query surface ✗) → [M020](../../milestones/M020/index.md) is promoted per [`.orchestrator/DECISIONS.md`](../../decisions.md) D011 and noted in P02-SUMMARY.md
    - Consumes:
      - `wiki/mkdocs.yml`, `wiki/docs/**` (P01)
      - [`.orchestrator/KNOWLEDGE.md`](../../knowledge.md) MEM entries (as cross-ref targets)

- [x] **P03**: Giscus integration, smoke test, remap script — "Every rendered page on the local build displays a Giscus comment thread below the content; the smoke-test script confirms the Giscus `<script>` block is present on every generated HTML page; the build fails loudly when Giscus config is missing; the remap script can migrate threads when an artifact is consolidated."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `wiki/overrides/partials/comments.html` (or Material theme extension equivalent) — Giscus `<script>` block rendered at the bottom of every page
      - `wiki/mkdocs.yml` Giscus config section — pathname mapping (AD-5), env-interpolated `giscus_repo`, `giscus_repo_id`, `giscus_category`, `giscus_category_id` (not hardcoded to production values)
      - `scripts/diagnostics/wiki-giscus-smoke.sh` — Bash 3.2 compatible; walks every HTML page in the built site and confirms the Giscus script tag is present; non-zero exit on any missing page
      - `scripts/diagnostics/wiki-giscus-remap.sh` — Bash 3.2 compatible; idempotent; takes `<old-path> <new-path>` pairs and relabels Giscus Discussion titles/mappings on the target repo via `gh api`; dry-run mode; documented usage in `wiki/README.md`
      - Loud-failure behavior when Giscus config is missing: build emits a non-zero exit with a clear diagnostic (US2 AS-5); acceptance is build-fails-loudly OR explicit "comments disabled: missing config" placeholder — not silent omission
      - Mapping-strategy tradeoffs documented in `wiki/README.md` (AD-5)
    - Consumes:
      - `wiki/mkdocs.yml` (P01) — extended with Giscus configuration
      - `wiki/docs/**` (P01) — pages that receive the Giscus overlay

- [x] **P04**: Deploy pipeline, home page, first-deploy validation — "Running `mkdocs gh-deploy --force` publishes the wiki to GitHub Pages in one invocation; the home page orients readers; `wiki/README.md` documents deploy, preview, Giscus setup, and remap usage; the deployed site passes link-check and Giscus smoke-test end-to-end."
  - Risk: low
  - Depends: P01, P02, P03
  - Boundary Map:
    - Produces:
      - `wiki/docs/index.md` — finalized home page with orientation (what this site is, how to navigate, where to comment, audience scope)
      - `wiki/README.md` — consolidated operator guide: deploy command, local preview, Giscus config & env-var names, mapping strategy tradeoffs, remap-script usage, first-deploy checklist (Discussions enabled, category chosen, env vars set)
      - Pre-build hook wiring: link-check (P02) and Giscus smoke-test (P03) run before `mkdocs gh-deploy`; either failure aborts the deploy
      - First deploy performed successfully to this repo's `gh-pages` branch (AD-2); deployed URL verified end-to-end (all 5 user stories walk-through documented in P04-SUMMARY.md)
      - SC-1..SC-11 verified against the deployed site: one-command deploy (SC-4), local preview (SC-8), loud failure on missing config (SC-9), self-contained wiki directory (SC-10), Bash 3.2 compat (SC-11)
    - Consumes:
      - `wiki/mkdocs.yml`, `wiki/requirements.txt` (P01)
      - Link rewriting + `wiki-link-check.sh` (P02)
      - Giscus integration + `wiki-giscus-smoke.sh` + `wiki-giscus-remap.sh` (P03)

## Cross-Cutting Concerns

- **Bash 3.2 compatibility (Constitution VIII)** — P02, P03. P02 establishes the pattern for Bash-3.2-safe diagnostic scripts (`wiki-link-check.sh`); P03 follows (`wiki-giscus-smoke.sh`, `wiki-giscus-remap.sh`). No `declare -A`; no compound bash in agent-facing content (M016/[M021](../../milestones/M021/index.md) linter applies).
- **Single source of truth (Constitution VI + AD-3)** — P01, P02, P03, P04. `.orchestrator/**.md` is never copied into `wiki/docs/`. Every phase references canonical paths via the include plugin. Any PR that introduces a duplicate is rejected by the link-checker (P02) and by convention check during review.
- **Loud failure on missing external config** — P03 establishes; P04 verifies end-to-end. Giscus missing → build fails with a diagnostic or explicit "comments disabled" placeholder — never silent. Applies to any future external-config dependency.
- **Idempotent helper scripts** — P02 (link-check is read-only, trivially idempotent), P03 (smoke test read-only; remap script must be idempotent per AD-5 so a half-finished consolidation can be re-run safely). P04 relies on this to wire the pre-deploy hooks without fear of partial state.
- **Version pinning for build determinism** — P01 pins MkDocs, Material, and include-plugin versions in `wiki/requirements.txt`. P02, P03, P04 do not upgrade pinned versions without an explicit commit documenting the reason. Ensures dogfood deploys are reproducible across team members.
- **D011 trigger evaluation runs at the close of P02** — The mechanical evaluation per [`.orchestrator/DECISIONS.md`](../../decisions.md) D011 counts how many of the three criteria (cross-refs to `knowledge/**/MEM*.md`, reviewed/unreviewed state, dispatch-callable query surface) shipped. M012 ships 1 (cross-refs, in P02). Result: **M020 promoted** as a committed milestone. This outcome is recorded in P02-SUMMARY.md and triggers a roadmap update post-M012 to position M020 between [M014](../../milestones/M014/index.md) and [M019](../../milestones/M019/index.md) Tier 2/3 per D011's framing.
- **Failure-mode visibility in dogfood** — P02 (broken links), P03 (missing Giscus config), P04 (deploy failures): every failure mode surfaces in the terminal with enough diagnostic to act. No swallowed errors, no silent skips.
- **No mid-milestone scope insertion (Constitution XV)** — All 4 phases. Features beyond this roadmap's Produces entries are non-goals or deferred. Review-state (D011 b) and query-surface (D011 c) explicitly deferred to M020; no phase adds them opportunistically.

## Dependency Graph

```
         ┌── P02 (high risk)
         │
P01 (low) ┤
         │
         └── P03 (medium) ──┐
                            │
P01, P02, P03 ───────────── P04 (low, integration)
```

Linear representation: `P01 → {P02, P03} → P04`. P02 and P03 are independent after P01 and may execute concurrently. P04 integrates all three.

## Execution Order

1. **P01** — foundation, no dependencies. Must complete first so P02 and P03 have a rendered-site surface to extend.
2. **P02** — high risk, depends only on P01; takes priority per FR-043 (high-risk-first when dependencies are satisfied). Cross-link rewriting + MEM resolution is the novel, most-complex work; front-loading it reduces the risk of late-milestone rework. D011 trigger evaluation also runs at P02 close.
3. **P03** — medium risk, depends only on P01; can execute **concurrently with P02** if capacity allows. Giscus integration is a well-known pattern; the novel scope is the remap-script contract (AD-5) which is bounded.
4. **P04** — low risk, depends on P01 + P02 + P03. Integration phase: wires pre-build hooks, finalizes home page and README, performs the first deploy, walks all 5 user stories end-to-end. Cannot begin until upstream phases are summarized.

**Parallelization note**: In sequential execution, order is P01 → P02 → P03 → P04. In concurrent execution, P02 and P03 run in parallel after P01 completes (two-worker max; P04 waits for both). Dispatch system chooses based on capacity.

## Validation

- **No conflicting producers**: **PASS**. Each phase produces a disjoint set of files:
  - P01 owns `wiki/mkdocs.yml` skeleton, `wiki/requirements.txt`, `wiki/docs/**` stubs, `wiki/docs/index.md` placeholder.
  - P02 owns `scripts/diagnostics/wiki-link-check.sh` and the link-rewriting config blocks in `wiki/mkdocs.yml`.
  - P03 owns `wiki/overrides/partials/comments.html`, Giscus config block in `wiki/mkdocs.yml`, `scripts/diagnostics/wiki-giscus-smoke.sh`, `scripts/diagnostics/wiki-giscus-remap.sh`.
  - P04 owns the finalized `wiki/docs/index.md` content (replaces P01 placeholder), `wiki/README.md`, and the pre-build hook wiring.
  - Note on `wiki/mkdocs.yml`: P01 creates the skeleton; P02 and P03 extend distinct sections (link-rewriting config vs. Giscus config). Phase verification checks that each phase's additions land in its declared section of the file. Not a conflict because the additions are in separate config sections and each phase's diff touches only its own block.
  - Note on `wiki/docs/index.md`: P01 writes a placeholder; P04 replaces it with the finalized home page. This is a sequenced producer relationship (P01 produces, P04 supersedes), documented here for clarity. Not a conflict per our phase-ordering model because P04 explicitly depends on P01.
- **All consumed items have producers**: **PASS**.
  - P01 consumes `.orchestrator/**.md` — produced by the orchestrator's operational history, not by this milestone. External-to-milestone consumption is valid.
  - P02 consumes `wiki/mkdocs.yml` and `wiki/docs/**` — produced by P01.
  - P03 consumes `wiki/mkdocs.yml`, `wiki/docs/**` — produced by P01.
  - P04 consumes P01 + P02 + P03 outputs.
- **DAG is acyclic**: **PASS**. Edges: `P01 → P02`, `P01 → P03`, `P01 → P04`, `P02 → P04`, `P03 → P04`. No back-edges.
- **Demo sentence coverage**: **PASS**. Each demo sentence names a concrete, observable outcome verifiable by running a command or inspecting a URL:
  - P01: `mkdocs serve` → browsable localhost site.
  - P02: clicking a link → navigates correctly; `wiki-link-check.sh` → zero broken in-scope.
  - P03: rendered pages → Giscus thread visible; `wiki-giscus-smoke.sh` → script tag present on every page; missing config → build fails loudly.
  - P04: `mkdocs gh-deploy --force` → site live on GitHub Pages; home page + README present; all SCs verified.
