# Research Synthesis: Speckit-Orchestrator Extension

**Date**: 2026-03-18
**Inputs**: 01-speckit.md, 02-gsd.md, 03-apm.md, 04-superpowers.md, 05-gh-aw.md

---

## 1. Integration Surface Map

Concrete integration points between each pair of repos, relevant to the orchestrator.

### spec-kit ↔ GSD-2

| spec-kit Surface | GSD-2 Surface | Integration Point |
|-----------------|---------------|-------------------|
| `extension.yml` manifest | `.gsd/` directory structure | Orchestrator state lives at `.specify/orchestrator/` (spec-kit convention), structured like `.gsd/milestones/` (GSD-2 pattern) |
| `provides.commands[]` | `/gsd`, `/gsd auto`, `/gsd discuss` | Orchestrator registers commands like `speckit.orchestrator.auto`, `speckit.orchestrator.status` via extension.yml |
| `hooks.before_tasks` / `hooks.after_tasks` | Dispatch phases (research → plan → execute → verify → summarize → advance) | Orchestrator hooks into spec-kit's task/implement lifecycle to inject phase-level orchestration |
| `templates/commands/*.md` (LLM-mediated) | Programmatic dispatch via Pi SDK | Orchestrator commands are markdown templates (spec-kit model), but must achieve GSD-2-level dispatch quality through careful prompt construction |
| `specs/###-feature/tasks.md` (checkbox format) | `S##-PLAN.md` + `T##-PLAN.md` (must-haves format) | Orchestrator translates spec-kit task phases into GSD-2-style slice plans with boundary maps and must-haves |
| `.specify/memory/constitution.md` | `.gsd/DECISIONS.md` + `.gsd/KNOWLEDGE.md` | Constitution feeds into every plan check; DECISIONS.md and KNOWLEDGE.md are generated during execution |
| Single-feature-at-a-time model | Milestone → Slice → Task hierarchy | **GAP**: spec-kit has no multi-feature coordination. Orchestrator adds the milestone/phase layer above spec-kit's features |

### spec-kit ↔ APM

| spec-kit Surface | APM Surface | Integration Point |
|-----------------|-------------|-------------------|
| `.specify/memory/constitution.md` | `constitution.py` injection during `apm compile` | APM automatically injects spec-kit's constitution into compiled AGENTS.md/CLAUDE.md |
| Extension commands (markdown files) | `.claude/commands/`, `.github/prompts/` | `apm install` deploys orchestrator skill folders to IDE-native directories |
| `.specify/templates/` (template resolution) | Primitive type system (instructions, skills, prompts, agents) | Orchestrator commands are APM skills; templates are APM instructions |

### spec-kit ↔ Superpowers

| spec-kit Surface | Superpowers Surface | Integration Point |
|-----------------|---------------------|-------------------|
| `/speckit.plan` (design before code) | `brainstorming/SKILL.md` HARD-GATE | Both enforce design-before-code; orchestrator inherits Superpowers' anti-rationalization tables |
| `/speckit.implement` (execute tasks) | `subagent-driven-development/SKILL.md` | Orchestrator dispatch uses Superpowers' prompt templates (implementer, spec-reviewer, code-quality-reviewer) |
| `/speckit.analyze` (consistency check) | `verification-before-completion/SKILL.md` | Both enforce evidence-before-claims; orchestrator adds mechanical must-haves verification |
| Checklist format in tasks.md | Plan format (exact paths, complete code, TDD steps) | Orchestrator task plans adopt Superpowers' zero-context plan format with bite-sized steps |

### spec-kit ↔ gh-aw

| spec-kit Surface | gh-aw Surface | Integration Point |
|-----------------|---------------|-------------------|
| Extension commands | Workflow markdown body (natural language) | Orchestrator generates `.github/workflows/orchestrator-*.md` files |
| `hooks.after_implement` | `safe-outputs: create-pull-request` | Post-implementation, orchestrator workflow creates PR via safe outputs |
| Feature branch model (`###-feature-name`) | `on: issues`, `on: slash_command` | Issue-triggered or comment-triggered workflows can invoke orchestrator phases |

### GSD-2 ↔ APM

| GSD-2 Surface | APM Surface | Integration Point |
|---------------|-------------|-------------------|
| Skills system (`docs/skills.md`) | Skill primitive (`SKILL.md` in folders) | Orchestrator skills are APM packages deployed via `apm install` |
| `KNOWLEDGE.md` / `DECISIONS.md` | Instructions primitive (`.instructions.md`) | Generated knowledge could be compiled into AGENTS.md via `apm compile` |

### GSD-2 ↔ gh-aw

| GSD-2 Surface | gh-aw Surface | Integration Point |
|---------------|---------------|-------------------|
| `gsd headless auto` (CI/cron mode) | Scheduled workflows, `engine: claude` | gh-aw workflow could invoke `gsd headless` as an execution runtime |
| `gsd headless query` (JSON state snapshot) | `cache-memory` tool | Workflow could query GSD-2 state for conditional logic |

---

## 2. Patterns to Adopt

### From GSD-2 (port principles, not code)

| Pattern | Source File | What to Adopt |
|---------|------------|---------------|
| Milestone → Slice → Task hierarchy | `GSD-WORKFLOW.md` lines 29-33 | Adopt as Milestone → Phase → Task with same size guidance |
| `.gsd/` directory structure | `GSD-WORKFLOW.md` lines 41-64 | Adapt to `.specify/orchestrator/` with same file naming |
| STATE.md derived from disk | `docs/architecture.md` state.ts | State derived from file existence, not a database |
| 13-step dispatch pipeline | `docs/architecture.md` lines 103-121 | Implement as markdown-based dispatch (spec-kit constraint) |
| Must-haves: Truths, Artifacts, Key Links | `GSD-WORKFLOW.md` lines 165-190 | Adopt verbatim for mechanical verification |
| Boundary maps | `GSD-WORKFLOW.md` lines 97-125 | Adopt for deterministic cross-phase verification |
| T##-SUMMARY.md frontmatter | `GSD-WORKFLOW.md` lines 406-445 | Adopt the 14-field frontmatter schema for structured summaries |
| DECISIONS.md format | `GSD-WORKFLOW.md` lines 232-258 | Adopt the 7-column append-only register verbatim |
| KNOWLEDGE.md | `docs/auto-mode.md` lines 79-81 | Adopt as append-only cross-session memory |
| continue.md protocol | `GSD-WORKFLOW.md` lines 474-497 | Adopt for crash recovery context |
| Timeout tiers (soft/idle/hard) | `docs/auto-mode.md` lines 100-116 | Adapt for spec-kit context (advisory, not programmatic) |
| Verification ladder | `GSD-WORKFLOW.md` lines 364-368 | Adopt: static → command → behavioral → human |

### From Superpowers (port philosophy and prompt templates)

| Pattern | Source File | What to Adopt |
|---------|------------|---------------|
| Mandatory skill activation | `using-superpowers/SKILL.md` | Inject orchestrator discipline into every session via hooks |
| HARD-GATE on design before code | `brainstorming/SKILL.md` | Enforce design phase cannot be skipped |
| Anti-rationalization tables | All discipline skills | Include rationalization tables in orchestrator skills |
| Subagent prompt templates | `subagent-driven-development/SKILL.md` | Adopt implementer, spec-reviewer, code-quality-reviewer templates |
| Status codes (DONE/CONCERNS/NEEDS_CONTEXT/BLOCKED) | `subagent-driven-development/SKILL.md` | Adopt with escalation ladder |
| Two-stage review | `subagent-driven-development/SKILL.md` | Spec compliance first, code quality second |
| Zero-context plan format | `writing-plans/SKILL.md` | Plans with exact paths, complete code, exact commands, expected output |
| Plan review loop (max 3 iterations) | `writing-plans/SKILL.md` | Adopt subagent reviewer for plan validation |

### From APM (adopt packaging model)

| Pattern | Source File | What to Adopt |
|---------|------------|---------------|
| Skill folder structure | `primitive-types.md` | Skills as folders with SKILL.md, scripts/, references/ |
| Per-target deployment | `ide-tool-integration.md` | Package orchestrator for Claude, Copilot, Cursor, OpenCode |
| Constitution injection | `compilation/constitution.py` | Leverage for auto-including constitution in compiled output |
| `apm.yml` manifest | `manifest-schema.md` | Declare orchestrator as APM package |

### From gh-aw (adopt workflow patterns)

| Pattern | Source File | What to Adopt |
|---------|------------|---------------|
| Markdown + YAML frontmatter workflows | `workflow-structure.md` | Generate orchestrator workflows in this format |
| `dependencies:` with `isolated: true` | `gh-aw.md` (APM integration) | Declare orchestrator APM package in workflow frontmatter |
| Safe outputs catalog | `safe-outputs.md` | Use for PR creation, comments, labels |
| Slash command triggers | `frontmatter.md` on: slash_command | `/orchestrate`, `/plan-phase`, `/advance-phase` |
| Scheduled workflows | Standard cron syntax | Periodic state machine loop for long-running projects |

---

## 3. Patterns to Adapt

| Pattern | Source | Adaptation Needed |
|---------|--------|-------------------|
| GSD-2 programmatic dispatch (Pi SDK) | `auto.ts`, `auto-dispatch.ts` | Cannot use Pi SDK. Must achieve same effect via markdown command templates + shell scripts. Dispatch quality depends on prompt engineering, not programmatic session control. |
| GSD-2 worktree isolation | `git-strategy.md` | Spec-kit uses feature branches (`###-feature-name`). Adapt worktree model to work with spec-kit's branching convention, or use `none` mode. |
| GSD-2 parallel execution | `parallel-orchestration.md` | Multi-worker coordination requires programmatic IPC (file-based signals). May need to simplify to sequential-only for initial version, with parallel as future enhancement. |
| GSD-2 metrics.json cost tracking | `cost-management.md` | Spec-kit has no cost tracking. Orchestrator must maintain its own execution-log.jsonl. Cannot intercept LLM API calls — must estimate from task duration/token counts if available. |
| Superpowers session-start hook injection | `hooks/hooks.json` | Spec-kit hooks are LLM-mediated markdown instructions, not programmatic SessionStart hooks. Must achieve discipline injection through `before_tasks` and `before_implement` hooks instead. |
| Superpowers subagent dispatch via Agent tool | `subagent-driven-development/SKILL.md` | Not all agents support the Agent tool. Must degrade to sequential in-session execution. Dispatch prompt templates must work both as subagent prompts AND as inline instructions. |

---

## 4. Patterns to Ignore

| Pattern | Source | Why Ignore |
|---------|--------|------------|
| GSD-2 Pi SDK binary / TypeScript runtime | `cli.ts`, `loader.ts` | Orchestrator is a spec-kit extension (markdown + scripts), not a standalone CLI |
| GSD-2 RPC / MCP server mode | `commands.md` | Not applicable to spec-kit extension model |
| GSD-2 VS Code extension / sidebar dashboard | `vscode-extension/` | Out of scope — APM handles IDE distribution |
| GSD-2 provider credential management | `onboarding.ts`, `wizard.ts` | Handled by the host agent (Claude Code, Copilot, etc.) |
| GSD-2 native Rust engine | `native/` | Performance optimization not needed for markdown-based orchestrator |
| Superpowers' Claude-specific plugin format | `.claude-plugin/plugin.json` | APM handles per-target distribution |
| APM compilation for non-Claude targets | `agents_compiler.py` | Only relevant when distributing; not needed at runtime |

---

## 5. Gaps

Where NONE of the 5 repos provide a solution and original design is needed.

### Gap 1: Scope Triage (Tier A/B/C Classification)

None of the repos have a scope evaluator that classifies work into execution tiers. GSD-2 always assumes Tier C (full orchestration). Superpowers always assumes single-context. Spec-kit always assumes single-feature.

**Original design needed**: An `evaluate` command that estimates context budget, decomposability, dependency complexity, and state accumulation to classify work as Tier A (inline), Tier B (phased), or Tier C (full orchestration).

### Gap 2: Spec-Kit Extension Hook Limitations

Spec-kit only provides hooks for `before_tasks`, `after_tasks`, `before_implement`, `after_implement`. There are NO hooks for `before_plan`, `after_plan`, `before_specify`, `after_specify`, `before_clarify`, `after_clarify`.

**Original design needed**: The orchestrator must work within these 4 hook points OR use command composition (orchestrator commands call spec-kit commands internally) to achieve coverage.

### Gap 3: LLM-Mediated vs. Programmatic Dispatch

GSD-2 achieves fresh context per unit programmatically (Pi SDK creates new sessions). Spec-kit extensions operate within LLM sessions via markdown instructions. There is no mechanism in spec-kit to programmatically clear context or create fresh sessions.

**Original design needed**: The orchestrator must achieve context freshness through:
- Instructing the agent to use the Agent tool (subagent dispatch) where available
- Falling back to "close this context and open a new one" instructions where not
- Using shell scripts that invoke the agent CLI externally (e.g., `claude --print` for Claude Code)
- Accepting that context freshness is best-effort in some environments

### Gap 4: Cross-Phase State Aggregation

Spec-kit has no built-in way to aggregate status across multiple feature directories or across phases within a feature. Tasks.md tracks per-task checkboxes but there's no dashboard.

**Original design needed**: `orchestrator-status` skill with scripts that parse `.specify/orchestrator/` state files and output a structured dashboard (progress, cost, blockers, next action).

### Gap 5: Knowledge Consolidation

GSD-2 produces KNOWLEDGE.md and DECISIONS.md incrementally. Superpowers produces no knowledge artifacts. Spec-kit produces no knowledge artifacts. APM's context optimization is for compiled instructions, not runtime knowledge.

**Original design needed**: A `consolidate` command that compresses verbose phase artifacts into optimized summaries, generates codebase-level AGENTS.md-compatible context files, and archives raw artifacts.

### Gap 6: Graceful Degradation Strategy

No repo provides a unified degradation model. GSD-2 requires Pi SDK. Superpowers requires Claude Code Agent tool. gh-aw requires GitHub Actions. APM install requires APM CLI.

**Original design needed**: A capability detection mechanism that checks:
- Can the agent dispatch subagents? (Agent tool available?)
- Can the agent run shell scripts? (Bash tool available?)
- Is this running in gh-aw? (GitHub Actions environment?)
- Is APM available? (apm CLI in PATH?)
And selects the appropriate execution strategy.

---

## 6. Proposed Command Surface

Based on spec-kit extension system constraints (from 01-speckit.md):
- Commands must follow `speckit.<extension-id>.<command-name>` pattern
- At least one command required in extension.yml
- Commands are markdown files in the extension's `commands/` directory

| Command | Purpose | Maps To |
|---------|---------|---------|
| `speckit.orchestrator.evaluate` | Scope triage — classify as Tier A/B/C | Original (Gap 1) |
| `speckit.orchestrator.roadmap` | Break spec into phases with boundary maps | GSD-2 roadmap planning |
| `speckit.orchestrator.plan-phase` | Plan one phase (creates task plan with must-haves) | GSD-2 slice planning |
| `speckit.orchestrator.dispatch` | Execute one unit in fresh context | GSD-2 dispatch + Superpowers subagent |
| `speckit.orchestrator.auto` | State machine loop — dispatch until milestone complete | GSD-2 `/gsd auto` |
| `speckit.orchestrator.status` | Progress dashboard | GSD-2 `/gsd status` |
| `speckit.orchestrator.resume` | Resume from crash/pause | GSD-2 crash recovery |
| `speckit.orchestrator.verify` | Run must-haves verification for a phase | GSD-2 verification + Superpowers verification-before-completion |
| `speckit.orchestrator.consolidate` | Compress knowledge, archive verbose artifacts | Original (Gap 5) |
| `speckit.orchestrator.discuss` | Capture decisions on gray areas | GSD-2 `/gsd discuss` |

### Hook Registrations

| Hook Point | What It Does |
|------------|-------------|
| `before_tasks` | Injects phase-level context if orchestrator is active |
| `after_tasks` | Triggers roadmap generation from tasks.md phases |
| `before_implement` | Injects phase scope enforcement (current phase only) |
| `after_implement` | Triggers phase summary generation and state advancement |

---

## 7. Proposed State File Structure

GSD-2's `.gsd/` adapted for spec-kit's `.specify/` conventions.

```
.specify/orchestrator/
├── STATE.md                           # Derived dashboard (gitignored)
├── DECISIONS.md                       # Append-only register (GSD-2 format)
├── KNOWLEDGE.md                       # Append-only cross-session memory
├── config.json                        # User preferences (tier, profile, verification cmds)
├── execution-log.jsonl                # Append-only dispatch history
├── milestones/
│   └── M001/
│       ├── M001-ROADMAP.md            # Phase plan with boundary maps
│       ├── M001-CONTEXT.md            # User decisions from discuss phase
│       ├── M001-SUMMARY.md            # Milestone rollup
│       └── phases/
│           └── P01/
│               ├── P01-PLAN.md        # Task decomposition with must-haves
│               ├── P01-SUMMARY.md     # Phase summary (structured frontmatter)
│               ├── P01-UAT.md         # Human test script
│               └── tasks/
│                   ├── T01-PLAN.md    # Individual task plan
│                   └── T01-SUMMARY.md # Task summary (14-field frontmatter)
└── archive/                           # Compressed artifacts from consolidation
    └── M001/
        └── P01/                       # Raw phase artifacts moved here
```

**Naming convention change from GSD-2**: "Slice" → "Phase" to align with spec-kit terminology. Prefix pattern: `M###` for milestones, `P##` for phases, `T##` for tasks.

---

## 8. Risk Register

| # | Risk | Impact | Likelihood | Mitigation |
|---|------|--------|------------|------------|
| R1 | LLM-mediated dispatch cannot achieve GSD-2 quality | Context freshness degrades, quality drops on later phases | HIGH | Design dispatch prompts carefully; use Agent tool where available; accept degradation in environments without subagent support |
| R2 | Spec-kit hook limitations (only 4 hook points) | Cannot intercept plan/specify/clarify phases | MEDIUM | Use command composition (orchestrator commands call spec-kit commands) rather than hooks |
| R3 | No programmatic session control in spec-kit | Cannot force fresh context windows | HIGH | Use Agent tool for subagent dispatch; shell script fallback (`claude --print`); document degradation |
| R4 | Cost tracking requires LLM API access | Cannot track token usage in all environments | MEDIUM | Track at dispatch level (timestamps, task IDs) not token level; rely on host agent's cost reporting |
| R5 | Parallel execution complexity | Multi-phase parallel dispatch may cause merge conflicts | MEDIUM | Start with sequential-only; add parallel as future enhancement with git worktree isolation |
| R6 | Extension.yml validation strictness | Command name pattern `^speckit\.[a-z0-9-]+\.[a-z0-9-]+$` limits naming | LOW | All proposed commands fit the pattern |
| R7 | Cross-agent compatibility | Different agents handle markdown commands differently | MEDIUM | Test on Claude Code + Copilot minimum; use agent-agnostic markdown patterns |
| R8 | Knowledge consolidation quality | LLM-generated summaries may lose critical information | MEDIUM | Include coverage verification step; preserve verbatim markers for complex decisions |
| R9 | Scope triage accuracy | Incorrect tier classification wastes effort (over-orchestrating) or loses quality (under-orchestrating) | MEDIUM | Allow user override; support tier promotion mid-execution; default to higher tier when uncertain |
| R10 | Condition evaluation gap in hooks | Hook conditions are NOT evaluated by LLM-side checking | LOW | Use `optional: true` with descriptive prompts; avoid relying on condition expressions |
