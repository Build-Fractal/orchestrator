**Speckit-Orchestrator**

Spec Overview

*Autonomous Multi-Phase Orchestration for Spec-Kit*

Feature Branch: 001-speckit-orchestrator

Status: Draft  |  Created: March 18, 2026

# **Executive Summary**

Speckit-Orchestrator is a spec-kit extension that adds autonomous multi-phase orchestration to spec-kit's spec-driven development (SDD) workflow. It solves a fundamental problem: spec-kit works exceptionally well within a single context window, but complex projects spanning multiple context windows lose coherence, context, and quality as work crosses session boundaries.

The orchestrator introduces intelligent scope triage (classifying work into the right execution tier), structured phase decomposition with dependency management, autonomous task dispatch to fresh agent contexts, crash recovery, and continuous knowledge generation that makes each phase of work build on the last.

| The Core Idea A developer describes what they want to build. The orchestrator classifies the scope, decomposes it into phases and tasks that each fit in one context window, dispatches each task with only the context it needs, verifies results mechanically, persists structured knowledge, and advances autonomously — until the work is done or a blocker requires human judgment. |
| :---- |

# **How It Works: The Three Tiers**

Every project starts with scope triage. The orchestrator evaluates a natural language description and classifies it into one of three execution tiers based on how many complete spec-kit process flows (specify → clarify → plan → tasks → implement) the work requires. The developer can always override the classification.

| Capability | Tier A | Tier B | Tier C |
| :---- | :---- | :---- | :---- |
| Scope | One context window | One SDD flow, multi-context | 2+ SDD flows, full orchestration |
| Roadmap | None | Single milestone, flat phases | Multi-milestone, nested |
| Dispatch | Inline | Developer-driven | Autonomous |
| Crash Recovery | N/A | None (manual sessions) | Lock files, stuck detection, resume |
| Knowledge Mgmt | None | Optional | Full (decisions, knowledge, consolidation) |
| Verification | Standard spec-kit | Per-task must-haves | Per-task \+ two-stage phase review |
| State Machine | N/A | 5 states (simplified) | 9 states (full) |

## **Tier A: Zero Overhead**

If the work fits in a single context window (a bugfix, a small feature, a tweak), the orchestrator stays out of the way. It routes directly to standard spec-kit commands with no additional files, directories, or ceremony. This is critical: the orchestrator must never slow down simple work.

## **Tier B: Structured Handoff**

For projects requiring one complete SDD flow where each step needs its own context window, Tier B adds a lightweight orchestration layer. The developer gets a single-milestone roadmap with flat phases, per-task dispatch to separate contexts, must-have verification, and phase summaries. But the developer drives each step transition manually. There are no lock files, no crash recovery machinery, no autonomous mode. The state machine is simplified to five states: pre-planning → planning → executing → summarizing → complete.

## **Tier C: Full Orchestration**

For projects requiring two or more complete SDD flows, Tier C activates the full orchestration engine: multi-milestone roadmaps, autonomous dispatch, crash recovery with stuck detection, pre-planning discussion gates, two-stage phase reviews, knowledge consolidation, and the complete nine-state state machine. This is the "start it and walk away" mode.

# **Work Hierarchy**

The orchestrator structures all work into three levels:

* **Milestones** — Shippable versions of the project, containing 4–10 phases. Each has a vision statement, success criteria, and a roadmap with boundary maps.

* **Phases** — Demoable vertical capabilities within a milestone, containing 1–7 tasks. Each has a goal, a demo sentence (what the user can see or do when it completes), must-haves, and dependency declarations.

* **Tasks** — Context-window-sized units of work and the atomic dispatch unit. Each task fits in a single agent context window. This is non-negotiable. If a task can't fit, it must be decomposed further.

| Why This Hierarchy Matters The hierarchy exists to solve a specific problem: agent context windows are finite. By decomposing work into tasks that each fit in one window, the orchestrator ensures every dispatch gets clean, focused context. Phase and milestone boundaries then provide natural verification checkpoints and knowledge persistence points. |
| :---- |

# **Roadmap and Decomposition**

For Tier B and C projects, the orchestrator generates a roadmap from the spec. The roadmap includes:

* **Phase definitions** with demo sentences describing the user-visible outcome

* **Dependency declarations** between phases, determining execution order

* **Risk classifications** — high-risk phases execute first (among those with satisfied dependencies) to validate feasibility early

* **Boundary maps** specifying concrete interfaces each phase produces and consumes: function signatures, type definitions, endpoints, or file paths

Boundary maps are central to cross-phase coordination. They declare what each phase will produce and what downstream phases will consume, enabling the orchestrator to mechanically verify that a phase actually delivered what it promised before letting dependent work begin.

For Tier C, the orchestrator supports roadmap reassessment after each phase completes. Phases can be reordered, added, or removed based on what's discovered during execution. Reassessment considers deviations recorded in the completed phase's summary, new interfaces discovered, decisions that invalidate downstream assumptions, and risk reclassifications. Completed phases are never modified by reassessment.

# **Autonomous Dispatch (Tier C)**

Autonomous dispatch is what transforms the orchestrator from a planning tool into an execution engine. The dispatch loop works as follows:

1. **1\. Read disk state** — determine the next eligible task

2. **2\. Construct minimal context payload** — only the task plan, phase plan excerpt, relevant upstream summaries, applicable decisions, and constitution principles. No session history.

3. **3\. Dispatch to fresh agent context** — the task executes in isolation

4. **4\. Verify completion** — mechanical checks (file existence, content, connections), not the agent's self-assessment

5. **5\. Persist results** — write the task summary to disk

6. **6\. Advance** — move to the next task, or if all tasks are done, run the phase-level review

The developer can start autonomous mode and step away. The orchestrator continues until the milestone completes or a blocker requires human judgment. From a second terminal, the developer can check status, inject decisions, or steer the project without interrupting execution.

| Escalation Path for Blockers When a task reports it's blocked, the orchestrator follows a structured escalation: (1) provide more context and retry, (2) break the task into smaller units, (3) pause and surface the blocker to the developer. This prevents infinite loops while giving the system a chance to self-correct. |
| :---- |

# **Verification Model**

Verification operates at two tiers, matching the dispatch and review granularity:

## **Per-Task Verification**

After each task dispatch completes, the orchestrator mechanically verifies must-haves in three categories:

* **Observable truths** — behaviors that must be true when done

* **Required artifacts** — files that must exist with real content

* **Critical connections** — wiring between artifacts that must be verified

Configurable verification commands (lint, test, build) also run at this boundary. This verification is independent of the agent's self-assessment — the orchestrator checks mechanically.

## **Per-Phase Review (Two-Stage)**

After all tasks in a phase pass verification, the orchestrator runs a two-stage review. Spec compliance must pass before code quality review begins.

* **Spec Compliance** — Does the phase achieve its demo sentence? Are all boundary map contracts satisfied? Did scope creep occur? Is the phase-level integration correct (individual tasks may pass while the whole fails)?

* **Code Quality** — Are naming conventions consistent across tasks? Is error handling uniform? Does test coverage meet thresholds? Are there leftover TODOs/FIXMEs or dead code?

# **State Management**

All orchestrator state is persisted to disk under .specify/orchestrator/ as a separate tree from spec-kit's feature directories. No in-memory state survives across sessions. The orchestrator derives its complete state by reading files on disk.

## **State Machine (Tier C)**

The full state machine has nine states, each derived deterministically from file presence or absence on disk (no stored state field):

* **pre-planning** — milestone directory exists but no roadmap

* **discussing** — context draft exists, needs full discussion before planning

* **planning** — roadmap exists, active phase has no plan

* **replanning** — phase needs replanning due to new info or failure

* **executing** — active task exists and is not yet done

* **summarizing** — all tasks done but no phase summary

* **validating** — all phases done but no milestone validation

* **completing** — validation passed but no milestone summary

* **complete** — milestone summary exists

Tier B uses a simplified five-state subset: pre-planning → planning → executing → summarizing → complete.

# **Knowledge Management**

Knowledge generation is what makes the orchestrator's output compound over time. Without it, each subsequent phase must rediscover context from raw code. The goal: make phase N+1 cheaper than phase N.

## **Phase Summaries**

Every completed phase produces a structured summary containing what was built, patterns established, decisions made, interfaces created, files affected, and verification results. These summaries serve as context input for downstream phases — only relevant summaries from upstream dependencies are loaded, not all summaries.

## **Decisions Register**

An append-only log of every architectural and design decision made during execution. Each entry records a sequential ID, scope, the decision question, the choice, the rationale, and whether it's revisable. Entries are never edited or removed — reversals are recorded as new entries referencing the original. This ensures every choice is traceable.

## **Knowledge File**

A cross-session memory file where patterns, rules, and lessons are recorded. Every entry has a scope tag (project-wide, milestone-specific, or phase-specific) that determines whether it's injected into dispatch payloads. This prevents unbounded context growth: only matching-scope entries are included.

## **Knowledge Consolidation**

After a milestone completes, the developer can consolidate verbose phase-level artifacts into compressed milestone summaries and archive raw artifacts. The compressed summaries preserve all critical information (decisions, boundary map contracts, established patterns) while reducing on-disk footprint by at least 60%. Future sessions read the compressed summary first and drill down to archived details only when needed.

# **Crash Recovery and Reliability**

Autonomous execution is only useful if it's reliable. The orchestrator provides several reliability mechanisms:

* **Lock files and stale detection** — On session start, the orchestrator checks whether a lock file's process is still running. Stale locks from crashed sessions are detected and handled.

* **Stuck detection** — If the same unit is dispatched twice without producing expected artifacts, the system stops retrying and reports the specific missing artifact. No infinite loops.

* **Recovery briefings** — After a crash, the orchestrator synthesizes context from surviving disk artifacts so the resumed phase knows what was previously attempted.

* **Graceful pause/resume** — The developer can intentionally pause autonomous mode. The orchestrator writes a structured continue file with the exact resume point, completed work, remaining work, and next action. On resume, the file is consumed and execution picks up exactly where it left off.

* **Phase rollback** — A completed phase can be marked for re-execution. The prior summary is archived, a reversal decision is recorded, and all dependent downstream phases are flagged for review.

# **Pre-Planning Discussion (Tier C)**

For Tier C projects, the orchestrator requires a discussion phase before roadmap generation. The discuss command creates a context draft file that captures architectural decisions, scope boundaries, design constraints, and open questions from the developer. This draft must be explicitly finalized before the system will generate a roadmap.

Discussion captures human preferences and constraints. It complements the technical research the agent performs during roadmap generation. Discussion informs what to build and how the developer wants it built; research informs what exists and what is technically feasible. For Tier B, discussion is optional.

# **Safety and Guardrails**

The orchestrator includes several mechanisms to prevent runaway or wasteful execution:

* **Dispatch and duration budgets** — Optional per-milestone caps on total dispatches and cumulative duration. When reached, autonomous mode pauses rather than continuing unbounded. Budgets are advisory; the developer can review and resume.

* **External modification detection** — At each phase boundary, the system detects if files in the phase scope were modified outside the orchestrator (by the developer or other tools). If so, it pauses for confirmation.

* **Phase scope enforcement** — During execution, agents are restricted to files declared in the phase plan. Out-of-scope modifications trigger verification warnings.

* **Destructive operation warnings** — File deletions, force-pushes, and database changes require explicit confirmation unless specifically authorized in the phase plan.

* **Idempotency** — Every orchestrator command is idempotent. Running a command when its output already exists produces no change, preventing accidental duplication.

* **Concurrent access safety** — State files support concurrent reads from a second terminal. Status queries and decision injection never corrupt the running execution.

# **File Structure and Key Artifacts**

All orchestrator state lives under .specify/orchestrator/, separate from spec-kit's specs/ feature directories. The key artifacts are:

* **Roadmap** — phase definitions, dependency graphs, boundary maps, feature reference

* **Phase/Task Summaries** — YAML frontmatter \+ markdown body; provides/requires/affects tracking, key files, drill-down paths

* **Decisions Register (DECISIONS.md)** — append-only table with ID, scope, decision, choice, rationale, revisability

* **Knowledge File (KNOWLEDGE.md)** — append-only list with category tags, scope tags, and dates

* **Execution Log (execution-log.jsonl)** — one JSON line per dispatch event with timestamp, unit, tier, duration, outcome

* **Lock File (orchestrator.lock)** — PID, session metadata, completed units (for crash detection)

* **Continue File (continue.md)** — exact resume point, completed/remaining work, next action (consumed on resume)

* **Context Draft ({M\#\#\#}-CONTEXT.md)** — pre-planning discussion artifact with finalization gate

* **Configuration (config.json)** — tier, verification commands, verbosity, git isolation, budgets

# **Integration with Spec-Kit**

The orchestrator is a valid spec-kit extension with an extension.yml manifest. It integrates via a hybrid approach:

* **Hooks** — lifecycle integration at spec-kit's four available hook points (before\_tasks, after\_tasks, before\_implement, after\_implement) for context injection at task/implement boundaries

* **Command composition** — for SDD steps without hooks (plan, specify, clarify), orchestrator commands wrap spec-kit commands, injecting orchestrator context before delegating

The orchestrator works with all spec-kit-supported agent runtimes without agent-specific code paths. At startup, it detects capabilities (subagent dispatch, shell execution, git, CI environment) and selects the best available execution strategy.

# **Optional: GitHub Agentic Workflows**

The orchestrator can optionally run as a GitHub Agentic Workflow, triggered by schedule, issue creation, or comment command. This enables overnight and unattended orchestration in CI without requiring a local terminal. All functionality works locally without degradation when GitHub workflows aren't available.

# **Success Criteria Highlights**

The spec defines 20 measurable success criteria. Key highlights:

* Tier classification to initial roadmap in under 5 minutes

* Each task's context payload uses less than 20% of total accumulated artifacts

* 5-phase milestones complete autonomously without human intervention (absent blockers)

* Crash recovery resumes within 2 minutes with no lost work

* Stuck detection triggers within 2 dispatch cycles

* Knowledge consolidation reduces artifact footprint by 60%+ while preserving critical information

* Tier A projects see zero additional overhead — no extra files, no extra prompts

* 100% of phase transitions include mechanical must-have verification

* Progress queryable from a second terminal in under 5 seconds

* All commands are idempotent — running twice produces identical disk state

# **Implementation Priority**

The spec defines eight user stories in priority order, designed so each builds on the last:

| Priority | Story | What It Enables |
| :---- | :---- | :---- |
| P1 | Scope Triage | Gateway decision — determines all downstream behavior |
| P2 | Phase-by-Phase Execution | Core orchestration: decomposition, handoff, summaries |
| P3 | Autonomous Dispatch | "Start and walk away" execution engine |
| P4 | Knowledge Generation | Structured docs that make each phase cheaper than the last |
| P5 | Crash Recovery | Reliable autonomous execution with stuck detection |
| P6 | Knowledge Consolidation | Compressed summaries, archived raw artifacts |
| P7 | GitHub Workflows | CI-based overnight orchestration |
| P8 | APM Packaging | One-command install distribution |

# **Key Constraints**

* Must be a valid spec-kit extension (extension.yml manifest, hook registrations)

* Must not import or wrap GSD-2 or APM at runtime — principles are ported, not dependencies

* Disk state is the sole source of truth — no in-memory state survives across sessions

* Every task must fit in one context window — no exceptions

* Plans must assume zero context — a cold agent can execute any plan from the plan itself

* All commands must be idempotent

* Knowledge and decision injection must be scope-filtered, not whole-file

# **Assumptions**

* Working spec-kit installation (version \>= 0.1.0)

* Git-based version control with feature-branch workflow

* Agent runtimes provide file read/write, shell execution, and markdown rendering at minimum

* Constitution file exists and governs orchestrator behavior

* Single developer operates autonomous mode per milestone (no concurrent human operators on same state)