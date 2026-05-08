---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M032"
goal: "Land the operator-facing wiki entry surface for any orchestrator-managed project: ship `commands/wiki-init.md` + `scripts/lifecycle/wiki-init.sh` default scope (FR-5) which copies wiki tooling from the P01 `project_assets:` manifest entries, sed-substitutes `{{site_name}}` / `{{site_description}}` / `{{site_url}}` / `{{repo_url}}` placeholders in `wiki/mkdocs.yml` from the consumer git remote (FR-6), probes `python3` + `pip3` with platform-aware diagnostics and `--auto-pip` opt-in per #Q-2 (FR-12); close the FR-6 self-application loop by running `wiki-init.sh --project-dir .` against the orchestrator repo itself within the FR-6 implementation task per AD-5 / MIT-002; extend `commands/init.md` + `scripts/lifecycle/init-project.sh` with the `--with-wiki [--with-giscus] [--deploy]` flag chain whose sequential-atomicity contract per FR-11 / MIT-011 preserves init outputs on `wiki-init` failure and propagates `wiki-init`'s exit code (the M033/P05 integration contract per CON-3); land `wiki/glossary.md` as the canonical project-glossary path-convention surface (FR-15) plus the additive `--include-glossary` toggle on `scripts/wiki/wiki-scan-sources.sh` and the additive Glossary-as-second-entry placement on `scripts/wiki/wiki-generate-nav.sh`; ship `scripts/knowledge/lookup-mems.sh --kind=glossary` honoring M031's Quick/Standard/Full traversal contract per FR-16 / MIT-010 with the inline `touched`-term definition (exact-or-stemmed task-description match OR file-change-set inclusion; safe-default-no-terms fallback when neither signal is available); land the SC-3 + SC-7 acceptance scripts and the three M032/M033 paired-launch seam scripts at `tests/paired-m032-m033/seam-{A,B,C}.sh` per #Q-B; preserve P01's byte-identical install behavior at default `mode: copy` and respect the FR-22 collision invariant for every new `target:` path (CON-4)."
demo_sentence: "An operator on a fresh project (using the P01 `tests/fixtures/m032-fresh-project-fixture/` shared fixture with its remote pointing at `https://github.com/fixture-owner/m032-fresh-project-fixture.git`) runs `bash scripts/lifecycle/wiki-init.sh --project-dir tests/fixtures/m032-fresh-project-fixture/` and observes (a) `<fixture>/wiki/mkdocs.yml` written from the bundle with the four templated fields resolved from the git remote (`site_name=m032-fresh-project-fixture`, `site_url=https://fixture-owner.github.io/m032-fresh-project-fixture/`, `repo_url=https://github.com/fixture-owner/m032-fresh-project-fixture`, `site_description=` empty default), (b) `<fixture>/wiki/overrides/partials/comments.html` carrying placeholder `{{giscus_repo}}` / `{{giscus_repo_id}}` / `{{giscus_category}}` / `{{giscus_category_id}}` tokens (filled by P03's `--with-giscus` scope, not P02), (c) `bash <fixture>/scripts/wiki/wiki-serve.sh` returning HTTP 200 at `:8000` with the rendered HTML containing a `<title>` element naming the fixture project; the operator runs `bash scripts/lifecycle/wiki-init.sh --project-dir .` against the orchestrator repo itself (FR-6 self-application per AD-5 / MIT-002) and observes the orchestrator's `wiki/mkdocs.yml` resolved with the orchestrator's own identity (`site_name: orchestrator`, `repo_url: https://github.com/Build-Fractal/orchestrator`, etc.) and `bash scripts/wiki/wiki-serve.sh` continues to return HTTP 200 against the orchestrator repo unchanged; on a host with `python3` absent from `PATH` the probe exits non-zero with the platform-aware diagnostic substring `brew install python3` (darwin) or `apt install python3` (linux) and writes nothing to disk (FR-12); the operator runs `bash scripts/lifecycle/init-project.sh --with-wiki --project-dir tests/fixtures/m032-fresh-project-fixture/` and observes (a) the init step writes its outputs (`.orchestrator/`, `CLAUDE.md`, etc.), (b) the `wiki-init` step runs as a second sequential step, (c) the compound command exit code is the exit code of `wiki-init.sh` (FR-11 / MIT-011 sequential atomicity); on a forced `wiki-init` failure the init outputs remain on disk and a `wiki-pending` partial state marker is documented in stderr; `<fixture>/wiki/glossary.md` exists as a path-convention stub authored by `wiki-init.sh` with at least three example entries demonstrating the `### TERM` heading + one-line definition + at-most-two-line elaboration format (FR-15 / US-6 invariant); `bash scripts/wiki/wiki-scan-sources.sh --root . --include-glossary` (default-on per FR-15) lists `wiki/glossary.md` as the second top-level source after Constitution and `bash scripts/wiki/wiki-generate-nav.sh --root .` writes the Glossary nav entry as the second top-level entry under `# >>> M012-P01 nav` markers (additive — region-marker split is P03's job); `bash scripts/knowledge/lookup-mems.sh --kind=glossary --root .` synthesizes one record per `### TERM` heading with stable IDs derivable from the term name, and re-running emits identical IDs (idempotency); under `--profile=quick --task-description 'rename a foo'` against a glossary containing `### Foo` and `### Bar`, the adapter emits only the `Foo` record (touched per FR-16 / MIT-010 inline definition); under `--profile=quick` with neither task-description nor file-change-set provided, the adapter emits zero records (safe-default-no-terms per MIT-010); the three paired-launch seam scripts at `tests/paired-m032-m033/seam-{A,B,C}.sh` exit 0 each (Seam-A asserts the `project_assets:` schema shape M033 consumes for its 7-new-commands + 6-new-scripts shipping; Seam-B asserts the `--with-wiki` failure-propagation contract; Seam-C asserts the `wiki/glossary.md` format invariant); `bash tests/m032-acceptance/p02-wiki-init-default-scope.sh` (SC-3) and `bash tests/m032-acceptance/p0X-glossary-surface.sh` (SC-7) exit 0; `bash tools/verify/m032-p02-phase-suite.sh` emits `SUMMARY: m032-p02-phase-suite.sh pass=N fail=0`; `bash tools/verify/m032-p02-scope-guard.sh` emits `PASS: m032-p02 scope-guard ...` confirming P02 modifies only the files declared in this phase's `Files Likely Touched` list."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/ with
     m032-p02-* prefix to avoid collision with M030/M031 existing
     p02-* verifiers in the shared tools/verify/ tree. Verifier scripts
     are co-authored alongside their corresponding artifact within the
     SAME task per plan-time discipline rule 2. -->

### Truths

- `commands/wiki-init.md` exists as a new orchestrator command document with the orchestrator-canonical structure (YAML frontmatter `description:`, Title, Prerequisites / State Check, Core Workflow, Output, Idempotency, Error Handling, Referenced Scripts) per MEM012, and references `scripts/lifecycle/wiki-init.sh` as the canonical implementation. The command document declares the three composable scopes (default copy+template, `--with-giscus` deferred to P03, `--deploy` deferred to P03) but the P02 surface ships only the default scope plus the `--auto-pip` opt-in (FR-5 + FR-12 + #Q-2).
  - Check: `bash tools/verify/m032-p02-wiki-init-command-shape.sh`

- `scripts/lifecycle/wiki-init.sh` exists, is executable, and at default invocation (no `--with-giscus` / no `--deploy`) (a) reads wiki tooling from the P01 `project_assets:` manifest entries via `scripts/lifecycle/read-project-assets.sh` (FR-5 — extending the manifest with a `wiki/` entry under T01's responsibility), (b) probes `python3` + `pip3` and emits a platform-aware diagnostic per FR-12 / #Q-2 (`brew install python3` on darwin, `apt install python3` on linux) failing closed without writing if either is absent, (c) parses `git -C "$PROJECT_DIR" remote get-url origin` to derive `<owner>/<repo>` and synthesizes the four `{{...}}` placeholder values, (d) sed-substitutes the four placeholders in the staged `<PROJECT_DIR>/wiki/mkdocs.yml`, (e) leaves `<PROJECT_DIR>/wiki/overrides/partials/comments.html` carrying the four `{{giscus_*}}` placeholders verbatim (P03's `--with-giscus` scope fills them), (f) authors a `wiki/glossary.md` path-convention stub at `<PROJECT_DIR>/wiki/glossary.md` per FR-15. The script honors `--site-name`, `--site-description`, and `--auto-pip` flags. Idempotency: a second invocation against an already-`wiki-init`'d project preserves operator edits to the templated files and exits 0 with a `no changes` diagnostic (US-2 Acceptance Scenario 5).
  - Check: `bash tools/verify/m032-p02-wiki-init-default-scope.sh`

- `wiki/mkdocs.yml` has its four hardcoded site-identity fields replaced with `{{site_name}}` / `{{site_description}}` / `{{site_url}}` / `{{repo_url}}` placeholder tokens per FR-6, AND the FR-6 self-application loop is closed within this phase: `bash scripts/lifecycle/wiki-init.sh --project-dir .` has been run against the orchestrator repo itself, the four placeholders have been resolved with the orchestrator's own identity (`site_name: orchestrator — dogfood wiki`, `site_url: https://build-fractal.github.io/orchestrator/`, `repo_url: https://github.com/Build-Fractal/orchestrator`, `site_description: Browseable projection of .orchestrator/ artifacts for the dogfood team.`), and the orchestrator's own `bash scripts/wiki/wiki-serve.sh` continues to return HTTP 200 at `:8000` (FR-6 / MIT-002 — without this loop closure the orchestrator's own wiki breaks for the duration of M032 + M033 paired development). The bundle-staged copy of `wiki/mkdocs.yml` (under `packaging/bundle/`, if it ships there per the P01 `project_assets:` `wiki/` entry) carries the placeholders verbatim; the orchestrator-repo-local copy carries the resolved values.
  - Check: `bash tools/verify/m032-p02-mkdocs-templating-and-self-application.sh`

- `commands/init.md` and `scripts/lifecycle/init-project.sh` carry the `--with-wiki [--with-giscus] [--deploy]` flag chain per FR-11 with the MIT-011 sequential-atomicity contract: `init-project.sh` writes its outputs first; `wiki-init.sh` runs as a second step ONLY if `--with-wiki` was passed; if `wiki-init.sh` exits non-zero the init outputs are preserved on disk and the compound `init --with-wiki` exit code is the exit code of `wiki-init.sh` (NOT `0`). The diagnostic on `wiki-init` failure names the partial state explicitly: `init-complete, wiki-pending`. Callers (including M033/P05) can re-run `wiki-init.sh` independently without re-running `init-project.sh`. The `--with-giscus` and `--deploy` pass-through flags are recognized by `init-project.sh` and forwarded verbatim to `wiki-init.sh` (P03 implements the corresponding `wiki-init.sh` scopes; P02 only ships the pass-through plumbing).
  - Check: `bash tools/verify/m032-p02-init-with-wiki-passthrough.sh`

- `wiki/glossary.md` exists at the orchestrator-repo level as a project-glossary surface (FR-15 / US-6 / CON-6) with at least three example entries in the format mandated by US-6: `### TERM` heading, one-line definition immediately under the heading, at most a two-line elaboration paragraph below the definition. The terms are alphabetized at file scope. The same path is also created in `tests/fixtures/m032-fresh-project-fixture/wiki/glossary.md` by a successful `wiki-init.sh` invocation (the path-convention stub authored by FR-5).
  - Check: `bash tools/verify/m032-p02-glossary-format-invariant.sh`

- `scripts/wiki/wiki-scan-sources.sh` carries an additive `--include-glossary` flag (default-on per FR-15) that prepends `wiki/glossary.md` as the second top-level source entry after Constitution. The flag is purely additive — pre-M032 invocations without the flag (or with `--include-glossary=false` for explicit opt-out) emit the pre-M032 source list unchanged. `scripts/wiki/wiki-generate-nav.sh` consumes the scan output and places Glossary as the second top-level nav entry under the existing `# >>> M012-P01 nav` markers (region-marker split into `auto-nav` / `custom-nav` is P03's job — P02 ships only the additive Glossary placement).
  - Check: `bash tools/verify/m032-p02-glossary-scanner-and-nav.sh`

- `scripts/knowledge/lookup-mems.sh` exists as a thin glossary-aware adapter with a `--kind=glossary` mode that reads `<PROJECT_ROOT>/wiki/glossary.md` and synthesizes one record per `### TERM` heading. Each record's `id` is derivable from the term name (lower-case, non-alphanumeric collapsed to `-`, prefix `gloss-`); IDs are stable across re-invocations against an unchanged glossary (idempotency). The adapter honors M031's Quick/Standard/Full traversal contract per FR-16 / MIT-010: under `--profile=standard` or `--profile=full` the adapter emits the FULL glossary; under `--profile=quick` the adapter emits ONLY touched terms, where a term is `touched` per the FR-16 inline definition: (a) the `--task-description` arg contains an exact or stemmed match of the term name, OR (b) the `--file-change-set` arg lists files whose contents contain the term. When neither `--task-description` nor `--file-change-set` is supplied under `--profile=quick`, the adapter emits ZERO records (safe-default-no-terms per MIT-010 — preserves M031's budget invariant).
  - Check: `bash tools/verify/m032-p02-lookup-mems-glossary.sh`

- `tests/paired-m032-m033/seam-A.sh` (#Q-B) exists, is executable, and exits 0. Asserts the shared install-bundle surface invariant M033 consumes: the `packaging/bundle/manifest.yml` `project_assets:` schema landed in P01 carries the four runtime-dir entries AND a `wiki/` entry (added in P02/T01); the P01 reader (`scripts/lifecycle/read-project-assets.sh`) emits a tuple for each. M033 ships 7 new commands + 6 new scripts on top of this seam — the seam asserts the schema shape M033 plans against is stable.
  - Check: `bash tools/verify/m032-p02-seam-a-shape.sh`

- `tests/paired-m032-m033/seam-B.sh` (#Q-B) exists, is executable, and exits 0. Asserts the `--with-wiki` failure-propagation contract per FR-11 / MIT-011: stage a fixture; export an environment variable forcing `wiki-init.sh` to exit 7 (test-only failure injection — `M032_WIKI_INIT_FORCE_EXIT=7`); run `bash scripts/lifecycle/init-project.sh --with-wiki --project-dir <fixture>`; assert (a) the init outputs are present on disk AFTER the failure, (b) the compound command exit code is 7 (NOT 0, NOT 1 — the literal `wiki-init.sh` exit code), (c) the diagnostic names `init-complete, wiki-pending` on stderr. M033/P01..P04 stub-mode compatibility per M033-MIT-001 inherits from this contract — Seam-B is the seam M033 plans against.
  - Check: `bash tools/verify/m032-p02-seam-b-shape.sh`

- `tests/paired-m032-m033/seam-C.sh` (#Q-B) exists, is executable, and exits 0. Asserts the `wiki/glossary.md` format invariant: alphabetized term entries, `### TERM` heading style, one-line definition under the heading, at-most-two-line elaboration paragraph. M033's grilling-shell (FR-18 in M033's spec) writes inline into this file as terms resolve — the seam asserts the format M033 will honor when writing.
  - Check: `bash tools/verify/m032-p02-seam-c-shape.sh`

- `tests/m032-acceptance/p02-wiki-init-default-scope.sh` (SC-3) exists, is executable, and exits 0 against the P01 `tests/fixtures/m032-fresh-project-fixture/` shared fixture (or POSIX exit 77 / `SKIP_REASON: python3 unavailable` per MIT-001 if `python3` cannot be exercised). Asserts: (a) FR-5 + FR-6 templating fired — `<fixture>/wiki/mkdocs.yml` exists and the four `{{...}}` placeholders are resolved from the fixture's git remote (NOT the orchestrator's values); (b) the Giscus partial under `<fixture>/wiki/overrides/partials/comments.html` retains the four `{{giscus_*}}` placeholder tokens (P03's surface, not P02's); (c) `bash <fixture>/scripts/wiki/wiki-serve.sh` started in background returns HTTP 200 at `:8000` and `curl -fsS http://localhost:8000` returns HTML containing `<title>` (US-2 Acceptance Scenario 4); (d) FR-12 platform-aware diagnostic fires when `python3` is `PATH`-removed via `PATH=/usr/bin:/bin` shadowing in the test (US-2 Acceptance Scenario 3).
  - Check: `bash tools/verify/m032-p02-acceptance-shape-sc3.sh`

- `tests/m032-acceptance/p0X-glossary-surface.sh` (SC-7) exists at `tests/m032-acceptance/p02-glossary-surface.sh` (resolving the `p0X-` placeholder per #Q-4 to P02), is executable, and exits 0. Asserts: (a) FR-15 — `wiki/glossary.md` exists with three test entries; `bash scripts/wiki/wiki-scan-sources.sh --root . --include-glossary` emits the glossary path; `bash scripts/wiki/wiki-generate-nav.sh --root .` places Glossary as the second top-level nav entry; (b) FR-16 — `bash scripts/knowledge/lookup-mems.sh --kind=glossary --root .` synthesizes three records with stable IDs derivable from each term name; (c) FR-16 / MIT-010 — under `--profile=quick --task-description 'rename foo'` against a glossary containing `### Foo` + `### Bar` + `### Baz`, only the Foo record is emitted; under `--profile=quick` with no task-description and no file-change-set, zero records are emitted (safe-default-no-terms).
  - Check: `bash tools/verify/m032-p02-acceptance-shape-sc7.sh`

- `tools/verify/m032-p02-phase-suite.sh` exists, is executable, invokes every P02 verifier in dependency order, exits 0 iff every sub-gate passes, and emits a single line `SUMMARY: m032-p02-phase-suite.sh pass=N fail=M` before exit. The suite chains, in order: `m032-p02-wiki-init-command-shape.sh`, `m032-p02-wiki-init-default-scope.sh`, `m032-p02-mkdocs-templating-and-self-application.sh`, `m032-p02-init-with-wiki-passthrough.sh`, `m032-p02-glossary-format-invariant.sh`, `m032-p02-glossary-scanner-and-nav.sh`, `m032-p02-lookup-mems-glossary.sh`, `m032-p02-seam-a-shape.sh`, `m032-p02-seam-b-shape.sh`, `m032-p02-seam-c-shape.sh`, `m032-p02-acceptance-shape-sc3.sh`, `m032-p02-acceptance-shape-sc7.sh`. Twelve sub-gates plus the suite line.
  - Check: `bash tools/verify/m032-p02-phase-suite.sh`

- The SC-13 / scope-guard invariant holds for the P02 diff: P02 modifies only files declared in this phase's "Files Likely Touched" list. None of `packaging/install/install-{claude-code,codex,cursor}.sh` (those belong to P01), `packaging/bundle/manifest.yml`'s pre-M032 top-level keys (only the new `wiki/` entry under `project_assets:` is added in T01), `wiki/mkdocs.yml` nav-region markers (P03's split), `wiki/overrides/partials/comments.html` Giscus IDs (P03's `--with-giscus`), or any `.orchestrator/proposals/**` file is touched (those belong to P04's scanner extensions).
  - Check: `bash tools/verify/m032-p02-scope-guard.sh`

### Artifacts

- `commands/wiki-init.md` (min 80 lines, contains "wiki-init", contains "FR-5", contains "FR-12", contains "--with-giscus", contains "--deploy", contains "--auto-pip", contains "Referenced Scripts") — create
- `scripts/lifecycle/wiki-init.sh` (min 200 lines, contains "wiki-init", contains "site_name", contains "site_url", contains "repo_url", contains "site_description", contains "git remote", contains "python3", contains "pip3", contains "brew install python3", contains "apt install python3", contains "--auto-pip", contains "--site-name", contains "--site-description", contains "wiki/glossary.md", contains "no changes") — create
- `wiki/mkdocs.yml` (existing-baseline modify, contains "{{site_name}}", contains "{{site_description}}", contains "{{site_url}}", contains "{{repo_url}}") — modify (FR-6 self-application closes the loop: orchestrator-repo-local copy carries resolved values, bundle-staged copy carries placeholders)
- `packaging/bundle/manifest.yml` (existing-baseline+wiki entry under project_assets:, contains "wiki/", contains "wiki", contains "mode: copy") — modify (T01 of P02 — additive `wiki/` entry under existing `project_assets:` block)
- `commands/init.md` (existing-baseline modify, contains "--with-wiki", contains "--with-giscus", contains "--deploy", contains "wiki-pending", contains "FR-11", contains "MIT-011") — modify
- `scripts/lifecycle/init-project.sh` (existing-baseline modify, contains "--with-wiki", contains "--with-giscus", contains "--deploy", contains "wiki-init.sh", contains "init-complete, wiki-pending", contains "FR-11") — modify
- `wiki/glossary.md` (min 30 lines, contains "###", contains "Constitution", contains "Knowledge Graph", contains "Glossary") — create
- `scripts/wiki/wiki-scan-sources.sh` (existing-baseline modify, contains "--include-glossary", contains "wiki/glossary.md", contains "FR-15") — modify
- `scripts/wiki/wiki-generate-nav.sh` (existing-baseline modify, contains "Glossary", contains "wiki/glossary.md", contains "FR-15") — modify
- `scripts/knowledge/lookup-mems.sh` (min 120 lines, contains "--kind=glossary", contains "--profile=quick", contains "--profile=standard", contains "--profile=full", contains "--task-description", contains "--file-change-set", contains "FR-16", contains "MIT-010", contains "gloss-", contains "safe-default-no-terms") — create
- `tests/m032-acceptance/p02-wiki-init-default-scope.sh` (min 60 lines, contains "SC-3", contains "FR-5", contains "FR-6", contains "FR-12", contains "wiki-serve.sh", contains "curl", contains "8000") — create
- `tests/m032-acceptance/p02-glossary-surface.sh` (min 50 lines, contains "SC-7", contains "FR-15", contains "FR-16", contains "lookup-mems.sh", contains "--kind=glossary", contains "--profile=quick", contains "MIT-010") — create
- `tests/paired-m032-m033/seam-A.sh` (min 30 lines, contains "Seam-A", contains "project_assets:", contains "M033", contains "read-project-assets.sh") — create
- `tests/paired-m032-m033/seam-B.sh` (min 40 lines, contains "Seam-B", contains "FR-11", contains "MIT-011", contains "M032_WIKI_INIT_FORCE_EXIT", contains "init-complete, wiki-pending") — create
- `tests/paired-m032-m033/seam-C.sh` (min 30 lines, contains "Seam-C", contains "wiki/glossary.md", contains "###", contains "format invariant") — create
- `tools/verify/m032-p02-wiki-init-command-shape.sh` (min 25 lines, contains "wiki-init.md", contains "Referenced Scripts", contains "FR-5") — create
- `tools/verify/m032-p02-wiki-init-default-scope.sh` (min 30 lines, contains "wiki-init.sh", contains "site_name", contains "FR-5", contains "FR-12") — create
- `tools/verify/m032-p02-mkdocs-templating-and-self-application.sh` (min 30 lines, contains "{{site_name}}", contains "{{repo_url}}", contains "FR-6", contains "MIT-002", contains "orchestrator") — create
- `tools/verify/m032-p02-init-with-wiki-passthrough.sh` (min 30 lines, contains "--with-wiki", contains "init-project.sh", contains "FR-11", contains "MIT-011") — create
- `tools/verify/m032-p02-glossary-format-invariant.sh` (min 25 lines, contains "wiki/glossary.md", contains "###", contains "FR-15", contains "alphabetized") — create
- `tools/verify/m032-p02-glossary-scanner-and-nav.sh` (min 30 lines, contains "wiki-scan-sources.sh", contains "--include-glossary", contains "wiki-generate-nav.sh", contains "Glossary", contains "FR-15") — create
- `tools/verify/m032-p02-lookup-mems-glossary.sh` (min 40 lines, contains "lookup-mems.sh", contains "--kind=glossary", contains "--profile=quick", contains "--task-description", contains "FR-16", contains "MIT-010", contains "gloss-") — create
- `tools/verify/m032-p02-seam-a-shape.sh` (min 25 lines, contains "tests/paired-m032-m033/seam-A.sh", contains "project_assets:") — create
- `tools/verify/m032-p02-seam-b-shape.sh` (min 25 lines, contains "tests/paired-m032-m033/seam-B.sh", contains "FR-11") — create
- `tools/verify/m032-p02-seam-c-shape.sh` (min 25 lines, contains "tests/paired-m032-m033/seam-C.sh", contains "wiki/glossary.md") — create
- `tools/verify/m032-p02-acceptance-shape-sc3.sh` (min 25 lines, contains "p02-wiki-init-default-scope.sh", contains "SC-3") — create
- `tools/verify/m032-p02-acceptance-shape-sc7.sh` (min 25 lines, contains "p02-glossary-surface.sh", contains "SC-7") — create
- `tools/verify/m032-p02-phase-suite.sh` (min 60 lines, contains "SUMMARY:", contains "m032-p02-wiki-init-command-shape", contains "m032-p02-acceptance-shape-sc7", contains "m032-p02-phase-suite") — create
- `tools/verify/m032-p02-scope-guard.sh` (min 35 lines, contains "packaging/install/install-claude-code.sh", contains "packaging/install/install-codex.sh", contains "packaging/install/install-cursor.sh", contains ".orchestrator/proposals/", contains "SC-13") — create

### Key Links

- `commands/wiki-init.md` → `scripts/lifecycle/wiki-init.sh` (command document references the canonical implementation in its Referenced Scripts section per MEM012)
- `scripts/lifecycle/wiki-init.sh` → `scripts/lifecycle/read-project-assets.sh` (FR-5 — wiki-init reads its bundle source paths from the P01 reader against the new `wiki/` `project_assets:` entry)
- `scripts/lifecycle/wiki-init.sh` → `wiki/mkdocs.yml` (FR-6 — wiki-init sed-substitutes the four `{{...}}` placeholders against the staged mkdocs.yml)
- `commands/init.md` → `scripts/lifecycle/init-project.sh` (init command document references init-project.sh per MEM012)
- `scripts/lifecycle/init-project.sh` → `scripts/lifecycle/wiki-init.sh` (FR-11 — init-project.sh invokes wiki-init.sh as a second sequential step under `--with-wiki`)
- `scripts/wiki/wiki-scan-sources.sh` → `wiki/glossary.md` (FR-15 — scanner enumerates the glossary path under `--include-glossary`)
- `scripts/wiki/wiki-generate-nav.sh` → `wiki/glossary.md` (FR-15 — nav generator places Glossary as the second top-level nav entry)
- `scripts/knowledge/lookup-mems.sh` → `wiki/glossary.md` (FR-16 — adapter reads the glossary file to synthesize records)
- `tests/m032-acceptance/p02-wiki-init-default-scope.sh` → `scripts/lifecycle/wiki-init.sh` (SC-3 invokes wiki-init.sh against the fixture)
- `tests/m032-acceptance/p02-wiki-init-default-scope.sh` → `tests/fixtures/m032-fresh-project-fixture/` (SC-3 uses the P01 shared fixture)
- `tests/m032-acceptance/p02-glossary-surface.sh` → `scripts/knowledge/lookup-mems.sh` (SC-7 invokes the glossary adapter)
- `tests/m032-acceptance/p02-glossary-surface.sh` → `wiki/glossary.md` (SC-7 reads the glossary path-convention surface)
- `tests/paired-m032-m033/seam-A.sh` → `packaging/bundle/manifest.yml` (Seam-A asserts the `project_assets:` schema shape M033 consumes)
- `tests/paired-m032-m033/seam-B.sh` → `scripts/lifecycle/init-project.sh` (Seam-B asserts the FR-11 / MIT-011 sequential-atomicity contract)
- `tests/paired-m032-m033/seam-C.sh` → `wiki/glossary.md` (Seam-C asserts the format invariant M033 will honor when writing inline)
- `tools/verify/m032-p02-phase-suite.sh` → `tools/verify/m032-p02-wiki-init-command-shape.sh` (suite invokes the command-shape gate first)
- `tools/verify/m032-p02-phase-suite.sh` → `tools/verify/m032-p02-acceptance-shape-sc7.sh` (suite invokes the SC-7 acceptance gate)

## Tasks

### T01: `wiki-init.sh` default scope + `commands/wiki-init.md` + `mkdocs.yml` templating + FR-6 self-application loop + bundle `wiki/` `project_assets:` entry (FR-5, FR-6, FR-12, MIT-002)

See `tasks/T01-wiki-init-default-scope-PLAN.md`.

T01 is the foundational P02 surface. It (a) authors `commands/wiki-init.md` per the orchestrator command-file convention (MEM012); (b) authors `scripts/lifecycle/wiki-init.sh` implementing the default-scope invocation: `python3` + `pip3` toolchain probe with platform-aware diagnostics, git-remote parsing for the four templated values, sed-substitution against the staged `wiki/mkdocs.yml`, idempotent re-run preserving operator edits; (c) amends `wiki/mkdocs.yml` to replace the four hardcoded site-identity values with `{{...}}` placeholders AND closes the FR-6 self-application loop in the same task by running `bash scripts/lifecycle/wiki-init.sh --project-dir .` against the orchestrator repo itself, resolving placeholders to the orchestrator's identity, and verifying `bash scripts/wiki/wiki-serve.sh` continues to return HTTP 200 (per AD-5 / MIT-002 — failure to close this loop within T01 breaks the orchestrator's own wiki for the duration of M032 + M033 paired development); (d) amends `packaging/bundle/manifest.yml` to add a `wiki/` entry under the existing P01 `project_assets:` block (additive — the four pre-M032 entries from P01 are byte-preserved). T01 ships `m032-p02-wiki-init-command-shape.sh`, `m032-p02-wiki-init-default-scope.sh`, and `m032-p02-mkdocs-templating-and-self-application.sh` verifiers.

### T02: `init --with-wiki [--with-giscus] [--deploy]` passthrough with FR-11 / MIT-011 sequential-atomicity contract

See `tasks/T02-init-with-wiki-passthrough-PLAN.md`.

T02 lands the M033/P05 integration contract per CON-3. It (a) amends `commands/init.md` to document the new `--with-wiki [--with-giscus] [--deploy]` flag chain and the FR-11 / MIT-011 sequential-atomicity contract; (b) amends `scripts/lifecycle/init-project.sh` to recognize the three flags and invoke `scripts/lifecycle/wiki-init.sh` as a second sequential step ONLY when `--with-wiki` is present, forwarding `--with-giscus` and `--deploy` verbatim; (c) implements the failure-propagation contract: if `wiki-init.sh` exits non-zero the init outputs are preserved on disk, the compound exit code is the literal `wiki-init.sh` exit code (not 0, not 1 unless wiki-init exited with 1), and the diagnostic names `init-complete, wiki-pending` on stderr; (d) ensures callers (M033/P05) can re-run `wiki-init.sh` independently without re-running `init-project.sh`. T02 ships `m032-p02-init-with-wiki-passthrough.sh`.

### T03: Glossary surface — `wiki/glossary.md` path convention + `wiki-scan-sources.sh --include-glossary` + `wiki-generate-nav.sh` Glossary-as-second-entry (FR-15)

See `tasks/T03-glossary-surface-PLAN.md`.

T03 lands the M033 grilling-protocol surface CON-6 mandates. It (a) authors `wiki/glossary.md` at the orchestrator-repo level with at least three example entries in the US-6 format (`### TERM` heading, one-line definition, at-most-two-line elaboration, alphabetized); (b) amends `scripts/wiki/wiki-scan-sources.sh` to add the `--include-glossary` flag (default-on) that prepends `wiki/glossary.md` as the second top-level source; (c) amends `scripts/wiki/wiki-generate-nav.sh` to consume the scanner output and place Glossary as the second top-level nav entry under the existing `# >>> M012-P01 nav` markers (additive — no region-marker split, that's P03); (d) amends `scripts/lifecycle/wiki-init.sh` (T01 deliverable) to author a `<PROJECT_DIR>/wiki/glossary.md` stub at consumer-side default-scope invocation. T03 ships `m032-p02-glossary-format-invariant.sh` and `m032-p02-glossary-scanner-and-nav.sh`.

### T04: Glossary knowledge adapter — `scripts/knowledge/lookup-mems.sh --kind=glossary` honoring M031 traversal contract (FR-16, MIT-010)

See `tasks/T04-glossary-knowledge-adapter-PLAN.md`.

T04 binds the glossary surface into the M020 knowledge graph and the M031 traversal contract. It authors `scripts/knowledge/lookup-mems.sh` (new file) with a `--kind=glossary` mode that reads `<PROJECT_ROOT>/wiki/glossary.md`, parses each `### TERM` heading + body, synthesizes one record per term with a stable `id` derived from the term name (`gloss-<slug>`), and emits records to stdout in a M020-knowledge-record-compatible shape. The adapter honors three profiles per M031: `--profile=full` and `--profile=standard` emit the FULL glossary; `--profile=quick` emits ONLY touched terms per the FR-16 / MIT-010 inline definition (exact-or-stemmed task-description match OR file-change-set inclusion). The safe-default-no-terms fallback fires under `--profile=quick` when neither `--task-description` nor `--file-change-set` is supplied. T04 ships `m032-p02-lookup-mems-glossary.sh`.

### T05: SC-3 + SC-7 acceptance scripts + paired-launch seam-{A,B,C} + phase suite + scope guard

See `tasks/T05-acceptance-and-seam-and-suite-PLAN.md`.

T05 lands the verification surface that ties P02 closed. It (a) authors `tests/m032-acceptance/p02-wiki-init-default-scope.sh` (SC-3) against the P01 shared fixture, exercising FR-5 + FR-6 templating + FR-12 toolchain probe end-to-end including a live `wiki-serve.sh` HTTP probe at `:8000`; (b) authors `tests/m032-acceptance/p02-glossary-surface.sh` (SC-7 — resolves the `p0X-` placeholder per #Q-4 to P02) exercising FR-15 scanner + nav placement, FR-16 record synthesis with stable IDs, and the FR-16 / MIT-010 Quick-profile touched-term branches AND the safe-default-no-terms fallback; (c) authors the three paired-launch seam scripts under `tests/paired-m032-m033/seam-{A,B,C}.sh` per #Q-B (Seam-A: `project_assets:` schema shape; Seam-B: `--with-wiki` failure-propagation contract via `M032_WIKI_INIT_FORCE_EXIT=7` injection; Seam-C: `wiki/glossary.md` format invariant); (d) authors the phase-suite aggregator at `tools/verify/m032-p02-phase-suite.sh` chaining all twelve sub-gates in dependency order (single-script-file shape per AD-19); (e) authors the scope-guard at `tools/verify/m032-p02-scope-guard.sh` asserting P02's diff is confined to the declared "Files Likely Touched" list. T05 ships `m032-p02-seam-a-shape.sh`, `m032-p02-seam-b-shape.sh`, `m032-p02-seam-c-shape.sh`, `m032-p02-acceptance-shape-sc3.sh`, `m032-p02-acceptance-shape-sc7.sh`, `m032-p02-phase-suite.sh`, and `m032-p02-scope-guard.sh`.

## Task Dependencies

```
T01 → T02
T01 → T03
T03 → T04
T01 + T02 + T03 + T04 → T05
```

Rationale: T01 (wiki-init.sh + mkdocs.yml templating + bundle entry) is the foundational surface — T02 (init passthrough) invokes wiki-init.sh, T03 (glossary surface) extends wiki-init.sh to author the glossary stub, and T04 (knowledge adapter) reads wiki/glossary.md (T03's deliverable). T05 ships the verification battery against all four upstream task surfaces. T02 and T03 can run in parallel after T01 lands; T04 must run after T03 lands.

## Files Likely Touched

- `commands/wiki-init.md` (create)
- `scripts/lifecycle/wiki-init.sh` (create)
- `wiki/mkdocs.yml` (modify — bundle copy gets placeholders; orchestrator-local copy gets resolved values via FR-6 self-application loop)
- `packaging/bundle/manifest.yml` (modify — add `wiki/` entry under existing `project_assets:` block from P01)
- `commands/init.md` (modify)
- `scripts/lifecycle/init-project.sh` (modify)
- `wiki/glossary.md` (create)
- `scripts/wiki/wiki-scan-sources.sh` (modify — add `--include-glossary` flag)
- `scripts/wiki/wiki-generate-nav.sh` (modify — Glossary as second top-level nav entry, additive only)
- `scripts/knowledge/lookup-mems.sh` (create)
- `tests/m032-acceptance/p02-wiki-init-default-scope.sh` (create)
- `tests/m032-acceptance/p02-glossary-surface.sh` (create)
- `tests/paired-m032-m033/seam-A.sh` (create)
- `tests/paired-m032-m033/seam-B.sh` (create)
- `tests/paired-m032-m033/seam-C.sh` (create)
- `tools/verify/m032-p02-wiki-init-command-shape.sh` (create)
- `tools/verify/m032-p02-wiki-init-default-scope.sh` (create)
- `tools/verify/m032-p02-mkdocs-templating-and-self-application.sh` (create)
- `tools/verify/m032-p02-init-with-wiki-passthrough.sh` (create)
- `tools/verify/m032-p02-glossary-format-invariant.sh` (create)
- `tools/verify/m032-p02-glossary-scanner-and-nav.sh` (create)
- `tools/verify/m032-p02-lookup-mems-glossary.sh` (create)
- `tools/verify/m032-p02-seam-a-shape.sh` (create)
- `tools/verify/m032-p02-seam-b-shape.sh` (create)
- `tools/verify/m032-p02-seam-c-shape.sh` (create)
- `tools/verify/m032-p02-acceptance-shape-sc3.sh` (create)
- `tools/verify/m032-p02-acceptance-shape-sc7.sh` (create)
- `tools/verify/m032-p02-phase-suite.sh` (create)
- `tools/verify/m032-p02-scope-guard.sh` (create)
