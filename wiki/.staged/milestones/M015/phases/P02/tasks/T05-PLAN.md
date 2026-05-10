---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M015"
name: "Reference sweep — update runtime refs to new paths"
depends_on: [T04]
---

## Prerequisites

- Working in repo root: `/Users/brettkellgren/Sites/lakeledger/orchestrator`
- T02 is complete: `.orchestrator/` populated, `.specify/orchestrator/` absent.
- T03 is complete: `.orchestrator/memory/constitution.md` present, `.specify/memory/` absent.
- T04 is complete: `scripts/state/resolve-root.sh` has no bridge rule.
- `scripts/verify/m015-p02-no-stale-state-refs.sh` (from T01) exists and can be run.
- The migration-adapter allow-list is FR-013 preserved: `scripts/migrate/`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, and `commands/migrate.md` MUST remain untouched by this task (they legitimately reference `.specify/` as a migration *source*).

## Description

Sweep every retained runtime file for references to `.specify/orchestrator/` or `.specify/memory/constitution.md` and replace them with the canonical `.orchestrator/` paths. This is the final task of P02 — it brings every runtime consumer into alignment with the physical state move done by T02/T03 and the resolver change done by T04.

The sweep distinguishes three classes:

1. **Runtime files that hardcode the old path** — must be updated. The preferred pattern is to use `scripts/state/resolve-root.sh` output rather than hardcoding `.orchestrator`, mirroring how [M008](../../../../../milestones/M008/index.md) refactored some call sites. Where a script already hardcoded `.specify/orchestrator`, the minimal correct fix is to hardcode `.orchestrator` instead — full refactor to resolver-driven paths is out of scope for this task and deferred to future work.

2. **Migration adapters** — must NOT be touched. These exist to help users coming *from* spec-kit; they target `.specify/` as a migration source. See the allow-list below.

3. **Historical artifacts** — immutable. Anything under `.orchestrator/` that was migrated from `.specify/orchestrator/` (phase summaries, task summaries, knowledge entries, decisions log, milestone summaries) preserves its original text describing where artifacts *used to live*. The T01-written sweep script excludes `.orchestrator/` from its search, which encodes this rule.

A key behavior: after T02/T03 moved state, some scripts that currently hardcode `.specify/orchestrator/` would now break at runtime — they point at a directory that no longer exists. Those scripts must be fixed. The sweep is not cosmetic; it is functionally required for the orchestrator to work after migration.

## Steps

1. Run the T01-written sweep script to get the current failing file list:

   ```
   bash scripts/verify/m015-p02-no-stale-state-refs.sh
   ```

   Capture the `FAIL:` output. This is the work list. Each file listed must be either:
   - Updated to use `.orchestrator/` instead of `.specify/orchestrator/` (most common);
   - Updated to use `.orchestrator/memory/constitution.md` instead of `.specify/memory/constitution.md`;
   - Added to the allow-list in the verify script with a documented reason.

2. For each file in the failing list, choose a fix class:

   **Fix class A — simple string replacement** (most files). Replace every literal occurrence of `.specify/orchestrator` with `.orchestrator` and every literal occurrence of `.specify/memory/constitution` with `.orchestrator/memory/constitution` in the file. Do NOT replace occurrences inside comments that explicitly describe the migration/move (e.g., a comment saying "this used to be under .specify/orchestrator"). Use judgment — the test is whether the string drives runtime behavior or describes history.

   **Fix class B — dual-path hermetic fixture** (M008 P04 hermetic tests). Scripts under `scripts/verify/m008-p04-*.sh` that exist precisely to test the old bridge-resolver behavior are problematic post-cutover: the bridge rule is gone. For these, the task is to either:
   - If the test's assertion is "bridge rule resolves `.specify/orchestrator/` correctly," the test is now testing removed behavior and must be deleted. Hard-delete per [M007](../../../../../milestones/M007/index.md) no-graceful-degradation.
   - If the test's assertion is "migration tool moves state correctly" (not bridge-specific), leave the test but add it to the verify-script allow-list via `ALLOW_SELF_REFERENCE`. These tests legitimately need to reference `.specify/orchestrator/` as a hermetic fixture source.

     Scripts to evaluate and likely DELETE (bridge-behavior tests): `scripts/verify/m008-p04-resolve-root-bridge.sh`.

     Scripts to evaluate and likely KEEP + allow-list (migration-behavior tests): `scripts/verify/m008-p04-migrate-state-moves.sh`, `scripts/verify/m008-p04-migrate-state-dry-run.sh`, `scripts/verify/m008-p04-migrate-state-skip.sh`.

     Scripts to evaluate (probably keep but update): `scripts/verify/m008-p04-resolve-root-prefers-new.sh`, `scripts/verify/m008-p04-resolve-root-env-override.sh` — these likely need `.specify/orchestrator/` references removed because the "prefers-new-over-bridge" assertion no longer has meaning.

     Scripts to evaluate (hermetic e2e): `scripts/verify/m008-p04-standalone-e2e.sh` — read and decide. If it builds a hermetic fixture that exercises the bridge, rework to exercise only the canonical path.

     Scripts to evaluate ([M003](../../../../../milestones/M003/index.md) resolver-integration tests): `scripts/verify/m003-p07-idempotency-dual-root.sh`, `scripts/verify/m003-p07-no-hardcoded-state-paths.sh` — read and decide. "Dual-root" tests the bridge and the canonical; post-cutover there is only the canonical. Simplify or delete per same discipline.

   **Fix class C — documentation files reserved for P03**. The files listed in the verify script's `ALLOW_P03_DOCS` regex (README.md, CLAUDE.md, references/architecture.md, references/installation.md, references/constitution-walkthrough.md, references/engine.md, references/events.md, references/errors.md, references/recipes.md, references/file-formats.md, references/state-machine.md, references/tier-definitions.md, docs/getting-started.md, docs/knowledge-management.md, docs/hook-development.md, docs/recipe-authoring.md, scripts/AGENTS.md) are explicitly tolerated by the T01 sweep script. Do NOT touch them in this task; P03 reframes them together with their other spec-kit-extension framing.

   **Fix class D — update allow-list** (rare). If a file legitimately needs to keep a `.specify/orchestrator/` reference for a non-migration reason (e.g., a test fixture that simulates the pre-cutover shape for migration testing), add it to the `ALLOW_SELF_REFERENCE` or a new allow-list in `scripts/verify/m015-p02-no-stale-state-refs.sh` with a comment explaining the reason. Prefer this sparingly — class A (simple replacement) should cover the vast majority.

3. Known runtime scripts requiring class-A replacement (enumeration is best-effort from a pre-task grep; T05 must re-verify by running the T01 sweep and processing its output):

   Lifecycle:
   - `scripts/lifecycle/generate-permissions.sh`
   - `scripts/lifecycle/evaluate-preflight.sh`
   - `scripts/lifecycle/mark-complete.sh`
   - `scripts/lifecycle/rollback-phase.sh`
   - `scripts/lifecycle/recovery-briefing.sh`

   Knowledge:
   - `scripts/knowledge/lib/index-utils.sh`
   - `scripts/knowledge/consolidate-artifacts.sh`
   - `scripts/knowledge/append-knowledge.sh`
   - `scripts/knowledge/append-decision.sh`

   Dispatch:
   - `scripts/dispatch/build-context.sh`
   - `scripts/dispatch/detect-capabilities.sh`
   - `scripts/dispatch/lib/section-handlers.sh`

   Diagnostics:
   - `scripts/diagnostics/run-doctor.sh`
   - `scripts/diagnostics/check-plans.sh`
   - `scripts/diagnostics/check-run-ids.sh`
   - `scripts/diagnostics/check-hashes.sh`
   - `scripts/diagnostics/check-cost-spikes.sh`
   - `scripts/diagnostics/check-constitution.sh`

   Engine:
   - `scripts/engine/run.sh`
   - `scripts/engine/checkpoint.sh`
   - `scripts/engine/test-resume.sh`

   Verify:
   - `scripts/verify/check-must-haves.sh`
   - `scripts/verify/m004-p06-check-must-haves-root.sh`
   - `scripts/verify/m002-p04-*.sh` (7 files: uses-index-pipeline, static-first-ordering, planning-uses-index, manifest-header, increments-hits, e2e, budget-enforcement)
   - `scripts/verify/m006-p01-arch-layout.sh`
   - `scripts/verify/m002-p07-e2e.sh`
   - `scripts/verify/m015-p01-no-stale-refs.sh` (update its `--exclude-dir='.specify/orchestrator'` to `--exclude-dir='.orchestrator'` — the exclusion target has moved)

   Migration (partial — runtime code inside `scripts/migrate/` that is NOT a spec-kit detector):
   - `scripts/migrate/lib/idempotency.sh` — inspect each reference. If the reference is to runtime state (not a spec-kit source), update to `.orchestrator/`. If the reference is to the `.specify/` source that migration adapters operate on, leave unchanged.
   - `scripts/migrate/migrate-state.sh` — inspect. It hardcodes `.specify/orchestrator` as the *source* of the state move. That is correct (the tool exists to migrate *from* that path for users still on the old layout). Leave unchanged.

   Commands (these contain markdown instructions for agents with literal path strings that drive runtime invocations):
   - `commands/auto.md` — 10 occurrences of `.specify/orchestrator` in runtime command invocations. Replace with `.orchestrator` or with shell substitution using `$(bash scripts/state/resolve-root.sh)` as appropriate.
   - `commands/evaluate.md`
   - `commands/verify.md`
   - `commands/plan-phase.md`
   - `commands/resume.md`
   - `commands/consolidate.md`

   Templates:
   - `templates/claude-settings.json` — update allow-listed paths from `.specify/orchestrator/*` to `.orchestrator/*` for anything that represents a runtime path. Keep `.specify/orchestrator/*` allow-list entries ONLY if they are required to allow migration-adapter file reads. Inspect each entry and decide.

   Other:
   - `.gitignore` — if it ignores `.specify/orchestrator/tmp/` or similar runtime-only directories, add equivalent `.orchestrator/` entries. Keep `.specify/orchestrator/*` ignores only if needed for compatibility when a migration source is staged in `.specify/`. Inspect and decide.

4. For each file requiring class-A replacement, apply two search-and-replaces:
   - `.specify/orchestrator` → `.orchestrator`
   - `.specify/memory/constitution` → `.orchestrator/memory/constitution`

   Use an editor that can do in-file substitution. Do NOT apply these replacements globally across the whole repo — apply file-by-file with review, because some files contain the strings in historical/comment contexts where the replacement would be wrong.

5. After class-A replacements, re-run the T01 sweep:

   ```
   bash scripts/verify/m015-p02-no-stale-state-refs.sh
   ```

   If any failures remain, they are either (a) class-B test-script cases (delete or add to allow-list), (b) class-C documentation (should already be in `ALLOW_P03_DOCS`), (c) class-D files needing explicit allow-list entries (add with documented reason), or (d) files missed by the pre-task enumeration (fix with class-A).

6. Verify the known-functional paths still work after the sweep. Run the existing project tests most affected by state-path references:

   ```
   bash scripts/diagnostics/run-doctor.sh
   ```

   Expected exit 0 with no `FAIL:` lines. If it fails, fix the specific consumer.

7. Run the T01-written doctor-clean verifier:

   ```
   bash scripts/verify/m015-p02-doctor-clean.sh
   ```

   Expected: `PASS: doctor reports clean state`. Exit 0.

8. Run the full P02 verify suite to confirm the whole phase is green:

   ```
   bash scripts/verify/m015-p02-state-tree-migrated.sh
   bash scripts/verify/m015-p02-constitution-moved.sh
   bash scripts/verify/m015-p02-resolver-no-bridge.sh
   bash scripts/verify/m015-p02-resolver-resolves-new.sh
   bash scripts/verify/m015-p02-no-stale-state-refs.sh
   bash scripts/verify/m015-p02-doctor-clean.sh
   ```

   Each must print `PASS: ...` and exit 0.

9. Run the must-haves gate for the phase:

   ```
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P02
   ```

   Expected: all truth/artifact/key-link checks PASS.

## Must-Haves

- `scripts/verify/m015-p02-no-stale-state-refs.sh` PASSes.
- `scripts/verify/m015-p02-doctor-clean.sh` PASSes.
- All migration adapters (`scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, `commands/migrate.md`) are untouched (verifiable via `git diff --stat` excluding those paths).
- `scripts/migrate/migrate-state.sh` is untouched (its hardcoded `.specify/orchestrator` is the migration *source* — correct).
- The P03-reserved documentation files are untouched.
- `scripts/diagnostics/run-doctor.sh` exits 0 with no `FAIL:` lines after the sweep.

## Verification

Run the full P02 verify suite:

```
bash scripts/verify/m015-p02-state-tree-migrated.sh
bash scripts/verify/m015-p02-constitution-moved.sh
bash scripts/verify/m015-p02-resolver-no-bridge.sh
bash scripts/verify/m015-p02-resolver-resolves-new.sh
bash scripts/verify/m015-p02-no-stale-state-refs.sh
bash scripts/verify/m015-p02-doctor-clean.sh
```

All must PASS. Then run:

```
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P02
```

Must output all truths as PASS.

## Inputs

### From Previous Tasks

- `scripts/verify/m015-p02-no-stale-state-refs.sh` (from T01)
  - Key API: takes no arguments. Exit 0 with `PASS: no stale state-path references in non-exempt runtime files`. Exit 1 with `FAIL: stale state-path references remain in:` followed by a newline-separated list of file paths.
  - Behavioral contract: greps for `.specify/orchestrator` and `.specify/memory/constitution` across the repo, excluding `.git`, `.orchestrator/`, `tests/fixtures/`, `CHANGELOG.md`, the P03-reserved docs, and the migration-adapter allow-list.

- `scripts/verify/m015-p02-doctor-clean.sh` (from T01)
  - Key API: takes no arguments. Exit 0 with `PASS: doctor reports clean state` on success.
  - Behavioral contract: runs `scripts/diagnostics/run-doctor.sh`, fails if exit code is nonzero or output contains a `FAIL:` line.

- `scripts/state/resolve-root.sh` (as modified by T04)
  - Key API: `bash scripts/state/resolve-root.sh [--verbose | --absolute]`. Emits `.orchestrator` by default, `root=.orchestrator` + `source=existing:.orchestrator` with `--verbose`.
  - Behavioral contract: four-rule resolver (env, config, existing, default). No bridge.

### From Disk (Pre-existing)

- Every file enumerated in Step 3. Most need class-A replacements; some (M008 P04 hermetic tests) need class-B decisions.
- `scripts/verify/check-must-haves.sh` — runs the must-have gate using the plan's Truths/Artifacts/Key Links format. Called at Step 9.

## Constraints

- DO NOT touch migration adapters: `scripts/migrate/adapters/speckit.sh`, `scripts/migrate/migrate-state.sh`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, `commands/migrate.md`. Verify via `git diff --stat` that these paths do not appear in the task's change set.
- DO NOT touch the P03-reserved documentation files (listed in the T01 sweep's `ALLOW_P03_DOCS`). P03 handles them.
- DO NOT rewrite historical content under `.orchestrator/` (migrated phase summaries, task summaries, knowledge entries). These are immutable.
- DO NOT add runtime behavior. All changes are path-string updates, allow-list additions, or hard-delete-per-M007 of tests that assert removed behavior.
- Preserve Bash 3.2 compatibility in every modified script.
- When replacing string paths in markdown command files, preserve the surrounding shell shape. `auto.md` contains literal commands an agent will execute — keep them in single-script-file shape where they already were; do not introduce compound bash.
- When a test script's entire purpose is to assert now-removed bridge behavior, DELETE it (hard delete per M007), do not stub it, do not rename it to `.legacy`, and do not add a skip marker. Update any test-runner that consumed it to no longer expect it.
- Do not introduce a "spec-kit compat" mode, flag, or shim. The cutover is one-way.

## Expected Output

After this task:
- `git status` shows ~35–50 files modified under `scripts/`, `commands/`, `templates/`, and possibly `.gitignore` (exact count depends on the pre-task grep).
- `git status` may show deletions of M008 P04 bridge-behavior test scripts (class B hard-deletions).
- All 6 P02 verify scripts PASS.
- `scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P02` reports all truths/artifacts/key-links as PASS.
- `scripts/diagnostics/run-doctor.sh` exits 0 with no `FAIL:` lines.
- Migration adapters untouched.
- P03-reserved docs untouched.
- The repo is now fully aligned on `.orchestrator/` as the canonical state root, with no runtime references to the legacy path.
