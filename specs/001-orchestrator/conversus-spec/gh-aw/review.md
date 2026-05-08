# UTILIZATION.md -- gh-aw Review of speckit-orchestrator Spec

**Reviewer perspective**: GitHub Agentic Workflows (gh-aw) -- Go CLI extension for GitHub Actions enabling autonomous agent dispatch in CI.

**Spec reviewed**: `/spec-kit-orc/specs/001-orchestrator/spec.md`

**Date**: 2026-03-18

---

## 1. Executive Summary

The speckit-orchestrator spec describes a multi-phase autonomous orchestration system that decomposes large projects into milestones, phases, and tasks -- dispatching each to fresh agent contexts with structured handoff. gh-aw provides a mature, production-grade runtime for exactly this kind of autonomous dispatch in CI: it has an orchestrator/worker pattern with `dispatch-workflow` and `call-workflow` safe outputs, persistent memory via repo-memory and cache-memory, concurrency controls, sub-issue hierarchies, Copilot coding agent assignment, and a TaskOps strategy that maps cleanly to the spec's research-plan-execute model. The spec acknowledges CI-based execution in User Story 7 (lines 127-140) but treats it as a "nice-to-have" enhancement rather than a first-class execution runtime, which means the spec's core dispatch and state management design does not take advantage of gh-aw's existing solutions to the same problems.

The fundamental mismatch is that the spec designs its own orchestration primitives from scratch -- custom state machines, lock files, crash recovery, dispatch payloads, and knowledge persistence -- when gh-aw already provides native analogs for most of these: workflow dispatch with input forwarding, repo-memory branches for durable state, concurrency groups for collision avoidance, safe outputs for structured GitHub API operations, and staged mode for dry-run validation. The spec does not mention any of these gh-aw features by name, suggesting either insufficient familiarity with the platform or a deliberate choice to remain runtime-agnostic. Either way, the result is that the CI execution story (US-7) is underspecified and the local execution model reinvents mechanisms that gh-aw already provides in a sandboxed, auditable form.

That said, the spec's architectural instincts are sound: the three-tier classification, phase-level verification gates, knowledge scoping, and boundary maps are all concepts that gh-aw's patterns support but do not prescribe. The spec's value proposition is in the orchestration intelligence (what to dispatch, how to verify, when to escalate), not in the dispatch plumbing itself. The recommendations below focus on wiring the spec's intelligence into gh-aw's existing infrastructure rather than reimplementing the infrastructure.

---

## 2. Alignment (What We're Getting Right)

- **Tiered execution with graceful degradation** (spec lines 14-17, FR-034 at line 269): The spec's Tier A/B/C classification mirrors gh-aw's own design philosophy where simple workflows (`slash_command` + single agent) coexist with complex multi-job orchestration patterns. The spec correctly avoids requiring CI for simple tasks, matching gh-aw's position that not every workflow needs the full dispatch infrastructure. gh-aw reference: `docs/src/content/docs/patterns/orchestration.md` lines 1-10.

- **Fresh context per dispatch unit** (spec FR-012 at line 214, FR-013 at line 215): The spec's requirement that each task dispatches to a fresh agent context with a minimal payload aligns with gh-aw's `dispatch-workflow` model, where each dispatched workflow runs as an independent GitHub Actions run with its own context. gh-aw's `call-workflow` similarly provides scoped execution. gh-aw reference: `docs/src/content/docs/reference/safe-outputs.md` dispatch-workflow section (lines 1062-1148 in the full reference), `docs/src/content/docs/patterns/orchestration.md` lines 16-26.

- **Structured knowledge persistence** (spec FR-024 through FR-027 at lines 250-253): The spec's decisions register, knowledge file, and phase summaries map conceptually to gh-aw's repo-memory system (persistent git branches) and cache-memory (ephemeral cross-run state). The spec recognizes that knowledge must persist across sessions and compound over time, which is the exact use case repo-memory was designed for. gh-aw reference: `docs/src/content/docs/reference/repo-memory.md`, `docs/src/content/docs/guides/memoryops.md`.

- **Mechanical verification before advancing** (spec FR-016, FR-016a at lines 223-224): The spec's insistence on mechanical (not self-assessed) verification at both task and phase boundaries aligns with gh-aw's deterministic-agentic pattern, where deterministic pre/post steps handle validation while the agent handles reasoning. gh-aw reference: `docs/src/content/docs/guides/deterministic-agentic-patterns.md` lines 1-36.

- **CI-based execution acknowledged** (spec US-7 at lines 127-140): The spec correctly identifies that GitHub Agentic Workflows can serve as a CI runtime for unattended orchestration, triggered by schedule, issue creation, or comment commands. This maps directly to gh-aw's trigger model (`schedule`, `issues`, `slash_command`). gh-aw reference: `docs/src/content/docs/patterns/dispatch-ops.md`, `docs/src/content/docs/reference/command-triggers.md`.

- **Idempotency requirement** (spec FR-066 at line 360): The spec's requirement that all orchestrator commands are idempotent is a direct match for how gh-aw workflows should be designed -- especially relevant for scheduled workflows and retry scenarios. gh-aw workflows that use repo-memory must handle "re-run" scenarios gracefully. gh-aw reference: `docs/src/content/docs/guides/memoryops.md` Pattern 1 (Exhaustive Processing) and Pattern 2 (State Persistence).

---

## 3. Missed Opportunities

- **`dispatch-workflow` safe output for task dispatch** (gh-aw: `docs/src/content/docs/reference/safe-outputs.md` dispatch-workflow section, `docs/src/content/docs/patterns/orchestration.md` lines 16-26; spec: FR-013 at line 215, FR-014 at line 216): The spec designs a custom dispatch mechanism where the orchestrator constructs a context payload and spawns a fresh agent context. In gh-aw, this is exactly what `dispatch-workflow` does -- it triggers a worker workflow with a JSON payload, compile-time validates the target, and runs asynchronously. The spec never mentions this capability, forcing implementers to build dispatch plumbing from scratch rather than declaring `safe-outputs: dispatch-workflow: [phase-worker, task-worker]` and letting gh-aw handle the rest.

- **`call-workflow` for synchronous phase execution** (gh-aw: `docs/src/content/docs/reference/safe-outputs.md` call-workflow section; spec: FR-015 at line 217, FR-016a at line 224): For the two-stage review (spec compliance then code quality), `call-workflow` provides compile-time fan-out where the review workflow runs as part of the same GitHub Actions run, preserving actor attribution and enabling the orchestrator to gate on the review result before advancing. The spec's review model at phase boundaries maps directly to a `call-workflow` invocation of a review worker.

- **`create-agent-session` for Copilot coding agent dispatch** (gh-aw: `docs/src/content/docs/reference/safe-outputs.md` create-agent-session section, `docs/src/content/docs/reference/assign-to-copilot.mdx`; spec: FR-013 at line 215, US-3 at lines 54-71): The spec describes dispatching tasks to fresh agent contexts but does not consider gh-aw's `create-agent-session` or `assign-to-agent` safe outputs, which can programmatically spawn Copilot coding agent sessions on issues. For Tier C projects, the orchestrator could create task issues and assign them to Copilot, getting both fresh context isolation and PR-based output -- a natural fit for the spec's autonomous dispatch model that requires no custom dispatch infrastructure.

- **Repo-memory for durable orchestrator state** (gh-aw: `docs/src/content/docs/reference/repo-memory.md`; spec: FR-019 at line 230, FR-020 at line 231): The spec stores all state under `.specify/orchestrator/` in the working tree and relies on git for persistence. In a CI context, the working directory is ephemeral. gh-aw's repo-memory provides persistent git-branch-backed storage at `/tmp/gh-aw/repo-memory-{id}/` with automatic commit/push after workflow completion, merge conflict resolution, and file validation. The spec's decisions register, knowledge file, execution log, and phase summaries could all live in a repo-memory branch, giving CI runs durable access without requiring manual git operations in the workflow.

- **Concurrency controls for autonomous mode** (gh-aw: `docs/src/content/docs/reference/concurrency.md`; spec: FR-053 at line 329): The spec's concurrent access safety requirement (status queries from a second terminal during autonomous mode) is handled in gh-aw by per-workflow and per-engine concurrency groups. The spec does not leverage `concurrency.job-discriminator` for fan-out scenarios where multiple tasks dispatch concurrently, nor does it consider the safe-outputs concurrency group for serializing state writes. These are solved problems in gh-aw.

- **Sub-issue hierarchies for work decomposition** (gh-aw: `docs/src/content/docs/patterns/issue-ops.md` lines 74-101, `docs/src/content/docs/reference/safe-outputs.md` link-sub-issue section; spec: FR-004 at line 197): The spec defines a three-level work hierarchy (milestone > phase > task) but does not consider mapping this to GitHub's native sub-issue feature via gh-aw's `create-issue` with `parent` field and `link-sub-issue` safe output. This would give the orchestrator's work hierarchy a native GitHub representation -- milestones as parent issues, phases as sub-issues, tasks as sub-sub-issues -- enabling project board tracking, assignment to Copilot, and cross-repository visibility without custom state files.

- **GitHub Projects for progress tracking** (gh-aw: `docs/src/content/docs/patterns/monitoring.md`; spec: FR-038 at line 275, FR-039 at line 276): The spec requires a progress overview derivable from disk state, but does not consider using gh-aw's `update-project` safe output to maintain a GitHub Projects board as the orchestrator's progress dashboard. Custom fields (phase status, blocker count, risk level) would give the spec's status command a visual, collaborative representation beyond terminal output.

- **TaskOps strategy alignment** (gh-aw: `docs/src/content/docs/patterns/task-ops.md`; spec: US-2 at lines 33-51, US-3 at lines 54-71): gh-aw's TaskOps pattern (Research -> Plan -> Assign) maps almost directly to the spec's Tier C flow (discuss -> plan -> execute). The spec does not reference TaskOps at all, missing an opportunity to ground its design in a proven gh-aw pattern. TaskOps already handles the research-to-issue-to-Copilot pipeline that the spec is reinventing with custom dispatch.

- **Staged mode for dry-run verification** (gh-aw: `docs/src/content/docs/reference/staged-mode.md`; spec: FR-016 through FR-018 at lines 223-226): The spec's verification ladder (static -> command -> behavioral -> human) does not consider gh-aw's staged mode, which allows workflows to preview their safe outputs without executing them. For the spec's two-stage review, staged mode could serve as a pre-flight check: run the review workflow in staged mode, inspect what it would produce, then re-run with staging disabled. This provides a built-in dry-run capability the spec otherwise has to engineer.

---

## 4. Off-Base Assumptions

- **CI execution as a secondary concern** (spec US-7 at lines 127-140, priority P7): The spec treats GitHub Agentic Workflows as an optional enhancement with the lowest priority before APM packaging. In practice, gh-aw's CI-based execution model is the natural home for Tier C autonomous dispatch -- it provides sandboxed execution, durable state (repo-memory), concurrency controls, and GitHub API integration that local execution must simulate. Designing the orchestrator core for local-first execution and then bolting on CI support leads to impedance mismatches: the spec's lock-file crash recovery, for instance, is unnecessary in CI where each workflow run is a discrete, auditable unit. The assumption should be reversed: design for CI dispatch as the primary autonomous runtime, with local execution as the development/debugging mode.

- **Custom dispatch plumbing vs. gh-aw's workflow dispatch** (spec FR-012 at line 214, FR-013 at line 215): The spec assumes the orchestrator must construct context payloads, manage dispatch, and verify completion itself. In gh-aw, `dispatch-workflow` handles payload delivery, `workflow_dispatch.inputs` provides typed input forwarding, compile-time validation ensures target workflows exist, and GitHub Actions' native run status provides completion tracking. The spec's dispatch model works locally but ignores that gh-aw already solves the CI dispatch problem with security guardrails (allowlisting, rate limiting) the spec does not address.

- **File-based state as the only persistence mechanism** (spec FR-019 at line 230): The spec mandates that all state lives under `.specify/orchestrator/` as regular files in the working tree. This is correct for local execution but ignores that gh-aw provides two purpose-built persistence mechanisms: repo-memory (unlimited retention, version controlled, git-branch-backed) and cache-memory (7-day retention, fast, cross-workflow). In CI, the working directory is ephemeral -- state files must be committed back explicitly. gh-aw's memory tools handle this automatically. The spec should specify how `.specify/orchestrator/` state maps to repo-memory branches when running in CI, rather than leaving it to the implementer to figure out.

---

## 5. Actionable Recommendations

1. **Map the work hierarchy to GitHub sub-issues**: Define a gh-aw workflow that uses `create-issue` with `temporary_id` and `parent` fields to create the milestone/phase/task hierarchy as GitHub issues. This gives the orchestrator's state a native GitHub representation, enables assignment to Copilot via `assignees: copilot`, and provides visibility through GitHub Projects. Reference: `docs/src/content/docs/patterns/issue-ops.md` lines 74-101, `docs/src/content/docs/reference/safe-outputs.md` issue creation with temporary IDs (lines 478-483 in the full reference).

2. **Use `dispatch-workflow` as the CI dispatch primitive**: For Tier C autonomous execution in CI, define a `task-worker.md` agentic workflow that accepts the task payload via `workflow_dispatch.inputs` and executes a single task. The orchestrator workflow uses `dispatch-workflow: [task-worker]` to fan out tasks. This eliminates custom dispatch plumbing and provides compile-time validation, rate limiting, and GitHub Actions audit trails. Reference: `docs/src/content/docs/reference/safe-outputs.md` dispatch-workflow section, `docs/src/content/docs/patterns/orchestration.md`.

3. **Use repo-memory for durable orchestrator state in CI**: Create a repo-memory configuration that maps to the spec's state directories: `memory/orchestrator-decisions` for DECISIONS.md, `memory/orchestrator-knowledge` for KNOWLEDGE.md, `memory/orchestrator-state` for the execution log and phase summaries. Each workflow run reads state from the memory branch, makes changes, and auto-commits on completion. This eliminates the need for manual git operations and crash-recovery lock files in CI. Reference: `docs/src/content/docs/reference/repo-memory.md`, `docs/src/content/docs/guides/memoryops.md`.

4. **Use `call-workflow` for synchronous phase reviews**: Define `spec-compliance-review.md` and `code-quality-review.md` as reusable workflows (`workflow_call` trigger) and invoke them via `call-workflow` at phase boundaries. This runs the review as part of the same workflow run (preserving actor context), provides typed input forwarding for the phase plan, and enables the orchestrator to gate on the review result before advancing. Reference: `docs/src/content/docs/reference/safe-outputs.md` call-workflow section, `docs/src/content/docs/patterns/orchestration.md` lines 29-42.

5. **Use `create-agent-session` or `assign-to-agent` for task execution**: Instead of custom dispatch to "fresh agent contexts," leverage gh-aw's ability to create Copilot coding agent sessions or assign Copilot to task issues. Each task issue contains the task plan as its body; Copilot produces a PR. The orchestrator workflow monitors PR creation, runs verification, and advances. This provides natural isolation, PR-based output, and human review integration. Reference: `docs/src/content/docs/reference/safe-outputs.md` create-agent-session section, `docs/src/content/docs/reference/assign-to-copilot.mdx`.

6. **Use `update-project` for progress dashboards**: Add a `update-project` safe output to orchestrator workflows that maintains a GitHub Projects board with custom fields for phase status, risk level, blocker count, and completion percentage. This replaces the spec's terminal-only progress overview (FR-038) with a persistent, collaborative dashboard. Reference: `docs/src/content/docs/patterns/monitoring.md`.

7. **Use concurrency groups to replace lock files in CI**: The spec's lock file mechanism (FR-021 at line 244) is designed for local execution where multiple processes might collide. In CI, gh-aw's per-workflow concurrency groups prevent concurrent runs of the same orchestrator workflow, and `job-discriminator` enables safe fan-out. Replace the lock file requirement with a CI-mode concurrency configuration. Reference: `docs/src/content/docs/reference/concurrency.md`.

8. **Elevate US-7 (CI execution) to P2 or P3**: The spec's current P7 priority for CI execution means the core architecture will be optimized for local execution and may require significant rework to support CI dispatch. Since Tier C autonomous execution is the primary value proposition, and gh-aw provides the most robust runtime for it, CI execution should be a design consideration from the start -- not an afterthought. At minimum, the spec should include CI dispatch as an acceptance scenario for US-3 (Autonomous Dispatch).

9. **Adopt the slash_command trigger for interactive orchestration**: The spec's `discuss` command (FR-056 at line 325) and decision injection (FR-052 at line 321) map naturally to gh-aw's `slash_command` trigger. A `/orchestrate discuss` or `/orchestrate inject` command in a GitHub issue would trigger the orchestrator workflow, with the issue body providing the input. This gives the orchestrator a native ChatOps interface for CI-based execution. Reference: `docs/src/content/docs/reference/command-triggers.md`, `docs/src/content/docs/patterns/chat-ops.md`.

10. **Leverage SpecOps pattern for specification propagation**: The spec currently does not describe how the orchestrator's spec artifacts (spec.md, plan.md, boundary maps) propagate to implementation. gh-aw's SpecOps pattern provides a proven model: specification updates trigger propagation workflows that create implementation PRs in consuming repositories. For a monorepo, this could propagate boundary map changes from phase N to phase N+1's planning workflow. Reference: `docs/src/content/docs/patterns/spec-ops.md`.

---

## 6. Referenced gh-aw Documentation

| Document | Path (relative to gh-aw root) |
|----------|-------------------------------|
| README.md | `README.md` |
| AGENTS.md | `AGENTS.md` |
| DEVGUIDE.md | `DEVGUIDE.md` |
| Workflow creation guide | `create.md` |
| Full frontmatter reference | `.github/aw/github-agentic-workflows.md` |
| Orchestration pattern | `docs/src/content/docs/patterns/orchestration.md` |
| TaskOps pattern | `docs/src/content/docs/patterns/task-ops.md` |
| DispatchOps pattern | `docs/src/content/docs/patterns/dispatch-ops.md` |
| DailyOps pattern | `docs/src/content/docs/patterns/daily-ops.md` |
| MultiRepoOps pattern | `docs/src/content/docs/patterns/multi-repo-ops.md` |
| SpecOps pattern | `docs/src/content/docs/patterns/spec-ops.md` |
| ChatOps pattern | `docs/src/content/docs/patterns/chat-ops.md` |
| IssueOps pattern | `docs/src/content/docs/patterns/issue-ops.md` |
| Projects and monitoring | `docs/src/content/docs/patterns/monitoring.md` |
| Safe outputs reference | `docs/src/content/docs/reference/safe-outputs.md` |
| Repo memory reference | `docs/src/content/docs/reference/repo-memory.md` |
| Cache memory reference | `docs/src/content/docs/reference/cache-memory.md` |
| Concurrency reference | `docs/src/content/docs/reference/concurrency.md` |
| Engines reference | `docs/src/content/docs/reference/engines.md` |
| Command triggers reference | `docs/src/content/docs/reference/command-triggers.md` |
| Triggers reference | `docs/src/content/docs/reference/triggers.md` |
| Staged mode reference | `docs/src/content/docs/reference/staged-mode.md` |
| Assign to Copilot reference | `docs/src/content/docs/reference/assign-to-copilot.mdx` |
| MemoryOps guide | `docs/src/content/docs/guides/memoryops.md` |
| Deterministic-agentic patterns | `docs/src/content/docs/guides/deterministic-agentic-patterns.md` |
