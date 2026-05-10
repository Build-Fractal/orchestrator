---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M015"
name: "Delete the spec-kit extension host artifacts"
depends_on: []
---

## Prerequisites

- Working in repo root: `/Users/brettkellgren/Sites/lakeledger/orchestrator`
- The repo currently contains `extension.yml`, 9 dogfooded `/speckit.*` slash command files in `.claude/commands/`, 5 helper scripts in `.specify/scripts/bash/`, 9 spec-kit-style command templates in `.specify/templates/commands/`, and 6 root-level spec-kit-style templates (`agent-file-template.md`, `checklist-template.md`, `constitution-template.md`, `plan-template.md`, `spec-template.md`, `tasks-template.md`).
- Per FR-013 and the cross-cutting "Migration adapter preservation" concern, `scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, and `commands/migrate.md` MUST NOT be touched by this task. They detect spec-kit shape as a *migration source*, not as a runtime host.

## Description

Delete the spec-kit extension host artifacts from the repo. This is a hard delete — no rename, no archive, no compat shim (per [M007](../../../../../milestones/M007/index.md) no-graceful-degradation discipline). After this task, the repo no longer registers itself as a spec-kit extension and no longer ships the dogfooded spec-kit slash commands or templates.

Also write the verification scripts that prove each removal class.

## Steps

1. Delete `extension.yml` at the repo root.
2. Delete every `.claude/commands/speckit.*.md` file. There are 9 of them: `speckit.analyze.md`, `speckit.checklist.md`, `speckit.clarify.md`, `speckit.constitution.md`, `speckit.implement.md`, `speckit.plan.md`, `speckit.specify.md`, `speckit.tasks.md`, `speckit.taskstoissues.md`.
3. Delete `.specify/scripts/bash/` and all files inside it (`check-prerequisites.sh`, `common.sh`, `create-new-feature.sh`, `setup-plan.sh`, `update-agent-context.sh`). Then remove the now-empty `.specify/scripts/bash/` directory. If `.specify/scripts/` becomes empty as a result, remove it too.
4. Delete `.specify/templates/commands/` and all files inside it (`analyze.md`, `checklist.md`, `clarify.md`, `constitution.md`, `implement.md`, `plan.md`, `specify.md`, `tasks.md`, `taskstoissues.md`). Then remove the now-empty `.specify/templates/commands/` directory.
5. Delete the 6 root-level spec-kit-style template files in `.specify/templates/`: `agent-file-template.md`, `checklist-template.md`, `constitution-template.md`, `plan-template.md`, `spec-template.md`, `tasks-template.md`. Leave any other files in `.specify/templates/` untouched.
6. Create `scripts/verify/m015-p01-no-extension-yml.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   test ! -e extension.yml || { echo "FAIL: extension.yml still exists"; exit 1; }
   echo "PASS: extension.yml is absent"
   ```

7. Create `scripts/verify/m015-p01-no-speckit-commands.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   matches=$(find .claude/commands -maxdepth 1 -name 'speckit.*.md' -print 2>/dev/null | wc -l | tr -d ' ')
   test "$matches" = "0" || { echo "FAIL: $matches dogfooded /speckit.* command file(s) remain in .claude/commands/"; exit 1; }
   echo "PASS: no dogfooded speckit command files remain"
   ```

8. Create `scripts/verify/m015-p01-no-specify-bash.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   test ! -d .specify/scripts/bash || { echo "FAIL: .specify/scripts/bash still exists"; exit 1; }
   echo "PASS: .specify/scripts/bash is absent"
   ```

9. Create `scripts/verify/m015-p01-no-specify-templates.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   test ! -d .specify/templates/commands || { echo "FAIL: .specify/templates/commands still exists"; exit 1; }
   for tpl in agent-file-template.md checklist-template.md constitution-template.md plan-template.md spec-template.md tasks-template.md; do
     test ! -e ".specify/templates/$tpl" || { echo "FAIL: .specify/templates/$tpl still exists"; exit 1; }
   done
   echo "PASS: spec-kit-style templates are absent"
   ```

10. Make all four verify scripts executable (`chmod +x`).

## Must-Haves

- The 4 deletion classes in this task all PASS their respective verify scripts.
- The migration adapters listed in Prerequisites are untouched (file mtime unchanged after this task).

## Verification

```
bash scripts/verify/m015-p01-no-extension-yml.sh
bash scripts/verify/m015-p01-no-speckit-commands.sh
bash scripts/verify/m015-p01-no-specify-bash.sh
bash scripts/verify/m015-p01-no-specify-templates.sh
```

Each must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

None — T01 has no upstream task dependencies.

### From Disk (Pre-existing)

- `extension.yml` — to be deleted
- `.claude/commands/speckit.*.md` (9 files) — to be deleted
- `.specify/scripts/bash/` — to be deleted
- `.specify/templates/commands/` — to be deleted
- `.specify/templates/{agent-file,checklist,constitution,plan,spec,tasks}-template.md` (6 files) — to be deleted

## Constraints

- Hard delete only. No archive. No git mv to a `legacy/` directory. No comments left in retained files explaining what was deleted.
- Do not touch `scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, or `commands/migrate.md`. These are migration-source code and stay per FR-013.
- Do not touch `.specify/orchestrator/` state in this task (P02 handles state migration).
- Do not touch `.specify/memory/constitution.md` in this task (P02 handles the constitution move).
- Do not delete `.specify/templates/orchestrator-config-default.yml` or any non-spec-kit templates that may live in `.specify/templates/`. Only the 6 explicitly named root-level templates and the `commands/` subdirectory.

## Expected Output

After this task:
- `git status` shows deletions for `extension.yml`, all 9 `.claude/commands/speckit.*.md`, the contents of `.specify/scripts/bash/`, the contents of `.specify/templates/commands/`, and the 6 root-level `.specify/templates/*-template.md` files.
- `git status` shows new files: 4 `scripts/verify/m015-p01-no-*.sh` scripts.
- All 4 verify scripts print `PASS:` and exit 0 when run.
