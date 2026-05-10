---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M032"
milestone: "M032"
provides:
  - "project_assets manifest schema; read-project-assets.sh shared reader; install-asset-mode.sh per-mode handler (copy + symlink + windows fail-closed); install-collision-check.sh FR-22 dual-oracle hierarchy (tracking-file + MIT-006 bootstrapping + operator-owned),install-claude-code.sh project_assets-driven runtime payload stage (FR-2 + FR-3 + FR-4 + FR-22); pre-M032 golden file-tree shape (tools/verify/fixtures/m032-pre-m032-golden.txt); --asset-mode-override flag (TEST-ONLY P01 surface); m032-p01-install-cc-byte-identical.sh verifier,install-codex.sh + install-cursor.sh migrated to project_assets: schema; --asset-mode-override flag added to both; cross-installer parity locked via tools/verify/m032-p01-installers-parity.sh,tests/fixtures/m032-fresh-project-fixture/ (.gitignore + .git-init-marker + README.md) shared with P02..P04; tests/m032-acceptance/p01-{managed-bundle-shape,symlink-mode,staged-dirs-collision}.sh (SC-1 + SC-2 + SC-10 acceptance scripts); tools/verify/m032-p01-{fixture-shape,acceptance-shape-sc1,acceptance-shape-sc2,acceptance-shape-sc10,phase-suite,scope-guard}.sh; tools/verify/fixtures/m032-p01-baseline-ref.txt (P01 baseline ref for SC-13 scope-guard)"
requires:
  - "none"
affects:
  - "P02"
key_files:
  - "packaging/bundle/manifest.yml,scripts/lifecycle/read-project-assets.sh,scripts/lifecycle/install-asset-mode.sh,scripts/lifecycle/install-collision-check.sh,tools/verify/m032-p01-manifest-schema-shape.sh,tools/verify/m032-p01-reader-emits-tuples.sh,tools/verify/m032-p01-mode-handler-symlink.sh,tools/verify/m032-p01-installed-files-format.sh,tools/verify/m032-p01-collision-oracle.sh,packaging/install/install-claude-code.sh,tools/verify/m032-p01-install-cc-byte-identical.sh,tools/verify/fixtures/m032-pre-m032-golden.txt,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,tools/verify/m032-p01-installers-parity.sh,tests/fixtures/m032-fresh-project-fixture/.gitignore,tests/fixtures/m032-fresh-project-fixture/.git-init-marker,tests/fixtures/m032-fresh-project-fixture/README.md,tests/m032-acceptance/p01-managed-bundle-shape.sh,tests/m032-acceptance/p01-symlink-mode.sh,tests/m032-acceptance/p01-staged-dirs-collision.sh,tools/verify/fixtures/m032-p01-baseline-ref.txt,tools/verify/m032-p01-fixture-shape.sh,tools/verify/m032-p01-acceptance-shape-sc1.sh,tools/verify/m032-p01-acceptance-shape-sc2.sh,tools/verify/m032-p01-acceptance-shape-sc10.sh,tools/verify/m032-p01-phase-suite.sh,tools/verify/m032-p01-scope-guard.sh"
key_decisions:
  - "FR-1,FR-2,FR-3,FR-22,NG-9,MIT-006,CON-4,AD-19,N/A,SC-1,SC-2,SC-10,SC-13,FR-4,MIT-001"
patterns_established:
  - "dual-oracle collision-check hierarchy with MIT-006 bootstrapping carve-out; tab-delimited column-1 installed-files.txt FILE FORMAT INVARIANT documented inline at the consumer; per-mode handler dispatches on key=value emit tokens (no mode: colon-literal in path-vicinity); Windows fail-closed via M032_FORCE_WINDOWS=1 OR absent ln,record-golden-before-migrating (load-bearing ordering invariant); two-pass project_assets tuple loop with printf-b joined target list for collision-check argv; column-1 awk extraction for installed-files.txt back-compat read paths,cross-installer parity invariant: project-asset staging block is byte-identical (78 lines) across all three installers; differences confined to surrounding runtime-specific context (skill-registration,hook-payload,settings-merge,--project-dir requirement),fixture-staging via mktemp -d + cp -R + git init + git remote add origin (committed fixture stays immutable; runtime .git/ materialized at test time); deny-all-then-allow-one .gitignore amendment for exercising the FR-22 operator-owned oracle branch (the fresh-project-fixture's .gitignore otherwise excludes commands/ which would mask operator-owned status); SC-13 baseline-ref captured to tools/verify/fixtures/m032-p01-baseline-ref.txt at scope-guard first run; phase-suite straight-line aggregator with single-script-file shape per AD-19"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P01/tasks/T01-manifest-and-libraries-SUMMARY.md, .orchestrator/milestones/M032/phases/P01/tasks/T02-install-claude-code-migration-SUMMARY.md, .orchestrator/milestones/M032/phases/P01/tasks/T03-install-codex-cursor-migration-SUMMARY.md, .orchestrator/milestones/M032/phases/P01/tasks/T04-fixture-and-acceptance-tests-SUMMARY.md"
duration: "210m"
verification_result: "pass"
completed_at: "2026-05-04T17:57:14Z"
observability_surfaces:
  - "none"
---

## What Shipped

P01 replaces the unmanaged `RUNTIME_DIRS` bulk-copy in all three installers
(`install-{claude-code,codex,cursor}.sh`) with a managed `project_assets:`
schema entry in `packaging/bundle/manifest.yml`, drives all three installers
from that single seam, and lands the FR-22 dual-oracle collision hierarchy
plus the SC-1 / SC-2 / SC-10 acceptance scripts and the `m032-p01-*`
verifier suite. The shared fresh-project fixture used by P02..P04 lands here
too. Default behavior at `mode: copy` is byte-identical to the pre-M032
`cp -R` path; `mode: symlink` is wired and POSIX-only with Windows
fail-closed (NG-9).

The four task tranches:

1. **T01 — Manifest + libraries**: appended `project_assets:` to
   `packaging/bundle/manifest.yml` (four entries: `commands/`, `scripts/`,
   `references/`, `templates/`), each declaring `source:` / `target:` /
   `mode: copy`. Authored `scripts/lifecycle/read-project-assets.sh`
   (shared reader, emits tab-separated `source=<src>\ttarget=<tgt>\tmode=<m>`
   tuples), `scripts/lifecycle/install-asset-mode.sh` (per-mode handler:
   copy + symlink + Windows fail-closed via `M032_FORCE_WINDOWS=1` OR absent
   `ln`), and `scripts/lifecycle/install-collision-check.sh` (FR-22
   dual-oracle hierarchy: tracking-file + MIT-006 bootstrapping carve-out +
   operator-owned). Pre-M032 manifest keys preserved byte-identically.

2. **T02 — install-claude-code migration (FR-2 + FR-3 + FR-4 + FR-22)**:
   replaced the hardcoded `RUNTIME_DIRS` bulk-copy at
   `install-claude-code.sh:415-458` with a `project_assets:`-driven loop
   that calls `read-project-assets.sh` then dispatches each tuple to
   `install-asset-mode.sh`. `installed-files.txt` extended with a per-asset
   `mode:` field (FR-4). Added the test-only `--asset-mode-override` flag
   for SC-2 symlink coverage. Recorded the pre-M032 file-tree golden at
   `tools/verify/fixtures/m032-pre-m032-golden.txt` *before* migrating
   (load-bearing ordering invariant — record-golden-before-migrating).

3. **T03 — install-codex + install-cursor migration**: applied the same
   `project_assets:` migration to `install-codex.sh` and `install-cursor.sh`.
   Cross-installer parity is locked: the project-asset staging block is
   byte-identical (78 lines) across all three installers; differences are
   confined to surrounding runtime-specific context (skill-registration,
   hook-payload, settings-merge, Codex's `--project-dir` requirement).

4. **T04 — Fixture + acceptance battery**: landed
   `tests/fixtures/m032-fresh-project-fixture/` (`.gitignore` +
   `.git-init-marker` + `README.md`) shared with P02..P04;
   the SC-1 / SC-2 / SC-10 acceptance scripts under `tests/m032-acceptance/`;
   and the full `tools/verify/m032-p01-*.sh` verifier battery
   (manifest-schema-shape, reader-emits-tuples, mode-handler-symlink,
   installed-files-format, collision-oracle, install-cc-byte-identical,
   installers-parity, fixture-shape, acceptance-shape-{sc1,sc2,sc10},
   phase-suite, scope-guard).

## Verification Results

`P01-VERIFICATION.md`: PASS — 99/99 must-haves, phase-suite `pass=11 fail=0`,
boundary-map exit 0 (legitimate SKIP — the P01 Produces line is prose-shaped
with `;` separators between rich deliverable descriptions, not bare
comma-separated paths, so the tokenizer correctly finds nothing
single-path-token-shaped to disk-check; produce verification rides the
must-haves Artifacts section + SC acceptance scripts, both green).

Trajectory: initial 89 PASS / 10 FAIL → post-rebaseline 98 PASS / 1 FAIL →
post-scope-guard-fix 99 PASS / 0 FAIL. Three load-bearing fixes resolved the
failures: (1) refreshed the pre-M032 golden + baseline-ref to current HEAD
([M033](../../../../milestones/M033/index.md) closure had invalidated both); (2) scope-guard switched from
working-tree-vs-baseline to committed-history-only diff
(`baseline_ref..HEAD`) so ambient working-tree dirt no longer pollutes the
scope signal; (3) `check-boundary-map.sh` parser learned to strip
brace-globs alongside parentheticals so `install-{claude-code,codex,cursor}.sh`'s
inner commas no longer tokenize as separate produce items.

## Key Decisions

- **MIT-006 bootstrapping carve-out**: pre-M032 consumers without
  `installed-files.txt` are detected at install time; the bootstrapping
  branch writes the tracking file from the current state instead of failing
  closed against the operator-owned oracle.
- **Tab-delimited column-1 `installed-files.txt` FILE FORMAT INVARIANT**:
  documented inline at the consumer; future readers extract via column-1
  awk for back-compat read paths.
- **POSIX-only symlink mode (NG-9)**: Windows fail-closed via either
  `M032_FORCE_WINDOWS=1` or absent `ln`, with the documented
  "POSIX-only in v1" diagnostic.
- **record-golden-before-migrating**: load-bearing ordering invariant —
  T02/T03 captured the pre-M032 file-tree golden *before* touching any
  installer body, locking the byte-identical CON-4 contract at default
  `mode: copy`.
- **--asset-mode-override flag (TEST-ONLY)**: P01 surface only, gated to
  the SC-2 symlink-mode acceptance path; not exposed in operator UX.

## Patterns Established

- Dual-oracle collision-check hierarchy with MIT-006 bootstrapping carve-out
  (reusable for any future managed-asset scheme that needs to coexist with
  pre-existing operator state).
- Per-mode handler dispatches on `key=value` emit tokens — no `mode:`
  colon-literal in path-vicinity, sidestepping AD-19 harness heuristics on
  `:` in compound bash.
- Fixture-staging via `mktemp -d` + `cp -R` + `git init` + `git remote add
  origin` (committed fixture stays immutable; runtime `.git/` materialized
  at test time). Deny-all-then-allow-one `.gitignore` amendment exercises
  the FR-22 operator-owned oracle branch.
- Phase-suite straight-line aggregator with single-script-file shape per
  AD-19 — replicable for future M0##/P##-suite verifiers.
- SC-13 baseline-ref captured to a fixture file at scope-guard first run
  (`tools/verify/fixtures/m032-p01-baseline-ref.txt`); committed-history
  diff (not working-tree) is the correct scope signal.

## Affects Downstream

- **P02** consumes the manifest schema + reader + per-mode handler +
  collision-check + fresh-project fixture. P02's `wiki/` asset type folds
  into the same `project_assets:` schema; collision-check carries forward
  unchanged.
- **P03 + P04** pick up the fixture and the verifier conventions
  established here.
