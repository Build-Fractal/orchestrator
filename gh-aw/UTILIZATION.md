# gh-aw Utilization Review -- speckit-orchestrator

## Executive Summary

The speckit-orchestrator spec correctly identifies gh-aw as an optional CI execution layer for unattended orchestration (spec line 237), but treats it as a thin "optional" appendix rather than deeply integrating with gh-aw's existing orchestration primitives. gh-aw already provides a mature orchestrator/worker dispatch pattern (`call-workflow`, `dispatch-workflow`), persistent cross-run memory (`cache-memory`, `repo-memory`), structured safe-output verification, campaign pacing controls, and a three-phase TaskOps strategy (research/plan/assign) -- all of which directly map to speckit-orchestrator concepts but are never referenced. The spec risks building parallel infrastructure that gh-aw already solves at the CI layer.

## Alignment (What We Are Getting Right)

- **Optional CI integration acknowledged.** The spec explicitly states that the orchestrator "can optionally run as a GitHub Agentic Workflow, triggered by schedule, issue creation, or comment command" (spec line 237-238). This correctly maps to gh-aw's `schedule`, `issues`, and `slash_command` triggers documented in `.github/aw/github-agentic-workflows.md` (lines 80-83).

- **Local-first with CI as an opt-in layer.** The spec mandates "All functionality works locally without degradation when GitHub workflows aren't available" (spec line 238). This aligns with gh-aw's design philosophy where the CLI (`gh aw compile`, `gh aw run`) works entirely locally and CI is only the deployment target.

- **Disk-state-as-truth philosophy.** The spec's principle that "No in-memory state survives across sessions" and "orchestrator derives its complete state by reading files on disk" (spec lines 122-123) is compatible with how gh-aw workflows operate -- each run is stateless, with `cache-memory` and `repo-memory` providing the persistence layer between runs. See `docs/src/content/docs/patterns/orchestration.md` (line 6): "Use this pattern when one workflow (the orchestrator) needs to fan out work to one or more worker workflows."

- **Tiered complexity model.** The three-tier classification (A: single context, B: structured handoff, C: full orchestration) at spec lines 24-32 maps well to gh-aw's natural layering: Tier A maps to a single agentic workflow, Tier B maps to a campaign workflow with `cache-memory`, and Tier C maps to the orchestrator/worker pattern with `call-workflow` or `dispatch-workflow`.

## Missed Opportunities

- **`call-workflow` safe output is the natural Tier C dispatch primitive.** The spec describes "dispatch to fresh agent context" (spec line 83) and an autonomous dispatch loop (spec lines 77-91), but never references gh-aw's `call-workflow` safe output which does exactly this at the CI layer. `call-workflow` generates static conditional `uses:` jobs at compile time where "the agent selects which worker to activate; the compiler validates and wires up all fan-out jobs" (`.github/aw/github-agentic-workflows.md`, line 893). This is purpose-built for the orchestrator-selects-worker pattern the spec describes. A concrete smoke test already exists at `.github/workflows/smoke-call-workflow.md`.

- **`dispatch-workflow` for async task dispatch.** For tasks that should run independently and outlive the orchestrator run (more aligned with the spec's "start and walk away" model at spec line 91), `dispatch-workflow` triggers other agentic workflows asynchronously with JSON payloads (`.github/aw/github-agentic-workflows.md`, lines 875-882). The spec's dispatch loop could use `dispatch-workflow` for fire-and-forget task execution with `max: 3` controlling blast radius. An example lives at `.github/workflows/test-dispatcher.md`.

- **`cache-memory` is the knowledge persistence layer the spec is designing from scratch.** The spec's Knowledge File (spec line 161), Decisions Register (spec line 157), and Phase Summaries (spec line 153) could all be implemented as structured JSON files persisted via gh-aw's `cache-memory` tool, which "Mounts a memory MCP server at `/tmp/gh-aw/cache-memory/` that persists across workflow runs" (`.github/aw/github-agentic-workflows.md`, lines 1296-1297). Multiple named caches (lines 1284-1293) allow separate persistence for decisions, knowledge, and phase summaries. The spec never mentions this existing mechanism.

- **`repo-memory` for durable cross-milestone knowledge.** For knowledge consolidation (spec lines 165-166) that should survive beyond cache TTL, gh-aw's `repo-memory` provides git-backed persistent storage on an orphan branch (`.github/aw/github-agentic-workflows.md`, lines 1331-1349). This maps directly to the spec's "compressed milestone summaries" that "Future sessions read the compressed summary first and drill down to archived details only when needed" (spec line 166). The spec could use `repo-memory` for consolidated milestone artifacts and `cache-memory` for active-session state.

- **Campaign pacing controls map to the spec's safety guardrails.** The spec's dispatch and duration budgets (spec line 192) and destructive operation warnings (spec line 198) have direct analogs in gh-aw's campaign design pattern at `.github/aw/campaign.md`: `concurrency` groups for mutual exclusion (line 31), `safe-outputs.*.max` for output caps (line 33), `stop-after` for hard deadlines (line 32), and `rate-limit` for per-user throttling (`.github/aw/github-agentic-workflows.md`, lines 209-213). None of these are referenced in the spec's P7 (GitHub Workflows) user story.

- **TaskOps is a proven three-phase pattern gh-aw already documents.** The spec's research-plan-execute cycle maps closely to gh-aw's TaskOps strategy documented at `docs/src/content/docs/patterns/task-ops.md`: Phase 1 (Research agent investigates), Phase 2 (Planner creates scoped issues), Phase 3 (Issues assigned to Copilot for execution). The spec's Tier B "developer drives each step transition manually" (spec line 40) is essentially TaskOps with human gates.

- **`create-agent-session` / `assign-to-agent` for delegating implementation tasks.** The spec's task dispatch to "fresh agent contexts" (spec line 83) could leverage gh-aw's `create-agent-session` safe output to spin up Copilot coding agent sessions, or `assign-to-agent` to assign issues to Copilot for automated implementation (`.github/aw/github-agentic-workflows.md`, lines 908-927). These are existing mechanisms for the exact "dispatch to fresh agent context" the spec describes.

- **Projects and monitoring for orchestrator status.** The spec requires "Progress queryable from a second terminal in under 5 seconds" (spec line 259). When running as a GitHub workflow, gh-aw's `update-project` safe output (`docs/src/content/docs/patterns/monitoring.md`, lines 17-30) and `create-project-status-update` (lines 34-46) provide a GitHub Projects dashboard that is inherently queryable from any browser or terminal. The spec could specify Projects integration as the CI-mode status mechanism.

- **Verification via `steps:` pre/post hooks.** The spec's per-task verification (spec lines 100-109) -- running lint, test, build at boundaries -- maps to gh-aw's `steps:` (pre-execution deterministic steps) and `post-steps:` (post-execution cleanup) documented in `.github/aw/github-agentic-workflows.md` (line 152-153). These run outside the agent sandbox with full shell access, ideal for mechanical verification commands.

## Off-Base Assumptions

- **"Single-job execution model" is a hard constraint the spec underestimates.** The spec assumes that a GitHub Agentic Workflow can manage a multi-phase loop (read state, dispatch, verify, advance, repeat) within a single run. gh-aw's own documentation explicitly warns: "Agentic workflows execute as a single GitHub Actions job with the AI agent running once" and lists what they CANNOT do, including "Cross-job state management" and "Multi-stage orchestration" (`.github/aw/create-agentic-workflow.md`, lines 131-149). The spec's Tier C autonomous dispatch loop (spec lines 77-91) -- a looping state machine that dispatches tasks sequentially and verifies each -- cannot run as described within a single agentic workflow run. It requires either: (a) a traditional GitHub Actions workflow with matrix jobs and dependencies, (b) a scheduled workflow that advances one phase per run using `cache-memory` to track state, or (c) the `call-workflow` fan-out pattern where the orchestrator selects one worker per invocation.

- **Lock files and PID-based crash detection are not viable in CI.** The spec describes lock files with PID checking and stale detection (spec lines 172-173). GitHub Actions runners are ephemeral -- there is no persistent PID space, and a "crashed" workflow simply does not exist on any machine after it fails. In CI, crash recovery should instead be implemented via workflow run status checks (the `gh run view` API), re-trigger via `workflow_dispatch`, and state recovery from `cache-memory` artifacts. The spec's local crash recovery model does not translate to CI without significant adaptation.

- **"Concurrent access from a second terminal" does not apply in CI.** The spec assumes a developer can "check status, inject decisions, or steer the project without interrupting execution" from a second terminal (spec line 91). In a GitHub Actions context, the equivalent is: (a) GitHub Projects dashboard for status, (b) `slash_command` triggers or issue comments for decision injection, (c) `workflow_dispatch` with inputs for steering. These are fundamentally different interaction models than filesystem concurrency. The spec's `continue.md` file (spec line 220) for pause/resume would need to be a `cache-memory` artifact or `repo-memory` file, not a local filesystem artifact.

- **Phase scope enforcement at the filesystem level is insufficient in CI.** The spec's "agents are restricted to files declared in the phase plan" (spec line 197) assumes filesystem-level enforcement. In gh-aw, the Agent Workflow Firewall (AWF) sandbox provides network egress controls but does not restrict which files the agent can read/write within the workspace. File scope enforcement would need to be implemented in the agent's prompt instructions and verified mechanically in `post-steps:`, not relied upon as a sandbox guarantee.

## Actionable Recommendations

1. **Map Tier C dispatch to `call-workflow` + `dispatch-workflow`.** Revise spec lines 75-91 (Autonomous Dispatch) to specify that when running as a gh-aw workflow, the dispatch loop uses `call-workflow` for synchronous worker execution (when the orchestrator needs results before advancing) and `dispatch-workflow` for async fire-and-forget tasks. Reference `docs/src/content/docs/patterns/orchestration.md` (lines 14-46) for the established orchestrator/worker pattern.

2. **Adopt `cache-memory` as the CI-mode state persistence layer.** Revise spec lines 206-224 (File Structure and Key Artifacts) to specify that when running in CI, the `.specify/orchestrator/` artifact tree is persisted as structured JSON files in gh-aw `cache-memory` (multiple named caches: one for roadmap, one for decisions, one for execution log). Reference `.github/aw/github-agentic-workflows.md` lines 1267-1327 for configuration.

3. **Use `repo-memory` for knowledge consolidation.** Revise spec lines 165-166 (Knowledge Consolidation) to specify that compressed milestone summaries are stored via `repo-memory` on a dedicated orphan branch (e.g., `memory/orchestrator`). This provides git-backed, version-controlled knowledge that survives cache eviction. Reference `.github/aw/github-agentic-workflows.md` lines 1329-1349.

4. **Replace PID-based crash recovery with workflow-run-status recovery.** Revise spec lines 168-178 (Crash Recovery) to define a CI-specific recovery model: on each scheduled trigger, the orchestrator checks the status of its last run via `gh run list` / `gh run view`, reads the last-known state from `cache-memory`, and resumes from the last completed phase. Remove references to PID files and stale lock detection for the CI execution path.

5. **Map the spec's verification model to `steps:` / `post-steps:`.** Revise spec lines 100-109 (Per-Task Verification) to specify that configurable verification commands (lint, test, build) run in gh-aw's `post-steps:` block, which executes deterministic commands outside the agent sandbox. Reference `.github/aw/github-agentic-workflows.md` line 153.

6. **Use `stop-after` and `concurrency` for budget enforcement.** Revise spec line 192 (Dispatch and duration budgets) to map directly to gh-aw's `on.stop-after` for absolute/relative time deadlines and `concurrency` groups for preventing overlapping runs. Reference `.github/aw/campaign.md` lines 28-35 for the established pacing pattern.

7. **Define status querying via GitHub Projects, not filesystem polling.** Revise the "Progress queryable from a second terminal in under 5 seconds" requirement (spec line 259) to specify that in CI mode, progress is tracked via `update-project` and `create-project-status-update` safe outputs on a GitHub Projects board. Reference `docs/src/content/docs/patterns/monitoring.md` lines 15-46.

8. **Adopt the one-phase-per-run model for Tier C CI execution.** The spec's autonomous dispatch loop cannot run as a single agentic workflow due to the single-job execution model constraint. Revise the CI integration section (spec lines 236-238, currently one paragraph) to specify a scheduled-trigger model: each scheduled run advances one phase, persists state to `cache-memory`, and exits. The next scheduled trigger picks up where the last left off. This is the campaign pattern documented in `.github/aw/campaign.md` lines 1-36. Reference the "Goal-aware early exit" pattern at `.github/aw/campaign.md` lines 64-98 for the deterministic pre-check + agentic work model.

9. **Reference the TaskOps pattern as Tier B's CI implementation.** Revise spec lines 38-41 (Tier B) to reference gh-aw's TaskOps strategy for the CI execution path: research agent generates the phase plan, developer reviews and approves, issues are assigned to Copilot agents for execution. Reference `docs/src/content/docs/patterns/task-ops.md` lines 1-54.

10. **Expand the P7 user story from one paragraph to a full CI integration design.** The spec's P7 (GitHub Workflows, spec line 277) is a single row in a priority table with no detail. Given that gh-aw has at least 10 directly relevant capabilities (dispatch, caching, projects, verification, pacing, agent sessions, TaskOps, campaign patterns, monitoring, slash commands), P7 deserves a dedicated section specifying which gh-aw primitives map to which orchestrator concepts, what adaptations are needed for the single-job model, and what the scheduled-run state machine looks like.

## Referenced gh-aw Documentation

- `/Users/business-daddy/code/payer-index-mono/gh-aw/AGENTS.md` -- Agent definitions and skill references
- `/Users/business-daddy/code/payer-index-mono/gh-aw/DEVGUIDE.md` -- Development guide, build system, CLI patterns
- `/Users/business-daddy/code/payer-index-mono/gh-aw/.github/aw/github-agentic-workflows.md` -- Complete frontmatter schema, safe outputs, triggers, tools, campaign patterns
- `/Users/business-daddy/code/payer-index-mono/gh-aw/.github/aw/campaign.md` -- Campaign workflow design patterns, pacing, KPI workflows
- `/Users/business-daddy/code/payer-index-mono/gh-aw/.github/aw/create-agentic-workflow.md` -- Workflow creator including single-job execution model constraints
- `/Users/business-daddy/code/payer-index-mono/gh-aw/.github/agents/agentic-workflows.agent.md` -- Dispatcher agent for workflow creation/debugging/upgrade
- `/Users/business-daddy/code/payer-index-mono/gh-aw/docs/src/content/docs/patterns/orchestration.md` -- Orchestrator/worker pattern documentation
- `/Users/business-daddy/code/payer-index-mono/gh-aw/docs/src/content/docs/patterns/task-ops.md` -- TaskOps three-phase strategy
- `/Users/business-daddy/code/payer-index-mono/gh-aw/docs/src/content/docs/patterns/monitoring.md` -- Projects and monitoring pattern
- `/Users/business-daddy/code/payer-index-mono/gh-aw/docs/src/content/docs/patterns/dispatch-ops.md` -- Manual dispatch via workflow_dispatch
- `/Users/business-daddy/code/payer-index-mono/gh-aw/.github/workflows/test-dispatcher.md` -- Example dispatch-workflow usage
- `/Users/business-daddy/code/payer-index-mono/gh-aw/.github/workflows/smoke-call-workflow.md` -- Example call-workflow orchestrator
- `/Users/business-daddy/code/payer-index-mono/gh-aw/skills/gh-agent-task/SKILL.md` -- Agent task/session creation skill
- `/Users/business-daddy/code/payer-index-mono/gh-aw/pkg/workflow/compiler_orchestrator.go` -- Compiler orchestrator module structure
- `/Users/business-daddy/code/payer-index-mono/gh-aw/pkg/workflow/compiler_orchestrator_workflow.go` -- Workflow compilation orchestration
