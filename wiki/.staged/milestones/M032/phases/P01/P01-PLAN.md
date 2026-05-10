---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M032"
goal: "Replace the unmanaged `RUNTIME_DIRS` bulk-copy at `install-{claude-code,codex,cursor}.sh` with a managed `project_assets:` schema entry in `packaging/bundle/manifest.yml` (FR-1), drive all three installers from that schema with byte-identical default behavior at `mode: copy` (FR-2 + CON-4), add the `mode: symlink` POSIX handler with Windows fail-closed (FR-3 / NG-9), extend `.orchestrator/installed-files.txt` with the per-asset `mode:` field (FR-4), and implement the FR-22 dual-oracle collision hierarchy with the MIT-006 pre-M032 bootstrapping branch — landing the `tests/fixtures/m032-fresh-project-fixture/` shared by P02..P04 plus the SC-1 / SC-2 / SC-10 acceptance scripts and a `tools/verify/m032-p01-*.sh` phase-suite aggregator."
demo_sentence: "An operator runs `bash packaging/install/install-claude-code.sh --project-dir tests/fixtures/m032-fresh-project-fixture/` against a fresh fixture and observes (a) all four of `commands/`, `scripts/`, `references/`, `templates/` populated with file counts matching the pre-M032 golden recorded in T04, (b) `<fixture>/.orchestrator/installed-files.txt` written with a `mode:` field on every entry, (c) a second invocation produces byte-identical output (idempotency); on a POSIX host with `~/.claude/orchestrator-runtime/<version>/` populated, the operator runs `bash packaging/install/install-claude-code.sh --project-dir <fixture> --asset-mode-override symlink` and observes the four runtime dirs resolved as symlinks to the runtime cache and `git -C <fixture> status --short -- commands scripts references templates` emits zero lines; on a Windows-host simulation (`M032_FORCE_WINDOWS=1`), the same `--asset-mode-override symlink` invocation exits non-zero with the documented `POSIX-only in v1` diagnostic; against a fixture pre-seeded without `installed-files.txt` and with the four runtime dirs already populated (pre-M032 consumer simulation), the installer recognizes the absent-tracking-file case, applies the bootstrapping oracle per FR-22, and writes `installed-files.txt` reflecting the bootstrapped state without blocking; against a fixture pre-seeded with an operator-owned file at a `target:` path absent from `installed-files.txt` and outside `.gitignore`, the installer fails closed with a diagnostic naming both the `project_assets:` entry and the consumer-owned path; runs `bash tests/m032-acceptance/p01-managed-bundle-shape.sh` (SC-1), `bash tests/m032-acceptance/p01-symlink-mode.sh` (SC-2), `bash tests/m032-acceptance/p01-staged-dirs-collision.sh` (SC-10) and observes exit 0 from each; runs `bash tools/verify/m032-p01-phase-suite.sh` and observes `SUMMARY: m032-p01-phase-suite.sh pass=N fail=0`."
risk: "high"
depends_on: []
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/.
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Namespacing: `m032-p01-*` prefix avoids collision with M030/[M031](../../../../milestones/M031/index.md)
     existing `p01-*` verifiers in the shared tools/verify/ tree. -->

### Truths

- `packaging/bundle/manifest.yml` carries a top-level `project_assets:` list with exactly four entries — one per runtime dir (`commands/`, `scripts/`, `references/`, `templates/`) — each declaring `source:`, `target:`, and `mode: copy` (default per FR-1). Schema is additive — existing manifest top-level keys (`schema_version`, `type`, `name`, `version`, `description`, `skill_spec`, `skills`, `hooks`, `config_default`, `runtime_compatibility`) MUST keep their pre-M032 values byte-identical.
  - Check: `bash tools/verify/m032-p01-manifest-schema-shape.sh`

- `scripts/lifecycle/read-project-assets.sh` exists and emits one `source=<src>\ttarget=<tgt>\tmode=<copy|symlink>` line per `project_assets:` entry on stdout. The reader is the single shared seam that all three installers read; reader output is line-oriented, tab-separated, UTF-8, and stable across re-invocations against the same manifest.
  - Check: `bash tools/verify/m032-p01-reader-emits-tuples.sh`

- `packaging/install/install-claude-code.sh` no longer contains the literal token `RUNTIME_DIRS=` anywhere in the file (FR-2 — the hardcoded bulk-copy at `install-claude-code.sh:415-458` is fully replaced by the `project_assets:`-driven path). The install step iterates `read-project-assets.sh` output and dispatches to the per-mode handler. At `mode: copy` the per-target file-tree under `<PROJECT_DIR>/<target>` is byte-identical to the pre-M032 `cp -R "$src/." "$dst/"` output (CON-4 — sha256 of file-tree is the golden recorded by T04). The pre-M032 RUNTIME_DIRS reference is preserved nowhere in the installer body (no commented-out code, no fallback path).
  - Check: `bash tools/verify/m032-p01-install-cc-byte-identical.sh`

- `packaging/install/install-codex.sh` and `packaging/install/install-cursor.sh` likewise no longer contain `RUNTIME_DIRS=`; both installers source the same `read-project-assets.sh` reader and dispatch through the same per-mode handler library. The three installers remain otherwise functionally distinct (skill-registration, hook-payload, settings-merge behavior is per-runtime), but their project-asset staging block is line-for-line identical (FR-2 covers all three installers).
  - Check: `bash tools/verify/m032-p01-installers-parity.sh`

- The per-asset mode handler at `scripts/lifecycle/install-asset-mode.sh` (or library equivalent invoked from each installer) supports `mode: copy` (current `cp -R` semantics) and `mode: symlink`. `mode: symlink` resolves the symlink target as `~/.claude/orchestrator-runtime/<version>/<source-basename>` per A-1, with fallback to `<PROJECT_DIR>/.orchestrator/runtime-cache/<source-basename>` if the user-global path is absent. On a host where `ln -s` is unavailable OR `M032_FORCE_WINDOWS=1` is exported (Windows simulation), `mode: symlink` exits non-zero with the literal diagnostic substring `POSIX-only in v1` and writes nothing under `<PROJECT_DIR>/<target>` (FR-3 / NG-9 fail-closed). The handler honors a `--asset-mode-override <copy|symlink>` installer flag for testing without re-authoring the manifest (TEST-ONLY surface; documented in `references/installation.md` as P02's responsibility, not P01's).
  - Check: `bash tools/verify/m032-p01-mode-handler-symlink.sh`

- `<PROJECT_DIR>/.orchestrator/installed-files.txt` is a line-oriented, human-readable file. Each line is `<target-relative-path>\tmode:<copy|symlink>` (literal tab between path and `mode:` token). The format is downstream-uninstall-compatible: the existing uninstall path (which today reads only the path column via leading-whitespace trimming) MUST keep working byte-identically against M032-format manifests. A second install run (idempotency) MUST produce a byte-identical `installed-files.txt` on disk (FR-4 + CON-4).
  - Check: `bash tools/verify/m032-p01-installed-files-format.sh`

- The FR-22 dual-oracle collision hierarchy is implemented in `scripts/lifecycle/install-collision-check.sh` (or library equivalent) and reads in this strict order: (1) **tracking-file oracle** — if `installed-files.txt` exists AND the target path appears as a left-column entry, the file is framework-installed and collision-detection skips it; (2) **bootstrapping oracle** — if `installed-files.txt` does NOT exist, all files matching `project_assets:` `target:` paths are framework-installed for this run only (MIT-006 pre-M032 bootstrap), and `installed-files.txt` is written reflecting the bootstrapped state at the END of the run; (3) **operator-owned oracle** — a target path that is (a) not in `installed-files.txt`, (b) pre-existing before this install run, AND (c) outside the consumer's `.gitignore` (verified via `git -C <PROJECT_DIR> check-ignore -- <path>` exit 1) is operator-owned: the installer fails closed with the literal diagnostic substring `staged-dirs-collision: project_assets entry <entry> collides with operator-owned <path>`. The operator-owned branch MUST name BOTH the manifest entry AND the consumer-owned path in the diagnostic — single-side naming is RISK-003 oracle ambiguity and was the failure mode FR-22 / MIT-003 was rewritten to close.
  - Check: `bash tools/verify/m032-p01-collision-oracle.sh`

- `tests/fixtures/m032-fresh-project-fixture/` exists as a minimal-but-valid fixture project: contains `.git/` (initialized via `git init`), a populated `.git/config` with a remote `origin` pointing at `https://github.com/fixture-owner/m032-fresh-project-fixture.git` (used by P02's `wiki-init` git-remote parsing), and a populated `<fixture>/.gitignore` listing exactly the four runtime dirs (`commands/`, `scripts/`, `references/`, `templates/`) plus `.orchestrator/` (the stable consumer-side gitignore for staged framework dirs). The fixture is self-contained — no symlinks, no submodules, no nested git repos — so it is safe to run installers against repeatedly.
  - Check: `bash tools/verify/m032-p01-fixture-shape.sh`

- `tests/m032-acceptance/p01-managed-bundle-shape.sh` (SC-1) exists, is executable, and exits 0 against `tests/fixtures/m032-fresh-project-fixture/`. Asserts: (a) FR-1 `project_assets:` schema present in manifest with exactly 4 entries each carrying `source` / `target` / `mode: copy`; (b) FR-2 first-run produces all four runtime dirs at expected paths with file counts matching the pre-M032 golden (`tools/verify/fixtures/m032-pre-m032-golden.txt` recorded by T04); (c) FR-4 `installed-files.txt` exists with `mode:` field on every entry; (d) idempotency — second install run is byte-identical via `diff -r` of file-tree + `cmp -s` of `installed-files.txt`.
  - Check: `bash tools/verify/m032-p01-acceptance-shape-sc1.sh`

- `tests/m032-acceptance/p01-symlink-mode.sh` (SC-2) exists, is executable, and exits 0 on a POSIX host (or POSIX exit code 77 / `SKIP_REASON: ln -s unavailable` per MIT-001 if `ln -s` cannot be exercised). Asserts: with `~/.claude/orchestrator-runtime/<version>/` pre-populated by the test (and torn down at end), a `--asset-mode-override symlink` install resolves all four runtime dirs as symlinks (`test -L <fixture>/<dir>` exit 0); `git -C <fixture> status --short -- commands scripts references templates` emits zero lines (FR-3 — consumer git history shows zero framework files); under `M032_FORCE_WINDOWS=1` the same invocation exits non-zero with `POSIX-only in v1` in stderr and writes nothing under `<fixture>/<target>` (FR-3 fail-closed).
  - Check: `bash tools/verify/m032-p01-acceptance-shape-sc2.sh`

- `tests/m032-acceptance/p01-staged-dirs-collision.sh` (SC-10) exists, is executable, and exits 0. Asserts both FR-22 oracle branches: (a) **no-collision case** — fresh fixture (no `installed-files.txt`, no pre-existing target paths) installs cleanly and exits 0; (b) **bootstrapping branch (MIT-006)** — fixture pre-seeded with the four runtime dirs already populated and NO `installed-files.txt` (pre-M032 consumer simulation) installs cleanly and writes `installed-files.txt` reflecting the bootstrapped state without blocking; (c) **operator-owned collision case** — fixture pre-seeded with a known operator-owned file at a `target:` path NOT listed in `installed-files.txt` AND NOT matched by `.gitignore` causes the installer to exit non-zero with the literal `staged-dirs-collision:` diagnostic naming both the manifest entry and the operator-owned path on stderr.
  - Check: `bash tools/verify/m032-p01-acceptance-shape-sc10.sh`

- `tools/verify/m032-p01-phase-suite.sh` exists, is executable, invokes every P01 verifier in dependency order, exits 0 iff every sub-gate passes, and emits a single line `SUMMARY: m032-p01-phase-suite.sh pass=N fail=M` before exit. The suite chains, in order: `m032-p01-manifest-schema-shape.sh`, `m032-p01-reader-emits-tuples.sh`, `m032-p01-install-cc-byte-identical.sh`, `m032-p01-installers-parity.sh`, `m032-p01-mode-handler-symlink.sh`, `m032-p01-installed-files-format.sh`, `m032-p01-collision-oracle.sh`, `m032-p01-fixture-shape.sh`, `m032-p01-acceptance-shape-sc1.sh`, `m032-p01-acceptance-shape-sc2.sh`, `m032-p01-acceptance-shape-sc10.sh`. Eleven sub-gates plus the suite line.
  - Check: `bash tools/verify/m032-p01-phase-suite.sh`

- The SC-13 / scope-guard invariant holds for the P01 diff: P01 modifies only files declared in this phase's "Files Likely Touched" list. None of `wiki/**`, `commands/init.md`, `scripts/lifecycle/init-project.sh`, `scripts/wiki/**`, `scripts/knowledge/lookup-mems.sh`, or any `.orchestrator/proposals/**` file is touched (those belong to P02, P03, P04). The `tests/paired-m032-m033/seam-*.sh` scripts are NOT P01 deliverables (they belong to P02 per #Q-B).
  - Check: `bash tools/verify/m032-p01-scope-guard.sh`

### Artifacts

- `packaging/bundle/manifest.yml` (existing-baseline+12 lines, contains "project_assets:", contains "source:", contains "target:", contains "mode: copy") — modify
- `scripts/lifecycle/read-project-assets.sh` (min 40 lines, contains "project_assets", contains "source=", contains "target=", contains "mode=") — create
- `scripts/lifecycle/install-asset-mode.sh` (min 60 lines, contains "mode: copy", contains "mode: symlink", contains "POSIX-only in v1", contains "M032_FORCE_WINDOWS", contains "orchestrator-runtime") — create
- `scripts/lifecycle/install-collision-check.sh` (min 50 lines, contains "tracking-file oracle", contains "bootstrapping oracle", contains "operator-owned", contains "staged-dirs-collision:", contains "MIT-006") — create
- `packaging/install/install-claude-code.sh` (existing-baseline-30 lines accounting for FR-2 deletion + new dispatch lines, MUST NOT contain "RUNTIME_DIRS=", contains "read-project-assets.sh") — modify
- `packaging/install/install-codex.sh` (existing-baseline-30 lines accounting for FR-2 deletion + new dispatch lines, MUST NOT contain "RUNTIME_DIRS=", contains "read-project-assets.sh") — modify
- `packaging/install/install-cursor.sh` (existing-baseline-30 lines accounting for FR-2 deletion + new dispatch lines, MUST NOT contain "RUNTIME_DIRS=", contains "read-project-assets.sh") — modify
- `tests/fixtures/m032-fresh-project-fixture/.gitignore` (min 5 lines, contains "commands/", contains "scripts/", contains "references/", contains "templates/", contains ".orchestrator/") — create
- `tests/fixtures/m032-fresh-project-fixture/.git-init-marker` (min 1 line, contains "fixture-owner/m032-fresh-project-fixture") — create (a marker file alongside `.git/`; the `.git/` directory itself is created by the fixture-bootstrap step, see T04)
- `tools/verify/fixtures/m032-pre-m032-golden.txt` (min 10 lines, contains "commands/", contains "scripts/", contains "references/", contains "templates/", contains "file_count=") — create
- `tests/m032-acceptance/p01-managed-bundle-shape.sh` (min 50 lines, contains "SC-1", contains "FR-1", contains "FR-2", contains "FR-4", contains "diff -r") — create
- `tests/m032-acceptance/p01-symlink-mode.sh` (min 50 lines, contains "SC-2", contains "FR-3", contains "test -L", contains "M032_FORCE_WINDOWS", contains "POSIX-only in v1") — create
- `tests/m032-acceptance/p01-staged-dirs-collision.sh` (min 50 lines, contains "SC-10", contains "FR-22", contains "MIT-006", contains "staged-dirs-collision:", contains "tracking-file", contains "bootstrapping", contains "operator-owned") — create
- `tools/verify/m032-p01-manifest-schema-shape.sh` (min 25 lines, contains "project_assets:", contains "source:", contains "target:", contains "mode: copy") — create
- `tools/verify/m032-p01-reader-emits-tuples.sh` (min 25 lines, contains "read-project-assets.sh", contains "source=", contains "target=", contains "mode=") — create
- `tools/verify/m032-p01-install-cc-byte-identical.sh` (min 30 lines, contains "install-claude-code.sh", contains "RUNTIME_DIRS", contains "read-project-assets.sh", contains "diff") — create
- `tools/verify/m032-p01-installers-parity.sh` (min 30 lines, contains "install-claude-code.sh", contains "install-codex.sh", contains "install-cursor.sh", contains "read-project-assets.sh") — create
- `tools/verify/m032-p01-mode-handler-symlink.sh` (min 25 lines, contains "install-asset-mode.sh", contains "mode: symlink", contains "POSIX-only in v1", contains "M032_FORCE_WINDOWS") — create
- `tools/verify/m032-p01-installed-files-format.sh` (min 25 lines, contains "installed-files.txt", contains "mode:", contains "FR-4") — create
- `tools/verify/m032-p01-collision-oracle.sh` (min 30 lines, contains "install-collision-check.sh", contains "tracking-file", contains "bootstrapping", contains "operator-owned", contains "MIT-006") — create
- `tools/verify/m032-p01-fixture-shape.sh` (min 25 lines, contains "m032-fresh-project-fixture", contains ".gitignore", contains "fixture-owner") — create
- `tools/verify/m032-p01-acceptance-shape-sc1.sh` (min 25 lines, contains "p01-managed-bundle-shape.sh", contains "SC-1") — create
- `tools/verify/m032-p01-acceptance-shape-sc2.sh` (min 25 lines, contains "p01-symlink-mode.sh", contains "SC-2") — create
- `tools/verify/m032-p01-acceptance-shape-sc10.sh` (min 25 lines, contains "p01-staged-dirs-collision.sh", contains "SC-10") — create
- `tools/verify/m032-p01-phase-suite.sh` (min 50 lines, contains "SUMMARY:", contains "m032-p01-manifest-schema-shape", contains "m032-p01-collision-oracle", contains "m032-p01-acceptance-shape-sc10", contains "m032-p01-phase-suite") — create
- `tools/verify/m032-p01-scope-guard.sh` (min 35 lines, contains "wiki/", contains "commands/init.md", contains "scripts/wiki/", contains "scripts/knowledge/lookup-mems.sh", contains "tests/paired-m032-m033/", contains "SC-13") — create

### Key Links

- `packaging/bundle/manifest.yml` → `scripts/lifecycle/read-project-assets.sh` (the manifest's `project_assets:` section is the input the reader parses; reader-side basename appears as a doc reference in the manifest header comment)
- `scripts/lifecycle/read-project-assets.sh` → `packaging/bundle/manifest.yml` (the reader parses the `project_assets:` section of the manifest at the bundle path)
- `packaging/install/install-claude-code.sh` → `scripts/lifecycle/read-project-assets.sh` (FR-2 — installer dispatches the project-asset stage by sourcing or invoking the reader)
- `packaging/install/install-claude-code.sh` → `scripts/lifecycle/install-asset-mode.sh` (FR-3 — installer dispatches each reader-emitted tuple to the mode handler)
- `packaging/install/install-claude-code.sh` → `scripts/lifecycle/install-collision-check.sh` (FR-22 — installer invokes the collision check before each tuple's mode-handler dispatch)
- `packaging/install/install-codex.sh` → `scripts/lifecycle/read-project-assets.sh` (FR-2 — same reader)
- `packaging/install/install-cursor.sh` → `scripts/lifecycle/read-project-assets.sh` (FR-2 — same reader)
- `tests/m032-acceptance/p01-managed-bundle-shape.sh` → `packaging/install/install-claude-code.sh` (SC-1 invokes the installer against the fixture)
- `tests/m032-acceptance/p01-managed-bundle-shape.sh` → `tools/verify/fixtures/m032-pre-m032-golden.txt` (SC-1 compares first-run file counts against the pre-M032 golden recorded in T04)
- `tests/m032-acceptance/p01-symlink-mode.sh` → `scripts/lifecycle/install-asset-mode.sh` (SC-2 exercises the symlink mode handler via `--asset-mode-override symlink`)
- `tests/m032-acceptance/p01-staged-dirs-collision.sh` → `scripts/lifecycle/install-collision-check.sh` (SC-10 exercises all three FR-22 oracles)
- `tools/verify/m032-p01-phase-suite.sh` → `tools/verify/m032-p01-manifest-schema-shape.sh` (suite invokes the manifest-schema gate first)
- `tools/verify/m032-p01-phase-suite.sh` → `tools/verify/m032-p01-acceptance-shape-sc10.sh` (suite invokes the SC-10 acceptance shape gate)

## Tasks

### T01: `project_assets:` schema in manifest + shared reader helper (FR-1) + per-mode handler library (FR-3) + collision check library (FR-22)

See `tasks/T01-manifest-and-libraries-PLAN.md`.

T01 is the foundational additive surface. It (a) amends `packaging/bundle/manifest.yml` with the `project_assets:` section listing the four runtime dirs at `mode: copy` (FR-1); (b) authors `scripts/lifecycle/read-project-assets.sh` as the shared reader the three installers will source in T02 + T03 (FR-2 prep); (c) authors `scripts/lifecycle/install-asset-mode.sh` with the `mode: copy` and `mode: symlink` handlers + Windows fail-closed (FR-3 / NG-9); (d) authors `scripts/lifecycle/install-collision-check.sh` implementing the FR-22 dual-oracle hierarchy with the MIT-006 bootstrapping branch. T01 does NOT touch any of the three installers — keeping the surface additive lets T02 land the installer migration as a focused, reviewable diff. T01 ships the `m032-p01-manifest-schema-shape.sh`, `m032-p01-reader-emits-tuples.sh`, `m032-p01-mode-handler-symlink.sh`, `m032-p01-installed-files-format.sh`, and `m032-p01-collision-oracle.sh` verifiers.

### T02: Migrate `install-claude-code.sh` to the `project_assets:` schema (FR-2 + FR-4 + FR-22) — primary installer

See `tasks/T02-install-claude-code-migration-PLAN.md`.

T02 is the primary FR-2 migration. It replaces the hardcoded `RUNTIME_DIRS` block at `install-claude-code.sh:415-458` with a `read-project-assets.sh`-driven loop that dispatches each tuple through `install-collision-check.sh` (FR-22) and then `install-asset-mode.sh` (FR-3). T02 amends the `installed-files.txt` writer to include the per-asset `mode:` field (FR-4), preserving the existing line-oriented format with a literal-tab separator. T02 also records the pre-M032 golden file-tree count at `tools/verify/fixtures/m032-pre-m032-golden.txt` BEFORE applying the installer changes — this is the CON-4 reference T04's SC-1 acceptance script compares against. T02 ships the `m032-p01-install-cc-byte-identical.sh` verifier.

### T03: Apply identical migration to `install-codex.sh` + `install-cursor.sh` (FR-2 across all three installers)

See `tasks/T03-install-codex-cursor-migration-PLAN.md`.

T03 is the symmetry pass. It applies the same FR-2 migration to `install-codex.sh:236-271` and `install-cursor.sh:245-280` so all three installers share the project-asset staging block line-for-line. T03 reuses the libraries authored in T01 (no new library code) and the `installed-files.txt` writer pattern established in T02. T03 ships the `m032-p01-installers-parity.sh` verifier.

### T04: Fixture + SC-1 / SC-2 / SC-10 acceptance scripts + phase-suite + scope-guard

See `tasks/T04-fixture-and-acceptance-tests-PLAN.md`.

T04 ships (a) the shared `tests/fixtures/m032-fresh-project-fixture/` consumed by P02 + P03 + P04 (gitignore + git-init-marker + the bootstrap procedure documented in `tests/fixtures/m032-fresh-project-fixture/README.md`); (b) the three SC acceptance scripts (`p01-managed-bundle-shape.sh` for SC-1, `p01-symlink-mode.sh` for SC-2, `p01-staged-dirs-collision.sh` for SC-10); (c) `tools/verify/m032-p01-phase-suite.sh` chaining all eleven P01 sub-gates straight-line (AD-19 compliant); (d) `tools/verify/m032-p01-scope-guard.sh` (SC-13 — asserts the P01 diff touches no path under `wiki/**`, `scripts/wiki/**`, `scripts/knowledge/lookup-mems.sh`, `commands/init.md`, `scripts/lifecycle/init-project.sh`, or `tests/paired-m032-m033/`). T04 also ships the `m032-p01-fixture-shape.sh` and `m032-p01-acceptance-shape-{sc1,sc2,sc10}.sh` verifiers.

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03 ──▶ T04
```

Strict linear chain. T01 ships the additive libraries (manifest schema + three lifecycle helpers); no installer is amended yet. T02 depends on T01 because the `install-claude-code.sh` migration sources the libraries authored in T01 (and records the pre-M032 golden BEFORE applying its own changes — order-sensitive). T03 depends on T02 because the codex/cursor migrations follow the exact pattern T02 lands and reuse T02's `installed-files.txt` writer convention. T04 depends on T03 because the acceptance scripts and phase-suite assert against the fully-migrated three-installer state. The SC-1 acceptance script in particular requires the pre-M032 golden recorded by T02 to be present on disk; the script reads it directly.

## Files Likely Touched

- `packaging/bundle/manifest.yml` (modify)
- `scripts/lifecycle/read-project-assets.sh` (create)
- `scripts/lifecycle/install-asset-mode.sh` (create)
- `scripts/lifecycle/install-collision-check.sh` (create)
- `packaging/install/install-claude-code.sh` (modify)
- `packaging/install/install-codex.sh` (modify)
- `packaging/install/install-cursor.sh` (modify)
- `tests/fixtures/m032-fresh-project-fixture/.gitignore` (create)
- `tests/fixtures/m032-fresh-project-fixture/.git-init-marker` (create)
- `tests/fixtures/m032-fresh-project-fixture/README.md` (create)
- `tools/verify/fixtures/m032-pre-m032-golden.txt` (create)
- `tests/m032-acceptance/p01-managed-bundle-shape.sh` (create)
- `tests/m032-acceptance/p01-symlink-mode.sh` (create)
- `tests/m032-acceptance/p01-staged-dirs-collision.sh` (create)
- `tools/verify/m032-p01-manifest-schema-shape.sh` (create)
- `tools/verify/m032-p01-reader-emits-tuples.sh` (create)
- `tools/verify/m032-p01-install-cc-byte-identical.sh` (create)
- `tools/verify/m032-p01-installers-parity.sh` (create)
- `tools/verify/m032-p01-mode-handler-symlink.sh` (create)
- `tools/verify/m032-p01-installed-files-format.sh` (create)
- `tools/verify/m032-p01-collision-oracle.sh` (create)
- `tools/verify/m032-p01-fixture-shape.sh` (create)
- `tools/verify/m032-p01-acceptance-shape-sc1.sh` (create)
- `tools/verify/m032-p01-acceptance-shape-sc2.sh` (create)
- `tools/verify/m032-p01-acceptance-shape-sc10.sh` (create)
- `tools/verify/m032-p01-phase-suite.sh` (create)
- `tools/verify/m032-p01-scope-guard.sh` (create)

<!-- The phase plan and task plan files (this file + tasks/T0[1-4]-*-PLAN.md)
     are written by the planner, not the executor — they are not listed here.
     The `.git/` directory inside the fixture is created by the fixture
     bootstrap procedure documented in T04's plan; T04's Steps create it on
     execution, but the directory is not a tracked artifact (it is a runtime
     state of the fixture, materialized by the bootstrap step). -->
