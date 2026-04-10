# Spec 004: Engine Architecture

## Summary

Replace the implicit coordination model (agent reads command docs, calls scripts ad-hoc) with an explicit engine layer that mechanically coordinates the dispatch pipeline, threads run context, emits structured events, enforces safety rails, and executes hooks at lifecycle points. Evolve the constitution to codify patterns learned from Conversus and index-pipeline. Drive context assembly, compression, and model routing from declarative YAML recipes instead of hardcoded script logic.

## Motivation

The orchestrator has 50+ scripts that work well individually but lack a coordination layer. Cross-cutting concerns (run correlation, event emission, budget enforcement, safety rails, hook dispatch) cannot be reliably handled by an agent reading markdown instructions. As we prepare for Conversus integration as an optional deliberation gate, the orchestrator needs mechanical hook points where external systems can observe and gate the pipeline. The current scripts mix policy (what sections to include, compression thresholds, model tiers) with mechanics (how to read files, parse frontmatter, write output), making configuration changes require code changes.

### Origin

Analysis of two sibling codebases (Conversus deliberation engine, index-pipeline content processing library) identified patterns that the orchestrator should adopt:

**From Conversus**: Structured event emission protocol, typed error taxonomy, plugin lifecycle hooks with dependency ordering, frozen state snapshots for hook consumers, cost transparency (unknown vs zero), gate verdict schema.

**From index-pipeline**: Result objects with typed errors, staleness/safety protection at state transitions, deterministic RunContext threading, content-hash-based idempotency, conformance test kit pattern, pure transform / effectful orchestration split, graduated fallback chains.

## User Stories

### US1: Engine Coordination

As a developer using the orchestrator, I want task dispatch to be mechanically coordinated by an engine so that safety rails, event emission, and hook dispatch happen every time — not only when the agent remembers.

**Acceptance Scenarios**:
- AS1: Running a phase dispatch through the engine emits `SESSION_START`, `TASK_START`, `TASK_COMPLETE`, `PHASE_COMPLETE` events to stdout in parseable format
- AS2: If a safety rail fails (empty payload, budget exceeded), the engine blocks dispatch and emits a `GUARD_BLOCKED` event with the guard name and reason
- AS3: Crash recovery: if the engine is interrupted mid-task, re-running it detects the checkpoint and resumes from the interrupted task
- AS4: All JSONL entries from a single engine run share the same `run_id`
- AS5: Running with `--dry-run` executes the full pipeline except actual agent dispatch, emitting events for what would happen

### US2: YAML-Driven Context Assembly

As a developer, I want context assembly driven by a YAML recipe so that I can customize what goes into dispatch payloads without modifying scripts.

**Acceptance Scenarios**:
- AS1: A default `templates/context-recipe.yaml` defines sections (state, knowledge, decisions, upstream, scope, task_plan, constraints) with source, priority, order, and filter configuration
- AS2: Placing a `context-recipe.yaml` in a milestone or phase directory overrides the default — most-specific wins
- AS3: Adding a new section to the recipe causes it to appear in the next dispatch payload without any script changes
- AS4: Removing a section from the recipe removes it from the payload
- AS5: Sections marked `priority: required` are never dropped by compression; sections marked `priority: compressible` are dropped under budget pressure

### US3: YAML-Driven Compression

As a developer, I want compression behavior driven by the recipe so that compression strategy is inspectable and configurable.

**Acceptance Scenarios**:
- AS1: The `compression:` block in the recipe defines graduated steps (drop optional, summarize, drop lowest-confidence)
- AS2: Changing `compression.steps` in the recipe changes compression behavior without modifying `compress-payload.sh`
- AS3: The token budget is derived from the model selection (via routing.yaml) and passed to compression automatically

### US4: Structured Events and Results

As a developer, I want every script to emit structured events and results so that I can build monitoring, dashboards, and Conversus integration on a reliable stream.

**Acceptance Scenarios**:
- AS1: Every engine-managed script emits at least one event via `emit_event`
- AS2: Every script emits a final `RESULT:{json}` line with `status`, `error_kind` (if failure), and `detail`
- AS3: Events follow a closed schema: type, timestamp, and type-specific key-value pairs
- AS4: A consumer can parse all events from a dispatch session by grepping for `^EVENT:` lines

### US5: Hook Lifecycle System

As a developer, I want hooks at pipeline lifecycle points so that Conversus and other tools can gate or observe dispatch without modifying engine code.

**Acceptance Scenarios**:
- AS1: Hooks are configured in `templates/hooks.yaml` with name, script path, enabled flag, and block_on_fail flag
- AS2: The engine executes hooks at 4 lifecycle points: PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE
- AS3: Hooks receive a frozen state snapshot (read-only temp file) — they cannot modify engine state
- AS4: Hooks block by default; a hook returning non-zero exit stops the pipeline with a `HOOK_BLOCKED` event
- AS5: A hook with `block_on_fail: false` emits a warning on failure but does not stop the pipeline
- AS6: Disabling a hook in hooks.yaml prevents it from running without removing the script

### US6: Safety Rails

As a developer, I want the engine to enforce safety checks at every dispatch so that garbage-in-garbage-out cascades are prevented.

**Acceptance Scenarios**:
- AS1: Pre-dispatch: if assembled payload is empty or < 100 chars, dispatch is blocked
- AS2: Pre-dispatch: if knowledge scope filter matches 0 entries but the index has 50+, a warning is emitted (scope may be too narrow)
- AS3: Post-dispatch: if agent output is empty or < 100 chars, result is recorded as `outcome: blocked` not `outcome: success`
- AS4: Phase advance: if SUMMARY.md exists but has no content sections, advance is blocked
- AS5: Budget: if cumulative cost exceeds `dispatch_budget` or `duration_budget`, dispatch is blocked (when `budget_enforcement: enforced`)
- AS6: All safety checks are overridable with `--force` for recovery scenarios

### US7: Constitution Evolution

As a project maintainer, I want the constitution updated with principles learned from Conversus and index-pipeline analysis so that the architectural decisions are codified and enforceable.

**Acceptance Scenarios**:
- AS1: Constitution v2.0 includes 5 new principles: No Dead Infrastructure, Reproducibility Over Inconsistency, Single Source of Truth, Templating Over Inference, Hook Isolation
- AS2: Principle II (Evidence Before Claims) is amended to require structured event emission
- AS3: A new "Agent Instruction Schema" principle requires dispatch instructions to follow a declared structure
- AS4: An `ANTIPATTERNS.md` file exists at the orchestrator root with at least 2 observed patterns
- AS5: The constitution version is bumped to 2.0.0 with a Sync Impact Report

### US8: Error Taxonomy and Result Protocol

As a developer, I want a closed set of error categories shared across all scripts so that downstream consumers can dispatch on error type rather than parsing strings.

**Acceptance Scenarios**:
- AS1: `lib/errors.sh` defines error categories: CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO
- AS2: All engine-managed scripts source `lib/errors.sh` and use `emit_result` for their final status
- AS3: `record-result.sh` records the error_kind in execution-log.jsonl entries
- AS4: `aggregate-metrics.sh` can group failures by error_kind

### US9: Deterministic RunContext

As a developer, I want every dispatch session to have a unique run ID and deterministic timestamps so that I can correlate events and reproduce payload assembly.

**Acceptance Scenarios**:
- AS1: `lib/run-context.sh` initializes `ORCH_RUN_ID`, `ORCH_STARTED_AT`, `ORCH_FORCE`, `ORCH_DRY_RUN` as exported environment variables
- AS2: All JSONL entries within a session include the `run_id` field
- AS3: No script calls `date` inline — all use `$ORCH_STARTED_AT` or request a timestamp from the run context
- AS4: Re-initializing run context with the same seed produces the same `ORCH_STARTED_AT`

### US10: Model Routing with Fallback Chains

As a developer, I want model routing to support fallback chains so that a rate-limited or failed model falls back to the next tier automatically.

**Acceptance Scenarios**:
- AS1: `routing.yaml` supports `fallback: [model1, model2]` per tier
- AS2: When primary model dispatch fails with a recoverable error (rate_limit, timeout), the engine retries with the next model in the fallback chain
- AS3: The execution log records which model was actually used (may differ from primary selection)
- AS4: If all models in the chain fail, the task is recorded as failed with error_kind DISPATCH

## Functional Requirements

### Engine Core
- FR-200: The engine (`scripts/engine/run.sh`) coordinates the dispatch pipeline: context build, compress, model select, safety check, dispatch, verify, record, advance
- FR-201: The engine initializes run context at session start and threads it through all script invocations via environment variables
- FR-202: The engine emits structured events at lifecycle points (session, task, phase boundaries)
- FR-203: The engine checkpoints after each task completion for crash recovery
- FR-204: The engine supports `--dry-run` mode that executes everything except actual agent dispatch

### YAML Recipes
- FR-210: Context assembly is driven by `templates/context-recipe.yaml` with per-section source, priority, order, and filter configuration
- FR-211: Recipe resolution follows specificity: task-level > phase-level > milestone-level > default
- FR-212: Compression strategy is declared in the recipe's `compression:` block
- FR-213: Routing configuration in `routing.yaml` supports fallback chains per tier
- FR-214: Hook configuration in `templates/hooks.yaml` declares scripts, lifecycle points, enabled flags, and block behavior

### Shared Libraries
- FR-220: `lib/errors.sh` defines a closed error taxonomy (CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO) and `emit_result` function
- FR-221: `lib/events.sh` defines `emit_event` function producing parseable `EVENT:{type}` lines with timestamp and key-value pairs
- FR-222: `lib/run-context.sh` initializes and exports deterministic run context variables
- FR-223: `lib/hooks.sh` discovers and executes hook scripts at lifecycle points, passing frozen state snapshots
- FR-224: `lib/guards.sh` implements safety rail checks (payload sanity, budget enforcement, output sanity, phase completeness)

### Constitution
- FR-230: Constitution v2.0 adds principles VIII-XII (No Dead Infrastructure, Reproducibility, Single Source of Truth, Templating Over Inference, Hook Isolation)
- FR-231: Principle II amended to require structured event emission from all engine-managed scripts
- FR-232: New Principle XIII: Agent Instruction Schema — dispatch instructions follow a declared structure for consistency and variance analysis
- FR-233: `ANTIPATTERNS.md` at orchestrator root with append-only entries referencing real observed incidents

## Non-Functional Requirements

- NFR-200: All new scripts Bash 3.2 compatible (no associative arrays, no readarray, no mapfile)
- NFR-201: Engine overhead < 500ms per task (excluding actual agent dispatch time)
- NFR-202: YAML recipe parsing uses grep/sed/awk (no jq hard dependency)
- NFR-203: All new libraries sourced with double-sourcing guards
- NFR-204: All existing scripts continue to work standalone (engine is additive, not required)
- NFR-205: Hook execution timeout: 30s per hook (configurable)

## Edge Cases

1. **Empty recipe**: If context-recipe.yaml has no sections, engine emits warning and assembles minimal payload (state section only)
2. **Missing hook script**: If hooks.yaml references a script that doesn't exist, engine emits warning and skips (not a fatal error)
3. **All fallback models fail**: Task recorded as failed with error_kind DISPATCH; engine continues to next task
4. **Hook modifies state snapshot**: Snapshot is chmod 444; if hook force-writes, engine detects modification and emits HOOK_VIOLATION event
5. **Recipe section source not found**: If a section references a file that doesn't exist, section is skipped with warning (not fatal unless priority: required)
6. **Concurrent engine runs**: Lock file prevents concurrent runs on same milestone; second invocation detects lock and exits with error_kind STATE
7. **Budget exceeded mid-phase**: Engine completes current task recording, then blocks before next task dispatch
