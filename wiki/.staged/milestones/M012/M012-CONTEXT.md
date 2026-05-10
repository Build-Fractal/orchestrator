---
schema_version: "1.0"
type: context-draft
milestone: "M012"
status: finalized
created_at: "2026-04-18T00:00:00Z"
finalized_at: "2026-04-18T00:00:00Z"
---

## Architectural Decisions

**AD-1: D011 criteria selection — ship cross-refs (a) only; defer (b) review state and (c) dispatch-callable query surface.**

- M012 ships **1 of 3** D011 criteria → **[M020](../../milestones/M020/index.md) is promoted** as a committed milestone (per [`.orchestrator/DECISIONS.md`](../../decisions.md) D011: ≤1 of 3 → promote).
- Rationale: (a) is a natural extension of the cross-link rewriting already in spec US4 and rides on KNOWLEDGE entries that already have MEM IDs — low marginal cost. (b) reviewed/unreviewed state and (c) a dispatch-callable query surface are speculative complexity (Constitution XIV) for a dogfood wiki: the team doesn't yet know whether a review-state UI or a query surface is the right abstraction. M020 is the correct home for those once M012 dogfooding reveals what the knowledge-layer surface actually needs.
- Consequence for roadmap: one phase covers cross-link rewriting plus MEM-entry resolution. No phase for review-state. No phase for query surface. The D011 evaluation at the close of that phase will mechanically count 1/3 and trigger M020 promotion.

**AD-2: Deploy target — same repo, `gh-pages` branch, same Discussions.**

- GitHub Pages served from this repo's `gh-pages` branch, pushed by `mkdocs gh-deploy`.
- Giscus threads land in this repo's GitHub Discussions (category chosen at deploy time).
- Rationale: lowest friction for dogfood, fewest moving pieces, one auth surface. If Discussions noise becomes a problem later, we can split to a `-wiki` repo, but deferring that decision avoids speculative infra.

**AD-3: Single-source-of-truth strategy — MkDocs include plugin (`mkdocs-include-markdown-plugin` or equivalent), no copy, no symlinks.**

- `.orchestrator/**.md` remains the canonical source. Wiki MkDocs config references those paths via an include plugin.
- No build-time copy into `wiki/docs/` (breaks SSOT unless copies are gitignored, which complicates navigation).
- No symlinks (Windows portability risk; contributors on non-POSIX systems should not be blocked).
- Rationale: Constitution VI (State On Disk Is Truth) — the orchestrator's authoritative state stays at `.orchestrator/`. The wiki is a read-only projection.

**AD-4: Archive inclusion (`.orchestrator/archive/`) — include, labeled "Archive" in nav, no date cutoff.**

- Archived milestones remain accessible because `DECISIONS.md` entries reference them (e.g., D004 references M011-era decisions). Breaking those links would degrade wiki value.
- Labeled clearly so readers know archived = historical, not current.
- No date cutoff: archive is small enough that omitting old entries provides no navigational relief.

**AD-5: Giscus mapping strategy — `pathname` + documented remap script for consolidation events.**

- Thread keyed on page path. Simple, no authoring burden, works across every page on day one.
- Tradeoff: rename or consolidation (`.orchestrator/milestones/M0xx/` → `.orchestrator/archive/M0xx/`) breaks the thread mapping by default.
- Mitigation: a documented one-time remap script (`scripts/diagnostics/giscus-remap.sh` or equivalent) transfers threads from the old path to the new path when a consolidation runs. The script ships in the same phase as the Giscus integration so it is ready when [M011](../../milestones/M011/index.md)'s first consolidation needs it.
- Revisit if dogfood reveals comment loss is common — at which point we switch to `specific` with manually-assigned terms and migrate existing threads.

**AD-6: Phase and task plan inclusion — include all `phases/**/*.md` and `tasks/**/*.md`, collapsed expandable nav sections.**

- Phase and task plans are the most-referenced artifacts during dogfooding. Omitting them defeats the wiki's point.
- Collapse per-milestone into an expandable nav tree so the sidebar remains readable.
- Rationale: MkDocs Material's collapsible nav handles this pattern natively.

**AD-7: Framework stack — MkDocs + Material theme + `mkdocs-include-markdown-plugin` (or equivalent) + Giscus + GitHub Pages.**

- Inherited as defaults from the spec's Assumptions section; no deviation.
- Locked here so planning doesn't re-litigate framework choice.

## Scope Boundaries

**In scope (M012):**

- MkDocs Material site under a single in-repo directory (tentatively `wiki/`, final name a planning decision).
- Rendering of all `.orchestrator/**.md` artifacts except files under `.orchestrator/scratch/`, `.orchestrator/tmp/`, and `.orchestrator/config/` — plus all non-markdown files (JSONL, TXT, VALIDATED markers).
- Per-page Giscus comment threads keyed by pathname.
- One-command deploy via `mkdocs gh-deploy --force`.
- Local preview via `mkdocs serve`.
- Cross-link rewriting: internal markdown links between in-scope `.orchestrator/**.md` files resolve to rendered routes; links to `knowledge/**/MEM*.md` entries resolve to their rendered pages (supports D011 criterion (a)).
- Out-of-scope link handling: flagged at build (link checker script) and either resolve to GitHub source or listed in build output.
- Link-check script that walks the built site and reports broken in-scope links (zero-tolerance for in-scope; out-of-scope enumerated).
- Giscus smoke-test script that confirms the Giscus `<script>` block is present on every generated HTML page.
- Giscus remap script for consolidation events (AD-5 mitigation).
- Home page (`index.md`) with orientation: what this site is, how to navigate, where to comment, audience (dogfood only).
- `wiki/README.md` or equivalent documenting: deploy command, local preview, Giscus config, mapping strategy tradeoffs, remap-script usage.

**Out of scope (explicitly deferred):**

- Reviewed/unreviewed state per page (D011 criterion b) — **deferred to M020**.
- Dispatch-callable query surface (D011 criterion c) — **deferred to M020**.
- Rendering `specs/**`, `commands/**`, `references/**`, `docs/**`, `README.md` — wiki covers `.orchestrator/` only.
- Rendering non-markdown artifacts (JSONL logs, TXT result files, VALIDATED markers).
- Comment classification, triage, or auto-application — **[M014](../../milestones/M014/index.md) scope**.
- GitHub Issues / Projects / Milestones sync — **[M013](../../milestones/M013/index.md) scope**.
- Automated CI deploys on push — manual `mkdocs gh-deploy` is sufficient; CI can be added post-M012 if useful.
- Editing UI / in-browser authoring — artifacts authored in-repo only.
- Staging, preview, or per-branch deploy environments — one dogfood deploy only.
- Pricing / usage / cost analytics surfaced in the wiki — **[M019](../../milestones/M019/index.md) Tier 2/3 scope**.
- Custom search beyond MkDocs default.
- Offline export (PDF, ePub).
- Access control / private deploys — GitHub Pages public is acceptable for dogfood.
- Mobile-specific UX, SEO, branded theming, accessibility audit — **M009 (Launch & Ecosystem) scope**.
- Rewriting or modernizing `.orchestrator/` content for wiki rendering — wiki is read-only projection; content changes are separate concerns.

## Design Constraints

- **Constitution VI (State On Disk Is Truth).** `.orchestrator/**.md` is canonical. The wiki is a read-only projection; no copy, no symlink-based duplication. Include-plugin-only strategy (AD-3).
- **Constitution XIV (No Speculative Complexity).** Scope is strictly what dogfood needs. D011 (b) and (c) are deferred to M020 (AD-1). No features beyond what US1–US5 require.
- **Constitution XV (Surgical Precision).** No mid-milestone scope insertion. Features not in this context are non-goals. Ship the wiki; stop.
- **Constitution VIII (Bash 3.2 compatibility).** Shipped helper scripts (link checker, Giscus smoke test, remap script, deploy wrapper if any) are Bash 3.2 compatible. No `declare -A`. No compound bash in agent-facing content (M016/[M021](../../milestones/M021/index.md) anti-pattern linter applies).
- **GitHub Pages is the deploy surface.** Build must produce a valid static-site bundle at `site/` (or `_site/`) that `mkdocs gh-deploy` pushes. No custom deploy target in M012.
- **Giscus requires GitHub Discussions enabled on this repo.** Deploy-time prerequisite; the wiki's first deploy must verify this is in place. Failure mode is loud (US2 AS-5): missing config fails the build or surfaces a "comments disabled" placeholder.
- **Include plugin must preserve MEM IDs in anchor links.** KNOWLEDGE.md entries carry IDs like `MEM-0012`; cross-link rewriting (AD-1) resolves references to those anchors. The plugin or the config must not strip or alter them.
- **Deploy command must be a single invocation.** Any wrapper script that adds steps beyond `mkdocs gh-deploy` — Giscus config validation, link check, etc. — runs as pre-build hooks, not as separate commands the user must remember (US3 AS-1).
- **Remap script is idempotent.** Running it twice on the same consolidation produces identical Discussion mappings; safe to re-run if a deploy fails mid-migration (AD-5).
- **Link checker runs at build, not at deploy.** Broken in-scope links fail the build locally before deploy; preserves fast feedback (US3 rationale).
- **MkDocs version pinned in config.** `mkdocs.yml` or `wiki/requirements.txt` pins MkDocs + Material + plugin versions so deploys are reproducible.
- **No network calls at build time other than what MkDocs needs.** No Giscus API calls, no GitHub API calls from the build — all integration happens at runtime via the Giscus `<script>` tag.
- **Single-command local preview.** `mkdocs serve` from the wiki directory (or a root-level shim that cds there) works without additional setup beyond `pip install` of pinned deps.

## Open Questions

Carried forward from the spec's `Open Questions` section for planning to resolve (not blocking finalization):

- **OQ-1**: Final wiki directory name. Spec uses placeholder `wiki/` or `docs-wiki/`. Planning picks one; consider that `docs/` is already used by the orchestrator's user guides. **Default unless planning overrides: `wiki/`.**
- **OQ-2**: Nav structure for `.orchestrator/milestones/**`. Flat list vs. grouped by status (active/archived) vs. grouped by type (current milestones / closed milestones / archive). Affects sidebar readability at ~14 milestones today.
- **OQ-3**: `DECISIONS.md` auto-generated table-of-contents for `D###` entries vs. relying on the file's own anchors. Low-cost feature if a MkDocs plugin does it; skippable otherwise.
- **OQ-4**: Git-derived "last updated" footer per page (MkDocs plugin `mkdocs-git-revision-date-localized-plugin` or equivalent). Nice-to-have; defer if it adds >1 hour to planning.
- **OQ-5**: "Propose a change" link per rendered page that opens GitHub's raw-markdown edit flow. Low-cost affordance; encourages in-context contributions. Accept or reject in planning.
- **OQ-6**: Remap-script trigger surface — does `orchestrator:consolidate` invoke it automatically when archiving a milestone, or is it a manual step? Auto-invoke is cleaner but couples M012 to `scripts/lifecycle/consolidate.sh`. Manual-only is safer.
- **OQ-7**: MEM anchor link format. KNOWLEDGE.md entries render with MkDocs' default heading anchors (e.g., `#mem-0012`) — does that suffice for D011(a) cross-refs, or do we need explicit anchor injection? Likely default suffices; verify during planning.
- **OQ-8**: Giscus strict mode (only map to existing Discussions) vs. lenient (auto-create Discussion on first comment). Affects first-comment UX and Discussions noise. Default: lenient. Revisit if spammy.

None of these block roadmap generation. Each is a phase- or task-level decision.
