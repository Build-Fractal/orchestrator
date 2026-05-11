---
schema_version: "1.0"
type: roadmap
milestone: "M035"
feature_ref: "039-packaging-distribution"
feature_spec: "specs/039-packaging-distribution/spec.md"
vision: "Ship the launch event as eight risk-ordered phases — Layer 1 (P00 + P01 + P01.5) lands pre-launch dogfood velocity dividends and locks the Build-Fractal Orchestrator name, Layer 2 (P02–P06) constitutes the launch event itself across npm + homebrew + curl-pipe-bash channels under cross-channel byte-equivalence (Constitution Principle XVI) with M033 friendly-tester findings gating P04 and P06."
tier: "C"
created_at: "2026-05-07T00:00:00Z"
updated_at: "2026-05-07T00:00:00Z"
---

## Phases

- [x] **P00**: Baseline hardening (installer integrity + wiki-stub-drift Layer 1 + npm name collision check) — "A fresh-machine install on macOS bash 3.2 exits non-zero on collision (US-3 SC-5), every installer leaves exactly one managed `.gitignore` block enclosing `install-meta.txt` (US-4 SC-6), `wiki-stubs-fresh.sh` diagnostic + Pages pre-build gate ship in the install-template, and `npm view @build-fractal/orchestrator` collision check confirms availability for D-RN-1."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces: `packaging/install/install-{claude-code,codex,cursor}.sh` bash 3.2 exit-status fix (FR-5); installer-managed `.gitignore` block emitter (FR-6); `scripts/diagnostics/wiki-stubs-fresh.sh`; install-template `.github/workflows/pages.yml` pre-build gate (`papercut-wiki-stub-drift.md` Layer 1); `tests/installer-acceptance/m035-collision-exit-status.sh`; D-RN-1 npm-name collision check evidence; M032 `wiki-deploy.sh` bundle-staging fix (path TBD — see Open Questions).
    - Consumes: M025 manifest schema (read-only); `packaging/bundle/` install-time staging contract (read-only).

- [x] **P01**: Dev-ergonomics — `--mode=symlink` install + drift datum — "`install-claude-code.sh --mode=symlink` produces a symlink runtime tree (SC-1) with reversible uninstall (SC-2); `scripts/state/check-orchestrator-drift.sh` emits `commits_behind=N`/`versions_behind=N` against a fixture install-meta.txt (SC-3); the drift line renders inside M029's already-shipped headline block when drift > 0, suppressed cleanly when `update_source: none` (SC-4)."
  - Risk: medium
  - Depends: P00
  - Boundary Map:
    - Produces: `--mode=symlink|copy` flag in all three installers (FR-1, default `copy` per CON-7); `installed-files.txt` `mode:` column (FR-1); mode-aware uninstall in `scripts/util/settings-merge.sh` (FR-2, preserves M025 reversibility-gate per CON-1); `scripts/state/check-orchestrator-drift.sh` (FR-3, read-only) with FR-3 SHA-absent fallback per `#Q-G5`; FR-4 drift-line emitter consumed by M029's status headline (AD-4 cross-milestone composition contract); fixture `install-meta.txt` shapes for SC-3 and SC-3b (pre-M035 install).
    - Consumes: P00 installer integrity baseline; M025 manifest mechanism; M029 headline-block contract via `references/cross-milestone-feature-shape.md` (read-only).

- [x] **P01.5**: Project + namespace rename (`spec-kit-orchestrator` → `orchestrator` / `speckit.orchestrator.*` → `orchestrator:*` co-ship) — "`grep -rE 'speckit\.orchestrator\.[a-z]'` against `commands/ scripts/ templates/ references/ docs/`, filtered by `tests/m035-acceptance/legacy-namespace-allowlist.txt`, returns zero matches (SC-7); `grep 'spec-kit-orchestrator' CLAUDE.md README.md package.json` returns zero matches (SC-7b); `specs/001-speckit-orchestrator/` is renamed to `specs/001-orchestrator/` via `git mv` with content references updated; `~/.claude/projects/-Users-brettkellgren-Sites-spec-kit-orchestrator/` is migrated to `…-Sites-orchestrator/` preserving accumulated memory; pre-rename tag `v0.9.X-final-spec-kit-name` is in place; the GitHub remote `Build-Fractal/spec-kit-orchestrator` is renamed to `Build-Fractal/orchestrator` (operator-executed off-tree, GitHub auto-redirect handles legacy URL surface)."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: in-tree rename across 10 RENAME-PLAN categories (C1: path/repo basename `spec-kit-orchestrator` → `orchestrator`; C2: title-case prose `Spec-Kit Orchestrator` → `Orchestrator`; C3: lowercase prose `spec-kit orchestrator` → `orchestrator`; C4: per-line judgment on `spec-kit` standalone references — eyeball-not-sed because many refs are to the upstream spec-kit framework and stay; C5: command-cohort `speckit.orchestrator.<cmd>` → `orchestrator:<cmd>` finishes the 4 remaining operational surfaces — `templates/claude-settings.json:56`, `templates/autonomy-defaults.yaml:91`, `templates/instruction-schema.md:140`, `templates/compression-tier3-prompt.md:14,45`; C6: local paths `~/Sites/spec-kit-orchestrator` → `~/Sites/orchestrator` in operator scripts + `references/installation.md` recipes; C9: `git mv specs/001-speckit-orchestrator/` → `specs/001-orchestrator/` + content reference updates; C10: Claude memory project-key migration); `tests/m035-acceptance/legacy-namespace-allowlist.txt` enforcing SC-7 going forward (allowlists historical/migration files: `commands/migrate.md`, `docs/migrating-from-speckit.md`, `references/RENAME-PLAN.md`, `scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt`, `scripts/state/namespace-aliases.sh`); SC-7b grep-zero-match assertion in the M035 acceptance battery; `D-RN-1..D-RN-7` decisions recorded in `.orchestrator/DECISIONS.md` as a `D0XX` block; pre-rename `v0.9.X-final-spec-kit-name` tag preserved.
    - Consumes: P00 D-RN-1 npm-name collision-check evidence (`@build-fractal/orchestrator` confirmed available); RENAME-PLAN.md runbook (read-only); PR #3 audit list (read-only); existing D-RN-1..D-RN-7 decisions (D-RN-1: `@build-fractal/orchestrator`; D-RN-2: `Build-Fractal/orchestrator`; D-RN-3: `orchestrator:<cmd>`; D-RN-4: `build-fractal/orchestrator` single-formula tap; D-RN-5: `~/Sites/orchestrator`; D-RN-6: migrate Claude memory; D-RN-7: tag pre-rename).

- [x] **P02**: npm publishing pipeline (`@build-fractal/orchestrator`) — "From a fresh container without the orchestrator repo cloned, `npm install -g @build-fractal/orchestrator@<tag>` exits 0; `which orchestrator` returns a path on PATH; `orchestrator --version` matches the `<tag>` (SC-8); cross-channel byte-equivalence test (`tests/m035-acceptance/cross-channel-byte-equivalence.sh`) is bootstrapped with the npm-channel hash assertion."
  - Risk: high
  - Depends: P01.5
  - Boundary Map:
    - Produces: `package.json` declaring `@build-fractal/orchestrator` (D-RN-1); `bin/orchestrator` entry point delegating to the orchestrator command surface (FR-8); postinstall script wrapping `install-claude-code.sh` or runtime-detected equivalent; `.github/workflows/release.yml` skeleton with npm-tarball build + publish job (CON-6 secrets scoped to `v*` tag-push events only, SC-14 PR-build job-condition assertion); `tests/m035-acceptance/cross-channel-byte-equivalence.sh` skeleton with npm-channel hash assertion (CON-5, AD-2 Constitution Principle XVI test).
    - Consumes: P01.5 cohort prefix and `@build-fractal/orchestrator` rename surface; P00 npm-name collision-check evidence; `CHANGELOG.md` SemVer source-of-truth (CON-4).

- [x] **P03**: Homebrew formula + tap (`build-fractal/orchestrator`) — "From a fresh brew-equipped machine, `brew tap build-fractal/orchestrator && brew install orchestrator` exits 0; `orchestrator --version` matches the latest published tap version (SC-9); `cross-channel-byte-equivalence.sh` is extended with the homebrew-channel hash assertion." Closed 2026-05-09 — `tools/verify/m035-p03-phase-suite.sh` BATTERY pass=7 fail=0; CON-5 cross-channel byte-equivalence verified end-to-end (NPM_HASH = HOMEBREW_HASH); MOS-1 + MOS-2 cleared, MOS-3 deferred to first-release smoke per plan.
  - Risk: medium
  - Depends: P02
  - Boundary Map:
    - Produces: `Build-Fractal/homebrew-orchestrator` tap repo (D-RN-4 single-formula tap); the formula (FR-9, registers skills via M025's manifest mechanism, no formula-specific install logic, uninstall cascades through M025); `.github/workflows/release.yml` extended with homebrew-bottle upload step (CON-6 secret scoping); `cross-channel-byte-equivalence.sh` extended with homebrew-channel hash assertion.
    - Consumes: P02 release-workflow shape; M025 manifest mechanism (uninstall cascade contract).

- [x] **P05**: Install-script integrity — signing + checksums + rollback marker — "`gpg --verify install.sh.sig install.sh` (or sigstore-equivalent per `#Q-3`) succeeds for every published release (SC-11); `shasum -a 256 install.sh` matches the value in GH release notes; rollback marker `.orchestrator/.previous-version` is written by every install/update; `orchestrator:update --rollback` reverts a fixture from N+1 to N byte-for-byte (SC-12)."
  - Risk: high
  - Depends: P02
  - Blocked by: none
  - Boundary Map:
    - Produces: signing infrastructure (key-management primitives + verification surface, `#Q-3` GPG-vs-sigstore resolved at P05 plan-phase, MIT-MIT-relevant); SHA-256 checksum publication step in `.github/workflows/release.yml` (FR-11); `.orchestrator/.previous-version` rollback-marker contract written at every install/update with prior version's manifest path/SHA (FR-12, `#Q-4` rollback-marker storage resolved at P05 plan-phase); `commands/update.md --rollback` dispatch reading the marker and reverting byte-for-byte (FR-12, missing-marker → loud failure no silent no-op); `references/installation.md § Verifying integrity` documenting public-key location + checksum format (FR-11).
    - Consumes: P02 release-workflow shape (extends, does not redefine).

- [x] **P04**: Curl-pipe-bash one-liner + GH release automation — "Hosted `install.sh` at the chosen URL works as `curl https://… | bash`; on `v*` tag push, `gh release create` uploads the four required artifacts (npm tarball, homebrew bottle, signed `install.sh`, SHA-256 checksums) within the documented timeout; the same workflow on a PR build does not run secret-bearing steps (SC-14 job-condition assertion); `cross-channel-byte-equivalence.sh` is extended with the curl-pipe-bash-channel hash assertion." Closed 2026-05-09 — `tools/verify/m035-p04-phase-suite.sh` BATTERY pass=6 fail=0; CON-5 cross-channel byte-equivalence lifted to 3-way (NPM_HASH = HOMEBREW_HASH = CURL_HASH); D009 (URL host) + D010/CON-8 (20-min timeout + escalation) + D011 (manual pre-1.0 cadence) recorded; MOS-4 + MOS-5 deferred to first-release smoke per plan.
  - Risk: high
  - Depends: P02, P03, P05
  - Blocked by: M033 friendly-tester pass (deadline 2026-05-12, protocol at `tests/m033-acceptance/friendly-tester-pass/protocol.md`) — P04 plan-phase entry blocks until the friendly-tester pass either completes or its findings are reviewed (`#Q-11`); allocate documentation contingency buffer at P04 plan-phase for any `orchestrator:start` adjustments surfaced by the pass.
  - Boundary Map:
    - Produces: hosted `install.sh` at the chosen URL (FR-10, URL resolution at P04 plan-phase per `#Q-3` family); `.github/workflows/release.yml` complete on-`v*`-tag-push pipeline composing npm tarball (P02) + homebrew bottle (P03) + signed install.sh + checksums (P05) + secret-scoping job conditions (CON-6, AD-3 acceptance-test invariant); `cross-channel-byte-equivalence.sh` extended with curl-pipe-bash-channel hash assertion (CON-5 third-channel coverage).
    - Consumes: P02 npm tarball job; P03 homebrew bottle job; P05 signing infrastructure + checksum step + rollback-marker contract; M033 friendly-tester findings (review-only, may inform documentation deltas).

- [x] **P06**: `orchestrator:update` multi-source dispatch + acceptance battery — "`bash scripts/lifecycle/run-update.sh --dry-run` against fixtures with `update_source: git`, `update_source: npm`, and `update_source: homebrew` configured each emits the channel-appropriate dispatched command on stdout; each run appends exactly one `update_run` event to `.orchestrator/observability/<date>.jsonl` (SC-13); `orchestrator:update --rollback` reverts byte-for-byte (SC-12 verified end-to-end); the M035 acceptance battery (`tests/m035-acceptance/run-acceptance-battery.sh`) emits `BATTERY: pass=N fail=0` covering all SCs (SC-15); `validate-milestone.sh M035` reports 100% pass; the `M035-VALIDATED` marker exists on disk (SC-16)."
  - Risk: medium
  - Depends: P02, P03, P04
  - Blocked by: M033 friendly-tester pass (same wiring as P04) — P06 plan-phase entry blocks until findings are reviewed; allocate documentation contingency buffer for any `commands/update.md` adjustments.
  - Boundary Map:
    - Produces: `update_source: git|npm|homebrew` config schema in `.orchestrator/config.yml` (FR-13, `#Q-5` schema details resolved at P06 plan-phase); multi-source dispatch in `scripts/lifecycle/run-update.sh` (FR-13, AD-5 detect-by-install-method-first when `update_source` absent, persists detected source to config for future runs); `update_run` JSONL event emission honoring CON-7/M027 suppression knobs (FR-13, FR-16); extended `commands/update.md` documenting multi-source dispatch (extends pre-M035 interim driver per `commands/update.md:88`); `tests/m035-acceptance/run-acceptance-battery.sh` covering SC-1..SC-14 + SC-15 self-reference; `M035-VALIDATED` marker + `M035-SUMMARY.md` on milestone closure.
    - Consumes: P02 npm install path; P03 homebrew formula; P04 release-tag publication shape; P05 rollback-marker contract; M027 observability suppression-knob convention (read-only).

## Cross-Cutting Concerns

- **CON-5 cross-channel byte-equivalence (Constitution Principle XVI test)** — touches P02, P03, P04. P02 establishes `tests/m035-acceptance/cross-channel-byte-equivalence.sh` skeleton + npm-channel hash assertion; P03 extends with homebrew-channel assertion; P04 extends with curl-pipe-bash-channel assertion. The CON-5 exclusion list is enumerated per `#Q-G2` base list — `.orchestrator/install-meta.txt` (always, every channel), npm `node_modules/` + lockfile artifacts under npm install path, homebrew receipt files (`.brew/*.bottle.tab`), channel-specific compiled-on-install artifacts (TBD per P02/P03 plan-phase). Plan-phase authors extending the list update `references/installation.md § Channel-specific metadata files` first, then reference from CON-5. AD-2 declares this an acceptance test, not an implementation goal.

- **CON-6 CI secrets hygiene (publishing-pipeline secret scoping)** — touches P02, P03, P04. Secret-bearing publishing steps run only on `v*` tag-push events on the canonical repo, never on PR runs. The fork-PR exfiltration attack vector against npm/homebrew/sigstore credentials is closed by job-condition assertions verified in SC-14 (PR-context dry-run probe that publishing steps are skipped or scoped). AD-3 declares this an acceptance test.

- **`update_run` JSONL emission** — produced by P06 only. P02/P03/P04 publishing pipelines do **not** emit `update_run` JSONL (write-claim is bounded to install/publish/update operations per FR-15). M027 suppression knobs honored (CON-7); M035 introduces no new suppression knob.

- **M025 manifest reversibility-gate (install→install→uninstall byte-equality)** — touches P00, P01, P02, P03. Every phase that adds an install-side artifact preserves the round-trip. P01's `mode:` column extension (FR-1, FR-2) is the load-bearing change — mode-aware uninstall in `scripts/util/settings-merge.sh` dispatches `rm <symlink>` for `mode: symlink` vs. `rm -rf <copy>` for `mode: copy` (CON-1 verified via SC-2).

- **M033 friendly-tester findings buffer** — touches P04, P06. The M033 friendly-tester pass deadline is 2026-05-12 (per launch-sequencing-amendment Q-1, protocol at `tests/m033-acceptance/friendly-tester-pass/protocol.md`). Findings on `orchestrator:start` may require P04/P06 documentation adjustments. Documentation contingency budget is allocated at each phase's plan-phase per `#Q-11`. Hard `Blocked by:` external prerequisite gates entry into P04 and P06 plan-phases until the pass either completes or its findings are reviewed.

- **AD-7 plan-phase-routed Open Questions** — `#Q-3..#Q-10` and `#Q-G6..#Q-G9` resolve at named plan-phase, not at roadmap. The roadmap surfaces them as plan-phase obligations only: `#Q-3` (signing tool: GPG vs sigstore) → P05; `#Q-4` (rollback marker storage) → P05; `#Q-5` (config schema for `update_source`) → P06; `#Q-6` (detect-by-install-method default) → already resolved by AD-5; `#Q-7` (CI runner) → P02; `#Q-8` (filesystem detection for symlink mode) → P01; `#Q-9` (install-meta.txt schema extension) → P01; `#Q-10` (publishing-pipeline test fixture strategy) → P02; `#Q-G6..#Q-G8` → relevant plan-phase per AD-7 P1 routing; `#Q-G9` (Windows postinstall guard, MIT-9) → P02.

- **M032 `wiki-deploy.sh` bundle-staging fix — open question for P00 plan-phase** — M035-CONTEXT.md `## Boundary with M032 / M037` declares this fix folds into M035 P00, but `packaging/install-template/` (the path the M032-SUMMARY referenced) does not exist on disk and `find packaging -name 'wiki-deploy.sh'` returns no matches. P00 plan-phase resolves: where does `wiki-deploy.sh` actually live, was the M032 deferred-validation acknowledgment ever wired, and does the fix scope still match P00's installer-integrity theme. Routed as a P00 plan-phase Open Question rather than blocking roadmap because the file-system detective work belongs in P00's planning frame.

- **Open Questions resolved at this roadmap step (no further routing)**:
  - `#Q-G1` (FR-7/A-8 external rename plan): **Option A** — full repo + namespace co-ship lands in P01.5. SC-7b activated.
  - `#Q-G2` (CON-5 exclusion list base enumeration): base list above; plan-phase extensions documented in `references/installation.md` first.
  - `#Q-G3` (SC-7b activation gating): **active** under `#Q-G1` Option A.
  - `#Q-G4` (`--mode=auto` reconciliation): **Option A** — Edge Cases revised to "stderr message + exit non-zero, no automatic fallback"; FR-1 stays `--mode=symlink|copy`.
  - `#Q-G5` (FR-3 SHA-absent fallback): SHA-absent installs emit `commits_behind=unknown` + `versions_behind` from semver delta against `CHANGELOG.md` top-line; one-time stderr advisory; SC-3b covers the pre-M035 install-meta.txt shape.
  - Wiki-stub-drift Layer 1 placement: **P00** (CI/install-template integrity theme).
  - Wiki-stub-drift Layer 2 ownership: **peeled out** as a standalone install-template paper-cut; ships independently of M035 closure.
  - Wiki-stub-drift verify integration: **CI-gate-only initially**; verify-time check deferred unless future workflow ships stubs without going through CI.
  - `#Q-1` (npm package name): **`@build-fractal/orchestrator`** (D-RN-1 — unscoped `orchestrator` is taken; collision-checked at P00).
  - `#Q-2` (homebrew tap-vs-cask + tap-org name): **tap, not cask**; `build-fractal/orchestrator` single-formula tap (D-RN-4); resolved here because D-RN-1 resolution unblocks D-RN-4.
  - `#Q-11` (M033 friendly-tester pass overlap): documentation contingency buffer at P04/P06 plan-phases; hard `Blocked by:` external prerequisite on roadmap entry into P04 and P06.
  - **D-RN-1..D-RN-7** decision block (recorded as `D0XX` in `.orchestrator/DECISIONS.md` at P01.5 plan-phase): D-RN-1 `@build-fractal/orchestrator`; D-RN-2 `Build-Fractal/orchestrator`; D-RN-3 `orchestrator:<cmd>`; D-RN-4 `build-fractal/orchestrator`; D-RN-5 `~/Sites/orchestrator`; D-RN-6 migrate Claude memory; D-RN-7 tag `v0.9.X-final-spec-kit-name`.

## Dependency Graph

```
P00 ──► P01 ──► P01.5 ──► P02 ──┬──► P03 ─────────┐
                                │                 │
                                ├──► P05 ─────────┤
                                │                 │
                                │                 ▼
                                │                P04* ──► P06*
                                │                 ▲
                                └─────────────────┘

* P04 and P06 are externally Blocked-by the M033 friendly-tester pass
  (deadline 2026-05-12). All phase Depends: edges are satisfied earlier;
  the friendly-tester gate is a separate external prerequisite per the
  template's Blocked-by convention. Documentation contingency budget
  allocated at each phase's plan-phase.
```

## Execution Order

1. **P00** — foundation, no dependencies. Bash 3.2 exit-status fix + managed `.gitignore` block + wiki-stub-drift Layer 1 + npm-name collision check evidence + M032 `wiki-deploy.sh` location investigation.
2. **P01** — depends on P00. `--mode=symlink` install option + `check-orchestrator-drift.sh` + FR-4 drift line in M029's headline.
3. **P01.5** — depends on P01. **Project + namespace rename co-ship** across RENAME-PLAN categories C1, C2, C3, C4, C5, C6, C9, C10. **Hard sequencing constraint per AD-6**: must precede P02 because the npm v1 tarball bakes the cohort prefix and package name forever; renaming after P02 means a deprecated package and a forced rename.
4. **P02** — depends on P01.5. npm publishing pipeline + `cross-channel-byte-equivalence.sh` skeleton.
5. **P03 and P05 can execute concurrently** — both depend only on P02. P03 ships the homebrew tap and extends the byte-equivalence test; P05 ships the signing infrastructure and rollback-marker contract. Neither depends on the other; both extend the release-workflow shape established in P02 along orthogonal axes.
6. **P04** — depends on P02 + P03 + P05. **Blocked by** M033 friendly-tester pass (≤2026-05-12 deadline). Curl-pipe-bash one-liner + GH release automation composes all three upstream artifacts and ships the third byte-equivalence-test channel.
7. **P06** — depends on P02 + P03 + P04. **Blocked by** M033 friendly-tester pass (same wiring as P04). `orchestrator:update` multi-source dispatch + acceptance battery + `M035-VALIDATED` marker on closure. P05 rollback-marker contract is consumed but P05 is not a hard `Depends:` because P05 ships before P04, and P06 transitively depends on P05 via P04.

## Validation

- **No conflicting producers**: PASS — each phase produces a disjoint surface. P02 establishes `.github/workflows/release.yml` and `cross-channel-byte-equivalence.sh` skeletons; P03/P04/P05 extend them additively (homebrew-bottle job, curl-pipe-bash composition + secret-scoping, signing + checksum step). No two phases produce the same artifact at the same key. The four operational `speckit.orchestrator.*` surfaces in P01.5 are not produced by any earlier phase (the prior in-tree rename was M008/M015-era and is correctly recognized as already-shipped; P01.5 finishes the residual surfaces).

- **All consumed items have producers**: PASS — every `Consumes` entry traces upward to a produced item or a pre-existing read-only contract. P00 consumes M025 manifest schema (pre-existing). P01 consumes P00 baseline + M029 headline-block contract (pre-existing per `references/cross-milestone-feature-shape.md`). P01.5 consumes P00 npm-name collision evidence + RENAME-PLAN.md (pre-existing). P02 consumes P01.5 cohort + `CHANGELOG.md` SemVer (pre-existing). P03 consumes P02 release-workflow shape + M025 manifest mechanism (pre-existing). P05 consumes P02 release-workflow shape (extends only). P04 consumes P02 + P03 + P05 deliverables. P06 consumes P02 + P03 + P04 + P05 rollback-marker (transitively via P04) + M027 suppression-knob convention (pre-existing).

- **DAG is acyclic**: PASS — linear backbone P00 → P01 → P01.5 → P02 fans out to {P03 ∥ P05}; P04 depends on {P02, P03, P05}; P06 depends on {P02, P03, P04}. No cycles. The `Blocked by:` external prerequisites on P04 and P06 (M033 friendly-tester pass) are not phase edges per the roadmap-template convention and do not affect DAG acyclicity.

- **Demo sentence coverage**: PASS — every phase's demo sentence references at least one concrete success criterion (P00 → SC-5/SC-6; P01 → SC-1/SC-2/SC-3/SC-4; P01.5 → SC-7/SC-7b; P02 → SC-8; P03 → SC-9; P05 → SC-11/SC-12; P04 → SC-14; P06 → SC-12/SC-13/SC-15/SC-16) and is observable post-phase without requiring downstream-phase artifacts.
