# Research Report: GitHub Agentic Workflows (gh-aw) for speckit-orchestrator

This report documents the complete gh-aw platform as it relates to building a spec-kit extension called "speckit-orchestrator". All information is sourced from the local `gh-aw/` submodule and `apm/` submodule within this monorepo.

---

## 1. Workflow Format and Lifecycle

### 1.1 Markdown Structure -- YAML Frontmatter + Natural Language Body

Every gh-aw workflow is a single Markdown file stored in `.github/workflows/`. It consists of two parts:

1. **YAML frontmatter** between `---` delimiters -- all configuration: triggers, permissions, tools, engine, safe-outputs, etc.
2. **Markdown body** -- natural language instructions for the AI agent.

```
---
on:
  issues:
    types: [opened]
permissions:
  contents: read
tools:
  github:
    toolsets: [issues]
safe-outputs:
  add-comment:
---

# Workflow Description

Read the issue #${{ github.event.issue.number }}. Add a comment listing useful resources.
```

Source: `gh-aw/docs/src/content/docs/reference/workflow-structure.md`

The workflow file (`.md`) is the editable source of truth. Running `gh aw compile` generates a `.lock.yml` file -- the compiled GitHub Actions workflow with security hardening. Both files are committed. The markdown body is loaded **at runtime**, meaning you can edit AI instructions without recompilation; only frontmatter changes require recompilation.

Source: `gh-aw/docs/src/content/docs/reference/compilation-process.md` (line ~260: "Compilation is only required when changing frontmatter configuration")

### 1.2 Every Frontmatter Field

The complete set of frontmatter fields, sourced from `gh-aw/docs/src/content/docs/reference/frontmatter.md`:

| Field | Purpose |
|-------|---------|
| `on:` | Trigger events (standard GitHub Actions syntax + extensions) |
| `description:` | Human-readable description rendered as lock file comment |
| `source:` | Origin tracking (`owner/repo/path@ref`), auto-populated by `gh aw add` |
| `private:` | Prevents installation via `gh aw add` |
| `resources:` | Companion files fetched alongside workflow |
| `labels:` | Array of strings for categorizing workflows |
| `metadata:` | Custom key-value pairs (1-64 char keys, max 1024 char values) |
| `plugins:` | (Experimental) Engine-specific plugin installation |
| `dependencies:` | APM package dependencies (see Section 2) |
| `runtimes:` | Override runtime versions (node, python, go, etc.) |
| `permissions:` | GitHub Actions permissions for the agent job |
| `on.roles:` | Repository access roles that can trigger (default: `[admin, maintainer, write]`) |
| `on.bots:` | Allowed bot accounts for triggering |
| `on.skip-roles:` | Skip for specific roles |
| `on.skip-bots:` | Skip for specific actors |
| `strict:` | Enhanced security validation (default: `true`) |
| `features:` | Feature flags (e.g., `action-mode`, `mcp-gateway`) |
| `engine:` | AI engine selection (`copilot`, `claude`, `codex`, `gemini`) |
| `network:` | Network access control with ecosystem identifiers and domain allowlists |
| `mcp-scripts:` | Inline custom MCP tools (JavaScript or shell) |
| `mcp-servers:` | Custom MCP server configurations |
| `safe-outputs:` | Write operations the agent can request |
| `tools:` | Tool configuration (edit, bash, github, web-fetch, web-search, playwright, cache-memory, repo-memory, agentic-workflows) |
| `run-name:` | Custom run name |
| `runs-on:` | Runner selection (default: `ubuntu-latest`) |
| `timeout-minutes:` | Max duration (default: 20) |
| `concurrency:` | Concurrency group configuration |
| `env:` | Environment variables |
| `secrets:` | Secret values passed to execution |
| `environment:` | Deployment protection rules |
| `container:` | Container to run job steps in |
| `services:` | Service containers (databases, caches) |
| `if:` | Conditional execution |
| `checkout:` | Configure `actions/checkout` (or `checkout: false` to disable) |
| `steps:` | Custom steps before agentic execution |
| `post-steps:` | Custom steps after agentic execution |
| `jobs:` | Custom jobs that run before agentic execution |
| `cache:` | Cache configuration using `actions/cache` syntax |
| `imports:` | Import shared workflow components |
| `sandbox:` | Sandbox environment configuration (AWF agent container, MCP Gateway) |

### 1.3 Trigger Types

Source: `gh-aw/docs/src/content/docs/reference/triggers.md`

gh-aw supports all standard GitHub Actions triggers plus extensions:

**Event-based triggers:**
- `issues:` -- Issue events (`opened`, `edited`, `labeled`, `closed`, etc.)
- `pull_request:` -- PR events (`opened`, `synchronize`, `labeled`, `merged`, etc.)
- `issue_comment:` / `pull_request_review_comment:` / `discussion_comment:` -- Comment events
- `push:` -- Push events (branch, tags)
- `workflow_run:` -- After another workflow completes
- `release:` -- Release events

**Schedule triggers:**
- Standard cron: `schedule: - cron: "0 9 * * 1"`
- Fuzzy schedules (recommended): `schedule: daily`, `schedule: weekly on monday`, `schedule: daily around 14:00`, `schedule: daily between 9:00 and 17:00`
- The compiler assigns deterministic scattered times based on file path to avoid load spikes

**Manual dispatch:**
- `workflow_dispatch:` -- Manual trigger with optional typed inputs (`string`, `boolean`, `choice`, `environment`)

**Command triggers (`slash_command:`):**
- Respond to `/command-name` in issues, PRs, and comments
- Shorthand: `on: /my-bot`
- Multiple command names: `name: ["cmd.add", "cmd.remove"]`
- Event filtering: `events: [issues, issue_comment, pull_request_comment]`
- The command must be the **first word** of the comment/body to trigger

Source: `gh-aw/docs/src/content/docs/reference/command-triggers.md`

**Trigger shorthands:**
```yaml
on: push to main
on: pull_request opened
on: pull_request merged
on: issue opened
on: issue labeled bug
on: manual
on: manual with input version
on: comment created
on: release published
on: daily
on: weekly on monday
on: /my-bot
```

**Additional trigger controls:**
- `reaction:` -- Emoji reaction on triggering items (e.g., `"eyes"`, `"rocket"`)
- `stop-after:` -- Auto-disable after deadline (`"+25h"`, `"2024-12-31"`)
- `manual-approval:` -- Require environment protection rules
- `skip-if-match:` / `skip-if-no-match:` -- Conditional skip via GitHub search queries
- `forks:` -- Fork filtering for pull_request triggers
- `lock-for-agent:` -- Lock issue during execution to prevent concurrent modifications

### 1.4 Compile Process

Source: `gh-aw/docs/src/content/docs/reference/compilation-process.md`

The `gh aw compile` command transforms markdown workflow files into GitHub Actions `.lock.yml` files through five phases:

**Phase 1: Parsing and Validation**
- Extract YAML frontmatter
- Validate against workflow schema
- Resolve imports using breadth-first search (BFS) traversal
- Merge configurations from imported files (field-specific merge strategies)
- Validate expression safety

**Phase 2: Job Construction**
- Builds specialized jobs: pre-activation, activation, agent, safe outputs, safe-jobs, custom jobs

**Phase 3: Dependency Resolution**
- Validates job dependencies, detects circular references
- Computes topological order, generates Mermaid graph

**Phase 4: Action Pinning**
- Pins all actions to commit SHAs (e.g., `actions/checkout@b4ffde6...11 # v6`)
- Resolution order: cache (`.github/aw/actions-lock.json`) -> GitHub API -> embedded pins

**Phase 5: YAML Generation**
- Assembles final `.lock.yml`: header with metadata, Mermaid dependency graph, alphabetical jobs, embedded original prompt

**Generated job types:**

| Job | Purpose |
|-----|---------|
| `pre_activation` | Role checks, stop-after deadlines, skip-if conditions |
| `activation` | Prepare context, sanitize event text, validate lock file freshness |
| `agent` | Core AI execution with configured engine, tools, MCP servers |
| `detection` | (Optional) Threat detection AI scan of agent output |
| Safe output jobs | Execute GitHub API writes (create issue, PR, comment, etc.) |
| `conclusion` | Aggregate results and generate workflow summary |

**CLI commands:**
```bash
gh aw compile                     # Compile all workflows
gh aw compile my-workflow         # Compile specific workflow
gh aw compile --strict            # Enhanced security validation
gh aw compile --no-emit           # Validate without generating files
gh aw compile --purge             # Remove orphaned .lock.yml files
gh aw validate                    # Compile + all linters, no file output
```

### 1.5 Safe Outputs

Source: `gh-aw/docs/src/content/docs/reference/safe-outputs.md`

Safe outputs are the mechanism by which agentic workflows perform write operations. The agent runs read-only and **declares** intended operations via structured output. Separate permission-controlled jobs then **execute** those operations after the agent completes.

**Security model:** Agents run read-only -> request actions via structured output -> separate jobs with scoped write permissions execute requests. This provides least privilege, defense against prompt injection, auditability, and controlled limits.

**Available safe output types:**

Issues & Discussions:
- `create-issue` -- Create GitHub issues (configurable max, title-prefix, labels, assignees, auto-expiration, grouping, cross-repo)
- `update-issue` -- Update issue status/title/body
- `close-issue` -- Close issues with comment
- `link-sub-issue` -- Link issues as sub-issues
- `create-discussion` -- Create GitHub discussions
- `update-discussion` -- Update discussion title/body/labels
- `close-discussion` -- Close with reason

Pull Requests:
- `create-pull-request` -- Create PRs with code changes (draft policy, reviewers, protected files, base-branch, excluded-files)
- `update-pull-request` -- Update PR title/body
- `close-pull-request` -- Close without merging
- `create-pull-request-review-comment` -- Line-specific code review comments
- `reply-to-pull-request-review-comment` -- Reply to existing review comments
- `resolve-pull-request-review-thread` -- Resolve review threads
- `push-to-pull-request-branch` -- Push changes to PR branch

Labels, Assignments & Reviews:
- `add-comment` -- Post comments on issues/PRs/discussions
- `hide-comment` -- Hide comments
- `add-labels` / `remove-labels` -- Manage labels (with `allowed:` allowlist)
- `add-reviewer` -- Add reviewers to PRs
- `assign-milestone` -- Assign issues to milestones
- `assign-to-agent` -- Assign Copilot coding agent to issues/PRs
- `assign-to-user` / `unassign-from-user` -- User assignments

Projects, Releases & Assets:
- `update-project` -- Manage GitHub Projects boards (add items, update fields)
- `create-project` -- Create new project boards
- `create-project-status-update` -- Create stakeholder-facing status updates
- `update-release` -- Update release descriptions
- `upload-asset` -- Upload files to orphaned git branch

Orchestration:
- `dispatch-workflow` -- Trigger other workflows via `workflow_dispatch` API
- `call-workflow` -- Call reusable workflows via compile-time fan-out

Security:
- `create-code-scanning-alert` -- Generate SARIF security findings
- `autofix-code-scanning-alert` -- Create automated fixes for code scanning alerts

Custom:
- `jobs:` -- Custom post-processing jobs with full GitHub Actions steps, registered as MCP tools

Source for schema: `gh-aw/schemas/agent-output.json`

### 1.6 Security Model

Source: `gh-aw/docs/src/content/docs/introduction/architecture.mdx`

gh-aw implements a defense-in-depth security architecture across three trust layers:

**Layer 1: Substrate-Level Trust**
- Hardware/kernel enforcement: CPU, MMU, kernel, container runtime
- Three privileged containers: network firewall (iptables), API proxy (token isolation), MCP Gateway (container spawning)
- Memory isolation, CPU isolation, kernel-enforced communication boundaries

**Layer 2: Configuration-Level Trust**
- Declarative configuration artifacts control component loading, connectivity, communication channels, privilege assignment
- Tool allowlisting: `bash: ["echo", "ls"]` restricts commands; `allowed:` on MCP servers restricts tools
- Network isolation: `network.allowed` controls egress; ecosystem identifiers (e.g., `python`, `node`) instead of individual domains in strict mode
- SHA-pinned actions prevent supply chain attacks

**Layer 3: Plan-Level Trust**
- Compiler decomposes workflow into stages with specific permissions per stage
- SafeOutputs: agent writes buffered artifacts -> deterministic filters/analyses -> externalised writes in separate jobs
- Agent job: read-only permissions, sandboxed in AWF container
- Safe output jobs: scoped write permissions, run only after agent completes (and optionally after threat detection)

**Key security features:**
- Read-only by default -- agents have no write permissions
- Sandboxed execution via Agent Workflow Firewall (AWF) -- Docker container with network egress control
- Input sanitization -- `needs.activation.outputs.text` neutralizes @mentions, bot triggers, XML injection, filters URIs, limits content size
- Content scanning -- hidden Unicode detection during APM install
- Threat detection -- optional AI-powered scan of agent output before safe output execution
- Strict mode (default: `true`) -- refuses write permissions, requires explicit network config, refuses wildcards, requires SHA-pinned actions

### 1.7 Multi-Engine Support

Source: `gh-aw/docs/src/content/docs/reference/engines.md`

gh-aw supports multiple AI engines via the `engine:` frontmatter field:

| Engine | Value | Required Secret | Default Model |
|--------|-------|-----------------|---------------|
| GitHub Copilot CLI | `copilot` (default) | `COPILOT_GITHUB_TOKEN` | claude-sonnet-4 |
| Claude by Anthropic (Claude Code) | `claude` | `ANTHROPIC_API_KEY` | -- |
| OpenAI Codex | `codex` | `OPENAI_API_KEY` | -- |
| Google Gemini CLI | `gemini` | `GEMINI_API_KEY` | -- |

**Extended configuration:**
```yaml
engine:
  id: copilot
  version: "0.0.422"           # Pin specific version
  model: gpt-5                 # Override default model
  command: /usr/local/bin/copilot  # Custom executable
  args: ["--add-dir", "/workspace"]  # Custom CLI arguments
  agent: agent-id              # Custom Copilot agent file
  api-target: api.acme.ghe.com  # Enterprise API endpoint
  env:
    DEBUG_MODE: "true"
```

Copilot is the default -- `engine:` can be omitted. Each engine interprets the markdown body and executes using configured tools and permissions.

For the orchestrator, engine-agnostic design means workflows work with any engine. The APM target is auto-inferred from `engine:` (`copilot`, `claude`, or `all` for other engines).

---

## 2. APM Native Integration

Source: `apm/docs/src/content/docs/integrations/gh-aw.md` and `gh-aw/docs/src/content/docs/reference/dependencies.md`

### 2.1 Frontmatter `dependencies:` Field -- Simple Array Format

```yaml
dependencies:
  - microsoft/apm-sample-package
  - github/awesome-copilot/skills/review-and-refactor
  - microsoft/apm-sample-package#v2.0   # version-pinned
```

Each entry is an APM package reference: `owner/repo` for a full package, `owner/repo/path/to/primitive` for an individual primitive, or `owner/repo#ref` for version pinning.

### 2.2 Object Format with Options

```yaml
dependencies:
  packages:
    - microsoft/apm-sample-package
    - your-org/security-compliance
  isolated: true   # clear repo primitives before unpack
```

The `isolated` flag controls whether existing `.github/` primitive directories are cleared before the bundle is unpacked.

### 2.3 How It Works

Source: `apm/docs/src/content/docs/integrations/gh-aw.md` (lines 67-73)

1. The gh-aw compiler detects the `dependencies:` field in workflow frontmatter
2. In the **activation job**, APM resolves the full dependency tree and runs `apm pack` to produce a self-contained bundle
3. In the **agent job**, the bundle is unpacked into the workspace via `apm unpack` and the agent discovers the primitives

APM lock files (`apm.lock`) pin every package to an exact commit SHA for reproducibility. Lock file diffs appear in pull requests and are reviewable.

### 2.4 Target Auto-Inference from `engine:` Field

Source: `gh-aw/docs/src/content/docs/reference/dependencies.md` (line ~69)

The APM compilation target is automatically inferred from the configured engine:
- `copilot` -> copilot target
- `claude` -> claude target
- Other engines -> `all` target

No manual target configuration is needed.

### 2.5 `apm-action` Pre-Step Alternative

Source: `apm/docs/src/content/docs/integrations/gh-aw.md` (lines 75-107)

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

**When to use this over frontmatter dependencies:**
- Custom compilation options (specific targets, flags)
- Running additional APM commands (audit, preview)
- Workflows that need `apm.yml`-based configuration
- Debugging dependency resolution

### 2.6 APM Bundles for Sandboxed Environments

Source: `apm/docs/src/content/docs/integrations/gh-aw.md` (lines 109-131)

For sandboxed environments where network access is restricted:
1. Run `apm pack` in CI to produce a self-contained bundle
2. Distribute as workflow artifact or commit to repository
3. Reference bundled primitives in workflow via `imports:`

Bundles resolve full dependency trees ahead of time -- **zero network access at runtime**.

### 2.7 Isolated Mode

Source: `apm/docs/src/content/docs/integrations/gh-aw.md` (lines 136-147)

When `isolated: true` is set in the object format:

```yaml
dependencies:
  packages:
    - your-org/triage-rules
  isolated: true
```

gh-aw clears existing `.github/` primitive directories (instructions, skills, agents) **before** unpacking the APM bundle. The agent sees **only** the context declared by the workflow, preventing instruction pollution from the host repository's developer-focused instructions.

This is critical for the orchestrator: automated agents should follow only their declared dependencies, not repository-level "use 4-space tabs" instructions.

### 2.8 Content Scanning

APM scans for hidden Unicode during install. This is part of the security model that prevents supply chain attacks through invisible characters in agent primitives.

---

## 3. Orchestrator Runtime Patterns

### 3.1 Scheduled Workflow for Orchestrator State Machine Loop

A scheduled workflow can drive the orchestrator's recurring evaluation loop -- checking project state, advancing phases, and dispatching work:

```yaml
---
on:
  schedule: daily around 9:00
  workflow_dispatch:
permissions:
  contents: read
  actions: read
engine: copilot

dependencies:
  packages:
    - clariti/speckit-orchestrator
  isolated: true

tools:
  github:
    toolsets: [default, issues, projects]
    github-token: ${{ secrets.GH_AW_READ_PROJECT_TOKEN }}
  cache-memory:

safe-outputs:
  create-issue:
    title-prefix: "[orchestrator] "
    labels: [orchestrator, phase-task]
    max: 10
    group: true
  add-comment:
    max: 5
  update-project:
    github-token: ${{ secrets.GH_AW_WRITE_PROJECT_TOKEN }}
    project: https://github.com/orgs/clariti/projects/1
    max: 5
  dispatch-workflow:
    workflows: [phase-research, phase-spec, phase-implement, phase-validate]
    max: 4
---

# Orchestrator State Machine

Evaluate the current state of the milestone tracked in the project board.

1. Read the orchestrator state from cache-memory
2. Check the project board for current phase and task status
3. Determine if the current phase is complete (all tasks done)
4. If complete, advance to the next phase and create new phase tasks
5. Dispatch the appropriate phase worker workflow
6. Update the project board with new status
7. Post a status comment on the tracking issue
```

Key patterns demonstrated:
- `schedule: daily around 9:00` for recurring evaluation
- `cache-memory:` for persistent state across runs
- `dispatch-workflow` to fan out to phase-specific workers
- `group: true` on `create-issue` for sub-issue hierarchies
- `isolated: true` on dependencies for clean orchestration context
- `update-project` for board synchronization

Source: Patterns derived from `gh-aw/docs/src/content/docs/patterns/orchestration.md`, `gh-aw/docs/src/content/docs/patterns/daily-ops.md`, `gh-aw/docs/src/content/docs/patterns/project-ops.mdx`

### 3.2 Issue-Triggered Workflow for Milestone Planning and Execution

An issue-triggered workflow responds when a milestone planning issue is created:

```yaml
---
on:
  issues:
    types: [opened, labeled]
    names: [orchestrate]
    lock-for-agent: true
permissions:
  contents: read
  actions: read

engine: copilot

dependencies:
  packages:
    - clariti/speckit-orchestrator
  isolated: true

tools:
  github:
    toolsets: [default, issues, pull_requests]
  edit:
  bash: ["gh issue list", "gh project item-list"]

safe-outputs:
  create-issue:
    title-prefix: "[milestone] "
    labels: [milestone, orchestrator]
    max: 20
    group: true
  add-comment:
    max: 3
  add-labels:
    allowed: [phase-research, phase-spec, phase-implement, phase-validate, blocked, in-progress, done]
    max: 5
---

# Milestone Planner

A new milestone has been requested via issue labeling.

Issue context: "${{ needs.activation.outputs.text }}"

## Your Task

1. Analyze the milestone request in the issue
2. Break it down into phases: Research -> Specification -> Implementation -> Validation
3. For each phase, create sub-issues with clear acceptance criteria
4. Group all sub-issues under a parent tracking issue
5. Label each sub-issue with its phase
6. Post a summary comment on the original issue with the plan
```

Key patterns:
- `names: [orchestrate]` triggers only when the `orchestrate` label is applied
- `lock-for-agent: true` prevents concurrent modifications during execution
- `group: true` on `create-issue` creates parent/sub-issue hierarchies
- `add-labels` with `allowed:` restricts to orchestrator-managed labels

### 3.3 Comment Commands for Individual Phase Triggers

Comment commands let team members control the orchestrator interactively:

```yaml
---
on:
  slash_command:
    name: ["orchestrate", "plan-phase", "advance-phase", "check-status"]
    events: [issue_comment]
  reaction: "rocket"
permissions:
  contents: read
  actions: read

engine: copilot

dependencies:
  packages:
    - clariti/speckit-orchestrator
  isolated: true

tools:
  github:
    toolsets: [default, issues]
  cache-memory:

safe-outputs:
  add-comment:
    max: 3
  add-labels:
    allowed: [phase-research, phase-spec, phase-implement, phase-validate, blocked, in-progress, done]
    max: 3
  dispatch-workflow:
    workflows: [orchestrator-loop]
    max: 1
---

# Orchestrator Command Handler

You were invoked by: /${{ needs.activation.outputs.slash_command }}

Context: "${{ needs.activation.outputs.text }}"

## Commands

- **/orchestrate** -- Start orchestration for this milestone. Analyze the issue, create a plan, and begin execution.
- **/plan-phase** -- Create detailed task breakdown for the current phase.
- **/advance-phase** -- Mark current phase as complete and advance to the next one.
- **/check-status** -- Report current orchestration status, phase progress, and blockers.

Execute the appropriate command based on the slash command used.
```

Key patterns:
- Multiple command names in a single workflow
- `needs.activation.outputs.slash_command` to determine which command was used
- `dispatch-workflow` to trigger the main orchestrator loop
- `reaction: "rocket"` for immediate visual feedback

Source: `gh-aw/docs/src/content/docs/reference/command-triggers.md` (multi-command support), `gh-aw/docs/src/content/docs/patterns/chat-ops.md`

### 3.4 Safe Outputs for Orchestrator Write Operations

The orchestrator needs these write operations, all handled via safe outputs:

**PR Creation for code/spec changes:**
```yaml
safe-outputs:
  create-pull-request:
    title-prefix: "[orchestrator] "
    labels: [orchestrator, automated]
    draft: true
    reviewers: [team-lead]
    max: 3
```

**Status comments on tracking issues:**
```yaml
safe-outputs:
  add-comment:
    max: 5
    target: "triggering"  # Comment on the triggering issue
```

**Label management for phase tracking:**
```yaml
safe-outputs:
  add-labels:
    allowed: [phase-research, phase-spec, phase-implement, phase-validate, blocked, in-progress, done]
    max: 5
  remove-labels:
    allowed: [in-progress, blocked]
    max: 3
```

**Project board updates:**
```yaml
safe-outputs:
  update-project:
    github-token: ${{ secrets.GH_AW_WRITE_PROJECT_TOKEN }}
    project: https://github.com/orgs/clariti/projects/1
    max: 10
```

**Worker dispatch:**
```yaml
safe-outputs:
  dispatch-workflow:
    workflows: [phase-research, phase-spec, phase-implement, phase-validate]
    max: 4
  call-workflow:
    workflows: [validate-spec]
    max: 1
```

Source: `gh-aw/docs/src/content/docs/patterns/orchestration.md`

The distinction between `dispatch-workflow` and `call-workflow`:
- `dispatch-workflow`: Workers run asynchronously as independent workflow runs, can outlive the parent
- `call-workflow`: Workers run as part of the same workflow run, preserving actor attribution, zero API overhead

### 3.5 Concrete Example Workflow Markdown Files

**Phase Worker: Research Phase**

```yaml
---
on:
  workflow_dispatch:
    inputs:
      milestone_issue:
        description: 'Milestone tracking issue number'
        required: true
        type: string
      research_scope:
        description: 'What to research'
        required: true
        type: string
permissions:
  contents: read
engine: copilot

dependencies:
  packages:
    - clariti/speckit-orchestrator
  isolated: true

tools:
  github:
    toolsets: [default, issues, repos]
  web-search:
  web-fetch:
  cache-memory:

safe-outputs:
  create-discussion:
    title-prefix: "[research] "
    category: "ideas"
  add-comment:
    target: "${{ github.event.inputs.milestone_issue }}"
    max: 2
  add-labels:
    allowed: [research-complete]
    max: 1
---

# Research Phase Worker

Conduct research for milestone #${{ github.event.inputs.milestone_issue }}.

Scope: "${{ github.event.inputs.research_scope }}"

## Tasks

1. Search the codebase for existing patterns and implementations
2. Research best practices for the given scope
3. Create a discussion with research findings
4. Post a summary comment on the milestone issue
5. When research is complete, add the `research-complete` label
```

**Phase Worker: Specification Phase**

```yaml
---
on:
  workflow_dispatch:
    inputs:
      milestone_issue:
        description: 'Milestone tracking issue number'
        required: true
        type: string
permissions:
  contents: read
engine: copilot

dependencies:
  packages:
    - clariti/speckit-orchestrator
  isolated: true

tools:
  github:
    toolsets: [default, issues]
  edit:
  bash: ["git", "find", "cat"]

safe-outputs:
  create-pull-request:
    title-prefix: "[spec] "
    labels: [specification, orchestrator]
    draft: true
    max: 1
  add-comment:
    target: "${{ github.event.inputs.milestone_issue }}"
    max: 2
---

# Specification Phase Worker

Write specifications for milestone #${{ github.event.inputs.milestone_issue }}.

## Tasks

1. Read the research findings from linked discussions
2. Draft specifications following the project's spec format
3. Create a pull request with the specification documents
4. Post a summary comment on the milestone issue
```

---

## 4. Principles for Orchestrator Integration

### 4.1 gh-aw as Execution Runtime

gh-aw provides the execution substrate for the orchestrator. The speckit-orchestrator defines **what** to do (state machine logic, phase definitions, task templates); gh-aw defines **when** and **how** it runs:

- **Declarative workflow** -- Markdown frontmatter declares triggers, permissions, tools, safe-outputs
- **Compiled to Actions YAML** -- `gh aw compile` generates the `.lock.yml` with security hardening, SHA-pinned actions, job dependency graphs
- **Runtime loading** -- Markdown body (AI instructions) loaded at runtime, editable without recompilation
- **Five compilation phases** ensure safety: parsing/validation -> job construction -> dependency resolution -> action pinning -> YAML generation

The orchestrator does not need to understand GitHub Actions YAML. It works at the markdown abstraction level: write a `.md` file with frontmatter + natural language instructions, compile, and push.

### 4.2 Isolated Mode for Clean Orchestration Context

Source: `apm/docs/src/content/docs/integrations/gh-aw.md` (lines 136-147)

The `isolated: true` flag is essential for orchestrator workflows:

```yaml
dependencies:
  packages:
    - clariti/speckit-orchestrator
  isolated: true
```

Without isolation, the orchestrator agent would also consume any `.github/instructions/`, `.github/skills/`, and `.github/agents/` files from the host repository. These developer-focused instructions ("use 4-space tabs", "prefer functional style") become noise for an automated orchestrator that should follow only its declared dependencies.

With `isolated: true`, gh-aw clears existing `.github/` primitive directories **before** unpacking the APM bundle. The agent sees **only** the orchestrator's context.

### 4.3 Comment Commands as Orchestrator Triggers

Source: `gh-aw/docs/src/content/docs/reference/command-triggers.md`

Comment commands provide the human-in-the-loop interface for the orchestrator:

- `/orchestrate` -- Start a new orchestration cycle
- `/plan-phase` -- Create detailed task breakdown for current phase
- `/advance-phase` -- Mark phase complete and advance
- `/check-status` -- Report current state

Implementation via `slash_command:`:
```yaml
on:
  slash_command:
    name: ["orchestrate", "plan-phase", "advance-phase", "check-status"]
    events: [issue_comment]
```

Key design points:
- Command must be the **first word** of the comment to trigger (prevents accidental triggers)
- `needs.activation.outputs.slash_command` tells the agent which command was used
- `needs.activation.outputs.text` provides sanitized context
- Multiple command names in a single workflow avoids workflow duplication
- `events:` filtering restricts where commands are active

### 4.4 Safe Outputs for Orchestrator Write Operations

The orchestrator needs to:
1. **Create issues** (tasks, sub-tasks) -> `create-issue` with `group: true`
2. **Post status comments** -> `add-comment`
3. **Manage labels** (phase tracking) -> `add-labels` / `remove-labels` with `allowed:` lists
4. **Create PRs** (specifications, code) -> `create-pull-request` with `draft: true`
5. **Update project boards** -> `update-project`
6. **Dispatch worker workflows** -> `dispatch-workflow` or `call-workflow`
7. **Close completed items** -> `close-issue`

All of these operations use the safe-outputs security model: the agent runs read-only and declares intended operations; separate jobs with scoped permissions execute them. The `max:` field on each safe output type prevents runaway creation. The `allowed:` field on labels restricts to orchestrator-managed values.

For cross-repo orchestration (e.g., orchestrating work across `clariti-snf-be/` and `clariti-frontend/`), use `target-repo` on safe outputs with a `github-token` that has access to target repositories.

Source: `gh-aw/docs/src/content/docs/patterns/multi-repo-ops.md`

### 4.5 Multi-Engine Support -- Orchestrator Works with Any Engine

The orchestrator's workflow files are engine-agnostic by design:

```yaml
engine: copilot   # Default, works out of the box
engine: claude    # Alternative
engine: codex     # Alternative
engine: gemini    # Alternative
```

The APM target is auto-inferred from the `engine:` field, so dependencies are compiled for the correct agent context. The markdown instructions work with any engine -- they interpret the same natural language instructions.

This means:
- Organizations can choose their preferred engine
- Different orchestrator workflows can use different engines (e.g., Claude for specification writing, Copilot for code implementation)
- Engine can be swapped without changing the orchestrator logic
- Version pinning available: `engine: { id: claude, version: "2.1.70" }`

---

## Key Files Referenced

| Path | Description |
|------|-------------|
| `gh-aw/README.md` | Project overview and quick start |
| `gh-aw/create.md` | Agent prompt for creating workflows |
| `gh-aw/schemas/agent-output.json` | JSON Schema for all safe output types |
| `gh-aw/docs/src/content/docs/reference/frontmatter.md` | Complete frontmatter reference |
| `gh-aw/docs/src/content/docs/reference/compilation-process.md` | Compilation phases and job types |
| `gh-aw/docs/src/content/docs/reference/safe-outputs.md` | Safe output types and configuration |
| `gh-aw/docs/src/content/docs/reference/safe-outputs-pull-requests.md` | PR-specific safe outputs |
| `gh-aw/docs/src/content/docs/reference/safe-outputs-specification.md` | W3C-style formal specification |
| `gh-aw/docs/src/content/docs/reference/engines.md` | AI engine configuration |
| `gh-aw/docs/src/content/docs/reference/triggers.md` | All trigger types |
| `gh-aw/docs/src/content/docs/reference/command-triggers.md` | Slash command triggers |
| `gh-aw/docs/src/content/docs/reference/tools.md` | Tool configuration |
| `gh-aw/docs/src/content/docs/reference/dependencies.md` | APM dependencies reference |
| `gh-aw/docs/src/content/docs/reference/imports.md` | Import system and merge semantics |
| `gh-aw/docs/src/content/docs/reference/workflow-structure.md` | File organization |
| `gh-aw/docs/src/content/docs/reference/sandbox.md` | Sandbox configuration |
| `gh-aw/docs/src/content/docs/reference/custom-safe-outputs.md` | Custom safe output jobs |
| `gh-aw/docs/src/content/docs/introduction/architecture.mdx` | Security architecture |
| `gh-aw/docs/src/content/docs/introduction/how-they-work.mdx` | Concepts overview |
| `gh-aw/docs/src/content/docs/patterns/orchestration.md` | Orchestrator/worker pattern |
| `gh-aw/docs/src/content/docs/patterns/chat-ops.md` | ChatOps pattern |
| `gh-aw/docs/src/content/docs/patterns/daily-ops.md` | DailyOps pattern |
| `gh-aw/docs/src/content/docs/patterns/issue-ops.md` | IssueOps pattern |
| `gh-aw/docs/src/content/docs/patterns/project-ops.mdx` | ProjectOps pattern |
| `gh-aw/docs/src/content/docs/patterns/multi-repo-ops.md` | MultiRepoOps pattern |
| `gh-aw/docs/src/content/docs/patterns/spec-ops.md` | SpecOps pattern |
| `gh-aw/docs/src/content/docs/patterns/dispatch-ops.md` | DispatchOps pattern |
| `gh-aw/docs/src/content/docs/examples/scheduled.md` | Scheduled workflow examples |
| `gh-aw/docs/src/content/docs/examples/comment-triggered.md` | Comment-triggered examples |
| `apm/docs/src/content/docs/integrations/gh-aw.md` | APM + gh-aw integration guide |
