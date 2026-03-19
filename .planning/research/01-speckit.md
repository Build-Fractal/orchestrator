# Spec-Kit Research Report for speckit-orchestrator Extension

**Date**: 2026-03-18
**Source**: `spec-kit/` submodule at `/Users/brettkellgren/Sites/payer-index-mono/spec-kit/`

---

## 1. Extension System

### 1.1 Manifest Schema (`extension.yml`) -- Every Field

The manifest is defined in `extensions/RFC-EXTENSION-SYSTEM.md` (lines 177-305) and validated by `ExtensionManifest._validate()` in `src/specify_cli/extensions.py` (lines 83-136).

**Schema version**: `"1.0"` (only accepted value, checked at line 91-95 of extensions.py)

#### Top-level required fields (line 58, `REQUIRED_FIELDS`):
```
schema_version, extension, requires, provides
```

#### `extension` block (required):
| Field | Type | Required | Validation | Notes |
|-------|------|----------|------------|-------|
| `id` | string | Yes | `^[a-z0-9-]+$` (line 104) | Unique across all extensions |
| `name` | string | Yes | Non-empty | Human-readable display name |
| `version` | string | Yes | Semantic version X.Y.Z via `packaging.version.Version` (line 112) | No `v` prefix, no pre-release |
| `description` | string | Yes | Non-empty, recommended <200 chars | Brief description |
| `author` | string | No* | None | *Required in API-REFERENCE.md but not enforced in code |
| `repository` | string | No* | None | *Required in API-REFERENCE.md but not enforced in code |
| `license` | string | No* | None | SPDX identifier |
| `homepage` | string | No | None | URL |

#### `requires` block (required):
| Field | Type | Required | Validation | Notes |
|-------|------|----------|------------|-------|
| `speckit_version` | string | Yes | Parsed by `packaging.specifiers.SpecifierSet` (line 427) | e.g., `">=0.1.0,<2.0.0"` |
| `tools` | array | No | None | Array of tool objects |
| `tools[].name` | string | No | None | Tool identifier |
| `tools[].version` | string | No | None | Version specifier |
| `tools[].required` | boolean | No | Default: false | Whether tool is mandatory |
| `tools[].description` | string | No | None | Human-readable description |
| `tools[].install_url` | string | No | None | Where to get the tool |
| `tools[].check_command` | string | No | None | CLI command to verify presence |
| `commands` | array | No | None | Core spec-kit commands this extension depends on |
| `scripts` | array | No | None | Core scripts required |

#### `provides` block (required):
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `commands` | array | Yes (>=1) | At least one command required (line 123-124) |
| `commands[].name` | string | Yes | Pattern: `^speckit\.[a-z0-9-]+\.[a-z0-9-]+$` (line 132) |
| `commands[].file` | string | Yes | Relative to extension root |
| `commands[].description` | string | No | Brief description |
| `commands[].aliases` | array | No | Alternative command names |
| `config` | array | No | Config file definitions |
| `config[].name` | string | - | Config filename |
| `config[].template` | string | - | Template file path |
| `config[].description` | string | - | Description |
| `config[].required` | boolean | - | Default: false |
| `scripts` | array | No | Helper script definitions |
| `scripts[].name` | string | - | Script name |
| `scripts[].file` | string | - | Script file path |
| `scripts[].executable` | boolean | - | Make executable on install |

#### `hooks` block (optional):
Keys are event names. Each hook object:

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `command` | string | - | Must match a command in `provides.commands` |
| `optional` | boolean | `true` | If true, prompt user before executing |
| `prompt` | string | Auto-generated | Prompt text for optional hooks |
| `description` | string | `""` | Hook description |
| `condition` | string | `null` | Condition expression (see 1.3) |

#### Other optional top-level fields:
| Field | Type | Notes |
|-------|------|-------|
| `tags` | array of strings | For catalog discovery, 2-10 recommended |
| `defaults` | object | Default configuration values merged with user config |
| `config_schema` | object | JSON Schema for validating extension config |
| `changelog` | string | URL to changelog |
| `support` | object | Contains `documentation`, `issues`, `discussions`, `email` |

### 1.2 Command Registration -- How Commands Get Wired Per Agent

Command registration is handled by `CommandRegistrar` in `src/specify_cli/extensions.py` (lines 704-791), which delegates to a shared `CommandRegistrar` in `src/specify_cli/agents.py`.

**Registration flow** (from `install_from_directory`, lines 481-488):
1. `ExtensionManager.install_from_directory()` calls `CommandRegistrar().register_commands_for_all_agents()`
2. This detects all agent directories present in the project root
3. For each detected agent, it writes the command in that agent's format

**Agent formats** (from `presets/ARCHITECTURE.md`, lines 80-87):

| Agent | Format | Extension | Arg Placeholder |
|-------|--------|-----------|-----------------|
| Claude, Cursor, opencode, Windsurf, etc. | Markdown | `.md` | `$ARGUMENTS` |
| Copilot | Markdown | `.agent.md` + `.prompt.md` | `$ARGUMENTS` |
| Gemini, Qwen, Tabnine | TOML | `.toml` | `{{args}}` |

**Per-agent output paths**:
- Claude: `.claude/commands/speckit.{ext}.{cmd}.md`
- Gemini: `.gemini/commands/speckit.{ext}.{cmd}.toml`
- Copilot: `.github/agents/speckit.{ext}.{cmd}.agent.md` + companion `.prompt.md`

**Transformation during registration** (extensions.py lines 736-773):
1. Parse the command file's YAML frontmatter and markdown body
2. Inject extension context comments: `<!-- Extension: {ext_id} -->` and `<!-- Config: .specify/extensions/{ext_id}/ -->`
3. Rewrite script paths from extension-relative to repo-root-relative
4. For Markdown agents: frontmatter + context note + body
5. For TOML agents: convert frontmatter to TOML, replace `$ARGUMENTS` with `{{args}}`

**Command file format** (from `EXTENSION-DEVELOPMENT-GUIDE.md` lines 228-257):
```yaml
---
description: "Command description"     # Required
tools:                                  # Optional: MCP tools
  - 'tool-name/function'
scripts:                                # Optional: helper scripts
  sh: ../../scripts/bash/helper.sh
  ps: ../../scripts/powershell/helper.ps1
---

# Command Title
## User Input
$ARGUMENTS
## Steps
...
```

**Unregistration** (lines 776-782): When an extension is removed, the `registered_commands` dict (stored in `.registry` metadata) maps agent names to lists of command names. Each corresponding file is deleted from the agent directory.

### 1.3 Hook System -- Every Hook Point, How They Fire

#### Defined hook points

The following hook events are referenced across the codebase:

| Event Name | Where Checked | File | Lines |
|------------|--------------|------|-------|
| `before_tasks` | Pre-execution checks in tasks.md | `templates/commands/tasks.md` | 27-57 |
| `after_tasks` | Post-execution in tasks.md | `templates/commands/tasks.md` | 100-127 |
| `before_implement` | Pre-execution checks in implement.md | `templates/commands/implement.md` | 18-48 |
| `after_implement` | Post-execution in implement.md | `templates/commands/implement.md` | 174-201 |
| `before_commit` | Referenced in API docs | `extensions/EXTENSION-API-REFERENCE.md` | 111 |
| `after_commit` | Referenced in API docs | `extensions/EXTENSION-API-REFERENCE.md` | 111 |

**Note**: `before_commit` and `after_commit` are documented in the API reference but have no corresponding check logic in any core command template.

#### How hooks fire

Hooks do NOT fire via programmatic invocation. They fire via **embedded instructions in the command markdown templates** that the LLM reads and follows. The pattern is identical across all hook points:

1. The command template instructs the AI agent to read `.specify/extensions.yml`
2. Look for entries under `hooks.{event_name}` key
3. Filter to `enabled: true` hooks
4. For each hook, check the `condition` field:
   - If `condition` is null/empty: treat as executable
   - If `condition` is non-empty: **skip it** (leave evaluation to HookExecutor; the LLM does NOT evaluate conditions)
5. Render output based on `optional` flag:

**Optional hooks** (`optional: true`):
```markdown
## Extension Hooks

**Optional Hook**: {extension}
Command: `/{command}`
Description: {description}

Prompt: {prompt}
To execute: `/{command}`
```
The user then decides whether to run the command.

**Mandatory hooks** (`optional: false`):
```markdown
## Extension Hooks

**Automatic Hook**: {extension}
Executing: `/{command}`
EXECUTE_COMMAND: {command}
```
The AI agent sees `EXECUTE_COMMAND:` and automatically invokes the command.

#### Hook registration in Python (HookExecutor, extensions.py lines 1509-1884)

When an extension is installed, `HookExecutor.register_hooks(manifest)` (line 1555) writes hook entries into `.specify/extensions.yml`:

```yaml
hooks:
  after_tasks:
    - extension: jira
      command: speckit.jira.specstoissues
      enabled: true
      optional: true
      prompt: "Create Jira issues from tasks?"
      description: "..."
      condition: null
```

#### Condition evaluation (HookExecutor._evaluate_condition, lines 1667-1740)

Supported condition patterns:
- `config.key.path is set` -- checks if config value exists via `ConfigManager.has_value()`
- `config.key.path == 'value'` -- equality check
- `config.key.path != 'value'` -- inequality check
- `env.VAR_NAME is set` -- checks environment variable existence
- `env.VAR_NAME == 'value'` / `!= 'value'` -- env var comparison

Unknown condition formats return `False` (fail-closed).

**Important**: The LLM-side hook checking (in the command templates) does NOT evaluate conditions -- it skips any hook with a non-empty condition. Only the Python `HookExecutor.should_execute_hook()` evaluates conditions. This means conditions only work when the Python API is invoked directly, not from within the AI agent's execution of a command template.

### 1.4 Config Management -- Layered Resolution

Implemented in `ConfigManager` class (extensions.py lines 1310-1506).

**Resolution order** (lowest to highest precedence):
1. **Extension defaults**: `extension.yml` -> `defaults` section (line 1348-1359)
2. **Project config**: `.specify/extensions/{ext-id}/{ext-id}-config.yml` (line 1361-1368)
3. **Local config**: `.specify/extensions/{ext-id}/local-config.yml` (gitignored) (line 1370-1377)
4. **Environment variables**: `SPECKIT_{EXT_ID}_{SECTION}_{KEY}` (line 1379-1415)

**Merge strategy**: Recursive deep merge -- nested dicts are merged, scalar values are overridden (lines 1417-1437).

**Environment variable pattern**: `SPECKIT_{EXT_ID_UPPER}_{KEY_PATH_UPPER}` where hyphens in the extension ID become underscores, and the remaining path segments map to nested dict keys.

**Access methods**:
- `config.get_config()` -- returns full merged dict
- `config.get_value("connection.url")` -- dot-path access with optional default
- `config.has_value("project.key")` -- existence check

### 1.5 Extension Lifecycle -- Install, Update, Remove

#### Install (`ExtensionManager.install_from_directory`, lines 439-503)
1. Load and validate `extension.yml` via `ExtensionManifest`
2. Check compatibility with current spec-kit version via `SpecifierSet`
3. Reject if already installed (must remove first)
4. Copy extension directory to `.specify/extensions/{id}/` (respecting `.extensionignore`)
5. Register commands for all detected AI agents
6. Register hooks in `.specify/extensions.yml`
7. Add to `.specify/extensions/.registry` JSON file

#### Install from ZIP (`install_from_zip`, lines 505-557)
1. Extract ZIP to temp directory (with Zip Slip protection, line 531-538)
2. Locate `extension.yml` (may be in root or single subdirectory)
3. Delegate to `install_from_directory`

#### Remove (`ExtensionManager.remove`, lines 559-624)
1. Read `registered_commands` from registry
2. Unregister command files from all agent directories
3. If `keep_config=True`: only remove non-config files
4. If `keep_config=False`: backup config files to `.specify/extensions/.backup/{ext-id}/`, then delete extension directory
5. Unregister hooks from `.specify/extensions.yml`
6. Remove from `.registry`

#### Update (from RFC, lines 396-409)
1. Check catalog for newer version
2. Download new version
3. Validate compatibility
4. Back up current config
5. Extract new version (preserving config)
6. Re-register commands
7. Update registry

#### Enable/Disable (ExtensionRegistry.update, lines 232-264)
- Uses `registry.update(ext_id, {"enabled": False})` to preserve `installed_at`
- `HookExecutor.disable_hooks(ext_id)` sets `enabled: false` on all hooks

### 1.6 Constraints and Limitations -- What Extensions CANNOT Do

1. **Cannot modify core commands**: Extensions are additive only. They cannot replace or modify `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, or `/speckit.implement`. (RFC line 88: "Extensions additive only, no core modifications")
2. **Cannot modify core templates**: Extensions can provide templates at `.specify/extensions/{ext-id}/templates/` but these are lower priority than presets and overrides (presets/ARCHITECTURE.md line 35).
3. **Cannot run arbitrary code at install time**: Installation copies files and registers commands/hooks -- no post-install scripts.
4. **Cannot access other extensions' config**: Each extension's config is isolated to its own directory.
5. **Hook events are limited**: Only `before_tasks`, `after_tasks`, `before_implement`, `after_implement` are actually checked in command templates. `before_commit` and `after_commit` are documented but not wired.
6. **Conditions are not evaluated by the LLM**: The command templates explicitly skip hooks with non-empty conditions. Only the Python API evaluates them.
7. **No inter-extension communication**: No mechanism for extensions to depend on or communicate with other extensions.
8. **Commands must be namespaced**: Pattern `speckit.{ext-id}.{cmd}` is enforced. Cannot create commands outside this namespace.
9. **Single hook per event per extension**: Each event key in `hooks` maps to one command (not an array of commands).
10. **No programmatic lifecycle hooks**: There are no `on_install`, `on_remove`, `on_enable` callbacks.
11. **No template merging**: Extension templates replace core templates entirely when they win resolution; they cannot inject sections into an existing template.

---

## 2. Core Development Phases

### 2.1 Phase Flow

```
constitution --> specify --> clarify --> plan --> tasks --> implement
                                                   |
                                              analyze (cross-cutting, post-tasks)
                                                   |
                                              checklist (cross-cutting, any time post-specify)
                                                   |
                                              taskstoissues (post-tasks, GitHub integration)
```

**Linear flow**: `constitution` -> `specify` -> `clarify` (optional) -> `plan` -> `tasks` -> `implement`

**Cross-cutting**: `analyze` runs after tasks (requires all three: spec.md, plan.md, tasks.md). `checklist` can run any time after specify. `taskstoissues` converts tasks to GitHub issues.

**Handoff declarations** in frontmatter (example from specify.md lines 4-9):
```yaml
handoffs:
  - label: Build Technical Plan
    agent: speckit.plan
    prompt: Create a plan for the spec...
  - label: Clarify Spec Requirements
    agent: speckit.clarify
    prompt: Clarify specification requirements
    send: true
```

### 2.2 Per-Phase Detail

#### `/speckit.constitution`
- **File**: `templates/commands/constitution.md`
- **Reads**: `.specify/memory/constitution.md` (existing constitution), `.specify/templates/constitution-template.md`
- **Produces**: Updated `.specify/memory/constitution.md` with filled-in principles
- **Also reads for propagation**: `plan-template.md`, `spec-template.md`, `tasks-template.md`, all command files
- **Hooks**: None
- **Scripts**: None
- **Key behavior**: Collects/infers project principles, fills template placeholders `[ALL_CAPS_IDENTIFIER]`, increments version (semver), produces a Sync Impact Report

#### `/speckit.specify`
- **File**: `templates/commands/specify.md`
- **Reads**: User's feature description from `$ARGUMENTS`
- **Produces**:
  - Git branch `{NNN}-{short-name}` (via `create-new-feature.sh`)
  - `specs/{NNN}-{short-name}/spec.md` (from spec-template.md)
  - `specs/{NNN}-{short-name}/checklists/requirements.md` (quality checklist)
- **Scripts**: `scripts/bash/create-new-feature.sh --json --short-name "{name}" "{description}"`
- **Hooks**: None
- **Key behavior**: Auto-detects next feature number from branches+specs, creates branch, fills spec template, runs quality validation loop (max 3 iterations), limits NEEDS CLARIFICATION markers to 3

#### `/speckit.clarify`
- **File**: `templates/commands/clarify.md`
- **Reads**: `FEATURE_SPEC` (spec.md from current feature)
- **Produces**: Updated spec.md with `## Clarifications` / `### Session YYYY-MM-DD` section
- **Scripts**: `scripts/bash/check-prerequisites.sh --json --paths-only`
- **Hooks**: None
- **Key behavior**: Sequential questioning (max 5 questions, one at a time), structured ambiguity taxonomy scan, integrates answers into spec sections after each acceptance, saves atomically after each integration

#### `/speckit.plan`
- **File**: `templates/commands/plan.md`
- **Reads**: `FEATURE_SPEC` (spec.md), `/memory/constitution.md`, plan-template.md
- **Produces**:
  - `plan.md` (filled from plan-template.md)
  - `research.md` (Phase 0: all NEEDS CLARIFICATION resolved)
  - `data-model.md` (Phase 1: entities and relationships)
  - `contracts/` (Phase 1: interface contracts)
  - `quickstart.md` (Phase 1: test scenarios)
  - Updated agent context file (via `update-agent-context.sh`)
- **Scripts**: `scripts/bash/setup-plan.sh --json`, `scripts/bash/update-agent-context.sh __AGENT__`
- **Hooks**: None
- **Key behavior**: Runs constitution gate checks, Phase 0 (research), Phase 1 (design), stops after Phase 1 planning

#### `/speckit.tasks`
- **File**: `templates/commands/tasks.md`
- **Reads**: `plan.md` (required), `spec.md` (required for user stories), `data-model.md`, `contracts/`, `research.md`, `quickstart.md` (all optional)
- **Produces**: `tasks.md` in feature directory
- **Scripts**: `scripts/bash/check-prerequisites.sh --json`
- **Hooks**: `before_tasks` (pre-execution), `after_tasks` (post-execution)
- **Key behavior**: Generates tasks organized by user story, each in strict checklist format

#### `/speckit.implement`
- **File**: `templates/commands/implement.md`
- **Reads**: `tasks.md` (required), `plan.md` (required), `data-model.md`, `contracts/`, `research.md`, `quickstart.md` (optional), `checklists/` directory
- **Produces**: Implemented code files as defined in tasks.md; updated tasks.md with `[X]` marks
- **Scripts**: `scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks`
- **Hooks**: `before_implement` (pre-execution), `after_implement` (post-execution)
- **Key behavior**: Checks checklists first (blocks on incomplete unless user overrides), creates ignore files per tech stack, executes tasks phase-by-phase, marks completed tasks

#### `/speckit.analyze`
- **File**: `templates/commands/analyze.md`
- **Reads**: `spec.md`, `plan.md`, `tasks.md` (all required), `/memory/constitution.md`
- **Produces**: Nothing (READ-ONLY). Outputs a markdown analysis report to the conversation.
- **Scripts**: `scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks`
- **Hooks**: None
- **Key behavior**: Non-destructive cross-artifact consistency analysis, severity classification (CRITICAL/HIGH/MEDIUM/LOW), coverage gap detection, max 50 findings

#### `/speckit.checklist`
- **File**: `templates/commands/checklist.md`
- **Reads**: `spec.md`, `plan.md` (optional), `tasks.md` (optional)
- **Produces**: `{FEATURE_DIR}/checklists/{domain}.md` (e.g., `ux.md`, `security.md`, `api.md`)
- **Scripts**: `scripts/bash/check-prerequisites.sh --json`
- **Hooks**: None
- **Key behavior**: Interactive clarification (max 5 questions), generates "unit tests for English" -- items that test requirements quality, not implementation behavior. Appends to existing files (never overwrites). Items use `CHK###` IDs.

#### `/speckit.taskstoissues`
- **File**: `templates/commands/taskstoissues.md`
- **Reads**: `tasks.md`, git remote URL
- **Produces**: GitHub issues (via MCP tool `github/github-mcp-server/issue_write`)
- **Scripts**: `scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks`
- **Hooks**: None
- **Key behavior**: Only proceeds if remote is a GitHub URL, creates one issue per task

### 2.3 Task Structure -- How tasks.md Formats Tasks

Defined in `templates/commands/tasks.md` (lines 139-203) and `templates/tasks-template.md`.

#### Task format (REQUIRED for every task):
```
- [ ] [TaskID] [P?] [Story?] Description with file path
```

**Components**:
1. **Checkbox**: Always `- [ ]` (markdown checkbox); completed tasks use `- [X]`
2. **Task ID**: Sequential `T001`, `T002`, `T003`... in execution order
3. **`[P]` marker**: Present ONLY if task is parallelizable (different files, no dependencies on incomplete tasks)
4. **`[Story]` label**: `[US1]`, `[US2]`, `[US3]` etc. REQUIRED only in user story phases (not in Setup, Foundational, or Polish)
5. **Description**: Clear action with exact file path

#### Phase structure:
- **Phase 1**: Setup (project initialization) -- no story labels
- **Phase 2**: Foundational (blocking prerequisites) -- no story labels, MUST complete before any user story
- **Phase 3+**: One phase per user story, ordered by priority (P1, P2, P3...) -- story labels REQUIRED
  - Within each: Tests (optional, if requested) -> Models -> Services -> Endpoints -> Integration
- **Final Phase**: Polish & Cross-Cutting Concerns -- no story labels

#### Dependency rules:
- Setup has no dependencies
- Foundational depends on Setup, blocks all user stories
- User stories depend on Foundational, can run in parallel with each other
- Polish depends on all desired user stories
- Within a story: models before services, services before endpoints, tests first (if TDD)

### 2.4 Implementation Execution -- How implement.md Works

From `templates/commands/implement.md`:

1. **Run prerequisite script** to get FEATURE_DIR and AVAILABLE_DOCS
2. **Check checklists**: Scan `checklists/` for `- [ ]` vs `- [X]` counts. If ANY checklist has incomplete items, STOP and ask user to proceed or halt.
3. **Load context**: Read tasks.md, plan.md, and optional design documents
4. **Project setup verification**: Detect tech stack and create/verify ignore files (.gitignore, .dockerignore, .eslintignore, etc.)
5. **Parse tasks**: Extract phases, dependencies, task details, parallel markers
6. **Execute phase-by-phase**:
   - Complete each phase before moving to next
   - Respect sequential dependencies; `[P]` tasks can run together
   - Follow TDD approach when tests are included
   - Validate checkpoints between phases
7. **Progress tracking**: Mark completed tasks as `[X]` in tasks.md, halt on non-parallel failures
8. **Completion validation**: Verify all tasks done, features match spec, tests pass
9. **Post-implementation hooks**: Check `hooks.after_implement` in extensions.yml

---

## 3. Template System

### 3.1 Template Resolution Order -- The `resolve_template` Function

Implemented in three places for consistency:
- **Bash**: `scripts/bash/common.sh` lines 178-252, function `resolve_template()`
- **Python**: `PresetResolver` in `src/specify_cli/presets.py`
- **PowerShell**: `Resolve-Template` in `scripts/powershell/common.ps1`

**Priority stack** (first match wins):

| Priority | Source | Path Pattern | Use Case |
|----------|--------|--------------|----------|
| 1 (highest) | Override | `.specify/templates/overrides/{name}.md` | Project-local one-off tweaks |
| 2 | Preset | `.specify/presets/{preset-id}/templates/{name}.md` | Shareable, stackable customizations (sorted by preset priority, lower number wins) |
| 3 | Extension | `.specify/extensions/{ext-id}/templates/{name}.md` | Extension-provided templates (skips hidden dirs like .backup, .cache) |
| 4 (lowest) | Core | `.specify/templates/{name}.md` | Shipped defaults |

**Preset sorting** (common.sh lines 196-229):
- If `.specify/presets/.registry` exists and `python3` is available: read preset IDs sorted by priority field (lower = higher precedence)
- Fallback: alphabetical directory order

**Usage in scripts**: `resolve_template "spec-template" "$REPO_ROOT"` returns the full path or empty string if not found. The `create-new-feature.sh` script (line 311) and `setup-plan.sh` script (line 42) both use this to copy the resolved template to the feature directory.

### 3.2 Available Variables

Template variables are limited and mostly exist as placeholders within markdown templates rather than programmatic substitution:

**In command files**:
| Variable | Description | Source |
|----------|-------------|--------|
| `$ARGUMENTS` | User-provided text after the slash command | AI agent runtime |
| `{SCRIPT}` | Resolved to the appropriate script path during command registration | Frontmatter `scripts.sh` / `scripts.ps` |
| `{ARGS}` | Alias for arguments in some contexts | Same as `$ARGUMENTS` |
| `{AGENT_SCRIPT}` | Resolved to `agent_scripts.sh` or `agent_scripts.ps` | Frontmatter `agent_scripts` |

**In template files** (placeholders filled by the LLM):
| Placeholder | Template | Description |
|-------------|----------|-------------|
| `[FEATURE NAME]` / `[FEATURE]` | spec-template.md, tasks-template.md, plan-template.md | Feature name |
| `[DATE]` | All templates | Current date |
| `[###-feature-name]` | plan-template.md | Branch name |
| `[PROJECT_NAME]` | constitution-template.md | Project name |
| `[PRINCIPLE_N_NAME]` / `[PRINCIPLE_N_DESCRIPTION]` | constitution-template.md | Constitution principles |
| `[CONSTITUTION_VERSION]` | constitution-template.md | Semver version |
| `[RATIFICATION_DATE]` / `[LAST_AMENDED_DATE]` | constitution-template.md | ISO dates |
| `[CHECKLIST TYPE]` | checklist-template.md | Checklist domain name |

### 3.3 Preset Override Mechanism

From `presets/README.md` and `presets/ARCHITECTURE.md`:

**Presets are stackable, priority-ordered collections of template and command overrides.**

**Installation**:
```bash
specify preset add healthcare-compliance --priority 5
```

**Stacking**: Multiple presets can be installed. Lower `--priority` number = higher precedence. When two presets provide the same template, the one with the lowest priority number wins entirely (no merging).

**Command overrides**: Presets can include `type: "command"` entries that replace core commands. These are automatically registered into all detected agent directories. When removed, the registered commands are cleaned up.

**Extension safety check** (ARCHITECTURE.md lines 72-76): When a preset provides a command with 3+ dot segments (e.g., `speckit.myext.cmd`), the system checks if `.specify/extensions/{ext-id}/` exists. If the extension is not installed, the command is skipped.

**Manifest format** (`preset.yml`): Located in `presets/scaffold/preset.yml` -- contains similar metadata to extensions but with `type: "command"` and `type: "template"` entries.

---

## 4. State and Memory

### 4.1 Session Memory -- `.specify/memory/` Directory

The `.specify/memory/` directory stores persistent project-level context:

| File | Description | Created By | Read By |
|------|-------------|------------|---------|
| `constitution.md` | Project constitution with principles | `/speckit.constitution` | `/speckit.plan`, `/speckit.analyze`, `/speckit.implement` |

This is the only documented file in the memory directory. The constitution is the primary persistent state document that governs all subsequent phases.

### 4.2 Cross-Command State -- How State Flows Between Commands

State flows entirely through **files on disk**. There is no in-memory session state between commands. The chain:

```
specify -> spec.md (feature directory)
clarify -> updates spec.md in-place
plan    -> reads spec.md, writes plan.md + research.md + data-model.md + contracts/ + quickstart.md
tasks   -> reads plan.md + spec.md + optional artifacts, writes tasks.md
implement -> reads tasks.md + plan.md + optional artifacts, modifies tasks.md (marks [X])
analyze -> reads spec.md + plan.md + tasks.md (read-only)
checklist -> reads spec.md + plan.md + tasks.md, writes checklists/{domain}.md
```

**Key state files and their roles**:

| File | Created By | Read By | Role |
|------|------------|---------|------|
| `spec.md` | specify | clarify, plan, tasks, analyze, checklist | Feature requirements, user stories |
| `plan.md` | plan | tasks, implement, analyze, checklist | Technical architecture, tech stack |
| `research.md` | plan | tasks, implement | Technical decisions and rationale |
| `data-model.md` | plan | tasks, implement | Entity definitions |
| `contracts/` | plan | tasks, implement | Interface contracts |
| `quickstart.md` | plan | tasks, implement | Validation scenarios |
| `tasks.md` | tasks | implement, analyze, checklist, taskstoissues | Executable task list |
| `checklists/*.md` | checklist, specify | implement | Quality gates |

**Environment variable for feature identity**: `SPECIFY_FEATURE` can be set to override branch detection (common.sh line 17-19). Scripts output `# To persist: export SPECIFY_FEATURE=...` to stderr.

### 4.3 File-Based Artifacts -- The `.specify/` Directory Structure

```
.specify/
├── memory/
│   └── constitution.md              # Project constitution
├── templates/
│   ├── overrides/                   # Priority 1: project-local overrides
│   ├── spec-template.md             # Core spec template
│   ├── plan-template.md             # Core plan template
│   ├── tasks-template.md            # Core tasks template
│   ├── constitution-template.md     # Core constitution template
│   ├── checklist-template.md        # Core checklist template
│   ├── agent-file-template.md       # Agent context file template
│   └── commands/                    # Core command templates
│       ├── specify.md
│       ├── plan.md
│       ├── tasks.md
│       ├── implement.md
│       ├── clarify.md
│       ├── analyze.md
│       ├── checklist.md
│       ├── constitution.md
│       └── taskstoissues.md
├── scripts/
│   └── bash/
│       ├── common.sh
│       ├── create-new-feature.sh
│       ├── check-prerequisites.sh
│       ├── setup-plan.sh
│       └── update-agent-context.sh
├── presets/
│   ├── .registry                    # Preset registry (JSON)
│   └── {preset-id}/
│       ├── preset.yml
│       ├── templates/
│       └── commands/
├── extensions/
│   ├── .registry                    # Extension registry (JSON)
│   ├── .cache/                      # Catalog cache (gitignored)
│   ├── .backup/                     # Config backups (gitignored)
│   │   └── {ext-id}/
│   ├── extensions.yml               # Project extension config (hooks, settings)
│   └── {ext-id}/
│       ├── extension.yml            # Manifest
│       ├── {ext-id}-config.yml      # User config
│       ├── {ext-id}-config.local.yml  # Local overrides (gitignored)
│       ├── commands/
│       ├── scripts/
│       ├── templates/               # Extension-provided templates (priority 3)
│       └── docs/
├── extension-catalogs.yml           # Custom catalog stack config
└── preset-catalogs.yml              # Custom preset catalog stack config

specs/
└── {NNN}-{feature-name}/
    ├── spec.md                      # Feature specification
    ├── plan.md                      # Implementation plan
    ├── research.md                  # Technical research
    ├── data-model.md                # Entity definitions
    ├── quickstart.md                # Validation scenarios
    ├── contracts/                   # Interface contracts
    └── checklists/
        ├── requirements.md          # Created by /speckit.specify
        ├── ux.md                    # Created by /speckit.checklist
        ├── security.md              # Created by /speckit.checklist
        └── ...
```

---

## 5. Integration Points for Orchestrator Extension

### 5.1 Where Milestones/Phases Could Hook In

The orchestrator can hook into the existing lifecycle at these points:

1. **`after_tasks`**: Most natural integration point. After tasks are generated, the orchestrator could analyze task phases, create milestone groupings, and track progress. This hook is already wired in `templates/commands/tasks.md` lines 100-127.

2. **`after_implement`**: After implementation completes, the orchestrator could update milestone status, calculate completion percentages, or trigger downstream workflows. Wired in `templates/commands/implement.md` lines 174-201.

3. **`before_tasks`**: The orchestrator could inject context or constraints before task generation (e.g., "this milestone must not exceed 20 tasks"). Wired in `templates/commands/tasks.md` lines 27-57.

4. **`before_implement`**: Could inject orchestration context or block implementation until prerequisites from other milestones are complete. Wired in `templates/commands/implement.md` lines 18-48.

5. **New custom commands**: The orchestrator can add its own commands (e.g., `speckit.orchestrator.status`, `speckit.orchestrator.milestone`) that operate independently of hooks.

### 5.2 What Hooks Are Available Post-Tasks, Post-Implement

**Post-tasks** (`after_tasks`):
- Fires at the end of `/speckit.tasks` command
- At this point, `tasks.md` is fully generated with all phases, task IDs, story labels, and parallel markers
- The hook command receives no arguments; it must discover context by reading the feature directory

**Post-implement** (`after_implement`):
- Fires at the end of `/speckit.implement` command
- At this point, all tasks in `tasks.md` should be marked `[X]`
- Implementation code exists, tests should be passing

**Important limitation**: Hooks fire as markdown instructions to the AI agent. They do NOT receive structured data about what just happened. The hook command must independently discover the current feature directory and read the relevant files.

### 5.3 How an Extension Could Add New Commands

An extension adds commands by declaring them in `provides.commands` in `extension.yml`:

```yaml
provides:
  commands:
    - name: "speckit.orchestrator.status"
      file: "commands/status.md"
      description: "Show orchestration status"
    - name: "speckit.orchestrator.milestone"
      file: "commands/milestone.md"
      description: "Create or update milestones"
```

Each command file is a markdown file with optional YAML frontmatter. The file is copied to all detected agent directories during installation. The command body is the instruction set the LLM follows when the user invokes the slash command.

**Command naming**: Must follow `speckit.{ext-id}.{cmd}` pattern. For orchestrator: `speckit.orchestrator.*`.

**Aliases**: Optional shorter names via `aliases: ["speckit.status"]`. Note aliases are NOT validated as strictly.

**Scripts**: Commands can reference scripts in their frontmatter:
```yaml
scripts:
  sh: ../../scripts/bash/helper.sh
  ps: ../../scripts/powershell/helper.ps1
```
These paths are rewritten relative to the repo root during registration.

### 5.4 How an Extension Could Add New Templates

Extensions can provide templates at `.specify/extensions/{ext-id}/templates/`. These sit at **priority 3** in the resolution stack (below overrides and presets, above core).

For example, to provide a custom tasks template:
```
.specify/extensions/orchestrator/
└── templates/
    └── tasks-template.md    # Would override core tasks-template if no higher-priority source exists
```

**Limitation**: Templates override entirely; there is no merge/inject mechanism. If the orchestrator provides a `tasks-template.md`, it replaces the core one completely (unless overrides or presets take precedence).

**Future consideration** (from presets/README.md lines 106-115): Composition strategies (`prepend`, `append`, `wrap`) are under consideration but not yet implemented. A `wrap` strategy would use a `{CORE_TEMPLATE}` placeholder to inject preset content before/after the core template.

### 5.5 Gaps: What Spec-Kit Doesn't Provide That the Orchestrator Needs

1. **No multi-feature coordination**: Spec-kit operates on one feature at a time (one branch, one spec directory). There is no concept of a "project" or "release" that groups multiple features. The orchestrator would need to build this layer.

2. **No progress tracking persistence**: Tasks.md tracks completion via checkboxes, but there is no structured progress database. The orchestrator would need to maintain its own state file (e.g., `.specify/extensions/orchestrator/orchestrator-state.yml`) for milestone tracking across sessions.

3. **No inter-feature dependencies**: No mechanism to express "feature A blocks feature B" or "milestone M requires features A, B, C". The orchestrator must model and track these.

4. **No hook data passing**: Hooks fire as text instructions to the LLM. There is no structured data passing between the triggering command and the hook. The orchestrator hook must re-read files to understand what happened.

5. **No aggregation across feature directories**: No built-in way to scan all `specs/*/tasks.md` files and aggregate status. The orchestrator would need its own scripts for this.

6. **No milestone/phase grouping above user stories**: The tasks template organizes by user story within a feature, but there is no concept of grouping user stories across features into milestones or releases.

7. **No timeline or scheduling**: No date-based planning, deadline tracking, or velocity estimation. Tasks have ordering but no time dimension.

8. **No team assignment**: Tasks have no assignee field. The `[P]` marker indicates parallelizability but not who should do the work.

9. **No notification/event system**: Beyond hooks (which are LLM-mediated), there is no event bus or notification mechanism. The orchestrator cannot subscribe to "task completed" events programmatically.

10. **No `before_plan` or `after_plan` hooks**: The plan command does not check for extension hooks. If the orchestrator needs to intercept or augment planning, it cannot hook into that phase. Same for `specify`, `clarify`, `analyze`, and `checklist`.

11. **No `after_specify` hook**: The specify command creates the initial feature but offers no hook point for extensions to react to feature creation.

12. **No structured task metadata**: Tasks are plain markdown checkboxes. There is no machine-readable task database. The orchestrator would need to parse the markdown format (`- [ ] T001 [P] [US1] Description`) to extract structured data.

13. **No cross-session state for hooks**: Hooks are stateless -- they fire every time the command runs. The orchestrator would need to track whether a hook has already been executed for a given feature to avoid duplicate actions.

14. **Condition evaluation gap**: The LLM-side hook checking in command templates does NOT evaluate `condition` expressions -- it skips any hook with a non-empty condition. This means conditions only work when hooks are checked via the Python `HookExecutor` API, not from within AI agent command execution. The orchestrator should use `optional: true` with descriptive prompts rather than relying on conditions.

---

## Appendix: Key File Paths

| Purpose | Path |
|---------|------|
| Extension system RFC | `spec-kit/extensions/RFC-EXTENSION-SYSTEM.md` |
| Extension Python implementation | `spec-kit/src/specify_cli/extensions.py` |
| Extension development guide | `spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md` |
| Extension API reference | `spec-kit/extensions/EXTENSION-API-REFERENCE.md` |
| Extension user guide | `spec-kit/extensions/EXTENSION-USER-GUIDE.md` |
| Extension template scaffold | `spec-kit/extensions/template/` |
| Selftest extension example | `spec-kit/extensions/selftest/` |
| Preset system architecture | `spec-kit/presets/ARCHITECTURE.md` |
| Template resolution function | `spec-kit/scripts/bash/common.sh` (line 183, `resolve_template`) |
| Feature creation script | `spec-kit/scripts/bash/create-new-feature.sh` |
| Prerequisite check script | `spec-kit/scripts/bash/check-prerequisites.sh` |
| Plan setup script | `spec-kit/scripts/bash/setup-plan.sh` |
| SDD methodology guide | `spec-kit/spec-driven.md` |
| Core command templates | `spec-kit/templates/commands/*.md` |
| Core artifact templates | `spec-kit/templates/*.md` |
| Extension catalog | `spec-kit/extensions/catalog.json` |
| Community catalog | `spec-kit/extensions/catalog.community.json` |
| Preset catalog | `spec-kit/presets/catalog.json` |
