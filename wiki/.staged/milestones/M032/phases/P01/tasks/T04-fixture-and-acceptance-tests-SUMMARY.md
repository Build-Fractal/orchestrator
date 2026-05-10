---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P01"
milestone: "M032"
provides:
  - "tests/fixtures/m032-fresh-project-fixture/ (.gitignore + .git-init-marker + README.md) shared with P02..P04; tests/m032-acceptance/p01-{managed-bundle-shape,symlink-mode,staged-dirs-collision}.sh (SC-1 + SC-2 + SC-10 acceptance scripts); tools/verify/m032-p01-{fixture-shape,acceptance-shape-sc1,acceptance-shape-sc2,acceptance-shape-sc10,phase-suite,scope-guard}.sh; tools/verify/fixtures/m032-p01-baseline-ref.txt (P01 baseline ref for SC-13 scope-guard)"
requires:
  - "from:M032/P01/T01 what:project_assets manifest schema + read-project-assets.sh + install-asset-mode.sh + install-collision-check.sh; from:M032/P01/T02 what:install-claude-code.sh project_assets-driven loop + tools/verify/fixtures/m032-pre-m032-golden.txt (golden read by SC-1); from:M032/P01/T03 what:install-codex.sh + install-cursor.sh parity-locked migration"
affects:
  - "P02 P03 P04"
key_files:
  - "tests/fixtures/m032-fresh-project-fixture/.gitignore,tests/fixtures/m032-fresh-project-fixture/.git-init-marker,tests/fixtures/m032-fresh-project-fixture/README.md,tests/m032-acceptance/p01-managed-bundle-shape.sh,tests/m032-acceptance/p01-symlink-mode.sh,tests/m032-acceptance/p01-staged-dirs-collision.sh,tools/verify/fixtures/m032-p01-baseline-ref.txt,tools/verify/m032-p01-fixture-shape.sh,tools/verify/m032-p01-acceptance-shape-sc1.sh,tools/verify/m032-p01-acceptance-shape-sc2.sh,tools/verify/m032-p01-acceptance-shape-sc10.sh,tools/verify/m032-p01-phase-suite.sh,tools/verify/m032-p01-scope-guard.sh"
key_decisions:
  - "SC-1,SC-2,SC-10,SC-13,FR-1,FR-2,FR-3,FR-4,FR-22,MIT-001,MIT-006,CON-4,AD-19"
patterns_established:
  - "fixture-staging via mktemp -d + cp -R + git init + git remote add origin (committed fixture stays immutable; runtime .git/ materialized at test time); deny-all-then-allow-one .gitignore amendment for exercising the FR-22 operator-owned oracle branch (the fresh-project-fixture's .gitignore otherwise excludes commands/ which would mask operator-owned status); SC-13 baseline-ref captured to tools/verify/fixtures/m032-p01-baseline-ref.txt at scope-guard first run; phase-suite straight-line aggregator with single-script-file shape per AD-19"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P01/tasks/T04-fixture-and-acceptance-tests-PAYLOAD.md"
duration: "30m"
verification_result: "pass"
completed_at: "2026-05-04T04:35:17Z"
---

T04 closes P01 by shipping the shared fresh-project fixture (consumed by
P02..P04), the three SC acceptance scripts (SC-1 / SC-2 / SC-10), the SC-13
scope-guard, and the phase-suite aggregator that chains all eleven P01
sub-gates straight-line.

**NOTE ON RECONSTRUCTION** — this SUMMARY was retro-authored after the auto
loop crashed mid-T04-record. The dispatched agent completed the file
authoring (mtimes 2026-05-03 21:27..21:35 PT line up with the AUTO:READY
marker at 21:22 PT) and the phase-suite verifier confirms all 11 sub-gates
pass against the on-disk artifacts; only the unit_close JSONL emit and this
narrative SUMMARY were missing. Verification evidence below was captured
post-recovery.

## What Shipped

1. **`tests/fixtures/m032-fresh-project-fixture/`** — three-file fixture:
   - `.gitignore` (14 lines) excludes `commands/`, `scripts/`, `references/`,
     `templates/`, `.orchestrator/` per the consumer-side staged-dirs
     invariant. The five exclusion entries are the canonical M032 set.
   - `.git-init-marker` (1 line) records
     `git_remote=https://github.com/fixture-owner/m032-fresh-project-fixture.git`
     for P02's `wiki-init` git-remote parsing.
   - `README.md` documents the bootstrap procedure (acceptance scripts copy
     into `mktemp -d`, then `git init && git remote add origin <marker>`),
     fixture purpose, and downstream consumers (P01 SC-1/SC-2/SC-10, P02
     wiki-init, P03 deploy fixture, P04 SC-11 doctor check).

2. **`tests/m032-acceptance/p01-managed-bundle-shape.sh`** (SC-1, 177 lines)
   asserts FR-1 (project_assets schema present with 4 entries at mode: copy),
   FR-2 (per-runtime-dir file counts match `m032-pre-m032-golden.txt`), FR-4
   (`installed-files.txt` carries `\tmode:` token on every line), and
   idempotency (sha256 of file-tree + `cmp -s` of installed-files.txt across
   two consecutive installer runs).

3. **`tests/m032-acceptance/p01-symlink-mode.sh`** (SC-2, 159 lines) probes
   `ln -s` availability up-front (POSIX exit 77 / `SKIP_REASON: ln -s
   unavailable` per MIT-001 if absent), exercises `--asset-mode-override
   symlink` with a fake runtime cache, asserts each runtime dir is `[ -L ]`,
   asserts `git status --short` emits zero lines (FR-3 git-clean invariant),
   and asserts the `M032_FORCE_WINDOWS=1` invocation exits non-zero with
   `POSIX-only in v1` on stderr and writes nothing under target.

4. **`tests/m032-acceptance/p01-staged-dirs-collision.sh`** (SC-10, 197 lines)
   exercises all three FR-22 oracle branches against three separate staged
   fixtures: (a) no-collision (fresh fixture, no installed-files.txt → exit
   0), (b) bootstrapping/MIT-006 (pre-seeded runtime dirs, no
   installed-files.txt → exit 0 with `oracle=bootstrapping
   result=framework-installed`), (c) operator-owned (deny-all-then-allow-one
   gitignore amendment exposes `commands/operator-file.md` as operator-owned
   → exit 4 with `staged-dirs-collision: project_assets entry commands/
   collides with operator-owned commands/operator-file.md` on stderr).

5. **Six T04 verifiers** under `tools/verify/m032-p01-*.sh`:
   - `m032-p01-fixture-shape.sh` (88 lines, 11 PASS / 0 FAIL) asserts the
     fixture's three files exist + `.gitignore` lists all five exclusion
     entries + `.git-init-marker` references `fixture-owner` + README
     references the four runtime dirs.
   - `m032-p01-acceptance-shape-sc1.sh` (91 lines, 9 PASS / 0 FAIL) asserts
     the SC-1 script's required substrings (SC-1, FR-1, FR-2, FR-4), invokes
     a sha256 tool, uses `cmp -s`, and exits 0 against the staged fixture.
   - `m032-p01-acceptance-shape-sc2.sh` (97 lines, 8 PASS / 0 FAIL) asserts
     SC-2 / FR-3 / `M032_FORCE_WINDOWS` / `POSIX-only in v1` substrings,
     `[ -L ` symlink check, and exit 0 or 77 (SKIP) shape.
   - `m032-p01-acceptance-shape-sc10.sh` (100 lines, 10 PASS / 0 FAIL)
     asserts SC-10 / FR-22 / MIT-006 / `staged-dirs-collision:` substrings,
     names all three oracle branches, and exits 0 against the staged
     fixtures.
   - `m032-p01-phase-suite.sh` (73 lines) aggregates eleven P01 sub-gates
     straight-line per AD-19, emits `SUMMARY: m032-p01-phase-suite.sh
     pass=N fail=M` before exit, exits non-zero on any sub-gate fail.
   - `m032-p01-scope-guard.sh` (155 lines, 3 PASS / 0 FAIL) reads the P01
     baseline ref from `tools/verify/fixtures/m032-p01-baseline-ref.txt`
     (`d21a8f98`), runs `git diff --name-only` between baseline and HEAD,
     asserts no path under `wiki/`, `scripts/wiki/`, `commands/init.md`,
     `scripts/lifecycle/init-project.sh`, `commands/wiki-init.md`,
     `tests/paired-m032-m033/`, `references/installation.md`, or
     `.orchestrator/proposals/*.md` is touched.

6. **`tools/verify/fixtures/m032-p01-baseline-ref.txt`** (1 line: `d21a8f98`)
   captures the P01 baseline commit ref for the scope-guard.

## Verification Results

`bash tools/verify/m032-p01-phase-suite.sh` →
`SUMMARY: m032-p01-phase-suite.sh pass=11 fail=0`. Per-sub-gate counts:

- m032-p01-manifest-schema-shape.sh    pass=19 fail=0
- m032-p01-reader-emits-tuples.sh      pass=11 fail=0
- m032-p01-install-cc-byte-identical.sh pass=9 fail=0
- m032-p01-installers-parity.sh        pass=25 fail=0
- m032-p01-mode-handler-symlink.sh     pass=12 fail=0
- m032-p01-installed-files-format.sh   pass=9  fail=0
- m032-p01-collision-oracle.sh         pass=13 fail=0
- m032-p01-fixture-shape.sh            pass=11 fail=0
- m032-p01-acceptance-shape-sc1.sh     pass=9  fail=0
- m032-p01-acceptance-shape-sc2.sh     pass=8  fail=0
- m032-p01-acceptance-shape-sc10.sh    pass=10 fail=0

`bash tools/verify/m032-p01-scope-guard.sh` →
`SUMMARY: m032-p01-scope-guard.sh pass=3 fail=0` (baseline-ref fixture
exists, baseline ref `d21a8f98` resolves, P01 diff contains no out-of-scope
paths).

## Constraints Honored

- Acceptance scripts stage into `mktemp -d` before exercising installers;
  the committed fixture remains immutable.
- All Check commands ship as single-script-file shapes per AD-19; no inline
  compound bash, no `$()` containing pipes.
- Phase-suite aggregator exits non-zero if any sub-gate fails (no
  fail-soft).
- Scope-guard runs `git diff --name-only` against the P01 baseline ref and
  flags any path outside the declared "Files Likely Touched" list,
  including paths under `tests/paired-m032-m033/` (P02's responsibility per
  #Q-B, not P01's).

## Notes for Downstream

- P02 (`orchestrator:wiki-init` integration) will consume the fresh-project
  fixture at `tests/fixtures/m032-fresh-project-fixture/` and parse the
  `.git-init-marker` for the `git_remote=` URL during wiki-init dry-runs.
- P03 (deploy path) reuses the same fixture via the bootstrap procedure
  documented in the README.
- P04 (`orchestrator:doctor` integration) reuses the fixture for the SC-11
  doctor check.
- The phase-suite is the canonical P01 verification entry point — invoked
  by `orchestrator:verify` at phase boundary and by CI at the milestone
  gate.
