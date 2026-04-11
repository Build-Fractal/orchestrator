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

## Autonomy Configuration

Spec-kit-orchestrator's Tier C autonomous mode (`speckit.orchestrator.auto`)
runs unattended — it dispatches tasks, verifies results, and advances
phase boundaries without developer interaction. For this to work
reliably, the agent host (Claude Code, Cursor, etc.) must have a
sufficient allow list so tool calls execute without permission prompts.

**How it works**: the orchestrator ships a generator at
`scripts/lifecycle/generate-permissions.sh` that introspects the
current project and emits a canonical JSON permissions object that
covers every orchestrator script (from `extension.yml`), every
`package.json` script key, every Makefile target, and the standard
toolchain commands for the languages in use. The writer at
`scripts/lifecycle/write-permissions.sh` translates the canonical
object to your agent host's specific settings file (today:
`.claude/settings.json`). A drift detector at
`scripts/diagnostics/check-permissions.sh` reports when the current
settings file has fallen behind the generated output.

### Autonomy Modes

Three modes ship in `templates/autonomy-defaults.yaml`:

| Mode | Tier default | Use case |
|------|--------------|----------|
| `minimal` | Tier A | Reads/edits only. No unattended bash. |
| `standard` | Tier B | Common toolchains + scripts/. Guided dispatch. |
| `full` | Tier C | Comprehensive allow list for unattended auto mode. |

The mode is tier-derived by default but can be overridden in
`orchestrator-config.yml`:

```yaml
autonomy:
  mode: full                # null (tier default) | minimal | standard | full
  generate_on_init: true    # Run generator during speckit.orchestrator.evaluate
  deny_patterns: []         # Extra deny patterns appended to baseline_deny
  extra_allow: []           # Extra allow patterns appended to baseline_allow
```

**Note**: `bypassPermissions` is **not** a supported mode. Per AD-7 in
`.specify/orchestrator/milestones/M005/M005-CONTEXT.md`, safety comes
from explicit allow-list enumeration, never from disabling checks.

### Running the Generator

```bash
# Emit canonical JSON to stdout (preview)
bash scripts/lifecycle/generate-permissions.sh --tier C

# Generate + write in one step
bash scripts/lifecycle/generate-permissions.sh --tier C > /tmp/canon.json
bash scripts/lifecycle/write-permissions.sh --input /tmp/canon.json

# Check for drift
bash scripts/diagnostics/check-permissions.sh
# -> DOCTOR:PERMISSIONS status=ok gaps=0 stale=0
```

### Drift Detection

`scripts/diagnostics/check-permissions.sh` compares the current
`.claude/settings.json` against what the generator would produce. It
emits a structured line consumable by diagnostics and returns:

- `status=ok` — zero gaps, zero stale patterns, baseline deny intact.
- `status=drift` — one or more missing patterns (regeneration needed).
- `status=missing` — `.claude/settings.json` does not exist at all.

`speckit.orchestrator.auto` runs this check as part of its pre-flight.
User-authored settings files trigger an informational warning but do
not block execution — AD-13 says user autonomy wins over orchestrator
opinion.

### Known Limitation: Harness Safety Heuristics

Generating a comprehensive allow list covers the allow-list layer of
the host's bash permission system, but there is a **second, independent
layer** — the safety heuristic check — that fires on command **shape**
(not content) to catch obfuscation patterns. This layer sits above the
allow list and cannot be disabled from `settings.json`. Even a command
whose individual tokens are fully allow-listed will trigger a prompt if
its shape matches one of the heuristic classes (plain subshells,
command substitution containing pipes, process substitution, inline
compound bash, etc.).

The orchestrator's remedy is **preventive**: task plan Truth `Check:`
commands and verification scripts must use the **single-script-file
shape** — extract multi-step logic into a helper script under
`scripts/verify/` and invoke the helper as a plain `bash scripts/...`
command. The authoritative list of forbidden shapes lives in AD-19 at
`.specify/orchestrator/milestones/M005/M005-CONTEXT.md` and in the
authoring guidance at `commands/plan-phase.md`.

If you are writing a new extension command or phase plan, follow the
shape guidance in `commands/plan-phase.md`. The advisory lint at
`scripts/diagnostics/check-plans.sh` (M005 P06) scans task plans and
flags violations so you can fix them before running auto mode.

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
