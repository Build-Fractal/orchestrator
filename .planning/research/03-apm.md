# APM (Agent Package Manager) -- Research Report for Speckit-Orchestrator

**Source**: `apm/` submodule in this monorepo
**Date**: 2026-03-18
**Purpose**: Document APM's package model, install-time integration, compilation, and integration points relevant to building the speckit-orchestrator extension.

---

## 1. Package Model

### 1.1 `apm.yml` Manifest Format -- Every Field

The manifest file is `apm.yml` (YAML 1.2) at the project root. Spec version 0.1 (Working Draft, 2026-03-06).

**Source**: `apm/docs/src/content/docs/reference/manifest-schema.md`

| Field | Type | Required | Default / Notes |
|-------|------|----------|-----------------|
| `name` | `string` | **REQUIRED** | Package identifier. Convention: alphanumeric, dots, hyphens, underscores. |
| `version` | `string` | **REQUIRED** | Semver pattern `^\d+\.\d+\.\d+` (pre-release/build suffixes allowed). |
| `description` | `string` | optional | Human-readable description. |
| `author` | `string` | optional | Package author or organization. |
| `license` | `string` | optional | SPDX identifier (e.g. `MIT`, `Apache-2.0`). |
| `target` | `enum` | optional | Controls compilation output targets. Values: `vscode`, `agents` (alias for vscode), `claude`, `all`. Auto-detected if absent: `.github/` only -> `vscode`; `.claude/` only -> `claude`; both -> `all`; neither -> `minimal`. |
| `type` | `enum` | optional | How content is processed. Values: `instructions`, `skill`, `hybrid`, `prompts`. |
| `scripts` | `map<string, string>` | optional | Named shell commands run via `apm run <name>`. Support `--param key=value` substitution. |
| `dependencies` | `object` | optional | Contains `apm` (list) and `mcp` (list) sub-keys. Unknown keys preserved for forward compat. |
| `compilation` | `object` | optional | Controls `apm compile` behavior. See section 3. |

**`compilation` sub-fields**:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `target` | `enum` | `all` | Same values as top-level `target`. |
| `strategy` | `enum` | `distributed` | `distributed` (per-directory AGENTS.md) or `single-file` (monolithic). |
| `single_file` | `bool` | `false` | Legacy alias; when true overrides strategy to `single-file`. |
| `output` | `string` | `AGENTS.md` | Custom output path. |
| `chatmode` | `string` | -- | Chatmode filter for compilation. |
| `resolve_links` | `bool` | `true` | Resolve relative Markdown links in primitives. |
| `source_attribution` | `bool` | `true` | Include source-file origin comments. |
| `exclude` | `list<string>` or `string` | `[]` | Glob patterns for dirs to skip (e.g. `apm_modules/**`). |
| `placement.min_instructions_per_file` | `int` | `1` | Minimum instruction count to warrant a separate AGENTS.md. |

### 1.2 Primitive Types -- Naming Conventions and Formats

**Source**: `apm/docs/src/content/docs/reference/primitive-types.md`, `apm/docs/src/content/docs/introduction/key-concepts.md`

All primitives live under `.apm/` (APM-native) or `.github/` (VSCode-compatible). Each type has a specific file extension and frontmatter schema:

#### Instructions (`.instructions.md`)

- Location: `.apm/instructions/`, `.github/instructions/`
- Frontmatter:
  - `description` (required) -- purpose of the standards
  - `applyTo` (required) -- glob pattern for file targeting (e.g. `"**/*.py"`)
  - `author` (optional)
  - `version` (optional)
- Body: Markdown content with the actual instructions

#### Agents (`.agent.md`, legacy: `.chatmode.md`)

- Location: `.apm/agents/`, `.github/agents/`, `.apm/chatmodes/`, `.github/chatmodes/`
- Frontmatter:
  - `description` (required)
  - `tools` (optional) -- list of tool names
  - `expertise` (optional) -- list of domain strings
  - `author`, `version` (optional)
- Body: Markdown persona definition

#### Prompts / Agent Workflows (`.prompt.md`)

- Location: `.apm/prompts/`, `.github/prompts/`
- Frontmatter:
  - `description` (optional)
  - `mode` (optional) -- agent to use
  - `input` (optional) -- list of parameter names
  - `allowed-tools` / `allowedTools` (optional)
  - `model` (optional)
  - `argument-hint` / `argumentHint` (optional)
- Body: Markdown workflow with `${input:param}` placeholders

#### Skills (`SKILL.md`)

- Location: `.apm/skills/{name}/SKILL.md` or package root `SKILL.md`
- Frontmatter:
  - `name` (optional)
  - `description` (optional)
- Body: Concise AI-optimized overview of what the package does
- The entire skill folder is copied to target directories (not just SKILL.md)

#### Context (`.context.md`, `.memory.md`)

- Location: `.apm/context/`, `.apm/memory/`
- Frontmatter: `description` (optional)
- Body: Project knowledge, architecture decisions, team info
- Linkable from other primitives via markdown links

#### Hooks (`.json`)

- Location: `.apm/hooks/`, `hooks/`
- Format: JSON with `hooks` key containing event arrays
- Supported events: `PreToolUse`, `PostToolUse`, `Stop`, `Notification`, `SubagentStop`
- Each event entry has `matcher` and `hooks` arrays with `type: "command"` + `command` string
- Scripts referenced by hooks live in `hooks/scripts/` or `.apm/hooks/scripts/`

#### Plugins (`plugin.json`)

- Pre-packaged agent bundles auto-normalized into APM packages
- APM synthesizes `apm.yml` from `plugin.json` metadata when no `apm.yml` exists
- `plugin.json` searched in: root, `.github/plugin/`, `.claude-plugin/`, `.cursor-plugin/`
- Artifact directories (`agents/`, `skills/`, `commands/`) mapped into `.apm/`

#### MCP Servers

- Declared in `dependencies.mcp` of `apm.yml`
- Two forms: string (registry reference) and object (with `name`, `transport`, `env`, `args`, `registry`, etc.)
- See section 6 for full details

### 1.3 Dependency Declaration

**Source**: `apm/docs/src/content/docs/reference/manifest-schema.md` sections 4.1.1--4.1.4, `apm/docs/src/content/docs/guides/dependencies.md`

Dependencies are declared under `dependencies.apm` as a list. Each entry can be:

**String form** (grammar):
```
dependency     = url_form / shorthand_form / local_path_form
shorthand_form = [host "/"] owner "/" repo ["/" virtual_path] ["#" ref] ["@" alias]
local_path_form = ("./" / "../" / "/" / "~/") path
```

- **GitHub shorthand**: `microsoft/apm-sample-package` (default host is github.com)
- **With ref**: `microsoft/apm-sample-package#v1.0.0`
- **With alias**: `microsoft/apm-sample-package@standards`
- **FQDN** (non-GitHub): `gitlab.com/acme/coding-standards`
- **Full URL**: `https://github.com/microsoft/apm-sample-package.git`, `git@github.com:...`
- **Virtual path**: `ComposioHQ/awesome-claude-skills/brand-guidelines` (subdirectory), `contoso/prompts/review.prompt.md` (single file)
- **Local path**: `./packages/my-shared-skills`, `../sibling-repo`

**Object form** (required when shorthand is ambiguous):
```yaml
- git: https://gitlab.com/acme/repo.git   # clone URL (required for remote)
  path: instructions/security              # sub-path inside repo (optional)
  ref: v2.0                                # git reference (optional)
  alias: acme-sec                          # local alias (optional)
```

**Canonical normalization**: `github.com` is stripped; all other hosts keep FQDN. Input `https://github.com/microsoft/apm-sample-package.git` stores as `microsoft/apm-sample-package`.

### 1.4 Transitive Resolution and Lockfile

**Source**: `apm/docs/src/content/docs/reference/manifest-schema.md` section 6, `apm/docs/src/content/docs/guides/dependencies.md`

**Lockfile**: `apm.lock.yaml` at project root, committed to version control.

```yaml
lockfile_version: "1"
generated_at: <ISO 8601 timestamp>
apm_version: <string>
dependencies:
  - repo_url: <string>              # Resolved clone URL
    host: <string>                  # Git host (optional)
    resolved_commit: <string>       # Full 40-char commit SHA
    resolved_ref: <string>          # Branch/tag resolved
    version: <string>               # Package version from its apm.yml
    virtual_path: <string>          # Virtual package path (if applicable)
    is_virtual: <bool>              # True for file/subdirectory packages
    depth: <int>                    # 1 = direct, 2+ = transitive
    resolved_by: <string>           # Parent dependency (transitive only)
    package_type: <string>          # e.g. "apm_package", "marketplace_plugin"
    deployed_files: <list<string>>  # Workspace-relative paths of installed files
mcp_servers: <list<string>>         # MCP references managed by APM
```

**Resolver behavior**:
1. First install: resolve all deps, write lockfile
2. Subsequent installs: use locked commit SHAs; skip download if checkout matches
3. `--update` flag: re-resolve from `apm.yml`, overwrite lockfile

**Transitive resolution**: Packages may contain their own `apm.yml` with further dependencies. APM resolves the full tree. `depth: 1` = direct, `depth: 2+` = transitive. Uninstall prunes orphaned transitives.

### 1.5 Virtual File Packages

**Source**: `apm/docs/src/content/docs/reference/manifest-schema.md` section 4.1.3

Virtual packages target a subdirectory, file, or collection within a repo rather than the whole repo. Classification rules (evaluated in order):

| Kind | Detection Rule | Example |
|------|---------------|---------|
| **File** | `virtual_path` ends in `.prompt.md`, `.instructions.md`, `.agent.md`, or `.chatmode.md` | `owner/repo/prompts/review.prompt.md` |
| **Collection (dir)** | path contains `/collections/` (no collection extension) | `owner/repo/collections/security` |
| **Collection (manifest)** | path contains `/collections/` + ends with `.collection.yml` | `owner/repo/collections/security.collection.yml` |
| **Subdirectory** | Does not match any above | `owner/repo/skills/security` |

Virtual file packages download a single file and integrate it directly. Virtual subdirectory packages download an entire folder (may contain `SKILL.md` + resources).

---

## 2. Install-Time Integration (Primary Mechanism)

This is the **primary mechanism** for deploying agent primitives. `apm install` copies files from `apm_modules/` into IDE-specific directories based on auto-detection.

**Source**: `apm/docs/src/content/docs/integrations/ide-tool-integration.md` (primary), `apm/docs/src/content/docs/reference/cli-commands.md`

### 2.1 Per-Target Deployment

#### VS Code / GitHub Copilot (`.github/` present)

| APM Primitive | Destination | Format |
|---------------|-------------|--------|
| Prompts (`.prompt.md`) | `.github/prompts/*.prompt.md` | Verbatim copy, original filename |
| Agents (`.agent.md`) | `.github/agents/*.agent.md` | Verbatim copy |
| Instructions (`.instructions.md`) | `.github/instructions/*.instructions.md` | Verbatim copy |
| Skills (`SKILL.md`) | `.github/skills/{folder-name}/` | Entire folder copied |
| Hooks (`.json`) | `.github/hooks/*.json` | Hook definitions with rewritten script paths |
| Hook scripts | `.github/hooks/scripts/{pkg}/` | Referenced scripts |
| MCP servers | `.vscode/mcp.json` | JSON `servers` object |

#### Claude Code (`.claude/` present)

| APM Primitive | Destination | Format |
|---------------|-------------|--------|
| Agents (`.agent.md`, `.chatmode.md`) | `.claude/agents/*.md` | Markdown files |
| Prompts (`.prompt.md`) | `.claude/commands/*.md` | Converted to Claude command format (frontmatter mapped, `$ARGUMENTS` appended) |
| Skills (`SKILL.md`) | `.claude/skills/{folder-name}/` | Entire folder copied |
| Hooks | `.claude/settings.json` (`hooks` key) | Merged into settings JSON |
| Hook scripts | `.claude/hooks/{pkg}/` | Referenced scripts |

#### Cursor (`.cursor/` present)

| APM Primitive | Destination | Format |
|---------------|-------------|--------|
| Instructions (`.instructions.md`) | `.cursor/rules/*.mdc` | Converted: `applyTo:` -> `globs:` frontmatter |
| Agents (`.agent.md`) | `.cursor/agents/*.md` | Markdown with YAML frontmatter |
| Skills (`SKILL.md`) | `.cursor/skills/{name}/SKILL.md` | Identical (agentskills.io standard) |
| Hooks | `.cursor/hooks.json` + `.cursor/hooks/{pkg}/` | Merged JSON config + scripts |
| MCP servers | `.cursor/mcp.json` | Standard `mcpServers` JSON |

#### OpenCode (`.opencode/` present)

| APM Primitive | Destination | Format |
|---------------|-------------|--------|
| Agents (`.agent.md`) | `.opencode/agents/*.md` | Markdown with YAML frontmatter |
| Prompts (`.prompt.md`) | `.opencode/commands/*.md` | Converted to command format |
| Skills (`SKILL.md`) | `.opencode/skills/{name}/SKILL.md` | Identical |
| MCP servers | `opencode.json` | `mcp` key with `command` array, `environment` |
| Instructions | Via `AGENTS.md` | Requires `apm compile` |

**Note**: OpenCode does not support hooks.

### 2.2 Auto-Detection

APM auto-detects which integrations to enable based on directory presence:

| Directory | Integration Enabled |
|-----------|-------------------|
| `.github/` exists | VS Code / Copilot integration |
| `.claude/` exists | Claude Code integration |
| `.cursor/` exists | Cursor integration |
| `.opencode/` exists | OpenCode integration |
| Neither `.github/` nor `.claude/` exists | Packages still installed to `apm_modules/`, but folder integration is skipped |

All integrations can coexist in the same project.

### 2.3 `apm install` vs. `apm compile` -- CRITICAL DISTINCTION

This is a fundamental architectural distinction:

**`apm install` deploys (primary)**:
- Prompts -> `.github/prompts/`, `.claude/commands/`, `.opencode/commands/`
- Agents -> `.github/agents/`, `.claude/agents/`, `.cursor/agents/`, `.opencode/agents/`
- Instructions -> `.github/instructions/`, `.cursor/rules/`
- Skills -> `.github/skills/`, `.claude/skills/`, `.cursor/skills/`, `.opencode/skills/`
- Hooks -> `.github/hooks/`, `.claude/settings.json`, `.cursor/hooks.json`
- MCP servers -> `.vscode/mcp.json`, `.cursor/mcp.json`, `opencode.json`

**`apm compile` generates (optional)**:
- `AGENTS.md` -- instructions ONLY (grouped by `applyTo` patterns). For Copilot, Cursor, OpenCode, Codex, Gemini.
- `CLAUDE.md` -- instructions ONLY (with `@import` syntax). For Claude Code, Claude Desktop.
- Does NOT generate prompts, agents, commands, hooks, or skills -- those are handled by `apm install`.

**When compilation is NOT needed**: GitHub Copilot, Claude Code, and Cursor read per-file instructions natively via `apm install`.

**When compilation IS needed**: OpenCode (instructions only via AGENTS.md), Codex, Gemini, or any tool that reads a single root instruction file.

### 2.4 Collision Detection and Cleanup/Sync

- **Collision detection**: If a local file has the same name as a package file and is NOT tracked in the managed files set (`deployed_files` in `apm.lock.yaml`), APM skips with a warning. Use `--force` to overwrite.
- **Package-owned files**: Always copied fresh (no version comparison needed).
- **Security scanning**: Source files scanned for hidden Unicode before deployment. Critical findings (tag characters, bidi overrides) block deployment.
- **Install**: Adds files, tracked in `deployed_files`.
- **Uninstall**: Removes only files tracked in `deployed_files` for that package. User-authored files preserved.
- **Prune**: Removes orphaned packages and their deployed files.
- **Link resolution**: Context links are resolved during integration (paths rewritten to point to actual source locations in `apm_modules/`).

### 2.5 `deployed_files` Tracking in `apm.lock`

Every file APM places in the project is recorded in `apm.lock.yaml` under the `deployed_files` list for the relevant package:

```yaml
dependencies:
  microsoft/apm-sample-package:
    repo_url: "https://github.com/microsoft/apm-sample-package"
    resolved_commit: "abc123def456"
    deployed_files:
      - .github/prompts/design-review.prompt.md
      - .github/prompts/accessibility-audit.prompt.md
      - .github/agents/design-reviewer.agent.md
      - .github/skills/style-checker/SKILL.md
      - .claude/commands/design-review.md
      - .claude/commands/accessibility-audit.md
```

This enables safe cleanup: only tracked files are removed on uninstall/prune.

---

## 3. Compilation (Optional, Instructions Only)

**Source**: `apm/docs/src/content/docs/guides/compilation.md`, `apm/src/apm_cli/compilation/agents_compiler.py`, `apm/src/apm_cli/compilation/distributed_compiler.py`, `apm/src/apm_cli/compilation/context_optimizer.py`, `apm/src/apm_cli/compilation/claude_formatter.py`, `apm/src/apm_cli/compilation/constitution.py`

### 3.1 When Compilation IS Needed vs. NOT Needed

**NOT needed** (read per-file instructions natively via `apm install`):
- GitHub Copilot
- Claude Code
- Cursor

**Needed** (require single-root-file formats):
- OpenCode: needs `apm compile` for instructions via `AGENTS.md` (but agents/commands/skills deployed by `apm install`)
- Codex CLI: instructions only via `AGENTS.md`
- Gemini: instructions only via `GEMINI.md`

### 3.2 Target Auto-Detection and Output Files

| Project Structure | Target | Generated Files |
|-------------------|--------|----------------|
| `.github/` only | `copilot` | `AGENTS.md` |
| `.claude/` only | `claude` | `CLAUDE.md` |
| Both folders | `all` | Both `AGENTS.md` and `CLAUDE.md` |
| Neither folder | `minimal` | `AGENTS.md` only (universal format) |

`AGENTS.md` contains ONLY instructions (grouped by `applyTo` patterns). `CLAUDE.md` contains ONLY instructions (with `@import` syntax for dependencies).

### 3.3 Distributed Compilation

Default strategy is `distributed` -- generates per-directory AGENTS.md files following the [AGENTS.md standard](https://agents.md):

- Recursive discovery: agents read AGENTS.md from current directory up to project root
- Proximity priority: closest AGENTS.md takes precedence
- Inheritance model: child directories inherit and can override parent instructions

The `DistributedAgentsCompiler` class (`apm/src/apm_cli/compilation/distributed_compiler.py`):
1. Phase 0: Context link resolution (register contexts, scan for references)
2. Phase 1: Directory structure analysis
3. Phase 2: Optimal AGENTS.md placement via `ContextOptimizer`
4. Phase 3: Generate distributed files
5. Phase 4: Orphaned file cleanup
6. Phase 5: Coverage validation

### 3.4 Context Optimization Algorithm

**Source**: `apm/src/apm_cli/compilation/context_optimizer.py`

The core optimization problem:
```
Objective: minimize Sum(pollution[d] * files[d]) for d in directories
Subject to: every matching file can inherit its applicable instructions
Variables: placement_matrix in {0,1}^(directories x instructions)
```

**Three-tier placement strategy** based on distribution score:

```python
Distribution_Score = (matching_directories / total_directories) * diversity_factor
# diversity_factor = 1.0 + (depth_variance * 0.5)
```

| Distribution Score | Strategy | Description |
|-------------------|----------|-------------|
| < 0.3 | Single-Point | `_optimize_single_point_placement()` -- place at best single directory |
| 0.3 -- 0.7 | Selective Multi | `_optimize_selective_placement()` -- place at select directories |
| > 0.7 | Distributed | `_optimize_distributed_placement()` -- wide coverage |

**Constraint satisfaction weights** (from source):
```python
COVERAGE_EFFICIENCY_WEIGHT = 1.0    # Mandatory coverage priority
POLLUTION_MINIMIZATION_WEIGHT = 0.8  # Strong pollution penalty
MAINTENANCE_LOCALITY_WEIGHT = 0.3    # Moderate locality preference
DEPTH_PENALTY_FACTOR = 0.1          # Excessive nesting penalty
```

**Default excluded directory names**: `node_modules`, `__pycache__`, `.git`, `dist`, `build`, `apm_modules`, plus hidden directories (starting with `.`).

### 3.5 Constitution Injection

**Source**: `apm/src/apm_cli/compilation/constitution.py`, `apm/src/apm_cli/compilation/constants.py`

The constitution file is expected at `.specify/memory/constitution.md` (defined in `CONSTITUTION_RELATIVE_PATH` in `apm/src/apm_cli/compilation/constants.py`).

**Block format** injected at the top of AGENTS.md/CLAUDE.md:
```
<!-- SPEC-KIT CONSTITUTION: BEGIN -->
hash: <sha256_12> path: .specify/memory/constitution.md
<entire original file content>
<!-- SPEC-KIT CONSTITUTION: END -->
```

**Behavior**:
- Enabled by default; disable via `--no-constitution` (existing block preserved)
- Idempotent: re-running compile without changes leaves file unchanged
- Drift aware: modifying the constitution regenerates block with new hash
- Safe: absence of constitution does not fail compilation (status MISSING in Rich table)
- Constitution read is cached per resolved `base_dir` for process lifetime

**Key constants** (`apm/src/apm_cli/compilation/constants.py`):
```python
CONSTITUTION_MARKER_BEGIN = "<!-- SPEC-KIT CONSTITUTION: BEGIN -->"
CONSTITUTION_MARKER_END = "<!-- SPEC-KIT CONSTITUTION: END -->"
CONSTITUTION_RELATIVE_PATH = ".specify/memory/constitution.md"
BUILD_ID_PLACEHOLDER = "<!-- Build ID: __BUILD_ID__ -->"
```

---

## 4. APM + Spec-Kit Integration

**Source**: `apm/docs/src/content/docs/integrations/ide-tool-integration.md` (APM + Spec-kit Integration section)

### 4.1 "Context Foundation" (APM) + "Specification Layer" (Spec-kit)

APM provides the **context foundation** -- infrastructure for AI development:
- Context packaging: bundle project knowledge, standards, patterns into reusable modules
- Dynamic loading: smart context composition based on file patterns and current tasks
- Performance optimization: optimized context delivery for large projects
- Memory management: strategic LLM token usage across conversations

Spec-kit provides the **specification layer** for Specification-Driven Development (SDD):
- Constitution injection: APM injects `constitution.md` into compiled `AGENTS.md`
- Rule enforcement: all coding agents respect non-negotiable governance rules
- Contextual augmentation: compiled output embeds team context modules after the constitution
- SDD enhancement: augments the SDD process with additional curated context

### 4.2 Constitution Injection During Compilation

When using `apm compile`, APM automatically injects the Spec-kit constitution (`.specify/memory/constitution.md`) into the compiled instruction files:
- For AGENTS.md: injected at top inside delimited block
- For CLAUDE.md: injected via `ClaudeFormatter._generate_claude_content()` which calls `read_constitution()` and adds a "# Constitution" section for root-level CLAUDE.md files
- The constitution block includes a SHA-256 hash for drift detection

### 4.3 Integrated Workflow

```bash
# 1. Set up APM contextual foundation
apm init my-project && apm install

# 2. Optional: compile for tools without native integration
# Spec-kit constitution is automatically included in compiled AGENTS.md
apm compile

# 3. AI workflows use both SDD rules and team context
```

**Key benefits**:
- Universal context: APM grounds any coding agent on context regardless of workflow
- SDD compatibility: perfect for specification-driven development
- Flexible workflows: also works with traditional prompting and vibe coding
- Team knowledge: combines constitutional rules with team-specific context

---

## 5. APM + GitHub Agentic Workflows Integration

**Source**: `apm/docs/src/content/docs/integrations/gh-aw.md`

### 5.1 Frontmatter `dependencies:` Field

gh-aw natively supports APM through a `dependencies:` frontmatter field in workflow files.

**Simple array format**:
```yaml
---
on:
  pull_request:
    types: [opened]
engine: copilot

dependencies:
  - microsoft/apm-sample-package
  - github/awesome-copilot/skills/review-and-refactor
---
```

**Object format with options**:
```yaml
---
on:
  issues:
    types: [opened]
engine: copilot

dependencies:
  packages:
    - microsoft/apm-sample-package
    - your-org/security-compliance
  isolated: true
---
```

Each entry is a standard APM package reference -- `owner/repo` for a full package or `owner/repo/path/to/skill` for an individual primitive.

### 5.2 How It Works

1. The gh-aw compiler detects the `dependencies:` field in workflow frontmatter
2. In the **activation job**, APM resolves the full dependency tree and packs the result
3. In the **agent job**, the bundle is unpacked into the workspace and the agent discovers the primitives

### 5.3 Target Auto-Inference from `engine:` Field

The APM compilation target is automatically inferred from the configured `engine:` field:
- `engine: copilot` -> copilot target
- `engine: claude` -> claude target
- Other engines -> `all` target

No manual target configuration is needed.

### 5.4 `apm-action` Pre-Step Alternative

For more control, use `microsoft/apm-action@v1` as an explicit workflow step:

```yaml
steps:
  - name: Install agent primitives
    uses: microsoft/apm-action@v1
    with:
      script: install
    env:
      GITHUB_TOKEN: ${{ github.token }}
```

This runs `apm install && apm compile` directly, giving access to the full APM CLI. The repo needs `apm.yml` + `apm.lock.yaml`.

**When to use apm-action over frontmatter deps**:
- Custom compilation options (specific targets, flags)
- Running additional APM commands (audit, preview)
- Workflows that need `apm.yml`-based configuration
- Debugging dependency resolution

### 5.5 APM Bundles for Sandboxed Environments

For environments where network access is restricted during workflow execution:

1. Run `apm pack` in CI to produce a self-contained bundle
2. Distribute as a workflow artifact or commit to the repo
3. Reference bundled primitives in the workflow

Bundles resolve full dependency trees ahead of time -- zero network access needed at runtime.

### 5.6 Isolated Mode

When `isolated: true` is set in the object format:

```yaml
dependencies:
  packages:
    - your-org/triage-rules
  isolated: true
```

gh-aw **clears existing `.github/` primitive directories** (instructions, skills, agents) before unpacking the APM bundle. The agent sees ONLY the context declared by the workflow, preventing instruction pollution from the host repository.

### 5.7 Content Scanning

APM scans all package source files before deployment:
- **Critical findings** (tag characters U+E0001-E007F, bidi overrides U+202A-E/U+2066-9): **block deployment**
- **Warnings** (zero-width spaces/joiners, mid-file BOM): non-blocking, flagged in diagnostics
- **Info** (non-breaking spaces, unusual whitespace): mostly harmless, flagged for awareness

Content scanning also runs during `apm compile` (defense-in-depth on compiled output) and `apm pack` (before bundling).

On-demand: `apm audit` scans deployed files or any arbitrary file. Exit codes: 0 (clean), 1 (critical), 2 (warnings only).

---

## 6. MCP Server Management

**Source**: `apm/docs/src/content/docs/reference/manifest-schema.md` section 4.2, `apm/docs/src/content/docs/integrations/ide-tool-integration.md`, `apm/docs/src/content/docs/enterprise/security.md`

### 6.1 Declaration Format in `apm.yml`

**String form** (registry reference):
```yaml
dependencies:
  mcp:
    - io.github.github/github-mcp-server
```

**Object form** (registry with overlays):
```yaml
- name: io.github.github/github-mcp-server
  tools: ["repos", "issues"]
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Object form** (self-defined, `registry: false`):
```yaml
- name: my-private-server
  registry: false
  transport: stdio          # Required: stdio | sse | http | streamable-http
  command: ./bin/my-server   # Required for stdio
  args: ["--port", "3000"]
  env:
    API_KEY: ${{ secrets.KEY }}
```

**Full field list for MCP object form**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | REQUIRED | Server identifier |
| `transport` | `enum` | Conditional | `stdio`, `sse`, `http`, `streamable-http`. Required when `registry: false`. |
| `env` | `map<string, string>` | optional | Environment variable overrides |
| `args` | `dict` or `list` | optional | Argument overrides |
| `version` | `string` | optional | Pin server version |
| `registry` | `bool` or `string` | optional | Default `true`. `false` = self-defined. String = custom registry URL. |
| `package` | `enum` | optional | `npm`, `pypi`, `oci` |
| `headers` | `map<string, string>` | optional | Custom HTTP headers |
| `tools` | `list<string>` | optional | Restrict exposed tools (default: `["*"]`) |
| `url` | `string` | Conditional | Required for http/sse/streamable-http when `registry: false` |
| `command` | `string` | Conditional | Required for stdio when `registry: false` |

### 6.2 Trust Model

| Dependency Type | Registry Servers | Self-Defined Servers (`registry: false`) |
|----------------|-----------------|----------------------------------------|
| Direct (depth 1) | Auto-trusted | Auto-trusted |
| Transitive (depth > 1) | Auto-trusted | **Skipped with warning** |

To trust self-defined servers from transitive dependencies:
1. Re-declare the server in your root `apm.yml` (recommended), or
2. Use `--trust-transitive-mcp` flag

### 6.3 Per-Client Config Generation

| Client | Config Location | Format |
|--------|----------------|--------|
| VS Code | `.vscode/mcp.json` | JSON `servers` object |
| Cursor | `.cursor/mcp.json` | Standard `mcpServers` JSON |
| OpenCode | `opencode.json` | `mcp` key with `command` array, `environment` |
| GitHub Copilot CLI | `~/.copilot/mcp-config.json` | JSON `mcpServers` object |
| Codex CLI | `~/.codex/config.toml` | TOML `mcp_servers` section |

APM detects which runtimes are installed and configures for all. Use `--runtime <name>` or `--exclude <name>` to control. Stale server cleanup happens on uninstall/dependency removal.

---

## 7. Integration Points for Orchestrator Extension

### 7.1 How the Orchestrator's Skills/Prompts/Agents Would Be Packaged in `apm.yml`

The speckit-orchestrator would be an APM package with an `apm.yml` like:

```yaml
name: speckit-orchestrator
version: 1.0.0
description: Orchestrator skills and workflows for spec-driven development
author: Clariti
license: MIT
type: hybrid    # Both instructions compilation AND skill installation

dependencies:
  apm: []       # Any upstream APM packages the orchestrator depends on
  mcp: []       # Any MCP servers needed

scripts:
  orchestrate: "copilot -p 'orchestrate.prompt.md'"
```

Package structure:
```
speckit-orchestrator/
├── apm.yml
├── SKILL.md                          # Package meta-guide for AI discovery
├── .apm/
│   ├── agents/
│   │   └── orchestrator.agent.md     # Orchestrator agent persona
│   ├── instructions/
│   │   └── orchestration.instructions.md  # Standards for orchestrated workflows
│   ├── prompts/
│   │   ├── orchestrate.prompt.md     # Main orchestration workflow
│   │   └── plan-review.prompt.md     # Plan review workflow
│   ├── skills/
│   │   └── task-delegation/
│   │       └── SKILL.md              # Task delegation skill
│   └── context/
│       └── orchestration-patterns.context.md
└── hooks/
    └── pre-task.json                  # Lifecycle hooks for orchestration events
```

The `type: hybrid` setting ensures both AGENTS.md compilation (for instructions) and skill directory creation (for the SKILL.md at root and sub-skills).

### 7.2 How `apm install` Would Deploy Orchestrator Commands to Each IDE

When a consuming project runs `apm install`:

**VS Code / Copilot** (`.github/` present):
- `.github/prompts/orchestrate.prompt.md`
- `.github/prompts/plan-review.prompt.md`
- `.github/agents/orchestrator.agent.md`
- `.github/instructions/orchestration.instructions.md`
- `.github/skills/speckit-orchestrator/SKILL.md` (+ supporting files)
- `.github/skills/task-delegation/SKILL.md`

**Claude Code** (`.claude/` present):
- `.claude/commands/orchestrate.md` (converted from `.prompt.md`, with `$ARGUMENTS` appended)
- `.claude/commands/plan-review.md`
- `.claude/agents/orchestrator.md`
- `.claude/skills/speckit-orchestrator/SKILL.md`
- `.claude/skills/task-delegation/SKILL.md`
- Hooks merged into `.claude/settings.json`

**Cursor** (`.cursor/` present):
- `.cursor/rules/orchestration.mdc` (instructions converted: `applyTo` -> `globs`)
- `.cursor/agents/orchestrator.md`
- `.cursor/skills/speckit-orchestrator/SKILL.md`

**OpenCode** (`.opencode/` present):
- `.opencode/agents/orchestrator.md`
- `.opencode/commands/orchestrate.md`
- `.opencode/skills/speckit-orchestrator/SKILL.md`

All deployed files would be tracked in `apm.lock.yaml` under the orchestrator package's `deployed_files` list.

### 7.3 How gh-aw Workflows Would Declare Orchestrator Package as a Dependency

In a GitHub Agentic Workflow file:

```yaml
---
on:
  issues:
    types: [opened]
engine: copilot

dependencies:
  - your-org/speckit-orchestrator
  - your-org/domain-context-package
---

# Orchestrated Issue Triage

Use the orchestrator to analyze this issue and delegate sub-tasks.
```

Or with isolated mode (recommended for CI automation):

```yaml
---
on:
  pull_request:
    types: [opened]
engine: copilot

dependencies:
  packages:
    - your-org/speckit-orchestrator
    - your-org/security-compliance
  isolated: true
---

# Orchestrated PR Review

Use the orchestrator to coordinate security review, code quality, and compliance checks.
```

The gh-aw compiler would:
1. Detect `dependencies:` in the frontmatter
2. In the activation job, resolve `speckit-orchestrator` and all its transitive deps via APM
3. Auto-infer the compilation target from `engine: copilot`
4. Pack the resolved bundle
5. In the agent job, unpack into the workspace -- orchestrator primitives are immediately available

### 7.4 How Constitution Injection Works for Orchestrator Workflows

The constitution injection flow affects the orchestrator in two ways:

**1. When the orchestrator package is used in a project with a constitution**:

If the consuming project has `.specify/memory/constitution.md` (the spec-kit constitution) and runs `apm compile`, the constitution is injected at the top of both `AGENTS.md` and `CLAUDE.md`. The orchestrator's instructions are included *after* the constitution block. This means:
- The orchestrator's agents and workflows always see the project's governance rules first
- Constitution hash enables drift detection -- if governance rules change, the compiled output is regenerated

**2. When the orchestrator package itself ships a constitution**:

If the orchestrator package includes its own `.specify/memory/constitution.md`, that constitution is used when compiling within the orchestrator's own development context. However, in consuming projects, the consuming project's constitution takes precedence (it's the project-root constitution that gets injected).

**Constitution injection constants** (from `apm/src/apm_cli/compilation/constants.py`):
```python
CONSTITUTION_MARKER_BEGIN = "<!-- SPEC-KIT CONSTITUTION: BEGIN -->"
CONSTITUTION_MARKER_END = "<!-- SPEC-KIT CONSTITUTION: END -->"
CONSTITUTION_RELATIVE_PATH = ".specify/memory/constitution.md"
```

**In CLAUDE.md**, the `ClaudeFormatter` adds a dedicated "# Constitution" section for root-level files by calling `read_constitution(self.base_dir)` and embedding the content.

**In AGENTS.md**, the `ConstitutionInjector` wraps the content in the delimited block format with the SHA-256 hash.

Both approaches ensure the orchestrator's instructions are always subordinate to project governance rules.

---

## Key Takeaways for Orchestrator Extension Design

1. **Package as a standard APM package** with `apm.yml`, `SKILL.md`, and primitives under `.apm/`. Use `type: hybrid` for maximum compatibility.

2. **Leverage install-time integration** as the primary deployment mechanism. The orchestrator's prompts become slash commands in Claude, prompt files in VS Code, etc. -- zero configuration needed from users.

3. **Skills are the discovery mechanism** -- the `SKILL.md` at the package root tells AI agents what the orchestrator can do. Sub-skills under `.apm/skills/` provide granular capabilities.

4. **Constitution subordination** is automatic -- when users have a spec-kit constitution, it always takes precedence over package-level instructions during compilation.

5. **gh-aw integration is declarative** -- just add the orchestrator to `dependencies:` in workflow frontmatter. Isolated mode prevents instruction pollution for CI automation.

6. **Security scanning is built-in** -- all package content is scanned before deployment. Critical findings block deployment. This is especially important for an orchestrator that may coordinate sensitive workflows.

7. **Transitive MCP trust boundary** applies -- if the orchestrator declares self-defined MCP servers, they are auto-trusted as direct deps but blocked for transitive consumers unless explicitly opted in.
