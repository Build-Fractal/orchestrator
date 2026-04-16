---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M015"
goal: "Remove the spec-kit extension host from the repo: delete the manifest, the dogfooded spec-kit slash commands, the spec-kit helper scripts and templates, and the extension-shape test artifacts. Fix the preflight→generate-permissions argument bug surfaced during evaluate. Sweep retained files for stale references."
demo_sentence: "The repo no longer contains extension.yml, dogfooded /speckit.* slash commands, .specify/scripts/bash/, or .specify/templates/, and no retained code references the deleted paths."
risk: "medium"
depends_on: []
---

## Must-Haves

### Truths

- The repo root contains no `extension.yml` file.
  - Check: `bash scripts/verify/m015-p01-no-extension-yml.sh`

- `.claude/commands/` contains no `speckit.*.md` slash command files.
  - Check: `bash scripts/verify/m015-p01-no-speckit-commands.sh`

- `.specify/scripts/bash/` does not exist.
  - Check: `bash scripts/verify/m015-p01-no-specify-bash.sh`

- `.specify/templates/commands/` does not exist and the spec-kit-style root-level template files are gone (`plan-template.md`, `spec-template.md`, `tasks-template.md`, `checklist-template.md`, `constitution-template.md`, `agent-file-template.md`).
  - Check: `bash scripts/verify/m015-p01-no-specify-templates.sh`

- The extension-registration test artifact (`scripts/verify/m002-p07-extension-registration.sh`) and the extension-shape fixtures (`tests/fixtures/verify-pass/extension.yml`, `tests/fixtures/verify-fail/extension.yml`) are removed.
  - Check: `bash scripts/verify/m015-p01-no-extension-test-artifacts.sh`

- `evaluate-preflight.sh` invokes `generate-permissions.sh` using the script's documented `--project-root` flag form, and a fresh run of `bash scripts/lifecycle/evaluate-preflight.sh . B` reports `permissions=generated` (not `permissions=error`).
  - Check: `bash scripts/verify/m015-p01-preflight-permissions-ok.sh`

- No retained file under `commands/`, `scripts/`, `references/`, `docs/`, `templates/`, or `tests/` contains a runtime reference to a deleted path. (Migration adapters in `scripts/migrate/`, `scripts/state/detect-speckit.sh`, and `scripts/dispatch/adapters/format/speckit.sh` are exempt — they reference `.specify/` as a *migration source*, which is preserved per FR-013.)
  - Check: `bash scripts/verify/m015-p01-no-stale-refs.sh`

### Artifacts

- `scripts/verify/m015-p01-no-extension-yml.sh` (min 3 lines, contains "extension.yml")
- `scripts/verify/m015-p01-no-speckit-commands.sh` (min 3 lines, contains "speckit")
- `scripts/verify/m015-p01-no-specify-bash.sh` (min 3 lines, contains ".specify/scripts/bash")
- `scripts/verify/m015-p01-no-specify-templates.sh` (min 3 lines, contains ".specify/templates")
- `scripts/verify/m015-p01-no-extension-test-artifacts.sh` (min 3 lines, contains "m002-p07-extension-registration")
- `scripts/verify/m015-p01-preflight-permissions-ok.sh` (min 5 lines, contains "permissions=generated")
- `scripts/verify/m015-p01-no-stale-refs.sh` (min 5 lines, contains "extension.yml")

### Key Links

- `.specify/orchestrator/milestones/M015/phases/P01/P01-PLAN.md` → `specs/015-standalone-cutover/spec.md` (this plan implements FR-001 through FR-005, and the preflight bug fix supporting FR-018)

## Tasks

### T01: Delete the spec-kit extension host artifacts

See `.specify/orchestrator/milestones/M015/phases/P01/tasks/T01-PLAN.md`.

### T02: Remove extension-validation test artifacts

See `.specify/orchestrator/milestones/M015/phases/P01/tasks/T02-PLAN.md`.

### T03: Fix the preflight → generate-permissions argument-passing bug

See `.specify/orchestrator/milestones/M015/phases/P01/tasks/T03-PLAN.md`.

### T04: Reference sweep — remove stale references to deleted paths

See `.specify/orchestrator/milestones/M015/phases/P01/tasks/T04-PLAN.md`.

## Task Dependencies

```
T01 → T02 → T03 → T04
```

Strict linear chain. T01 deletes the host artifacts. T02 removes the now-irrelevant extension-validation tests. T03 fixes the unrelated-but-discovered preflight bug (placed inside this phase because it improves auto-mode reliability for the rest of M015). T04 sweeps every retained file for stale references — must run last because it consumes the deletion state from T01 and T02.

## Files Likely Touched

- `extension.yml` (delete)
- `.claude/commands/speckit.analyze.md` (delete)
- `.claude/commands/speckit.checklist.md` (delete)
- `.claude/commands/speckit.clarify.md` (delete)
- `.claude/commands/speckit.constitution.md` (delete)
- `.claude/commands/speckit.implement.md` (delete)
- `.claude/commands/speckit.plan.md` (delete)
- `.claude/commands/speckit.specify.md` (delete)
- `.claude/commands/speckit.tasks.md` (delete)
- `.claude/commands/speckit.taskstoissues.md` (delete)
- `.specify/scripts/bash/check-prerequisites.sh` (delete)
- `.specify/scripts/bash/common.sh` (delete)
- `.specify/scripts/bash/create-new-feature.sh` (delete)
- `.specify/scripts/bash/setup-plan.sh` (delete)
- `.specify/scripts/bash/update-agent-context.sh` (delete)
- `.specify/scripts/bash/` (delete the now-empty directory)
- `.specify/templates/commands/analyze.md` (delete)
- `.specify/templates/commands/checklist.md` (delete)
- `.specify/templates/commands/clarify.md` (delete)
- `.specify/templates/commands/constitution.md` (delete)
- `.specify/templates/commands/implement.md` (delete)
- `.specify/templates/commands/plan.md` (delete)
- `.specify/templates/commands/specify.md` (delete)
- `.specify/templates/commands/tasks.md` (delete)
- `.specify/templates/commands/taskstoissues.md` (delete)
- `.specify/templates/commands/` (delete the now-empty directory)
- `.specify/templates/agent-file-template.md` (delete)
- `.specify/templates/checklist-template.md` (delete)
- `.specify/templates/constitution-template.md` (delete)
- `.specify/templates/plan-template.md` (delete)
- `.specify/templates/spec-template.md` (delete)
- `.specify/templates/tasks-template.md` (delete)
- `scripts/verify/m002-p07-extension-registration.sh` (delete)
- `tests/fixtures/verify-pass/extension.yml` (delete)
- `tests/fixtures/verify-fail/extension.yml` (delete)
- `scripts/lifecycle/evaluate-preflight.sh` (modify — fix line 74 call site)
- `scripts/verify/m015-p01-no-extension-yml.sh` (create)
- `scripts/verify/m015-p01-no-speckit-commands.sh` (create)
- `scripts/verify/m015-p01-no-specify-bash.sh` (create)
- `scripts/verify/m015-p01-no-specify-templates.sh` (create)
- `scripts/verify/m015-p01-no-extension-test-artifacts.sh` (create)
- `scripts/verify/m015-p01-preflight-permissions-ok.sh` (create)
- `scripts/verify/m015-p01-no-stale-refs.sh` (create)
- Any retained file containing a stale reference to a deleted path (modify — discovered by T04's sweep)
