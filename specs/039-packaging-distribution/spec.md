---
schema_version: "1.0"
type: feature-spec
feature_slug: "039-packaging-distribution"
created_at: "2026-05-08"
status: "Draft"
milestone: "M035"
---

# Feature Specification: 039-packaging-distribution

**Feature Branch**: `039-packaging-distribution`
**Created**: 2026-05-08
**Status**: Draft
**Milestone**: M035
**Input**: User description: "M035 packaging and distribution: the launch-readiness milestone. Two layers sequenced: pre-launch ergonomics (P00 baseline + P01 --mode=symlink install option + orchestrator:status version-drift warning, bridging the staleness gap that hits dogfood projects today every time orchestrator commands edit) and launch-event publishing (P02-P06 npm + homebrew + curl-pipe-bash publishing pipelines, GitHub release automation, install-script integrity, orchestrator:update first-class command with multi-source dispatch). M035 is the final pre-launch milestone; P02-P06 constitute the launch event. Brief at .orchestrator/proposals/M035-packaging-distribution.md."

## Problem Statement

The orchestrator has no canonical install path. Today's only route is `git clone <repo> && bash packaging/install/install-claude-code.sh --project-dir <path>` — fine for the operator and a handful of pre-launch dogfooders, hostile to anyone who hasn't already opted in to the project. There is no `npm install -g`, no `brew install`, no `curl … | bash` one-liner, no signed release artifacts, and no version-drift detection between an installed runtime and upstream HEAD. Until those exist, "launch" is a documentation event without an installable surface.

Three concrete pain-points follow from the gap. First, **active dogfoodners hit a staleness wall on every commit**: `packaging/install/install-claude-code.sh:295-318` does `cp -R` of `scripts/`, `templates/`, `references/`, `commands/` into each consumer project, so editing `commands/auto.md` in this repo requires re-installing across every consumer (lakeledger, pbj-central, bbt-companion) before the change takes effect. M025's skill registration is global-pinned-snapshot for the same reason. Second, **there is no drift detection** — `references/installation.md:231-245` documents the upgrade path as "pull the orchestrator repo and re-run the installer with `--force`"; if the operator forgets, the consumer silently runs stale code with no warning. Third, **`clone + bash` is not a credible install pattern for OSS adoption** — casual evaluators expect a package-manager command, not a git workflow. Without P02–P06's publishing pipelines, the launch surface is missing.

The minimum surface that fixes all three: a `--mode=symlink` install option that collapses the edit-and-re-install cycle to edit-and-git-pull for dogfooders (P01); a version-drift warning rendered into M029's headline status block that surfaces staleness without requiring the operator to remember (P01); a fresh-machine install audit that confirms the installer's exit code is trustworthy on macOS bash 3.2 (P00); a `speckit.orchestrator.*` → `orchestrator:*` cohort rename that aligns the in-tree namespace with the published-package scope before v1 ships (P01.5); and the npm/homebrew/curl-pipe-bash publishing pipelines + signed releases + multi-source `orchestrator:update` dispatch that *constitute* the launch event (P02–P06).

This feature does **not** re-architect the installer's internals (M025's territory), does not change runtime behavior (every other milestone touches that), does not introduce a new project-bootstrap UX (M033's territory), does not change `orchestrator:status` rendering (M029's territory — M035 contributes the drift datum, M029 renders it), does not invent a new versioning scheme (SemVer is already in use per `CHANGELOG.md`), and does not ship a docs-site or marketing-page launch (separate scope, possibly a one-off project rather than a milestone).

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

User Story 1 (`--mode=symlink` install) and User Story 2 (`orchestrator:status` version-drift warning) together close the pre-launch dogfood loop. Once those land, every active consumer project (lakeledger, pbj-central, bbt-companion) sees orchestrator edits propagate via `git pull` instead of re-install, and any consumer running stale code surfaces the drift in the next `orchestrator:status` invocation. User Story 3 (P00 bash 3.2 exit-status fix) and User Story 4 (installer-managed `.gitignore`) ride alongside as P00/P01 hygiene because both compose with the install-mode + drift work and cost less to ship together than to defer. User Story 5 (namespace cohort rename) is sequenced as P01.5 because it must land before P02 — the npm package's first published version determines the canonical command-cohort prefix and we cannot ship `speckit.orchestrator.*` references inside `@spec-kit/orchestrator@1.0.0`. User Stories 6 through 10 (P02–P06: npm, homebrew, curl-pipe-bash, install-script integrity, multi-source `orchestrator:update`) are the launch event itself; they are defended on top of the pre-launch slice but their shipment *is* the launch.

### User Story 1 — `--mode=symlink|copy` install option for active dogfooders (Priority: P1)

A developer who maintains the orchestrator and three consumer projects (lakeledger, pbj-central, bbt-companion) installs the orchestrator into each consumer with `bash packaging/install/install-claude-code.sh --project-dir <path> --mode=symlink`. The installer replaces the per-runtime-dir `cp -R` calls with `ln -sfn` to the orchestrator repo and registers symlink-pointed skills in `~/.claude/skills/`. The `.orchestrator/installed-files.txt` manifest records `mode: symlink` per entry so M025's uninstall path knows to `rm` the symlink (leaving the source tree intact) rather than `rm -rf` the staged copy. After this lands, the developer's edit-loop collapses from "edit `commands/auto.md` + re-install across N consumers" to "edit + `git pull` in each consumer."

**Why this priority**: This is the single biggest velocity unlock for pre-launch dogfooding. Every milestone after M035 P01 ships pays this dividend. Without it, every milestone-touching-commands work-item carries a hidden multi-consumer re-install cost. P1 because it's load-bearing for the post-M029 dogfood velocity; not P0 only because Quick/Standard intensity work technically still ships without it.

**Independent Test**: Run `bash packaging/install/install-claude-code.sh --project-dir <fixture> --mode=symlink` against a fresh fixture project. Assert: (a) every entry in `.orchestrator/installed-files.txt` carries `mode: symlink`; (b) `readlink <fixture>/scripts` resolves to the orchestrator repo's `scripts/` path; (c) editing `<repo>/commands/auto.md` is immediately visible inside `<fixture>` without re-install; (d) `bash packaging/install/install-claude-code.sh --project-dir <fixture> --uninstall` removes only the symlinks and leaves `<repo>/scripts/` untouched. No dependency on US-2 or any other story.

**Acceptance Scenarios**:

1. **Given** a fresh fixture project with no orchestrator install, **When** the developer runs `install-claude-code.sh --project-dir <fixture> --mode=symlink`, **Then** every staged runtime-dir entry is a symlink to the source repo, the manifest records `mode: symlink`, and an edit to a source-repo file is visible in the fixture without re-install.
2. **Given** the same fixture re-installed in `--mode=copy` (or default), **When** uninstall runs against either mode, **Then** the manifest replay correctly removes symlinks (mode=symlink) or `rm -rf`s copies (mode=copy) without touching the source repo.
3. **Given** the same fixture moved to a second machine where the orchestrator repo lives at a different absolute path, **When** any orchestrator command runs, **Then** the broken-symlink failure is loud (clear stderr message naming the missing source path), not silent.

### User Story 2 — `orchestrator:status` version-drift warning (Priority: P1)

A developer opens `orchestrator:status` inside a consumer project whose orchestrator runtime was installed three weeks ago. The headline block from M029 includes a new line: `STALE: orchestrator runtime is 14 commits behind upstream — run \`orchestrator:update\``. The drift datum comes from comparing the consumer's installed `CHANGELOG.md` top-line version (or commit SHA, when present in the install metadata) against a reference source — pre-launch the reference is a configurable orchestrator-repo path (default `$HOME/Sites/orchestrator`), at-launch (P06) it switches to package-manager metadata (`npm view`/`brew info`).

**Why this priority**: P1 because silent staleness is the second-largest pre-launch dogfood pain (the first being the re-install cycle US-1 fixes). Pairs naturally with US-1 — symlink-mode dogfooders rarely see drift (their install is live), but copy-mode consumer-project installs need the warning to know when to re-install. Composes cleanly with M029's existing headline-status surface; M035 contributes the drift datum, M029 renders.

**Independent Test**: Stage a consumer project's `.orchestrator/install-meta.txt` with a known-old commit SHA, set `update_source: git` and a configured orchestrator-repo path in `.orchestrator/config.yml`, and assert `orchestrator:status` headline contains the documented drift line with the correct commit-count. Toggle `update_source: none` (or absent) and assert the line is suppressed entirely (no warning, no error). Run against a fresh-install fixture and assert no warning appears.

**Acceptance Scenarios**:

1. **Given** a consumer project whose `install-meta.txt` records a commit SHA that is 14 commits behind the configured upstream, **When** `orchestrator:status` runs, **Then** the headline block contains exactly one line of the form `STALE: orchestrator runtime is 14 commits behind upstream — run \`orchestrator:update\`` and exit code is unchanged from today's status command.
2. **Given** a fresh install whose `install-meta.txt` SHA matches upstream HEAD, **When** `orchestrator:status` runs, **Then** the drift line is absent.
3. **Given** `.orchestrator/config.yml` carries `update_source: none` (drift detection opted out), **When** `orchestrator:status` runs, **Then** drift detection is suppressed silently regardless of actual SHA divergence.

### User Story 3 — Installer exit-code integrity on macOS bash 3.2 (Priority: P1)

A developer runs `install-claude-code.sh --project-dir <path>` against a project whose `wiki/` directory already exists (M032 staged-dirs collision). The installer detects the collision, prints the documented `staged-dirs-collision: ...` error to stderr, and exits non-zero. Today on macOS bash 3.2 the same scenario silently exits 0 because of a `set -e` + process-substitution + `while read` interaction that swallows the inner exit status. The installer must mean what its exit code says on every platform an operator might run it on.

**Why this priority**: P1 because today's masking is benign (everything M037 needs lands before the loop) but tomorrow it will mask a real install failure and the operator will not know until something downstream breaks. P00 baseline-hardening is the natural slot since the fresh-machine install audit exercises exactly this surface. Bundling here keeps the installer-internals surface coherent with US-1 and US-4.

**Independent Test**: Reproduce the masking on macOS bash 3.2 with a synthetic collision fixture (pre-existing `wiki/` directory). Assert `INSTALLER_EXIT != 0`. Run the same fixture on bash 4+ (Docker or Linux CI) and assert the same behavior. After the fix, regression test under `tests/installer-acceptance/` runs on both shells and stays green.

**Acceptance Scenarios**:

1. **Given** a fixture project with a pre-existing `wiki/` directory and an operator running macOS bash 3.2, **When** `install-claude-code.sh --project-dir <fixture>` runs, **Then** stderr contains `staged-dirs-collision` and exit code is non-zero (matching the inner `exit "$rc"` value).
2. **Given** the same fixture on bash 4+, **When** the installer runs, **Then** the same exit code surfaces — no platform-specific divergence.
3. **Given** a fixture without the collision, **When** the installer runs, **Then** exit code is 0 and the install completes idempotently.

### User Story 4 — Installer-managed `.gitignore` for installer sidecars (Priority: P1)

A developer running `install-claude-code.sh` (or the codex / cursor variants) ends up with `<project>/.orchestrator/install-meta.txt` containing operator-specific absolute paths (`source_root=/Users/<name>/...`). Without intervention, an unwitting `git add -A` commits the path. The installer prevents this by appending a managed marker block to `<project>/.gitignore` covering installer-managed sidecars. The block uses the same convention as the giscus paper-cut closed at the wiki-init layer (`# >>> orchestrator-managed: gitignore >>>` … `# <<< orchestrator-managed: gitignore <<<`). Re-runs replace the block contents idempotently rather than appending duplicates.

**Why this priority**: P1 because the sidecar exists today, the leak risk is real, and the fix is a tiny addition to all three installers (~30 LOC each). Pairs with US-3 because both touch installer scripts and both belong to "installer integrity hygiene."

**Independent Test**: Run `install-claude-code.sh --project-dir <fixture>` against a fresh fixture, then `grep -A1 'orchestrator-managed: gitignore' <fixture>/.gitignore` and assert the marker block contains `.orchestrator/install-meta.txt`. Re-run the installer and assert the block appears exactly once (idempotent). Repeat for `install-codex.sh` and `install-cursor.sh`.

**Acceptance Scenarios**:

1. **Given** a fresh fixture with no `.gitignore`, **When** any of the three installers runs, **Then** `<fixture>/.gitignore` contains the managed marker block covering `.orchestrator/install-meta.txt`.
2. **Given** a fixture whose `.gitignore` already contains an unrelated managed-block from another tool, **When** the installer runs, **Then** the orchestrator block is appended without disturbing the existing block.
3. **Given** a fixture with the orchestrator marker block already present, **When** the installer re-runs, **Then** the block is rewritten in place (no duplicate appended); operator-edited content outside the block is preserved.

### User Story 5 — `speckit.orchestrator.*` → `orchestrator:*` namespace cohort rename (Priority: P1)

A developer reading `commands/auto.md` Stage 2 sees `Skill(orchestrator:plan-phase)` rather than `Skill(speckit.orchestrator.plan-phase)`. Across the 15 files carrying the legacy namespace (~71 occurrences per the 2026-04-30 PR #3 audit), every operational reference is replaced with the `orchestrator:<command>` shape; historical / migration documentation (`commands/migrate.md` AD-15, `templates/instruction-schema.md`) reframes the legacy name as a documented historical reference rather than an active surface. The cohort rename ships co-located with the broader `spec-kit-orchestrator` → `orchestrator` repo / project rename (separate scope, same audit pass) so both renames land in one commit sequence.

**Why this priority**: P1 because P02 (npm publish) cannot ship until the rename closes. Whatever scope ships in P02 (`@spec-kit/orchestrator` vs `@orchestrator/cli` vs unscoped — see #Q-1) determines the canonical command-cohort prefix, and the in-tree namespace must match. Renaming earlier risks shipping a name that conflicts with the published-package decision; renaming later means v1's npm tarball carries `speckit.orchestrator.*` references in its skills/commands, baking the legacy name into the install surface forever.

**Independent Test**: After the sweep, `grep -r 'speckit\.orchestrator\.' commands/ templates/ scripts/ references/ docs/` returns hits only inside files explicitly tagged as historical/migration documentation (a small allow-list in the test). Operational references — anything reachable from `commands/auto.md` Stage 2 dispatch shapes, `commands/dispatch.md`, `commands/resume.md`, etc. — return zero hits. Run the full test suite and assert no regressions from the rename.

**Acceptance Scenarios**:

1. **Given** the pre-rename codebase with 71 occurrences of `speckit.orchestrator.*`, **When** the cohort sweep lands, **Then** `grep -r 'speckit\.orchestrator\.' commands/ scripts/ templates/ | grep -v -f tests/m035-acceptance/legacy-allowlist.txt` returns no matches.
2. **Given** the post-rename codebase, **When** the test suite runs, **Then** every existing test passes — operational references resolve correctly under the new `orchestrator:*` shape.
3. **Given** a dispatched agent reading the renamed `commands/auto.md`, **When** Stage 2 dispatch shape executes, **Then** `Skill(orchestrator:plan-phase)` resolves to the registered skill (no broken Skill invocation).

### User Story 6 — npm publishing pipeline (Priority: P2)

A developer on a fresh machine runs `npm install -g @spec-kit/orchestrator` (or the chosen scope per #Q-1). The package's postinstall script wraps the existing `install-claude-code.sh`, places a `bin/orchestrator` entry point on PATH, and registers Claude Code skills in `~/.claude/skills/` via the same M025 manifest mechanism as the bash-driven install. `npm publish` runs idempotently from the orchestrator repo (manual at first; CI-automated in P04). The package version aligns with `CHANGELOG.md`'s top-line.

**Why this priority**: P2, not P1, because npm publishing is launch-event scope rather than pre-launch dogfood. Within the launch event, npm is the highest-leverage channel because it's the most-expected install path for OSS DX tools. Sequenced first within P02–P06 because subsequent channels (homebrew, curl-pipe-bash) compose against the npm-published artifact in some configurations.

**Independent Test**: From a fresh machine (or container) without the orchestrator repo cloned, run `npm install -g <published-package>` against a beta-tagged release. Assert `which orchestrator` returns the bin path, `orchestrator --version` matches `CHANGELOG.md`, and a fresh `orchestrator:init <fixture>` invocation produces the same result as a clone+bash install of the same SHA.

**Acceptance Scenarios**:

1. **Given** a fresh machine without the orchestrator repo, **When** `npm install -g <package>` runs, **Then** the install completes, `orchestrator --version` succeeds, and `orchestrator:init` works against a fresh project fixture.
2. **Given** `npm install -g <package>` already ran once, **When** the same command re-runs (same version), **Then** the install is idempotent (no errors, no duplicate skills, manifest unchanged).
3. **Given** an installed package and a newer published version, **When** `npm update -g <package>` runs, **Then** the runtime is updated and `orchestrator:status` no longer reports drift.

### User Story 7 — Homebrew formula + tap (Priority: P2)

A macOS or Linuxbrew developer runs `brew tap <org>/orchestrator && brew install orchestrator`. The tap repo (`homebrew-orchestrator`) hosts the formula; the formula installs the same artifact set as the npm channel and registers skills via the same M025 manifest. Uninstall (`brew uninstall orchestrator`) cascades through M025's existing uninstall path, leaving no orphan skills or runtime files.

**Why this priority**: P2 alongside US-6 because homebrew is the second-most-expected install path on the launch posture's primary platform (macOS). Tap-vs-cask decision and tap-org name are deferred to P00 baseline (#Q-2).

**Independent Test**: From a fresh macOS install (or container with Linuxbrew), run `brew tap` + `brew install` against a published formula. Assert `which orchestrator` succeeds, the runtime layout is byte-identical to the npm-installed equivalent (verified by hash), and `brew uninstall` removes everything the install placed.

**Acceptance Scenarios**:

1. **Given** a fresh brew-equipped machine, **When** `brew tap <org>/orchestrator && brew install orchestrator` runs, **Then** the install completes and the runtime layout matches the documented manifest byte-for-byte.
2. **Given** an installed orchestrator via brew, **When** `brew uninstall orchestrator` runs, **Then** all installed files are removed and no skills remain registered in `~/.claude/skills/`.
3. **Given** the brew install and the npm install of the same version, **When** both runtimes are hashed (`find . -type f | xargs shasum`), **Then** the hashes are identical (Principle XVI byte-equivalence across channels).

### User Story 8 — `curl … | bash` one-liner + GH release automation (Priority: P2)

A developer following a README or docs page runs `curl -sSL https://orchestrator.dev/install.sh | bash` (or the GitHub raw URL fallback). The hosted `install.sh` auto-detects the runtime (Claude Code / Codex CLI / Cursor) and dispatches to the appropriate installer. CI runs the publishing pipeline on every `v*` tag push: `gh release create` with auto-generated notes plus uploaded artifacts (npm tarball, homebrew bottle, signed `install.sh`).

**Why this priority**: P2 because curl-pipe-bash is the lowest-friction install path for evaluators not already invested in npm or brew. The GH release automation is the load-bearing CI scaffolding that all three channels (npm, brew, curl) rely on for versioning and artifact publication.

**Independent Test**: Push a synthetic `v0.0.0-test` tag to a fork and assert the CI workflow runs to completion: GitHub release created, npm tarball uploaded, homebrew bottle attached, `install.sh` uploaded with detached signature. Run `curl -sSL <release-url>/install.sh | bash` against a fresh fixture and assert the install completes.

**Acceptance Scenarios**:

1. **Given** a `v*` tag push to the orchestrator repo, **When** the CI publishing workflow runs, **Then** a GitHub release is created with the expected artifacts (npm tarball, homebrew bottle, signed install.sh, SHA-256 checksums).
2. **Given** a published release, **When** `curl -sSL <install-url> | bash` runs from a fresh machine, **Then** the install completes and the runtime is byte-identical to npm and brew installs of the same tag.
3. **Given** a CI run on a PR (not a tag push), **When** the publishing workflow is checked, **Then** it does not run — secret-bearing publishing steps are scoped to tag-push events only.

### User Story 9 — Install-script integrity (signing, checksums, rollback) (Priority: P2)

A developer running `curl -sSL <install-url> | bash` can verify the integrity of what they're about to execute: a detached GPG (or sigstore) signature is published alongside the install script; a SHA-256 checksum is published in the GitHub release notes. After install, every release stores a `.previous-version` marker so `orchestrator:update --rollback` reverts to the prior version without manual intervention. Operators who care about supply-chain integrity have first-class verification primitives.

**Why this priority**: P2 because integrity is non-optional for a published install path that runs under `curl … | bash`. Constitution Principle XVI (Distribution Surface Integrity) makes this a launch gate. Rollback is folded in here because it shares the release-artifact surface (the `.previous-version` marker is a release artifact, not a separate concern).

**Independent Test**: Verify a release's `install.sh.sig` against the published public key (or sigstore log); verify the SHA-256 published in release notes matches the actual file. After installing, run `orchestrator:update --rollback` against a fixture project that was upgraded across two releases and assert the runtime reverts to the prior version's manifest byte-for-byte.

**Acceptance Scenarios**:

1. **Given** a published release, **When** the operator verifies the signature on `install.sh` against the published key, **Then** verification succeeds.
2. **Given** an installed orchestrator at version N, **When** the operator runs `orchestrator:update` to version N+1 followed by `orchestrator:update --rollback`, **Then** the runtime reverts to version N's manifest byte-for-byte (verified by hash).
3. **Given** a release artifact whose checksum does not match the published value, **When** an integrity-aware install path consumes it, **Then** the install fails loudly rather than silently proceeding.

### User Story 10 — `orchestrator:update` multi-source dispatch (Priority: P2)

A developer running `orchestrator:update` on a machine where the orchestrator was installed via npm sees the skill dispatch `npm update -g @spec-kit/orchestrator`. On a machine where it was installed via brew, the same skill dispatches `brew upgrade orchestrator`. On a clone-and-bash install (or operator-resolved local source repo), the same skill dispatches the existing git-source flow shipped pre-M035 on 2026-05-06. The dispatch reads `update_source: git|npm|homebrew` from `.orchestrator/config.yml`, defaulting to detect-by-install-method (#Q-6 resolution). Every run emits an `update_run` JSONL event for M027 cost+quality observability rollups.

**Why this priority**: P2 because the skill exists pre-M035 (git-source-only); P06's work is the *extension* to multi-source dispatch, not authoring from scratch. Sequenced last within M035 because it depends on P02 (npm) and P03 (homebrew) shipping the channels it dispatches to.

**Independent Test**: Stage three fixture projects with `update_source: git`, `update_source: npm`, and `update_source: homebrew` respectively. Run `orchestrator:update` (or `bash scripts/lifecycle/run-update.sh`) against each and assert the dispatched command matches the expected channel-appropriate invocation (verified via `--dry-run` flag or a stubbed dispatcher in test mode). Assert each run emits exactly one `update_run` JSONL record under `.orchestrator/observability/`.

**Acceptance Scenarios**:

1. **Given** a project with `update_source: npm` in `.orchestrator/config.yml`, **When** `orchestrator:update` runs (dry-run mode), **Then** the dispatched command is `npm update -g <package>` (or equivalent) and a `source: npm` JSONL event is emitted.
2. **Given** a project with no `update_source` configured, **When** `orchestrator:update` runs, **Then** the source is detected from install metadata (manifest or `install-meta.txt`) and persisted to config for future runs.
3. **Given** a project with `update_source: git` and a configured local source repo, **When** `orchestrator:update` runs, **Then** behavior matches the pre-M035 interim driver byte-for-byte (no regression).

---

## Edge Cases

- **Symlink-mode install on a filesystem that does not support symlinks**: the installer detects unsupported filesystem (e.g., older NFS, Windows without dev mode — explicitly out of scope per #Q-8) and refuses to proceed in symlink mode with a clear stderr message; falls back to copy mode only if `--mode=auto` is set explicitly.
- **Symlink-mode install whose source repo path moves or is deleted**: orchestrator commands fail loudly with "source repo not found at <path>" rather than producing partial results; recovery is documented (re-install in copy mode or restore the source path).
- **Drift warning when no upstream is configured**: `orchestrator:status` headline emits no drift line at all (silent suppression); no error, no warning. Distinct from "drift detected: 0 commits" which would render an explicit "up to date" line if shown — current scope shows the line only on drift.
- **Drift warning when the configured upstream path / npm registry is unreachable**: degrade gracefully — emit a single-line "drift check unavailable" advisory rather than failing `orchestrator:status` overall.
- **`install-meta.txt` predating M035 P01**: pre-existing installs lack the gitignore entry; the next install run idempotently appends the marker block. Operators who already committed `install-meta.txt` are advised in the upgrade notes to remove from index.
- **Namespace rename mid-flight against in-progress dispatched agents**: the rename is one atomic commit sequence; agents dispatched before the commit see legacy names, agents dispatched after see the new names. No straddling-agent failure mode because dispatch payloads are immutable per agent.
- **npm install on a machine without Claude Code installed**: `bin/orchestrator` succeeds (the binary is just the orchestrator's command surface), but `orchestrator:init` warns that no runtime is detected and refuses to register skills until Claude Code (or another supported runtime) is available.
- **Homebrew formula install on a system where M025's existing manifest file is owned by a different user (sudo install vs user install)**: install fails with a clear ownership-mismatch message rather than silently corrupting the manifest.
- **CI publishing run on a forked PR**: secret-bearing publishing steps must be scoped to tag-push events on the canonical repo; PR-build access to GPG keys / npm tokens / brew tap-write tokens is forbidden.
- **`orchestrator:update --rollback` when no `.previous-version` marker exists**: emits a clear "no prior version recorded — rollback unavailable" message and exits non-zero rather than silently no-oping.
- **Bundle hygiene after symlink-mode install**: symlinking `scripts/` (US-1) bypasses any pre-publish bundle filter (#Q-9); the dogfood-only artifacts are visible in symlink-mode consumers but excluded from copy-mode adopter installs. This is by design — symlink-mode is dogfood-only.

---

## Functional Requirements

- **FR-1 (install-mode-flag)**: Add `--mode=symlink|copy` flag to `packaging/install/install-claude-code.sh`, `install-codex.sh`, and `install-cursor.sh`. Default is `copy` (preserves stable consumer-install semantics today). `symlink` mode replaces per-runtime-dir `cp -R` calls with `ln -sfn` to the source repo path resolved at install time. Recorded in `.orchestrator/installed-files.txt` as a per-entry `mode:` column. Satisfies US-1.
- **FR-2 (manifest-mode-aware-uninstall)**: M025's uninstall path (`scripts/util/settings-merge.sh` + manifest replay) reads each entry's `mode:` field and dispatches `rm <symlink>` for `mode: symlink` (target untouched) vs. `rm -rf <copy>` for `mode: copy`. Reversibility-gate (install→install→uninstall byte-equality) holds for both modes. Satisfies US-1.
- **FR-3 (drift-detection-helper)**: Ship `scripts/state/check-orchestrator-drift.sh` that reads the consumer's `.orchestrator/install-meta.txt` (commit SHA + version), compares against the configured `update_source` (path / npm registry / brew formula), and emits the drift datum (`commits_behind: N` and `versions_behind: <semver-delta>`) on stdout in a structured `key=value` block. Returns exit 0 always; consumers branch on the data, not the exit code. Pure read; no I/O writes. Satisfies US-2.
- **FR-4 (drift-line-in-status-headline)**: M029's `orchestrator:status` headline block consumes `check-orchestrator-drift.sh` output and renders a `STALE: orchestrator runtime is N commits behind upstream — run \`orchestrator:update\`` line when `commits_behind > 0` (or `versions_behind > 0`, whichever the configured upstream supports). Suppressed when `update_source: none`, when no drift detected, and when the drift check itself is unavailable. Satisfies US-2.
- **FR-5 (bash-3.2-installer-exit-integrity)**: All three installer scripts replace any `set -e` + process-substitution + `while read` pattern that masks inner exit status with a process-substitution-safe form (explicit exit-status capture into an outer variable, or a `for` loop over a temp file). Regression test under `tests/installer-acceptance/` runs on macOS bash 3.2 (via Docker or macOS CI runner) and bash 4+ to confirm no platform-specific divergence. Satisfies US-3.
- **FR-6 (managed-gitignore-block)**: All three installer scripts append a managed marker block to `<PROJECT_DIR>/.gitignore` covering installer-managed sidecars (minimum: `.orchestrator/install-meta.txt`). Block delimited by `# >>> orchestrator-managed: gitignore >>>` / `# <<< orchestrator-managed: gitignore <<<`. Re-runs replace the block contents in place (idempotent). Satisfies US-4.
- **FR-7 (namespace-cohort-rename)**: Across the 15 files identified in the 2026-04-30 PR #3 audit, every operational reference to `speckit.orchestrator.*` is replaced with the `orchestrator:<command>` shape. Historical / migration documentation (`commands/migrate.md` AD-15, `templates/instruction-schema.md` legacy schema docs) preserves the legacy name framed as a documented historical reference. Co-shipped with the broader `spec-kit-orchestrator` → `orchestrator` repo / project rename in a single commit sequence. Satisfies US-5.
- **FR-8 (npm-package)**: Author `package.json` declaring the chosen scope (#Q-1 resolution). `bin/orchestrator` entry point delegates to the orchestrator command surface. Postinstall script wraps `install-claude-code.sh` (or runtime-detected equivalent). `npm publish` works idempotently from the orchestrator repo. Versions align with `CHANGELOG.md`. Satisfies US-6.
- **FR-9 (homebrew-formula-and-tap)**: Author the formula (or cask, per #Q-2) and host the tap repo (`homebrew-orchestrator` or chosen name). Formula install registers skills via M025's manifest mechanism (no formula-specific install logic). Uninstall cascades through M025. Satisfies US-7.
- **FR-10 (curl-pipe-bash-and-release-automation)**: Host `install.sh` at the chosen URL (#Q-3 resolution). CI workflow on `v*` tag pushes runs `gh release create` plus uploads (npm tarball, homebrew bottle, signed `install.sh`, SHA-256 checksums). Secret-bearing steps scoped to tag-push events only; PR builds have no secret access. Satisfies US-8.
- **FR-11 (install-script-signing)**: Every published `install.sh` is signed (sigstore keyless or project GPG key per #Q-4 resolution). SHA-256 checksums published alongside each release artifact. Verification primitives (public key location, checksum format) documented at `references/installation.md` `## Verifying integrity`. Satisfies US-9.
- **FR-12 (rollback-marker)**: Every install / update writes `.orchestrator/.previous-version` recording the prior version's manifest path / SHA. `orchestrator:update --rollback` reads this marker and reverts to the prior version's manifest byte-for-byte. Missing marker → loud failure (no silent no-op). Satisfies US-9.
- **FR-13 (orchestrator-update-multi-source-dispatch)**: Extend the pre-M035 `commands/update.md` + `scripts/lifecycle/run-update.sh` driver to read `update_source: git|npm|homebrew` from `.orchestrator/config.yml`, defaulting to detect-by-install-method (resolve from `install-meta.txt` provenance). Dispatch `git pull` + `--force` re-install (existing path), `npm update -g`, or `brew upgrade <formula>` accordingly. Emit one `update_run` JSONL event per run for M027 cost+quality observability. Satisfies US-10.
- **FR-14 (cross-channel-byte-equivalence)**: Runtime layouts produced by the npm channel (FR-8), the homebrew channel (FR-9), and the curl-pipe-bash channel (FR-10) at the same version tag are byte-identical (verified by hashing the staged runtime tree post-install across all three channels, ignoring documented per-install metadata files). Constitution Principle XVI test surface. Satisfies US-6 / US-7 / US-8.
- **FR-15 (read-only-on-render)**: The drift detection helper (FR-3), `orchestrator:status` headline composition (FR-4), and `orchestrator:update` (FR-13) — except for the rollback-marker write (FR-12) and the JSONL event emission — never mutate orchestrator state on render or check. M035's write-claim is bounded to install-time (FR-1, FR-2, FR-6), publishing-time (FR-8 through FR-11), and update-time (FR-12, FR-13) operations.
- **FR-16 (suppression-knob-honored)**: `update_source: none` in `.orchestrator/config.yml` suppresses all drift-detection rendering (FR-4). `update_run` JSONL emission honors M027's existing observability suppression knobs. M035 introduces no new suppression knob; it inherits M025 / M027 conventions.

## Success Criteria

- **SC-1**: `bash packaging/install/install-claude-code.sh --project-dir <fixture> --mode=symlink` exits 0; `grep -E 'mode: symlink' <fixture>/.orchestrator/installed-files.txt` returns at least one line per staged runtime dir; `readlink <fixture>/scripts` returns the source-repo absolute path.
- **SC-2**: `bash packaging/install/install-claude-code.sh --project-dir <fixture> --uninstall` against a symlink-mode install removes only the symlinks; `[ -d <source-repo>/scripts ]` exit 0 (source untouched). Same uninstall against a copy-mode install removes the copied tree.
- **SC-3**: `bash scripts/state/check-orchestrator-drift.sh --consumer <fixture>` against a fixture whose `install-meta.txt` records a SHA 14 commits behind the configured upstream emits stdout containing `commits_behind=14`; exit 0.
- **SC-4**: `orchestrator:status` rendered against the SC-3 fixture emits a headline including the documented drift line; exit 0. Toggling `update_source: none` in fixture config suppresses the line; no other field changes (regression check via `diff` against baseline render).
- **SC-5**: `tests/installer-acceptance/m035-collision-exit-status.sh` reproduces the pre-fix collision masking on bash 3.2 (red), then verifies the post-fix installer exits non-zero on the same fixture across both bash 3.2 and bash 4+ (green). Battery includes the bash version each run executed under.
- **SC-6**: After running any of the three installers against a fresh fixture, `<fixture>/.gitignore` contains exactly one `# >>> orchestrator-managed: gitignore >>>` marker block enclosing `.orchestrator/install-meta.txt`. Re-running the installer leaves the block count at exactly 1 (idempotent).
- **SC-7**: `grep -rE 'speckit\.orchestrator\.[a-z]' commands/ scripts/ templates/ references/ docs/ | grep -v -F -f tests/m035-acceptance/legacy-namespace-allowlist.txt` returns zero matches. The allowlist enumerates only historical / migration documentation files (e.g., `commands/migrate.md`, `templates/instruction-schema.md`).
- **SC-8**: From a fresh container without the orchestrator repo cloned, `npm install -g <published-package@<tag>>` exits 0; `which orchestrator` returns a path on PATH; `orchestrator --version` matches the `<tag>`.
- **SC-9**: From a fresh brew-equipped machine, `brew tap <org>/orchestrator && brew install orchestrator` exits 0; `orchestrator --version` matches the latest published tap version.
- **SC-10**: For a given release tag, hashing the staged runtime tree post-install (excluding documented per-install metadata files) under each channel — npm, homebrew, curl-pipe-bash — produces identical SHA-256 digests across all three. Encoded as `tests/m035-acceptance/cross-channel-byte-equivalence.sh`.
- **SC-11**: `gpg --verify install.sh.sig install.sh` (or sigstore-equivalent) succeeds for every published release; `shasum -a 256 install.sh` matches the value published in the GitHub release notes.
- **SC-12**: After `orchestrator:update` upgrades a fixture from version N to N+1, `orchestrator:update --rollback` reverts the fixture to a runtime tree whose SHA-256 matches the version-N install byte-for-byte (excluding documented metadata files).
- **SC-13**: `bash scripts/lifecycle/run-update.sh --dry-run` against fixtures with `update_source: git`, `update_source: npm`, and `update_source: homebrew` configured emits the channel-appropriate dispatched command on stdout in each case; each run appends exactly one `update_run` event to `.orchestrator/observability/<date>.jsonl`.
- **SC-14**: CI publishing workflow exercised against a synthetic `v0.0.0-test` tag push completes within the documented timeout; the resulting GitHub release contains the four required artifacts (npm tarball, homebrew bottle, signed install.sh, SHA-256 checksums file). Same workflow on a PR build does not run secret-bearing steps (verified by job-condition assertion).
- **SC-15**: Running the M035 acceptance battery (`tests/m035-acceptance/run-acceptance-battery.sh`) emits `BATTERY: pass=N fail=0` covering all SCs in this list. No flaky retries.
- **SC-16**: `validate-milestone.sh M035` reports 100% pass; the `M035-VALIDATED` marker exists on disk after milestone closure.

## Non-Goals

- **Re-architecting the installer's internals**: M025 owns `scripts/util/settings-merge.sh`, the manifest schema, and the uninstall cascade. M035 *extends* the manifest with a `mode:` column (FR-1) but does not redesign the installer.
- **Changing installed-runtime behavior**: M035 changes how the orchestrator is *delivered*, not what it does at runtime. Every other milestone touches that surface.
- **A new project-bootstrap UX**: M033 owns the warm front door (`orchestrator:start`, four-branch detection). M035's `orchestrator:update` is post-install ergonomics, not first-impression onboarding.
- **Changing `orchestrator:status` rendering**: M029 owns the headline-status surface. M035 contributes the drift datum (FR-3) and the line-shape (FR-4) but defers all rendering layout to M029.
- **A new versioning scheme**: SemVer is already in use per `CHANGELOG.md`. M035 honors the existing version line; it does not introduce a new versioning convention.
- **Docs-site / marketing-page launch**: a hosted marketing site is separate scope (likely a one-off project, not an orchestrator milestone). M035 ships package-manager presence and signed install artifacts; the question of "what landing page do those install commands appear on" is downstream.
- **Windows symlink-mode support**: per #Q-8, defer until M009 (multi-runtime parity audit) post-launch. P01 documents `--mode=symlink` as Unix-only at v1.
- **A new aggregator over M027 observability surfaces**: M035's `update_run` JSONL event flows into M027's existing `metrics-rollup.sh` / `efficiency-footer.sh` consumer surface. No new aggregator.
- **Cross-runtime parity audit beyond what M018/P07 already proved**: M009's job, demand-driven post-launch.

## Constraints

- **CON-1 (reversibility-gate)**: M025's install→install→uninstall byte-equality round-trip MUST hold for every new mode. Symlink mode adds the manifest `mode:` column; uninstall reads it and dispatches `rm <symlink>` vs. `rm -rf <copy>` accordingly. Verified by SC-2.
- **CON-2 (bash-3.2-and-POSIX-only-in-installers)**: All install logic remains bash 3.2 + POSIX-sh-compatible. CI publishing scripts may use bash 4+ since they run in GitHub Actions (Ubuntu). FR-5 explicitly closes the bash 3.2 exit-status gap.
- **CON-3 (AP-009-shape-guard-honored)**: Install scripts route compound logic through existing `scripts/util/run-probe.sh` per the AP-009 (compound-chain-gt2) convention. No new compound-chain shapes in installer paths.
- **CON-4 (never-auto-applied)**: `orchestrator:update` requires explicit invocation. No background auto-update. Drift warning is a *warning*, not an auto-action. Operator always in control.
- **CON-5 (cross-channel-byte-equivalence)**: At a given release tag, the runtime layouts produced by every distribution channel (npm, homebrew, curl-pipe-bash) are byte-identical, ignoring documented per-install metadata. Verified by SC-10.
- **CON-6 (secrets-scoped-to-tag-push)**: Publishing CI secrets (GPG / sigstore key, npm token, homebrew tap-write token) MUST be scoped to tag-push events on the canonical repo. No PR-build secret access. Verified as a job-condition check in SC-14.
- **CON-7 (M027-suppression-knobs-honored)**: `update_run` JSONL emission honors the existing M027 observability suppression knobs (no new knob introduced).

### Knowledge-Layer Boundary (M035 vs. M025 + M027 + M029 + M032)

M035 is a **distribution + update-ergonomics** milestone. It does NOT extend the knowledge-graph schema (M020), does NOT introduce new observability primitives (M027), does NOT modify status rendering (M029), and does NOT change project-asset distribution conventions (M032). M035's write claim is limited to:

- `packaging/install/install-{claude-code,codex,cursor}.sh` modifications: `--mode` flag, manifest `mode:` column, managed `.gitignore` block, bash 3.2 exit-status fix.
- `packaging/bundle/manifest.yml` — possible filter convention if #Q-9 is resolved as M035-absorbing.
- `packaging/bundle/build-bundle.sh` — possible pre-publish filter pass if #Q-9 is resolved as M035-absorbing.
- `package.json` (new), `bin/orchestrator` (new), homebrew tap repo (new), CI publishing workflow under `.github/workflows/release.yml` (new).
- `scripts/state/check-orchestrator-drift.sh` (new, read-only).
- `scripts/lifecycle/run-update.sh` modifications: multi-source dispatch (extends pre-M035 driver).
- `commands/update.md` modifications: multi-source dispatch documentation (extends pre-M035 skill).
- The `speckit.orchestrator.*` cohort rename: in-tree namespace sweep across the 15 files identified in the PR #3 audit.
- `.orchestrator/installed-files.txt` schema: extended with `mode:` column.
- `.orchestrator/.previous-version` (new, per-install rollback marker).
- `tests/m035-acceptance/`, `tests/installer-acceptance/m035-*` (new fixtures).
- `references/installation.md` `## Upgrading` and `## Verifying integrity` (extended).

M035 explicitly does NOT write to:

- `.orchestrator/KNOWLEDGE.md` schema (M020 owns).
- `execution-log.jsonl` schema (M019 owns) — `update_run` is a separate JSONL stream under `.orchestrator/observability/`, not the execution log.
- M027's `metrics-rollup.sh`, `efficiency-footer.sh`, `predictive-surface.sh` (read-only consumers; M035 emits events that flow *into* M027).
- M029's `scripts/diagnostics/render-position.sh`, headline composition logic (M035 contributes the drift datum; M029 renders).
- M032's `--with-<feature>` flag pattern or `project_assets:` schema (M035's `--mode` flag is parallel-shape, not extending).
- M013's GitHub integration sidecar (no GitHub API calls on render).

## Assumptions

- **A-1**: M025 (installer coexistence, closed) is on disk with its public surfaces stable — manifest schema, `settings-merge.sh`, uninstall cascade. M035 extends the manifest with a `mode:` column rather than redesigning.
- **A-2**: M027 (cost+quality observability surfaces, closed) provides the JSONL observability stream surface. M035 emits `update_run` events into it; M027 consumes them via existing rollup logic.
- **A-3**: M029 (roadmap visibility & CLI UX, closed) provides the `orchestrator:status` headline surface. M035 contributes the drift line; M029 renders.
- **A-4**: M032 (wiki distribution + init integration, closed) provides the `--with-<feature>` flag-shape precedent. M035's `--mode=symlink|copy` flag follows the same convention.
- **A-5**: The pre-M035 `orchestrator:update` skill (shipped 2026-05-06, git-source-only) is on disk with `commands/update.md` + `scripts/lifecycle/run-update.sh`. M035 P06 extends this driver rather than authoring from scratch.
- **A-6**: M033 (project onboarding experience, closed pending friendly-tester pass ≤ 2026-05-12) ships `orchestrator:start` and the four-branch detection surface. M035's curl-pipe-bash install path lands users at `orchestrator:start` post-install. The friendly-tester pass deadline is parallel to M035 work and not on its critical path; if the pass surfaces blocking issues, M035's user-facing install copy adapts at the documentation surface.
- **A-7**: SemVer is honored in `CHANGELOG.md`; the published-package version aligns with the top-line CHANGELOG version.
- **A-8**: The cohort rename's broader twin — `spec-kit-orchestrator` → `orchestrator` repo / project rename — is captured as a separate plan (not authored here) but ships co-located in the same commit sequence as US-5. This spec does not author the broader rename; it assumes its scope is captured elsewhere.
- **A-9**: GitHub Actions runners (Ubuntu-latest at minimum) provide the publishing-CI environment. macOS runners are required for the bash 3.2 regression test (FR-5 / SC-5).

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle I (Context Minimization)**: M035's `--mode=symlink` install (US-1) reduces total task tokens system-wide by collapsing the dogfood edit-loop's re-install overhead — every commit's distribution work drops from O(N consumer projects) to O(1). The drift warning (US-2) lowers the cost of detecting staleness from "operator must remember" to "rendered every status invocation," shifting the detection cost from human attention to mechanical render. The pre-M035 `orchestrator:update` skill is not re-authored; M035 P06 extends the existing driver, honoring the principle's "compose, don't duplicate" implication.
- **Principle II (Evidence Before Claims)**: P00 baseline (FR-5) is *required*, not optional — fresh-machine install evidence on macOS bash 3.2 + Linux drives every P01–P06 design decision, same standard as M032's pbj-central P00. Cross-channel byte equivalence (FR-14, SC-10) is the mechanical evidence that distribution channels did not silently diverge. Every SC names a command, an exit code, and an observable artifact.
- **Principle III (Design Before Code)**: Open Questions (#Q-1 through #Q-11) are surfaced rather than silently resolved. The npm scope, homebrew tap shape, GPG signing strategy, release cadence, and `update_source` default-detection logic all defer to plan-phase per the spec contract — no implementation begins until each question is resolved on disk. The bundle-hygiene fold-in question (#Q-9) and the P07 adoption-surface fold-in question (#Q-10) are explicit rather than buried.
- **Principle XV (Surgical Precision)**: M035 does not touch `auto-loop.sh`, does not modify M019/M020/M027 schemas, does not introduce new event types beyond the single `update_run` record, and does not redesign installer internals. Each new surface is bounded to a specific install / publish / update path; the blast radius is the distribution path.
- **Principle XVI (Distribution Surface Integrity)**: M035 *is* the canonical Principle XVI compliance test. Every distribution channel (npm, homebrew, curl-pipe-bash) goes through the integrity gates P05 / FR-11 specifies. FR-14 / SC-10 enforce byte-identity across channels: the hashed runtime tree post-install must match across npm, homebrew, and curl-pipe-bash at a given tag. CON-6 enforces secrets hygiene at the CI surface. This is not a side-effect; it is the load-bearing constitutional contract for the launch event.
- **Principle XIV (No Speculative Complexity)**: Windows support is deferred (#Q-8) rather than built speculatively. Bundle hygiene (#Q-9) and adoption-surface polish (#Q-10) are surfaced as fold-in questions rather than auto-absorbed. The pre-M035 interim `orchestrator:update` skill exists; M035 extends it rather than re-authoring. The spec resists every temptation to grow scope beyond the install + publish + update path.
- **Principle VIII (No Dead Infrastructure)**: Every M035 surface has an SC entry and a fixture. The acceptance battery (SC-15) exercises all SCs; surfaces without exercise rights would surface as battery gaps before close. The bash 3.2 exit-status fix (FR-5) is a delete-of-dead-state-handling masquerading as an addition — it removes a silently-passing branch, not adds a new one.

## Open Questions (defer to planning)

- **#Q-1 (npm-scope)**: `@spec-kit/orchestrator` vs `@orchestrator/cli` vs unscoped `spec-kit-orchestrator` vs `orchestrator` (likely taken). Trademark + registry collision check needed in P00 baseline. Recommendation: confirm `orchestrator` and `spec-kit-orchestrator` availability on npm; if `@spec-kit/` org is registrable, that scope is the cleanest match for the published package because it preserves the historical project name as the org slug while letting the unscoped command surface (`orchestrator:*`) align with the cohort rename in US-5. Resolve at `orchestrator:discuss` and bind US-5 / FR-7 to the resolved scope.
- **#Q-2 (homebrew-formula-vs-cask)**: Formula if the install delivers a CLI binary (`bin/orchestrator`); cask if it's a "managed installation" (more meta). Recommendation: formula. Delegates the Claude-Code-skill registration to a post-install hook. Resolve at P00 baseline.
- **#Q-3 (curl-pipe-bash-domain)**: Host on GitHub raw URL (free, ugly) vs register `orchestrator.dev` (~$15/yr, polished) vs sub-path of an existing domain. Recommendation: `orchestrator.dev` short-URL alias to GitHub raw URL — simple redirect, no hosting infrastructure. Defer registration until P04.
- **#Q-4 (signing-strategy)**: Operator's personal GPG key vs project key in CI secrets vs sigstore (keyless). Recommendation: sigstore for keyless signing primary; project CI key as fallback for compatibility. Resolve at P00 baseline; bind FR-11 / SC-11 to the resolved choice.
- **#Q-5 (release-cadence)**: Every PR merge auto-publishes a `@beta` tag; manual `gh release create` for stable. Or stable on every `main` push? Recommendation: manual stable releases pre-1.0, automatic post-1.0 with conventional-commits-driven version bumping. Resolve at P04 plan-phase.
- **#Q-6 (update-source-default)**: `git` (current de facto) vs prompt at install time vs detect by install method. Recommendation: detect by install method — installs via npm get `npm`, installs via clone get `git`. Setting persisted to `.orchestrator/config.yml` on first run. Resolve at P06 plan-phase.
- **#Q-7 (symlink-vs-hardlink)**: Symlinks survive `git pull` cleanly but break across-machine; hardlinks survive across-machine but break across-filesystem-boundary. Recommendation: symlink only, document the tradeoff in `references/installation.md` `## Symlink-mode caveats`. Resolve at P01 plan-phase.
- **#Q-8 (windows-support)**: Defer until M009 (multi-runtime parity audit) ships post-launch and provides Windows runtime evidence. P01 documents `--mode=symlink` as Unix-only at v1; copy mode (the default) is platform-agnostic. Resolve at P01 plan-phase by codifying the Unix-only documentation rather than implementing Windows symlink support.
- **#Q-9 (absorb-bundle-hygiene-proposal)**: `.orchestrator/proposals/m035-bundle-hygiene-pre-publish-filter.md` documents the 791-file dump risk: `scripts/verify/m[0-9]*-p[0-9]*-*` files are project-internal acceptance verifiers but ship in the bundle today. Proposal recommends a pattern-exclusion + magic-comment opt-out filter in `build-bundle.sh`. Should M035 absorb this as P02 fold-in (~½ day audit + ~½ day filter implementation + verifier), or defer post-launch as a fast-follow? Recommendation: **absorb as P02 fold-in** — the launch-event milestone's first npm publish must not ship 791 milestone-internal verifiers to adopters; bundle hygiene is a launch gate (Principle XVI), not a polish item. Resolve at `orchestrator:discuss` and add explicit P02 task scope if absorbed.
- **#Q-10 (absorb-P07-adoption-surface-polish)**: `.orchestrator/proposals/M035-P07-adoption-surface-polish.md` documents five adoption-polish items (voice consistency pass, origin-story doc, first-30-seconds asciinema artifacts, "When NOT" deepening, README hero-section). Items 3 and 5 hard-depend on P02–P06 publishing pipelines (asciinema must point at the published install commands). Should M035 grow a P07 phase capping at 5 days, or defer all five items to a separate post-launch M040? Recommendation: **fold as M035 P07** with a 5-day cap and a mid-flight split-off escape hatch — adoption polish IS launch readiness; splitting risks shipping M035 with a still-stale README. Resolve at `orchestrator:discuss` after operator weighs editorial scope-creep risk.
- **#Q-11 (M033-friendly-tester-pass-impact)**: M033 (project onboarding experience) closed under signed-attestation fallback; the friendly-tester pass against the four init branches is deferred to ≤ 2026-05-12 deadline (parallel to M035 work). If the friendly-tester pass surfaces blocking issues in `orchestrator:start`, the curl-pipe-bash install path's documented landing point (US-8 docs surface) may need adjustment. Recommendation: track as a parallel risk; M035 spec authoring proceeds; user-facing install-completion documentation in P04 / P06 budgets a contingency note for any M033 follow-up. Resolve at P04 plan-phase if friendly-tester findings have landed by then; otherwise note as a known operational risk.

### Conversus Gate Findings (advisory BLOCK, 2026-05-08) — defer to `orchestrator:discuss`

Pass-3 gate ran at Standard intensity (advisory). Verdict: BLOCK with 7 landed risks, 5 mitigated, 0 accepted, 2 disputed (red-blue mode, spec-pressure-test preset). Full deliberation at `specs/039-packaging-distribution/conversus/summary/final.md`; per-agent reviews / cross-reviews / revisions / disputes under `conversus/{blue-advocate,red-advocate}/`. P0 findings must be resolved at `orchestrator:discuss` before roadmap; P1/P2 findings before the relevant phase's `orchestrator:plan-phase` opens. Spec body preserved verbatim per the Standard-advisory contract; mitigations land at amend-time. Required mitigations:

- **#Q-G1 (FR-7/A-8 rename co-ship unspecced, RISK-1, P0, MIT-1)**: A-8 names "captured as a separate plan (not authored here)" with no file path / PR reference / dependency entry, while FR-7 declares co-shipment as a requirement. Plan-phase author has no coordination point for the repo-rename half of FR-7. Resolve via Option A (amend A-8 to read `captured at .orchestrator/proposals/m035-repo-rename-plan.md` — author the plan if absent; add Dependencies entry) OR Option B (amend FR-7 co-ship language to make the repo rename a contingency: ships only if a rename plan is approved before P01.5 plan-phase; otherwise FR-7 narrows to in-tree namespace sweep + named paper-cut tracking commitment). Resolve at `orchestrator:discuss`.
- **#Q-G2 (CON-5 / SC-10 / FR-14 exclusion list undefined, RISK-2, P0, MIT-2)**: "Documented per-install metadata files" appears in CON-5, SC-10, SC-12, FR-14 with zero definitions. `tests/m035-acceptance/cross-channel-byte-equivalence.sh` cannot be mechanically authored without knowing what to exclude. Resolve via enumeration block in CON-5 — minimum: `.orchestrator/install-meta.txt`, npm `package-lock.json` if present, homebrew `.brew/*.bottle.tab` receipt files; reference updates in SC-10 / SC-12 / FR-14 to read "files enumerated in CON-5's metadata-files list." Plan-phase authors extending the list update `references/installation.md § Channel-specific metadata files` first. Resolve at `orchestrator:discuss`.
- **#Q-G3 (no SC verifies repo rename in-tree surfaces, RISK-3, P0, MIT-3)**: SC-7 scopes only to `commands/ scripts/ templates/ references/ docs/`; does not check `package.json name`, `README.md`, or `CLAUDE.md`. The acceptance battery passes with the repo still named `spec-kit-orchestrator` and README still referencing old name. Resolve via SC-7b (or extend SC-7 path) gated on MIT-1 resolution: Option A (repo rename in scope) activates `grep 'spec-kit-orchestrator' CLAUDE.md README.md package.json` returns zero matches; Option B (scope narrows) explicitly omits this assertion. The GitHub repository rename is verified by a named US-5 task-plan step rather than a spec-level SC (avoids `gh api` external-dependency in acceptance tests). Resolve at `orchestrator:discuss` co-located with #Q-G1.
- **#Q-G4 (`--mode=auto` referenced in Edge Cases but absent from FR-1, RISK-4, P0, MIT-4)**: FR-1 enumerates `--mode=symlink|copy` (two values); Edge Cases describes `--mode=auto` fallback behavior. A conforming FR-1 implementation has no `--mode=auto` flag. Resolve via Option A — revise Edge Cases to read "stderr message `'symlink mode unsupported on this filesystem — re-run with --mode=copy'`; exits non-zero. No automatic fallback." (recommended: lower spec complexity, consistent with FR-1 enumeration) OR Option B — amend FR-1 to `--mode=symlink|copy|auto` with specified `auto` behavior + new SC-1b. Resolve at `orchestrator:discuss`.
- **#Q-G5 (FR-3 SHA-absent fallback undefined, RISK-6, P0, MIT-5)**: FR-3 reads "consumer's `.orchestrator/install-meta.txt` (commit SHA + version)" with no fallback for absent SHA. The three active dogfood projects (lakeledger, pbj-central, bbt-companion) installed pre-M035 lack commit SHAs — the cohort US-2 was designed to benefit. Resolve by amending FR-3 with explicit fallback: SHA-absent installs emit `commits_behind=unknown` + `versions_behind` from semver delta, plus one-time stderr advisory `'commit-SHA not recorded in install-meta.txt — drift detection using version comparison only (pre-M035 install).'` Add SC-3b covering pre-M035-format `install-meta.txt`. Resolve at `orchestrator:discuss`.
- **#Q-G6 (SC-14 timeout undefined, RISK-7, P1, MIT-6)**: SC-14 asserts CI workflow "completes within the documented timeout" — no value defined anywhere in spec. Resolve by replacing with "within 20 minutes on Ubuntu-latest" + new CON-8 (escalation clause: if measured duration consistently >15min across three synthetic-tag runs, plan-phase author splits workflow into parallel jobs or documents revised timeout). Resolve at P04 plan-phase (latest).
- **#Q-G7 (A-2 `update_run` consumption-path claim disputed, RISK-5, P1, MIT-7)**: A-2 states "M027 consumes `update_run` events via existing rollup logic"; Blue's own cross-review defense conceded the consumption path may not exist. Resolve via 15-minute codebase read of `scripts/diagnostics/metrics-rollup.sh` for `.orchestrator/observability` references. If consumed: amend A-2 to specific reference + extend SC-13 to four-field minimum (`source`, `version`, `timestamp`, `channel`). If not consumed: amend A-2 to remove false claim + add explicit M035 P06 task to extend M027's consumer (paper-cut within M035 write boundary). Resolve at `orchestrator:discuss` (codebase read can land before discuss closes).
- **#Q-G8 (FR-12 rollback semantics undefined for symlink-mode, RISK-9, P1, MIT-8)**: FR-12 specifies rollback "reverts to the prior version's manifest byte-for-byte"; in symlink mode the runtime is symlinks into the source repo, not copies — rollback shape undefined (silent no-op vs. error vs. `git checkout` in source repo affecting all consumers). Resolve by amending FR-12 with explicit symlink-mode scoping clause: rollback unsupported in symlink mode, exits non-zero with advisory `'rollback not available for symlink-mode installs — symlink-mode consumers are always at HEAD; to revert, run \`git checkout <prior-sha>\` in the orchestrator source repo.'` FR-12's byte-for-byte revert applies to copy-mode installs only. Add SC-12b covering the symlink-mode advisory path. Resolve at P01 plan-phase (latest, before P01 implementation begins).
- **#Q-G9 (FR-8 npm postinstall lacks platform guard, RISK-8, P2, MIT-9)**: FR-8 has no requirement for `package.json` to include `engines` or `os` field guard. Once P02 ships, Windows users hit opaque shell failure when postinstall runs `install-claude-code.sh`. Resolve by amending FR-8 with explicit requirement: `package.json` MUST include `"engines": {"node": ">=14"}` and `"os": ["darwin", "linux"]`. Adds one line to SC-8 testing the `unsupported_platform` rejection path. Three lines of FR amendment + three lines of `package.json` implementation. Resolve at P02 plan-phase (latest).

Disputed risks resolved by arbiter ruling: RISK-5 (#Q-G7 above — codebase read settles the dispute) and RISK-8 (#Q-G9 above — arbiter ruled in Red's favor; spec must mandate the platform guard explicitly). Mitigated risks (THREAT-3 SC-11 dual signing + #Q-4 binding mechanism, THREAT-5 FR-3/SC-3 format consistency under "structured `key=value` block" descriptor, THREAT-6 FR/SC behavioral-vs-invocation pattern explains `--consumer` flag location, THREAT-9 P00 baseline as discovery slot for npm scope registration, THREAT-10 standard fixture-based regression-test convention) survived scrutiny intact and require no spec changes.

The full risk register table is at `conversus/summary/final.md` § Risk Matrix. Per-finding evidence chains are at `conversus/{blue-advocate,red-advocate}/{review,cross-reviews,revision,disputes}.md`. The deliberation also surfaced two meta-observations worth tracking: (a) every conceded vulnerability is a supporting-detail defect (missing enumeration, missing fallback clause, orphaned flag reference, unresolvable external plan reference) — none required architectural revision, which validates the two-layer sequencing rationale and Principle XVI compliance design; (b) Red withdrew 5 of 12 original attacks after Blue's cross-review refutations, suggesting the spec's design choices (FR/SC behavioral-vs-invocation pattern, #Q-binding mechanism, P00 discovery slot, fixture-based regression convention) are technically sound even where the spec's prose around them could be tightened.

## Dependencies

- **M025 (installer coexistence, closed 2026-04-23)**: provides `scripts/util/settings-merge.sh`, `.orchestrator/installed-files.txt` manifest schema, and uninstall cascade. M035 P01 extends the manifest with a `mode:` column (FR-1, FR-2) and the uninstall path with mode-aware dispatch.
- **M027 (cost+quality observability surfaces, closed 2026-04-27)**: provides the JSONL observability stream surface. M035 P06 emits `update_run` events into this stream (FR-13).
- **M029 (roadmap visibility & CLI UX, closed 2026-05-06)**: provides the `orchestrator:status` headline surface. M035 P01 contributes the drift datum (FR-3) and line-shape (FR-4); M029 renders.
- **M032 (wiki distribution + init integration, closed 2026-05-05)**: provides the `--with-<feature>` flag-shape precedent. M035's `--mode=symlink|copy` flag (FR-1) follows the same convention.
- **M033 (project onboarding experience, closed 2026-05-04 pending friendly-tester pass)**: provides `orchestrator:start` and four-branch detection. M035's curl-pipe-bash install (US-8) lands operators at `orchestrator:start`. Friendly-tester pass deadline ≤ 2026-05-12 is parallel to M035 work (#Q-11).
- **Pre-M035 interim `orchestrator:update` skill (shipped 2026-05-06)**: provides `commands/update.md` + `scripts/lifecycle/run-update.sh` as a git-source-only driver. M035 P06 extends this driver with multi-source dispatch (FR-13) rather than re-authoring.
- **`packaging/bundle/build-bundle.sh` and `packaging/bundle/manifest.yml`**: the bundle assembly pipeline that M035 P02–P06 publishes. If #Q-9 resolves as M035-absorbing, P02 extends `build-bundle.sh` with a pre-publish filter pass.
- **GitHub Actions**: CI runner platform. macOS-latest required for the bash 3.2 regression test (FR-5). Ubuntu-latest sufficient for the publishing-CI workflow.
- **`references/installation.md`**: existing manual upgrade workflow doc — extended in P01 with `## Symlink-mode caveats` and in P05 with `## Verifying integrity` subsections.
- **`CHANGELOG.md`**: existing top-line version source — read by FR-3 drift detection logic and by FR-8 npm package version alignment.

## Downstream Consumers (informational, not binding)

- **Post-launch evaluators and adopters**: every reader landing on the orchestrator README post-launch will install via one of the three M035 channels. The runtime they receive is what they evaluate the project on; FR-14 byte-equivalence ensures the experience is identical regardless of channel choice.
- **`external-tool-adapters` (post-launch, demand-driven)**: any third-party adapter (GitHub Projects / Trello / Notion / Linear) consuming the `orchestrator:status --format=json` schema (M029 surface) benefits from the schema's stability under M035-published versioned releases. M035 does not pre-build for these but does not block them.
- **M033 onboarding (friendly-tester pass and beyond)**: warm front door composes naturally with `npm install -g` / `brew install` / `curl … | bash` install paths. The first-impression UX downstream of `orchestrator:init` benefits when the install path is one command rather than a clone-and-bash workflow.
- **CI integrators of consumer projects**: any CI pipeline using `orchestrator:status` benefits from the M035 P01 drift warning — silent staleness becomes loud staleness automatically.
- **Constitution amendment (Principle XVI Distribution Surface Integrity)**: this milestone's FR-14 + SC-10 cross-channel byte-equivalence + CON-6 secrets-hygiene scopes form the canonical compliance test surface for Principle XVI. Future distribution work (additional channels, signing-key rotation) inherits these primitives.
- **M036b post-launch slice (P08–P09)**: wiki projection and operator-facing scale UX fast-follow demand-driven. M035's published channels mean M036b's reference-corpus surface is reachable by operators who never cloned the repo.
- **M009 (multi-runtime parity audit, post-launch)**: extends the runtime-parity story to include Windows symlink-mode (#Q-8 deferral). Inherits M035's `--mode=symlink|copy` flag-shape rather than re-litigating.
