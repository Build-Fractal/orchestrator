---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P08"
milestone: "M003"
name: "Execute validation, triage findings, mark refit complete"
depends_on: ["T03"]
---

## Prerequisites

- T01, T02, T03 complete: synthetic fixture, status wrapper, integration test, and all eight P08 verify scripts exist and individually pass against a non-live-fixture baseline.
- Current branch: `m003-p07-p08-refit` (per repo state at plan time).

## Description

Drive the phase to green: run the integration test against the synthetic fixture first (CI-reachable), then the live lakeledger fixture (when present), triage any failures, land any required corrections as clearly-scoped commits, and finally flip the M003-ROADMAP checkboxes for P07 and P08 and append a refit-closeout note to `milestone-summary.md`.

No new scripts are authored in this task — T04 is orchestration + bookkeeping on top of T01–T03 artifacts. If T04 uncovers latent bugs in `scripts/migrate/**` or `scripts/knowledge/**`, small scope-tight fixes land here; architectural gaps escalate to the user before landing.

## Steps

1. **Dry run on synthetic fixture**:
   ```bash
   bash tests/integration/test-m003-e2e-migration.sh
   ```
   Expected: `passed=<N> failed=0 skipped=<0 or 1>` and exit 0. If `skipped=1`, that's the lakeledger pass skipping because the submodule isn't mounted on this host — acceptable.

2. **Dry run against live lakeledger fixture** (only when `/Users/brettkellgren/Sites/lakeledger/.gsd/` is present):
   - The integration test will pick this up automatically as the secondary pass.
   - If the live pass fails where the synthetic pass succeeds, the failure is data-shape-specific: a table or column in the real project triggers a code path not covered by the synthetic fixture.

3. **Triage any failure** into one of:
   - **(a) Test-harness bug** — fix in `tests/integration/test-m003-e2e-migration.sh` or a verify script. Commit message: `fix(M003/P08): <short>`.
   - **(b) Latent P07 refit bug** — fix in the P07-produced code (`migrate.sh`, transforms, idempotency, rebuild-index wiring). Commit message: `fix(M003/P07): <short> — surfaced by P08 e2e`.
   - **(c) Latent P01–P06 bug** — fix inline with a commit message noting the latent-bug origin: `fix(M003/P##): <short> — latent bug surfaced by P08 e2e`.
   - **(d) Architectural gap** — append a short note under an `## Open Questions` section in this plan (T04-PLAN.md) and **stop**. Escalate to the user before landing anything.

4. **Re-run the full verify suite** after each fix:
   ```bash
   bash tests/integration/test-m003-e2e-migration.sh
   for f in scripts/verify/m003-p08-*.sh; do bash "$f" || exit 1; done
   bash scripts/verify/m003-p08-p07-still-green.sh
   ```
   Must be all-green before advancing to step 5.

5. **Flip roadmap checkboxes** in `.specify/orchestrator/milestones/M003/M003-ROADMAP.md`:
   - Change `- [ ] **P08**: End-to-End Validation Against Live GSD2 (refit)` to `- [x] **P08**: ...` (line 129 at plan time).
   - Verify `- [x] **P07**` is already set from the P07 transition (it is — see recent commits). If somehow not, flip it too.

6. **Append refit closeout note** to `.specify/orchestrator/milestone-summary.md`. Add a new section near the top (or under the existing M003 entry) with the following shape:
   ```markdown
   ### M003 Refit Complete (2026-04-14)

   P07/P08 closed post-M007/[M008](../../../../../milestones/M008/index.md) drift:
   - P07: `migrate.sh` now consumes `scripts/state/resolve-root.sh --absolute`; idempotency probes
     both orchestrator-root and project-root layouts; `rebuild-index.sh` wired as P04 stage.
   - P08: `tests/integration/test-m003-e2e-migration.sh` validates the refitted pipeline
     end-to-end against a synthetic GSD2 fixture (`tests/fixtures/m003-p08-gsd-minimal/`)
     and the live lakeledger fixture when present.
   - Artifact added: `scripts/orchestrator/status.sh` — thin wrapper on `resolve-root.sh`
     + `derive-phase.sh` that the roadmap demo sentence now points to literally.
   ```

7. **Commit the closeout changes** with `commit` skill semantics:
   - Message: `chore(M003/P08): close refit — flip roadmap, append closeout note`
   - One commit per concern: (a) fixture + status wrapper (T01+T02), (b) integration test + verify scripts (T03), (c) triage fixes (if any, one commit per triaged finding), (d) roadmap + summary (T04 step 5–6). No amends.

8. **Final state check**:
   ```bash
   bash scripts/state/derive-phase.sh .specify/orchestrator/milestones/M003
   ```
   Expected: `summarizing` or `completing` (both are valid post-P08 states pending the phase-summary write). If the state is not one of those, something is off — do not advance until resolved.

## Must-Haves

- `tests/integration/test-m003-e2e-migration.sh` exits 0 on this host (at minimum the synthetic pass passes).
- All eight `scripts/verify/m003-p08-*.sh` exit 0.
- All seven `scripts/verify/m003-p07-*.sh` still exit 0 (no regression).
- `M003-ROADMAP.md` shows `[x]` for both P07 and P08.
- `milestone-summary.md` contains the refit closeout note.
- Each triage fix (if any) is a separate commit with a clear `fix(M003/P##)` message.

## Verification

- `bash tests/integration/test-m003-e2e-migration.sh`
- `bash scripts/verify/m003-p08-p07-still-green.sh`
- `bash scripts/util/check-plan-exists.sh .specify/orchestrator/milestones/M003 P08` → should print `PLAN_EXISTS task_plans=4` before T04 runs.
- `grep -c '^- \[x\] \*\*P0[78]\*\*' .specify/orchestrator/milestones/M003/M003-ROADMAP.md` → should be `2` after step 5.

## Inputs

### From Previous Tasks
- `tests/fixtures/m003-p08-gsd-minimal/` (from T01)
- `scripts/orchestrator/status.sh` (from T02)
- `tests/integration/test-m003-e2e-migration.sh` + `scripts/verify/m003-p08-*.sh` (from T03)
  - Key API: `bash test-m003-e2e-migration.sh` → exits 0 on synthetic-only or synthetic+lakeledger; prints `passed=/failed=/skipped=` summary to stdout.

### From Disk (Pre-existing)
- `.specify/orchestrator/milestones/M003/M003-ROADMAP.md` — modified to flip P07/P08 checkboxes.
- `.specify/orchestrator/milestone-summary.md` — modified to append closeout note.
- `scripts/verify/m003-p07-*.sh` — regression guard.
- `scripts/state/derive-phase.sh` — for final state check.

## Constraints

- **Surgical precision** (Constitution XV): fixes triggered by T04 triage must be scope-tight; don't rewrite modules that happen to be adjacent.
- **No graceful degradation** (MEM project_m007_no_degradation): if the synthetic pass works but the live pass reveals a data-shape gap, fix the code path — do not silently skip the live pass.
- **No speculative complexity** (Constitution XIV): resist adding "nice to have" plumbing (multi-fixture, configurable timeouts, etc.) unless a failure demands it.
- If a finding is classified (d) architectural gap, **stop and escalate** before committing anything. Do not leave the tree in a half-patched state.

## Expected Output

After T04 completes:
- All integration + verify scripts green.
- `M003-ROADMAP.md` has `[x] **P07**` and `[x] **P08**`.
- `milestone-summary.md` has a new "M003 Refit Complete" section.
- Between zero and a small number of `fix(M003/P##)` commits addressing triaged findings.
- Milestone state (per `derive-phase.sh`) is `summarizing` or `completing`.
