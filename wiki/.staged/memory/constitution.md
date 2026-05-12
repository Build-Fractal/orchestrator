<!--
  Sync Impact Report
  ==================
  Version change: 2.2.1 → 2.3.0 (MINOR — Quality Gates section gains
  a new "Install gates" bullet per follow-on amendment Item 3 of
  .orchestrator/proposals/M0XX-tier-2-xxii-xii-substantive-followups.md;
  Candidate A / Tier 2 XXII inheritance shape changes materially —
  Invariant 3 (end-to-end install testing) relocates from XXII's
  invariant body to constitution Quality Gates as release-time
  evidence per Decision A Pathway 1; Items 1 + 2 also ship in this
  amendment batch — Invariant 1 reassigned to Principle XI
  enforcement; Invariant 2 X-distinctness sentence recorded.
  Operational definitions for "fresh project fixture" and "works"
  land in the new Quality Gates bullet body — Decision B resolved
  in this amendment.)

  Previous: 2.2.0 → 2.2.1 (PATCH — Principle VIII scope-boundary
  clarification per follow-on amendment Item 4; VIII bullet 1 made
  self-derivable without cross-reference to CONFORMANCE.md.)

  Previous: 2.1.0 → 2.2.0 (MINOR — Tier 2 inheritance declarations,
  amended guidance)

  Added (Tier 2 inheritance, recorded in CONFORMANCE.md not as new
  numbered principles):
    - Tier 2 XXII (Distribution Surface Integrity) — inherited from
      conversus; orchestrator-side evidence under scripts/verify/*.sh
      stubs + CHANGELOG.md single-source versioning.
    - conversus Tier 2 XII (No Dead Infrastructure) — inherited from
      conversus; orchestrator-side evidence via
      scripts/diagnostics/check-dead-infra.sh against
      templates/orchestrator-config-default.yml (41 leaves, baseline 0
      dead).

  Amended principles:
    - I. Context Minimization — appended clarification on total-task-
      tokens optimization target; L48 ratio carries PATCH-level
      proxy-status annotation.
    - VIII. No Dead Infrastructure — appended Tier 2 alignment
      paragraph clarifying scope boundary with inherited conversus
      Tier 2 XII (check-dead-infra.sh = config-knob class; run-doctor.sh
      = file-system-level reachability). At v2.2.1 the opening
      declaration was further PATCHed so the scope boundary is
      constitutionally self-derivable from VIII's plain text without
      requiring cross-reference to CONFORMANCE.md (per follow-on
      amendment Item 4).
    - XI. Single Source of Truth — at v2.3.0 a compliance-note
      paragraph appended documenting that
      scripts/verify/version-source-of-truth.sh is XI's enforcement
      script for installer-channel version SST. Reassigned from
      Candidate A / Tier 2 XXII per follow-on amendment Item 1
      (Decision A Pathway 1 ship-commit batch).

  Amended sections:
    - Quality Gates — at v2.3.0 gains a new "Install gates" bullet
      relocating Candidate A / Tier 2 XXII Invariant 3 (end-to-end
      install testing) from XXII's invariant body to release-time
      evidence per follow-on amendment Item 3 (Decision A Pathway 1).
      Bullet body carries the operational definitions for
      "fresh project fixture" and "works" — Decision B resolved
      in-this-amendment.

  Amended sections:
    - Governance — added one-paragraph cross-reference to conversus
      Inclusion Criteria for new principles (build-fractal Tier 1
      inheritance basis); orchestrator I-XV grandfathered.

  Unchanged principles (by number and body):
    - II, III, IV, V, VI, VII, IX, X, XI, XII, XIII, XIV, XV

  Ratification provenance:
    - Originating + self-consistency + blind deliberations 2026-05-11
      (.orchestrator/ratification/2026-05-11-XXII-XII/, all three
      gate-result.md files PASS).
    - Operator-routed Path 1 (accept headline PASS, defer blind's
      substantive distinctness findings to follow-on amendment).
    - Decision packet:
      .orchestrator/comments/review-queue/2026-05-11-XXII-XII-blind-substantive-findings.md
    - Deliberation log entries: .orchestrator/memory/CONSTITUTIONAL_CONVERSATIONS.md
      (three 2026-05-11 entries).

  Templates requiring updates:
    ⚠️ templates/phase-plan.md — Constitution Check may reference Tier 2
       XXII / conversus Tier 2 XII where applicable. Low urgency:
       templates dynamically load constitution; no hardcoded principle
       references.

  Prior version history:
    - 2.2.1: VIII bullet 1 PATCH (scope boundary self-derivable;
      2026-05-11)
    - 2.2.0: Tier 2 XXII + conversus Tier 2 XII inheritance
      declarations ratified (2026-05-11, Path 1)
    - 2.1.0: Added XIV-XV, amended II (success criteria) + III
      (ambiguity surfacing)
    - 2.0.0: Added VIII-XIII, amended II (event emission)
    - 1.0.0: Original I-VII
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
  *(Note: this ratio measures context payload efficiency as a proxy
  for the governing optimization target; the operative target is
  total task tokens across the full dispatch cycle, including
  exploration-recovery costs, per the clarification below.)*
- When this ratio degrades, the system is failing. Every design
  choice MUST be evaluated against this metric.
- **Minimize total task tokens** by delivering the right context
  efficiently — not by sending less context. The knowledge graph is
  the orchestrator's compression mechanism; bypassing it to "save
  tokens" typically increases total tokens spent because the agent
  recovers context the expensive way (exploration tokens) or
  produces lower-quality output that requires re-dispatch. Context
  minimization means *minimum sufficient context, delivered via the
  cheapest pipeline available*. A future execution path that
  proposes bypassing the knowledge graph + compression pipeline
  MUST justify the bypass with empirical token data showing total
  task tokens go down, not just payload size.

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
- Before execution begins, the task plan MUST transform the request
  into testable completion criteria. "Fix the bug" → "write a test
  that reproduces it, then make it pass." A task without upfront
  success criteria is incomplete — you cannot verify what you have
  not defined.
- Engine-managed scripts MUST emit structured events (`emit_event`)
  and a final result (`emit_result`). A script that runs to
  completion without emitting a RESULT line is treated as a silent
  failure. Events are the observable evidence trail for engine
  coordination — they are NOT optional instrumentation.

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
- The design step MUST surface uncertainty, not hide it. When a
  requirement has multiple valid interpretations, enumerate them
  and state which was chosen — do not silently pick one. Push back
  if a simpler approach exists. Stop and ask rather than guess.

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

### VIII. No Dead Infrastructure

Every file, script, template, and configuration file — interpreted
in this principle as a file-system artifact audited by
`scripts/diagnostics/run-doctor.sh` — MUST be reachable from a live
code path. Variable-level liveness of individual config knobs within
those files is outside this principle's scope; that variable-level
scope is governed by the inherited conversus Tier 2 XII (No Dead
Infrastructure) declaration enforced by
`scripts/diagnostics/check-dead-infra.sh`. Infrastructure that exists
"for future use" or "just in case" violates Context Minimization
(Principle I) by consuming context budget without delivering value.

- New files MUST be referenced by at least one command, script, or
  template before the phase is marked complete.
- Audit tooling (`run-doctor.sh`) MUST detect unreachable files and
  report them as warnings.
- Removing dead infrastructure is always cheaper than maintaining it.
  When in doubt, delete.

**Tier 2 alignment** (added 2026-05-11 by the XXII + conversus Tier 2
XII inheritance amendment): the build-fractal namespace carries
conversus Tier 2 XII (No Dead Infrastructure) governing config-knob,
schema-variable, and documented-consumer surfaces with
`scripts/diagnostics/check-dead-infra.sh` as the canonical linter.
VIII governs file-system-level infrastructure reachability with
`scripts/diagnostics/run-doctor.sh` as the canonical audit. The
scope boundary is declared explicitly in
[`CONFORMANCE.md`](../../CONFORMANCE.md) under the Component-tier
declarations § conversus Tier 2 XII inheritance row and its
three-bucket structure. Together VIII + inherited conversus Tier 2
XII discharge the orchestrator's full dead-infrastructure coverage.

### IX. Reproducibility Over Convenience

Given identical inputs (disk state, configuration, environment), any
orchestrator operation MUST produce identical outputs.
Non-determinism is a bug, not a feature.

- No inline `date` calls — use `$ORCH_STARTED_AT` or run-context
  timestamps.
- No random identifiers without seed control — `ORCH_RUN_ID` is
  deterministic when seeded.
- Recipe-driven assembly produces the same payload given the same
  recipe and source files.
- If a script's output varies between runs with identical inputs, it
  is broken.

### X. Templating Over Inference

Configuration and policy MUST be declared in templates (YAML recipes,
routing config, hooks config), not inferred by scripts at runtime.
Scripts implement mechanics; templates declare policy.

- Context assembly sections, order, and priority: declared in
  `context-recipe.yaml`.
- Compression strategy and thresholds: declared in the recipe's
  `compression:` block.
- Model selection and fallback chains: declared in `routing.yaml`.
- Hook lifecycle points and behavior: declared in `hooks.yaml`.
- When a behavior is controlled by a template, changing it requires
  editing the template — not the script. This is the design goal.

### XI. Single Source of Truth

Every piece of orchestrator state, configuration, and knowledge MUST
have exactly one authoritative location. Duplication across files is
a consistency bug waiting to happen.

- State: derived from disk by `derive-phase.sh` — no cached state
  variables.
- Configuration: `orchestrator-config.yml` with specificity resolution
  (task > phase > milestone > default).
- Knowledge: three-temperature storage (hot index, warm detail files,
  cold archive) with one entry per concept.
- Roadmap phase status: the roadmap file is the single source; phase
  directories are artifacts, not status indicators.
- **Installer-channel version SST** (added 2026-05-11 at v2.3.0 per
  follow-on amendment Item 1 of
  `.orchestrator/proposals/M0XX-tier-2-xxii-xii-substantive-followups.md`,
  reassigned from Candidate A / Tier 2 XXII Invariant 1 under
  Decision A Pathway 1): the version string consumed by every
  per-runtime installer in `packaging/install/install-*.sh` and by
  every bundle manifest in `packaging/bundle/*/manifest.txt` MUST
  derive from the `CHANGELOG.md` top-line `## [X.Y.Z]` heading. No
  installer or manifest may embed a hardcoded version literal.
  Enforcement script: `scripts/verify/version-source-of-truth.sh`
  (PENDING per CONFORMANCE.md § Tier 2 XXII PENDING/ACTIVE
  verifier-stub cap — the cap row remains in the XXII table by
  convention because the stub was created in that lineage; the cap's
  failure-consequence rollup attributes this row's ADVISORY demotion
  to Principle XI rather than Tier 2 XXII at v2.3.0).

### XII. Hook Isolation

Hook scripts operate in a sandbox: they receive a read-only state
snapshot and produce stdout/stderr output. They MUST NOT modify
engine state, write to orchestrator directories, or have side effects
on the dispatch pipeline.

- State snapshots are `chmod 444` temp files deleted after hook
  execution.
- Hooks that violate isolation (force-write to snapshot, write to
  orchestrator paths) trigger a `HOOK_VIOLATION` event.
- Hook timeout is enforced (default 30s). Hooks that exceed timeout
  are killed and recorded as failures.
- This principle exists because hooks are the integration seam for
  external tools (Conversus, monitoring). An untrusted hook MUST NOT
  be able to corrupt orchestrator state.

### XIII. Agent Instruction Schema

Dispatch instructions (the payload assembled for executing agents)
MUST follow a declared, inspectable schema. Ad-hoc instruction
assembly produces inconsistent agent behavior and prevents variance
analysis.

- The instruction schema declares required sections, optional
  sections, and section ordering.
- Context recipes (`context-recipe.yaml`) are the mechanism for
  schema declaration.
- New instruction formats require a recipe change — not a script
  change.
- This principle enables systematic analysis of what context agents
  receive and how it correlates with task outcomes. Progressive
  migration: new instructions conform immediately, existing
  instructions migrate as they are touched.

### XIV. No Speculative Complexity

Every implementation MUST deliver exactly what was requested —
nothing more. Complexity is debt that consumes context budget
(Principle I) and increases maintenance surface.

- No features beyond what was asked.
- No abstractions for single-use code. Three similar lines are
  better than a premature helper.
- No "flexibility" that was not requested. Extension points and
  configurability are features requiring justification.
- No error handling for impossible scenarios. Validate at system
  boundaries only.
- Litmus test: would a senior engineer say "this is
  overcomplicated"? If yes, rewrite.

### XV. Surgical Precision

Every changed line MUST trace directly to the request. Code
outside the request scope is not yours to modify.

- Do NOT "improve" adjacent code. Refactoring is a separate task
  with its own plan.
- Do NOT refactor working code. Ugly but working code is still
  working code.
- Match the existing style even if you would do it differently.
- If you notice unrelated issues: record them in the task summary
  (Principle VII). Do NOT fix them in-scope.
- Verification: `git diff` should contain no hunks that cannot be
  justified by the task plan's stated objective.

## Constraints

- Standalone-first: MUST work as a direct Claude Code extension
  without requiring spec-kit. Spec-kit integration is an optional
  mode, not a prerequisite.
- MUST NOT require GSD-2, APM, or spec-kit as runtime dependencies.
  Principles are ported from these systems, not wrapped.
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
- **Install gates** (added 2026-05-11 at v2.3.0 per follow-on
  amendment Item 3 of
  `.orchestrator/proposals/M0XX-tier-2-xxii-xii-substantive-followups.md`,
  shipping Candidate A / Tier 2 XXII Invariant 3 to its constitutional
  structural home as release-time evidence rather than as an
  architectural invariant): every version-tag publication triggering
  the GH release automation workflow introduced in [M035](milestones/M035/index.md) runs each
  per-runtime installer in `packaging/install/install-*.sh` against a
  **fresh project fixture** and verifies that the installation
  **works**. Both operational terms are defined below to satisfy
  Principle II's mechanical-gate requirement; the gate emits a
  deterministic PASS/FAIL without human judgment. Evidence:
  `scripts/verify/installer-smoke.sh` (PENDING per CONFORMANCE.md
  § Tier 2 XXII — PENDING/ACTIVE verifier-stub cap; promotion to
  ACTIVE per the cap's promotion conditions).
  - **Fresh project fixture**: a temporary directory containing only
    the files the installer places there, with no prior
    `.orchestrator/` state. The fixture is created immediately
    before and destroyed immediately after each release gate run.
    Where a runtime requires pre-existing scaffold files before the
    installer can be invoked, those files MUST be enumerated
    explicitly in the smoke test fixture's documented preconditions
    and MUST NOT overlap with any file that the installation itself
    places. A fixture specification that requires runtime-specific
    preconditions must document those preconditions in a named
    fixture manifest file within `scripts/verify/`.
  - **Works**: the installer invocation exits with code 0 and the
    resulting project's status command exits with code 0 and emits
    at least one line of output matching the structured status
    format. These are the minimum conditions for
    `installer-smoke.sh` to emit a deterministic PASS/FAIL without
    human judgment.
  - **Non-substitutability**: ad-hoc freshly-generated directories
    are not acceptable. Non-deterministic environments violate
    Principle IX (Reproducibility Over Convenience); the fixture
    discipline above is the determinacy mechanism.

## Governance

- **Inclusion Criteria for new principles** (added 2026-05-11) are
  defined in the build-fractal suite constitution's Governance
  section (`build-fractal/conversus/CONSTITUTION.md` §
  "Inclusion Criteria for New Principles") and apply to orchestrator
  amendments by Tier 1 inheritance per
  [`CONFORMANCE.md`](../../CONFORMANCE.md). The three tests
  (mechanical verification capability / falsifiable scope /
  distinctness) are not re-stated here — amendment authors follow
  the cross-reference. Orchestrator principles I-XV are grandfathered
  and are not retroactively required to satisfy these tests.
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

**Version**: 2.3.0 | **Ratified**: 2026-03-18 | **Last Amended**: 2026-05-11
