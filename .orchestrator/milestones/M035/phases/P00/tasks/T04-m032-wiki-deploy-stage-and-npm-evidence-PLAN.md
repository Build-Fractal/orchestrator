---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P00"
milestone: "M035"
name: "m032-wiki-deploy-stage-and-npm-evidence"
depends_on: ["T03"]
---

## Prerequisites

- T03 has landed — `wiki-init.sh emit_pages_workflow()` includes the pre-build gate.
- `scripts/lifecycle/wiki-init.sh` exists with `--deploy` step 2 at approximately lines 999–1023 (the `bash "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh" --root "$PROJECT_DIR"` invocation block — verified).
- `scripts/wiki/wiki-deploy.sh` exists at the repo root (verified).
- `npm` is on PATH on the plan-author's machine for the collision-check command. If not present, the plan-author records the gap in the evidence file and notes the manual command to re-run when npm is available — the resolution is the same: per RENAME-PLAN D-RN-1, `@build-fractal/orchestrator` is the default fallback when unscoped `orchestrator` is taken (which it is, per user's confirmation in discuss-step).

## Description

Three deliverables wrapped into one task because each is small:

1. **M032 wiki-deploy.sh staging fix** — close the M032 SC-5 deferred-validation gap. `wiki-init.sh --deploy` step 2 currently invokes `bash "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh"` (line 1011), assuming the consumer ran `install-claude-code.sh` first to stage the file via the `project_assets:` `scripts/` entry. The M032 acceptance protocol does not pre-install, so the deploy path fails with a missing-file error. The fix: if `$PROJECT_DIR/scripts/wiki/wiki-deploy.sh` does not exist, stage it from `$REPO_ROOT/scripts/wiki/wiki-deploy.sh` immediately before the invocation.

2. **D-RN-1 npm-name collision-check evidence** — record the `npm view @build-fractal/orchestrator` and `npm view orchestrator` outcomes in `packaging/bundle/D-RN-1-evidence.txt` so P01.5 can rename without re-running the check and so the evidence is auditable.

3. **P00 phase-suite aggregator** — author `tools/verify/m035-p00-phase-suite.sh` that runs the four task-grain verifiers (`m035-p00-bash32-collision.sh`, `m035-p00-managed-gitignore.sh`, `m035-p00-wiki-stubs-fresh.sh`, `m035-p00-wiki-deploy-stage.sh`, `m035-p00-npm-collision-evidence.sh`) and aggregates their pass/fail into a single `BATTERY: pass=N fail=0` line. The naming convention follows AD-19 milestone-prefix discipline — `m035-p00-phase-suite.sh`, never `p00-phase-suite.sh` (the unprefixed shape silently clobbered prior milestones' aggregators per the path-collision incident captured in the `commands/plan-phase.md` rule 6).

## Steps

1. **Edit `scripts/lifecycle/wiki-init.sh` `--deploy` step 2** (around line 999–1023). Insert a stage-from-repo-root fallback immediately before the existing invocation:

   ```bash
   # Step 2 prelude (M035/P00/T04 — closes M032 SC-5 fixture-completeness gap):
   # If $PROJECT_DIR is missing scripts/wiki/wiki-deploy.sh (M032 acceptance
   # protocol does not pre-install), stage it from $REPO_ROOT.
   if [ ! -f "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh" ]; then
     if [ -f "$REPO_ROOT/scripts/wiki/wiki-deploy.sh" ]; then
       mkdir -p "$PROJECT_DIR/scripts/wiki"
       cp "$REPO_ROOT/scripts/wiki/wiki-deploy.sh" "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh"
       echo "wiki-init: staged $PROJECT_DIR/scripts/wiki/wiki-deploy.sh from \$REPO_ROOT (M032 SC-5 deferred-validation fallback)" >&2
     else
       echo "FAIL: wiki-init: --deploy step 2 cannot stage wiki-deploy.sh — neither \$PROJECT_DIR/scripts/wiki/wiki-deploy.sh nor \$REPO_ROOT/scripts/wiki/wiki-deploy.sh exist" >&2
       exit 11
     fi
   fi
   ```

   The original step-2 invocation (`bash "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh" --root "$PROJECT_DIR"`) follows unchanged.

2. **Author `packaging/bundle/D-RN-1-evidence.txt`**. Run the collision check and record the result:

   ```bash
   npm view @build-fractal/orchestrator 2>&1 | head -3 > /tmp/dRN1-scoped.txt
   npm view orchestrator 2>&1 | head -3 > /tmp/dRN1-unscoped.txt
   ```

   Then write `packaging/bundle/D-RN-1-evidence.txt` with the canonical content:

   ```
   D-RN-1 npm-name collision-check evidence
   Captured at: <ISO 8601 timestamp>
   Captured by: M035 P00 T04
   Captured from: orchestrator repo at <git rev-parse HEAD>

   Command 1: npm view @build-fractal/orchestrator
   Outcome: <verbatim head -3 of stdout/stderr — likely "404 Not Found - GET https://registry.npmjs.org/@build-fractal%2Forchestrator - Not found" indicating the name is available>
   Interpretation: AVAILABLE (404 means no published package; the scope @build-fractal exists / can be claimed at publish time)

   Command 2: npm view orchestrator
   Outcome: <verbatim head -3 of stdout — likely package metadata since the unscoped name is taken>
   Interpretation: TAKEN (existing published package; unscoped is not an option)

   Resolution: D-RN-1 = @build-fractal/orchestrator (RENAME-PLAN.md default fallback when unscoped is taken; user-confirmed at discuss-step 2026-05-07).

   Downstream binding:
   - D-RN-2 GitHub repo basename: Build-Fractal/orchestrator (RENAME-PLAN match-npm-scope rule).
   - D-RN-4 Homebrew tap: build-fractal/orchestrator (RENAME-PLAN single-formula tap default).
   - C7 npm scope token resolution: @build-fractal/orchestrator (lands in P02 plan-phase package.json authoring).

   Operator action items at P01.5:
   - Update CLAUDE.md, README.md, package.json (when authored at P02) to reflect @build-fractal/orchestrator and Build-Fractal/orchestrator forms.
   - Tag v0.9.X-final-spec-kit-name immediately before P01.5 rename commits land (D-RN-7).
   - Migrate ~/.claude/projects/-Users-brettkellgren-Sites-spec-kit-orchestrator/ → -Sites-orchestrator/ (D-RN-6).
   ```

   If `npm` is unavailable on the executing machine, write the file with the `Outcome:` lines marked `<npm not available; verify before P01.5 with: npm view @build-fractal/orchestrator>` and the `Interpretation:` lines marked `(unverified — assumed AVAILABLE per RENAME-PLAN default; re-run before P01.5 commits)`. The resolution remains `@build-fractal/orchestrator` because the user committed to it at discuss-step regardless of which scope-collision path the registry takes.

3. **Author `tools/verify/m035-p00-wiki-deploy-stage.sh`**. The verifier:
   - Greps `scripts/lifecycle/wiki-init.sh` for the substring `M035/P00/T04 — closes M032 SC-5` (or a less brittle anchor like `staged $PROJECT_DIR/scripts/wiki/wiki-deploy.sh from $REPO_ROOT`).
   - Asserts the staging fallback block precedes the existing `bash "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh"` invocation (extract line numbers via `grep -n`, compare).
   - Stages a tmp `$PROJECT_DIR` fixture under `$(mktemp -d)` with NO `scripts/wiki/` subdir. Sets `M032_DEPLOY_GH_API_STUB=1` to bypass the actual gh API call. Invokes `bash scripts/lifecycle/wiki-init.sh --deploy` against the fixture (with the wiki-init flags needed for a no-op deploy run — review existing M032 acceptance fixtures for the working flag set). Asserts: after the run, `<fixture>/scripts/wiki/wiki-deploy.sh` exists.
   - Prints `PASS: m035-p00-wiki-deploy-stage (M032 SC-5 fallback wired; tmp fixture stages wiki-deploy.sh from \$REPO_ROOT)` or `FAIL: …`.
   - Bash 3.2 compatible.

4. **Author `tools/verify/m035-p00-npm-collision-evidence.sh`**. The verifier:
   - Asserts `packaging/bundle/D-RN-1-evidence.txt` exists.
   - Asserts the file contains the substrings `D-RN-1`, `@build-fractal/orchestrator`, `Resolution:`, and `Captured at:`.
   - Asserts the file is non-empty (≥ 8 lines per the phase-plan artifact contract).
   - Prints `PASS: m035-p00-npm-collision-evidence (D-RN-1-evidence.txt records collision-check outcome)` or `FAIL: …`.
   - Bash 3.2 compatible.

5. **Author `tools/verify/m035-p00-phase-suite.sh`** (aggregator). Contract:
   - Invokes each task-grain verifier in sequence: `m035-p00-bash32-collision.sh`, `m035-p00-managed-gitignore.sh`, `m035-p00-wiki-stubs-fresh.sh`, `m035-p00-wiki-deploy-stage.sh`, `m035-p00-npm-collision-evidence.sh`.
   - Captures each verifier's exit code into a tally. Emits a per-verifier `PASS:` or `FAIL:` line on stdout.
   - Emits a final `BATTERY: pass=<N> fail=<M>` summary.
   - Exits 0 if `fail=0`; non-zero otherwise.
   - The script's basename embeds the milestone slug (`m035-p00-phase-suite.sh`) per AD-19 path discipline — never the unprefixed `p00-phase-suite.sh` shape that has historically clobbered prior milestones' aggregators.
   - Bash 3.2 compatible.

6. **Run the aggregator locally** to confirm `BATTERY: pass=5 fail=0`.

## Must-Haves

This task addresses three phase must-haves:

- "`scripts/lifecycle/wiki-init.sh` `--deploy` step 2 stages `$REPO_ROOT/scripts/wiki/wiki-deploy.sh` into `$PROJECT_DIR/scripts/wiki/wiki-deploy.sh` when the project copy is missing …"
- "`packaging/bundle/D-RN-1-evidence.txt` exists and records the `npm view @build-fractal/orchestrator` … alongside the resolution …"
- "All P00 deliverables aggregate green via the milestone-prefixed phase-suite aggregator."

## Verification

```bash
bash tools/verify/m035-p00-wiki-deploy-stage.sh
bash tools/verify/m035-p00-npm-collision-evidence.sh
bash tools/verify/m035-p00-phase-suite.sh
```

## Inputs

### From Previous Tasks

- `tools/verify/m035-p00-bash32-collision.sh` (from T01) — invoked by the phase-suite aggregator.
  - Key API: `bash <script>` invocation; exits 0 on green, non-zero on red. Stdout: `PASS:` / `FAIL:` line.
- `tools/verify/m035-p00-managed-gitignore.sh` (from T02) — invoked by the phase-suite aggregator. Same API contract.
- `tools/verify/m035-p00-wiki-stubs-fresh.sh` (from T03) — invoked by the phase-suite aggregator. Same API contract.

### From Disk (Pre-existing)

- `scripts/lifecycle/wiki-init.sh` — modification target. `--deploy` step 2 block at lines 999–1023 (verify before editing — line numbers may shift after T03's HEREDOC modification).
- `scripts/wiki/wiki-deploy.sh` — pre-existing M012/P04 wiki deploy wrapper at the repo root. Read-only source for the staging fallback.
- `packaging/bundle/manifest.yml` — pre-existing M032 manifest. Read-only context for understanding the normal install-time staging path (`scripts/` `project_asset` line 52). T04's fallback is for the install-bypassed path.
- `references/RENAME-PLAN.md` — pre-existing decision-runbook authoritative for D-RN-1..D-RN-7. T04's evidence file references it.

## Constraints

- Bash 3.2 + POSIX-sh compatibility for the wiki-init.sh edit and all verifiers.
- AP-009 shape-guard discipline: every verifier invocation is a plain `bash <script>` call.
- The phase-suite aggregator MUST embed `m035-p00-` in its filename — the unprefixed `p00-phase-suite.sh` shape silently clobbered prior milestones' aggregators (M030 lost to M031, M031 lost to M036) and is forbidden by AD-19 path discipline.
- The wiki-init.sh edit must NOT change behavior when `$PROJECT_DIR/scripts/wiki/wiki-deploy.sh` already exists — the fallback is a strict "missing-only" stage. Existing-file path is unchanged.
- D-RN-1-evidence.txt must record both verbatim command outcomes and human-readable interpretation, so an auditor unfamiliar with npm registry semantics can read the file and understand the resolution.

## Expected Output

`bash tools/verify/m035-p00-phase-suite.sh` exits 0 with stdout ending in: `BATTERY: pass=5 fail=0`.

## Notes

- **Why three deliverables in one task**: the wiki-deploy stage fix is ~10 lines of installer-edit; the D-RN-1 evidence file is a ~25-line text artifact; the phase-suite aggregator is a ~30-line shell script. Each is too small for its own task plan, and the phase-suite aggregator's correctness depends on T01/T02/T03 verifiers existing — it's the natural last-task wrap-up. Standard intensity (2–4 tasks per phase) sized cleanly to four tasks; combining these three into one keeps the boundary clean.
- **D-RN-1 follow-up at P01.5**: if `npm view @build-fractal/orchestrator` returns "name reserved by another scope owner" rather than 404, P01.5 plan-phase re-decides D-RN-1 with operator input. The evidence file's `(unverified — re-run before P01.5)` annotation handles this case explicitly.
- **Why this closes M032 SC-5**: M032's SC-5 SKIP_REASON cited "fixture lacks scripts/wiki/wiki-deploy.sh (operator-side install required for --deploy)". The staging fallback removes the operator-install precondition for the deploy path; the `--deploy` invocation now self-heals the missing-file case from `$REPO_ROOT`. Future M032 SC-5 re-runs (or M035's own acceptance battery covering the same surface) will green without manual install.
- **Expected verifier output** (informational, not in `## Verification`): `BATTERY: pass=5 fail=0`.
