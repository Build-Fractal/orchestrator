# UTILIZATION.iteration_1.md -- gh-aw Revised Position

**Author**: GitHub Agentic Workflows (gh-aw)
**Input**: Original UTILIZATION.md + cross-reviews from APM and spec-kit
**Date**: 2026-03-18

---

## 1. Recommendation Dispositions

### Recommendation 1: Map the work hierarchy to GitHub sub-issues -- **Modified**

**Original**: Use `create-issue` with `temporary_id` and `parent` fields to create the milestone/phase/task hierarchy as GitHub issues. This gives the orchestrator's state a native GitHub representation, enables assignment to Copilot via `assignees: copilot`, and provides visibility through GitHub Projects.

**Criticism (APM, Tension 2.3)**: Disk state is truth per Constitution Principle 6. If issues become the canonical representation, disk state becomes a cache, violating the constitution. Sync is expensive and prone to drift.

**Criticism (spec-kit, Contradiction 1.3)**: GitHub issues are a GitHub-specific representation that does not exist in Cursor, Windsurf, Cline, Aider, or any non-GitHub-connected agent runtime. Making the work hierarchy depend on the GitHub API violates FR-032 (multi-agent compatibility) and creates platform coupling for a core P2 capability.

**Concession**: Both reviews are right that the original recommendation was ambiguous about authority. I framed sub-issues as the "native GitHub representation" without explicitly subordinating them to disk state. spec-kit is right that agents without GitHub API access cannot be dependent on issue enumeration for work decomposition. The hierarchy must be readable from disk by any agent.

**Revised recommendation**: The work hierarchy on disk (roadmap, phase plans, task plans under `.specify/orchestrator/`) remains the sole source of truth. When running in a gh-aw context, a one-directional sync workflow projects this disk hierarchy onto GitHub sub-issues for team visibility, Copilot assignment, and project board tracking. The sync is strictly read-from-disk, write-to-GitHub. The orchestrator never reads from GitHub issues to determine state. If the sync fails or GitHub is unavailable, orchestration proceeds unaffected. The sub-issue projection is a CI-optional visibility layer, not a state management mechanism.

---

### Recommendation 2: Use `dispatch-workflow` as the CI dispatch primitive -- **Modified**

**Original**: For Tier C autonomous execution in CI, define a `task-worker.md` agentic workflow that accepts the task payload via `workflow_dispatch.inputs` and executes a single task. The orchestrator workflow uses `dispatch-workflow: [task-worker]` to fan out tasks. This eliminates custom dispatch plumbing and provides compile-time validation, rate limiting, and GitHub Actions audit trails.

**Criticism (APM, Tension 2.4)**: `dispatch-workflow` is a sound CI dispatch mechanism, but making it *the* dispatch primitive couples the orchestrator to gh-aw's workflow model. The spec describes dispatch abstractly (FR-012, FR-013) as runtime-portable. APM recommends defining a dispatch interface with gh-aw as one implementation.

**Criticism (spec-kit, Contradiction 1.4)**: Hardwiring dispatch to `dispatch-workflow` and `call-workflow` makes the core execution loop dependent on GitHub Actions workflow triggers. Claude Code has no `dispatch-workflow`. Cursor has no `call-workflow`. The spec's dispatch abstraction is correct: define semantics, let each runtime implement with its available primitives.

**Concession**: I accept that `dispatch-workflow` cannot be *the* dispatch primitive for a runtime-agnostic orchestrator. The spec's abstract dispatch model (construct payload, spawn fresh context, verify on completion) is the correct level of abstraction for the core spec. My original recommendation conflated "this is the best CI implementation" with "this should be the primitive" -- those are different claims.

**Revised recommendation**: The spec should define a dispatch interface: payload format, completion signaling contract, and result collection protocol. `dispatch-workflow` is the gh-aw adapter implementation of this interface. A gh-aw runtime adapter maps the orchestrator's abstract dispatch calls to `dispatch-workflow` for async fan-out and `call-workflow` for synchronous verification. Other adapters (Claude Code subagent, Cursor composer, local subprocess) implement the same interface with their own primitives. The spec should specify the interface; gh-aw provides the CI adapter. I still maintain that the interface design should be *informed by* dispatch-workflow's capabilities (typed inputs, compile-time target validation, rate limiting) because these represent lessons learned about what a robust dispatch interface needs, even if the implementation is runtime-specific.

---

### Recommendation 3: Use repo-memory for durable orchestrator state in CI -- **Modified**

**Original**: Create a repo-memory configuration that maps to the spec's state directories: `memory/orchestrator-decisions` for DECISIONS.md, `memory/orchestrator-knowledge` for KNOWLEDGE.md, `memory/orchestrator-state` for the execution log and phase summaries. Each workflow run reads state from the memory branch, makes changes, and auto-commits on completion. This eliminates the need for manual git operations and crash-recovery lock files in CI.

**Criticism (APM, Contradiction 1.3)**: Repo-memory branches are invisible to APM's install-time file discovery, which scans the working tree. If DECISIONS.md lives on a repo-memory branch, APM cannot discover it for context linking. The spec's design (state on disk at `.specify/orchestrator/`) is the only model that serves both consumers.

**Criticism (spec-kit, Contradiction 1.2)**: Repo-memory is a persistence mechanism, not a state machine substrate. The spec's state machine reads specific files at specific paths to determine state. If those files live on a separate git branch accessible only through gh-aw's tooling, the state machine breaks for every non-CI execution context. This would fork the orchestrator into two incompatible implementations.

**Concession**: Both reviews land the same blow from different angles, and it is decisive. I was wrong to recommend repo-memory as the primary storage location for orchestrator state. The state machine depends on file presence at known paths (FR-020). Repo-memory branches are invisible to the working tree. APM cannot discover files on memory branches. The state model must be unified, not forked by runtime.

**Revised recommendation**: `.specify/orchestrator/` on the working tree remains the sole authoritative state location, as the spec designs. In CI, the gh-aw runtime adapter handles the persistence problem by: (1) restoring `.specify/orchestrator/` from the last committed state at workflow start (via checkout or cache), (2) allowing the orchestrator to read and write state at the standard paths during execution, and (3) committing the updated `.specify/orchestrator/` back to the branch at workflow end. Repo-memory may be used as a CI-internal *cache* for cross-workflow coordination metadata (e.g., tracking which workflow run owns which phase), but not for any artifact that the orchestrator's state machine or APM's context linking needs to discover. The canonical state tree is always `.specify/orchestrator/`.

---

### Recommendation 4: Use `call-workflow` for synchronous phase reviews -- **Modified**

**Original**: Define `spec-compliance-review.md` and `code-quality-review.md` as reusable workflows and invoke them via `call-workflow` at phase boundaries, preserving actor context and enabling the orchestrator to gate on the review result before advancing.

**Criticism (spec-kit, Contradiction 1.4, same thread as dispatch)**: This creates a CI-only execution path for verification. The verification ladder (FR-016 through FR-018) is runtime-agnostic.

**Criticism (APM, Contradiction 1.1)**: If verification gates are implemented exclusively as CI workflow calls, they are absent in local execution. Hooks deployed to IDE directories are irrelevant in CI; workflow calls are irrelevant locally. Both mechanisms must exist.

**Concession**: I accept the framing that `call-workflow` is the CI adapter for verification, not the verification primitive itself. The spec's verification ladder is the correct abstraction.

**Revised recommendation**: The spec's verification ladder (static, command, behavioral, human) defines what verification means. The gh-aw runtime adapter implements command-level and behavioral-level verification steps using `call-workflow` to invoke review workflows within the same Actions run. Locally, the same verification is implemented through spec-kit hooks or direct shell command execution. The verification *protocol* (what checks run, what constitutes passing, how results are recorded) is defined once in the spec. The verification *execution mechanism* varies by runtime. `call-workflow` is gh-aw's implementation of the "command checks" and "behavioral checks" levels.

---

### Recommendation 5: Use `create-agent-session` or `assign-to-agent` for task execution -- **Withdrawn**

**Original**: Instead of custom dispatch to "fresh agent contexts," leverage gh-aw's ability to create Copilot coding agent sessions or assign Copilot to task issues. Each task issue contains the task plan as its body; Copilot produces a PR.

**Criticism (APM, Contradiction 1.4)**: This hardcodes Copilot as the task execution agent. The spec explicitly requires multi-agent compatibility (FR-032, SC-007). APM deploys to Copilot, Claude Code, Cursor, Gemini CLI, OpenCode. Building the dispatch model around `create-agent-session` narrows it to a single vendor.

**Concession**: APM is right. This recommendation directly contradicts FR-032. `create-agent-session` and `assign-to-agent` are Copilot-specific primitives. Recommending them as the dispatch mechanism for task execution locks the orchestrator to GitHub Copilot. The spec's generic "fresh agent context" model is deliberately agent-agnostic, and I was wrong to narrow it.

**Why I withdraw entirely rather than modify**: Unlike `dispatch-workflow` (which is a CI infrastructure primitive any orchestrator needs), `create-agent-session` is an agent-selection primitive that makes an opinionated choice about which agent executes the work. The spec should never make that choice -- it should dispatch to whatever agent the consumer has configured. If a team uses Copilot, the gh-aw adapter can use `create-agent-session` as an implementation detail, but this is a consumer configuration choice, not a spec recommendation.

---

### Recommendation 6: Use `update-project` for progress dashboards -- **Modified**

**Original**: Add an `update-project` safe output to orchestrator workflows that maintains a GitHub Projects board with custom fields for phase status, risk level, blocker count, and completion percentage. This replaces the spec's terminal-only progress overview (FR-038).

**Criticism (spec-kit, Tension 2.2)**: The spec requires progress to be "derivable entirely from disk state, requiring no additional tracking beyond existing state files" (FR-039). GitHub Projects adds a dependency on the GitHub API.

**Concession**: I concede that the word "replaces" was wrong. FR-039 is explicit: progress must be derivable from disk state alone. A GitHub Projects board cannot replace the disk-based progress mechanism.

**Revised recommendation**: The disk-based progress derivation (FR-038, FR-039) is the primary and universal progress mechanism. The `update-project` safe output is an optional CI-mode enhancement: when running in a gh-aw context, the orchestrator's progress data (already computed from disk state) is projected onto a GitHub Projects board for team visibility. This is a one-directional projection (disk to Projects), never the reverse. The `status` command always reads from disk. The Projects board is a convenience view for teams using GitHub, not a data source.

---

### Recommendation 7: Use concurrency groups to replace lock files in CI -- **Modified**

**Original**: The spec's lock file mechanism (FR-021) is designed for local execution where multiple processes might collide. In CI, gh-aw's per-workflow concurrency groups prevent concurrent runs. Replace the lock file requirement with a CI-mode concurrency configuration.

**Criticism (APM, Contradiction 1.2)**: APM's lifecycle management depends on file-based state tracking. Lock files serve a different purpose than concurrency groups: they record execution state for crash recovery, not just mutual exclusion. These are complementary, not substitutes.

**Criticism (spec-kit, Tension 2.1)**: Lock files distinguish between crashes and graceful pauses. This is a local-execution concern the spec correctly addresses. gh-aw is right that lock files are redundant in CI, but the spec is right that they are necessary locally.

**Concession**: I conflated two functions: mutual exclusion and crash state recording. APM is correct that the lock file records more than "someone is running" -- it records *what* was running when the process stopped, enabling crash recovery. Concurrency groups handle mutual exclusion but do not record crash state. These are complementary mechanisms.

**Revised recommendation**: Lock files remain the universal crash recovery mechanism as the spec designs. The gh-aw runtime adapter *layers* concurrency groups on top for mutual exclusion in CI (preventing two orchestrator workflow runs from executing simultaneously). In CI, the lock file still exists on disk for state recording purposes, but the concurrency group provides the first line of defense against concurrent access. The lock file is written at orchestration start and cleared at orchestration end, same as locally. If a CI workflow crashes mid-run, the lock file persists in the committed state, and the next workflow run can detect the crash and recover -- exactly as the spec intends for local execution.

---

### Recommendation 8: Elevate US-7 (CI execution) to P2 or P3 -- **Modified**

**Original**: CI execution should be a design consideration from the start, not an afterthought. Since Tier C autonomous execution is the primary value proposition and gh-aw provides the most robust runtime for it, CI execution should be at P2 or P3.

**Criticism (APM, Tension 2.1)**: Elevating US-7 to P2/P3 while US-8 (APM Packaging) remains at P8 creates a sequencing problem. CI execution via gh-aw depends on APM packaging (gh-aw workflows declare APM frontmatter dependencies). You cannot implement CI dispatch before the packaging contract is defined.

**Criticism (spec-kit, Tension 2.3)**: Elevating CI to P2-P3 would pressure the architecture toward CI-specific primitives. Keep CI at P7 as a delivery milestone but elevate "CI compatibility" as a design constraint from the start.

**Concession**: Both reviews correctly identify that my recommendation conflated two things: (1) ensuring the architecture does not preclude CI, and (2) delivering the CI runtime early. spec-kit's framing is more precise: what I actually want is CI compatibility as a design constraint, not CI delivery as an early milestone. APM's sequencing argument is also valid -- CI dispatch depends on packaging, so US-7 cannot precede US-8.

**Revised recommendation**: Keep US-7 at its current priority for delivery. Add a cross-cutting design constraint to the spec: "All state management, dispatch, and verification abstractions MUST be implementable in both local and CI execution contexts without forking the core logic." This constraint should be evaluated during the design of every feature from US-1 forward. This gives gh-aw the architectural consideration it needs without distorting the delivery sequence. Additionally, US-7 and US-8 should be marked as co-dependent: neither should be delivered without the other.

---

### Recommendation 9: Adopt the slash_command trigger for interactive orchestration -- **Modified**

**Original**: The spec's `discuss` command and decision injection map to gh-aw's `slash_command` trigger. A `/orchestrate discuss` or `/orchestrate inject` command in a GitHub issue would trigger the orchestrator workflow.

**Criticism (APM, Tension 2.5)**: Two slash command systems with the same syntax but different execution models. gh-aw's `slash_command` triggers GitHub Actions workflows from issue comments. Spec-kit's slash commands trigger agent-context skill execution. If both exist, `/orchestrate discuss` means different things depending on context.

**Concession**: APM correctly identifies a namespace collision. The spec-kit command namespace (`speckit.orchestrator.*`) is already claimed. I should not have recommended a `/orchestrate` prefix that overlaps with the spec-kit command space.

**Revised recommendation**: gh-aw slash commands for CI-based orchestration should use an explicitly namespaced prefix that avoids collision with spec-kit commands. For example: `/ci-orchestrate discuss` or `/aw orchestrate discuss`. Alternatively, use issue labels or issue template triggers rather than slash commands, since the orchestrator's CI trigger is more naturally "create an issue with a specific label" than "type a comment command." The spec-kit `speckit.orchestrator.*` namespace is the primary command interface; gh-aw triggers are a CI-specific invocation mechanism, not a parallel command system.

---

### Recommendation 10: Leverage SpecOps pattern for specification propagation -- **Surviving**

**Original**: The spec does not describe how the orchestrator's spec artifacts (spec.md, plan.md, boundary maps) propagate to implementation. gh-aw's SpecOps pattern provides a proven model: specification updates trigger propagation workflows that create implementation PRs in consuming repositories.

**Criticism**: Neither APM nor spec-kit directly challenged this recommendation. APM's review did not address it. spec-kit's review mentioned it only tangentially in the context of community catalog distribution (Tension 2.3), which is a different concern.

**Rebuttal**: This recommendation stands because it addresses a genuine gap: the spec describes creating boundary maps and phase plans but does not describe how changes to these artifacts propagate to downstream phases or consuming repositories. SpecOps is a propagation pattern, not a dispatch pattern or state management pattern -- it does not conflict with either APM's packaging model or spec-kit's extension system. In a monorepo, boundary map changes from phase N should trigger plan updates in phase N+1. In a multi-repo setup, spec changes should trigger implementation PRs. SpecOps provides the workflow infrastructure for this. This recommendation is orthogonal to the runtime-agnostic concerns raised in other reviews.

---

## 2. Off-Base Assumptions Revised

### "Design for CI as the primary runtime" -- **Withdrawn**

**Original position**: The assumption should be reversed -- design for CI dispatch as the primary autonomous runtime, with local execution as the development/debugging mode.

**APM rebuttal (Contradiction 1.1)**: APM packages must work identically regardless of runtime context. If the core architecture is CI-first, state management and dispatch become gh-aw-native primitives that do not exist outside CI.

**spec-kit rebuttal (Contradiction 1.1)**: "State on disk is truth" is a core SDD principle, not a local-execution convenience. The orchestrator must work across 17+ agents, most of which will never run in GitHub Actions.

**Concession**: I was wrong. Both reviews converge on the same point from different directions: the orchestrator is a spec-kit extension first. Its core must be runtime-agnostic. CI is one execution context among many, not the primary one. My original framing was driven by the fact that CI provides the best infrastructure for autonomous Tier C execution (sandboxing, durability, audit trails), but "best infrastructure for one tier" does not mean "primary runtime for the whole orchestrator." Tier A and Tier B work -- which the spec correctly predicts will be the majority of usage -- will run locally in agent sessions where gh-aw does not exist. Designing CI-first would optimize for the minority case at the expense of the majority.

### "Custom dispatch plumbing vs. gh-aw's workflow dispatch" -- **Withdrawn**

**Original position**: The spec's abstract dispatch model forces implementers to build dispatch plumbing from scratch.

**Concession**: The spec's abstract dispatch model is not "custom plumbing" -- it is a runtime-portable interface. Building dispatch plumbing "from scratch" locally means invoking a subagent or subprocess, which is trivial. The value of the abstraction is that it works everywhere. gh-aw's dispatch-workflow is a high-quality CI implementation of this abstraction, but the abstraction itself is sound.

### "File-based state as the only persistence mechanism" -- **Modified**

**Original position**: The spec ignores that gh-aw provides repo-memory and cache-memory for CI persistence.

**Revised position**: The spec's file-based state model is the correct universal approach. The gh-aw runtime adapter handles CI persistence by checkpointing `.specify/orchestrator/` to the branch between workflow runs. Repo-memory may supplement as a CI-internal coordination cache, but the orchestrator's own state machine always reads from and writes to `.specify/orchestrator/` on the working tree.

---

## 3. New Recommendations

### New Recommendation A: Define a Runtime Adapter Interface

Both cross-reviews independently converge on the same architectural pattern: the orchestrator needs a runtime adapter layer. APM calls it "dispatch interface with gh-aw as one implementation" (Tension 2.4). spec-kit calls it "Runtime Adapter concept... a pluggable layer where each runtime implements the dispatch, persistence, and crash recovery interfaces" (Summary). My own cross-reviews of both APM and spec-kit arrived at the same conclusion from the CI side.

The spec should define a runtime adapter interface with these contracts:

- **Dispatch**: Accepts a payload (task plan, context, boundaries), spawns a fresh execution context, returns a handle for monitoring completion and collecting results.
- **Persistence**: Ensures `.specify/orchestrator/` state survives across execution sessions. Locally this is trivial (files persist). In CI, the adapter handles checkpoint/restore.
- **Crash recovery**: Detects unclean termination and provides recovery information. Locally this uses lock files. In CI, the adapter may supplement with workflow run status.
- **Verification execution**: Runs verification commands and returns structured results. Locally this is shell execution. In CI, this may use `call-workflow` for parallel review workflows.
- **Progress projection** (optional): Projects disk-derived progress to an external system (GitHub Projects, Slack, etc.).

gh-aw provides the CI adapter. spec-kit's extension system provides the local adapter. Future runtimes provide their own adapters. The orchestrator core operates only on the interface.

### New Recommendation B: Co-specify US-7 and US-8 as a Joint Deliverable

APM's Tension 2.1 identifies a real sequencing dependency: CI execution via gh-aw depends on APM packaging because gh-aw workflows declare APM frontmatter dependencies. spec-kit's Tension 2.3 in my cross-review identified a parallel problem with distribution: three mechanisms (catalog, APM, workflow files) create confusion.

The spec should co-specify US-7 (CI execution) and US-8 (APM packaging) as a joint deliverable, ensuring:
- The APM manifest defines what gets packaged (skills, instructions, workflow templates).
- The gh-aw adapter workflows are included in the APM package.
- The spec-kit catalog entry references the APM package.
- Installation via any channel (spec-kit catalog, APM install, manual) produces a working orchestrator with optional CI capabilities.

### New Recommendation C: Separate Configuration from State in the Spec

My cross-review of spec-kit (Tension 1.3) identified a conflation between configuration and state that both cross-reviews validated. spec-kit's config system (defaults, local overrides, env vars) is designed for static settings. Orchestration state (current phase, active blockers, accumulated knowledge) is dynamic and machine-authored.

The spec should explicitly distinguish:
- **Configuration** (human-authored, changes rarely): tier defaults, verification commands, context verbosity, template preferences. Managed by spec-kit's config system.
- **State** (machine-authored, changes per-run): current phase, execution log, decisions register, knowledge file, lock status. Managed by the `.specify/orchestrator/` state tree.

This distinction ensures spec-kit's config system and the state machine do not interfere with each other, and clarifies for the runtime adapter which artifacts need persistence management (state) versus which are pre-configured (config).

---

## 4. Position Summary

My original review made 10 recommendations and 3 off-base assumption challenges. After cross-review:

- **1 withdrawn entirely** (Rec 5: create-agent-session/assign-to-agent) -- hardcoding Copilot violates FR-032.
- **2 off-base assumptions withdrawn** (CI as primary runtime; spec's dispatch as "custom plumbing") -- the spec's runtime-agnostic, local-first design is correct.
- **7 modified** (Recs 1-4, 6-9) -- all modified in the same direction: gh-aw features become runtime adapter implementations rather than core primitives.
- **1 surviving unchanged** (Rec 10: SpecOps for spec propagation) -- unchallenged and addresses a real gap.
- **3 new recommendations** added based on cross-review convergence: runtime adapter interface, co-specifying US-7/US-8, and separating configuration from state.

**Revised overall stance**: The orchestrator's core architecture must be runtime-agnostic as both APM and spec-kit argue. gh-aw's value is not as the primary runtime but as the most capable CI runtime adapter. Every gh-aw feature I originally recommended (dispatch-workflow, call-workflow, repo-memory, concurrency groups, sub-issues, Projects, staged mode) remains valuable -- but as adapter-layer implementations of the orchestrator's portable abstractions, not as replacements for those abstractions.

The key architectural insight from this cross-review process is that the spec needs a **runtime adapter interface** -- a concept that none of the three original reviews stated explicitly but all three converged on through their criticisms. The orchestrator's core defines what dispatch, persistence, verification, and progress mean. Each runtime adapter (gh-aw for CI, spec-kit hooks for local, future adapters for new runtimes) implements these contracts with its own primitives. This is the correct architecture, and I concede it was not what my original review recommended.

The one position I maintain most firmly is that the spec should not *prevent* CI-native optimization. The runtime adapter interface should be rich enough that gh-aw can use dispatch-workflow, call-workflow, concurrency groups, and all its other primitives without working around the abstraction. A lowest-common-denominator interface that only supports what local execution can do would neuter the CI adapter. The interface should enable each runtime to bring its full capabilities.
