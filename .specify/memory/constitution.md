<!--
  Sync Impact Report
  ==================
  Version change: N/A → 1.0.0 (initial ratification)

  Added principles:
    - I. Context Minimization
    - II. Evidence Before Claims
    - III. Design Before Code
    - IV. Plans Assume Zero Context
    - V. Fresh Context Per Unit
    - VI. State On Disk Is Truth
    - VII. Knowledge Compounds

  Added sections:
    - Constraints
    - Quality Gates
    - Governance

  Templates requiring updates:
    ✅ .specify/templates/plan-template.md — Constitution Check section
       dynamically loads from this file; no edits needed.
    ✅ .specify/templates/spec-template.md — Generic template; no
       constitution-specific references to update.
    ✅ .specify/templates/tasks-template.md — Generic template; no
       constitution-specific references to update.
    ✅ .specify/templates/commands/*.md — No outdated references found.

  Follow-up TODOs: None.
-->

# Speckit-Orchestrator Constitution

## Core Principles

### I. Context Minimization

Every architectural decision MUST optimize for minimizing the context
each individual task consumes.

- Distribute knowledge hierarchically (not in monolithic files).
  Closest context takes precedence; broad knowledge lives at the root,
  narrow knowledge lives deep in the hierarchy.
- Use fresh sessions per task (not accumulated garbage from prior
  tasks). Each session starts clean.
- Produce structured summaries (not raw transcripts). Summaries are
  the handoff artifact between units of work.
- The optimization target:
  `Context_Efficiency = Relevant_Instructions / Total_Instructions_Inherited`
- When this ratio degrades, the system is failing. Every design
  choice MUST be evaluated against this metric.

### II. Evidence Before Claims

No task is marked complete without fresh verification evidence.

- "Should work" is NOT evidence. "Tests passed last time" is NOT
  evidence. "I followed the plan" is NOT evidence.
- The verification sequence is: run the command → read the output →
  confirm the result matches expectations → THEN claim completion.
- Verification is a mechanical gate, not an LLM compliance exercise.
  Must-haves (Truths, Artifacts, Key Links) MUST be checkable without
  human judgment.
- If verification cannot be performed mechanically, the task plan
  MUST specify what evidence constitutes proof.

### III. Design Before Code

Every piece of work MUST go through an explicit design step, no
matter how "simple" it seems.

- Simple projects are where unexamined assumptions cause the most
  wasted work.
- The mandatory pipeline: brainstorm → plan → execute → review.
- No implementation without an approved design. The design gate is a
  HARD GATE — rationalization ("this is too simple to need a design")
  is a red flag, not a valid exemption.
- Design artifacts are lightweight and proportional to scope, but
  they MUST exist.

### IV. Plans Assume Zero Context

Implementation plans MUST be written as if the executing agent has
zero codebase context and questionable taste.

- Document everything: exact file paths, complete code, exact
  commands with expected output, verification steps with expected
  results.
- An agent dropped into the repo cold MUST be able to execute the
  plan without reading any file not referenced in the plan itself.
- Plans that require the executor to "figure it out" or "use
  judgment" are incomplete plans.
- Each plan MUST include verification commands so the executor can
  confirm success without external guidance.

### V. Fresh Context Per Unit

Each unit of work (task, phase) MUST execute in a fresh context that
receives ONLY what it needs.

- The orchestrator constructs the minimal context payload for each
  dispatch. This payload is explicitly defined, not implicitly
  inherited.
- Subagents MUST NOT inherit the orchestrator's session history.
  They receive: task plan + dependency artifacts + relevant
  constitution principles. Nothing else.
- This prevents context rot and preserves the orchestrator's context
  budget for coordination work.
- If a task requires context from a prior task, it receives the
  prior task's structured summary — never the raw session.

### VI. State On Disk Is Truth

No in-memory state across sessions. All state MUST be recoverable
from files on disk.

- The state machine reads disk state, determines the next action,
  executes, and persists results back to disk.
- Crash recovery derives entirely from file state: lock files for
  detecting interrupted work, session forensics for determining what
  completed, structured summaries for resumption context.
- Stuck detection derives from file state: if the same unit is
  dispatched twice without progress artifacts appearing on disk, the
  system is stuck.
- If it is not on disk, it did not happen. No exceptions.

### VII. Knowledge Compounds

Every phase of work MUST produce structured, discoverable
documentation.

- Required outputs: what was built, what patterns were used, what
  decisions were made, what interfaces were established, what was
  learned.
- This accumulated knowledge hierarchy is the orchestrator's most
  valuable output — more valuable than the code itself, because it
  compounds.
- Each task that generates good documentation makes every future
  task cheaper to execute by reducing the context that task needs
  to consume (reinforces Principle I).
- Knowledge artifacts are NOT optional. They are mandatory outputs
  at every level: task summaries, phase summaries, milestone
  summaries, decisions registers, lessons learned.
- The knowledge base uses hierarchical placement: project-wide
  knowledge at the root, phase-specific knowledge near the phase,
  component-specific knowledge near the component.

## Constraints

- This is a spec-kit extension — MUST be installable via
  `specify extension add`.
- MUST work with all spec-kit-supported agents: Claude Code,
  Copilot, Cursor, Gemini CLI.
- MUST NOT require GSD-2 or APM as runtime dependencies. Principles
  are ported from these systems, not wrapped. No import or invocation
  of GSD-2 or APM binaries at runtime.
- MUST degrade gracefully:
  - No subagent capability → fall back to sequential in-session
    execution.
  - No GitHub Agentic Workflows → operate locally only.
  - No APM → manual skill/prompt installation.
- Every task MUST fit in one context window. This is the "iron rule."
  If a task cannot fit, it MUST be decomposed into two or more tasks.
  There are no exceptions.

## Quality Gates

- No phase advances without verification evidence (Principle II).
  The gate is mechanical: required artifacts MUST exist on disk with
  passing verification status.
- Two-stage review after implementation:
  1. **Spec compliance review**: Did we build what was specified?
     Catches over-building and under-building.
  2. **Code quality review**: Is it built well? Catches
     implementation issues.
  Reviews MUST NOT be skipped. "Close enough" is not passing.
- Knowledge artifacts are mandatory outputs, not optional
  nice-to-haves (Principle VII). A phase that produces code but no
  knowledge documentation is an incomplete phase.
- Constitution compliance is checked at two points:
  1. At plan time (before implementation begins).
  2. After implementation (before the phase is marked complete).
  Violations MUST be justified in a Complexity Tracking table or the
  design MUST be changed.

## Governance

- This constitution supersedes all other project guidance. In case of
  conflict between the constitution and any other document, the
  constitution wins.
- Amendments require:
  1. Explicit version bump following semantic versioning:
     - MAJOR: Principle removal or backward-incompatible redefinition.
     - MINOR: New principle or materially expanded guidance.
     - PATCH: Clarifications, wording, non-semantic refinements.
  2. Documented rationale for the change.
  3. Consistency propagation across all dependent templates.
- All phases MUST verify compliance with this constitution.
  Violations require either:
  - Justification in the Complexity Tracking table (with rationale
    for why the simpler alternative was rejected), OR
  - A design change to achieve compliance.
- Compliance review expectations: every plan and every implementation
  review MUST include an explicit constitution check section
  referencing each applicable principle by number.

**Version**: 1.0.0 | **Ratified**: 2026-03-18 | **Last Amended**: 2026-03-18
