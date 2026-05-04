---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M032"
name: "Fresh-project fixture + SC-1 / SC-2 / SC-10 acceptance scripts + phase-suite + scope-guard"
depends_on: ["T03"]
---

## Prerequisites

- T03 complete: all three installers (`install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh`) are migrated to the `project_assets:` schema and parity-checked (verified by `bash tools/verify/m032-p01-installers-parity.sh`).
- T02 complete: `tools/verify/fixtures/m032-pre-m032-golden.txt` exists with per-runtime-dir file counts.
- T01 complete: the three lifecycle helpers exist and are exercised end-to-end via T02 + T03.
- `tests/fixtures/` directory exists (verified by `[ -d tests/fixtures ]`); existing fixtures live alongside (e.g., `tests/fixtures/m030-acceptance/`, `tests/m031-acceptance/fixtures/`).
- `tests/m032-acceptance/` directory does NOT yet exist; T04 creates it via `mkdir -p`.
- `tools/verify/` exists; T04 ships seven new verifiers under it (`m032-p01-fixture-shape.sh`, `m032-p01-acceptance-shape-{sc1,sc2,sc10}.sh`, `m032-p01-phase-suite.sh`, `m032-p01-scope-guard.sh`, plus the `m032-p01-installed-files-format.sh` actually-asserting-format-on-disk version that supersedes T01's documentation-only stub if T01 only stubbed it).

## Description

T04 closes P01 by shipping (a) the shared `tests/fixtures/m032-fresh-project-fixture/` consumed by P02 + P03 + P04, (b) the three SC acceptance scripts for SC-1 / SC-2 / SC-10, (c) the `m032-p01-phase-suite.sh` aggregator chaining all eleven P01 verifiers, and (d) the `m032-p01-scope-guard.sh` invariant verifier (SC-13 derivation contribution).

**Fixture design.** The fresh-project-fixture is a minimal-but-valid consumer-shape: a `.gitignore` that excludes the four runtime dirs + `.orchestrator/`, a `.git-init-marker` file documenting the fixture's git remote (`https://github.com/fixture-owner/m032-fresh-project-fixture.git`, used by P02's `wiki-init` for git-remote parsing), and a `README.md` documenting the fixture-bootstrap procedure (because the `.git/` directory itself is not committed — it is materialized at test time via `git init` + `git remote add origin`). Acceptance scripts that need a populated `.git/` run the bootstrap procedure as their first step against a `mktemp -d`-staged copy of the fixture.

**Acceptance script architecture.** All three SC scripts use the same fixture-staging pattern: `cp -R tests/fixtures/m032-fresh-project-fixture/. <tmp-staging>/` then `git -C <tmp-staging> init && git -C <tmp-staging> remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git`. The acceptance scripts run installers and tests against `<tmp-staging>/`, leaving the committed fixture immutable. Teardown `rm -rf <tmp-staging>` is mandatory; dangling staging dirs in `/tmp/` are a CI-cleanliness regression.

## Steps

1. **Create the fixture skeleton** at `tests/fixtures/m032-fresh-project-fixture/`:

   ```text
   tests/fixtures/m032-fresh-project-fixture/
     .gitignore             # exclude commands/, scripts/, references/, templates/, .orchestrator/
     .git-init-marker       # one-line marker: "git_remote=https://github.com/fixture-owner/m032-fresh-project-fixture.git"
     README.md              # documents the fixture-bootstrap procedure used by acceptance scripts
   ```

   The `.gitignore` content (5 lines):

   ```text
   commands/
   scripts/
   references/
   templates/
   .orchestrator/
   ```

   The `.git-init-marker` content (1 line):

   ```text
   git_remote=https://github.com/fixture-owner/m032-fresh-project-fixture.git
   ```

   The `README.md` documents (a) the fixture purpose, (b) the bootstrap procedure (`git init` + `git remote add origin`), (c) the consumers (P01 SC-1/SC-2/SC-10, P02 wiki-init default-scope, P03 deploy fixture, P04 SC-11 doctor check).

2. **Author `tests/m032-acceptance/p01-managed-bundle-shape.sh`** (SC-1). The script:
   - Stages the fixture: `tmp_fix=$(mktemp -d)/m032-sc1-$$ ; cp -R tests/fixtures/m032-fresh-project-fixture/. "$tmp_fix"/ ; ( cd "$tmp_fix" && git init -q && git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git )`.
   - Asserts FR-1: `grep -q '^project_assets:$' packaging/bundle/manifest.yml` and the four entries are present (one per runtime dir, all `mode: copy`).
   - Runs first install: `bash packaging/install/install-claude-code.sh --project-dir "$tmp_fix"`; captures exit code.
   - Asserts FR-2: all four runtime dirs exist under `$tmp_fix/`; per-dir file counts match `tools/verify/fixtures/m032-pre-m032-golden.txt`.
   - Asserts FR-4: `[ -f "$tmp_fix/.orchestrator/installed-files.txt" ]`; every line matches `^[^[:space:]]+\tmode:(copy|symlink)$`.
   - Captures sha256 of file-tree under each runtime dir (`find <dir> -type f -exec sha256sum {} \; | sort > /tmp/sc1-sha-pre.txt`).
   - Runs second install (idempotency): `bash packaging/install/install-claude-code.sh --project-dir "$tmp_fix"`.
   - Captures sha256 again into `/tmp/sc1-sha-post.txt`; asserts `cmp -s /tmp/sc1-sha-pre.txt /tmp/sc1-sha-post.txt` (idempotency).
   - Asserts `installed-files.txt` is byte-identical between runs (`cmp -s` against a copy taken after run 1).
   - Teardown: `rm -rf "$tmp_fix"`.
   - Emits `RESULT: ok p01-managed-bundle-shape.sh` on stdout and exits 0; on any assertion failure emits `RESULT: fail p01-managed-bundle-shape.sh reason=<reason>` and exits 1.

3. **Author `tests/m032-acceptance/p01-symlink-mode.sh`** (SC-2). The script:
   - Stages a fixture as in step 2.
   - Sets up a fake runtime cache: `runtime_cache=$(mktemp -d)/orchestrator-runtime/m032-test-$$ ; mkdir -p "$runtime_cache" ; cp -R commands scripts references templates "$runtime_cache"/`. Exports `HOME` override or symlinks `~/.claude/orchestrator-runtime/test-$$/` to `$runtime_cache`.
   - Probes `ln -s` availability: `if ! ln -s /dev/null "$tmp_fix/.lntest" 2>/dev/null; then echo "SKIP_REASON: ln -s unavailable" ; rm -rf "$tmp_fix" ; exit 77; fi` (POSIX exit 77 / SKIP_REASON per MIT-001).
   - Runs `bash packaging/install/install-claude-code.sh --asset-mode-override symlink --project-dir "$tmp_fix"`.
   - Asserts FR-3: each of `$tmp_fix/{commands,scripts,references,templates}` is a symbolic link (`[ -L "$tmp_fix/<dir>" ]`).
   - Asserts FR-3 git-clean invariant: `( cd "$tmp_fix" && git add -A . && git status --short -- commands scripts references templates )` emits zero lines (the `.gitignore` excludes the symlinks; verified by `git status --short`).
   - Asserts Windows fail-closed: `M032_FORCE_WINDOWS=1 bash packaging/install/install-claude-code.sh --asset-mode-override symlink --project-dir "$tmp_fix2" 2>&1 | grep -q 'POSIX-only in v1'`; exit code is non-zero.
   - Asserts no-write-on-fail: under the `M032_FORCE_WINDOWS=1` invocation, the four runtime dirs are NOT created under `$tmp_fix2/` (the handler must fail-closed BEFORE any writes).
   - Teardown: `rm -rf "$tmp_fix" "$tmp_fix2" "$runtime_cache"`.

4. **Author `tests/m032-acceptance/p01-staged-dirs-collision.sh`** (SC-10). The script exercises all three FR-22 oracle branches in sequence against three separate staged fixtures:
   - **No-collision case**: fresh fixture, no `installed-files.txt`, no pre-existing target paths → install exits 0; `installed-files.txt` is written.
   - **Bootstrapping branch (MIT-006)**: fixture pre-seeded with the four runtime dirs already populated (cp -R the source dirs into the staging) but NO `installed-files.txt` → install exits 0 with stdout containing `oracle=bootstrapping result=framework-installed`; `installed-files.txt` is written reflecting the bootstrapped state.
   - **Operator-owned collision case**: fixture pre-seeded with an operator-owned file at `<fixture>/commands/operator-file.md` (NOT in `.gitignore` — so it is not gitignored and IS plausibly operator-owned), no `installed-files.txt` → wait, this is the bootstrapping case. Subtle.
     The correct setup for the operator-owned branch is: fixture has an `installed-files.txt` already (from a prior install), but the operator-owned file at `commands/operator-file.md` was added AFTER that install run, IS NOT in `installed-files.txt`, and IS NOT matched by `.gitignore`. The fresh-project-fixture's `.gitignore` excludes `commands/`, so a file at `commands/operator-file.md` IS gitignored — which makes it not operator-owned per FR-22 oracle 3. To exercise the operator-owned branch, the fixture's `.gitignore` must be temporarily amended to NOT exclude `commands/operator-file.md`. The acceptance script does this by writing a `.gitignore` like `commands/*\n!commands/operator-file.md\n` (deny-all-then-allow-one) for this branch only.
     Asserts: install exits 4 (or whatever `install-collision-check.sh` exits — 4 is the documented FR-22 collision code from T01); stderr contains `staged-dirs-collision: project_assets entry commands/ collides with operator-owned commands/operator-file.md`.
   - Teardown: `rm -rf` each of the three staged fixtures.

5. **Author `tools/verify/m032-p01-fixture-shape.sh`**. Asserts:
   - `[ -f tests/fixtures/m032-fresh-project-fixture/.gitignore ]`
   - `grep -qE '^commands/$' tests/fixtures/m032-fresh-project-fixture/.gitignore` (and same for scripts/, references/, templates/, .orchestrator/)
   - `grep -q 'fixture-owner/m032-fresh-project-fixture' tests/fixtures/m032-fresh-project-fixture/.git-init-marker`
   - `[ -f tests/fixtures/m032-fresh-project-fixture/README.md ]` and the README references the four runtime dirs.

6. **Author the three acceptance-shape verifiers**:
   - `tools/verify/m032-p01-acceptance-shape-sc1.sh` — asserts the SC-1 script exists, references SC-1 / FR-1 / FR-2 / FR-4 by string, contains `diff -r` or sha256-comparison logic, exits 0 against the staged fixture.
   - `tools/verify/m032-p01-acceptance-shape-sc2.sh` — asserts the SC-2 script exists, references SC-2 / FR-3 / `M032_FORCE_WINDOWS` / `POSIX-only in v1` by string, contains `[ -L` symlink check, exits 0 against the staged fixture (or 77 SKIP if ln -s unavailable).
   - `tools/verify/m032-p01-acceptance-shape-sc10.sh` — asserts the SC-10 script exists, references SC-10 / FR-22 / MIT-006 / `staged-dirs-collision:` by string, exercises all three oracle branches, exits 0.

7. **Author the actually-asserting-format `tools/verify/m032-p01-installed-files-format.sh`** that supersedes T01's documentation-only stub. The verifier:
   - Stages a fixture, runs `install-claude-code.sh` against it, reads `<fixture>/.orchestrator/installed-files.txt`.
   - Asserts every non-blank line matches `^[^\t]+\tmode:(copy|symlink)$` (literal tab between path and mode token).
   - Asserts the file is non-empty and contains entries for all four runtime dirs.

8. **Author `tools/verify/m032-p01-phase-suite.sh`**. The aggregator chains all eleven P01 verifiers in order:

   ```
   m032-p01-manifest-schema-shape.sh
   m032-p01-reader-emits-tuples.sh
   m032-p01-install-cc-byte-identical.sh
   m032-p01-installers-parity.sh
   m032-p01-mode-handler-symlink.sh
   m032-p01-installed-files-format.sh
   m032-p01-collision-oracle.sh
   m032-p01-fixture-shape.sh
   m032-p01-acceptance-shape-sc1.sh
   m032-p01-acceptance-shape-sc2.sh
   m032-p01-acceptance-shape-sc10.sh
   ```

   Per AD-19 single-script-file shape: each verifier is invoked as `bash tools/verify/<name>.sh` with output captured to a per-verifier log file; failures increment a fail counter; final line `SUMMARY: m032-p01-phase-suite.sh pass=N fail=M` is emitted before `exit $fail_count`.

9. **Author `tools/verify/m032-p01-scope-guard.sh`** (SC-13). The scope-guard asserts P01's diff did not touch out-of-scope files:
   - Forbidden touches: any path under `wiki/`, `scripts/wiki/`, `scripts/knowledge/lookup-mems.sh`, `commands/init.md`, `scripts/lifecycle/init-project.sh`, `commands/wiki-init.md`, `tests/paired-m032-m033/`, `references/installation.md`, or `.orchestrator/proposals/*.md`.
   - The verifier uses `git diff --name-only` between a P01 baseline tag (or the HEAD commit prior to T01 start) and HEAD, and asserts the diff path list does not intersect any of the forbidden globs.
   - For the planning context (no baseline tag yet), the verifier's first run records the baseline ref to `tools/verify/fixtures/m032-p01-baseline-ref.txt`; subsequent runs read it. The baseline-ref capture is documented in the verifier's header comment.

10. **Run the entire phase-suite** to confirm exit 0:

    ```bash
    bash tools/verify/m032-p01-phase-suite.sh
    ```

    Expected stdout: `SUMMARY: m032-p01-phase-suite.sh pass=11 fail=0` (eleven sub-gates, all passing).

## Must-Haves

- `tests/fixtures/m032-fresh-project-fixture/` exists with `.gitignore`, `.git-init-marker`, `README.md`.
- `tests/m032-acceptance/p01-managed-bundle-shape.sh` (SC-1) exists, exits 0 against the fixture, asserts FR-1 + FR-2 + FR-4 + idempotency.
- `tests/m032-acceptance/p01-symlink-mode.sh` (SC-2) exists, exits 0 (or 77 SKIP) against the fixture, asserts FR-3 POSIX symlink + Windows fail-closed.
- `tests/m032-acceptance/p01-staged-dirs-collision.sh` (SC-10) exists, exits 0, exercises all three FR-22 oracle branches (no-collision, bootstrapping/MIT-006, operator-owned).
- `tools/verify/m032-p01-phase-suite.sh` exists, chains all eleven sub-gates, exits 0 with `SUMMARY: m032-p01-phase-suite.sh pass=11 fail=0`.
- `tools/verify/m032-p01-scope-guard.sh` exists and asserts no out-of-scope path was touched in the P01 diff.

## Verification

```bash
bash tools/verify/m032-p01-phase-suite.sh
bash tools/verify/m032-p01-scope-guard.sh
```

## Inputs

### From Previous Tasks

- All three migrated installers (from T02 + T03) — invoked by the SC acceptance scripts.
- `tools/verify/fixtures/m032-pre-m032-golden.txt` (from T02) — read by the SC-1 acceptance script for per-dir file count comparison.
- T01 lifecycle helpers — invoked transitively by the migrated installers under test.
- The five T01 verifiers + two T02/T03 verifiers (`m032-p01-install-cc-byte-identical.sh`, `m032-p01-installers-parity.sh`) — chained by the phase-suite aggregator.

### From Disk (Pre-existing)

- `tests/fixtures/` — canonical fixture directory; T04 creates the `m032-fresh-project-fixture/` subdirectory.
- `tests/` — top-level tests directory; T04 creates `tests/m032-acceptance/` if not present.
- `tools/verify/` — canonical verifier directory; T04 ships seven new verifiers there.

## Constraints

- Acceptance scripts MUST stage the fixture into `mktemp -d` before running installers — never run installers against the committed fixture directly (committing pollute would break repeat-runnability).
- Acceptance scripts MUST teardown their staging dirs (`rm -rf "$tmp_fix"`) on every exit path (success, fail, SKIP) — dangling `/tmp/m032-sc*` dirs are a CI-hygiene regression.
- All Check commands in this task plan and in the phase-suite verifier MUST use single-script-file shape (AD-19); no inline compound bash, no plain subshells with sourcing, no `$()` containing pipes.
- The phase-suite aggregator MUST exit non-zero if ANY sub-gate fails (no fail-soft); the failure mode is what `auto-loop.sh --step=V` reads to decide first-fail-retry/second-fail-pause.
- The scope-guard MUST flag any file outside the "Files Likely Touched" list in `P01-PLAN.md` — including the seam scripts under `tests/paired-m032-m033/` (those belong to P02 per #Q-B, NOT P01).

## Expected Output

After T04 closes: P01 is verifiable end-to-end via `bash tools/verify/m032-p01-phase-suite.sh` returning `SUMMARY: m032-p01-phase-suite.sh pass=11 fail=0`. The fresh-project-fixture is committed and ready for P02..P04 consumption. The three SC acceptance scripts (SC-1, SC-2, SC-10) exit 0 in expected environments and emit the documented SKIP_REASON / non-zero shapes in unsupported environments. The scope-guard confirms P01's diff stayed inside the declared "Files Likely Touched" list.

State derivation after T04: `bash scripts/state/derive-phase.sh .orchestrator/milestones/M032/` should report `summarizing` (all P01 task plans have summaries, but the phase summary itself has not been written) — at which point `orchestrator:verify` runs the milestone-grain verification and the phase summary is written, transitioning P01 to complete and unblocking P02 planning.
