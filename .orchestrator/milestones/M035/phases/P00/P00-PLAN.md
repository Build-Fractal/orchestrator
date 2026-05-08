---
schema_version: "1.0"
type: phase-plan
phase: "P00"
milestone: "M035"
goal: "Baseline-harden the three runtime installers, ship the wiki-stubs-fresh diagnostic + Pages pre-build gate, fold M032's wiki-deploy.sh staging fix into wiki-init's --deploy path, and record the @build-fractal/orchestrator npm-name collision-check evidence so P01.5 can rename without re-deciding."
demo_sentence: "A fresh-machine install on macOS bash 3.2 exits non-zero on a name-collision (US-3 SC-5); every installer leaves exactly one managed `.gitignore` block enclosing `.orchestrator/install-meta.txt` (US-4 SC-6); `bash scripts/diagnostics/wiki-stubs-fresh.sh` exits zero on a fresh repo and non-zero with a clear regen message after a stub is renamed; `wiki-init.sh --deploy` stages `scripts/wiki/wiki-deploy.sh` from `$REPO_ROOT` into `$PROJECT_DIR` when missing (closes M032 SC-5); and `packaging/bundle/D-RN-1-evidence.txt` records the `npm view` collision check confirming `@build-fractal/orchestrator` is available."
risk: "medium"
depends_on: []
---

## Must-Haves

### Truths

- Each of the three installers replaces every process-substitution-fed `while read` loop that drives a write/copy step with an exit-status-capturing form (explicit `rc=$?` after the loop, OR temp-file iteration), so a non-zero exit from the producing command surfaces as a non-zero installer exit.
  - Check: `bash tools/verify/m035-p00-bash32-collision.sh`
- Each of the three installers emits a `# >>> orchestrator-managed: gitignore >>>` / `# <<< orchestrator-managed: gitignore <<<` marker block to `<PROJECT_DIR>/.gitignore` containing at minimum `.orchestrator/install-meta.txt`, and re-runs replace the block contents in place leaving exactly one block (idempotent).
  - Check: `bash tools/verify/m035-p00-managed-gitignore.sh`
- `scripts/diagnostics/wiki-stubs-fresh.sh` exists, is bash 3.2 compatible, accepts `--root <project-dir>` (default `$PWD`), runs `wiki-generate-stubs.sh` + `wiki-generate-nav.sh` against a tmp dir, diffs against committed `wiki/docs/` + `wiki/mkdocs.yml`, and exits non-zero with a regen-instruction message on drift.
  - Check: `bash tools/verify/m035-p00-wiki-stubs-fresh.sh`
- `scripts/lifecycle/wiki-init.sh emit_pages_workflow()` HEREDOC includes a `bash scripts/diagnostics/wiki-stubs-fresh.sh` step before `mkdocs build` in newly-emitted `pages.yml` workflows; the existing-workflow preservation branch (CON-3 at line 484) is unchanged.
  - Check: `bash tools/verify/m035-p00-wiki-stubs-fresh.sh`
- `scripts/lifecycle/wiki-init.sh` `--deploy` step 2 stages `$REPO_ROOT/scripts/wiki/wiki-deploy.sh` into `$PROJECT_DIR/scripts/wiki/wiki-deploy.sh` when the project copy is missing, before invoking it (closes M032 SC-5 fixture-completeness gap).
  - Check: `bash tools/verify/m035-p00-wiki-deploy-stage.sh`
- `packaging/bundle/D-RN-1-evidence.txt` exists and records the `npm view @build-fractal/orchestrator` and `npm view orchestrator` outcomes captured at P00 plan-time, alongside the resolution `D-RN-1: @build-fractal/orchestrator (unscoped name taken)`.
  - Check: `bash tools/verify/m035-p00-npm-collision-evidence.sh`
- All P00 deliverables aggregate green via the milestone-prefixed phase-suite aggregator.
  - Check: `bash tools/verify/m035-p00-phase-suite.sh`

### Artifacts

- `tests/installer-acceptance/m035-collision-exit-status.sh` (min 60 lines, contains "exit-status")
- `scripts/diagnostics/wiki-stubs-fresh.sh` (min 60 lines, contains "wiki-generate-stubs.sh")
- `packaging/bundle/D-RN-1-evidence.txt` (min 8 lines, contains "@build-fractal/orchestrator")
- `tools/verify/m035-p00-bash32-collision.sh` (min 25 lines, contains "process-substitution")
- `tools/verify/m035-p00-managed-gitignore.sh` (min 25 lines, contains "orchestrator-managed: gitignore")
- `tools/verify/m035-p00-wiki-stubs-fresh.sh` (min 25 lines, contains "wiki-stubs-fresh")
- `tools/verify/m035-p00-wiki-deploy-stage.sh` (min 25 lines, contains "wiki-deploy.sh")
- `tools/verify/m035-p00-npm-collision-evidence.sh` (min 15 lines, contains "D-RN-1")
- `tools/verify/m035-p00-phase-suite.sh` (min 30 lines, contains "m035-p00")

### Key Links

- `tests/installer-acceptance/m035-collision-exit-status.sh` → `packaging/install/install-claude-code.sh` (the regression fixture exercises the installer it protects)
- `scripts/lifecycle/wiki-init.sh` → `scripts/diagnostics/wiki-stubs-fresh.sh` (the Pages-workflow HEREDOC references the diagnostic by basename)
- `tools/verify/m035-p00-phase-suite.sh` → `tools/verify/m035-p00-bash32-collision.sh` (aggregator references the per-truth verifier)

## Tasks

### T01: bash-3.2-installer-exit-status

See `tasks/T01-bash32-installer-exit-status-PLAN.md`.

### T02: managed-gitignore-block

See `tasks/T02-managed-gitignore-block-PLAN.md`.

### T03: wiki-stubs-fresh-diagnostic-and-gate

See `tasks/T03-wiki-stubs-fresh-diagnostic-and-gate-PLAN.md`.

### T04: m032-wiki-deploy-stage-and-npm-evidence

See `tasks/T04-m032-wiki-deploy-stage-and-npm-evidence-PLAN.md`.

## Task Dependencies

```
T01 → T02 → T03 → T04
```

T01 → T02 sequential because both edit all three installers; serializing avoids the merge-conflict surface and keeps the `## Files Likely Touched` accountability clean. T02 → T03 sequential because T03's verifier walks the project tree assuming T01/T02 deliverables landed (the phase-suite aggregator exercises all four cumulatively at T04). T03 → T04 sequential because both modify `scripts/lifecycle/wiki-init.sh` (T03 edits `emit_pages_workflow()`, T04 edits the `--deploy` step 2 block; non-overlapping but same file).

## Files Likely Touched

- `packaging/install/install-claude-code.sh` (modify) — T01 (process-subst exit-status fix), T02 (managed-gitignore block emitter)
- `packaging/install/install-codex.sh` (modify) — T01 (process-subst exit-status fix), T02 (managed-gitignore block emitter)
- `packaging/install/install-cursor.sh` (modify) — T01 (process-subst exit-status fix), T02 (managed-gitignore block emitter)
- `tests/installer-acceptance/m035-collision-exit-status.sh` (create) — T01
- `scripts/diagnostics/wiki-stubs-fresh.sh` (create) — T03
- `scripts/lifecycle/wiki-init.sh` (modify) — T03 (Pages workflow HEREDOC adds gate step), T04 (--deploy step 2 stages wiki-deploy.sh from $REPO_ROOT)
- `packaging/bundle/D-RN-1-evidence.txt` (create) — T04
- `tools/verify/m035-p00-bash32-collision.sh` (create) — T01
- `tools/verify/m035-p00-managed-gitignore.sh` (create) — T02
- `tools/verify/m035-p00-wiki-stubs-fresh.sh` (create) — T03
- `tools/verify/m035-p00-wiki-deploy-stage.sh` (create) — T04
- `tools/verify/m035-p00-npm-collision-evidence.sh` (create) — T04
- `tools/verify/m035-p00-phase-suite.sh` (create) — T04

## Boundary Map

### Produces

- Bash 3.2-safe installer exit-status discipline across all three runtimes (`install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh`).
- Installer-managed `.gitignore` block emitter wired into all three installers, idempotent across re-runs.
- `tests/installer-acceptance/m035-collision-exit-status.sh` regression fixture (red-then-green proof for SC-5).
- `scripts/diagnostics/wiki-stubs-fresh.sh` Layer 1 stub-freshness diagnostic (resolves wiki-stub-drift paper-cut).
- `scripts/lifecycle/wiki-init.sh emit_pages_workflow()` Pages pre-build gate wiring.
- `scripts/lifecycle/wiki-init.sh` `--deploy` step 2 wiki-deploy.sh staging fix (closes M032 SC-5 deferred-validation gap).
- `packaging/bundle/D-RN-1-evidence.txt` npm-name collision-check evidence (`@build-fractal/orchestrator` confirmed available; unscoped `orchestrator` confirmed taken).
- Six project-owned slug-bearing verifiers under `tools/verify/m035-p00-*.sh` plus the `m035-p00-phase-suite.sh` aggregator.

### Consumes

- `scripts/lifecycle/read-project-assets.sh` — pre-existing producer of the asset-tuple stream consumed by the process-substitution-fed `while` loops T01 hardens (read-only contract).
- `scripts/wiki/wiki-generate-stubs.sh` and `scripts/wiki/wiki-generate-nav.sh` — pre-existing M012/M037 producers; T03's diagnostic invokes them against a tmp dir to compute the drift signal (read-only).
- `scripts/wiki/wiki-deploy.sh` — pre-existing operator-runnable wrapper; T04 stages it from `$REPO_ROOT` into `$PROJECT_DIR` when missing (read-only source).
- `packaging/bundle/manifest.yml` `project_assets:` block — pre-existing M032 contract that bulk-stages `scripts/` (line 52) into consumer projects; T04's wiki-deploy staging is a fallback for the `wiki-init --deploy` fixture path that bypasses normal install (read-only).
- `scripts/verify/check-must-haves.sh` and `scripts/verify/check-scope.sh` — framework-owned verifiers consumed by phase verification.
