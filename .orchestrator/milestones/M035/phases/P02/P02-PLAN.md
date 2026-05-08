---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M035"
goal: "npm publishing pipeline (`@build-fractal/orchestrator`) — author `package.json` + `bin/orchestrator` + postinstall + `.github/workflows/release.yml` skeleton + `tests/m035-acceptance/cross-channel-byte-equivalence.sh` skeleton with npm-channel hash assertion + bundle-hygiene pre-publish filter (#Q-9 fold-in). The npm-tarball v1 surface that bakes the cohort prefix and package name forever."
demo_sentence: "From a fresh container without the orchestrator repo cloned, `npm install -g @build-fractal/orchestrator@<tag>` exits 0 (or `npm install -g ./build-fractal-orchestrator-<tag>.tgz` from a locally-packed tarball during CI dry-run); `which orchestrator` returns a path on PATH; `orchestrator --version` matches the `<tag>` (SC-8); `tests/m035-acceptance/cross-channel-byte-equivalence.sh` runs end-to-end and emits the npm-channel SHA-256 (CON-5, AD-2 / Constitution Principle XVI bootstrap)."
risk: "high"
depends_on: ["P01.5"]
---

## Plan-Phase-Resolved Open Questions (AD-7)

These resolve at this plan-phase per AD-7 / spec routing. They land as
design constraints in the task plans below.

- **#Q-7 (CI runner platform)** → `ubuntu-latest`. npm tarball assembly +
  `npm publish` is shell + node-only; no macOS-only surface in P02.
  Cross-channel byte-equivalence will gain a `macos-latest` matrix when
  P03 (homebrew) lands. Recorded as **D001** (`M035/P02 convention`,
  appended 2026-05-08). Aligned with CON-2 (bash 4+ permitted in CI
  scripts).

- **#Q-10 (test-fixture strategy)** → `npm pack` → local tarball →
  install into a fixture-local npm prefix (`--prefix=<fixture>/.npm-prefix`).
  Never touches the public registry. Postinstall runs under `DRY_RUN=1`
  by default in CI; live-postinstall is exercised only in a
  containerized acceptance fixture on `v*` tag-push events. Avoids the
  verdaccio service dependency. Recorded as **D002** (`M035/P02
  convention`, appended 2026-05-08).

- **#Q-G9 / MIT-9 (Windows postinstall guard)** → `package.json` declares
  `"engines": {"node": ">=14"}` AND `"os": ["darwin", "linux"]` (npm
  itself refuses install on win32 with `EBADPLATFORM`); the
  postinstall script ALSO `case`-checks `uname -s` for
  `MINGW*|CYGWIN*|MSYS*|Windows_NT` and exits non-zero with a clear
  stderr message before invoking `install-claude-code.sh`. Belt-and-
  suspenders fail-closed posture. Recorded as **D003** (`M035/P02
  convention`, appended 2026-05-08). Aligned with #Q-8 (Windows
  symlink-mode deferred to post-launch M009).

- **#Q-9 (bundle-hygiene fold-in)** → **absorbed as P02 T05** per
  the spec OQ recommendation ("the launch-event milestone's first
  npm publish must not ship 791 milestone-internal verifiers to
  adopters; bundle hygiene is a launch gate"). Pattern exclusion
  (`m[0-9]*-p[0-9]*-*` under `scripts/verify/` and parallel locations)
  + magic-comment opt-out (`# bundle: dogfood-only` header / `bundle:
  dogfood-only` frontmatter) added to `packaging/bundle/build-bundle.sh`.
  No new D-row needed — bound by spec amendment.

## Must-Haves

### Truths

- `package.json` exists at the repo root, declares
  `"name": "@build-fractal/orchestrator"` (D-RN-1), `"bin":
  {"orchestrator": "bin/orchestrator"}`, `"engines": {"node":
  ">=14"}`, `"os": ["darwin", "linux"]`, `"version"` aligned with
  `CHANGELOG.md` top-line via T01 author-time read (CON-4), and a
  `"scripts": {"postinstall": "..."}` field pointing at the
  postinstall driver.
  - Check: `bash tools/verify/m035-p02-package-json-shape.sh`

- `bin/orchestrator` exists, is executable, prints the package version
  on `--version` (matches `package.json` `version` field), and prints a
  short usage banner naming the command-cohort prefix
  `orchestrator:<cmd>` (D-RN-3).
  - Check: `bash tools/verify/m035-p02-bin-entry.sh`

- `packaging/npm/postinstall.sh` exists, is executable, refuses with
  exit non-zero on Windows-detected `uname -s` (MIT-9 belt-and-suspenders
  guard), respects `DRY_RUN=1` (no writes; emits `would_invoke=...`
  lines), and on Unix delegates to
  `packaging/install/install-claude-code.sh` with `--project-dir
  "$INIT_CWD"` resolved from the `INIT_CWD` env var (npm convention).
  - Check: `bash tools/verify/m035-p02-postinstall-shape.sh`

- `.github/workflows/release.yml` exists with two jobs: a
  `pr-validate` job that runs on `pull_request` events (no secret
  access, exercises `npm pack` + tarball-shape lint) AND a
  `npm-publish` job conditioned on `if: startsWith(github.ref,
  'refs/tags/v')` (CON-6 secrets scoped to tag-push only). The
  publish job has `npm publish --access public` and `NODE_AUTH_TOKEN`
  injected from `secrets.NPM_TOKEN`. Workflow runs on `ubuntu-latest`
  (D001).
  - Check: `bash tools/verify/m035-p02-release-workflow-shape.sh`

- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` exists,
  is executable, and runs the npm-channel arm end-to-end:
  `npm pack` → install into a fixture prefix under `DRY_RUN=1` →
  `find <staged-tree> -type f | shasum -a 256` over the staged
  runtime tree, ignoring the documented exclusion list enumerated in
  `references/installation.md § Channel-specific metadata files`
  (MIT-2 enumeration: `.orchestrator/install-meta.txt`, `package.json`,
  `package-lock.json`, `.previous-version`, `node_modules/`,
  `package/.npmignore` artifacts). Emits `NPM_HASH=<sha>` on stdout.
  Homebrew + curl-pipe-bash arms are stubbed with `SKIP: pending P03`
  / `SKIP: pending P04` lines and a hash-set of size 1 — extended in
  P03/P04. CON-5 / SC-10 / AD-2 Principle XVI bootstrap.
  - Check: `bash tools/verify/m035-p02-byte-equivalence-skeleton.sh`

- `references/installation.md` is extended with `## Channel-specific
  metadata files` enumerating the five exclusion-list paths
  load-bearing for FR-14 / SC-10 / SC-12 cross-channel byte equivalence
  (MIT-2 resolution; spec-amend prerequisite).
  - Check: `bash tools/verify/m035-p02-installation-doc-exclusion-list.sh`

- `packaging/bundle/build-bundle.sh` honors a pre-publish filter:
  files under `scripts/verify/` (and parallel `tools/verify/`,
  `templates/conversus-presets/`) matching glob `m[0-9]*-p[0-9]*-*`
  are excluded from the staged bundle; ANY file with a
  `# bundle: dogfood-only` header line OR a `bundle: dogfood-only`
  frontmatter key is excluded. Filter is invoked on every build
  (#Q4 of bundle-hygiene proposal). #Q-9 absorption.
  - Check: `bash tools/verify/m035-p02-bundle-hygiene-filter.sh`

- `npm pack` from the repo root produces a tarball
  (`build-fractal-orchestrator-<version>.tgz`) whose extracted
  contents include `bin/orchestrator`, `packaging/install/`,
  `packaging/bundle/` (post-filter), `commands/`, `scripts/`,
  `references/`, `templates/`, and `package.json`; AND DO NOT include
  the dogfood-only `m[0-9]*-p[0-9]*-*` verifier corpus, the
  `.orchestrator/` state tree, the `specs/` tree, the `tests/` tree,
  the `tools/` tree, or the `docs/` tree (NPM bundle hygiene gate).
  - Check: `bash tools/verify/m035-p02-npm-pack-contents.sh`

- The phase-suite aggregator
  `tools/verify/m035-p02-phase-suite.sh` exists and runs every
  per-truth verifier above in sequence, emitting `PASS:` / `FAIL:`
  lines plus a `BATTERY: pass=N fail=0` summary line (matching the
  M030 / M032 / M029 / M037 / P01.5 acceptance-battery line shape).
  - Check: `bash tools/verify/m035-p02-phase-suite.sh`

### Artifacts

- `package.json` (min 30 lines, contains `@build-fractal/orchestrator`)
- `bin/orchestrator` (min 20 lines, contains `--version`)
- `packaging/npm/postinstall.sh` (min 40 lines, contains
  `Windows_NT` AND `INIT_CWD`)
- `.github/workflows/release.yml` (min 60 lines, contains
  `startsWith(github.ref, 'refs/tags/v')` AND
  `secrets.NPM_TOKEN`)
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` (min 80
  lines, contains `NPM_HASH=` AND `SKIP: pending P03`)
- `references/installation.md` (modified — contains
  `## Channel-specific metadata files`)
- `packaging/bundle/build-bundle.sh` (modified — contains
  `bundle: dogfood-only` AND `m[0-9]*-p[0-9]*-*`)
- `tools/verify/m035-p02-phase-suite.sh` (min 30 lines, contains
  `BATTERY:`)

### Key Links

- `package.json` → `bin/orchestrator` (`bin` field maps the binary
  name to the entry script)
- `package.json` → `packaging/npm/postinstall.sh` (`scripts.postinstall`
  field invokes the driver)
- `packaging/npm/postinstall.sh` → `packaging/install/install-claude-code.sh`
  (postinstall delegates to the existing installer; CON-7 reversibility-
  gate preserved)
- `.github/workflows/release.yml` → `package.json` (publish job runs
  `npm publish` against the tarball derived from this manifest)
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` →
  `references/installation.md` (consults the `## Channel-specific
  metadata files` exclusion list at runtime via grep)
- `packaging/bundle/build-bundle.sh` → `packaging/bundle/manifest.yml`
  (filter applied during bundle assembly; manifest comments document
  the contract)

## Tasks

### T01: `package.json` + `bin/orchestrator` entry point (FR-8 minimum surface, MIT-9 platform guards)

See `tasks/T01-package-json-and-bin-PLAN.md`.

### T02: `packaging/npm/postinstall.sh` driver (Unix-delegate, Windows fail-closed, INIT_CWD-aware)

See `tasks/T02-postinstall-driver-PLAN.md`.

### T03: Cross-channel byte-equivalence skeleton + exclusion-list documentation

See `tasks/T03-byte-equivalence-skeleton-PLAN.md`.

### T04: `.github/workflows/release.yml` skeleton (PR-validate + tag-push-publish, CON-6 secrets-scoped)

See `tasks/T04-release-workflow-PLAN.md`.

### T05: Bundle-hygiene pre-publish filter (#Q-9 absorption) + phase-suite aggregator

See `tasks/T05-bundle-hygiene-and-phase-suite-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T04 ──► T05
```

Strictly sequential (one commit per task per RENAME-PLAN convention §
5 inherited from P01.5). Sequencing rationale:

- **T01 first** because every downstream artifact reads `package.json`:
  T02 reads `INIT_CWD` resolution shape from npm convention which is
  paired with `bin` registration; T03's npm-channel arm runs `npm
  pack` against the manifest authored in T01; T04's publish job
  publishes the manifest; T05's bundle-hygiene filter excludes
  artifacts the npm tarball would otherwise stage.

- **T02 before T03** because T03's npm-channel arm exercises the
  postinstall path under `DRY_RUN=1`; if T02's driver doesn't honor
  `DRY_RUN=1` cleanly the byte-equivalence test cannot bootstrap.

- **T03 before T04** because the workflow's `pr-validate` job invokes
  `tests/m035-acceptance/cross-channel-byte-equivalence.sh`; the
  workflow assertion (SC-14 PR-build job-condition assertion) must
  reference an existing test file.

- **T04 before T05** because T05's phase-suite aggregator runs
  `m035-p02-release-workflow-shape.sh` against the workflow file
  T04 authors.

Plan-Time Discipline Rule 2 (verifier-availability cross-check): every
task plan below schedules its task-grain verifier authorship inside
its own `## Steps`. T05 schedules the phase-suite aggregator
authorship inside its own steps. No cross-task verifier dependencies.

## Files Likely Touched

- `package.json` (create) — T01
- `bin/orchestrator` (create) — T01
- `packaging/npm/postinstall.sh` (create) — T02
- `packaging/npm/` (new directory) — T02
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` (create) — T03
- `tests/m035-acceptance/npm-pack-install.sh` (create — T03 helper) — T03
- `references/installation.md` (modify — append `## Channel-specific
  metadata files` section) — T03
- `.github/workflows/release.yml` (create) — T04
- `packaging/bundle/build-bundle.sh` (modify — add filter pass) — T05
- `packaging/bundle/manifest.yml` (modify — comment-doc the filter
  convention) — T05
- `tools/verify/m035-p02-package-json-shape.sh` (create) — T01
- `tools/verify/m035-p02-bin-entry.sh` (create) — T01
- `tools/verify/m035-p02-postinstall-shape.sh` (create) — T02
- `tools/verify/m035-p02-byte-equivalence-skeleton.sh` (create) — T03
- `tools/verify/m035-p02-installation-doc-exclusion-list.sh` (create) — T03
- `tools/verify/m035-p02-release-workflow-shape.sh` (create) — T04
- `tools/verify/m035-p02-bundle-hygiene-filter.sh` (create) — T05
- `tools/verify/m035-p02-npm-pack-contents.sh` (create) — T05
- `tools/verify/m035-p02-phase-suite.sh` (create) — T05

Plan-Time Discipline Rule 6 (path-collision check): every `create`
path above was checked at plan-authoring time via `ls`/`test -f` and
none exist on disk. The slug-bearing verifier names (`m035-p02-*`)
follow the milestone-prefix discipline from CLAUDE.md ("milestone slug
REQUIRED for per-phase verifiers"). The framework-staged dirs
(`commands/`, `references/`, `scripts/`, `templates/`) are NOT
written under by this phase.
