---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M006"
name: "Create docs/getting-started.md — installation, first project, running the engine"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- P01-P03 reference docs exist: `references/architecture.md`, `references/engine.md`,
  `references/events.md`, `references/errors.md`, `references/hooks.md`,
  `references/recipes.md`, `references/routing.md`, `references/file-formats.md`,
  `references/installation.md`.
- No prior tasks required — T01 is the phase entry point.

## Description

Create the `docs/` directory and the primary getting-started guide at
`docs/getting-started.md`. This document is the first thing a new user reads
and must walk them through the complete journey from installation to running
their first orchestrated milestone. The audience is "users" (DC-2).

The guide must follow progressive disclosure (DC-1): title, disclosure
statement, audience label, `## Overview`, then sections from simplest to
most advanced. All cross-links use relative paths (DC-3). Every command
and workflow step must be verified against the actual codebase (DC-4).

The document covers these sections:

1. **Overview** — what the orchestrator does, when to use it, what it
   produces (2-3 paragraphs).

2. **Installation** — how to install the extension. Cross-links to
   `references/installation.md` for prerequisites and detailed setup.
   Covers: spec-kit requirement, extension installation command, verifying
   installation with `speckit.orchestrator.status`.

3. **Your First Orchestrated Milestone** — step-by-step walkthrough:
   - Create a feature spec (`speckit.specify`)
   - Evaluate scope (`speckit.orchestrator.evaluate`) — explains Tier A/B/C
   - Capture decisions (`speckit.orchestrator.discuss`)
   - Generate roadmap (`speckit.orchestrator.roadmap`)
   - Plan first phase (`speckit.orchestrator.plan-phase`)
   - Execute via dispatch or auto mode (`speckit.orchestrator.dispatch` /
     `speckit.orchestrator.auto`)
   - Verify results (`speckit.orchestrator.verify`)
   - Check progress (`speckit.orchestrator.status`)

4. **Understanding Engine Output** — how to read what the engine produces:
   - Event lines (`EVENT:` prefix, common types: SESSION_START, TASK_START,
     TASK_COMPLETE, PHASE_COMPLETE). Cross-links to `references/events.md`.
   - Result lines (`RESULT:` prefix, JSON format). Cross-links to
     `references/errors.md`.
   - State transitions and the `.specify/orchestrator/` directory structure.
     Cross-links to `references/state-machine.md`.

5. **Output File Structure** — what files the orchestrator creates and where:
   - `.specify/orchestrator/milestones/M###/` directory layout
   - Roadmap, phase plans, task plans, summaries, execution log
   - Cross-links to `references/file-formats.md` and `references/architecture.md`.

6. **Resuming After Interruption** — crash recovery and pause/resume
   (`speckit.orchestrator.resume`). Cross-links to `references/engine.md`.

7. **Diagnostics** — running `speckit.orchestrator.doctor` to check health.

8. **Next Steps** — links to the other three user guides (recipe authoring,
   hook development, knowledge management) and to the reference docs.

## Steps

### Step 1 — Create the docs/ directory

Create `docs/` at the project root if it does not exist.

### Step 2 — Read source materials for accuracy

Read the following to ensure all documented steps are accurate:

- `references/installation.md` — installation steps, prerequisites
- `extension.yml` — the 12 commands, their names and descriptions
- `references/architecture.md` — engine pipeline overview, file layout
- `references/engine.md` — CLI args, env vars, exit codes
- `references/events.md` — event type list and format
- `references/errors.md` — error taxonomy and result format
- `references/state-machine.md` — state transitions
- `references/file-formats.md` — file format schemas
- `commands/evaluate.md` — evaluate command flow
- `commands/discuss.md` — discuss command flow
- `commands/roadmap.md` — roadmap command flow
- `commands/auto.md` — auto command flow
- `commands/status.md` — status command flow
- `commands/resume.md` — resume command flow
- `commands/doctor.md` — doctor command flow

### Step 3 — Write docs/getting-started.md

Create the file following the structure in the Description section.
Use this document template shape:

```markdown
# Getting Started with speckit-orchestrator

> User guide for installing and running the speckit-orchestrator extension.
> Follow the steps in order to set up your first orchestrated milestone.

> Audience: users

## Overview

[What the orchestrator does, when to use it, what it produces]

---

## Installation

[Prerequisites, install command, verification]

See [Installation Reference](../references/installation.md) for detailed prerequisites.

---

## Your First Orchestrated Milestone

### Step 1: Create a Feature Spec
...

### Step 2: Evaluate Scope
...

[etc. for all steps]

---

## Understanding Engine Output

### Event Lines
### Result Lines
### State Transitions

---

## Output File Structure

---

## Resuming After Interruption

---

## Diagnostics

---

## Next Steps

- [Recipe Authoring Guide](recipe-authoring.md)
- [Hook Development Guide](hook-development.md)
- [Knowledge Management Guide](knowledge-management.md)
```

### Step 4 — Verify-as-you-write (DC-4)

For every command name mentioned:
- Confirm it appears in `extension.yml` under `provides.commands[].name`.
- Confirm the command `.md` file exists under `commands/`.

For every file path mentioned:
- Confirm it exists on disk with `test -f` or `test -d`.

For every cross-link:
- Confirm the target file exists relative to `docs/`.

### Step 5 — Verify command name accuracy

Extract all `speckit.orchestrator.*` command names from the guide and
cross-reference against `extension.yml`. If any command is mentioned that
doesn't exist, fix the guide. If any important command is omitted, add it.

## Must-Haves

- [ ] `docs/` directory exists
- [ ] `docs/getting-started.md` exists and is 200+ lines
- [ ] File opens with progressive disclosure statement and audience label "users"
- [ ] Contains `## Overview` section
- [ ] Documents installation with cross-link to `references/installation.md`
- [ ] Documents the complete first-milestone workflow (evaluate through verify)
- [ ] Documents engine output interpretation (events, results, state transitions)
- [ ] Documents the output file structure
- [ ] Every command name matches `extension.yml`
- [ ] All cross-links use relative paths and resolve to existing files

## Verification

After writing the file, run:

```
bash scripts/verify/m006-p04-gs-header.sh
bash scripts/verify/m006-p04-gs-install.sh
bash scripts/verify/m006-p04-gs-workflow.sh
bash scripts/verify/m006-p04-gs-engine.sh
bash scripts/verify/m006-p04-commands-match.sh
```

All must exit 0. If any verification script does not yet exist (because T05
has not run), verify manually by grepping the file for required patterns.

## Inputs

### From Previous Tasks

None — T01 is the phase entry point.

### From Disk (Pre-existing)

- `references/installation.md` — installation prerequisites (258 lines)
- `references/architecture.md` — engine pipeline, file layout (378 lines)
- `references/engine.md` — CLI args, env vars, lifecycle (245 lines)
- `references/events.md` — event type registry (617 lines)
- `references/errors.md` — error taxonomy, result protocol (316 lines)
- `references/state-machine.md` — state transitions
- `references/file-formats.md` — file format schemas (1105 lines)
- `references/hooks.md` — hook lifecycle (361 lines)
- `references/recipes.md` — recipe reference (531 lines)
- `references/routing.md` — routing reference (260 lines)
- `extension.yml` — 12 commands, 5 hooks, scripts list
- `commands/*.md` — all 12 command instruction documents

## Constraints

- **DC-1**: Progressive disclosure format — `## Overview` immediately after title,
  `##`/`###` structure, ASCII diagrams OK, no inline HTML.
- **DC-2**: Audience label: `users`.
- **DC-3**: All cross-links use relative paths from `docs/` directory.
- **DC-4**: Verify-as-you-write — every command name, file path, and workflow step
  confirmed against the actual codebase.
- **DC-5**: Any bug fix commit messages reference `docs/getting-started.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.

## Expected Output

After completing this task:

1. `docs/` directory exists at the project root.
2. `docs/getting-started.md` exists with 200+ lines.
3. The document walks a new user from installation through first milestone completion.
4. All command names match `extension.yml`.
5. All cross-links resolve to existing files.
6. If any code bugs were found and fixed, each fix is committed with a message
   referencing `(found via docs/getting-started.md)`.
