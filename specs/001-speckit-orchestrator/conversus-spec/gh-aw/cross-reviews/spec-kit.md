# Cross-Review: spec-kit's UTILIZATION.md

**Reviewer**: gh-aw (GitHub Agentic Workflows)
**Document reviewed**: `conversus/spec-kit/UTILIZATION.md`
**Date**: 2026-03-18

---

## 1. Dangerous Contradictions

### 1.1 Command Composition via Wrapping vs. CI Dispatch Boundaries

**spec-kit position** (Section 4, Off-Base Assumption 3): The orchestrator should wrap core spec-kit commands (`specify`, `plan`, `clarify`) via either (a) new `speckit.orchestrator.*` commands that internally instruct the LLM to delegate to the standard workflow, or (b) preset-based overrides that replace the standard commands with orchestrator-augmented versions.

**gh-aw position** (Section 3, Missed Opportunity: `dispatch-workflow`; Section 5, Recommendation 2): Task dispatch in CI must use `dispatch-workflow` as the dispatch primitive, where each dispatched unit is an independent GitHub Actions workflow run with its own context, typed inputs, and compile-time validation. The orchestrator's job is to *dispatch work units*, not to *wrap commands within a single agent session*.

**Why this is dangerous**: spec-kit's wrapping model assumes a single long-running agent session where the orchestrator intercepts commands mid-execution to inject context. This is fundamentally incompatible with CI dispatch, where each workflow run is a discrete, stateless unit that cannot "wrap" a command running in a different process. If the spec follows spec-kit's wrapping recommendation, the entire command composition layer must be redesigned for CI -- the abstraction does not survive the process boundary. The spec must decide whether orchestration commands *compose within a session* (spec-kit's model) or *dispatch across sessions* (gh-aw's model). For Tier C, these are mutually exclusive architectural choices, not complementary options. Implementing the wrapping model first and then attempting to bolt on CI dispatch later (per the spec's P7 priority for US-7) will produce a design that works locally but cannot be mapped onto gh-aw's workflow dispatch without a rewrite of the command layer.

**gh-aw's position**: The dispatch model must be the foundational abstraction. Local execution is dispatch-to-self (same machine, fresh context). CI execution is dispatch-to-workflow (GitHub Actions run). Both share the same payload contract and state protocol. Command wrapping within a session is a local optimization, not an architectural primitive.

---

### 1.2 Preset-Based Template Overrides vs. Dispatch Payload Isolation

**spec-kit position** (Section 5, Recommendation 2): Create a companion `speckit-orchestrator` preset that overrides `spec-template`, `plan-template`, and `tasks-template` with orchestrator-aware versions. When orchestration is active, these templates include milestone references, phase scope, and boundary map sections.

**gh-aw position** (Section 2, Alignment: Fresh Context Per Dispatch; Section 4, Off-Base Assumption: File-based state): Each dispatched unit must operate with a minimal, self-contained payload. The orchestrator constructs the context needed for a task and sends it via `workflow_dispatch.inputs` or repo-memory. The dispatched worker should not depend on templates that happen to be installed in the repo's `.specify/` directory at the time of execution.

**Why this is dangerous**: Preset-based template overrides create implicit environmental dependencies. A dispatched worker that relies on an orchestrator-aware `plan-template` being present in the repo's preset stack will silently produce wrong output if: (a) the preset is not installed, (b) a different preset overrides it, (c) the worker runs in a fork or CI environment without the preset, or (d) a concurrent phase changes the preset configuration mid-execution. The spec's Constitution Principle 4 ("Plans Assume Zero Context") is directly violated by templates that assume orchestrator context is ambient. gh-aw's dispatch model makes this explicit: context travels with the payload, not through the environment.

**gh-aw's position**: Orchestrator context (milestone reference, phase scope, boundary maps) must be included in the dispatch payload, not injected via template overrides. Templates should remain generic. The orchestrator injects context into the *input* to the command, not into the *template* the command uses.

---

### 1.3 Extension Config System vs. Repo-Memory for State Persistence

**spec-kit position** (Section 5, Recommendation 1): Replace the spec's custom `config.json` with spec-kit's multi-layer config system: `orchestrator-config.yml` with `defaults` in `extension.yml`, `.local.yml` overrides, and `SPECKIT_ORCHESTRATOR_*` env vars.

**gh-aw position** (Section 3, Missed Opportunity: Repo-memory; Section 5, Recommendation 3): Orchestrator state (decisions register, knowledge file, execution log, phase summaries) should live in repo-memory branches for CI durability. Each workflow run reads from the memory branch, operates, and auto-commits on completion.

**Why this is dangerous**: These two recommendations target different concerns but overlap in a harmful way for *runtime state*. spec-kit's config system is designed for static configuration (tier defaults, verification commands, verbosity settings). gh-aw's repo-memory is designed for dynamic runtime state that evolves across workflow runs. The danger is conflating the two: if the orchestrator uses spec-kit's config layers for settings that change during execution (e.g., current phase, active blockers, last checkpoint), those settings become stale the moment a CI workflow reads them from the repo's working tree. Conversely, if repo-memory is used for settings that should be project-controlled (e.g., default tier, verification commands), those settings become invisible to developers who expect to find them in config files.

**gh-aw's position**: Static configuration belongs in spec-kit's config system. Dynamic orchestration state belongs in repo-memory (CI) or `.specify/orchestrator/` (local). The spec must draw a clear boundary between configuration (changes rarely, human-authored, version-controlled in the main branch) and state (changes per-run, machine-authored, version-controlled in a memory branch or state directory). spec-kit's recommendation does not make this distinction.

---

### 1.4 Skill Folder Reconciliation Eliminates the Dispatch Payload Contract

**spec-kit position** (Section 4, Off-Base Assumption 2; Section 5, Recommendation 7): The spec's "skill folder" concept should be mapped onto spec-kit's extension primitives: trigger descriptions become command `description` fields, helper scripts go in `scripts/`, output templates go in `templates/`, references go in `docs/`, and user preferences use the config system. Eliminate the parallel "skill folder" abstraction.

**gh-aw position** (Section 2, Alignment: Fresh Context Per Dispatch; implicit in all dispatch recommendations): The spec's skill folder architecture (FR-028) serves a critical role that spec-kit's recommendation erases: it defines the *dispatch payload contract* -- the complete, self-contained package of instructions, scripts, templates, and references that a fresh agent context needs to execute a task. gh-aw's `dispatch-workflow` sends a payload to an independent workflow; the skill folder *is* that payload's structural definition.

**Why this is dangerous**: If skill folders are dissolved into spec-kit's extension directory structure (`scripts/`, `templates/`, `docs/` scattered across extension subdirectories), there is no longer a single unit that answers "what does a dispatched worker need to execute this command?" The dispatch payload becomes an assembly problem: gather the command from `commands/`, the scripts from `scripts/`, the templates from `templates/`, and the references from `docs/`. In CI, where the worker workflow runs in a clean checkout, this assembly must happen at dispatch time, and the orchestrator must know the full dependency graph of each command. The skill folder kept this implicit -- everything the command needs is in one directory.

**gh-aw's position**: The skill folder concept should be preserved as the dispatch payload unit. It can be *registered* with spec-kit's extension system (command metadata, hook declarations) but the folder itself should remain a cohesive unit. spec-kit's recommendation to scatter it across extension subdirectories optimizes for spec-kit's directory conventions at the expense of dispatch ergonomics.

---

## 2. Tensions

### 2.1 Hook-Based Lifecycle Integration vs. Workflow-Level Orchestration

**spec-kit** recommends deep integration through the 4 available hook points (`before_tasks`, `after_tasks`, `before_implement`, `after_implement`) plus the `condition` field for declarative activation checks (Section 3, Missed Opportunity on `condition` field; Section 4, Off-Base Assumption 1 on `before_*` hooks).

**gh-aw** operates at the workflow level: orchestration is expressed as workflow-to-workflow dispatch, not as hooks within a single command execution. gh-aw has no concept of "hooks within a step" -- its orchestration primitive is the workflow run.

**Tension**: For local execution, hooks are the right integration surface because the orchestrator lives in the same process as spec-kit. For CI execution, hooks are irrelevant because each spec-kit command runs in its own workflow. The spec must support both, which means the hook logic and the workflow dispatch logic must express the same orchestration semantics in two different paradigms.

**Resolution path**: Define the orchestration protocol (state transitions, verification gates, context injection) as a runtime-agnostic contract. Hooks implement the contract for local execution. Workflow dispatch implements the contract for CI. The contract is the source of truth, not either implementation.

---

### 2.2 Template Resolution Stack vs. Explicit Context Injection

**spec-kit** recommends using the template resolution stack (`presets > extensions > core`) to inject orchestrator context into specs and plans (Section 3, Missed Opportunities on presets and extension templates; Section 5, Recommendations 2 and 3).

**gh-aw** injects context explicitly via dispatch payloads and repo-memory reads. There is no template resolution stack in CI -- each workflow gets what it is given.

**Tension**: The template resolution stack is powerful for local development (modify templates once, all commands benefit) but creates hidden dependencies for CI (the worker must have the right templates installed). These are not incompatible, but they create divergent developer experiences: locally, changing a template changes all subsequent command output; in CI, the same change requires updating the dispatch payload construction.

**Resolution path**: Use templates for *formatting* (how output is structured) but not for *context* (what information is available). Orchestrator context (phase scope, boundary maps, prior decisions) should always be injected explicitly, whether via template variables (local) or dispatch payload fields (CI). Templates should not *contain* orchestrator context; they should have *slots* for it.

---

### 2.3 Community Catalog Distribution vs. gh-aw Workflow Distribution

**spec-kit** recommends catalog submission via `catalog.community.json` for discoverability through `specify extension search` (Section 3, Missed Opportunity; Section 5, Recommendation 10).

**gh-aw** distributes orchestration patterns as agentic workflow files (`.md` files in `.github/aw/`) that are either committed directly or referenced via `workflow_call`. The spec already mentions APM packaging (US-8).

**Tension**: Three distribution mechanisms (spec-kit catalog, APM package, gh-aw workflow files) create confusion about what the user installs and where. A developer who installs the spec-kit extension via the catalog does not automatically get the gh-aw workflows. A developer who copies the gh-aw workflows does not get the spec-kit extension commands.

**Resolution path**: Define a clear distribution hierarchy: the spec-kit extension is the primary package (installed via catalog or APM), and it *includes* gh-aw workflow templates in its `scripts/` or `templates/` directory. The extension's install hook copies workflow files to `.github/aw/` if gh-aw is detected. This makes the spec-kit extension the single distribution unit, with gh-aw support as an optional capability enabled at install time.

---

### 2.4 `requires.commands` Validation vs. CI Runtime Availability

**spec-kit** recommends declaring `requires.commands` in the extension manifest to validate that core spec-kit commands (`speckit.tasks`, `speckit.plan`, etc.) are present before installation (Section 5, Recommendation 4).

**gh-aw** CI workflows do not go through spec-kit's extension installation process. A workflow that dispatches a `speckit.plan` command assumes spec-kit is installed in the repo but has no mechanism to validate this at compile time.

**Tension**: `requires.commands` protects local installs but provides no safety net for CI execution. A gh-aw workflow that dispatches to a `speckit.plan` worker will fail at runtime if spec-kit is not installed, with no pre-flight check.

**Resolution path**: Add a `check-prerequisites` step to gh-aw orchestrator workflows that verifies spec-kit installation and required commands before dispatching. This is the CI equivalent of `requires.commands` -- same validation, different enforcement point.

---

### 2.5 Extension Config Schema Validation vs. Runtime Flexibility

**spec-kit** recommends a `config_schema` in the extension manifest with JSON Schema validation for settings like `default_tier`, `verification_commands`, `context_verbosity`, etc. (Section 5, Recommendation 5).

**gh-aw** passes configuration as workflow inputs, which are validated by GitHub Actions' input type system (string, boolean, choice, environment) at dispatch time. Workflow inputs can be overridden per-run.

**Tension**: A strict JSON Schema validates configuration at install time but cannot account for per-run overrides that CI dispatch enables. A developer might want to run a specific phase with `context_verbosity: full` for debugging without changing the installed config. spec-kit's schema validation and gh-aw's per-run input overrides enforce consistency at different points and with different flexibility.

**Resolution path**: The config schema should validate *defaults* at install time. Per-run overrides (whether via env vars per spec-kit's `SPECKIT_ORCHESTRATOR_*` convention or via workflow dispatch inputs per gh-aw's model) should bypass schema validation with a clear precedence order: workflow input > env var > local override > project config > extension defaults.

---

## 3. Safe Agreements

### 3.1 Separate State Tree at `.specify/orchestrator/`

**spec-kit** (Section 2, Alignment: Separate state tree): Correctly endorses placing orchestrator state at `.specify/orchestrator/` separate from `specs/`, consistent with spec-kit's convention where extensions store state under `.specify/extensions/{ext-id}/`.

**gh-aw** (Section 2, Alignment: Structured knowledge persistence): Agrees that orchestrator state must be persistent and structured. The `.specify/orchestrator/` path provides a clear local-execution state root that can be mapped to repo-memory branches for CI.

**Why this is safe**: Both reviews agree on the *location* and *separation* of orchestrator state from spec artifacts. The disagreement (addressed above in Tension 1.3) is about *persistence mechanisms* in CI, not about the logical separation. The path `.specify/orchestrator/` is a sound convention that both systems can work with.

---

### 3.2 Zero Overhead for Tier A

**spec-kit** (Section 2, Alignment: Zero overhead for Tier A): Correctly endorses that Tier A work routes directly to standard spec-kit commands with no orchestration ceremony.

**gh-aw** (Section 2, Alignment: Tiered execution with graceful degradation): Agrees that simple workflows should not incur the full dispatch infrastructure. gh-aw's own design philosophy supports the same principle: a `slash_command` triggering a single agent does not need multi-job orchestration.

**Why this is safe**: Both reviews agree that the tier system's primary value is *preventing over-engineering*. Neither review suggests Tier A should touch orchestration infrastructure. This is a foundational design decision both systems can build on without conflict.

---

### 3.3 Mechanical Verification at Phase Boundaries

**spec-kit** (Section 2, Alignment: Disk-only state): Endorses the file-presence-based state machine where status is derived from artifact existence, consistent with spec-kit's pattern of checking for `tasks.md` and `plan.md` existence.

**gh-aw** (Section 2, Alignment: Mechanical verification): Endorses the spec's insistence on mechanical (not self-assessed) verification, mapping it to gh-aw's deterministic-agentic pattern where deterministic steps handle validation.

**Why this is safe**: Both reviews agree that verification must be objective and automated. spec-kit grounds this in file-presence checks; gh-aw grounds it in deterministic pre/post steps. These are implementations of the same principle in different runtimes, and they do not conflict. The spec can require mechanical verification as a protocol-level contract and let each runtime implement it with its native tools.

---

### 3.4 Idempotent Command Design

**spec-kit** (Section 2, Alignment: Disk-only state): Implicitly requires idempotency through file-presence-based state derivation -- if the file already exists, the command is a no-op or an update, not a duplicate creation.

**gh-aw** (Section 2, Alignment: Idempotency requirement): Explicitly endorses FR-066's idempotency requirement as essential for CI retry scenarios and scheduled workflows.

**Why this is safe**: Both reviews agree that every orchestrator command must be safe to re-run. This is non-negotiable for CI (where retries are common) and beneficial for local execution (where developers may interrupt and restart). The spec's existing FR-066 is sufficient and both systems support it.

---

## Summary

The core disagreement between the two reviews is architectural: **spec-kit sees the orchestrator as an extension that enhances spec-kit's existing command execution model from within**, while **gh-aw sees the orchestrator as a dispatch system that uses spec-kit commands as execution units within a larger workflow**. spec-kit's recommendations optimize for deep integration with the framework's existing infrastructure (presets, templates, config layers, hooks). gh-aw's recommendations optimize for dispatch portability across execution environments (local terminals, CI runners, Copilot sessions).

Both perspectives are valid for their respective runtimes. The danger is in following one exclusively: pure spec-kit integration produces an orchestrator that only works locally; pure gh-aw integration produces an orchestrator that only works in CI. The spec must define a runtime-agnostic orchestration protocol and implement it twice -- once through spec-kit's extension primitives, once through gh-aw's workflow primitives -- sharing the same state contract, verification protocol, and dispatch payload format.
