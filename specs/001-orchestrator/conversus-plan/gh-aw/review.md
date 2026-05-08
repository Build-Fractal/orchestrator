# gh-aw Review: Speckit-Orchestrator Implementation Plan

**Reviewer**: gh-aw (GitHub Agentic Workflows)
**Perspective**: CI dispatch, workflow automation, repo-memory, concurrency
**Date**: 2026-03-19
**Artifacts Reviewed**: data-model.md, plan.md, quickstart.md, research.md

---

## Executive Summary

The speckit-orchestrator plan presents a well-structured, file-based state machine for multi-phase autonomous work orchestration. From the gh-aw perspective, the runtime adapter interface (AD-3) is the critical integration surface. The plan correctly identifies the need for a `gh-aw-ci` adapter with batch dispatch, concurrency control, and state persistence capabilities (research.md, R-003). However, the adapter specification is underspecified in ways that will cause real friction at implementation time: the 5-operation interface maps poorly onto gh-aw's actual dispatch primitives (`dispatch-workflow` and `call-workflow` safe outputs), the plan ignores gh-aw's compilation model (frontmatter changes require `gh aw compile`), and the state persistence strategy for ephemeral CI runners has no concrete design. The orchestrator's disk-state-is-truth principle (AD-2) is fundamentally sound but needs explicit bridging to gh-aw's artifact-based and repo-memory persistence mechanisms. The plan also misses several gh-aw capabilities that would directly benefit orchestrator workflows: staged mode for safe verification previews, deterministic precomputation steps, fan-out concurrency discriminators, and the MemoryOps patterns for cross-run state management.

---

## Alignment

- **AD-2 (Disk State is Truth) aligns with gh-aw's repo-memory model.** The orchestrator's `.specify/orchestrator/` state tree maps naturally to gh-aw's `repo-memory` branches, which provide unlimited-retention, version-controlled, persistent file storage on Git branches -- exactly the durability guarantee the orchestrator needs across ephemeral CI runs (repo-memory.md: "persistent file storage via Git branches with unlimited retention").

- **AD-3 (Runtime Adapter Interface) correctly anticipates gh-aw's capability profile.** The `gh-aw-ci` adapter row in research.md R-003 lists `batch_dispatch`, `concurrency_control`, and `persist_state` as optional capabilities -- all three map to real gh-aw features: `dispatch-workflow` with `max:` for batch, `concurrency.job-discriminator` for fan-out isolation (concurrency.md lines 86-119), and `repo-memory` for persistence.

- **The execution-log.jsonl append-only format aligns with gh-aw's MemoryOps JSONL best practice.** The `execution-log.jsonl` format (data-model.md line 283) matches the exact pattern recommended for time-series data in gh-aw workflows (memoryops.md: "Append-only format ideal for logs and metrics").

- **AD-8 (Mechanical Verification Protocol) maps to gh-aw's deterministic + agentic pattern.** The verification ladder (static checks then command checks then behavioral then human) mirrors gh-aw's architecture of deterministic precomputation steps feeding into agentic reasoning (deterministic-agentic-patterns.md: "Combine deterministic steps with AI agents to precompute data, filter triggers, preprocess inputs").

- **The config precedence model (R-004) mirrors gh-aw's environment variable hierarchy.** The 4-level config precedence (env vars > local override > project config > extension defaults) directly parallels gh-aw's most-specific-wins env var model (environment-variables.md lines 126-142).

- **Lock file crash recovery (R-007) is compatible with gh-aw's concurrency serialization.** The lock file + stale PID detection model works alongside gh-aw's per-engine concurrency groups that already prevent concurrent agent execution (`gh-aw-{engine-id}` groups, concurrency.md lines 26-33).

---

## Missed Opportunities

1. **No use of gh-aw's `staged: true` safe-output mode for verification dry runs.** The verification ladder (research.md R-006) defines static, command, behavioral, and human tiers but never considers gh-aw's staged mode, which previews all safe-output operations without execution (staged-mode.md: "Every write operation is skipped; instead, a detailed preview appears in the GitHub Actions step summary"). A `verify` command running in CI could use staged mode to preview what the orchestrator would produce (issues, PRs, status updates) before committing to execution -- a natural "behavioral verification" tier for CI.

2. **No concrete mapping of the 5 adapter operations to gh-aw dispatch primitives.** The adapter interface defines `dispatch-task`, `await-completion`, `collect-result`, `signal-failure`, `inject-context` (research.md R-003), but gh-aw has exactly two dispatch mechanisms: `dispatch-workflow` (asynchronous, independent runs) and `call-workflow` (synchronous, same-run fan-out) (orchestration.md lines 16-46). The plan never specifies which one the adapter should use, or whether different task types demand different dispatch modes. This is a blocking design gap for implementation.

3. **gh-aw's compilation requirement is invisible in the plan.** Every gh-aw workflow frontmatter change requires `gh aw compile` to regenerate `.lock.yml` files (compilation-process.md: "Compilation is only required when changing frontmatter configuration"). The orchestrator's `dispatch` command will need to either use pre-compiled worker workflows or dynamically generate workflows -- neither path is addressed. If the orchestrator dynamically generates dispatch payloads as markdown prompts, the markdown body can be edited without recompilation, but any frontmatter changes (permissions, tools, safe-outputs) require a compile step. This constraint should be documented in the adapter contract.

4. **No exploitation of gh-aw's deterministic precomputation steps for state derivation.** The plan's `derive-phase.sh` script (research.md R-002) is a deterministic operation that reads disk and outputs state. In gh-aw, this maps perfectly to an `on.steps:` precomputation that runs before the agent, passing the derived state as a job output that gates or parameterizes the agent's behavior (deterministic-agentic-patterns.md lines 97-160). This would avoid burning an AI engine invocation just to run a shell script.

5. **The `orchestrator.lock` file has no CI-specific persistence strategy.** The lock file (data-model.md lines 237-249) assumes filesystem persistence (`pid`, `startedAt`), but gh-aw runners are ephemeral -- each workflow run gets a fresh filesystem. The plan mentions `persist_state` as an adapter capability but provides zero specification for how the lock file survives across CI runs. gh-aw's `repo-memory` (auto-commit/push on completion) or `cache-memory` (7-day retention, faster) are the natural bridges, but neither is referenced.

6. **Fan-out concurrency for parallel task dispatch is unaddressed.** The plan supports up to 7 tasks per phase (data-model.md line 93) and the adapter declares `batch_dispatch` capability (research.md R-003), but never addresses the gh-aw concurrency collision problem: when multiple workflow instances are dispatched concurrently, static concurrency groups cause cancellations. gh-aw solves this with `concurrency.job-discriminator` (concurrency.md lines 86-119). The adapter must use `${{ inputs.task_id }}` as a discriminator, or every batch-dispatched task will cancel the previous one.

7. **No mention of gh-aw's protected files policy for orchestrator state commits.** If the orchestrator creates PRs or pushes branches containing `.specify/orchestrator/` state files, and if `CLAUDE.md` or `AGENTS.md` exists at the repo root, gh-aw's protected-files enforcement will block the push by default (safe-outputs-pull-requests.md lines 118-223). The adapter must either configure `protected-files: allowed` or use `allowed-files` patterns to whitelist orchestrator state paths.

8. **The `dispatch-budget` and `duration_budget` config fields have no CI cost-control analog.** gh-aw provides `timeout-minutes` per workflow (capped at engine step level, default 20 min) and `stop-after` deadlines for scheduling windows. The orchestrator's advisory budgets (plan.md line 19) should map to these concrete CI mechanisms rather than relying on the orchestrator to self-police.

9. **No integration with gh-aw's `skip-if-match` for idempotent re-runs.** If an orchestrator CI workflow is accidentally triggered twice for the same milestone/phase/task, there is no deduplication. gh-aw's `skip-if-match` query (frontmatter field) can search for existing issues/PRs matching a task ID label and skip execution if found -- a natural idempotency guard for the `dispatch` command.

---

## Off-Base Assumptions

1. **"PID-based lock detection works in CI" (data-model.md lines 237-249, research.md R-007).** The lock file stores a `pid` field and the recovery flow checks "if lock + PID alive" vs "if lock + PID dead" (research.md R-007 lines 221-224). In gh-aw, each workflow run executes on a fresh ephemeral runner -- the PID from a previous run is meaningless because the process space is gone. The lock file needs a different liveness signal for CI: the GitHub Actions `run_id` + a status check via `gh api` to determine if the run is still active. The `pid` approach is correct for local adapters only and the plan conflates the two.

2. **"All 5 adapter operations are equivalently implementable" (research.md R-003).** The `inject-context` operation ("inject context into a running task") has no clean gh-aw equivalent. Once a gh-aw workflow is running, you cannot inject new context into it mid-execution -- the markdown prompt is fixed at workflow start time. The only workaround is writing to a file the agent polls (via repo-memory or cache-memory), but that requires the agent to have been pre-instructed to check for injections. This operation should be marked as `not_supported` in the gh-aw adapter capabilities rather than assumed implementable.

3. **"The orchestrator can dispatch and then await completion synchronously" (research.md R-003).** The `await-completion(task_id) -> status` operation implies the orchestrator blocks while a dispatched task runs. With `dispatch-workflow`, the dispatched run is fully asynchronous and the parent workflow cannot block on it -- it can only poll via `gh api`. With `call-workflow`, the child runs synchronously but within the same workflow run, consuming the same timeout budget. The plan should specify which mode the adapter uses and design the state machine loop accordingly (polling loop with `schedule` re-trigger vs synchronous call-workflow with timeout implications).

4. **Implicit assumption that the orchestrator session is long-lived enough to drive a full milestone.** The `auto` command (plan.md line 68) drives the state machine loop. In gh-aw, a single workflow run is capped by `timeout-minutes` (default 20, max varies by runner). A milestone with 10 phases x 7 tasks = 70 dispatches cannot complete in a single run. The plan needs explicit design for re-entry: a scheduled or `repository_dispatch`-triggered workflow that re-enters the state machine loop on each run, derives the current state, and dispatches the next unit.

---

## Actionable Recommendations

1. **[P1] Design the gh-aw adapter's dispatch mode explicitly.** Decide between `dispatch-workflow` (async, each task is an independent workflow run) and `call-workflow` (sync, tasks run within the orchestrator's workflow). For Tier C autonomous mode with 70+ tasks, `dispatch-workflow` is the only viable option because `call-workflow` shares timeout budgets. Document this in the runtime-adapter contract under `specs/001-orchestrator/contracts/runtime-adapter.md`. Reference: orchestration.md lines 43-47.

2. **[P1] Replace PID-based liveness with run-ID-based liveness in the CI adapter.** Store `github.run_id` and `github.run_attempt` instead of `pid` in the lock file when running in gh-aw. Use `gh api /repos/{owner}/{repo}/actions/runs/{run_id}` to check if the run is still `in_progress` or `queued`. This is the only reliable liveness signal on ephemeral runners. Reference: data-model.md lines 237-249.

3. **[P1] Specify repo-memory configuration for orchestrator state persistence.** Add a concrete `repo-memory` configuration to the adapter contract:
   ```yaml
   tools:
     repo-memory:
       branch-name: memory/orchestrator
       file-glob: ["memory/orchestrator/*.md", "memory/orchestrator/*.json", "memory/orchestrator/*.jsonl"]
       max-file-size: 1048576
       max-patch-size: 102400
   ```
   Map `.specify/orchestrator/` files to this branch. The adapter's `persist_state` capability is implemented by committing state files to this branch. Reference: repo-memory.md.

4. **[P1] Add `concurrency.job-discriminator` to all dispatched task workflows.** Every task dispatch workflow must include `concurrency: { job-discriminator: ${{ inputs.task_id }} }` to prevent fan-out cancellations when multiple tasks from the same phase are dispatched concurrently. Without this, dispatching T02 cancels T01. Reference: concurrency.md lines 86-119.

5. **[P2] Use deterministic `on.steps:` for state derivation instead of an agent invocation.** The `derive-phase.sh` script is pure computation (read files, output string). In gh-aw, run it as an `on.steps:` precomputation step that outputs the current state, then gate the agent invocation with `if: needs.pre_activation.outputs.state_result != 'complete'`. This saves an AI engine invocation per loop iteration. Reference: deterministic-agentic-patterns.md lines 97-160.

6. **[P2] Mark `inject-context` as `not_supported` in the gh-aw adapter.** gh-aw does not support injecting context into a running workflow. The adapter should declare this honestly:
   ```json
   { "inject_context": false, "batch_dispatch": true, "concurrency_control": true, "progress_reporting": true, "persist_state": true }
   ```
   Design the orchestrator to not depend on `inject-context` for correctness -- if context injection fails, the task should still produce a valid result or fail gracefully. Reference: research.md R-003 line 76.

7. **[P2] Design re-entry for the `auto` command loop via scheduled triggers.** A single gh-aw run cannot drive a full milestone. Design the `auto` command's CI mode as a `schedule: every 5m` workflow (or `repository_dispatch`-triggered) that: (a) runs `derive-phase.sh` as a precomputation step, (b) if state is not `complete`, dispatches the next unit, (c) exits. The state machine advances one unit per scheduled run. Include `skip-if-match` to prevent overlapping runs. Reference: memoryops.md Pattern 2 (State Persistence).

8. **[P2] Add `protected-files` configuration to the adapter's PR creation safe output.** If the orchestrator creates PRs that touch `.specify/` paths alongside code files, and if `CLAUDE.md` or `.github/` files exist, the default `blocked` policy will reject the PR. The adapter's workflow must declare:
   ```yaml
   safe-outputs:
     create-pull-request:
       protected-files: fallback-to-issue
       allowed-files: [".specify/**", "src/**", "scripts/**"]
   ```
   Reference: safe-outputs-pull-requests.md lines 118-150.

9. **[P3] Use staged mode for verification dry runs in CI.** Add a `verify --staged` mode that runs the full verification pipeline but with `staged: true` on all safe outputs. This lets teams preview what the orchestrator would create (issues, PRs, status comments) without side effects. Reference: staged-mode.md lines 12-30.

10. **[P3] Map `dispatch_budget` and `duration_budget` to gh-aw's `timeout-minutes` and `stop-after`.** Instead of advisory-only budgets, the gh-aw adapter should enforce them:
    - `dispatch_budget` -> track in `execution-log.jsonl` + check count in precomputation step, skip if exceeded
    - `duration_budget` -> set `on.stop-after:` on the orchestrator workflow to the configured duration
    Reference: plan.md line 19, gh-aw frontmatter `stop-after` field.

---

## Referenced Documentation

| Document | Location | Relevance |
|----------|----------|-----------|
| Orchestration pattern | `gh-aw/docs/src/content/docs/patterns/orchestration.md` | `dispatch-workflow` vs `call-workflow` dispatch modes |
| Concurrency control | `gh-aw/docs/src/content/docs/reference/concurrency.md` | Fan-out discriminators, per-engine serialization |
| Repo memory | `gh-aw/docs/src/content/docs/reference/repo-memory.md` | Persistent state storage for ephemeral runners |
| Safe outputs (PRs) | `gh-aw/docs/src/content/docs/reference/safe-outputs-pull-requests.md` | Protected files policy, PR creation config |
| Staged mode | `gh-aw/docs/src/content/docs/reference/staged-mode.md` | Preview-only safe output execution |
| Deterministic patterns | `gh-aw/docs/src/content/docs/guides/deterministic-agentic-patterns.md` | Precomputation steps, state derivation |
| MemoryOps | `gh-aw/docs/src/content/docs/guides/memoryops.md` | Cross-run state management patterns |
| Environment variables | `gh-aw/docs/src/content/docs/reference/environment-variables.md` | Config precedence model |
| Compilation process | `gh-aw/docs/src/content/docs/reference/compilation-process.md` | Frontmatter compile requirement |
| Workflow structure | `gh-aw/docs/src/content/docs/reference/workflow-structure.md` | Markdown + YAML format |
| DispatchOps | `gh-aw/docs/src/content/docs/patterns/dispatch-ops.md` | `workflow_dispatch` trigger mechanics |
| TaskOps | `gh-aw/docs/src/content/docs/patterns/task-ops.md` | Research/plan/assign multi-phase pattern |
| SpecOps | `gh-aw/docs/src/content/docs/patterns/spec-ops.md` | Spec propagation across repos |
| Multi-phase blog | `gh-aw/docs/src/content/docs/blog/2026-01-13-meet-the-workflows-multi-phase.md` | Multi-day workflow patterns with repo-memory |
