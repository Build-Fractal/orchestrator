# Speckit-Orchestrator: Complete Execution Playbook

**Approach**: Pragmatic Hybrid — spec-kit (Claude Code slash commands) for design, GSD-2 (standalone CLI) for implementation orchestration.

- **Spec-kit**: Claude Code slash commands (`/speckit.specify`, etc.) — runs inside your Claude Code session
- **GSD-2**: Standalone TypeScript CLI (`gsd`) built on the Pi SDK — runs its OWN agent sessions with programmatic control over context windows, git, crash recovery, and dispatch. NOT the v1 `/gsd:*` Claude Code skills.

We use spec-kit where it's strongest (structured specification workflow) and GSD-2 where it's strongest (autonomous execution with real context control).

---

## Prerequisites

Before starting Window 1, run these one-time setup steps in a terminal:

```bash
# 1. Initialize all required submodules
cd /Users/brettkellgren/Sites/payer-index-mono
git submodule update --init --recursive spec-kit gsd-2 apm superpowers gh-aw

# 2. Initialize spec-kit in this repo (creates .specify/ directory structure)
# If spec-kit CLI is installed:
specify init --here --ai claude

# If spec-kit CLI is NOT installed, create the structure manually:
mkdir -p .specify/templates .specify/memory .specify/templates/commands
cp spec-kit/templates/constitution-template.md .specify/templates/
cp spec-kit/templates/spec-template.md .specify/templates/
cp spec-kit/templates/plan-template.md .specify/templates/
cp spec-kit/templates/tasks-template.md .specify/templates/
cp spec-kit/templates/checklist-template.md .specify/templates/
cp spec-kit/templates/commands/*.md .specify/templates/commands/

# 3. Create the research output directory
mkdir -p .planning/research

# 4. Verify GSD-2 is installed (should be v2.28.0+)
gsd --version
```

**Verify before proceeding:**
- [ ] `ls .specify/templates/` shows template files
- [ ] All 5 submodules populated: spec-kit, gsd-2, apm, superpowers, gh-aw
- [ ] `.planning/research/` directory exists
- [ ] `gsd --version` shows v2.28.0 or later

---

## Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────┐
│              DESIGN PHASE (Claude Code + spec-kit)              │
│              Runs in: Claude Code sessions                      │
│                                                                 │
│  W1: /speckit.constitution ──→ .specify/memory/constitution.md  │
│  W2: Research subagents ──→ .planning/research/*.md             │
│  W3: /speckit.specify ──→ specs/001-speckit-orchestrator/spec.md│
│  W4: /speckit.clarify ──→ updated spec.md                      │
│  W5: /speckit.plan ──→ plan.md + design artifacts               │
│  W6: /speckit.tasks ──→ tasks.md                                │
│  W7: /speckit.analyze ──→ consistency report, fix issues        │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│              BRIDGE (spec-kit artifacts → GSD-2 state)          │
│              Runs in: Terminal + GSD-2 CLI                      │
│                                                                 │
│  W8: gsd ──→ discussion to create .gsd/ from spec artifacts    │
│      /gsd auto ──→ GSD-2 takes over execution                  │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│              IMPLEMENTATION PHASE (GSD-2 autonomous)            │
│              Runs in: GSD-2's own agent sessions (Pi SDK)       │
│                                                                 │
│  GSD-2 auto-mode handles:                                      │
│    - Fresh session per task (programmatic, not prompt-based)    │
│    - Context pre-loading (inlines only what the task needs)     │
│    - Git worktree isolation (one branch per milestone)          │
│    - Crash recovery (lock files + session forensics)            │
│    - Stuck detection (dispatch-twice → diagnostic → stop)       │
│    - Adaptive replanning (roadmap reassessment per slice)       │
│    - Cost tracking (per-unit token/cost ledger)                 │
│    - KNOWLEDGE.md (cross-session memory)                        │
│    - DECISIONS.md (append-only register)                        │
│    - Verification enforcement (configurable commands)           │
│    - Timeout supervision (soft/idle/hard)                       │
│                                                                 │
│  Your role during auto-mode:                                    │
│    Terminal 2: gsd → /gsd discuss, /gsd status, /gsd steer     │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│              WRAP-UP                                             │
│              Runs in: Claude Code session                       │
│                                                                 │
│  W9: Knowledge consolidation — merge GSD-2 outputs back into   │
│      spec-kit's .specify/ structure                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Window 1: Constitution

**Runs in**: Claude Code session
**Purpose**: Establish non-negotiable governing principles.

### Handoff Prompt

```
/speckit.constitution

Create the constitution for the speckit-orchestrator project with these 7 core principles:

1. **Context Minimization** — Every architectural decision must optimize for minimizing the context each individual task consumes. Hierarchical knowledge distribution (not monolithic files), fresh sessions per task (not accumulated garbage), structured summaries (not raw transcripts). The optimization target: Context_Efficiency = Relevant_Instructions / Total_Instructions_Inherited. When this ratio degrades, the system is failing.

2. **Evidence Before Claims** — No task is marked complete without fresh verification evidence. "Should work" is not evidence. "Tests passed last time" is not evidence. Run the command, read the output, confirm the result, THEN claim completion. Verification is a mechanical gate, not an LLM compliance exercise.

3. **Design Before Code** — Every piece of work goes through an explicit design step, no matter how "simple" it seems. Simple projects are where unexamined assumptions cause the most wasted work. The brainstorm → plan → execute → review pipeline is mandatory. No implementation without an approved design.

4. **Plans Assume Zero Context** — Implementation plans must be written as if the executing agent has zero codebase context and questionable taste. Document everything: exact file paths, complete code, exact commands with expected output, verification steps with expected results. An agent dropped into the repo cold should be able to execute the plan.

5. **Fresh Context Per Unit** — Each unit of work (task, phase) executes in a fresh context that receives ONLY what it needs. The orchestrator constructs the minimal context payload for each dispatch. Subagents never inherit the orchestrator's session history. This prevents context rot and preserves the orchestrator's context budget for coordination.

6. **State On Disk Is Truth** — No in-memory state across sessions. The state machine reads disk state, determines the next action, executes, and persists results back to disk. Crash recovery, stuck detection, and session resumption all derive from file state. If it's not on disk, it didn't happen.

7. **Knowledge Compounds** — Every phase of work must produce structured, discoverable documentation — patterns, decisions, interfaces, lessons learned. This accumulated knowledge hierarchy is the orchestrator's most valuable output. Each task that generates good documentation makes every future task cheaper to execute. The knowledge base compounds; code is ephemeral.

Additional sections:

**Constraints:**
- This is a spec-kit extension — must be installable via `specify extension add`
- Must work with all spec-kit-supported agents (Claude Code, Copilot, Cursor, Gemini CLI)
- Must NOT require GSD-2 or APM as runtime dependencies (principles are ported, not wrapped)
- Must degrade gracefully (no subagent capability → sequential; no gh-aw → local only)
- Every task must fit in one context window (the "iron rule" — if it can't, it's two tasks)

**Quality Gates:**
- No phase advances without verification evidence
- Two-stage review after implementation: spec compliance first, code quality second
- Knowledge artifacts are mandatory outputs, not optional nice-to-haves
- Constitution compliance is checked at plan time AND after implementation

**Governance:**
- Constitution supersedes all other project guidance
- Amendments require explicit version bump with rationale
- All phases must verify compliance; violations require justification or design change
```

### Verify Before Advancing
- [ ] `.specify/memory/constitution.md` exists with all 7 principles
- [ ] No `[PLACEHOLDER]` tokens remain
- [ ] Version line present (should be `1.0.0`)

---

## Window 2: Research (Parallel Subagents)

**Runs in**: Claude Code session (dispatches subagents)
**Purpose**: Deep-dive into all 5 source repos.

### Handoff Prompt

```
We are building a spec-kit extension called "speckit-orchestrator" that brings
GSD-style autonomous orchestration into spec-kit's spec-driven development workflow.

Read the project constitution at .specify/memory/constitution.md first — these
principles govern every design decision.

Ensure all submodules are initialized:
git submodule update --init --recursive spec-kit gsd-2 apm superpowers gh-aw

Dispatch 5 research subagents in parallel. Each reads actual source code from
its submodule (not just READMEs) and produces a structured report. Save each
report to .planning/research/.

IMPORTANT: Read implementation files, test fixtures, config schemas, and prompt
templates — not just documentation. We need concrete details.

---

SUBAGENT 1 — spec-kit (./spec-kit/)

Research the extension system architecture. Read:
- extensions/RFC-EXTENSION-SYSTEM.md, EXTENSION-DEVELOPMENT-GUIDE.md,
  EXTENSION-API-REFERENCE.md, EXTENSION-USER-GUIDE.md
- src/specify_cli/extensions.py
- extensions/selftest/, extensions/template/
- All templates/commands/*.md and templates/*-template.md
- presets/README.md, presets/ARCHITECTURE.md
- scripts/bash/common.sh (resolve_template function)

Document: extension.yml manifest schema, command registration per agent,
hook system (every hook point and how they fire), config management, template
resolution stack, phase flow with per-phase inputs/outputs/artifacts, and
gaps where the orchestrator needs to extend.

Save to: .planning/research/01-speckit.md

---

SUBAGENT 2 — GSD-2 (./gsd-2/)

CRITICAL: GSD-2 is a standalone TypeScript CLI built on the Pi SDK. It is NOT
a set of Claude Code slash commands. It controls its own agent sessions
programmatically. Read the actual source, not just conceptual docs.

Read:
- src/resources/GSD-WORKFLOW.md (the full manual bootstrap protocol)
- docs/architecture.md (system structure, dispatch pipeline, key modules)
- docs/auto-mode.md (state machine, fresh sessions, crash recovery,
  stuck detection, verification enforcement, adaptive replanning)
- docs/commands.md (all commands: /gsd, /gsd auto, /gsd discuss, etc.)
- docs/getting-started.md (project structure, hierarchy, two-terminal workflow)
- docs/token-optimization.md (profiles, context compression, complexity routing)
- docs/cost-management.md (budgets, per-unit tracking)
- docs/git-strategy.md (worktree isolation, branch modes, squash merge)
- docs/parallel-orchestration.md (multi-worker, coordinator)
- docs/skills.md
- docs/configuration.md (preferences, models, hooks, verification_commands)
- src/resources/extensions/ (list the bundled extensions)
- src/resources/agents/ (scout, researcher, worker roles)

Document:
- The Milestone → Slice → Task hierarchy and .gsd/ directory structure
  (exact file paths: STATE.md, M###-ROADMAP.md, S##-PLAN.md, T##-PLAN.md,
  T##-SUMMARY.md, DECISIONS.md, KNOWLEDGE.md, continue.md, boundary maps)
- The 13-step auto-mode dispatch pipeline (from architecture.md)
- How state is derived purely from files on disk
- Fresh session per unit — programmatic via Pi SDK, not prompt-based
- Context pre-loading table (what gets inlined into each dispatch)
- Crash recovery: lock files, session forensics, headless auto-restart
- Stuck detection: dispatch-twice rule, diagnostic prompt, stop
- Verification enforcement: configurable commands, auto-fix retries
- Adaptive replanning after each slice
- Token profiles (budget/balanced/quality) and complexity routing
- Boundary maps: what slices produce/consume for deterministic verification
- Two-terminal workflow: auto-mode in T1, /gsd discuss + /gsd steer in T2
- Headless mode for CI/cron: gsd headless auto, gsd headless query
- Must-haves format: Truths, Artifacts, Key Links (mechanical verification)

Save to: .planning/research/02-gsd.md

---

SUBAGENT 3 — APM (./apm/)

Read:
- docs/src/content/docs/reference/manifest-schema.md
- docs/src/content/docs/guides/dependencies.md
- docs/src/content/docs/reference/primitive-types.md
- docs/src/content/docs/introduction/key-concepts.md
- docs/src/content/docs/integrations/ide-tool-integration.md (CRITICAL)
- docs/src/content/docs/integrations/gh-aw.md (CRITICAL)
- docs/src/content/docs/guides/compilation.md
- src/apm_cli/compilation/ (agents_compiler.py, distributed_compiler.py,
  context_optimizer.py, constitution.py)
- MANIFESTO.md

Document: Complete apm.yml manifest. All primitive types. The CRITICAL
distinction between `apm install` (deploys primitives to IDE-native dirs)
and `apm compile` (optional, generates instruction files only). Per-target
deployment details. Context pollution optimization. Constitution injection.
APM + gh-aw integration (frontmatter deps, isolated mode, bundles).

Save to: .planning/research/03-apm.md

---

SUBAGENT 4 — Superpowers (./superpowers/)

Read EVERY skill file in skills/:
- using-superpowers, brainstorming, writing-plans,
  subagent-driven-development, verification-before-completion,
  executing-plans, dispatching-parallel-agents, test-driven-development,
  systematic-debugging, using-git-worktrees, writing-skills

Also read:
- tests/subagent-driven-dev/ (example plans and designs)
- agents/code-reviewer.md
- hooks/hooks.json, .claude-plugin/plugin.json

Document: Complete philosophy. Subagent dispatch (context isolation,
prompt construction per role, two-stage review, status handling:
DONE/CONCERNS/NEEDS_CONTEXT/BLOCKED, model selection). Plan structure
from real examples. Session-start hook for discipline injection.

Save to: .planning/research/04-superpowers.md

---

SUBAGENT 5 — GitHub Agentic Workflows (./gh-aw/)

Also read: ./apm/docs/src/content/docs/integrations/gh-aw.md

Read: README.md, all docs/ files, example workflow markdown files.

Document: Markdown + YAML frontmatter format. Trigger types. Multi-engine.
gh aw compile. Safe outputs. Security model. APM native integration
(frontmatter deps, isolated mode, activation/agent pipeline).
Concrete workflow examples the orchestrator would generate.

Save to: .planning/research/05-gh-aw.md

---

SYNTHESIS — After all 5 reports

Read all 5 and produce .planning/research/00-synthesis.md:

1. **Integration Surface Map** — concrete integration points across repo pairs
2. **Patterns to Adopt** — with source repo and specific file references
3. **Patterns to Adapt** — things needing modification for spec-kit's model
4. **Patterns to Ignore** — things that don't apply
5. **Gaps** — where none of the 5 repos provide a solution
6. **Proposed Command Surface** — based on spec-kit extension system constraints
7. **Proposed State File Structure** — GSD-2's .gsd/ adapted for .specify/
8. **Risk Register** — technical risks the spec should address
```

### Verify Before Advancing
- [ ] All 6 files exist in `.planning/research/`
- [ ] `02-gsd.md` covers GSD-2 as a standalone CLI (not v1 prompt framework)
- [ ] `02-gsd.md` documents the 13-step dispatch pipeline and .gsd/ file structure
- [ ] Each report cites specific source files

---

## Window 3: Specify

**Runs in**: Claude Code session

### Handoff Prompt

```
/speckit.specify

Build a spec-kit extension called "speckit-orchestrator" that adds autonomous
multi-phase orchestration to spec-kit's spec-driven development workflow.

IMPORTANT: Before writing the spec, read these files for context:
- .specify/memory/constitution.md (governing principles)
- .planning/research/00-synthesis.md (integration surface map and gaps)
- .planning/research/01-speckit.md (extension system constraints)
- .planning/research/02-gsd.md (GSD-2 orchestration patterns)
- .planning/research/04-superpowers.md (subagent dispatch patterns)

THE PROBLEM:
Spec-kit excels at single-context-window development: constitution → specify →
plan → tasks → implement. But projects larger than one context window hit a wall.
Users must manually break work into pieces, manually manage fresh contexts for
each piece, manually track progress, and manually reassemble results. There is
no orchestration layer.

THE SOLUTION:
An extension that adds a hierarchy above tasks — milestones (shippable versions)
containing phases (demoable capabilities) containing tasks (context-window-sized
units) — and orchestrates execution across them.

USER STORIES (prioritize these):

P1 — SCOPE TRIAGE: As a developer, I describe what I want to build and the
orchestrator evaluates scope and classifies it into the right execution tier:
- Tier A (fits one context window): Run standard spec-kit inline, no overhead
- Tier B (multiple phases, each fits one window): Add roadmap layer, manage
  phase-to-phase handoff with summaries and context bridging
- Tier C (full orchestration): State machine, subagent dispatch, crash
  recovery, parallel execution, continuous knowledge generation
Same entry point for a bugfix or a platform rewrite.

P2 — PHASE-BY-PHASE EXECUTION: As a developer with a Tier B/C project, the
orchestrator breaks my spec into phases with a roadmap, dependencies, and
boundary maps. Each phase runs in a fresh context receiving only what it needs.
Phase results are persisted as structured summaries to disk.

P3 — AUTONOMOUS DISPATCH: As a developer with a Tier C project, I can start
auto-mode and walk away. The state machine reads disk state, determines the
next unit, constructs a minimal context payload, dispatches to a fresh agent
session, verifies completion (must-haves: Truths, Artifacts, Key Links),
persists results, and advances. Crashes are recoverable from disk state.

P4 — KNOWLEDGE GENERATION: Every phase produces structured documentation —
what was built, patterns used, decisions made, interfaces established. This
knowledge hierarchy is searchable by future agents, reducing context needs.
Includes KNOWLEDGE.md (cross-session memory) and DECISIONS.md (append-only
register).

P5 — CRASH RECOVERY AND RELIABILITY: If a session crashes or times out mid-
task, the orchestrator detects incomplete state via lock files, synthesizes a
recovery briefing from session forensics, and resumes. Stuck detection
(dispatch-twice rule) prevents infinite loops.

P6 — KNOWLEDGE CONSOLIDATION: After a milestone completes, compress verbose
task/phase artifacts into optimized summaries, generate codebase-level context
files, archive raw artifacts.

P7 — GITHUB AGENTIC WORKFLOWS RUNTIME: Optionally run the orchestrator as a
GitHub Agentic Workflow — triggered by schedule, issue, or comment command —
with APM package declared in frontmatter dependencies.

P8 — APM PACKAGING: Installable via APM (`apm install speckit-orchestrator`),
deploys skills, prompts, and agent definitions to IDE-native directories.

SKILL DESIGN REQUIREMENTS (from Anthropic's skill best practices):

Each orchestrator command must be designed as a skill FOLDER, not just a
markdown file. Skills are the primary unit of packaging and distribution.

Folder structure per skill:
  skills/<skill-name>/
  ├── SKILL.md              # Trigger-phrased description + workflow + gotchas
  ├── scripts/              # Helper scripts the agent composes
  │   ├── read-state.sh     # Parse state files, output JSON
  │   ├── build-context.sh  # Assemble minimal context payload for a phase
  │   └── verify-must-haves.sh  # Mechanically check truths/artifacts/links
  ├── templates/            # Output templates agent copies and fills
  │   ├── dispatch-prompt.md
  │   ├── phase-summary.md
  │   └── recovery-briefing.md
  ├── references/           # Progressive disclosure — loaded only when needed
  │   └── state-machine.md
  └── config.json           # User preferences (persists across sessions)

Design principles for skills:
- **Progressive disclosure via file system**: SKILL.md tells the agent what
  reference files exist. The agent reads them only when it actually needs
  the detail. This serves Context Minimization — don't dump everything into
  one file.
- **Scripts for composition, not reconstruction**: Give the agent helper
  scripts (state parsing, context assembly, verification) so it spends
  turns on decisions, not reimplementing boilerplate every dispatch.
- **Templates for output consistency**: Agent copies and fills templates
  for summaries, dispatch prompts, and recovery briefings rather than
  generating from scratch each time.
- **Gotchas section in every SKILL.md**: Document known failure modes,
  context pollution patterns, state machine edge cases, and dispatch
  anti-patterns. Updated over time as new edge cases are discovered —
  this is the Knowledge Compounds principle expressed as skill maintenance.
- **config.json for user preferences**: First run asks the user (tier
  override, token profile, verification commands, git isolation mode,
  knowledge verbosity). Subsequent runs read the config. Use
  AskUserQuestion tool for structured setup prompts.
- **Trigger-phrased descriptions**: The SKILL.md description field is what
  the agent scans to decide whether to invoke the skill. Phrase it as
  "Use when..." not as a feature summary.
  Bad:  "Orchestrator dispatch system for multi-phase projects"
  Good: "Use when a project has been broken into phases and you need to
         execute the next phase in a fresh context with only its required
         dependencies loaded"
- **On-demand hooks**: Skills register hooks active only during execution:
  - Phase scope enforcement (blocks edits outside declared phase files)
  - Verification evidence logging (captures proof to phase summary)
  - Destructive operation warnings during auto-mode
- **Execution history**: Store append-only logs (execution-log.jsonl) for
  cross-session continuity, cost tracking, and retrospective analysis.
  Use ${CLAUDE_PLUGIN_DATA} for data that survives skill upgrades.

Skill categories the orchestrator should provide:
- Business Process & Automation → orchestrator-auto (the main loop)
- Product Verification → orchestrator-verify (must-haves checking)
- Code Scaffolding → orchestrator-scaffold (phase/milestone file structure)
- Code Quality & Review → orchestrator-review (two-stage review)
- Runbooks → orchestrator-recover (crash recovery, debugging)
- Data Fetching & Analysis → orchestrator-status (progress, cost, state)

CONSTRAINTS:
- Must be a valid spec-kit extension (extension.yml, registered commands, hooks)
- Must not require GSD-2 or APM as runtime dependencies
- Must work with any spec-kit-supported agent
- Must degrade gracefully (no subagent → sequential; no gh-aw → local only)
- State on disk is source of truth
- Every task must fit one context window
- Plans assume zero context
- Skills must be folders with scripts, templates, references, and config —
  not flat markdown files
```

### Verify Before Advancing
- [ ] `specs/001-speckit-orchestrator/spec.md` exists
- [ ] All 8 user stories present with acceptance scenarios
- [ ] Functional requirements are testable
- [ ] Success criteria are measurable and technology-agnostic
- [ ] No more than 3 `[NEEDS CLARIFICATION]` markers

---

## Window 4: Clarify

**Runs in**: Claude Code session

### Handoff Prompt

```
/speckit.clarify

Clarify the speckit-orchestrator specification.

Additional context: research reports at .planning/research/ provide deep
technical context. Focus on areas that materially impact:
1. State machine design (state transitions, file formats, recovery)
2. Dispatch model (what context payload each unit receives)
3. Extension integration surface (which hooks, which commands)
4. Tier triage criteria (how to classify A vs B vs C)
5. Knowledge hierarchy structure (what gets generated, where it lives)
```

### Verify Before Advancing
- [ ] Spec has `## Clarifications` section with session date
- [ ] Clarifications integrated into relevant spec sections

---

## Window 5: Plan

**Runs in**: Claude Code session

### Handoff Prompt

```
/speckit.plan

Create the implementation plan for speckit-orchestrator. I am building with:

- Language: Markdown command templates + Bash/PowerShell scripts
  (spec-kit extension format)
- Extension system: spec-kit's extension.yml manifest, command registration,
  hook system
- State management: File-based state machine reading/writing
  .specify/orchestrator/ directory hierarchy
- Packaging: APM package (apm.yml manifest)
- Execution runtimes:
  1. Local CLI (spec-kit commands in agent session)
  2. Subagent dispatch (Agent tool / equivalent)
  3. GitHub Agentic Workflows (optional)
- Testing: Shell-based integration tests + /speckit.analyze

IMPORTANT — SKILL FOLDER ARCHITECTURE:
The spec requires each orchestrator command to be a skill FOLDER (not flat
markdown) containing scripts/, templates/, references/, config.json, and
a SKILL.md with gotchas and trigger-phrased description. The plan must
account for this structure — each skill folder is a distinct deliverable
with its own scripts, templates, and progressive disclosure hierarchy.
Skills also register on-demand hooks (phase scope enforcement, verification
logging, destructive operation warnings).

Read these before planning:
- .planning/research/01-speckit.md (extension system)
- .planning/research/02-gsd.md (state machine patterns — NOTE: GSD-2 is a
  standalone CLI, we are porting its PRINCIPLES not wrapping it)
- .planning/research/03-apm.md (packaging)
- .planning/research/04-superpowers.md (subagent dispatch)
- .planning/research/05-gh-aw.md (workflow runtime)
- .planning/research/00-synthesis.md (integration surfaces and gaps)
- spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md
- spec-kit/extensions/EXTENSION-API-REFERENCE.md
- spec-kit/extensions/selftest/ (example extension)
```

### Verify Before Advancing
- [ ] `plan.md` filled (no template placeholders)
- [ ] `research.md` exists with resolved unknowns
- [ ] `data-model.md` exists
- [ ] Constitution check PASS or justified

---

## Window 6: Tasks

**Runs in**: Claude Code session

### Handoff Prompt

```
/speckit.tasks

Generate the task breakdown for speckit-orchestrator.

IMPORTANT — GSD-2 BRIDGING METADATA:

After implementation, these spec-kit artifacts will be fed into GSD-2
(standalone CLI) to orchestrate execution. GSD-2 works with:
- Milestones → Slices → Tasks
- Each slice has a boundary map (what it produces/consumes)
- Each task has must-haves (Truths, Artifacts, Key Links for verification)
- State derived from .gsd/ files on disk

To make the bridge to GSD-2 smooth, add to each phase:

1. **Boundary Map** — what interfaces/artifacts this phase produces and
   what it consumes from prior phases (GSD-2 uses these for deterministic
   verification that phases connect):
   ```
   **Boundary Map:**
   Produces: [files, functions, interfaces this phase creates]
   Consumes: [specific outputs from prior phases it depends on]
   ```

2. **Must-Haves** — observable verification criteria in GSD-2's format:
   ```
   **Must-Haves:**
   Truths: [observable behaviors that must be true when done]
   Artifacts: [files that must exist with real implementation]
   Key Links: [critical wiring between artifacts]
   ```

These map directly to GSD-2's S##-PLAN.md format, making the W8 bridge
a straightforward translation rather than a redesign.

IMPORTANT — SKILL FOLDER DELIVERABLES:

Each orchestrator skill is a folder, not a flat file. Tasks for each skill
should include:
- SKILL.md authoring (trigger-phrased description, workflow, gotchas)
- scripts/ creation (helper scripts the agent composes)
- templates/ creation (output templates for summaries, prompts, briefings)
- references/ for progressive disclosure (detailed docs split out of SKILL.md)
- config.json schema definition (user preferences)
- On-demand hook registration (phase scope, verification logging, etc.)
- Gotchas section seeded with known failure modes from research

Skill categories to deliver:
- orchestrator-auto (Business Process — the main loop)
- orchestrator-verify (Verification — must-haves checking)
- orchestrator-scaffold (Scaffolding — phase/milestone file structure)
- orchestrator-review (Code Quality — two-stage review)
- orchestrator-recover (Runbook — crash recovery, debugging)
- orchestrator-status (Data & Analysis — progress, cost, state dashboard)

Standard tasks.md requirements still apply: checklist format, IDs, [P]
markers, [Story] labels, exact file paths.
```

### Verify Before Advancing
- [ ] `tasks.md` exists
- [ ] Every phase has Boundary Map and Must-Haves blocks
- [ ] All tasks have IDs, checkboxes, file paths
- [ ] Phase dependencies are explicit

---

## Window 7: Analyze

**Runs in**: Claude Code session

### Handoff Prompt

```
/speckit.analyze

Run consistency analysis on speckit-orchestrator artifacts. Focus on:
1. Coverage: every requirement has at least one task
2. Constitution alignment: all phases respect the 7 principles
3. GSD-2 readiness: every phase has Boundary Map and Must-Haves
4. Terminology: Milestone → Phase → Task used consistently
5. Dependency coherence: phase chains match plan.md architecture
```

### Handle Results
- **No CRITICAL**: Proceed to Window 8.
- **CRITICAL found**: Fix in this window. Re-run `/speckit.analyze`.

---

## Window 8: Bridge — Feed Spec-Kit Artifacts into GSD-2

**Runs in**: Terminal (GSD-2 CLI)
**Purpose**: Create the GSD-2 project from our existing design artifacts.

GSD-2 normally starts with `/gsd` → discussion → research → plan. We're
telling it that the design is ALREADY DONE and giving it the spec-kit
artifacts as the context for creating its milestone structure.

### Step 1: Launch GSD-2

Open a terminal in the project root:

```bash
cd /Users/brettkellgren/Sites/payer-index-mono
gsd
```

### Step 2: Create the Milestone from Existing Artifacts

In the GSD-2 session, paste:

```
I have a fully specified project that needs implementation. All design
artifacts are already complete — do NOT redo research or specification.

Read these files as the source of truth:

SPECIFICATION:
- .specify/memory/constitution.md (7 governing principles)
- specs/001-speckit-orchestrator/spec.md (feature specification with 8 user stories)
- specs/001-speckit-orchestrator/plan.md (implementation plan with tech stack)
- specs/001-speckit-orchestrator/research.md (technical decisions)
- specs/001-speckit-orchestrator/data-model.md (state entities)
- specs/001-speckit-orchestrator/tasks.md (phase breakdown with boundary maps and must-haves)

DEEP RESEARCH (already completed):
- .planning/research/00-synthesis.md (integration surface map)
- .planning/research/01-speckit.md (spec-kit extension system)
- .planning/research/02-gsd.md (GSD-2 patterns we're porting)
- .planning/research/03-apm.md (APM packaging)
- .planning/research/04-superpowers.md (subagent dispatch patterns)
- .planning/research/05-gh-aw.md (GitHub Agentic Workflows)

Create a milestone from these artifacts. The phases in tasks.md already
have Boundary Maps (produces/consumes) and Must-Haves (Truths/Artifacts/
Key Links) that map directly to GSD-2's slice plan format.

Map each phase from tasks.md to a GSD-2 slice in the roadmap. Preserve
the boundary maps and must-haves — they're the verification criteria.

The 7 constitution principles from constitution.md should be treated as
project-level constraints that every slice must satisfy.

Tech stack: Markdown command templates + Bash/PowerShell scripts (spec-kit
extension format). No compiled language. Primary output is markdown files,
shell scripts, and YAML manifests.

IMPORTANT DETAIL: Each orchestrator command is a skill FOLDER containing
SKILL.md, scripts/, templates/, references/, and config.json. The tasks.md
phases include specific tasks for authoring each skill folder's contents.
Each skill also registers on-demand hooks. Treat each skill folder as a
distinct deliverable within its slice.
```

### Step 3: Review the Roadmap

GSD-2 will create `.gsd/milestones/M001/M001-ROADMAP.md`. Review it:

```
/gsd status
```

Verify that:
- [ ] Slices map to your tasks.md phases
- [ ] Boundary maps are preserved
- [ ] Dependencies match tasks.md

### Step 4: Start Auto Mode

```
/gsd auto
```

GSD-2 now takes over. It will:
1. Research each slice (reading your existing research reports)
2. Plan each slice (creating T##-PLAN.md with must-haves)
3. Execute each task in a fresh session (Pi SDK creates clean context)
4. Verify each task (must-haves: Truths, Artifacts, Key Links)
5. Commit with meaningful messages
6. Write summaries (T##-SUMMARY.md, S##-SUMMARY.md)
7. Reassess the roadmap after each slice
8. Advance to the next slice
9. Repeat until milestone complete

### Step 5: Steer While It Builds (Optional — Second Terminal)

Open a second terminal:

```bash
cd /Users/brettkellgren/Sites/payer-index-mono
gsd
```

Use these commands to monitor and steer:

| Command | What It Does |
|---------|-------------|
| `/gsd status` | Progress dashboard — slices done, active task, cost |
| `/gsd discuss` | Talk through architecture decisions mid-build |
| `/gsd steer` | Hard-steer plan documents during execution |
| `/gsd capture` | Fire-and-forget thought capture for later triage |
| `/gsd queue` | Queue and reorder future milestones |
| `Ctrl+Alt+G` | Toggle dashboard overlay |
| `Escape` | Pause auto mode (preserves conversation) |

### What GSD-2 Handles (That You Don't)

| Concern | What GSD-2 Does |
|---------|----------------|
| Fresh context | Pi SDK creates new session per task — programmatic, not prompt-based |
| Context payload | Inlines task plan, prior summaries, decisions register, roadmap excerpt |
| State tracking | Reads/writes .gsd/ files — STATE.md, ROADMAP, PLAN, SUMMARY |
| Git isolation | Worktree per milestone on `milestone/M001` branch, squash merge on complete |
| Crash recovery | Lock file + session forensics → recovery briefing on next `/gsd auto` |
| Stuck detection | Same unit dispatched twice → diagnostic prompt → stop with exact expected file |
| Verification | Configurable commands (lint, test) with auto-fix retries |
| Adaptive replanning | Roadmap reassessed after each slice — slices reordered/added/removed |
| Cost tracking | Per-unit token/cost ledger, budget ceilings can pause auto mode |
| Knowledge | KNOWLEDGE.md (cross-session memory), DECISIONS.md (append-only register) |
| Timeout | Soft (20min warn) → Idle (10min intervene) → Hard (30min pause) |

### Verify Before Advancing
- [ ] `.gsd/` directory exists with milestone structure
- [ ] All slices show complete in `/gsd status`
- [ ] Milestone branch merged to main (or ready to merge)
- [ ] `.gsd/KNOWLEDGE.md` has accumulated project knowledge
- [ ] `.gsd/DECISIONS.md` has architectural decisions

---

## Window 9: Knowledge Consolidation

**Runs in**: Claude Code session
**Purpose**: Merge GSD-2's outputs back into spec-kit's structure and produce
the consolidated knowledge base that future work on this extension will use.

### Handoff Prompt

```
We have completed implementation of the speckit-orchestrator extension.

GSD-2 produced these artifacts during implementation:
- .gsd/KNOWLEDGE.md (cross-session lessons and patterns)
- .gsd/DECISIONS.md (append-only architectural decisions register)
- .gsd/milestones/M001/M001-SUMMARY.md (milestone rollup)
- .gsd/milestones/M001/slices/S*/S*-SUMMARY.md (per-slice summaries)

Read the constitution at .specify/memory/constitution.md — particularly
Principle 7 (Knowledge Compounds) and Principle 1 (Context Minimization).

Perform knowledge consolidation:

1. Read all GSD-2 summaries and knowledge files.

2. Create .specify/orchestrator/KNOWLEDGE.md synthesizing:
   - Patterns established (how things are built in this extension)
   - Decisions register (import from .gsd/DECISIONS.md with context)
   - Lessons learned (import from .gsd/KNOWLEDGE.md with context)
   - Interface contracts between components

3. Create .specify/orchestrator/milestone-summary.md with:
   - What was built (high-level)
   - Architecture overview
   - Component inventory with file paths
   - How to extend (for future milestones)

4. For each major directory the extension created, evaluate whether an
   AGENTS.md-compatible context file helps future agents. Create where
   useful.

5. Review specs/001-speckit-orchestrator/ artifacts for drift from what
   was actually built. Update spec.md and plan.md if significant
   deviations occurred during implementation.

6. Optimize all outputs for token efficiency — maximum information
   density per token.
```

### Verify When Complete
- [ ] `.specify/orchestrator/KNOWLEDGE.md` exists
- [ ] `.specify/orchestrator/milestone-summary.md` exists
- [ ] Spec drift documented if any
- [ ] Final commit made

---

## Quick Reference: File Map After Completion

```
.specify/
├── memory/
│   └── constitution.md                    # W1
├── orchestrator/
│   ├── KNOWLEDGE.md                       # W9
│   └── milestone-summary.md              # W9
└── templates/                             # Prerequisites

.planning/
├── research/
│   ├── 00-synthesis.md                    # W2
│   ├── 01-speckit.md                      # W2
│   ├── 02-gsd.md                          # W2
│   ├── 03-apm.md                          # W2
│   ├── 04-superpowers.md                  # W2
│   └── 05-gh-aw.md                        # W2
└── speckit-orchestrator-playbook.md       # This file

specs/
└── 001-speckit-orchestrator/
    ├── spec.md                            # W3 + W4
    ├── plan.md                            # W5
    ├── research.md                        # W5
    ├── data-model.md                      # W5
    ├── contracts/                         # W5
    ├── tasks.md                           # W6
    └── checklists/                        # W3

.gsd/                                      # W8 (GSD-2 state — auto-managed)
├── STATE.md
├── KNOWLEDGE.md
├── DECISIONS.md
└── milestones/
    └── M001/
        ├── M001-ROADMAP.md
        ├── M001-SUMMARY.md
        └── slices/
            └── S##/
                ├── S##-PLAN.md
                ├── S##-SUMMARY.md
                └── tasks/T##-{PLAN,SUMMARY}.md

(extension source files)                   # Created by GSD-2 auto-mode
├── extension.yml                          # Spec-kit extension manifest
├── commands/                              # Spec-kit command registrations
└── skills/
    ├── orchestrator-auto/
    │   ├── SKILL.md                       # Trigger desc + workflow + gotchas
    │   ├── scripts/
    │   │   ├── read-state.sh
    │   │   ├── build-context.sh
    │   │   └── advance-state.sh
    │   ├── templates/
    │   │   └── dispatch-prompt.md
    │   ├── references/
    │   │   └── state-machine.md
    │   └── config.json
    ├── orchestrator-verify/
    │   ├── SKILL.md
    │   ├── scripts/verify-must-haves.sh
    │   └── templates/verification-report.md
    ├── orchestrator-scaffold/
    │   ├── SKILL.md
    │   └── templates/                     # Phase/milestone file templates
    ├── orchestrator-review/
    │   ├── SKILL.md
    │   └── templates/                     # Review prompt templates
    ├── orchestrator-recover/
    │   ├── SKILL.md
    │   ├── scripts/synthesize-briefing.sh
    │   └── templates/recovery-briefing.md
    └── orchestrator-status/
        ├── SKILL.md
        └── scripts/dashboard.sh
```

---

## Troubleshooting

**spec-kit commands can't find feature branch**: Set env var:
`export SPECIFY_FEATURE=001-speckit-orchestrator`

**GSD-2 wants to redo research**: Make sure you explicitly tell it in the
discussion that research is complete and point it at .planning/research/.

**GSD-2 creates wrong slice structure**: Use `/gsd steer` in the second
terminal to hard-steer the roadmap back to matching tasks.md phases.

**GSD-2 session crashes mid-task**: This is what GSD-2 was built for. Run
`gsd` again and `/gsd auto` — it reads the lock file, synthesizes a
recovery briefing, and resumes. With `gsd headless auto --max-restarts 3`,
restarts happen automatically with exponential backoff.

**Want CI execution instead of local**: Use headless mode:
`gsd headless new-milestone --context specs/001-speckit-orchestrator/spec.md --auto`

**Quality degrading mid-build**: Check `/gsd status` for cost and token
metrics. Consider switching to a higher token profile:
`/gsd prefs` → set token_profile to `quality`.

---

## Principles in Practice

| Playbook Pattern | Principle | Enforced By |
|-----------------|-----------|-------------|
| Spec-kit design pipeline (W1-W7) | 3. Design Before Code | spec-kit commands |
| Research before specification | 3. Design Before Code | You (W2 before W3) |
| Fresh session per task | 5. Fresh Context Per Unit | GSD-2 Pi SDK (programmatic) |
| Context pre-loading per dispatch | 1. Context Minimization | GSD-2 dispatch pipeline |
| Must-haves (Truths/Artifacts/Links) | 2. Evidence Before Claims | GSD-2 verification |
| .gsd/ files as sole state source | 6. State On Disk Is Truth | GSD-2 state machine |
| KNOWLEDGE.md + DECISIONS.md | 7. Knowledge Compounds | GSD-2 memory system |
| Zero-context plans with exact paths | 4. Plans Assume Zero Context | GSD-2 T##-PLAN.md |
| Adaptive replanning after slices | 3. Design Before Code | GSD-2 auto-mode |
| Verification commands with auto-fix | 2. Evidence Before Claims | GSD-2 config |

Spec-kit handles design quality (principles 3, 4).
GSD-2 handles execution quality (principles 1, 2, 5, 6, 7).
You handle judgment calls, steering, and quality review.
