---
schema_version: "1.0"
type: feature-spec
feature_slug: "040-wiki-readability-decorator"
created_at: "2026-05-08"
status: "Ready-for-discuss"
milestone: "M040"
---

# Feature Specification: 040-wiki-readability-decorator

**Feature Branch**: `040-wiki-readability-decorator`
**Created**: 2026-05-08
**Status**: Ready-for-discuss
**Milestone**: M040
**Predecessor**: This spec is the Principle XIV "spec amendment" gate that
the deleted `scripts/wiki/wiki-decorate-codes.sh` stub explicitly called for
in its header comment (lines 6–7, 35–36 of the deleted file): *"Surface
exists; polish deferred to post-launch wiki-UX-deep proposal (per Principle
XIV: ship the interface so downstream proposals build against a known shape;
do NOT expand scope without spec amendment)."* This amendment is that
post-launch deep proposal, scoped against the dogfood-validated shape that
already shipped and proved itself in `pbj-central-mono-repo` Phase 1.
**Input**: Backport the wiki readability decorator from
`pbj-central-mono-repo` Phase 1 (validated end-to-end: 235 stubs decorated,
2628 in-scope links, 0 broken, `mkdocs build --strict` clean) into the
upstream framework so every consumer project gets the readability rollout
on the next `orchestrator:update`.

## Promise

Every wiki page that renders an orchestrator artifact (milestone CONTEXT,
phase plan, decision page, task plan, knowledge entry, reference chunk)
loads with codes (DR-/AN-/BG-/OD-/MEM-/Q-/MIT-/…), file paths
(`.orchestrator/<rest>.md`, `knowledge/<rest>.md`), section references
(`§N[.N…]`), and milestone names rendered as live hyperlinks with
hover-tooltip titles, plus a per-page plain-English admonition (when the
operator has authored a sibling `<page>.summary.md`). The reader who lands
on `/decisions/` or `/milestones/<name>/` sees scannable concepts rather
than opaque code-soup; hovering any code reveals its one-line title;
clicking any path navigates to the rendered wiki stub.

## Problem Statement

Orchestrator-managed wiki content is dense with codes that are
load-bearing for cross-references and grep-ability but opaque on first
contact for a non-author reader. PBJ-central's pre-validator-pilot wiki
pass (2026-05-07) surfaced the impact: every milestone CONTEXT, every
phase plan, every decision page reads as code-soup with constant
cross-referencing required. The `pbj-central-mono-repo` Phase 1 prototype
landed a working decorator that fixed all four readability surfaces
(codes, paths, §-refs, milestone-names) and proved itself end-to-end in
the validating-dogfood pass: `mkdocs build --strict` clean, 235 stubs
decorated, 2628 in-scope links, 0 broken. But the deliverables live under
`scripts/` which the PBJ project gitignores (framework code lives
authoritatively in the upstream framework repo); without this upstream
backport the next `orchestrator:update` would wipe the rollout.

The framework already shipped a Principle-XIV stub at
`scripts/wiki/wiki-decorate-codes.sh` for exactly this surface. The stub
header (lines 5–7, 35–36) explicitly named "post-launch wiki-UX-deep
proposal" as the spec-amendment gate. This amendment IS that gate.

## Functional Requirements

FR numbers continue from M037's series (last assigned: FR-22 in M037).

- **FR-23 (walk-every-stub decorator)**: A new
  `scripts/wiki/wiki-decorate-build.py` walks every `wiki/docs/**/*.md`
  stub that contains an `include-markdown` directive whose target
  resolves under `.orchestrator/` or `knowledge/`. For each, it decorates
  the included markdown into `wiki/.staged/<same-relative-path>` and
  rewrites the stub include directive to pull from `.staged/` with
  `rewrite-relative-urls=false`. Decoration covers the four surfaces:
  codes (DR-/AN-/BG-/OD-/MEM-/etc.), bare path references
  (`.orchestrator/<rest>.md`, `knowledge/<rest>.md`), `§N[.N…]` tokens
  resolved against nearby path-link context (~80 char window), and bare
  milestone names matching a directory under
  `wiki/docs/milestones/<name>/`.

- **FR-24 (sibling-summary-md convention)**: For each stub whose
  rendered page would benefit from a plain-English overview, the
  operator authors a sibling file `<stub>.summary.md` (3–5 short
  paragraphs in plain prose, no codes). The decorator wraps the body in
  a Material `!!! info "In plain English"` admonition prepended to the
  stub. Marker-tagged for idempotent re-application; an absent sibling
  strips a stale admonition and adds the stub to a `/tmp/wiki-summary-
  todo.md` manifest (operator-discoverable backlog).

- **FR-25 (pipeline integration)**: The decorator runs in the regen
  sequence for `wiki-serve.sh` (between stub-gen and nav-gen), inside
  the freshness-check `wiki-stubs-fresh.sh` against the staged tmp
  tree, and in the `pages.yml` GitHub Actions workflow that
  `wiki-init.sh::emit_pages_workflow()` templates into consumer
  projects (between the freshness-check step and `mkdocs build`).
  Cross-version compatibility gates (`[ -f scripts/wiki/wiki-decorate-
  build.py ]`) protect consumer projects on pre-readability-rollout
  runtimes from breakage; the freshness-check and pages.yml emit a
  visible skip diagnostic when the decorator is absent.

- **FR-26 (.orchestrator/config.yml-driven config)**: The decorator
  generalizes via two new keys under the `wiki:` namespace in
  `.orchestrator/config.yml`:
    - `wiki.code_prefixes:` — list of prefix strings to scan as
      pipe-table column-A codes (e.g., `[AN, BG, OD]`).
    - `wiki.spec_paths:` — list of `.orchestrator`-relative paths to
      spec markdown files containing pipe-table-coded rows.
  Both default to empty lists; with empty lists the decorator still
  operates against `.orchestrator/DECISIONS.md` alone (zero-config
  behavior so every orchestrator-managed project gets DR-### links for
  free regardless of project-specific spec conventions).

- **FR-27 (managed-gitignore extension)**: `wiki/.staged/` is added to
  the canonical `emit-managed-gitignore.sh` body so consumers don't
  accidentally commit decorator output. Marker-delimited block
  preserves operator edits outside the block.

## CI runtime posture (Option B — verbatim-mirror fallback)

**The structural gap.** The framework's managed-gitignore (per
`scripts/lifecycle/emit-managed-gitignore.sh`) excludes the entire
`scripts/` tree from consumer-project commits — so consumer-project CI
checkouts (`actions/checkout@v4`) never have `scripts/wiki/wiki-decorate-build.py`
on disk. The decorator step's `[ -f ... ]` cross-version gate (FR-25) is
therefore *always false in CI*, the `wiki/.staged/` tree is never
materialized, and `mkdocs build` fails with `ERROR - No files found
including '../.staged/<rel>'` once any stub has been rewritten by a local
decorate run. This was first surfaced in `pbj-central-mono-repo` after
commit `4a11407` (2026-05-08); the upstream handoff is at
`/tmp/upstream-handoff-pages-decorator-ci-gap-2026-05-09.md` (preserved
here as `proposals/`-equivalent reference).

**Chosen posture: Option B (verbatim-mirror fallback in the workflow
template).** The decorator step's `else` branch — when
`scripts/wiki/wiki-decorate-build.py` is absent — copies `.orchestrator/`
verbatim into `wiki/.staged/` so mkdocs include directives resolve. CI
deploys ship **stub-baked admonitions** (the `!!! info "In plain English"`
blocks the decorator wrote into stubs at local-preview time, which ARE
committed) but **NOT body-text hyperlink decoration** (codes / §-refs /
bare paths / bare milestone names render as plain text in CI deploys
because the verbatim mirror skips decoration). Local previews retain full
decoration via the regen sequence in `wiki-serve.sh`.

**Why not Option A (install orchestrator at CI time)?** Option A is the
architecturally clean answer — preserves `scripts/`-as-framework-managed,
ships full decoration in CI — but requires a published install endpoint
(`https://raw.githubusercontent.com/<org>/spec-kit-orchestrator/<tag>/packaging/install/install-claude-code.sh`)
to pin against. M035 packaging (npm + homebrew + curl-pipe-bash) is
in-flight and *constitutes the launch event*; no canonical release tag
exists yet. Wiring CI to a not-yet-published endpoint is premature
coupling.

**Why not Option C (move decorator out of `scripts/`)?** Breaks the
"framework code lives authoritatively upstream, consumer projects
gitignore it" architecture rule. Consumers would lose
`orchestrator:update --force` regenerating the script; script versioning
would fragment across consumer repos.

**Why not Option D (commit `wiki/.staged/`)?** Every decorator run
mutates 60–100 files; merge conflicts on every PR that touches
`.orchestrator/`; defeats the gitignore rationale.

**Upgrade path (post-M035 follow-up).** Once M035 P02–P06 publish a
stable install endpoint, the workflow template's `else` branch should
flip from verbatim-mirror to *install-at-CI-time* (Option A): pin a
release tag in `.orchestrator/config.yml`, have the workflow `curl |
bash` the per-runtime installer with a `--scripts-only` flag (yet to
ship), then run the decorator. Tracked as a post-launch demand-driven
follow-up under `external-tool-adapters` / `wiki-ux-deep`.

## Migration

- **`scripts/wiki/wiki-decorate-codes.sh` deleted.** The Principle-XIV
  stub it shipped (per its header comment lines 5–7 + 35–36) was the
  deliberate-deferral surface; this spec amendment IS the deferred deep
  proposal, and the new decorator supersedes the stub cleanly.
- **No shim.** The deleted stub took `--in/--glossary/--out` and ran
  page-by-page; the new tool walks every stub by default and offers
  `--only <relpath>` (relative to `wiki/docs/`) as the per-page
  equivalent for consumers who scripted around the page-by-page
  invocation.
- **Consumers on pre-Phase-2 runtimes.** Cross-version gates in
  `wiki-stubs-fresh.sh` and the `pages.yml` workflow template skip the
  decorate step when `scripts/wiki/wiki-decorate-build.py` is absent,
  so pre-`orchestrator:update` consumer projects continue to build.
- **Consumers on the readability-rollout-but-pre-CI-fallback workflow.**
  Any consumer project that ran `wiki-init.sh` between commit `69293440`
  (M040 backport, 2026-05-08) and the CI-fallback amendment lands has
  the bare `echo skip` shape in `.github/workflows/pages.yml`. After this
  amendment lands, those consumers must re-emit the workflow — either
  delete `.github/workflows/pages.yml` and re-run `wiki-init.sh`, or
  manually fold the verbatim-mirror `else` branch from
  `scripts/lifecycle/wiki-init.sh::emit_pages_workflow()` into their
  workflow file. PBJ-central is the canonical case (workaround at
  commits `26a1f35` + `c4701af`); after the upstream amendment lands,
  PBJ should drop its local workaround and re-emit.

## Validating Dogfood

`pbj-central-mono-repo` Phase 1 (handoff at
`~/Sites/pbj-central-mono-repo/.orchestrator/knowledge/UPSTREAM-PATCH-HANDOFF-wiki-readability-2026-05-08.md`)
landed the decorator locally and validated end-to-end:

- 235 wiki stubs decorated.
- 2628 in-scope hyperlinks emitted.
- 0 broken in-scope links (`scripts/diagnostics/wiki-link-check.sh`).
- `mkdocs build -f wiki/mkdocs.yml --strict` exits 0.
- Live preview: <https://ubiquitous-couscous-6qr8nor.pages.github.io/>.

Phase 2 (this amendment) is the byte-for-byte upstream backport with
PBJ-specific lines generalized via `wiki.code_prefixes:` +
`wiki.spec_paths:`. Post-Phase-2 dogfood expectation: a clean
`orchestrator:update` against PBJ + re-running `wiki-serve.sh`
produces byte-identical decorated output to the Phase 1 prototype.

## Anti-goals (verbatim from predecessor)

These bound the decorator's scope so future maintainers don't expand it
without re-amending the spec:

- **Don't auto-generate plain-English summaries** with an LLM. The value
  is editorial; machine-generated prose drifts from intent.
- **Don't auto-inject `{ #an-007 }` anchors** into source spec markdown
  to fix the spec-table-row anchor gap. The current decorator drops the
  fragment + keeps the page-link with tooltip; that's the agreed shape.
- **Don't expand decoration to other patterns** beyond the six surfaces
  shipped: codes / paths / §-refs / milestone-names / case-insensitive
  resolution / anchor-verify. (Specifically: DR-numbered cross-doc
  references, full-text cross-linking, glossary auto-derivation are
  out-of-scope.)
- **Don't ship Phase 2 without the synthetic-project test fixture.**
  The fixture-backed acceptance test is the self-contained proof; the
  PBJ dogfood pass is the second validation layer.
- **Don't mutate `.orchestrator/` source files** in any consumer project
  for any reason. The decorator is read-only over them.
- **Don't author plain-English summaries** for the synthetic fixture —
  leave them blank so the missing-summary manifest path is exercised by
  the test.

## Acceptance

The fixture-backed acceptance harness lives at
`tests/m040-acceptance/p01-decorator-acceptance.sh` and exercises the
synthetic project under `tests/fixtures/wiki-readability/`. It must
report pass on:

1. `python3 scripts/wiki/wiki-decorate-build.py --root <fixture>` exits 0.
2. `python3 scripts/wiki/wiki-decorate-build.py --root <fixture>
   --print-map` emits the expected code-map (snapshot comparison).
3. The decorated `wiki/.staged/` tree matches a snapshot for at least
   one representative page (link count, tooltip-title strings, anchor
   presence on resolvable codes, anchor-dropped on unresolvable codes).
4. Re-running the decorator on unchanged source produces byte-identical
   output (idempotency check).
5. `/tmp/wiki-summary-todo.md` is emitted listing every fixture stub
   without a `<stub>.summary.md` sibling (the fixture deliberately
   leaves them blank — anti-goal #6 above).

## Rollout

1. Phase 2 (this amendment's deliverables) lands upstream.
2. Operator runs `orchestrator:update` against PBJ.
3. Operator verifies the Phase 1 prototype is now superseded — the
   local `wiki-decorate-build.py` at PBJ comes from upstream;
   re-running `wiki-serve.sh` produces identical decorated output.
4. PBJ-side commit lands the `.gitignore` + `pages.yml` + 75 stub
   updates + `mkdocs.yml` deliverables (the decorator itself is now
   framework-tracked and stays out of the project commit).
5. **CI-gap amendment (this revision, 2026-05-09).** Operators on the
   readability rollout MUST re-run `wiki-init.sh` (or
   `orchestrator:update`) to pick up the verbatim-mirror fallback in
   `.github/workflows/pages.yml`. Without it, the next CI deploy after
   any local decorator run will fail at `mkdocs build` with `No files
   found including '../.staged/<rel>'`. The fixture-driven acceptance
   test at `tests/m040-acceptance/p02-pages-ci-fallback.sh` simulates a
   consumer-CI checkout (no `scripts/` present) and asserts the
   verbatim-mirror `else` branch materializes `wiki/.staged/` so
   mkdocs build succeeds against rewritten stubs.
