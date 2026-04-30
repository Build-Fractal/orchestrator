# Proposal: M032 — Wiki Distribution + Init Integration

**Captured**: 2026-04-28 during pbj-central-mono-repo team-onboarding session
**Shape**: Milestone (3 phases + optional P00 baseline) — collapsible to 2 quick PRs depending on bundle-architecture call
**Predecessors**: M012 (built the dogfood wiki, this repo only), M013 (taught us the cost of shipping a codepath that was never tested against real-project shape), M025 (installer coexistence — covers user-global skills/hooks but not project-local assets), M027 (cost+quality observability — adopted into wiki nav already)
**Source**: 2026-04-28 session — operator started new project `pbj-central-mono-repo`, wanted team-onboarding via wiki + Giscus comments, discovered wiki tooling does not ship in `packaging/bundle/manifest.yml` and `orchestrator:init` has no concept of project-local assets. Same session surfaced M013/M014 walker-contract bug — both findings caused by "M012/M013-era infrastructure ships fine for this repo's self-hosting but doesn't cross the install boundary."

## Goal

Make `orchestrator:init` produce a working, reviewable, comment-enabled wiki for any new orchestrator-managed project — without hand-stitching across `wiki/`, `scripts/wiki/`, `scripts/diagnostics/wiki-giscus-*.sh`, `mkdocs.yml`, and the Giscus theme override. End state: a fresh `git init`'d project, after `orchestrator:init --with-wiki --deploy`, has a live mkdocs Material wiki at the project's GH Pages URL with Giscus comments wired against the project's own GitHub Discussions, fully populated by whatever spec/roadmap/plan content has been ingested into `.orchestrator/` and `knowledge/`.

## Why M032 (not extending M012 / M025)

M012 shipped the dogfood wiki for this repo. Its scope was correctly bounded — "render `.orchestrator/**.md` for *this* project's team" — and the wiki tooling lives in this repo's `wiki/` and `scripts/wiki/` because that's where M012 put it. Extending M012 would re-open a closed milestone.

M025 (installer coexistence, shipped 2026-04-23) covers user-global install drift across runtimes (`~/.claude/`, `~/.codex/`, etc.). Its surface is *user-global skills + hooks*. M032's surface is *project-local assets* (mkdocs config, theme overrides, Python deps, project-scoped helper scripts). Different surface, different invariants — doesn't fold cleanly.

Naming as a new milestone keeps M012's verification artifacts immutable, lets M025's user-global invariants stay clean, and gives M032 its own success criteria.

## Why this is load-bearing for Principle XVI

The constitution-amendment proposal (`.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`) introduces Principle XVI — Distribution Surface Integrity — with three invariants: single-source versioning, force-include discipline, end-to-end install testing. M032 is **the first milestone that exercises Invariant 2 (force-include discipline) and Invariant 3 (end-to-end install testing) against a project-local-asset surface, not just user-global skills/hooks.** If Principle XVI lands before or alongside M032, M032 becomes its first compliance test. If M032 ships first, Principle XVI's eventual landing is informed by what M032 actually had to design.

Either ordering works. They reinforce each other.

## Why this is also the M013 / M014 lesson, applied

The 2026-04-28 dogfood discovered M013/M014's walker filters on a frontmatter `state:` field that `templates/phase-plan.md` never emits. Cause: M013's tests only ran against `M013_GH_STUB_DIR` synthetic fixtures, never against real orchestrator milestone shape. Effect: shipped feature, zero real coverage, blocker on first dogfood.

M032 must not repeat this. Every phase below carries an integration test against a *fresh fixture project* (not a synthetic stub), and P03's success criterion is an end-to-end install run against a throwaway GH repo with assertions on the live wiki URL.

## Existing infrastructure (do not duplicate)

- `wiki/mkdocs.yml` — Material + include-markdown + pymdownx config; auto-nav from `wiki-generate-nav.sh`. Source pattern.
- `wiki/overrides/` — Material theme override carrying the Giscus partial. Source pattern.
- `wiki/requirements.txt` — Python deps (mkdocs, mkdocs-material, mkdocs-include-markdown-plugin).
- `scripts/wiki/wiki-scan-sources.sh` — already covers `.orchestrator/**.md` + `knowledge/<category>/MEM*.md` (M012/P02/T01). Project-agnostic; runs against `--root <project-dir>`.
- `scripts/wiki/wiki-generate-nav.sh` — produces `nav:` block. Project-agnostic.
- `scripts/wiki/wiki-milestone-titles.sh` — milestone-title humanization (last session's work).
- `scripts/wiki/wiki-{serve,deploy}.sh` — local preview + GH Pages deploy.
- `scripts/diagnostics/giscus-ids-from-gh.sh` — fetches Giscus IDs for private repos via GraphQL (the load-bearing automation; giscus.app's web setup refuses private repos).
- `scripts/diagnostics/wiki-giscus-{config-check,smoke,remap}.sh` — Giscus verification + remap helpers.
- `scripts/verify/m012-p03-mkdocs-giscus-config.sh` — config-shape verifier.
- `scripts/lifecycle/init-project.sh` — existing detect → probe → generate → installer pipeline; M032 extends with new `--with-wiki` flag.
- `packaging/bundle/manifest.yml` — current `skills:` and `hooks:` sections; M032 adds a `project_assets:` section.
- `packaging/install/install-{claude-code,codex,cursor}.sh` — current per-runtime installers; M032 adds project-asset copy step.

## Findings (root-cause analysis)

### Finding A: Project-asset distribution exists but is unmanaged (revised 2026-04-28 post-pbj-bootstrap)

**Original framing**: "Bundle manifest has no project-local-asset surface." This was wrong — a surface exists. It's just unmanaged.

**Actual evidence** (`packaging/install/install-claude-code.sh:287-330`):

```bash
# --- 4.5 Stage runtime (scripts/, templates/, references/, commands/) into project ---
RUNTIME_DIRS="scripts templates references commands"
# ...
for dir in $RUNTIME_DIRS; do
  cp -R "$src/." "$dst/"
  # ...
done
```

The installer **unconditionally bulk-copies 4 directories (1,157 files)** into every consumer project. The header comment is explicit:

> "Every commands/*.md invokes helpers via project-relative paths (e.g. `bash scripts/state/find-active-milestone.sh`). Without this stage, the first command after orchestrator:init dies with No such file or directory."

**Confirmed empirically (pbj-central-mono-repo bootstrap, 2026-04-28)**: a fresh `orchestrator:init` against a content-only project produced 1,157 framework files in `<project>/commands/`, `<project>/scripts/`, `<project>/references/`, `<project>/templates/`, plus a 1,157-line `.orchestrator/installed-files.txt` manifest, plus `AGENTS.md` (Codex-runtime fallback) alongside `CLAUDE.md`. **`packaging/bundle/manifest.yml` had nothing to do with this.** The install bypassed the bundle manifest entirely.

**Root cause** (revised): M012's wiki-tooling staging was the second instance of project-asset distribution; the first was the runtime-staging step in `install-claude-code.sh:287` that's been there since standalone cutover (M015). Neither went through `packaging/bundle/manifest.yml`. The bundle manifest's `skills:` + `hooks:` schema only covers user-global assets. Project-local distribution was implemented ad-hoc directly in the installer, with no schema, no opt-in/opt-out, no symlink mode, no version-pinning, and no awareness across the codebase that "project-asset surface" is even a concept.

**Implications for fix shape** (sharpened):

1. P01 isn't "extend bundle/install with project-asset surface" — it's **"replace existing unmanaged staging with managed `project_assets:` schema."** Bigger scope than the original framing.
2. The `project_assets:` schema must subsume what `install-claude-code.sh:287-330` does today. Migration: every directory currently in `RUNTIME_DIRS="scripts templates references commands"` becomes a `project_assets:` entry with `mode: copy` (current behavior) or `mode: symlink` (proposed clean-consumer mode).
3. **Symlink mode is high-leverage**. Today's bulk-copy means consumer projects accumulate 1,157 framework files in their git history (or maintain a `.gitignore` workaround). Symlinks resolve via `~/.claude/orchestrator-runtime/<version>/` (or equivalent) and keep consumer git histories clean. Tradeoff: Windows fragility (symlinks need admin or developer-mode); POSIX-only mode in v1 is acceptable for CC-only launch posture.
4. Per-asset `mode:` field also enables per-asset opt-in/opt-out. Wiki tooling becomes `mode: copy` (because the wiki templating sed-substitutes per-project values). Framework runtime becomes `mode: symlink` (because it's the same content for every consumer). M032's original `--with-wiki` flag pattern (Finding F) reuses this.
5. Existing `.orchestrator/installed-files.txt` manifest becomes the **source of truth for clean uninstall**, regardless of mode. Already wired correctly today; needs schema expansion to track per-asset mode.

**Fix shape (still small)**: extend `packaging/bundle/manifest.yml` with `project_assets:`. Each entry: `source:`, `target:`, `mode: copy|symlink` (default `copy` for backwards-compat). Installer §4.5 reads from `project_assets:` instead of hardcoded `RUNTIME_DIRS`. Migration is mechanical: 4 hardcoded dirs become 4 manifest entries. Schema extension ~10 lines + docs; installer change ~30 lines + symlink-mode handler.

**Impact**: today every consumer project either bloats its git history with framework copies or maintains a defensive `.gitignore` (pbj's case). M032 properly fixes this for any future consumer. Future consumers (Wiki tooling, GitHub Actions workflow files, project-local hook scripts, project-local templates) all reuse the same `project_assets:` surface with appropriate `mode:` selection.

**P00 baseline evidence (captured live during pbj bootstrap)**:
- 1,157 framework files staged into `~/Sites/pbj-central-mono-repo/{commands,scripts,references,templates}/`
- `.orchestrator/installed-files.txt` = 1,157 lines
- `AGENTS.md` generated despite runtime=claude-code (Codex-fallback always-on; possibly a separate Finding G — "runtime-targeted instruction file generation is bilateral, not gated by detected runtime")
- pbj's first commit ships with `.gitignore` excluding all four staged directories — exactly the workaround M032 P01 is designed to make unnecessary.

### Finding B: `mkdocs.yml` is not template-able per-project

**Evidence**: `wiki/mkdocs.yml:9-12` hard-codes `site_name`, `site_description`, `site_url`, and `repo_url` to `Build-Fractal/spec-kit-orchestrator` values. A consumer project copying this file as-is gets the orchestrator repo's branding and a broken Pages URL.

**Root cause**: M012's mkdocs.yml was authored for this project. No templating layer exists.

**Fix shape**: parameterize `mkdocs.yml` with `{{site_name}}`, `{{site_description}}`, `{{site_url}}`, `{{repo_url}}` placeholders matching the existing init-project.sh sed-substitution pattern (`init-project.sh:14-16` already documents controlled `|`-delimiter sed replacement). The wiki-init step resolves these from: detected git remote → derive `<owner>/<repo>` → derive `https://<owner>.github.io/<repo>/` for `site_url`, `https://github.com/<owner>/<repo>` for `repo_url`. `site_name` defaults to `<repo>` with a `--site-name` override flag. `site_description` is a `--site-description` flag, no default.

**Impact**: any project using copied wiki tooling has wrong branding. Quality-of-bootstrap blocker for the team-onboarding goal.

### Finding C: Giscus partial not parameterized + per-project IDs not flowed in

**Evidence**: The Giscus partial in `wiki/overrides/` carries hard-coded `data-repo`, `data-repo-id`, `data-category`, `data-category-id` for THIS repo. `giscus-ids-from-gh.sh` already produces the four values for any repo via `--repo <slug> --category <name>`. The output is `export GISCUS_*` lines; nothing currently consumes them.

**Root cause**: M012 wrote Giscus inline; the helper-with-export-shape was added later (last session's work) but the partial-templating loop was never closed.

**Fix shape**: parameterize the Giscus partial with `{{giscus_repo}}`, `{{giscus_repo_id}}`, `{{giscus_category}}`, `{{giscus_category_id}}` placeholders. `wiki-init --with-giscus` runs `giscus-ids-from-gh.sh`, parses the four `export` lines, sed-substitutes them into the partial. `wiki-giscus-config-check.sh` runs as a post-step verifier. Failure mode is loud (`integration-giscus-config-failed: <reason>`); reversible by re-running with corrected `--repo` / `--category` flags.

**Impact**: without this, Giscus comments are wired to the *orchestrator's* discussions, not the consumer project's. Worse than no comments — silently routes team review noise to the wrong place.

### Finding D: GH Discussions not enabled by init; no Pages-from-`gh-pages` toggle

**Evidence**: Giscus requires Discussions on (per `references/github-integration.md` § Giscus prerequisites — already documented). `pbj-central-mono-repo` may or may not have Discussions on at fresh-create. Pages-from-`gh-pages` is a separate toggle that must fire after `wiki-deploy.sh` pushes the branch. Neither is in `init` scope today.

**Root cause**: scope. `init` builds local state; remote-state mutations (Discussions, Pages) were correctly out of scope until now.

**Fix shape**: gate behind `--deploy` flag. When set:
1. `gh api --method PATCH /repos/<owner>/<repo>` with `has_discussions=true` (idempotent — no-op if already on).
2. `wiki-deploy.sh` for first deploy.
3. `gh api --method PUT /repos/<owner>/<repo>/pages` with `source: { branch: gh-pages, path: / }` (creates Pages if absent; updates source if present).
4. Print live URL to stdout.

Each step is a single `gh api` call. Idempotent. Reversible (delete `gh-pages` branch + `gh api --method DELETE /repos/<owner>/<repo>/pages` + flip Discussions off).

**Impact**: without `--deploy`, the team-onboarding flow has 4 manual GitHub steps after init. Defeats the "great first experience" goal.

### Finding E: Python toolchain not in `init`'s probe matrix

**Evidence**: `init-project.sh` probes runtime (claude-code/codex/cursor) and HOME guard. It does not probe for `python3`, `pip`, or attempt `pip install -r wiki/requirements.txt`.

**Root cause**: scope. Until M032, no orchestrator path needed Python.

**Fix shape**: under `--with-wiki`, extend the probe step to check for `python3` and `pip3`. Two failure modes to design around:
- **Missing Python**: clear diagnostic + abort. `--with-wiki` requires Python 3.8+ on PATH; suggest `brew install python3` / `apt install python3` based on detected platform.
- **Missing pip**: same shape.

Optionally (open question for `orchestrator:specify`): `init` runs `pip install -r wiki/requirements.txt` automatically vs. printing the command for the operator to run. Auto-pip is convenient but adds a side effect; manual is hygienic but adds a step. Recommendation: print + offer; don't auto.

**Impact**: without the probe, `--with-wiki` succeeds at copying tooling but fails at first `wiki-serve` because `mkdocs` isn't installed. Confusing.

### Finding F: `init` lacks a flag-progressive opt-in pattern

**Evidence**: `init` today is binary — runs the full pipeline or doesn't. No precedent for "extend init with optional sub-features."

**Root cause**: scope-creep prevention, healthy. But M032 needs three progressively-deeper opt-ins.

**Fix shape**: introduce the `--with-<feature>` flag pattern. M032 ships `--with-wiki` (default scope: copy + template). `--with-wiki --with-giscus` extends. `--with-wiki --deploy` extends further. Each extension is independent — `--with-giscus` without `--deploy` is valid (configure Giscus, don't deploy yet); `--deploy` without `--with-giscus` is also valid (deploy with empty Giscus until configured).

Future milestones consume the same pattern: `--with-github-integration` (M013/M014 + M032-equivalent polish), `--with-design-layer` (M023), etc. Each is opt-in, default-off, composable.

**Impact**: without this pattern, every feature added to init becomes either always-on (bloat) or its own command (fragmentation). The flag pattern keeps init's surface small while enabling progressive enrichment.

### Finding G: Codes-without-titles burns the reader (added 2026-04-29 — pbj wiki deploy session)

**Evidence**: PBJ's constitution renders bare code shorthand throughout — `Why: AN-011 + AUD-003 + BG-003 + BG-004` — without surfacing what those codes mean. The reader must cross-reference a separate page (or several) to understand a single principle. Same problem for orchestrator's own M-codes (M028, M030), AP-codes (AP-009), DR-codes (DR-STACK-001). The wiki today is technically complete and practically unscannable.

**Root cause**: M012 rendered raw markdown unchanged. No code-to-title resolution layer exists. The codes are the project's natural shorthand in source markdown — they shouldn't be rewritten *in source* — but the rendered wiki should decorate them inline: `AN-011 (Analyzer Trust Erosion)` linking to the definition.

**Fix shape**: build-time decorator pass. Reads a glossary file (`<project>/.orchestrator/knowledge/glossary.md` if present, or scans the codebase for code-definition patterns) → on each rendered page, regex-scan for known code patterns (`[A-Z]{2,4}-\d+`, `M\d{3}`, `DR-[A-Z]+-\d+`, `AP-\d+`) → rewrite first occurrence on each page as `CODE (Title)` linked to the definition; subsequent occurrences just linked. Configurable per-project: which patterns to scan, where to look up titles. Skip patterns that don't resolve (no broken-link noise).

**Impact**: this is the **single biggest readability blocker** for cross-company adoption (Brett's primary success criterion: "make the knowledge base accessible to everyone in the company to read, comment on, edit"). Without it, the wiki is internal-team-only — non-engineers and new hires can't navigate the cross-references. Loadbearing for the post-launch wiki-UX-deep milestone (see `.orchestrator/proposals/post-launch-wiki-ux-and-adapters.md`).

### Finding H: Real product content lives outside the wiki scanner's enumeration (added 2026-04-29, extended 2026-04-30)

**Evidence**: PBJ has canonical product content in three locations the wiki scanner doesn't see, plus the orchestrator itself has the same issue with one of them. All three matter for the cross-company-collaboration thesis (see `post-launch-wiki-ux-and-adapters.md` § Forward-Planning Lifecycle Visibility).

1. **Project-root specs**: `<project>/specs/<NNN>-<slug>/spec.md` — feature spec (262 lines for PBJ). Speckit convention; lives at project root, not under `.orchestrator/`.
2. **Project-root decisions**: `<project>/decisions/<DR-CODE>-<slug>.md` — domain decision detail (BG-002 inventory was 184 lines added in PBJ's recent architectural session).
3. **Future-planning briefs**: `.orchestrator/proposals/<name>.md` — captured stubs and full briefs for milestones not yet promoted to formal `specs/` (orchestrator has 11 today: M028, M029, M030, M031, M032, M033, M034, M035, post-launch wiki UX/adapters, papercut-sweep, constitution-amendment). PBJ has none today but will accumulate them as the project matures. **This is the workflow surface where cross-company input shapes the plan before it hardens** — by far the highest-leverage of the three for the engagement-loop goal.

The scanner's current enumeration is `.orchestrator/**.md` minus tmp/scratch/config + `knowledge/<category>/MEM*.md`. Despite being under `.orchestrator/`, the `proposals/` directory falls outside the categorization (`top:*`, `milestone:*`, `archive:*`) — so it's silently dropped by the categorizer, not by an exclusion rule.

Also surfaced: **flat knowledge files** like `.orchestrator/knowledge/analysis-object-schema.md` (90 lines) — a knowledge entry that's *not* under a category subdir and doesn't follow the `MEM###` naming, so the M012/P02/T02 knowledge-rendering pattern misses it.

**Root cause**: M012's scanner was scoped to the orchestrator's own state-tree shape *as it existed in M012*. Two sources of drift since then:
- Consumer projects have richer content layouts (specs/, decisions/) that the scanner doesn't model.
- The orchestrator's own state tree grew a `proposals/` directory (M027-era) that the M012 scanner predates and doesn't enumerate.

**Fix shape**: extend the scanner with three additive enumerations:
1. **`proposals/` as a top-level category** (in-tree fix, no config needed — same pattern for orchestrator and consumer projects). Adds `top:proposals` enum value, renders under a "Forward Plans" or "Proposals" or "Roadmap" nav section (naming TBD — see Open question below). Each entry's lifecycle stage is exposed via a frontmatter `stage:` field (`stub | brief | specified | active | closed`); the wiki renders a stage badge per entry. This is the load-bearing piece for the engagement-loop goal.
2. **`wiki.extra_dirs:` in `<project>/.orchestrator/config.yml`** — list of additional project-root dirs whose `.md` files render under a configurable nav section. Default empty. PBJ-style usage: `[specs/, decisions/]`.
3. **Flat-knowledge support** — also pick up `.orchestrator/knowledge/*.md` files (no category subdir) under a "Knowledge — Flat" section, separate from categorized entries.

All three are pure scanner extensions — no template changes, no nav-format changes. Generator adds new sections only when matching content exists.

**Open question for spec**: nav section name for `proposals/`. "Proposals" is technically accurate but reads like internal jargon to non-technical readers. "Roadmap" reads to non-technical readers but conflates with the formal `M###-ROADMAP.md` artifacts under each milestone. "Forward Plans" is a compromise that dodges both. Recommend `orchestrator:specify` resolves with one of: (a) "Roadmap" with the milestone-internal roadmaps renamed "Phase Map"; (b) "Forward Plans" as the wiki section, internal docs keep "proposals" as a directory name; (c) "Proposals" with a one-line introduction-paragraph at the section index explaining what it is.

**Impact**: without proposals/ in the wiki, the cross-company-collaboration goal has a hole — engineering can see future plans by reading `.orchestrator/proposals/`, but non-technical contributors can't comment on plans before they're formal specs. By that point, plan direction is mostly locked in. **The engagement loop only closes when stage 1–3 artifacts (stub / brief / specified) are visible alongside stage 4–5 (active milestone / closed). Today only 4–5 ship.**

For specs/ and decisions/: today every consumer project must either move their content under `.orchestrator/` (violates Speckit convention) or hand-author include stubs (what we did for PBJ — reproducible workaround, but high-friction).

### Finding I: Auto-generated nav clobbers user-added entries (added 2026-04-29)

**Evidence**: `wiki-generate-nav.sh` rewrites the entire `nav:` block between `# >>> M012-P01 nav` and `# <<< M012-P01 nav end` markers. Any nav entries the operator hand-added (today's PBJ workaround for Finding H — Spec, Domain Decisions, Knowledge-as-section) are silently destroyed on next regenerate.

**Root cause**: M012/P01/T04 designed the nav as wholly auto-generated. No "user customization" surface.

**Fix shape**: split the nav block into two regions:
- `# >>> auto-nav` ... `# <<< auto-nav end` — managed wholly by the generator (Constitution / Decisions / Knowledge / Milestones).
- `# >>> custom-nav` ... `# <<< custom-nav end` — preserved verbatim across regenerates. Default empty; operators add Spec / Domain Decisions / project-specific top-level entries here.

Generator merges the two at output time. ~15 lines of awk in `wiki-generate-nav.sh` to read+preserve custom block; no schema change.

**Impact**: today, any operator workaround for Finding H is throwaway after first regenerate. With this fix, custom entries persist across the regen lifecycle. Loadbearing for Finding H's "hand-author include stubs" workaround being viable.

### Finding J: `mkdocs gh-deploy` uses cwd's git remote — silent cross-project hazard (added 2026-04-29)

**Evidence**: `mkdocs gh-deploy` builds the site, then `git push <cwd's origin> gh-pages --force`. If the operator runs `mkdocs gh-deploy -f /path/to/project-A/wiki/mkdocs.yml` from inside `/path/to/project-B/`, the build reads from project A but the push goes to project B's remote. Today's session lost ~1 minute restoring `Build-Fractal/spec-kit-orchestrator`'s `gh-pages` after PBJ's wiki content force-pushed there. Prior gh-pages SHA was recoverable via reflog; without reflog, would have been a real loss.

**Root cause**: `-f <config>` was added by mkdocs to support cross-config builds, but `gh-deploy`'s git-remote inference is cwd-bound. Mismatch is invisible until the push line.

**Fix shape**: `wiki-deploy.sh` (already exists) becomes the *only* documented deploy path for consumer projects. It does an explicit `cd "$PROJECT_ROOT"` before `mkdocs gh-deploy`, plus a sanity check: parse `repo_url:` from `mkdocs.yml`, compare to `git -C <cwd> remote get-url origin`, fail closed on mismatch. Add this gate to `wiki-deploy.sh` regardless of M032's other work — it's a 5-line patch.

Documentation update in `wiki/README.md`: explicitly warn against direct `mkdocs gh-deploy -f` usage; point to `wiki-deploy.sh`.

**Impact**: silent cross-project force-push. Even with reflog rescue, a confidence-eroding bug. The `wiki-deploy.sh` gate makes this class of error impossible regardless of operator carefulness.

### Finding K: Domain glossary is not a first-class wiki artifact (added 2026-04-30 — mattpocock/skills review)

**Evidence**: the consumer wiki today renders `.orchestrator/**.md` + `knowledge/<category>/MEM*.md` (Finding A row 1, M012/P02/T01 wiki-scan-sources). It has no convention for a *domain glossary* — the project-specific vocabulary of nouns and verbs that callers, agents, and reviewers all need to share. `mattpocock/skills::grill-with-docs` (MIT) ships this as `CONTEXT.md` at project root, with two enforced disciplines:

1. **Update inline as terms resolve** — never batch glossary updates to the end of a session. The moment the user disambiguates "materialization cascade" from "lesson rendering," the entry lands.
2. **Only domain-meaningful terms** — no implementation specifics; the glossary is the cross-section of *what the project means*, not *how the project is built*. Implementation-shaped notes belong in MEMs or ADRs.

The orchestrator already has surfaces for *decisions* (`DECISIONS.md`, MEM030/MEM031 conventions) and *patterns* (`knowledge/patterns/`). The glossary is the missing surface — it lives upstream of those because deciding requires already-shared vocabulary.

**Root cause**: M020 closed the knowledge layer with kinds `pattern | convention | lesson | decision` plus spec-chunk subkinds. No `glossary` kind. M012 wiki-scan-sources had no glossary path to render.

**Fix shape (load-bearing for M033)**: M032 adds a project-glossary surface with three pieces:

- **Path convention**: `wiki/glossary.md` at project root, single file, alphabetized term entries with one-line definitions and at most a two-line elaboration. (Multi-context projects fold this into Finding I's custom-nav region — operator decision, not auto-generated.)
- **Wiki rendering**: `wiki-scan-sources.sh` gets a `--include-glossary` toggle (default on) that prepends `wiki/glossary.md` to the auto-nav block as the second top-level entry after Constitution.
- **Knowledge graph integration**: a thin `scripts/knowledge/lookup-mems.sh --kind=glossary` adapter that reads `wiki/glossary.md` and synthesizes glossary records for `build-context.sh` to inject into Standard/Full payloads. Quick payloads inject only glossary terms touched by the task (per M031's `--profile=quick` traversal contract).

**Why M032, not M020**: M020's kinds are *content-shaped* (decisions vs patterns vs lessons). The glossary is *project-shaped* — one per project, single file, owned by the operator, distributed via the wiki. It rides M032's project-asset surface (Finding A revised) cleanly.

**Why this is load-bearing for M033**: M033's grilling protocol (proposal § *Adopted external pattern*) commits to *update doc inline as terms resolve*. The doc the protocol updates needs to exist before the protocol runs. M032 lands the surface; M033 P01–P02 are the first authoring path that writes into it; M033 P03 (codebase ingestion) seeds initial entries from README/manifests/directory-structure on the existing-codebase branch.

**Impact**: without this, the grilling protocol has nowhere to write resolved terms. Glossary entries either never get captured (the grilling produces shared vocabulary in-conversation but the next conversation starts from zero) or land in the wrong file (knowledge MEMs get polluted with vocabulary that should ride at the wiki/spec level). With the glossary surface in place, every M033 grilling session compounds — same as the rest of the knowledge layer per Constitution Principle VII.

**Effort**: small. Adapter scripts ≤ 80 lines total; wiki-nav extension reuses Finding I's custom-nav region; no schema change. Could ship in P01 alongside the bundle work if scope budget allows; otherwise P02 alongside `wiki-init` is the natural seam.

## Phase shape

| Phase | Goal | Key artifact | Verifies |
|---|---|---|---|
| **P00** (optional) | Empirical baseline | Manual bootstrap of `pbj-central-mono-repo` using existing pieces (no script). Captures real-world friction inventory. Decision point: collapse to 2 PRs or proceed with full milestone. | Inventory matches Findings A-F; if a finding is fictional (operator can already do X), drop it from scope. |
| **P01** | Bundle + project-asset surface | `packaging/bundle/manifest.yml` schema extended with `project_assets:` section. `packaging/install/install-{claude-code,codex,cursor}.sh` gain project-asset copy step. `wiki/mkdocs.yml`, `wiki/overrides/`, `wiki/requirements.txt`, `scripts/wiki/*.sh`, `scripts/diagnostics/wiki-giscus-*.sh`, `scripts/diagnostics/giscus-ids-from-gh.sh` listed as project assets. Schema extension docs. | Fresh fixture project → `bash packaging/install/install-claude-code.sh --project-dir <fixture>` → all wiki tooling present at expected paths. Idempotency: second run is byte-identical (extends M025's pinned-sha gate to project-asset surface). |
| **P02** | `orchestrator:wiki-init` command | `commands/wiki-init.md` + `scripts/lifecycle/wiki-init.sh`. Default scope: copy assets + template `mkdocs.yml` + template Giscus partial with placeholders + Python toolchain probe. `--with-giscus` scope: invoke `giscus-ids-from-gh.sh`, parse exports, sed-substitute partial, run config-check verifier. Both scopes idempotent. | Fresh fixture project → `wiki-init` (default) → `wiki-serve.sh` succeeds at `:8000`. Add `--with-giscus`, re-run → partial carries fixture-repo IDs; config-check passes. |
| **P03** | `--deploy` scope + `init --with-wiki` integration | P02's `wiki-init` extended with `--deploy` (Discussions on, deploy, Pages on, URL print). `orchestrator:init` gains `--with-wiki [--with-giscus] [--deploy]` pass-through. End-to-end fixture test: throwaway GH repo, run `init --with-wiki --with-giscus --deploy`, assert 200 on Pages URL + Giscus partial loads + comment-post smoke test. Reversibility test: `gh repo delete <fixture>` cleans up state with no artifacts left in this repo. | Live fixture URL responds 200 and renders nav from a synthesized `.orchestrator/` tree. Giscus iframe loads without JS console errors. Reversibility: `gh repo delete` succeeds, no orphan state. |

P00 is **strongly recommended** given the M013/M014 lesson. It's also the work that gets the operator's pbj-central wiki standing tonight (or whenever) without throwaway code — the "manual bootstrap" *is* the empirical baseline, not throwaway.

## Collapse condition

If P00 baseline shows that templating `mkdocs.yml` + the Giscus partial covers 90% of the friction (i.e., Findings B + C are the load-bearing pair, A is overkill, D and E are operator-acceptable manual steps), M032 collapses to:
- **PR-1**: parameterize `mkdocs.yml` + Giscus partial, ship templating sed pass as a standalone helper. Bundle changes deferred.
- **PR-2**: `orchestrator:wiki-init --with-giscus` as a project-local command, no `init` integration.

Total ~2 days of work instead of a 4-phase milestone. P00 is the gating data.

If P00 baseline shows the bundle/install layer is genuinely needed (because operators *will* re-bootstrap wikis across many projects, not just one), the full 4-phase scope holds.

## Sequencing options

This milestone has **two coherent slot positions**:

**Option Pre-Launch** — slot at end of pre-launch queue:
```
M028 → M030 → M031 → M032 → M029 → launch
```
- Adds ~3-7 days to launch (depending on collapse).
- Wins: launch story includes "wiki distribution out of the box for any new project." Team-onboarding via wiki becomes a Day 1 capability for any consumer.
- Costs: pushes launch out. M032 doesn't compound on later work (unlike M028/M030); skipping doesn't slow other milestones.

**Option Post-Launch Fast-Follow** — alongside M009 / M023 / M010:
```
M028 → M030 → M031 → M029 → launch (CC-only, wiki by hand)
                              ├─ M032 (wiki distribution, demand-driven)
                              ├─ M009 (multi-runtime parity)
                              ├─ M023 (design layer)
                              └─ M010 (managed agents)
```
- Launch on existing schedule.
- Wins: real-user signal informs M032's design (which findings are load-bearing? P00 baseline collects this data).
- Costs: first consumer projects need to hand-stitch wiki tooling (or use a temporary `bootstrap-wiki-into-project.sh` escape hatch from this session).

**Recommendation**: **Post-Launch Fast-Follow with P00 baseline done now** (during pbj-central onboarding). The P00 baseline is the substance — once it exists, M032's other phases are cheap mechanical work informed by real friction. Pre-launch slotting makes sense only if multiple consumer projects are queued at launch and all need wiki tooling.

## Out of scope

- Replacing mkdocs with a different static-site generator. mkdocs Material is the M012 commitment; M032 makes it portable, doesn't re-litigate the choice.
- A wiki-content-authoring command. The wiki *renders* `.orchestrator/` and `knowledge/`; authoring those is `orchestrator:specify`, `orchestrator:plan-phase`, etc. M032 doesn't add new authoring surface.
- Search backends beyond mkdocs's built-in search. Future milestone.
- Custom-domain support. GH Pages default domain only. Custom domains can be configured manually post-deploy.
- Vercel / Netlify / Cloudflare Pages adapters. GH Pages only in v1. Other targets are demand-driven post-launch.
- Wiki-side comment moderation tooling (Giscus delegates to GitHub Discussions moderation natively; nothing to add).
- Multi-language i18n in mkdocs config. Single-language only in v1.

## Open questions for `orchestrator:specify`

1. **Bundle schema**: introduce a `project_assets:` section vs. a separate `project-bundle.yml` file? Single-manifest is simpler; split-manifest cleanly separates user-global (skills/hooks) from project-local (assets) concerns.
2. **Auto-pip-install**: under `--with-wiki`, run `pip install -r wiki/requirements.txt` automatically, prompt the operator, or print the command? Convenience vs. side-effect-discipline tradeoff.
3. **Python version floor**: target Python 3.8+ (mkdocs minimum) or 3.10+ (modern feature set)? mkdocs Material's current floor; check at probe time.
4. **GH Pages deploy method**: `mkdocs gh-deploy` (mkdocs-native, force-pushes `gh-pages` branch) vs. a custom `wiki-deploy.sh` (already exists, current pattern)? `mkdocs gh-deploy` is shorter; current `wiki-deploy.sh` integrates with our diagnostic shell.
5. **Giscus category creation**: if `--with-giscus --category "Wiki Comments"` is passed and the category doesn't exist, do we create it or fail? Creation requires GH Discussions admin scope; failing is hygienic but adds a manual step.
6. **Templating engine**: continue with sed-substitution (matches `init-project.sh` precedent) or introduce a real templater (Mustache via `mustache-cli`, Jinja via Python)? sed is bash-3.2-friendly; templater adds a dep.
7. **Cross-runtime deferral**: does `wiki-init` work under codex / cursor runtimes, or is it CC-only at launch (matching the broader CC-only launch posture)? Wiki tooling is runtime-agnostic in principle (it's just markdown + Python), but `gh api` calls under `--deploy` may need per-runtime adapter wiring.
8. **Bootstrap fixture management**: where lives the throwaway-fixture project for P03's end-to-end test? `tests/fixtures/wiki-deploy-fixture/` permanent, or `tests/fixtures/_wiki_*` template-generated at test-time? M028 has the same question for cross-project replay; align answers.

## Source evidence (file paths)

- `packaging/bundle/manifest.yml` — current `skills:` + `hooks:` schema; needs `project_assets:` extension.
- `packaging/install/install-{claude-code,codex,cursor}.sh` — current installers; need project-asset copy step.
- `scripts/lifecycle/init-project.sh:1-21` — flag-parsing pattern; sed-substitution pattern documented in script header (lines 14-16).
- `wiki/mkdocs.yml:9-12` — hard-coded site identity (Finding B target).
- `wiki/overrides/` — Material theme override; carries Giscus partial (Finding C target).
- `wiki/requirements.txt` — Python deps (Finding E target).
- `scripts/wiki/wiki-{scan-sources,generate-nav,milestone-titles,serve,deploy}.sh` — already project-agnostic (accept `--root`).
- `scripts/diagnostics/giscus-ids-from-gh.sh` — Giscus ID lookup automation; load-bearing for Finding C.
- `scripts/diagnostics/wiki-giscus-{config-check,smoke,remap}.sh` — Giscus verification helpers.
- `scripts/verify/m012-p03-mkdocs-giscus-config.sh` — config-shape verifier.
- `.orchestrator/proposals/constitution-amendment-inclusion-criteria.md` § Change 3 — Principle XVI (Distribution Surface Integrity); M032 is its first project-local-asset compliance test.
- `.orchestrator/milestones/M013/M013-SUMMARY.md` — the cautionary tale on shipping infrastructure that wasn't tested against real-project shape; M032's P03 success criterion (live fixture, not synthetic stub) is the direct counter-pattern.
- 2026-04-28 session transcript — `pbj-central-mono-repo` bootstrap context and Findings A-F evidence.
