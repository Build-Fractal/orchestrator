# Research Prompt: Orchestrator Extension

## Mission

You are researching five open-source repositories (available as submodules in this monorepo) to produce a **detailed specification** for a new spec-kit extension called **`speckit-orchestrator`** (working name). This extension brings GSD-style autonomous orchestration, context-engineered subagent dispatch, and multi-phase execution into spec-kit's spec-driven development workflow, using APM for package/dependency management and GitHub Agentic Workflows as an optional execution runtime.

The goal: **a meta-prompting, context engineering, and spec-driven development system that enables agents to work for long periods autonomously without losing track of the big picture.**

---

## Submodule Setup

Before dispatching research subagents, ensure all required submodules are initialized:

```bash
git submodule update --init --recursive spec-kit gsd-2 apm superpowers gh-aw
```

### Submodule Reference Table

| Submodule | Local Path | Remote | Status |
|-----------|-----------|--------|--------|
| spec-kit | `./spec-kit/` | `github/spec-kit` | Required |
| gsd-2 | `./gsd-2/` | `gsd-build/gsd-2` | Required |
| apm | `./apm/` | `microsoft/apm` | Required |
| superpowers | `./superpowers/` | `obra/superpowers` | Required |
| gh-aw | `./gh-aw/` | `github/gh-aw` | Required |

---

## Context: What We're Building and Why

### The Problem

Spec-kit is excellent at the planning layer: constitution -> specify -> plan -> tasks -> implement. But when a project is bigger than what fits in one context window or one milestone, users hit a wall. They have to manually break work into pieces, manually manage fresh contexts for each piece, manually track what's done vs. what's next, and manually reassemble results. There is no orchestration layer.

GSD-2 solves orchestration brilliantly -- fresh sessions per unit, state-machine-driven auto mode, crash recovery, cost tracking, adaptive replanning -- but it's a standalone CLI built on the Pi SDK. It doesn't integrate with spec-kit's planning model or its extension system.

### The Vision

Take spec-kit's planning philosophy (constitution -> specify -> plan -> tasks) and layer GSD's orchestration principles on top of it, delivered as a **spec-kit extension** that:

1. **Adds a hierarchy above tasks**: Spec-kit currently has `specify -> plan -> tasks -> implement`. We add **milestones** (shippable versions) containing **phases/slices** (demoable capabilities) containing **tasks** (context-window-sized units). This maps to GSD's Milestone -> Slice -> Task hierarchy.

2. **Orchestrates autonomous execution**: A state machine reads disk state, determines the next unit of work, dispatches it to a fresh agent context with pre-loaded relevant context, and advances when done. This is the core GSD auto-mode loop adapted for spec-kit.

3. **Uses APM for dependency/package management**: The extension's agent instructions, skills, prompts, and any dependent packages are declared in `apm.yml` and compiled via `apm compile` to the appropriate agent format (AGENTS.md, CLAUDE.md, .cursor/rules/).

4. **Can use GitHub Agentic Workflows as execution runtime**: For CI/scheduled/event-triggered orchestration, the extension can emit GitHub Agentic Workflow markdown files that run the spec-kit orchestration loop in GitHub Actions with proper guardrails.

5. **Borrows subagent-driven-development patterns from Superpowers**: Fresh subagent per task, two-stage review (spec compliance then code quality), plan-driven dispatch with isolated context.

6. **Continuously generates and maintains agent-searchable context**: Every phase of work produces structured, discoverable documentation -- patterns, decisions, business logic, data structures, API contracts, lessons learned. This accumulated knowledge becomes a searchable hierarchy that future agents can query to bootstrap context quickly. The better the knowledgebase, the less context each individual task needs to consume.

---

## Core Philosophical Principles

These principles are non-negotiable and must be deeply embedded in the extension's design.

### From Superpowers: Discipline Over Convenience

Superpowers enforces a philosophy where **skills are mandatory, not optional**. When a relevant skill exists, the agent MUST use it. This prevents the "I'll just quickly..." anti-pattern that leads to context rot and sloppy work.

Key principles to adopt:
- **Evidence before claims** ("verification-before-completion"): No completion claims without fresh verification evidence. "Should work" is not evidence. Run the command, read the output, THEN claim the result.
- **Design before code** ("brainstorming"): Every piece of work goes through a design step, no matter how "simple" it seems. Simple projects are where unexamined assumptions cause the most wasted work.
- **Plans assume zero context** ("writing-plans"): Implementation plans must be written as if the executing agent has zero codebase context and questionable taste. Document everything: exact file paths, complete code, exact commands with expected output, verification steps.
- **Fresh subagent per task** ("subagent-driven-development"): Subagents never inherit the orchestrator's session context. The orchestrator constructs exactly what each subagent needs. This preserves the orchestrator's context for coordination work.
- **Two-stage review**: After each task, spec compliance review first (did we build what was specified?), then code quality review (is it built well?). Never skip reviews, never accept "close enough."
- **YAGNI ruthlessly**: Remove unnecessary features from all designs. Complexity is the enemy of autonomous execution.
- **Design for isolation and clarity**: Break systems into smaller units with one clear purpose, well-defined interfaces, testable independently. If someone can't understand what a unit does without reading its internals, the boundaries need work.

### From APM Compilation: The Context Pollution Problem

APM's compilation guide identifies a fundamental mathematical problem: **context pollution degrades AI agent performance quadratically as projects grow**. The solution is hierarchical, proximity-based context delivery.

```
Context_Efficiency = Relevant_Instructions / Total_Instructions_Inherited
```

Key principles to adopt:
- **Hierarchical context files**: Instead of one monolithic context document, distribute context across a directory hierarchy. Agents discover context by walking from their current working directory up to the project root. Closest context takes precedence.
- **Proximity priority**: Context relevant to a specific subsystem lives near that subsystem, not in a global file. This is the AGENTS.md standard: recursive discovery with inheritance.
- **Minimal pollution**: Every instruction placed in a directory pollutes the context of every file in that directory. The optimization goal is: complete coverage of relevant context with minimal inclusion of irrelevant context.
- **Distributed placement**: APM uses a three-tier algorithm (single-point, selective-multi, distributed) based on how broadly an instruction applies. We should generate our orchestrator's knowledge artifacts with the same awareness -- narrow knowledge lives deep in the hierarchy, broad knowledge lives at the root.

### The Context Minimization Principle

**Every architectural decision in the orchestrator must optimize for minimizing the context each individual task consumes.** This is the unifying principle that ties everything together:

- **Why hierarchical knowledge?** So a task working on `src/auth/` inherits only auth-relevant context, not the entire project's documentation.
- **Why fresh sessions per task?** So no task inherits accumulated garbage from previous tasks.
- **Why structured summaries after each task?** So the next task gets a compressed summary, not a raw transcript.
- **Why a decisions register?** So architectural decisions are recorded once and referenced by path, not re-explained in every task prompt.
- **Why continuous documentation generation?** So future agents can bootstrap from documentation rather than re-reading source code.

The orchestrator should continuously produce and maintain:
- **Pattern documentation**: How things are built in this project (conventions, idioms, architectural patterns)
- **Business logic documentation**: What the system does and why (domain rules, edge cases, constraints)
- **Data structure documentation**: What data exists, how it flows, what the schemas are
- **API/interface documentation**: How components talk to each other
- **Decision records**: Why things were built a certain way (ADR-style)
- **Lessons learned**: What went wrong, what was discovered, what to avoid next time (GSD's KNOWLEDGE.md pattern)

This hierarchy of agent-searchable context is the orchestrator's most valuable output -- more valuable than the code itself, because it compounds. Every task that generates good documentation makes every future task cheaper.

---

## The Five Repositories to Research

All five repositories are available as submodules in the current working directory. Subagents have full access to source code, docs, tests, and examples. **Read the actual source files, not just READMEs.** Search through implementation code, test fixtures, config files, prompt templates, and internal docs. Web search should supplement local research, not replace it.

---

### SUBAGENT 1: spec-kit (`./spec-kit/`)

**Submodule:** `spec-kit` | **Remote:** `github/spec-kit`

**Research objectives:**

1. **Extension system architecture** -- Read these files thoroughly:
   - `extensions/RFC-EXTENSION-SYSTEM.md` (the full RFC)
   - `extensions/EXTENSION-DEVELOPMENT-GUIDE.md`
   - `extensions/EXTENSION-API-REFERENCE.md`
   - `extensions/EXTENSION-USER-GUIDE.md`
   - `extensions/EXTENSION-PUBLISHING-GUIDE.md`
   - `src/specify_cli/extensions.py` (the implementation)
   - `extensions/selftest/` (example extension)
   - `extensions/template/` (extension template)

   Document: extension.yml manifest schema, command registration across agents, hook system (available hook points and how they fire), config management, catalog system, CLI commands.

2. **Core development phases and commands** -- Read:
   - `templates/commands/specify.md`
   - `templates/commands/plan.md`
   - `templates/commands/tasks.md`
   - `templates/commands/implement.md`
   - `templates/commands/clarify.md`
   - `templates/commands/analyze.md`
   - `templates/commands/checklist.md`
   - `templates/commands/constitution.md`
   - `templates/commands/taskstoissues.md`
   - `spec-driven.md` (the comprehensive guide, if it exists)

   Document: What each phase does. What artifacts it produces. What it reads. How tasks.md structures task output. How implement.md executes. What hooks fire after each phase.

3. **Template system** -- Read:
   - `templates/plan-template.md`
   - `templates/spec-template.md` (in presets)
   - `templates/tasks-template.md` (in presets)
   - `templates/constitution-template.md`
   - `templates/agent-file-template.md`

   Document: How templates are resolved, how presets override them, what template variables are available.

4. **Memory and state** -- Read:
   - Any files in `.specify/memory/`
   - How the session memory system works
   - What state persists between commands

5. **Presets system** -- Read:
   - `presets/README.md`
   - `presets/ARCHITECTURE.md`
   - `presets/catalog.json`

   Document: How presets work, how they override core behavior, relationship to extensions.

**Output format for this subagent:**

```markdown
# Spec-Kit Research Report

## 1. Extension System
### 1.1 Manifest Schema (extension.yml)
### 1.2 Command Registration (per-agent)
### 1.3 Hook System (hook points, execution model)
### 1.4 Config Management (layered resolution)
### 1.5 Extension Lifecycle (install, update, remove)
### 1.6 Constraints and Limitations

## 2. Core Development Phases
### 2.1 Phase Flow (constitution -> specify -> plan -> tasks -> implement)
### 2.2 Per-Phase: Inputs, Outputs, Artifacts, Hooks
### 2.3 Task Structure (how tasks.md formats tasks)
### 2.4 Implementation Execution (how implement.md works)

## 3. Template System
### 3.1 Template Resolution Order
### 3.2 Available Variables
### 3.3 Preset Override Mechanism

## 4. State and Memory
### 4.1 Session Memory
### 4.2 Cross-Command State
### 4.3 File-Based Artifacts (.specify/ directory structure)

## 5. Integration Points for Orchestrator Extension
### 5.1 Where milestones/phases could hook in
### 5.2 What hooks are available post-tasks, post-implement
### 5.3 How an extension could add new commands (e.g., speckit.orchestrator.plan-milestone)
### 5.4 How an extension could add new templates
### 5.5 Gaps: What spec-kit doesn't provide that the orchestrator needs
```

---

### SUBAGENT 2: GSD-2 (`./gsd-2/`)

**Submodule:** `gsd-2` | **Remote:** `gsd-build/gsd-2`

**Research objectives:**

1. **Work hierarchy and state machine** -- Read:
   - `src/resources/GSD-WORKFLOW.md` (manual bootstrap protocol)
   - `docs/architecture.md`
   - `docs/auto-mode.md`
   - `docs/getting-started.md`
   - The `.gsd/` directory structure specification from GSD-WORKFLOW.md

   Document: The Milestone -> Slice -> Task hierarchy. File naming conventions. STATE.md format. ROADMAP.md format. PLAN.md format. SUMMARY.md format. DECISIONS.md. How state is derived from disk.

2. **Auto-mode dispatch pipeline** -- Read:
   - `docs/auto-mode.md`
   - `docs/architecture.md` (dispatch pipeline section)
   - `docs/token-optimization.md`

   Document: The full dispatch loop (read state -> determine unit -> classify complexity -> build prompt -> create session -> execute -> verify -> persist -> loop). How context is pre-loaded into each dispatch. How fresh sessions prevent context rot. The token profile system.

3. **Orchestration and parallel execution** -- Read:
   - `docs/parallel-orchestration.md`
   - `docs/git-strategy.md`

   Document: Coordinator/worker architecture. Worktree isolation. Signal-based IPC. Eligibility analysis. How parallel milestones are tracked and merged.

4. **Crash recovery, stuck detection, verification** -- Read:
   - `docs/auto-mode.md` (crash recovery, stuck detection, timeout sections)
   - `docs/troubleshooting.md`
   - `docs/cost-management.md`

   Document: Lock file mechanism. Session forensics. Recovery briefing synthesis. Stuck detection (dispatch-twice rule). Timeout tiers. Verification enforcement. Cost tracking per unit.

5. **Adaptive replanning and knowledge persistence** -- Read:
   - `docs/auto-mode.md` (adaptive replanning, incremental memory sections)
   - Any KNOWLEDGE.md references

   Document: How roadmap reassessment works after each slice. How KNOWLEDGE.md accumulates cross-session wisdom. How the decisions register works.

6. **Extension and skills system** -- Read:
   - `docs/skills.md`
   - `src/resources/extensions/` directory listing
   - `src/resources/agents/` directory listing

   Document: How GSD's built-in extensions work (Browser Tools, Subagent, Search, etc.). How skills are discovered and loaded. The scout/researcher/worker agent roles.

**Output format for this subagent:**

```markdown
# GSD-2 Research Report

## 1. Work Hierarchy
### 1.1 Milestone -> Slice -> Task model
### 1.2 File structure (.gsd/ directory)
### 1.3 State derivation (STATE.md)
### 1.4 Roadmap format and parsing
### 1.5 Plan format (slice plans, task plans)
### 1.6 Summary format and frontmatter

## 2. Auto-Mode Dispatch Pipeline
### 2.1 The full loop (13-step pipeline)
### 2.2 Context pre-loading (what gets inlined)
### 2.3 Fresh session per unit (how and why)
### 2.4 Token profiles and context compression
### 2.5 Complexity classification and model routing

## 3. Orchestration
### 3.1 Sequential execution (single-worker auto mode)
### 3.2 Parallel execution (multi-worker coordinator)
### 3.3 Git isolation (worktree, branch, none modes)
### 3.4 Inter-process communication (file-based IPC)

## 4. Reliability
### 4.1 Crash recovery (lock files, session forensics)
### 4.2 Stuck detection and retry
### 4.3 Timeout supervision (soft/idle/hard)
### 4.4 Provider error handling
### 4.5 Verification enforcement
### 4.6 Milestone validation gate

## 5. Adaptive Intelligence
### 5.1 Roadmap reassessment after each slice
### 5.2 KNOWLEDGE.md cross-session memory
### 5.3 DECISIONS.md register
### 5.4 Context pressure monitor

## 6. Principles to Port to Spec-Kit Extension
### 6.1 "Iron rule" -- task must fit one context window
### 6.2 State machine driven by files on disk
### 6.3 Fresh context per unit with pre-loaded artifacts
### 6.4 Crash recovery via lock + forensics
### 6.5 Adaptive replanning as a first-class phase
### 6.6 Cost tracking and budget enforcement
### 6.7 Verification as a mechanical gate, not LLM compliance
```

---

### SUBAGENT 3: APM (`./apm/`)

**Submodule:** `apm` | **Remote:** `microsoft/apm`

**CRITICAL CONTEXT**: APM has two distinct operations that must not be conflated:
- `apm install` -- Deploys primitives (prompts, agents, skills, hooks, instructions) directly into IDE-native directories (`.github/`, `.claude/`, `.cursor/`, `.opencode/`). This is the primary integration mechanism. Most agents read these natively -- no compilation needed.
- `apm compile` -- **Optional.** Only generates instruction-only files (`AGENTS.md`, `CLAUDE.md`). Needed only for tools that don't read per-file primitives (Codex, Gemini, OpenCode instructions). Does NOT produce prompts, agents, commands, or skills -- those come from `apm install`.

APM already has a defined integration pattern with spec-kit: when using `apm compile`, APM injects the spec-kit `constitution.md` into compiled instruction files automatically.

**Research objectives:**

1. **Package manifest and dependency model** -- Read:
   - `docs/src/content/docs/reference/manifest-schema.md`
   - `docs/src/content/docs/guides/dependencies.md`
   - `docs/src/content/docs/reference/primitive-types.md`
   - `docs/src/content/docs/introduction/key-concepts.md`
   - `README.md`
   - `MANIFESTO.md`

   Document: The `apm.yml` manifest format. Dependency declaration syntax (GitHub shorthand, FQDN, object format with git/path/ref). What types of primitives can be declared: instructions (`.instructions.md`), skills (`SKILL.md`), prompts (`.prompt.md`), agents (`.agent.md`), hooks (`.json`), MCP servers. Transitive dependency resolution. Lockfile (`apm.lock.yaml`) and `deployed_files` tracking. Virtual file packages (single-file installs).

2. **Install-time integration (the primary mechanism)** -- Read:
   - `docs/src/content/docs/integrations/ide-tool-integration.md` (CRITICAL DOC)
   - `src/apm_cli/compilation/injector.py`

   Document the per-target deployment that `apm install` performs:
   - **VS Code/Copilot**: `.github/prompts/*.prompt.md`, `.github/agents/*.agent.md`, `.github/instructions/*.instructions.md`, `.github/skills/{name}/SKILL.md`, `.github/hooks/*.json`
   - **Claude**: `.claude/agents/*.md` (sub-agents), `.claude/commands/*.md` (slash commands from .prompt.md), `.claude/skills/{name}/SKILL.md`, hooks merged into `.claude/settings.json`
   - **Cursor**: `.cursor/rules/*.mdc` (instructions converted), `.cursor/agents/*.md`, `.cursor/skills/{name}/SKILL.md`, `.cursor/mcp.json`
   - **OpenCode**: `.opencode/agents/*.md`, `.opencode/commands/*.md`, `.opencode/skills/{name}/SKILL.md`

   Document: Auto-detection (`.github/` or `.claude/` folder triggers integration). Collision detection. Link resolution. Cleanup/sync on uninstall. Intent-first discovery (original filenames preserved).

3. **Compilation system (optional, instructions only)** -- Read:
   - `docs/src/content/docs/guides/compilation.md`
   - `src/apm_cli/compilation/agents_compiler.py`
   - `src/apm_cli/compilation/claude_formatter.py`
   - `src/apm_cli/compilation/distributed_compiler.py`
   - `src/apm_cli/compilation/context_optimizer.py`
   - `src/apm_cli/compilation/constitution.py`

   Document: Target auto-detection (copilot, claude, all, minimal). The distributed compilation model (per-directory AGENTS.md files vs. single monolithic). The context pollution optimization problem and three-tier placement algorithm. Constitution injection (spec-kit constitution.md automatically included). What `apm compile` does NOT do (it does not produce prompts, agents, commands, skills -- those come from `apm install`).

4. **APM + spec-kit integration** -- Read:
   - `docs/src/content/docs/integrations/ide-tool-integration.md` (the "APM + Spec-kit Integration" section)

   Document: How APM provides the "context foundation" while spec-kit provides the "specification layer". Constitution injection during compilation. The integrated workflow: `apm init && apm install` -> optional `apm compile` -> agent has both SDD rules and team context.

5. **APM + GitHub Agentic Workflows integration** -- Read:
   - `docs/src/content/docs/integrations/gh-aw.md` (CRITICAL DOC for APM+gh-aw integration)
   - Cross-reference with the `gh-aw` submodule at `./gh-aw/` for implementation details

   Document: The frontmatter `dependencies:` field (gh-aw natively recognizes APM packages). Simple array format vs. object format with `isolated: true`. How it works: gh-aw compiler detects dependencies -> activation job resolves via APM and packs -> agent job unpacks bundle. Target auto-inferred from `engine:` field. The `apm-action` pre-step alternative for more control. APM bundles for sandboxed environments (pre-built via `apm pack`, zero network at runtime). Isolated mode (clears existing `.github/` primitives so agent sees only declared deps). Content scanning.

6. **MCP server management** -- Read:
   - `docs/src/content/docs/integrations/ide-tool-integration.md` (MCP section)
   - `docs/src/content/docs/guides/plugins.md`

   Document: MCP dependency declaration in `apm.yml`. Registry vs. self-defined servers. Trust model (direct deps auto-trusted, transitive self-defined skipped). Per-client config generation (`.vscode/mcp.json`, `~/.copilot/mcp-config.json`, etc.). Package type inference.

7. **CLI commands and security** -- Read:
   - `docs/src/content/docs/reference/cli-commands.md`
   - `docs/src/content/docs/enterprise/security.md`

   Document: Key CLI commands (install, compile, pack, audit, deps, mcp). Content scanning (hidden Unicode detection). The pack/bundle workflow for CI.

**Output format for this subagent:**

```markdown
# APM Research Report

## 1. Package Model
### 1.1 apm.yml manifest format (full schema)
### 1.2 Primitive types (instructions, skills, prompts, agents, hooks, MCP)
### 1.3 Dependency declaration (shorthand, FQDN, object format)
### 1.4 Transitive resolution and lockfile
### 1.5 Virtual file packages

## 2. Install-Time Integration (Primary Mechanism)
### 2.1 Per-target deployment (VS Code, Claude, Cursor, OpenCode)
### 2.2 Auto-detection and collision handling
### 2.3 What `apm install` deploys vs. what `apm compile` generates
### 2.4 Cleanup, sync, and deployed_files tracking

## 3. Compilation (Optional, Instructions Only)
### 3.1 When compilation is needed vs. not needed
### 3.2 Target auto-detection and output files
### 3.3 Distributed compilation (per-directory AGENTS.md)
### 3.4 Context optimization algorithm
### 3.5 Constitution injection (spec-kit integration)

## 4. APM + Spec-Kit Integration
### 4.1 Context foundation (APM) + specification layer (spec-kit)
### 4.2 Constitution injection during compilation
### 4.3 Integrated workflow

## 5. APM + GitHub Agentic Workflows Integration
### 5.1 Frontmatter dependencies (gh-aw native support)
### 5.2 How the activation/agent job pipeline works
### 5.3 apm-action pre-step alternative
### 5.4 APM bundles for sandboxed environments
### 5.5 Isolated mode (clearing host repo primitives)

## 6. MCP Server Management
### 6.1 Declaration format and registry resolution
### 6.2 Trust model for transitive dependencies
### 6.3 Per-client configuration

## 7. Integration Points for Orchestrator Extension
### 7.1 How the orchestrator's skills/prompts/agents would be packaged
### 7.2 How `apm install` would deploy orchestrator commands to each IDE
### 7.3 How gh-aw workflows would declare orchestrator package as a dependency
### 7.4 How the orchestrator could leverage APM's constitution injection
### 7.5 How MCP servers (GitHub MCP, etc.) would be declared for orchestrator workflows
```

---

### SUBAGENT 4: Superpowers (`./superpowers/`)

**Submodule:** `superpowers` | **Remote:** `obra/superpowers`

**NOTE**: Superpowers is a CRITICAL philosophical influence on this project, not just a mechanical reference. Read every SKILL.md thoroughly. The principles embedded in these skills -- evidence before claims, design before code, fresh context per task, two-stage review, YAGNI, plans written for zero-context agents -- are foundational to the orchestrator's design.

**Research objectives:**

1. **Superpowers skill system and philosophy** -- Read EVERY skill file:
   - `skills/using-superpowers/SKILL.md` -- The meta-skill: how skills are discovered, why they're mandatory not optional, the priority system, the "red flags" for rationalization
   - `skills/brainstorming/SKILL.md` -- The design-before-code discipline: explore context -> ask questions one at a time -> propose approaches -> present design in sections -> write design doc -> spec review loop -> user gate -> transition to implementation. The HARD-GATE preventing implementation without design approval. The scope check for decomposing large projects.
   - `skills/writing-plans/SKILL.md` -- The plan format: plans assume zero context, bite-sized tasks (2-5 min each), exact file paths, complete code in plan, exact commands with expected output, TDD red-green steps. The plan review loop with subagent reviewer. The execution handoff.
   - `skills/subagent-driven-development/SKILL.md` -- Fresh subagent per task, two-stage review (spec compliance THEN code quality), implementer status handling (DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED), model selection by task complexity, prompt templates for each role.
   - `skills/executing-plans/SKILL.md` -- Fallback for environments without subagent support
   - `skills/dispatching-parallel-agents/SKILL.md` -- When to parallelize, domain isolation, prompt construction, result integration
   - `skills/verification-before-completion/SKILL.md` -- "Evidence before claims, always." The iron law of verification. Rationalization prevention. The gate function.
   - `skills/test-driven-development/SKILL.md` -- RED-GREEN-REFACTOR enforcement
   - `skills/systematic-debugging/SKILL.md` -- 4-phase root cause process
   - `skills/requesting-code-review/SKILL.md` -- Pre-review checklist
   - `skills/receiving-code-review/SKILL.md` -- Responding to feedback
   - `skills/using-git-worktrees/SKILL.md` -- Workspace isolation before any work
   - `skills/finishing-a-development-branch/SKILL.md` -- Verify tests, present options, clean up
   - `skills/writing-skills/SKILL.md` -- How to create new skills (meta-pattern for the orchestrator's own skill generation)

   Document: The full philosophy. How mandatory skill activation prevents corner-cutting. The brainstorm -> plan -> execute -> review -> finish pipeline. How each skill enforces discipline that an autonomous agent would otherwise skip. The anti-patterns each skill prevents.

2. **Subagent dispatch patterns** -- Deep dive on:
   - `skills/subagent-driven-development/SKILL.md` and its sibling prompt templates (implementer-prompt.md, spec-reviewer-prompt.md, code-quality-reviewer-prompt.md)
   - `skills/dispatching-parallel-agents/SKILL.md`
   - `tests/subagent-driven-dev/` (example plans and designs)
   - `agents/code-reviewer.md`

   Document: How subagents get isolated context -- the orchestrator constructs exactly what they need, they never inherit session history. How the orchestrating agent constructs prompts for each role. The two-stage review pattern (spec compliance catches over/under-building, code quality catches implementation issues). How results are integrated back. Model selection by complexity (cheap for mechanical tasks, capable for architecture). How to handle BLOCKED status.

3. **Plan structure and execution model** -- Read:
   - `tests/subagent-driven-dev/svelte-todo/plan.md` and `design.md`
   - `tests/subagent-driven-dev/go-fractals/plan.md` and `design.md`

   Document: Concrete plan format examples. The plan header (goal, architecture, tech stack). Task structure (files, steps with checkboxes, exact code, exact commands, expected output). How plans are self-contained documents that an agent with zero project context can execute.

4. **Hook system and session lifecycle** -- Read:
   - `hooks/hooks.json` and `hooks/session-start`
   - `.claude-plugin/plugin.json` and `.cursor-plugin/plugin.json`
   - `package.json`

   Document: How skills auto-activate via the session-start hook (injects using-superpowers content into every session). The plugin distribution model (Claude marketplace, Cursor marketplace, Gemini extensions). How this ensures every session starts with the right discipline.

**Output format for this subagent:**

```markdown
# Superpowers Research Report

## 1. Philosophy and Skill System
### 1.1 Core philosophy: mandatory discipline, evidence before claims, design before code
### 1.2 Skill structure and mandatory activation (using-superpowers meta-skill)
### 1.3 Anti-patterns and rationalization prevention
### 1.4 The brainstorm -> plan -> execute -> review -> finish pipeline
### 1.5 How each skill enforces discipline an autonomous agent would skip

## 2. Subagent Dispatch Patterns
### 2.1 Subagent-driven development model (fresh context per task)
### 2.2 Context isolation: orchestrator constructs exactly what subagent needs
### 2.3 Prompt construction for each role (implementer, spec reviewer, code quality reviewer)
### 2.4 Two-stage review (spec compliance THEN code quality)
### 2.5 Implementer status handling (DONE/CONCERNS/NEEDS_CONTEXT/BLOCKED)
### 2.6 Model selection by task complexity
### 2.7 Parallel vs. sequential dispatch

## 3. Plan Structure
### 3.1 Plan format (from concrete examples in tests/)
### 3.2 Plans assume zero context (exact paths, complete code, exact commands)
### 3.3 Task granularity (bite-sized, 2-5 min, TDD steps)
### 3.4 Plan review loop (subagent reviewer, max 3 iterations)
### 3.5 Design document -> plan -> execution handoff flow

## 4. Session Lifecycle and Hooks
### 4.1 Session-start hook (injects using-superpowers into every session)
### 4.2 Plugin distribution (Claude marketplace, Cursor, Gemini)
### 4.3 How this ensures every session starts with discipline
```

---

### SUBAGENT 5: GitHub Agentic Workflows (`./gh-aw/`)

**Submodule:** `gh-aw` | **Remote:** `github/gh-aw`

**Also reference:** APM integration docs at `./apm/docs/src/content/docs/integrations/gh-aw.md`

**Research objectives:**

1. **Workflow structure and lifecycle** -- Read the gh-aw submodule source:
   - `README.md`
   - `docs/` directory (all documentation files)
   - Example workflow markdown files (look in `examples/`, `tests/`, or root `*.md` files)
   - The compiler source or docs explaining `gh aw compile`

   Document: Markdown files with YAML frontmatter (triggers, engine, permissions, tools, safe outputs) + natural language body. Available triggers: issues, PRs, schedule, manual dispatch, comment commands (`/plan`, `/archie`, etc.). `gh aw compile` converts markdown -> GitHub Actions YAML lock file. Safe outputs: write operations (create PR, add label, post comment) require explicit declaration and approval. Security: sandboxed execution, tool allowlisting, network isolation, read-only by default. Multi-engine: `engine: copilot` | `engine: claude` | `engine: codex`.

2. **APM native integration** -- Read:
   - `./apm/docs/src/content/docs/integrations/gh-aw.md` (CRITICAL DOC)
   - Any gh-aw source/docs that reference APM, dependencies, or package resolution

   Document: gh-aw has a `dependencies:` frontmatter field that natively recognizes APM packages. Simple array format: `dependencies: [microsoft/apm-sample-package, org/repo/skills/review]`. Object format with options: `dependencies: { packages: [...], isolated: true }`. How it works: gh-aw compiler detects `dependencies:` -> activation job resolves full dep tree via APM and packs -> agent job unpacks bundle and discovers primitives. Target auto-inferred from `engine:` field -- no manual APM target config needed. `apm-action` pre-step alternative (`microsoft/apm-action@v1`) for more control (runs `apm install && apm compile` directly). APM bundles for sandboxed environments: pre-built via `apm pack`, zero network at runtime. **Isolated mode**: `isolated: true` clears existing `.github/` primitive directories before unpacking, so agent sees ONLY the context declared by the workflow -- prevents instruction pollution from host repo. Content scanning: APM scans for hidden Unicode during install, critical findings block deployment.

3. **Execution model for orchestration** -- Analyze:
   - How a scheduled workflow could run the orchestrator state machine loop
   - How an issue-triggered workflow could plan and execute a milestone
   - How orchestrator skills would be declared as APM `dependencies:` in frontmatter
   - How `isolated: true` ensures the orchestration agent runs with clean, focused context

   Document: The full authoring -> compile -> trigger -> execute -> output lifecycle. How this serves as an execution runtime for the orchestrator.

**Output format for this subagent:**

```markdown
# GitHub Agentic Workflows Research Report

## 1. Workflow Format and Lifecycle
### 1.1 Markdown structure (frontmatter + natural language body)
### 1.2 Trigger types (issues, PRs, schedule, manual, comment commands)
### 1.3 Compile process (gh aw compile -> .lock.yml)
### 1.4 Safe outputs and security model
### 1.5 Multi-engine support (copilot, claude, codex)

## 2. APM Native Integration
### 2.1 Frontmatter dependencies: field (array and object format)
### 2.2 Activation/agent job pipeline (resolve -> pack -> unpack)
### 2.3 Target auto-inference from engine: field
### 2.4 apm-action pre-step alternative
### 2.5 APM bundles for sandboxed execution
### 2.6 Isolated mode (clearing host repo context)
### 2.7 Content scanning and security

## 3. Orchestrator Runtime Patterns
### 3.1 Scheduled workflow for state machine loop
### 3.2 Issue-triggered workflow for milestone execution
### 3.3 Orchestrator skills as APM frontmatter dependencies
### 3.4 Clean context via isolated mode
### 3.5 Safe outputs for orchestrator write operations

## 4. Principles for Orchestrator Integration
### 4.1 gh-aw as execution runtime with APM frontmatter dependencies
### 4.2 Isolated mode for clean orchestration context
### 4.3 Comment commands as orchestrator triggers
### 4.4 Safe outputs for PR creation, status comments, label management
```

---

## Synthesis: What the Final Spec Must Cover

After all five subagent reports are complete, synthesize them into a specification for **`speckit-orchestrator`** covering:

### A. Extension Manifest and Structure

Define the `extension.yml`, commands provided, hooks registered, config files, and APM package declaration. The extension must be installable via `specify extension add orchestrator` and its agent dependencies resolvable via `apm install && apm compile`.

### B. Scope Triage: One Tool for Any Size Project

The orchestrator's first job on any request is to evaluate the scope and determine the appropriate execution tier. This makes the tool universal -- you use it for everything from a 20-minute bugfix to a 6-month platform rewrite, and it applies only as much process overhead as the work demands.

**The Triage Command: `speckit.orchestrator.evaluate`**

Before any planning or execution begins, the orchestrator evaluates the initial prompt/spec and classifies it into one of three tiers:

**Tier A -- Single Context Window ("One-Shot")**
- The entire scope -- spec, plan, tasks, implementation, verification -- fits comfortably within one healthy context window
- No orchestration overhead. The tool runs the standard spec-kit flow inline: constitution check -> specify -> plan -> tasks -> implement
- The orchestrator adds value by enforcing the Superpowers discipline (design before code, verification before claims) but does NOT impose milestone/phase/dispatch machinery
- Examples: small feature, bugfix, config change, refactor of a single module, adding a test suite for existing code
- Output: runs spec-kit commands in sequence within the current session, generates a single task summary when done

**Tier B -- Multiple Phases, One Context Window Each ("Phased")**
- The work is too large for a single context window but each logical phase (research, plan, implement per component) fits within one context window
- The orchestrator adds the roadmap layer (breaking spec into phases with dependencies and priority order) and manages phase-to-phase handoff (summaries, context bridging) but does NOT need the full subagent dispatch pipeline or parallel execution
- Each phase runs as a standard spec-kit flow with the orchestrator providing phase-scoped context at the start and collecting structured output at the end
- The user reviews each phase's plan before execution proceeds (like spec-kit's normal interactive flow, but scoped to one phase at a time)
- Examples: medium feature spanning 3-5 files, multi-component change, API + frontend + tests, a feature that needs research before implementation
- Output: phase-level roadmap, per-phase plans and summaries, single knowledge document at the end

**Tier C -- Full Orchestration ("Autonomous")**
- The work is larger than Tier B: multiple phases where individual phases themselves may need multiple context windows, or the work spans multiple milestones
- Full orchestration machinery activates: state machine, fresh context per unit, subagent dispatch, crash recovery, parallel execution, continuous knowledge generation, adaptive replanning
- This is where GSD's auto-mode patterns, Superpowers' subagent-driven development, and the full knowledge hierarchy apply
- Examples: new subsystem, platform migration, multi-milestone feature set, anything where you'd walk away and come back to built software
- Output: full milestone/phase/task hierarchy, continuous knowledge generation, AGENTS.md-compatible context hierarchy, structured summaries at every level

**Triage Criteria:**

The evaluator considers:
- **Token estimate**: How many tokens would the full spec -> plan -> tasks -> implement cycle consume? Compare against a healthy context window budget (e.g., 70% of model's context limit, leaving room for tool calls and responses)
- **Decomposability**: Can the work be broken into independent phases where each phase's plan + implementation fits one context window?
- **Dependency complexity**: How interconnected are the components? High coupling pushes toward Tier C because phases can't be planned independently
- **State accumulation**: How much context do later tasks need from earlier tasks? High accumulation pushes toward Tier C because context bridging becomes critical
- **Risk tolerance**: User can override the triage upward (e.g., force Tier C on a Tier B project for extra documentation and verification) but never downward beyond what's safe

**Tier transitions:**
- If Tier A execution discovers the scope was underestimated, the orchestrator pauses and re-triages (promoting to B or C). Work already done is preserved.
- If Tier B execution reveals a phase that doesn't fit one context window, that phase gets promoted to Tier C treatment (subagent dispatch for its tasks) while the rest stays at Tier B.
- Tiers can be mixed within a project: some phases are simple enough for inline execution, others need full dispatch.

### C. Terminology and Hierarchy

Establish the naming conventions. Proposed mapping:

| Concept | Spec-Kit Term | GSD Term | Orchestrator Term |
|---------|--------------|----------|-------------------|
| Governing principles | Constitution | -- | Constitution (inherited) |
| High-level description | Spec | -- | Spec (inherited) |
| Shippable version | -- | Milestone | Milestone |
| Demoable capability | -- | Slice | Phase |
| Implementation approach | Plan | -- | Plan (per-phase) |
| Atomic unit of work | Task | Task | Task |
| Context-window execution | Implement | Execute | Execute |

### D. Commands

Define each new command the extension provides:

- `speckit.orchestrator.evaluate` -- Scope triage: classify work as Tier A/B/C, determine execution strategy
- `speckit.orchestrator.milestone` -- Define/manage milestones from a spec
- `speckit.orchestrator.roadmap` -- Break a milestone into phases with dependencies
- `speckit.orchestrator.plan-phase` -- Run spec-kit's plan command scoped to one phase
- `speckit.orchestrator.dispatch` -- Execute one unit of work (research, plan, or task) in a fresh context
- `speckit.orchestrator.auto` -- State-machine-driven autonomous execution loop
- `speckit.orchestrator.status` -- Dashboard showing progress, costs, state
- `speckit.orchestrator.resume` -- Resume from crash/pause state
- `speckit.orchestrator.validate` -- Run milestone validation gate
- `speckit.orchestrator.consolidate` -- Run knowledge cleanup/compression on accumulated docs

### E. File Structure

Define the `.specify/orchestrator/` directory structure for state tracking, following GSD's file-on-disk state model adapted for spec-kit's conventions.

### F. Dispatch Model

Specify how the orchestrator constructs prompts for each unit type, what context is pre-loaded, how fresh sessions are managed, and how results are persisted. Draw from GSD's dispatch pipeline and Superpowers' subagent patterns.

### G. Execution Runtimes

Define how the orchestrator can execute via:
1. **Local CLI** -- Direct agent invocation (like GSD auto mode)
2. **GitHub Agentic Workflows** -- Workflow markdown in `.github/workflows/` with orchestrator APM package declared in frontmatter `dependencies:` field. gh-aw natively resolves APM deps, compiles to GitHub Actions YAML. Use `isolated: true` for clean context. Agent engine selected via `engine:` field.
3. **Subagent dispatch** -- Using the host agent's subagent capability (Claude Code Task(), Copilot, etc.)

### H. Reliability

Specify crash recovery, stuck detection, timeout supervision, verification enforcement, and cost tracking, adapted from GSD's mechanisms to work within spec-kit's extension model.

### I. APM Integration

Define the `apm.yml` for the orchestrator as a distributable APM package. Specify:
- What primitives the package provides: instructions (`.instructions.md`), skills (`SKILL.md` for orchestration workflow), prompts (`.prompt.md` for dispatch templates), agents (`.agent.md` for orchestrator/worker roles)
- How `apm install` deploys these into IDE-native directories (`.github/`, `.claude/`, `.cursor/`, `.opencode/`) -- this is the primary integration, NOT compilation
- How `apm compile` optionally produces `AGENTS.md`/`CLAUDE.md` with orchestrator instructions for tools that need it (Codex, Gemini, OpenCode)
- How spec-kit's constitution.md gets injected during compilation (already a built-in APM behavior)
- MCP server dependencies if needed (declared under `dependencies.mcp:` in apm.yml)
- How the orchestrator package declares transitive dependencies on other useful packages (e.g., code review skills, testing skills)

### J. GitHub Agentic Workflows Integration

Define how the orchestrator emits workflow markdown files for `.github/workflows/`. Specify:
- The frontmatter `dependencies:` field declaring the orchestrator APM package -- gh-aw natively resolves this
- How the `engine:` field selects the agent runtime and auto-infers the APM compilation target
- How `isolated: true` ensures the orchestration agent gets clean context without host repo instruction pollution
- Safe outputs for write operations (creating PRs, posting status comments, updating issue labels)
- How the state machine loop runs inside a GitHub Action (event-triggered or scheduled)
- How `apm pack` produces bundles for sandboxed execution with zero network access
- The `apm-action` pre-step alternative when the orchestrator needs full `apm.yml`-based configuration

### K. Continuous Knowledge Generation and Agent-Searchable Context Hierarchy

This is the orchestrator's highest-value capability. Define:

**What gets generated:**
- After each task: structured task summary (what was built, what files changed, what decisions were made, what was learned)
- After each phase: phase summary rolling up task summaries, documenting the component/feature that was built, its interfaces, its patterns
- After each milestone: milestone summary, updated architecture documentation, API contracts, data flow diagrams
- Continuously: KNOWLEDGE.md (GSD pattern) for cross-session lessons, DECISIONS.md for architectural decision records
- On demand: pattern documentation, business logic documentation, data structure documentation

**How it's organized (the hierarchy):**
- Follow APM's context pollution philosophy: distribute knowledge hierarchically, not in one monolithic file
- Root level: project-wide architecture, constitution, cross-cutting patterns
- Per-milestone: milestone-specific context, roadmap, success criteria
- Per-phase: phase-specific patterns, component documentation, interface contracts
- Per-directory (in the codebase itself): AGENTS.md-compatible context files describing the code in that directory -- its purpose, its patterns, its interfaces, its conventions
- This hierarchy should be compatible with `apm compile`'s distributed placement model so that any agent working in a specific directory inherits the right context automatically

**How agents search it:**
- Agents working on a task should be able to discover relevant context by walking the hierarchy from their working directory upward (AGENTS.md standard)
- The orchestrator's dispatch prompt should pre-load only the relevant slice of the knowledge hierarchy for each task (not the entire project's documentation)
- Skills/prompts should be generated that help agents query the knowledge base efficiently (e.g., "find patterns related to authentication", "what decisions were made about the data model")
- The knowledge hierarchy should be structured to maximize the ratio of relevant-to-total context for any given task

**How it reduces context per task:**
- Instead of each task reading source files to understand the codebase, it reads pre-generated summaries
- Instead of each task re-discovering patterns, it inherits documented patterns from the hierarchy
- Instead of each task asking the user about architectural decisions, it reads the decisions register
- The knowledge base compounds: each task that generates good documentation makes every future task cheaper to execute

### L. Knowledge Consolidation and Cleanup Phase

Raw documentation generated during execution is verbose by design -- task summaries capture everything that happened, phase summaries capture everything that was built. But verbose docs are bad for future context efficiency. The orchestrator needs a consolidation phase that compresses accumulated knowledge into optimized, agent-searchable units.

**When consolidation runs:**
- After each milestone completes (mandatory) -- triggered automatically by the state machine after milestone validation passes
- After each phase completes (optional, configurable) -- useful for long milestones where interim cleanup helps
- On demand via `speckit.orchestrator.consolidate` -- for manual cleanup or periodic maintenance
- As a scheduled GitHub Agentic Workflow -- for continuous knowledge hygiene on active repos

**What consolidation does:**

1. **Compress task-level artifacts into phase-level summaries**: Individual task summaries, plans, and research notes are synthesized into a single phase-level document that captures the net knowledge -- what was built, why, what patterns emerged, what decisions were made. The raw task artifacts are moved to a `.specify/orchestrator/archive/` directory (preserving full git history) and replaced with the compressed summary.

2. **Compress phase-level summaries into milestone-level documentation**: Phase summaries are synthesized into milestone-level architecture documentation, API documentation, pattern guides. Again, raw phase artifacts are archived.

3. **Generate/update codebase-level context files**: The consolidator examines what code was produced and generates or updates AGENTS.md-compatible context files in the relevant source directories. These describe: what the code in this directory does, what patterns it uses, what interfaces it exposes, what conventions it follows. This is the bridge between orchestrator knowledge and APM's hierarchical context model.

4. **Update the root knowledge base**: KNOWLEDGE.md, DECISIONS.md, and any project-wide pattern/architecture docs get updated with lessons and decisions from the completed work. Duplicates are merged. Stale entries are pruned.

5. **Optimize for token efficiency**: The consolidator explicitly targets token reduction. Each output document has a target token budget. If a phase summary would exceed its budget, it gets further compressed. The goal is: maximum information density per token, because every token in the knowledge base is a token that gets loaded into some future task's context.

**Archive strategy:**
- Raw artifacts (verbose task summaries, research notes, intermediate plans) are moved to `.specify/orchestrator/archive/{milestone}/{phase}/`
- Archive directory is gitignored by default (the raw artifacts live in git history anyway) -- configurable to track if the team wants explicit archive access
- The archive serves as an audit trail and recovery mechanism but is never loaded into agent context
- A `speckit.orchestrator.consolidate --dry-run` shows what would be archived and what the compressed output would look like before committing

**Consolidation quality gates:**
- After compression, verify that no critical information was lost: key decisions, interface contracts, pattern documentation, lessons learned must survive compression
- The consolidator runs a coverage check: does the compressed knowledge base cover every component that was built? Every decision that was made? Every pattern that was established?
- If compression would lose critical info (e.g., a complex architectural decision that can't be further summarized), it's preserved at full fidelity with a `[preserved-verbatim]` marker

---

## Execution Instructions

1. **Dispatch five subagents**, one per repository. Each subagent reads the specified files from the local submodule and produces its structured report.

2. **Each subagent should prioritize**:
   - Concrete implementation details over marketing language
   - File formats, schemas, and data structures over abstract descriptions
   - Integration surface area (hooks, APIs, CLIs, file conventions) over internal architecture
   - Specific patterns that should be adopted vs. adapted vs. ignored

3. **After all five reports are collected**, synthesize into the final spec following sections A through L above.

4. **The final spec should be concrete enough** that an agent could take it and build the extension -- with specific file paths, manifest contents, command definitions, state machine transitions, and prompt templates.

---

## Key Design Constraints

- **Must be a valid spec-kit extension** -- installable via `specify extension add`, with proper extension.yml, registered commands, and hooks.
- **Must not require GSD as a dependency** -- we're porting principles, not wrapping GSD.
- **Must not require APM at runtime** -- APM is used at setup time (`apm install` deploys primitives to IDE-native dirs; optional `apm compile` generates instruction files). At runtime, the extension uses spec-kit's native mechanisms and the agent reads already-deployed primitives. When used with gh-aw, APM deps are resolved in the activation job before the agent runs.
- **Must work with any spec-kit-supported agent** -- Claude Code, Copilot, Gemini CLI, Cursor, etc. Commands are in universal markdown format.
- **Must degrade gracefully** -- If no subagent capability is available, fall back to sequential in-session execution. If no GitHub Agentic Workflows, operate locally only.
- **State on disk is the source of truth** -- No in-memory state across sessions. Everything recoverable from `.specify/orchestrator/` files.
- **The "iron rule" applies** -- Every task must fit in one context window. If it can't, it's two tasks.
- **Evidence before claims** -- No task is marked complete without fresh verification. Borrowed from Superpowers' verification-before-completion skill.
- **Knowledge compounds** -- Every phase of work must produce structured, discoverable documentation. The knowledge hierarchy is the orchestrator's most valuable output because it reduces context usage for every future task.
- **Context efficiency is the optimization target** -- Follow APM's context pollution model: distribute knowledge hierarchically, minimize irrelevant context per task, maximize the ratio of relevant-to-total context for any unit of work.
- **Plans assume zero context** -- Following Superpowers' writing-plans philosophy, every task plan must be self-contained with exact file paths, complete code, exact commands, and expected output. An agent with no project knowledge should be able to execute it.
