# Installation Reference

> How to install spec-kit-orchestrator into a consumer project.
> Self-contained — follow this document to set up orchestration in any spec-kit project.

## Overview

spec-kit-orchestrator is an extension that adds multi-phase orchestration to spec-kit's SDD workflow. It is distributed as a set of files that you copy into your project. There is no package manager or installer — you copy the extension directories and configure your project.

## What to Copy

Copy these directories from the spec-kit-orchestrator repo into your project root:

| Directory | Purpose | Required |
|-----------|---------|----------|
| `commands/` | 10 orchestrator command definitions (agent instruction documents) | Yes |
| `scripts/` | 23 helper scripts organized by concern (state, dispatch, verify, knowledge, lifecycle) | Yes |
| `templates/` | 14 output templates + 1 config default | Yes |
| `references/` | 5 progressive disclosure docs (state machine, verification, tiers, file formats, installation) | Yes |
| `extension.yml` | spec-kit extension manifest | Yes |

## What NOT to Copy

These are development artifacts for the extension itself and should not be copied to consumer projects:

| Path | Reason |
|------|--------|
| `specs/` | The extension's own feature specs — your project has its own specs |
| `.specify/` | The extension's own orchestrator state from its development |
| `tests/` | Extension test suites — not needed at runtime |
| `docs/` | Extension development documentation |
| `CLAUDE.md` | Extension-specific project instructions (create your own) |
| `CHANGELOG.md` | Extension changelog (not relevant to your project) |
| `.git/`, `.github/` | Extension repo metadata |

## Installation Steps

### 1. Copy extension files

From the spec-kit-orchestrator repo, copy the required directories into your project:

```bash
# From your project root:
cp -r /path/to/spec-kit-orchestrator/commands/ ./commands/
cp -r /path/to/spec-kit-orchestrator/scripts/ ./scripts/
cp -r /path/to/spec-kit-orchestrator/templates/ ./templates/
cp -r /path/to/spec-kit-orchestrator/references/ ./references/
cp /path/to/spec-kit-orchestrator/extension.yml ./extension.yml
```

### 2. Create project configuration (optional)

Copy the default config template and customize:

```bash
cp templates/orchestrator-config-default.yml orchestrator-config.yml
```

Edit `orchestrator-config.yml` to set project-specific values (verification commands, default tier, etc.). See `extension.yml` config_schema for valid values.

### 3. Set up CLAUDE.md for your project

Create a `CLAUDE.md` in your project root that references the orchestrator. At minimum, include:

```markdown
## Orchestration

This project uses spec-kit-orchestrator for multi-phase orchestration.
- Commands are in `commands/` (10 orchestrator commands)
- Scripts are in `scripts/` (23 helper scripts)
- Templates are in `templates/` (14 output templates)
- Reference docs are in `references/`

## SDD Workflow

- `/speckit.orchestrator.evaluate` — classify scope and activate orchestration
- `/speckit.orchestrator.discuss` — pre-planning discussion (Tier C required, Tier B optional)
- `/speckit.orchestrator.roadmap` — decompose spec into phases
- `/speckit.orchestrator.plan-phase` — plan one phase
- `/speckit.orchestrator.dispatch` — execute one task
- `/speckit.orchestrator.verify` — verify phase completion
- `/speckit.orchestrator.auto` — autonomous execution (Tier C)
- `/speckit.orchestrator.status` — check progress
- `/speckit.orchestrator.resume` — resume after crash/pause
- `/speckit.orchestrator.consolidate` — compress knowledge at milestone end
```

### 4. Create your feature spec

Before running orchestrator commands, create a feature spec using standard spec-kit:

```bash
# Your spec goes in specs/{NNN}-{name}/spec.md
mkdir -p specs/001-your-feature
# Write your spec...
```

### 5. Start orchestration

```bash
/speckit.orchestrator.evaluate
```

The evaluate command will discover your spec, classify the tier, scaffold the orchestrator directory structure, and tell you what to do next.

## Directory Structure After Installation

```
your-project/
├── commands/              # Orchestrator command definitions
├── scripts/               # Helper scripts
│   ├── state/             # derive-phase.sh, read-roadmap.sh, read-config.sh
│   ├── dispatch/          # build-context.sh, scope-filter.sh, detect-capabilities.sh
│   ├── verify/            # check-must-haves.sh, check-boundary-map.sh, etc.
│   ├── knowledge/         # write-summary.sh, append-decision.sh, etc.
│   ├── lifecycle/         # scaffold.sh, lock-manager.sh, auto-loop.sh, etc.
│   └── util/              # json-field.sh
├── templates/             # Output templates
├── references/            # Progressive disclosure docs
├── extension.yml          # Extension manifest
├── orchestrator-config.yml  # Project config (optional, you create this)
├── specs/                 # Your feature specs
│   └── 001-your-feature/
│       └── spec.md
├── .specify/              # Created by orchestrator at runtime
│   └── orchestrator/
│       ├── DECISIONS.md
│       ├── KNOWLEDGE.md
│       ├── execution-log.jsonl
│       └── milestones/
│           └── M001/
│               ├── M001-EVALUATION.md
│               ├── M001-CONTEXT.md  (Tier C)
│               ├── M001-ROADMAP.md
│               └── phases/
└── CLAUDE.md              # Your project instructions
```

## Updating

To update the orchestrator, re-copy the `commands/`, `scripts/`, `templates/`, and `references/` directories from a newer version of the spec-kit-orchestrator repo. Your project-specific files (`specs/`, `.specify/`, `orchestrator-config.yml`, `CLAUDE.md`) are unaffected.

Check `CHANGELOG.md` in the spec-kit-orchestrator repo for breaking changes before updating.

## Verification

After installation, verify the extension is working:

```bash
# Check that scaffold.sh is executable and has correct syntax
bash -n scripts/lifecycle/scaffold.sh && echo "scaffold.sh OK"

# Check that derive-phase.sh is executable
bash -n scripts/state/derive-phase.sh && echo "derive-phase.sh OK"

# Check that read-config.sh works
bash scripts/state/read-config.sh default_tier && echo "read-config.sh OK"
```
