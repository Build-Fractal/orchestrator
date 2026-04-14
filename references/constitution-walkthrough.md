# Constitution Walkthrough

> Progressive disclosure reference for the speckit-orchestrator constitution (v2.0).
> Self-contained — read this document to understand each governing principle with
> concrete codebase examples and compliance checks.

> Audience: contributors

## Overview

The speckit-orchestrator constitution (`.specify/memory/constitution.md`) is the supreme governance document for the project. It defines 13 principles that every architectural decision, script, template, and phase plan must satisfy. When the constitution conflicts with any other document, the constitution wins.

The constitution exists because orchestration is a coordination problem, and coordination fails when participants (agents, scripts, contributors) operate under different assumptions. The 13 principles encode the assumptions that every participant must share.

Principles I-VII were ratified with v1.0.0. Principles VIII-XIII were added in v2.0.0 to address patterns discovered during M002-M004 execution. Amendments follow semantic versioning: MAJOR for removal or incompatible redefinition, MINOR for new principles, PATCH for wording clarifications.

Compliance is checked at two points in every phase: before implementation begins (at plan time) and after implementation (before the phase is marked complete). Violations require either a justified entry in the Complexity Tracking table or a design change.

---

## Quick Reference Table

| # | Name | One-sentence summary |
|---|------|----------------------|
| I | Context Minimization | Every decision must optimize for reducing the context each task consumes. |
| II | Evidence Before Claims | No task is marked complete without fresh, mechanical verification evidence. |
| III | Design Before Code | Every piece of work must go through an explicit design step, no matter how simple. |
| IV | Plans Assume Zero Context | Implementation plans must be written as if the executor has zero codebase knowledge. |
| V | Fresh Context Per Unit | Each task executes in a fresh context that receives only what it needs. |
| VI | State On Disk Is Truth | All state must be recoverable from files on disk; no in-memory state across sessions. |
| VII | Knowledge Compounds | Every phase must produce structured, discoverable documentation. |
| VIII | No Dead Infrastructure | Every file, script, and template must be reachable from a live code path. |
| IX | Reproducibility Over Convenience | Given identical inputs, any operation must produce identical outputs. |
| X | Templating Over Inference | Policy is declared in templates, not inferred by scripts at runtime. |
| XI | Single Source of Truth | Every piece of state, configuration, and knowledge has exactly one authoritative location. |
| XII | Hook Isolation | Hook scripts operate in a sandbox with read-only state snapshots and enforced timeouts. |
| XIII | Agent Instruction Schema | Dispatch instructions follow a declared, inspectable schema. |

---

## Principles

### Principle I: Context Minimization

#### What It Means

Every architectural decision must optimize for minimizing the context each individual task consumes. The optimization target is:

```
Context_Efficiency = Relevant_Instructions / Total_Instructions_Inherited
```

When this ratio degrades, the system is failing. Knowledge is distributed hierarchically (broad at the root, narrow deep in the tree), sessions start fresh per task, and summaries replace raw transcripts as handoff artifacts.

#### Codebase Examples

- **`scripts/dispatch/build-context.sh`** constructs a minimal, scoped payload for each dispatched task. It reads the context recipe, resolves only the files needed for the specific milestone/phase/task combination, and assembles them into a single payload. It does not dump the entire orchestrator state; it selects what is relevant.

- **`scripts/dispatch/scope-filter.sh`** strips knowledge entries down to only those matching the current scope (project-level, milestone-level, or phase-level). Entries outside the task's scope are excluded from the payload, directly reducing `Total_Instructions_Inherited`.

- **`scripts/dispatch/compress-payload.sh`** applies compression to `compressible` sections when the payload exceeds the budget, preserving `required` sections verbatim. This is a mechanical enforcement of context minimization under budget pressure.

#### Common Violations

- Including the full `KNOWLEDGE.md` in every dispatch payload without scope filtering.
- Passing raw session transcripts between tasks instead of structured summaries.
- Storing broad project knowledge in a phase-level directory where only that phase's agent reads it.
- Adding "just in case" context sections to a dispatch payload (overlaps with Principle VIII).

#### How to Check Compliance

- Inspect `templates/context-recipe.yaml`: every section should have a `filter:` value (`scope`, `staleness`, `confidence`, or `none`). Sections marked `none` for filter should be `required` priority.
- After a dispatch, check that the payload size logged to stderr (`Context payload: X bytes`) is proportional to the task complexity. A simple rename task should not produce a 50KB payload.
- Verify that knowledge entries use hierarchical placement: project-wide entries at the orchestrator root, phase-specific entries near the phase.

---

### Principle II: Evidence Before Claims

#### What It Means

No task is marked complete without fresh verification evidence. "Should work," "tests passed last time," and "I followed the plan" are not evidence. The verification sequence is: run the command, read the output, confirm the result matches expectations, then claim completion.

Verification must be mechanical (checkable without human judgment). Engine-managed scripts must emit structured events (`emit_event`) and a final result (`emit_result`). A script that runs to completion without emitting a `RESULT` line is treated as a silent failure.

#### Codebase Examples

- **`scripts/verify/check-must-haves.sh`** mechanically verifies phase completion by parsing the Must-Haves section of a phase plan. It checks three categories:
  - **Truths**: runs `Check:` commands extracted from backtick-delimited grep patterns.
  - **Artifacts**: verifies file existence, minimum line counts, and content patterns.
  - **Key Links**: confirms cross-references between source and target files.
  Each check produces a `PASS:` or `FAIL:` line. The script exits non-zero if any check fails.

- **`scripts/engine/run.sh`** emits `emit_event` calls at every lifecycle boundary (`SESSION_START`, `PHASE_START`, `TASK_START`, `TASK_COMPLETE`) and a final `emit_result` on exit. These structured events are the observable evidence trail for engine coordination.

- **`scripts/verify/check-must-haves.sh` exit handler** (lines 22-32) ensures a `RESULT` line is always emitted, even on unexpected exit. This prevents silent failures.

#### Common Violations

- Marking a task complete because the implementation "looks right" without running verification commands.
- Writing a phase plan with Must-Haves that require human judgment (e.g., "code is clean" instead of a specific grep pattern).
- Scripts that exit 0 without emitting `emit_result` — these are silent successes that cannot be distinguished from silent failures.
- Skipping the verification tier after implementation ("we already know it works").

#### How to Check Compliance

- Every phase plan must have a `## Must-Haves` section with `### Truths`, `### Artifacts`, and `### Key Links` subsections.
- Run `bash scripts/verify/check-must-haves.sh <phase-dir>` and confirm all lines show `PASS:`.
- Grep engine-managed scripts for `emit_result`: `grep -rn 'emit_result' scripts/`. Every script sourcing `events.sh` should have at least one `emit_result` call (typically in an EXIT trap).

---

### Principle III: Design Before Code

#### What It Means

Every piece of work must go through an explicit design step, no matter how "simple" it seems. The mandatory pipeline is: brainstorm, plan, execute, review. No implementation without an approved design. The design gate is a hard gate — rationalizing that something is "too simple to need a design" is a red flag.

Design artifacts are lightweight and proportional to scope, but they must exist.

#### Codebase Examples

- **The SDD workflow** itself enforces this: `/speckit.specify` (brainstorm/spec), `/speckit.plan` (design), `/speckit.implement` (execute), then verification (review). No task is implemented without a prior `T##-PLAN.md`.

- **Phase plans** (`P##-PLAN.md`) are mandatory before any phase execution begins. The `derive-phase.sh` state machine returns `planning` when a phase lacks a plan, blocking execution until the design exists.

- **Milestone context drafts** (`M###-CONTEXT.md`) capture architectural decisions before roadmap generation for Tier C projects. The `discussing` state gates the transition to `planning`.

#### Common Violations

- Implementing a "quick fix" directly without creating a task plan ("it's just one line").
- Skipping the `/speckit.plan` step because the spec "already describes the implementation."
- Treating the design step as a formality by writing the plan after the implementation.

#### How to Check Compliance

- Every task directory under `phases/P##/tasks/` should contain a `T##-PLAN.md` before a `T##-SUMMARY.md` exists.
- Run `derive-phase.sh` on a milestone directory: if it returns `executing`, every active phase must have a `P##-PLAN.md`.
- Check git history: plan files should be committed before implementation files.

---

### Principle IV: Plans Assume Zero Context

#### What It Means

Implementation plans must be written as if the executing agent has zero codebase context and questionable taste. Document everything: exact file paths, complete code, exact commands with expected output, verification steps with expected results. An agent dropped into the repo cold must be able to execute the plan without reading any file not referenced in the plan.

#### Codebase Examples

- **Task plans** (e.g., `T01-PLAN.md` files throughout `.specify/orchestrator/milestones/`) include exact file paths, literal code blocks, and verification commands with expected output. Every file to be created or modified is listed explicitly.

- **`scripts/dispatch/build-context.sh`** constructs a payload that bundles the task plan with all dependency artifacts, so the executing agent receives everything it needs in a single document. The agent does not need to discover context on its own.

- **Phase plans** include a Must-Haves section with machine-checkable verification commands, removing the need for the executor to "figure out" how to verify their work.

#### Common Violations

- Writing a task plan that says "update the relevant files" without naming them.
- Assuming the executor will read the spec or constitution to understand requirements.
- Omitting verification commands and expecting the executor to "use judgment."
- Referencing a function by name without specifying which file it lives in.

#### How to Check Compliance

- Read any `T##-PLAN.md`: every file to be created or modified should have an explicit path. Code blocks should be complete (not snippets with `...` elisions).
- The plan should include a verification section with commands that can be copy-pasted and run.
- If a plan references a prior task's output, it should specify the path to the summary file, not assume the executor remembers what was built.

---

### Principle V: Fresh Context Per Unit

#### What It Means

Each unit of work (task, phase) must execute in a fresh context that receives only what it needs. The orchestrator constructs a minimal context payload for each dispatch. Subagents must not inherit the orchestrator's session history. They receive: task plan + dependency artifacts + relevant constitution principles. Nothing else.

This prevents context rot and preserves the orchestrator's context budget for coordination work.

#### Codebase Examples

- **`scripts/dispatch/build-context.sh`** assembles a self-contained payload per dispatch. The payload is explicitly constructed from the recipe, not implicitly inherited from a prior session.

- **`scripts/engine/run.sh`** discovers pending tasks (those with a `T##-PLAN.md` but no matching `T##-SUMMARY.md`) and dispatches each one independently. No state carries over from one task dispatch to the next within the engine loop.

- **Task summaries** (`T##-SUMMARY.md`) are the structured handoff between tasks. When a later task depends on an earlier one, it receives the summary, never the raw session.

#### Common Violations

- Dispatching a second task in the same agent session that executed the first task (session accumulates garbage context).
- Including the orchestrator's own session history in a subagent payload.
- Passing raw execution logs between tasks instead of structured summaries.

#### How to Check Compliance

- Verify that `build-context.sh` constructs a new payload for each dispatch call (no caching of prior payloads).
- Check that the engine loop in `run.sh` does not accumulate context between iterations — each task dispatch is independent.
- Confirm that inter-task dependencies are resolved via summary files on disk, not in-memory variables.

---

### Principle VI: State On Disk Is Truth

#### What It Means

No in-memory state across sessions. All state must be recoverable from files on disk. The state machine reads disk state, determines the next action, executes, and persists results back to disk. Crash recovery derives entirely from file state. If it is not on disk, it did not happen.

#### Codebase Examples

- **`scripts/state/derive-phase.sh`** is the canonical implementation. It takes a milestone directory as input and returns one of 10 states by examining which files exist on disk. It checks, in priority order: does the directory exist? Is there a context draft with `status: draft`? Is there a roadmap? Are there task plans without summaries? The state is never stored as a field — it is derived every time.

- **Lock files** (`engine.lock`) detect interrupted work. The engine creates a lock at session start and removes it on clean exit. If a lock exists at startup, a prior session crashed.

- **`scripts/engine/checkpoint.sh`** writes checkpoint state to disk after each completed task, enabling crash recovery to resume from the last good task rather than restarting the phase.

- **Execution logs** (`execution-log.jsonl`) are append-only JSONL files that record every dispatch, verification, and result. They are the forensic record of what happened.

#### Common Violations

- Storing state in environment variables that do not survive session boundaries.
- Relying on a running process to remember which task was last completed.
- Caching derived state in a variable and reusing it after a disk mutation (the cached value may be stale).

#### How to Check Compliance

- Run `derive-phase.sh` on a milestone directory twice in succession: the output must be identical if no files changed between runs.
- After a simulated crash (kill the engine mid-task), run `derive-phase.sh` again: it should return a valid state that enables recovery.
- Verify that no script stores phase/task state in files outside `.specify/orchestrator/`.

---

### Principle VII: Knowledge Compounds

#### What It Means

Every phase of work must produce structured, discoverable documentation. Required outputs: what was built, what patterns were used, what decisions were made, what interfaces were established, what was learned. Knowledge artifacts are mandatory outputs at every level: task summaries, phase summaries, milestone summaries, decision registers, lessons learned.

Good documentation makes future tasks cheaper by reducing context consumption (reinforces Principle I).

#### Codebase Examples

- **`scripts/knowledge/append-knowledge.sh`** appends scoped knowledge entries to `KNOWLEDGE.md` with ISO 8601 timestamps and scope tags (`project`, `milestone:M###`, `phase:M###/P##`). Every entry is discoverable by scope.

- **`scripts/knowledge/consolidate-artifacts.sh`** archives verbose artifacts (task plans, task summaries) while preserving phase summaries, the roadmap, decisions, and knowledge files. This achieves a 60%+ footprint reduction while retaining the compounding knowledge.

- **The three-temperature knowledge storage**: hot (KNOWLEDGE.md index entries), warm (detail files per concept), cold (archived entries). This hierarchy ensures frequently-needed knowledge is immediately accessible while older knowledge remains available without consuming active context.

#### Common Violations

- Completing a phase without writing a `P##-SUMMARY.md`.
- Recording "what was done" without capturing "what was learned" or "what patterns were used."
- Storing knowledge only in git commit messages, where it is not discoverable by scope.
- Duplicating knowledge across multiple files instead of placing it at the appropriate hierarchy level.

#### How to Check Compliance

- Every completed phase directory must contain a `P##-SUMMARY.md`.
- Every completed milestone must have an `M###-SUMMARY.md`.
- Run `grep -c '^\- ' .specify/orchestrator/KNOWLEDGE.md` to confirm knowledge entries are being appended over time.
- Check that `DECISIONS.md` is updated when architectural decisions are made during a phase.

---

### Principle VIII: No Dead Infrastructure

#### What It Means

Every file, script, template, and configuration entry must be reachable from a live code path. Infrastructure that exists "for future use" or "just in case" violates Context Minimization by consuming context budget without delivering value. Removing dead infrastructure is always cheaper than maintaining it.

#### Codebase Examples

- **`extension.yml`** is the manifest of live code paths. Every command and script listed here is reachable. Scripts not listed in `extension.yml` (and not referenced by listed scripts) are candidates for removal.

- **`scripts/diagnostics/check-orphaned.sh`** detects orphaned knowledge artifacts — files that exist in the knowledge hierarchy but are not referenced by any index or cross-link. The doctor suite (`run-doctor.sh`) runs this check and reports orphans as warnings.

- **Template files** in `templates/` are all referenced by at least one command or script. The context recipe (`context-recipe.yaml`), routing config (`routing.yaml`), and hooks config (`hooks.yaml`) are consumed by their respective pipeline stages.

#### Common Violations

- Adding a helper script "for future use" without wiring it into any command or pipeline.
- Keeping a template that was superseded by a newer version but never deleted.
- Adding a reference document that no command or script links to.
- Creating a configuration key in `orchestrator-config.yml` that no script reads.

#### How to Check Compliance

- Run `bash scripts/diagnostics/run-doctor.sh` and check for orphan warnings.
- Cross-reference `extension.yml` script entries with actual files in `scripts/`: every listed script should exist, and every script should be listed (or referenced by a listed script).
- For new files added in a phase, confirm the phase plan's Key Links section shows at least one reference to each new file.

---

### Principle IX: Reproducibility Over Convenience

#### What It Means

Given identical inputs (disk state, configuration, environment), any orchestrator operation must produce identical outputs. Non-determinism is a bug. No inline `date` calls — use `$ORCH_STARTED_AT` or `orch_now()`. No random identifiers without seed control — `ORCH_RUN_ID` is deterministic when seeded. If a script's output varies between runs with identical inputs, it is broken.

#### Codebase Examples

- **`scripts/lib/run-context.sh`** provides `orch_now()`, which returns the frozen timestamp `$ORCH_STARTED_AT` instead of the current wall-clock time. This ensures all timestamps within a run are consistent regardless of execution duration.

- **`ORCH_RUN_SEED`** environment variable seeds `init_run_context` for deterministic `ORCH_RUN_ID` generation. Tests use this to produce reproducible run IDs.

- **`scripts/engine/run.sh`** header comment explicitly cites Principle IX: "deterministic run context and frozen timestamps (orch_now)."

- **`templates/context-recipe.yaml`** drives recipe-driven assembly: the same recipe and source files always produce the same payload.

#### Common Violations

- Calling `date +%Y-%m-%d` inline in a script instead of using `orch_now`.
- Generating random identifiers (UUIDs, nonces) without checking for `ORCH_RUN_SEED`.
- Producing output that depends on file listing order without explicit sorting (filesystem order varies by platform).
- Using `$$` (PID) in file names without documenting the non-determinism.

#### How to Check Compliance

- Grep scripts for bare `date` calls: `grep -rn 'date ' scripts/ | grep -v 'orch_now\|ORCH_STARTED_AT\|#'`. Any matches outside of `run-context.sh` are suspect.
- Run the same script twice with `ORCH_RUN_SEED=test` and diff the outputs. They should be identical.
- Check that `orch_now` is used consistently for timestamp generation in engine-managed scripts.

---

### Principle X: Templating Over Inference

#### What It Means

Configuration and policy must be declared in templates (YAML recipes, routing config, hooks config), not inferred by scripts at runtime. Scripts implement mechanics; templates declare policy. When behavior is controlled by a template, changing it requires editing the template, not the script.

#### Codebase Examples

- **`templates/context-recipe.yaml`** declares which sections to include in a dispatch payload, their priority (`required`, `compressible`, `optional`), ordering, filter strategy, and cache hints. The script `build-context.sh` reads this recipe and assembles the payload mechanically — it does not decide what to include.

- **`templates/routing.yaml`** declares model selection and fallback chains. The `select-model.sh` script reads routing policy from this file rather than hardcoding model preferences.

- **`templates/hooks.yaml`** declares hook lifecycle points and behavior. The `hooks.sh` library reads this file to determine which hooks to run at each lifecycle point.

- The header comment in `context-recipe.yaml` (lines 8-10) explicitly cites Principles X, XI, and XIII.

#### Common Violations

- Hardcoding a compression threshold in a script instead of reading it from the recipe's `compression:` block.
- Inferring the model to use based on task complexity inside a script, instead of declaring it in `routing.yaml`.
- Adding a new hook lifecycle point by modifying `hooks.sh` instead of declaring it in `hooks.yaml`.
- Using conditional logic in a script to determine payload section ordering, rather than reading `order:` from the recipe.

#### How to Check Compliance

- For any new behavior, ask: "Where is this declared?" If the answer is "in a script," it likely violates Principle X.
- Check that `build-context.sh`, `select-model.sh`, and `hooks.sh` read their policy from YAML files, not from hardcoded values.
- When adding a new configurable behavior, verify that a YAML template entry is created before the script logic that reads it.

---

### Principle XI: Single Source of Truth

#### What It Means

Every piece of orchestrator state, configuration, and knowledge must have exactly one authoritative location. Duplication across files is a consistency bug waiting to happen. State is derived by `derive-phase.sh` (not cached in variables). Configuration uses specificity resolution: task > phase > milestone > default. Knowledge uses three-temperature storage with one entry per concept. The roadmap file is the single source for phase status.

#### Codebase Examples

- **`scripts/state/derive-phase.sh`** derives state from disk every time it is called. It never reads a "cached state" file. This ensures state is always consistent with reality.

- **`templates/context-recipe.yaml`** supports specificity overrides (FR-211): a recipe placed in a task directory overrides one in a phase directory, which overrides the default. There is always exactly one effective recipe per dispatch, resolved by specificity.

- **Roadmap files** (`M###-ROADMAP.md`) are the single source for phase status and ordering. Phase directories contain artifacts, but the roadmap determines which phase is active.

- **`orchestrator-config.yml`** uses specificity resolution: task-level config overrides phase-level, which overrides milestone-level, which overrides the default template.

#### Common Violations

- Storing phase status both in the roadmap and in a separate status field in the phase plan.
- Duplicating configuration values in multiple YAML files without a clear override hierarchy.
- Copying a knowledge entry into a task plan instead of referencing the knowledge file.
- Caching the output of `derive-phase.sh` in a variable and reusing it after making changes to disk.

#### How to Check Compliance

- Search for duplicate state: `grep -rn 'status:' .specify/orchestrator/` should show status only in well-defined locations (context drafts, evaluation files), not scattered across arbitrary files.
- Verify that configuration resolution follows the task > phase > milestone > default chain.
- Check that knowledge entries in `KNOWLEDGE.md` are not duplicated verbatim in phase plans or task plans.

---

### Principle XII: Hook Isolation

#### What It Means

Hook scripts operate in a sandbox. They receive a read-only state snapshot and produce stdout/stderr output. They must not modify engine state, write to orchestrator directories, or have side effects on the dispatch pipeline. Snapshots are `chmod 444` temp files deleted after hook execution. Hooks that violate isolation trigger a `HOOK_VIOLATION` event that is never downgraded, even under `--force`.

#### Codebase Examples

- **`scripts/lib/hooks.sh`** implements the sandbox. The `_hooks_snapshot_create()` function copies state to a temp file and sets `chmod 444`. After hook execution, `_hooks_snapshot_unchanged()` compares the snapshot's modification time. If it changed, a `HOOK_VIOLATION` event is emitted unconditionally.

- **Timeout enforcement** (line 36): `ORCH_HOOK_TIMEOUT_SEC` defaults to 30 seconds. Hooks exceeding the timeout are killed and recorded as failures.

- **`HOOK_VIOLATION` events** are the only event class that cannot be overridden by `ORCH_FORCE`. This is explicitly documented in the hooks.sh header: "Hook tampering detection (HOOK_VIOLATION) is NEVER overridable."

#### Common Violations

- A hook script writing directly to `.specify/orchestrator/` instead of producing output on stdout.
- A hook modifying the snapshot file (detected mechanically by mtime comparison).
- A hook running longer than the timeout without being designed for async execution.
- A hook reading engine state directly from disk instead of from the provided snapshot.

#### How to Check Compliance

- Review any hook script for write operations: `grep -n 'echo.*>>\|printf.*>>\|tee\|cp.*\.specify' hooks/`. Any writes to orchestrator paths are violations.
- Run a hook with `ORCH_HOOK_TIMEOUT_SEC=5` and verify it completes within the window.
- Check `hooks.sh` for the `HOOK_VIOLATION` event emission path — it must not be conditional on `ORCH_FORCE`.

---

### Principle XIII: Agent Instruction Schema

#### What It Means

Dispatch instructions (the payload assembled for executing agents) must follow a declared, inspectable schema. Ad-hoc instruction assembly produces inconsistent agent behavior and prevents variance analysis. The instruction schema declares required sections, optional sections, and section ordering. Context recipes (`context-recipe.yaml`) are the mechanism for schema declaration.

New instruction formats require a recipe change, not a script change. This enables systematic analysis of what context agents receive and how it correlates with task outcomes.

#### Codebase Examples

- **`templates/context-recipe.yaml`** is the schema declaration. Each `sections:` entry specifies `source`, `priority`, `order`, `filter`, and `cache_hint`. This is a complete, inspectable declaration of what the dispatch payload contains.

- **`scripts/dispatch/build-context.sh`** reads the recipe and dispatches each section to a handler in `scripts/dispatch/lib/section-handlers.sh`. The script does not decide what sections to include — the recipe does.

- **`scripts/lib/manifest-builder.sh`** generates a manifest table at the top of each payload, listing every section included with its byte count. This makes the payload inspectable after assembly.

- The recipe's comment header explicitly cites Principle XIII alongside Principles X and XI.

#### Common Violations

- Adding a new payload section by modifying `build-context.sh` instead of adding a recipe entry.
- Constructing dispatch payloads ad-hoc in a command file without going through the recipe-driven pipeline.
- Changing section ordering in a script instead of updating the `order:` value in the recipe.
- Omitting the manifest header from assembled payloads (prevents inspection).

#### How to Check Compliance

- All dispatch payloads should begin with a manifest table listing included sections and byte counts.
- New sections require a corresponding entry in `context-recipe.yaml` — check `git diff` for recipe changes when payload content changes.
- Run `bash scripts/diagnostics/check-recipe.sh` to validate recipe structure and section handler coverage.

---

## Cross-References

- [Constitution source](../.specify/memory/constitution.md) — the authoritative v2.0 text
- [State machine reference](state-machine.md) — detailed state derivation rules (Principle VI)
- [Architecture reference](architecture.md) — engine pipeline and subsystem relationships
- [Verification ladder](verification-ladder.md) — 4-tier verification framework (Principle II)
- [Recipes reference](recipes.md) — context recipe format and override resolution (Principles X, XIII)
- [Hooks reference](hooks.md) — hook lifecycle and isolation mechanics (Principle XII)
- [Events reference](events.md) — structured event emission contract (Principle II, amended)
- [Routing reference](routing.md) — model selection and fallback chains (Principle X)
- [File formats reference](file-formats.md) — canonical file schemas across the orchestrator
- [Tier definitions](tier-definitions.md) — scope classification that determines workflow gates (Principle III)
- [Contributor Guide](../scripts/AGENTS.md) — coding conventions and compliance checklist derived from these principles
- [Anti-Patterns](../ANTIPATTERNS.md) — registered anti-patterns with constitutional principle references
