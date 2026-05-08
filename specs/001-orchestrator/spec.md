# Feature Specification: Speckit-Orchestrator Extension

**Feature Branch**: `001-speckit-orchestrator`
**Created**: 2026-03-18
**Status**: Implemented (M001 — v0.1.0, 2026-03-20). US1-US6 delivered. US7 (GitHub Agentic Workflows) and US8 (APM Packaging) deferred to future milestones.
**Input**: Build a spec-kit extension that adds autonomous multi-phase orchestration to spec-kit's spec-driven development workflow.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Scope Triage (Priority: P1)

As a developer, I describe what I want to build in natural language and the orchestrator evaluates scope to classify it into the right execution tier — so that the same entry point works for a bugfix or a platform rewrite, applying only the overhead each project size demands.

**Tier definitions** (classified by how many complete spec-kit SDD flows the work requires):
- **Tier A** (single context window): The entire feature fits in ~1 context window — one task or a few very small tasks, all SDD steps inline. Run standard spec-kit with zero orchestration overhead.
- **Tier B** (one SDD flow, multiple contexts): The work requires one complete SDD flow where each step fits in its own context window. Tasks dispatch to separate contexts as designed. Add structured handoff between steps but no multi-flow coordination.
- **Tier C** (multiple SDD flows, full orchestration): The work requires orchestrating two or more complete SDD flows with roadmap decomposition, autonomous dispatch, crash recovery, cross-phase coordination, and continuous knowledge generation.

**Why this priority**: Without scope classification, the orchestrator either over-engineers simple tasks (adding unnecessary ceremony) or under-serves complex ones (missing critical coordination). This is the gateway decision that determines every downstream behavior.

**Independent Test**: Can be tested by providing descriptions of varying complexity (a one-line bugfix, a multi-file feature, a platform rewrite) and verifying the correct tier classification and corresponding workflow activation.

**Acceptance Scenarios**:

1. **Given** a feature description that fits in one context window (e.g., "fix the date parsing bug in the validator"), **When** the developer invokes the orchestrator, **Then** the system classifies it as Tier A and routes to standard spec-kit with no additional files or ceremony.
2. **Given** a feature description requiring multiple phases (e.g., "add user authentication with login, registration, and password reset"), **When** the developer invokes the orchestrator, **Then** the system classifies it as Tier B, creates a roadmap with phase breakdown and dependency mapping, and manages phase-to-phase handoff.
3. **Given** a feature description requiring full orchestration (e.g., "build a multi-tenant data pipeline with ingestion, transformation, storage, API, and monitoring"), **When** the developer invokes the orchestrator, **Then** the system classifies it as Tier C, activates the full state machine with dispatch capabilities, crash recovery, and knowledge generation.
4. **Given** a Tier A classification that the developer disagrees with, **When** the developer overrides the tier, **Then** the system accepts the override and activates the corresponding workflow without re-evaluation.
5. **Given** a project that was classified as Tier B but grows in complexity during execution, **When** the developer requests a tier promotion, **Then** the system promotes to Tier C, preserving all existing progress and artifacts.

---

### User Story 2 - Phase-by-Phase Execution (Priority: P2)

As a developer with a Tier B or Tier C project, I need the orchestrator to decompose my spec into phases with a roadmap, dependency graph, and boundary maps — so that each phase can execute in a fresh context receiving only what it needs, and phase results persist as structured summaries.

**Why this priority**: This is the core orchestration capability. Without phase decomposition and structured handoff, multi-context-window projects cannot maintain quality across sessions. Every subsequent story depends on this decomposition model.

**Independent Test**: Can be tested by providing a multi-phase spec and verifying that a roadmap is generated with phases, dependencies, and boundary maps; that each phase receives only its required context; and that phase results are persisted as structured summaries on disk.

**Acceptance Scenarios**:

1. **Given** a spec with multiple user stories and cross-cutting concerns, **When** the orchestrator decomposes it, **Then** a roadmap is produced containing milestones (shippable versions) with phases (demoable capabilities) and tasks (context-window-sized units), each phase having a demo sentence describing what the user can see or do when it completes.
2. **Given** a roadmap with inter-phase dependencies, **When** a phase completes, **Then** the orchestrator produces a structured summary containing what was built, patterns used, decisions made, interfaces established, and files affected — and this summary is available as context input for dependent downstream phases.
3. **Given** a roadmap with a boundary map specifying what each phase produces and consumes, **When** a phase completes, **Then** the orchestrator verifies that the phase actually produced the interfaces declared in the boundary map before allowing dependent phases to proceed.
4. **Given** phases with no dependency relationship, **When** the orchestrator evaluates execution order, **Then** those phases are identified as parallelizable (even if executed sequentially by default).
5. **Given** phases with different risk levels in the roadmap, **When** the orchestrator determines execution order, **Then** high-risk phases are scheduled before low-risk phases (among those whose dependencies are satisfied) to validate feasibility early and surface blockers before investing in dependent work.
6. **Given** a Tier B project with a roadmap, **When** a phase completes, **Then** the orchestrator advances to the next phase without roadmap reassessment, without boundary map verification, and without requiring the developer to interact with crash recovery or knowledge consolidation machinery — the developer manually initiates each phase transition.
7. **Given** a Tier B project, **When** all phases complete, **Then** the orchestrator transitions directly to `complete` state, skipping the `validating` and `completing` gates that Tier C requires.
8. **Given** a Tier C project requiring a discussion phase, **When** the developer first invokes the orchestrator, **Then** the system enters the `discussing` state, presents targeted questions about architectural preferences and scope boundaries, records answers in a context draft file, and requires explicit finalization before generating a roadmap. Discussion captures human preferences and constraints; it is complementary to any technical research the agent performs during roadmap generation.

---

### User Story 3 - Autonomous Dispatch (Priority: P3)

As a developer with a Tier C project, I can start autonomous execution and step away. The orchestrator reads disk state, determines the next unit of work, constructs a minimal context payload, dispatches to a fresh agent context, verifies completion, persists results, and advances — without human intervention.

**Why this priority**: Autonomous dispatch is what transforms the orchestrator from a planning tool into an execution engine. It enables "start and walk away" workflows that multiply developer productivity.

**Independent Test**: Can be tested by starting autonomous mode on a project with a completed roadmap and verifying that tasks execute sequentially, each in a fresh context, with must-have verification and summary persistence between each, until the milestone completes or a blocker is encountered.

**Acceptance Scenarios**:

1. **Given** a project with a completed roadmap and phase plans, **When** the developer starts autonomous mode, **Then** the orchestrator dispatches the first eligible task to a fresh context, waits for completion, verifies the task's must-haves (observable truths, required artifacts, critical connections), persists the task summary, and automatically dispatches the next task. When all tasks in a phase complete, the orchestrator runs the phase-level review (spec compliance then code quality), produces a phase summary, and advances to the next phase.
2. **Given** a task that completes successfully, **When** the orchestrator verifies it, **Then** verification checks are mechanical (file existence, content checks, connection verification) — not dependent on the agent's self-assessment.
3. **Given** autonomous mode running, **When** the developer opens a second terminal, **Then** they can check status, inject decisions, or steer the project without interrupting the running execution.
4. **Given** a task dispatch where the executing agent reports it is blocked, **When** the orchestrator receives this status, **Then** it follows an escalation path: provide more context and retry, then break the task into smaller units, then pause and surface the blocker to the developer.
5. **Given** autonomous mode and a verification failure after a task completes, **When** the orchestrator detects the failure, **Then** it retries the task once with diagnostic context. If it fails again, autonomous mode pauses and reports the specific verification that failed.
6. **Given** a task dispatch where the executing agent reports completion with concerns (DONE_WITH_CONCERNS), **When** the orchestrator receives this status, **Then** it evaluates the concerns: if they affect correctness or scope, the orchestrator addresses them before proceeding; if they are observational (e.g., "this file is growing large"), the orchestrator notes them in the task summary and proceeds.
7. **Given** the developer wants to pause autonomous mode intentionally (not a crash), **When** they issue a pause command, **Then** the orchestrator completes the current task (or saves resume state if mid-task), writes a structured continue file with exact resume point, completed work, remaining work, and next action, and halts cleanly.

---

### User Story 4 - Knowledge Generation (Priority: P4)

As a developer, every phase of orchestrated work produces structured documentation — what was built, patterns used, decisions made, interfaces established — so that future agent sessions can consume relevant context without reading raw code or transcripts.

**Why this priority**: Knowledge artifacts are what make the orchestrator's output compound over time. Without them, each subsequent phase must rediscover context from raw code, degrading quality and increasing cost. Knowledge generation is what makes phase N+1 cheaper than phase N.

**Independent Test**: Can be tested by completing a phase and verifying that the required knowledge artifacts exist on disk with the correct structure and content, and that a subsequent phase can load them as context input.

**Acceptance Scenarios**:

1. **Given** a completed phase, **When** the orchestrator persists results, **Then** a structured phase summary is written containing: what was built, what patterns were established, what decisions were made, what interfaces were created, and what files were affected.
2. **Given** multiple completed phases, **When** a new phase begins, **Then** the orchestrator loads only the relevant summaries from upstream dependencies (not all summaries), keeping the context payload minimal.
3. **Given** an architectural decision made during a phase, **When** the phase completes, **Then** the decision is recorded in an append-only decisions register with: sequential ID, scope, what was decided, what was chosen, rationale, and whether it is revisable.
4. **Given** a recurring pattern or lesson learned during execution, **When** the agent identifies it, **Then** it is recorded in a cross-session knowledge file that subsequent sessions read at startup, giving autonomous mode cross-session memory.

---

### User Story 5 - Crash Recovery and Reliability (Priority: P5)

As a developer running autonomous mode, if a session crashes or times out mid-phase, the orchestrator detects the incomplete state and can resume without losing progress or entering an infinite retry loop.

**Why this priority**: Autonomous execution is only useful if it is reliable. Without crash recovery, a single failure during an overnight run wastes all subsequent time. Without stuck detection, failures can burn resources indefinitely.

**Independent Test**: Can be tested by simulating a crash mid-phase (interrupting a session) and verifying that the orchestrator detects the incomplete state, synthesizes a recovery context, and resumes from the correct point.

**Acceptance Scenarios**:

1. **Given** a session that crashes mid-phase, **When** the orchestrator is restarted, **Then** it detects the incomplete state from disk artifacts (lock files, missing summaries), determines what completed and what did not, and constructs a recovery context for resumption.
2. **Given** a phase that has been dispatched twice without producing the expected artifacts, **When** the orchestrator evaluates state, **Then** it identifies the stuck condition (dispatch-twice rule), stops retrying, and surfaces the specific expected artifact that is missing.
3. **Given** a lock file from a previous crashed session, **When** the orchestrator starts, **Then** it checks whether the process that created the lock is still running. If not, it treats the lock as stale and proceeds with recovery.
4. **Given** a crash during autonomous mode, **When** recovery begins, **Then** the orchestrator synthesizes a recovery briefing from whatever artifacts survived on disk, so the resumed phase has context about what was attempted.
5. **Given** a previously paused session with a continue file on disk, **When** the developer resumes, **Then** the orchestrator reads the continue file, deletes it (it is consumed, not permanent), and picks up execution from the exact point described in the "Next Action" field — without re-executing completed work.
6. **Given** a completed phase that is later discovered to have introduced a bad pattern or incorrect interface, **When** the developer marks the phase for re-execution, **Then** the orchestrator clears the phase's summary and marks its tasks as incomplete in the roadmap, records a reversal decision in the decisions register explaining why the phase is being re-done, and treats the phase as the next eligible work unit. Dependent downstream phases that have already completed MUST also be flagged for review.

---

### User Story 6 - Knowledge Consolidation (Priority: P6)

As a developer who has completed a milestone, I can consolidate the verbose phase-level artifacts into optimized summaries, generate codebase-level context files, and archive the raw artifacts — so that the knowledge remains accessible but doesn't bloat the working directory.

**Why this priority**: Without consolidation, the orchestrator's output grows linearly with project size. Consolidation is what keeps the knowledge hierarchy efficient: compressed summaries for active use, archived raw artifacts for drill-down when needed.

**Independent Test**: Can be tested by completing a milestone and running consolidation, then verifying that compressed summaries exist, raw artifacts are archived, and the compressed summaries contain all critical information from the originals.

**Acceptance Scenarios**:

1. **Given** a completed milestone with verbose phase and task summaries, **When** the developer runs consolidation, **Then** the system produces compressed milestone-level summaries that capture the essential information from all phases.
2. **Given** consolidation has run, **When** a future agent session needs context from the consolidated milestone, **Then** it can read the compressed summary first and drill down to archived raw artifacts only when specific detail is needed.
3. **Given** consolidation has run, **When** the developer inspects the working directory, **Then** raw phase artifacts have been moved to an archive location, reducing directory clutter while preserving access.
4. **Given** consolidation is running, **When** the system compresses phase summaries into a milestone summary, **Then** it verifies that all decisions from the decisions register, all boundary map contracts, and all established patterns are preserved in the compressed output — flagging any information loss before archiving raw artifacts.

---

### User Story 7 - GitHub Agentic Workflows Runtime (Priority: P7)

As a developer, I can optionally run the orchestrator as a GitHub Agentic Workflow — triggered by schedule, issue creation, or comment command — so that orchestrated work can execute in CI without requiring a local terminal session.

**Why this priority**: CI-based execution enables overnight and unattended orchestration, integrating with existing team workflows. This is an enhancement to the core local workflow, not a prerequisite.

**Independent Test**: Can be tested by creating a GitHub workflow file that triggers the orchestrator, running it in a CI environment, and verifying that phases execute and results are committed back to the repository.

**Acceptance Scenarios**:

1. **Given** the orchestrator is configured for GitHub Agentic Workflows, **When** a scheduled trigger fires, **Then** the orchestrator reads project state from the repository, executes the next eligible phase, commits results, and optionally creates a pull request.
2. **Given** a GitHub issue with a specific label or command comment, **When** the workflow triggers, **Then** the orchestrator processes the issue as a work item and begins orchestration.
3. **Given** no GitHub Agentic Workflows environment available, **When** the developer uses the orchestrator, **Then** all functionality works locally without degradation — the GitHub runtime is purely additive.

---

### User Story 8 - APM Packaging (Priority: P8)

As a developer, I can install the orchestrator via APM (`apm install speckit-orchestrator`), which deploys skills, prompts, and agent definitions to the correct IDE-native directories for my agent.

**Why this priority**: APM packaging is the distribution mechanism. While important for adoption, it is the lowest priority because the orchestrator must work correctly before it can be packaged for distribution. Manual installation is an acceptable alternative.

**Independent Test**: Can be tested by running `apm install speckit-orchestrator` in a project and verifying that skills and commands are deployed to the correct agent directories, and that the orchestrator commands are invocable via the agent's slash command system.

**Acceptance Scenarios**:

1. **Given** APM is available in the project, **When** the developer runs the install command, **Then** orchestrator skills are deployed to the IDE-native command directories for all detected agents.
2. **Given** APM is not available, **When** the developer wants to use the orchestrator, **Then** they can install it manually as a spec-kit extension (`specify extension add`) with equivalent functionality.
3. **Given** the orchestrator is installed via APM, **When** the developer invokes an orchestrator command, **Then** the command works identically to a manually installed extension command.
4. **Given** the `apm.yml` manifest is defined, **When** `apm install` runs, **Then** the manifest specifies: `name: speckit-orchestrator`, `type: hybrid`, dependencies on spec-kit core, compilation scripts, and `target: all` (compile for all supported agent runtimes). In CI environments, only `.github/` targets are relevant.
5. **Given** a team uses version pinning, **When** the `apm.yml` references the orchestrator, **Then** both `@main` (branch tracking for development) and `#v1.0.0` (tag pinning for stable releases) are supported version specifiers.

---

### Edge Cases

- What happens when a phase produces artifacts that contradict the boundary map from the roadmap? The orchestrator must detect the discrepancy during verification and flag it before allowing dependent phases to proceed. (FR-008, FR-015, FR-016a)
- What happens when all phases in a milestone are completed but the milestone-level success criteria are not met? The orchestrator must distinguish between "all phases done" and "milestone actually achieved" via a validation gate. (FR-016a, validating/completing states)
- What happens when a tier promotion occurs mid-execution (Tier B to Tier C)? Existing artifacts must be preserved and integrated into the new tier's state structure without requiring re-execution. (FR-002)
- What happens when the developer modifies files outside the orchestrator's tracked scope during autonomous mode? The orchestrator must not overwrite manual changes and should detect external modifications at phase boundaries. (FR-064)
- What happens when two phases declare they produce the same artifact in the boundary map? The orchestrator must detect the conflict during roadmap creation and require resolution before execution begins. (FR-007, FR-008)
- What happens when the knowledge file or decisions register grows too large to fit in a single context window? The orchestrator must implement hierarchical loading — milestone summary first, drill down only when needed — and enforce size limits on injected context. (FR-062, FR-063)
- What happens when a phase completes with concerns (DONE_WITH_CONCERNS status)? The orchestrator must evaluate whether the concerns affect correctness/scope (block and address) or are observational (note and proceed). Ignoring concerns risks compounding issues; over-reacting to observations wastes execution cycles. (FR-016a)
- What happens when the developer intentionally pauses autonomous mode mid-phase? The orchestrator must distinguish between a graceful pause (continue file written, clean state) and a crash (lock file stale, partial artifacts). Recovery from each follows a different path. (FR-047, FR-049)
- What happens when the orchestrator starts and discovers multiple agent runtimes with different capabilities (e.g., one supports subagent dispatch, another does not)? The system must detect capabilities per-runtime and select the best available execution strategy without requiring the developer to configure each runtime manually. (FR-046, FR-067)
- What happens when a completed phase is marked for re-execution after downstream phases have already started or completed? The orchestrator must flag all dependent downstream phases for review, record the rollback reason in the decisions register, and not silently re-execute work that was based on the now-invalidated phase's outputs. (FR-057, FR-058, FR-073)
- What happens when a command is run twice (e.g., scaffolding when the directory already exists, or verification on an already-verified phase)? All orchestrator commands must be idempotent — running a command when its output already exists must produce no change rather than an error or duplication. (FR-066)
- What happens when KNOWLEDGE.md or DECISIONS.md grows large within an active milestone (before consolidation)? The orchestrator must scope-filter entries for injection: only entries tagged with the current milestone, phase, or `project-wide` scope are injected into dispatches, not the full file. Scope filtering (FR-062/FR-063) is the primary size management mechanism — it bounds injected content to O(phases-in-milestone). The payload size guard in `build-context.sh` is a secondary backstop for cases where even scoped content exceeds the context window threshold. (FR-062, FR-063)
- What happens when a Tier A project needs promotion to Tier B or C? Since Tier A produces no orchestrator state (no milestone directory, no state files), promotion requires running `evaluate` with a tier override. The orchestrator scaffolds the milestone directory from scratch and the developer proceeds with the standard Tier B or C workflow. No artifacts need preservation because Tier A operates entirely within standard spec-kit — any existing spec artifacts in `specs/{NNN}/` are naturally consumed by the orchestrator's roadmap generation. (FR-002, FR-003)

## Requirements *(mandatory)*

### Functional Requirements

#### Scope Triage

- **FR-001**: The system MUST accept a natural language project description and classify it into one of three execution tiers (A, B, or C) based on the LLM's estimate of how many complete spec-kit process flows (specify→clarify→plan→tasks→implement) the work requires:
  - **Tier A**: The entire feature fits in approximately one context window. All SDD steps run inline with minimal context switching. The work is one task or a few very small tasks.
  - **Tier B**: The work requires one complete SDD flow where each step (specify, clarify, plan, tasks, implement) fits in its own context window. Tasks dispatch to separate contexts as designed, but it is a single pass through the process.
  - **Tier C**: The work requires orchestrating two or more complete SDD flows — multiple milestones or phases, each needing its own full specify→implement cycle, with roadmap decomposition, autonomous dispatch, and cross-phase coordination.
- **FR-002**: The system MUST allow the developer to override the automatic tier classification at any time, including promoting from a lower tier to a higher tier mid-execution while preserving all existing artifacts.
- **FR-003**: For Tier A classifications, the system MUST route directly to standard spec-kit commands with zero additional files, directories, or ceremony.

#### Tier B Behavior

- **FR-054**: For Tier B classifications, the system MUST apply a reduced orchestration surface compared to Tier C:
  - **Included**: A single-milestone roadmap with flat phases (no nested milestones), task-level dispatch to separate contexts, per-task must-have verification, phase summaries, and structured handoff between SDD steps.
  - **Excluded**: Autonomous mode (the developer drives step transitions manually), crash recovery machinery (no lock files — sessions are developer-initiated), roadmap reassessment after phases, boundary maps (optional — phases are sequential by default), knowledge consolidation, and the `discussing` state.
  - **Optional**: DECISIONS.md and KNOWLEDGE.md are created if decisions or patterns emerge, but are not required scaffolding.
  - The state machine for Tier B uses a simplified subset: `pre-planning` → `planning` → `executing` → `summarizing` → `complete`. The `discussing`, `replanning`, `validating`, and `completing` states are Tier C only.

#### Work Hierarchy

- **FR-004**: The system MUST support a three-level work hierarchy: milestones (shippable versions containing 4-10 phases), phases (demoable capabilities containing 1-7 tasks), and tasks (context-window-sized units of work).
- **FR-005**: Each task MUST fit within a single agent context window. If a task cannot fit, the system MUST require it to be decomposed into smaller tasks before execution. This is a non-negotiable constraint.
- **FR-006**: Each phase MUST have a demo sentence describing what the user can see or do when the phase completes.

#### Roadmap and Decomposition

- **FR-007**: The system MUST generate a roadmap from a spec that includes: phase definitions with demo sentences, dependency declarations between phases, risk classifications, and a boundary map specifying what each phase produces and consumes.
- **FR-008**: The boundary map MUST declare concrete interfaces: function signatures, type definitions, endpoints, or file paths that each phase produces and that downstream phases consume.
- **FR-009**: The system MUST support roadmap reassessment after each phase completes, allowing phases to be reordered, added, or removed based on new information revealed during execution.

#### Phase Planning

- **FR-010**: Each phase plan MUST include must-haves in three categories: observable truths (behaviors that must be true when done), required artifacts (files that must exist with real content), and critical connections (wiring between artifacts that must be verified).
- **FR-011**: Phase plans MUST be written assuming the executing agent has zero codebase context — including exact file paths, complete code snippets, exact commands with expected output, and verification steps.

#### Dispatch and Execution

- **FR-012**: The system MUST construct a minimal context payload for each task dispatch containing only: the task plan, phase plan excerpt, relevant upstream summaries, applicable decisions, and constitution principles. No session history from the orchestrator. The task is the atomic dispatch unit; phase completion is derived from all tasks completing successfully.
- **FR-013**: The system MUST support dispatching tasks to fresh agent contexts where the agent runtime supports it, and MUST fall back to sequential in-session execution where it does not.
- **FR-014**: The system MUST support autonomous mode where tasks are dispatched individually to fresh contexts, verified after each completion, and advanced without human intervention until the milestone completes or a blocker is encountered. Phase and milestone completion are derived from task completion state.
- **FR-015**: The system MUST implement a two-stage review after all tasks in a phase complete (at the phase boundary): first spec compliance (did we build what was specified?), then code quality (is it built well?). Spec compliance MUST pass before code quality review begins. This phase-level review is distinct from per-task must-have verification.

#### Verification

Verification operates at two tiers corresponding to the dispatch and review granularity:

- **FR-016**: **Per-task verification** — After each task dispatch completes, the system MUST verify the task's must-haves mechanically: observable truths are true, required artifacts exist with real content, and critical connections are present. This verification is not dependent on the agent's self-assessment. Configurable verification commands (FR-017) also run at this boundary. The autonomous dispatch loop is: `dispatch task → verify task must-haves → run verification commands → persist task summary → next task`.
- **FR-016a**: **Per-phase verification** — After all tasks in a phase complete and pass per-task verification, the system MUST run the two-stage review (FR-015): spec compliance review then code quality review. Only after both pass does the system produce the phase summary and advance to the next phase. The full phase cycle is: `all tasks verified → spec compliance review → code quality review → phase summary → roadmap reassessment (optional) → next phase`.
- **FR-017**: The system MUST support configurable verification commands (e.g., lint, test) that run automatically after each task completes.
- **FR-018**: The system MUST implement a verification ladder: static checks (files exist, exports present), command checks (tests pass, build succeeds), behavioral checks (flows work, responses correct), and human checks (only when mechanical verification is insufficient). Per-task verification uses static and command checks. Per-phase review adds behavioral and human checks as needed.

#### State Management

- **FR-019**: All orchestrator state MUST be persisted to disk under `.specify/orchestrator/` as a separate tree from spec-kit's `specs/` feature directories. No in-memory state may survive across sessions. The orchestrator MUST be able to derive its complete state by reading files on disk. Spec artifacts (spec.md, plan.md, tasks.md) remain in `specs/{NNN}/`; orchestrator state (roadmaps, phase plans, task plans, summaries, decisions register, knowledge file, execution log, lock files) lives in `.specify/orchestrator/milestones/{M###}/`.
- **FR-020**: The system MUST use a state machine with 9 canonical phases, each derived deterministically from file presence/absence on disk (no stored state field):
  - `pre-planning` — milestone directory exists but no roadmap file
  - `discussing` — context draft exists but needs full discussion before planning
  - `planning` — roadmap exists, active phase has no plan yet
  - `replanning` — a phase needs replanning due to new information or failure
  - `executing` — active task exists and is not yet done
  - `summarizing` — all tasks in a phase are done but no phase summary exists
  - `validating` — all phases in a milestone are done but no milestone validation file exists
  - `completing` — milestone validation passed but no milestone summary exists
  - `complete` — milestone summary exists

#### Crash Recovery

- **FR-021**: The system MUST detect interrupted sessions via lock files and determine what completed and what did not by examining disk artifacts.
- **FR-022**: The system MUST implement stuck detection: if the same unit is dispatched twice without producing the expected artifacts, the system MUST stop and report the specific missing artifact rather than retrying indefinitely.
- **FR-023**: The system MUST synthesize a recovery briefing from surviving disk artifacts when resuming after a crash, providing the resumed phase with context about what was previously attempted.

#### Knowledge Management

- **FR-024**: Every completed phase MUST produce a structured summary containing: what was built, patterns established, decisions made, interfaces created, files affected, and verification results.
- **FR-025**: The system MUST maintain an append-only decisions register recording: sequential ID, scope, decision question, choice made, rationale, and revisability. Entries are never edited or removed; reversals are recorded as new entries.
- **FR-026**: The system MUST maintain a cross-session knowledge file where patterns, rules, and lessons are recorded and loaded into every subsequent session.
- **FR-027**: The system MUST implement knowledge consolidation that compresses verbose phase artifacts into optimized milestone summaries and archives raw artifacts.

#### Skill Architecture

- **FR-028**: Each orchestrator command MUST have a spec-kit command markdown file (`.md`) as its authoritative definition, registered in `extension.yml` following the `speckit.orchestrator.*` naming convention. The command definition is the canonical source for the command's purpose, arguments, and behavior. Helper scripts (state parsing, context assembly), output templates (summaries, dispatch prompts), and reference documents (progressive disclosure) MUST be discoverable from their command via `scripts` frontmatter declarations. Shared resources are organized by concern (e.g., `scripts/state/`, `scripts/verify/`); single-command resources MAY be co-located in the command's resource directory. APM skill metadata (trigger-phrased descriptions, `SKILL.md` files) is either derived from command frontmatter at install time or co-located within the command's resource directory — not in a parallel `skills/` tree. The spec-kit extension model is the canonical organizational structure; APM packaging wraps it.
- **FR-029**: Skill descriptions MUST use trigger phrasing ("Use when...") rather than feature summaries, to enable accurate skill discovery by agents. This applies whether the description is in a `SKILL.md` file, command frontmatter, or APM-generated metadata.
- **FR-030**: Each skill MUST document known failure modes, context pollution patterns, and anti-patterns in a dedicated gotchas section.

#### Extension Templates

- **FR-074**: Structural formatting templates (roadmap layout, phase summary format, task summary format) MUST be registered as extension templates in `.specify/extensions/orchestrator/templates/` and resolved through spec-kit's template resolution stack. Project-level overrides follow spec-kit's standard template override mechanism. Templates MUST NOT embed orchestrator-specific context (milestone references, phase scope, boundary maps). Orchestrator context is always injected explicitly into command inputs at runtime, keeping templates context-free and reusable. Commands reference templates via spec-kit's `{TEMPLATE:name}` placeholder, which resolves from the installed extension's `templates/` directory (`.specify/extensions/orchestrator/templates/{name}.md`). Project-level template overrides follow spec-kit's resolution stack: `.specify/templates/orchestrator/{name}.md` takes precedence over the extension-installed template.

#### Extension Compliance

- **FR-031**: The system MUST be a valid spec-kit extension with an `extension.yml` manifest, registered commands following the `speckit.orchestrator.*` naming pattern, and hook registrations at all 5 available hook points (`before_tasks`, `after_tasks`, `before_implement`, `after_implement`, `before_commit`). For SDD steps without hook points (plan, specify, clarify), orchestrator commands MUST wrap the corresponding spec-kit commands via command composition, injecting orchestrator context before delegating.
- **FR-071**: The `extension.yml` manifest MUST declare `requires.commands` listing the spec-kit commands the orchestrator depends on: `speckit.tasks`, `speckit.plan`, `speckit.specify`, `speckit.clarify`, `speckit.implement`, `speckit.analyze`. Spec-kit validates these prerequisites at extension load time. CI environments MUST perform their own prerequisite validation (e.g., a `check-prerequisites` workflow step). APM installations validate via `apm.yml` dependencies. These are complementary validations at different layers.
- **FR-072**: The `extension.yml` manifest MUST include a `config_schema` section defining a JSON Schema for orchestrator configuration. The schema MUST validate the following properties: `default_tier` (enum: A, B, C, or null), `verification_commands` (array of strings), `context_verbosity` (enum: minimal, standard, full), `git_isolation` (boolean), `dispatch_budget` (integer or null), `duration_budget` (string or null), `budget_enforcement` (enum: advisory, enforced). The schema validates persisted configuration files (`orchestrator-config.yml`, `orchestrator-config.local.yml`), not per-run environment variable overrides.
- **FR-032**: The system MUST work with all spec-kit-supported agents without requiring agent-specific code paths in the core logic.
- **FR-033**: The system MUST NOT require GSD-2 or APM as runtime dependencies. Principles and patterns are ported, not wrapped.

#### Graceful Degradation

- **FR-034**: If the agent runtime does not support subagent dispatch, the system MUST fall back to sequential in-session execution with explicit context separation instructions.
- **FR-035**: If GitHub Agentic Workflows are not available, the system MUST operate locally with equivalent functionality.
- **FR-036**: If APM is not available, the system MUST be installable manually as a spec-kit extension.

#### Status and Progress

- **FR-038**: The system MUST provide a progress overview displaying: milestone completion state (phases done vs total), phase completion state (tasks done vs total), active blockers, next recommended action, and cumulative execution history (dispatch count, total duration).
- **FR-039**: The progress overview MUST be derivable entirely from disk state, requiring no additional tracking beyond existing state files, summaries, and the execution log.

#### Execution History

- **FR-037**: The system MUST maintain an append-only execution log recording each dispatch event with: timestamp, unit ID, tier, duration, and outcome. This log persists across sessions and survives skill upgrades.

#### First-Run Configuration

- **FR-040**: Configuration MUST flow through spec-kit's multi-layer config system with the following precedence (highest to lowest):
  1. **Environment variables** (`SPECKIT_ORCHESTRATOR_*`) — for CI and per-run overrides
  2. **Local overrides** (`orchestrator-config.local.yml`, gitignored) — for developer preferences
  3. **Project overrides** (`orchestrator-config.yml` at project root, outside APM deployment radius) — for team-shared settings
  4. **Extension defaults** (`extension.yml` `defaults` section) — factory defaults shipped with the extension
  On first invocation, if no project-level config exists, the system MUST prompt the developer for configuration preferences (default tier override, verification commands, context verbosity level, git isolation mode) and write them to `orchestrator-config.yml`. The prompt is triggered by `read-config.sh`, which is invoked by any orchestrator command that requires configuration. In practice, this means the first orchestrator command the developer runs (typically `evaluate`) presents the configuration prompt. Subsequent invocations MUST read this configuration without re-prompting. Prompt content is generated by `read-config.sh`; the calling command presents it and writes responses to `orchestrator-config.yml`.
- **FR-041**: All configuration preferences MUST be overridable per-invocation via environment variables or command options without modifying the stored configuration files.
- **FR-075**: When `git_isolation` is enabled in configuration, the `scaffold.sh` script MUST create a git worktree for each milestone (`git worktree add .worktrees/M001 -b orchestrator/M001`). Task dispatch and execution occur within the worktree. On milestone completion, the orchestrator merges the worktree branch back to the feature branch and removes the worktree. On crash with an active worktree, recovery detects the worktree via `git worktree list` and resumes within it. When `git_isolation` is disabled (default), all work occurs on the current branch.
- **FR-070**: User-mutable configuration MUST NOT reside in APM-managed directories. The `orchestrator-config.yml` and `orchestrator-config.local.yml` files live at the project root, outside `.specify/extensions/orchestrator/`. APM deployment never overwrites user configuration.

#### Scaffolding

- **FR-042**: The system MUST provide a scaffolding command that creates the orchestrator directory structure under `.specify/orchestrator/milestones/{M###}/` for a milestone, including directories for phases, tasks, and the required state files (decisions register, knowledge file, execution log). The scaffolded structure MUST match the expected layout that the state machine reads. Global state files (DECISIONS.md, KNOWLEDGE.md, execution-log.jsonl) live at `.specify/orchestrator/` root. Configuration lives outside this directory per the multi-layer config system (FR-040).

#### Risk-Ordered Execution

- **FR-043**: When determining phase execution order, the system MUST prioritize high-risk phases before low-risk phases among those whose dependencies are satisfied. This ensures feasibility is validated early before investing in dependent lower-risk work.

#### Phase Scope Enforcement

- **FR-044**: During phase execution, the system MUST enforce that the executing agent only modifies files declared in the phase plan's "files likely touched" section. Modifications to files outside the declared scope MUST be flagged as a verification warning.
- **FR-045**: During autonomous mode, the system MUST warn before any destructive operations (file deletion, branch force-push, database changes) and require explicit confirmation unless the phase plan specifically authorizes them. **v0.1.0 Implementation Note**: For v0.1.0 (Claude Code-only), destructive operation detection is delegated to Claude Code's built-in safety checks, which already prompt for confirmation before destructive file operations and git commands. The orchestrator's scope enforcement (`check-scope.sh`) provides a complementary layer by flagging modifications to files outside the declared scope. Orchestrator-level destructive operation detection (independent of the agent runtime) is deferred to a future milestone when multi-agent support broadens the runtime surface.

#### Capability Detection

- **FR-046**: At startup, the system MUST detect available runtime capabilities: subagent dispatch support, shell command execution, git availability, and GitHub Agentic Workflows environment. The detected capability set MUST determine the execution strategy (subagent dispatch vs sequential, local vs CI, isolated worktree vs shared branch).

#### Runtime Adapter Interface

- **FR-067**: The orchestrator's core logic MUST program against an abstract runtime adapter interface, never directly against platform-specific APIs. The interface MUST define five platform-neutral operations:
  - `dispatch-task` — send a task payload to an agent context for execution
  - `await-completion` — block or poll until a dispatched task signals done
  - `collect-result` — retrieve the output artifacts and status from a completed task
  - `signal-failure` — report a task failure with diagnostic context
  - `inject-context` — provide additional context to a running or queued task
- **FR-068**: Runtime adapters (local subprocess, gh-aw CI, future runtimes) MUST implement the five core operations using platform-native primitives. The orchestrator MUST NOT contain conditional branches based on runtime identity in its core dispatch, verification, or state management logic.
- **FR-069**: Adapters MAY implement internal optimizations (e.g., batch dispatch, parallel fan-out) that are invisible to the orchestrator's core dispatch loop. The five core operations defined in FR-067 are the complete interface contract; there is no capability-negotiation protocol, no `AdapterCapabilities` type, and no conditional branches in core logic based on adapter identity. Unsupported scenarios degrade gracefully through the sequential core operations.

> **v0.1.0 Implementation Note (FR-067/FR-068/FR-069)**: The orchestrator is implemented as a spec-kit extension (markdown command documents + shell scripts), not a programmatic API. The five adapter operations are realized through the extension's architecture rather than as a formal script-level abstraction: `dispatch-task` and `inject-context` are implemented by `build-context.sh` assembling a payload and the command document instructing the agent on dispatch strategy; `await-completion` and `collect-result` are handled by the agent runtime's task execution model (the agent executes the payload and writes artifacts to disk); `signal-failure` is captured by verification scripts (`check-must-haves.sh`, `run-commands.sh`) detecting missing/incorrect artifacts. Capability detection (`detect-capabilities.sh`) selects the dispatch strategy (subagent vs sequential) without conditional branches in the core command logic — the command documents describe both paths and the agent follows the applicable one. This design satisfies the intent of FR-067-069 (no platform-specific branching in core logic, graceful degradation) while being idiomatic for the markdown-command extension architecture. Formal adapter scripts may be introduced in a future milestone if additional runtimes (e.g., GitHub Agentic Workflows) require platform-native primitives.

#### Feature-Milestone Mapping

- **FR-055**: By default, one spec-kit feature (`specs/{NNN}-{name}/`) maps to one orchestrator milestone. The milestone roadmap MUST include a `feature_ref` frontmatter field linking to the originating feature branch name and spec directory path. For Tier C projects where a single feature decomposes into multiple milestones, or where a milestone spans multiple features, the mapping MUST be explicitly declared in the roadmap and discoverable by the status command.

#### Graceful Pause and Resume

- **FR-047**: The system MUST support intentional pause during autonomous mode. A pause MUST produce a structured continue file containing: current milestone/phase/task position, completed work summary, remaining work description, decisions made in this session, and the exact next action to take on resume.
- **FR-048**: When resuming from a continue file, the system MUST read the file, delete it (it is consumed, not permanent), and proceed from the described next action without re-executing completed work.
- **FR-049**: The system MUST distinguish between graceful pauses (continue file present, no stale lock) and crashes (stale lock, no continue file) and apply the appropriate recovery path for each.

#### Context Budget Profiles

- **FR-050**: The system MUST support configurable context verbosity levels that control how much context is injected into each dispatch: minimal (phase plan and essential prior summaries only), standard (adds roadmap excerpt, decisions register, and dependency summaries), and full (includes all available context artifacts). The default verbosity level MUST be standard. The developer MUST be able to override this per-project via configuration or per-invocation via command options.
- **FR-051**: *Merged into FR-050.*

#### Discussion and Decision Injection

- **FR-052**: The system MUST provide a command for the developer to inject architectural decisions, constraints, or steering context into the orchestrator's state during autonomous execution. Injected decisions MUST be recorded in the decisions register and picked up at the next phase boundary. This capability is provided by the `discuss` command operating in decision injection mode (automatically selected when the state machine is in `executing` or later states). See FR-056 for the `discuss` command's pre-planning mode.

#### Pre-Planning Discussion

- **FR-056**: The system MUST provide a `speckit.orchestrator.discuss` command that creates or updates a context draft file (`{M###}-CONTEXT.md`) from developer input. The context draft captures architectural decisions, constraints, scope boundaries, and design preferences that inform roadmap generation. The state machine transitions from `discussing` to `planning` when the developer finalizes the context (via an explicit "finalize" action that sets `status: finalized` in the context file's frontmatter). For Tier C projects, discussion is a required gate before roadmap generation — the system MUST NOT generate a roadmap without a finalized context. For Tier B, discussion is optional and skippable.

#### Concurrent Access Safety

- **FR-053**: Orchestrator state files MUST be safe for concurrent read access from a second terminal while autonomous mode is running. Status queries and decision injection MUST NOT corrupt the running execution's state.

#### Phase Rollback

- **FR-057**: The system MUST support marking a completed phase for re-execution. Rolling back a phase MUST: (a) clear the phase's summary file so the state machine treats it as incomplete, (b) record a reversal decision in the decisions register with the rollback reason, referencing the original completion decision, and (c) flag all downstream phases that depend on the rolled-back phase's boundary map outputs for review. The developer MUST explicitly confirm before any downstream phase re-execution begins.
- **FR-058**: Rolling back a phase MUST NOT delete the phase's prior summary or task summaries. Instead, prior summaries MUST be moved to the archive directory as a historical record, and the phase re-executes with a clean slate. The recovery briefing for re-execution MUST include context about why the phase is being re-done and what went wrong in the prior attempt.

#### Two-Stage Review Specificity

- **FR-059**: The spec compliance stage of the two-stage review (FR-015) MUST check phase-level concerns that per-task verification cannot catch: (a) the phase as a whole achieves its demo sentence, (b) all boundary map contracts declared in the roadmap are satisfied — not just per-artifact existence but the complete interface surface, (c) no scope creep occurred — features or files not in the phase plan were not introduced, and (d) the phase's output is consistent with its declared must-haves at the aggregate level (individual task must-haves may pass while the phase-level integration fails).
- **FR-060**: The code quality stage of the two-stage review MUST check cross-task consistency: (a) naming conventions are consistent across all tasks in the phase, (b) error handling patterns are uniform, (c) test coverage meets the project's configured threshold (if verification commands include tests), and (d) no dead code, unused imports, or placeholder implementations ("TODO", "FIXME") were left by task-level execution.

#### Specification Propagation

- **FR-073**: When a phase's outputs change boundary maps, interfaces, or constraints that affect subsequent phases, the orchestrator MUST detect the invalidation and trigger re-planning for affected downstream phases. Detection MUST occur during roadmap reassessment (FR-009, FR-061) by comparing the completed phase's actual outputs against the boundary map contracts consumed by downstream phases. If a downstream phase's plan references an interface or artifact that has changed, the orchestrator MUST mark that phase's plan as stale, record the invalidation in the decisions register, and require re-planning before dispatch. The specific re-planning mechanism (automatic or developer-initiated) is a runtime adapter concern, but detection and flagging are core orchestrator responsibilities.

#### Roadmap Reassessment Criteria

- **FR-061**: Roadmap reassessment (FR-009) MUST consider: (a) deviations recorded in the just-completed phase's summary, (b) new interfaces discovered during execution that are not in the original boundary map, (c) decisions recorded in the decisions register that invalidate assumptions in downstream phase plans, and (d) risk reclassifications based on execution experience (e.g., a phase classified as low-risk that revealed unexpected complexity). Reassessment MUST NOT modify phases that are already complete. Reassessment MUST NOT modify the currently executing phase. Changes from reassessment MUST be recorded in the decisions register.

#### Knowledge Scoping

- **FR-062**: Every entry in KNOWLEDGE.md MUST include a `scope` tag indicating its applicability: `project` (applies to all future work), `milestone:{M###}` (applies within a specific milestone), or `phase:{M###/P##}` (applies only to a specific phase and its direct dependents). When constructing the context payload for a dispatch, the orchestrator MUST inject only entries whose scope matches the current milestone/phase context, plus all `project`-scoped entries. This prevents unbounded growth of injected knowledge within an active milestone.
- **FR-063**: Every entry in DECISIONS.md MUST include the existing `When` column (which captures `M###/P##/T##` scope). When constructing context payloads, the orchestrator MUST inject: all decisions scoped to the current milestone, all decisions scoped to the current phase's upstream dependencies, and all decisions scoped to the current phase itself. Decisions from unrelated phases within the same milestone MUST NOT be injected unless they are tagged with `scope: arch` (architectural decisions apply milestone-wide).

#### External Modification Detection

- **FR-064**: At each phase boundary (after all tasks in a phase complete and before the two-stage review begins), the system MUST detect external modifications to files within the active phase's declared scope. Detection MUST use git status or file checksum comparison against the state at phase start. If external modifications are detected, the system MUST surface them to the developer with a list of changed files and pause for confirmation before proceeding with the phase review. This prevents the review from validating a state the orchestrator did not produce.

#### Budget Awareness

- **FR-065**: The execution log (FR-037) MUST track cumulative dispatch count and total duration per milestone. The system MUST support an optional `dispatch_budget` configuration (maximum number of dispatches per milestone) and an optional `duration_budget` configuration (maximum cumulative duration per milestone). When either budget is reached, autonomous mode MUST pause and surface the budget status to the developer rather than continuing unbounded. Budgets are advisory — the developer can resume after reviewing.

#### Idempotency

- **FR-066**: All orchestrator commands MUST be idempotent. Running a command when its output already exists and is current MUST produce no change rather than an error or duplication. Specifically: scaffolding an already-scaffolded milestone MUST be a no-op, verifying an already-verified phase MUST return the cached result, and generating a roadmap when one already exists MUST require explicit confirmation before overwriting.

### Key Entities

*Note: FR IDs are stable identifiers — they are never renumbered. Gaps in the sequence (e.g., FR-037 appearing after FR-039) are intentional to preserve cross-reference stability across spec revisions. New FRs receive the next available ID regardless of document position.*

- **Milestone**: A shippable version of the project. Contains 4-10 phases. Has a vision statement, success criteria, and a roadmap with boundary maps. Identified by sequential ID (M001, M002...). By default, one spec-kit feature (`specs/{NNN}/`) maps to one milestone. For Tier C projects spanning multiple concerns, a single milestone may decompose into phases that each correspond to separate spec-kit features, or a single feature may spawn multiple milestones. The milestone directory stores a `feature_ref` in its roadmap frontmatter linking back to the originating feature branch and spec directory.
- **Phase**: A demoable vertical capability within a milestone. Contains 1-7 tasks. Has a goal, demo sentence, must-haves, and dependency declarations. Identified by sequential ID within milestone (P01, P02...).
- **Task**: A context-window-sized unit of work within a phase and the atomic dispatch unit for autonomous execution. Each task is dispatched to a fresh agent context with a constructed payload. Has a plan with exact steps, verification criteria, and expected outputs. Identified by sequential ID within phase (T01, T02...).
- **Roadmap**: The decomposition of a milestone into ordered phases with dependency graphs and boundary maps. Source of truth for what phases exist and their completion status.
- **Boundary Map**: A declaration within a roadmap specifying what each phase produces (function signatures, types, endpoints) and what it consumes from upstream phases. Enables deterministic cross-phase verification.
- **Phase Summary**: Structured output produced when a phase completes. Contains what was built, patterns used, decisions made, interfaces established, files affected, and verification results. Serves as context input for downstream phases.
- **Decisions Register**: Append-only log of architectural and design decisions made during execution. Entries are never modified; reversals are new entries referencing the original.
- **Knowledge File**: Append-only cross-session memory containing project-specific rules, patterns, and lessons learned. Read at the start of every session.
- **Execution Log**: Append-only record of every dispatch event with timestamps, unit IDs, and outcomes. Used for cost tracking, debugging, and retrospective analysis.
- **Lock File**: Ephemeral file indicating an active or crashed session. Contains session metadata for crash recovery forensics.
- **Continue File**: Ephemeral file written during a graceful pause, containing the exact resume point (milestone, phase, task, step), completed work, remaining work, session decisions, and the next action. Consumed and deleted on resume.
- **Configuration**: Project-level preferences controlling orchestrator behavior: default tier, verification commands, context verbosity level, git isolation mode, optional dispatch/duration budgets. Delivered through spec-kit's multi-layer config system: extension defaults in `extension.yml`, project overrides in `orchestrator-config.yml` (project root), local overrides in `orchestrator-config.local.yml` (gitignored), and `SPECKIT_ORCHESTRATOR_*` environment variables for CI/per-run overrides. Set on first run, overridable per-invocation.
- **Tier Metadata**: Persisted tier classification created by the `evaluate` command for Tier B and C projects. Stored as `{M###}-TIER.md` in the milestone directory. Records the tier, feature reference, classification timestamp, and whether the developer manually overridden the automatic classification. Consumed by `derive-phase.sh` to determine valid state machine transitions (e.g., Tier B skips `discussing`, `replanning`, `validating`, and `completing` states). When the roadmap is generated, the tier is copied into the roadmap frontmatter; both sources remain consistent.
- **Context Draft**: A pre-planning artifact created during the `discussing` state that captures the developer's architectural decisions, constraints, scope boundaries, and design preferences. Created via the `discuss` command, finalized explicitly by the developer. Required gate for Tier C roadmap generation; optional for Tier B. Captures human judgment that complements any technical research the agent performs.

### File Format Specifications

**Task Summary** (`T##-SUMMARY.md`): YAML frontmatter with markdown body. Frontmatter fields (15 fields):
- `schema_version`: Schema format version (always `1` for v0.1.0)
- `type`: Summary type identifier (always `task` for task summaries)
- `id`: Task ID (T01, T02...)
- `parent`: Phase ID (P01, P02...)
- `milestone`: Milestone ID (M001, M002...)
- `provides`: List of what this task built (~5 items)
- `requires`: List of upstream dependencies consumed (slice ID + what was used)
- `affects`: List of downstream phase IDs that depend on this task's output
- `key_files`: List of important file paths created or modified
- `key_decisions`: List of decisions made with brief rationale
- `patterns_established`: List of patterns introduced and where they live
- `drill_down_paths`: List of paths to related plan files for detail
- `duration`: Estimated or actual duration
- `verification_result`: pass | fail | partial
- `completed_at`: ISO 8601 timestamp

Body contains: one-liner summary (not "task complete" but what shipped), What Happened (prose narrative), Deviations (what differed from plan), Files Created/Modified (path + description).

**Phase Summary** (`P##-SUMMARY.md`): Same frontmatter schema as task summary (16 fields — the 15 task fields plus `observability_surfaces`), but `type` is `phase`, `id` is a phase ID, `parent` is a milestone ID, and content is a compressed rollup of all task summaries in the phase. Includes `drill_down_paths` to each task summary. Phase and milestone summaries include an optional `observability_surfaces` frontmatter field listing verification endpoints, health checks, or monitoring hooks relevant to the completed work.

**Milestone Summary** (`M###-SUMMARY.md`): Same frontmatter schema (16 fields), `type` is `milestone`, compressed rollup of all phase summaries. Updated incrementally as each phase completes. Includes `observability_surfaces` field (same as phase summary).

**Lock File** (`.specify/orchestrator/orchestrator.lock`): JSON file containing:
- `schema_version`: Schema format version (always `1` for v0.1.0)
- `pid`: Process ID of the active session
- `runtime`: Runtime environment identifier (e.g., "local", "ci-github")
- `startedAt`: ISO 8601 timestamp of session start
- `unitType`: Current dispatch unit type (e.g., "execute-task", "plan-phase", "complete-phase")
- `unitId`: Current unit identifier (e.g., "M001/P01/T02")
- `unitStartedAt`: ISO 8601 timestamp of current unit dispatch
- `completedUnits`: Array of unit IDs completed in this session
- `featureBranch`: Active feature branch name
- `phase_start_tree`: Git tree hash at phase start for external modification detection

The `runtime` field determines the liveness check strategy: `"local"` checks PID via `kill -0`, `"ci-github"` checks workflow run status via GitHub API. For CI runtimes, add `"run_id"` field. The `phase_start_tree` field stores the git tree hash at phase start for external modification detection (FR-064).

**Continue File** (`continue.md`): YAML frontmatter with markdown body. Frontmatter: `schema_version`, `milestone`, `phase`, `task`, `step`, `total_steps`, `saved_at`. Body sections: Completed Work, Remaining Work, Decisions Made, Context, Next Action (exact first thing to do on resume).

**Decisions Register** (`DECISIONS.md`): Markdown table with columns: # (D001, D002...), When (M001/P01/T02), Scope (arch|pattern|library|data|api|scope|convention), Decision (question), Choice (answer), Rationale (why), Revisable? (No | Yes — trigger condition). Append-only; reversals are new rows referencing the original ID.

**Knowledge File** (`KNOWLEDGE.md`): Append-only markdown list of project-specific rules, patterns, and lessons learned. Each entry has a category tag, a scope tag (`project`, `milestone:{M###}`, or `phase:{M###/P##}`), and a date. Scope determines which entries are injected into dispatch payloads — only matching-scope entries are included (see FR-062). Read at the start of every session with scope filtering applied.

**Context Draft** (`{M###}-CONTEXT.md`): YAML frontmatter with markdown body. Frontmatter: `schema_version`, `milestone`, `status` (draft | finalized), `created_at`, `finalized_at`. Body sections: Architectural Decisions (preferences about patterns, libraries, approaches), Scope Boundaries (what is explicitly in and out of scope), Design Constraints (non-negotiable requirements from stakeholders or existing systems), Open Questions (unresolved items to investigate during planning). Finalization sets `status: finalized` and triggers the `discussing` → `planning` state transition.

**Tier Metadata File** (`{M###}-TIER.md`): YAML frontmatter. Created by the `evaluate` command when a project is classified as Tier B or C. Persists the tier classification to disk before the roadmap is generated, ensuring the state machine can determine valid states (e.g., whether `discussing` is a valid state for Tier B). Consumed by `derive-phase.sh` and `roadmap` command. Frontmatter fields:
- `schema_version`: Schema format version (always `1` for v0.1.0)
- `tier`: Tier classification (B or C — Tier A produces no orchestrator state)
- `feature_ref`: Originating feature branch name
- `feature_spec`: Path to the originating feature's spec.md
- `classified_at`: ISO 8601 timestamp
- `override`: Whether the classification was manually overridden by the developer (boolean)

**Execution Log** (`execution-log.jsonl`): One JSON object per line. Fields: `timestamp`, `unitId`, `unitType`, `tier`, `duration`, `outcome` (success|failure|blocked|concerns), `model` (if available), `featureBranch`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can go from a natural language project description to a tier classification and initial roadmap in under 5 minutes of interaction, regardless of project complexity.
- **SC-002**: Each task executes in a fresh context that contains less than 20% of the total project's accumulated artifacts — only what that specific task needs.
- **SC-003**: Autonomous mode can complete a 5-phase milestone without human intervention, provided no phases encounter blockers that require human judgment.
- **SC-004**: After a simulated crash mid-phase, the orchestrator resumes execution within 2 minutes of restart, with no loss of completed work and no re-execution of already-completed phases.
- **SC-005**: Stuck detection triggers within 2 dispatch cycles of a task failing to produce expected artifacts, preventing unbounded retries.
- **SC-006**: Knowledge artifacts produced by the orchestrator reduce the context payload for subsequent phases by at least 50% compared to loading raw code and transcripts.
- **SC-007**: The orchestrator works correctly on at least two different agent runtimes (e.g., Claude Code and one other spec-kit-supported agent) without agent-specific configuration. **v0.1.0 Note**: For v0.1.0, the orchestrator is designed and validated exclusively with Claude Code. The architecture avoids agent-specific code paths (no Claude Code APIs in scripts, all instructions are agent-neutral markdown), but multi-agent validation is deferred until spec-kit's agent ecosystem matures. Multi-runtime testing is a candidate for M002.
- **SC-008**: Tier A projects (single context window) experience zero additional overhead — no extra files, directories, or prompts beyond standard spec-kit.
- **SC-009**: 100% of phase transitions include mechanical verification of must-haves (truths, artifacts, connections) before advancing.
- **SC-010**: The orchestrator's extension manifest passes spec-kit's validation without errors, and all commands are discoverable via the agent's slash command system.
- **SC-011**: Knowledge consolidation reduces the on-disk footprint of a completed milestone's artifacts by at least 60% while preserving all critical information accessible via drill-down. "Critical information" is defined as: all decisions register entries scoped to the milestone, all boundary map contracts, all KNOWLEDGE.md patterns, and all phase demo sentence verification results.
- **SC-012**: Every decision made during orchestrated execution is traceable in the decisions register with its rationale, enabling future sessions to understand why choices were made without re-debating them.
- **SC-013**: A developer can query orchestration progress from a second terminal and receive a complete status overview (milestone/phase/task completion, blockers, next action) within 5 seconds, without interrupting the running execution.
- **SC-014**: After an intentional pause mid-phase, the orchestrator resumes from the exact pause point with no re-execution of completed work and no loss of decisions made during the paused session.
- **SC-015**: High-risk phases in a roadmap execute before low-risk phases (among those with satisfied dependencies), ensuring feasibility issues surface within the first 30% of milestone execution rather than at the end.
- **SC-016**: After rolling back a completed phase and re-executing it, all dependent downstream phases are flagged for review, the rollback reason is traceable in the decisions register, and the prior phase summary is preserved in the archive for historical reference.
- **SC-017**: Tier B projects complete with fewer than half the state files that Tier C produces — no lock files, no crash recovery artifacts, no knowledge consolidation output, no validation gate files — confirming the reduced surface is real, not just documented.
- **SC-018**: Running any orchestrator command twice in succession with no intervening changes produces identical disk state after both runs (idempotency).
- **SC-019**: When KNOWLEDGE.md contains 50+ entries across multiple scopes, a dispatch payload for a specific phase includes only scope-matched entries (project-wide + current milestone + current phase), not the full file — verifiable by inspecting the constructed context.
- **SC-020**: When a configured dispatch budget is reached during autonomous mode, the system pauses within 1 dispatch cycle of the threshold and surfaces the budget status, rather than continuing indefinitely.

## Clarifications

### Session 2026-03-18

- Q: What is the autonomous dispatch unit — phase or task? → A: Task-level dispatch. The orchestrator dispatches each task individually to a fresh context, verifies after each, and derives phase completion from task completion.
- Q: What are the canonical state machine phases and their file-based triggers? → A: Adopt GSD-2's 9-phase model: pre-planning, discussing, planning, replanning, executing, summarizing, validating, completing, complete. Each derived from file presence/absence on disk — no stored state field.
- Q: Where does orchestrator state live relative to spec-kit's specs/ directory? → A: Separate tree at `.specify/orchestrator/` with milestone/phase/task subdirs. Global orchestrator state references features by ID. Spec artifacts remain in `specs/{NNN}/`.
- Q: What concrete signals determine tier classification (A vs B vs C)? → A: Primary signal is the LLM's estimate of how many complete spec-kit process flows the work requires. Tier A: entire feature fits in ~1 context window (one or a few very small tasks, all SDD steps inline). Tier B: one complete SDD flow where each step fits in its own context window (tasks dispatch to separate contexts). Tier C: requires orchestrating two or more complete SDD flows with full coordination machinery.
- Q: Should the orchestrator use hooks, command composition, or hybrid for integrating with spec-kit's flow? → A: Hybrid. Use hooks at the 5 available points (before_tasks, after_tasks, before_implement, after_implement, before_commit) for lifecycle integration and context injection. Use command composition for SDD steps the orchestrator needs to augment with context but that lack hook points — in practice, the planning step is wrapped via `plan-phase.md`. The specify and clarify steps run at the project level before orchestration activates and do not require wrapping.
- Q: What is the relationship between the `discuss` command and technical research during roadmap generation? → A: Discussion captures human preferences and constraints (architectural decisions, scope boundaries, design tradeoffs). Technical research is performed by the agent during roadmap generation to understand the codebase and technical landscape. They are complementary — discussion informs _what_ to build and _how_ the developer wants it built; research informs _what exists_ and _what is technically feasible_. Discussion is a required gate for Tier C; research is performed as needed by the planning process.
- Q: What exactly does each stage of the two-stage review check? → A: Spec compliance checks phase-level integration that per-task verification misses: does the phase achieve its demo sentence, are all boundary map contracts satisfied as a complete interface surface, and was there scope creep (files/features not in the plan). Code quality checks cross-task consistency: naming conventions, error handling patterns, test coverage, and no leftover placeholders (TODO/FIXME). The two stages are sequential — spec compliance must pass before code quality review begins.
- Q: Can a completed phase be rolled back? → A: Yes. The developer can mark a phase for re-execution. The orchestrator clears the phase summary (moving it to archive), records a reversal decision, and flags dependent downstream phases for review. This is a manual developer action, not something the orchestrator does autonomously.
- Q: How are dispatch budgets enforced? → A: Budgets (dispatch count and cumulative duration per milestone) are advisory configuration. When reached, autonomous mode pauses. The developer can review and resume. Budgets are not hard limits — they are guardrails against unbounded resource consumption.

## Assumptions

- The developer has a working spec-kit installation (version >=0.1.0) in the project.
- The project uses git for version control and follows a feature-branch workflow.
- Agent runtimes provide at minimum: file read/write, shell command execution, and markdown rendering. Subagent dispatch is a bonus capability, not a requirement.
- The constitution file (`.specify/memory/constitution.md`) exists and governs all orchestrator behavior. The orchestrator's own constitution is already ratified.
- Context window sizes vary by agent and model, but a "context-window-sized unit" is defined by the task fitting comfortably within the agent's available context, leaving room for the plan, summaries, and agent reasoning.
- Disk I/O is fast enough that file-based state management does not create meaningful latency compared to agent response times.
- The developer is the sole operator during autonomous mode for a given milestone (no concurrent human operators modifying the same milestone's orchestrator state).

## Constraints

- Must be a valid spec-kit extension conforming to extension.yml schema version 1.0.
- Must not import, invoke, or wrap GSD-2 or APM binaries at runtime.
- Must use a hybrid integration strategy: leverage spec-kit's 5 available hook points (`before_tasks`, `after_tasks`, `before_implement`, `after_implement`, `before_commit`) for lifecycle integration and context injection at task/implement boundaries; use command composition (orchestrator commands wrapping spec-kit commands internally) for SDD steps that the orchestrator needs to augment with context but that lack hook points. In practice, the orchestrator wraps the planning step via `plan-phase.md` (which injects phase boundary maps, upstream summaries, and zero-context enforcement into the planning process). The specify and clarify steps run at the project level before orchestration activates and do not require wrapping — their outputs (spec.md) are consumed as inputs to the orchestrator's roadmap command. Hook commands check whether orchestration is active and no-op when it is not.
- Command resources (scripts, templates, references) must be discoverable from their command via `scripts` frontmatter declarations. Shared resources are organized by concern; single-command resources MAY be co-located.
- State on disk is the sole source of truth. No in-memory state across sessions.
- Every task must fit in one context window. No exceptions.
- Plans must assume zero context. An agent dropped into the repo cold must be able to execute any plan without reading files not referenced in the plan itself.
- All orchestrator commands must be idempotent. Running a command when its output already exists and is current must produce no change.
- Knowledge and decision injection into dispatch payloads must be scope-filtered, not whole-file. Unbounded context injection violates Principle I.
- The orchestrator MUST NOT override or replace core spec-kit commands via presets or any other mechanism. The command composition mechanism is exclusively new `speckit.orchestrator.*` commands that delegate to standard spec-kit workflows with injected context. Preset-based command replacement is prohibited.
- All state management, dispatch, and verification abstractions MUST be implementable in both local and CI execution contexts without forking the core logic. CI-specific behavior is confined to runtime adapter implementations, never to conditional branches in the orchestrator's core state machine, dispatch loop, or verification pipeline.
- **Deployment directory boundary**: `.specify/extensions/orchestrator/` is the APM/extension deployment target (overwritten on install). `.specify/orchestrator/` is the runtime state directory (never touched by APM or extension install). No APM primitive or extension install operation may target paths under `.specify/orchestrator/`. No runtime operation may modify files under `.specify/extensions/orchestrator/`. These two directory trees have strictly non-overlapping write ownership.

## Architecture: Static Configuration vs. Dynamic Runtime State

The orchestrator enforces an explicit boundary between static configuration and dynamic runtime state. No configuration setting changes during orchestration execution. No runtime state is stored in configuration files.

| Item | Category | Location | Mutability During Execution |
|---|---|---|---|
| Default tier | Static config | spec-kit multi-layer config (see FR-040) | Immutable |
| Verification commands | Static config | spec-kit multi-layer config | Immutable |
| Context verbosity | Static config | spec-kit multi-layer config | Immutable |
| Git isolation mode | Static config | spec-kit multi-layer config | Immutable |
| Dispatch budget | Static config | spec-kit multi-layer config | Immutable |
| Duration budget | Static config | spec-kit multi-layer config | Immutable |
| Current phase / state | Dynamic state | `.specify/orchestrator/` | Updated by orchestrator |
| Execution log | Dynamic state | `.specify/orchestrator/execution-log.jsonl` | Append-only |
| Decisions register | Dynamic state | `.specify/orchestrator/DECISIONS.md` | Append-only |
| Knowledge file | Dynamic state | `.specify/orchestrator/KNOWLEDGE.md` | Append-only |
| Lock files | Dynamic state | `.specify/orchestrator/orchestrator.lock` | Created/deleted per session |
| Phase summaries | Dynamic state | `.specify/orchestrator/milestones/{M###}/` | Written on phase completion |
| Continue files | Dynamic state | `.specify/orchestrator/continue.md` | Written on pause, consumed on resume |

**Rule**: Static configuration flows through spec-kit's multi-layer config system (extension defaults, project overrides, local overrides, environment variables). Dynamic state lives exclusively in `.specify/orchestrator/`. These two domains never overlap.
