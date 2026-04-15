---
schema_version: "1.0"
type: context-draft
milestone: "M004"
status: finalized
created_at: "2026-04-10T22:00:00Z"
finalized_at: "2026-04-10T22:00:00Z"
---

## Architectural Decisions

### AD-1: Engine is a Bash coordinator, not a framework

The engine (`scripts/engine/run.sh`) is a single Bash script (~200-300 lines) that coordinates the dispatch pipeline. It is NOT a Python async framework, a process manager, or a daemon. It calls existing scripts in sequence, threads run context via environment variables, emits events to stdout, and executes hooks between stages. The coordination problem is reliable sequencing with cross-cutting concerns, not concurrent fan-out.

### AD-2: YAML recipes declare policy; scripts implement mechanics

Context recipes (`templates/context-recipe.yaml`) declare WHAT goes into a dispatch payload — which sections, in what order, from what source, with what priority. Scripts implement HOW to read, parse, filter, and assemble each section type. This separation means configuration changes (add a section, change compression threshold, reorder sections) don't require code changes.

### AD-3: Shared libraries sourced, not executed

`lib/errors.sh`, `lib/events.sh`, `lib/run-context.sh`, `lib/hooks.sh`, `lib/guards.sh` are sourced (`. lib/errors.sh`), not executed as subprocesses. This lets them set environment variables and define functions that persist across the script's lifetime. All libraries use double-sourcing guards.

### AD-4: Events are stdout lines, not a bus

Events are `EVENT:{type} timestamp=... key=value ...` lines on stdout. There is no event bus, no pub/sub, no queue. Consumers parse stdout. This is consistent with the orchestrator's file-based architecture and avoids runtime dependencies. The existing JSONL log remains the durable store; events are the real-time stream.

### AD-5: Hooks block by default

Unlike Conversus (where plugins are advisory by design), orchestrator hooks are safety gates. A budget check that doesn't block is just a log line. Default is `block_on_fail: true`. Informational hooks (telemetry recording) explicitly set `block_on_fail: false`. This inverts the Conversus default because the orchestrator's hooks serve a fundamentally different purpose.

### AD-6: Frozen state snapshots via temp files

Hook scripts receive a read-only temp file containing the current state snapshot. The file is `chmod 444` before hook execution and deleted after. Hooks cannot modify engine state — they can only read the snapshot and emit their own stdout/stderr. This mirrors Conversus's frozen Pydantic models but implemented in Bash via filesystem permissions.

### AD-7: Recipe resolution follows specificity

Recipe files are resolved: task > phase > milestone > default. The most-specific recipe wins entirely (no merging). This is the same pattern as orchestrator-config.yml resolution. Merging recipes across levels would create hard-to-debug interactions; override-in-full is simpler and predictable (Conversus Principle VII: Reproducibility).

### AD-8: Error taxonomy is a closed set

Six error categories: CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO. This is intentionally smaller than Conversus's 8-category taxonomy because the orchestrator has fewer error sources (no auth, no rate limiting from APIs, no network errors — those are the agent's problem). The set is closed — adding a category requires a constitution-level discussion.

### AD-9: Agent instruction schema is aspirational with progressive migration

The constitution principle requires a declared schema for agent instructions. Day 1: define the schema, new instructions conform, existing instructions are noted for migration. Migration is progressive — instructions are updated as phases are touched, not in a big-bang rewrite. The goal is structural consistency so variance can be analyzed, not perfection on day 1.

### AD-10: Constitution v2.0 is a MAJOR version bump

Adding 6 new principles (VIII-XIII), amending 1 existing principle (II), and adding an antipattern register constitutes a material architectural shift. This is a MAJOR version bump (1.0.0 → 2.0.0), not a MINOR, because the new principles change what constitutes a compliant implementation.

### AD-11: Antipatterns are permanent, knowledge decays

Antipattern entries in `ANTIPATTERNS.md` do not have staleness decay, confidence scores, or lifecycle management. They are permanent warnings with real incident references. This contrasts with knowledge entries (which decay via staleness). The distinction: knowledge is contextual and may become outdated; antipatterns are structural failures that recur regardless of context.

### AD-12: Existing scripts work standalone (NFR-204)

All existing scripts must continue to work when called directly (not through the engine). The engine is additive. Scripts detect whether they're engine-managed by checking for `ORCH_RUN_ID` in the environment. When engine-managed, they use run context and emit structured events. When standalone, they use inline timestamps and plain stdout. This enables incremental adoption and backward compatibility.

## Scope Boundaries

### In Scope

- Engine coordinator script (`scripts/engine/run.sh`) with task loop, hook dispatch, safety rails, checkpointing
- 5 shared libraries: errors, events, run-context, hooks, guards
- Context recipe YAML schema and default recipe
- Recipe-driven refactor of build-context.sh (recipe interpreter)
- Recipe-driven refactor of compress-payload.sh (reads compression config)
- Routing.yaml extension with fallback chains
- Hooks.yaml configuration format
- Constitution v2.0 (6 new principles, 1 amendment, antipattern register)
- ANTIPATTERNS.md with initial entries
- Conformance checks extending run-doctor.sh

### Out of Scope

- Conversus integration (hooks provide the seam; actual Conversus gate is a future milestone)
- Dashboard or UI for event consumption
- Distributed tracing or OpenTelemetry integration
- Agent instruction schema enforcement tooling (principle is added; tooling is future)
- Rewriting all existing scripts to be recipe-driven (only build-context.sh and compress-payload.sh are refactored; others are touched only for lib sourcing)
- Multi-agent dispatch (engine dispatches one task at a time sequentially)

## Design Constraints

### Technical Constraints

- Bash 3.2 compatibility for all new code (NFR-200)
- YAML parsing without jq (NFR-202) — recipe schema must be parseable with grep/sed/awk
- Engine overhead < 500ms per task excluding agent dispatch (NFR-201)
- All libraries with double-sourcing guards (NFR-203)
- Hook execution timeout 30s per hook (NFR-205)

### Compatibility Constraints

- Existing scripts work standalone without engine (NFR-204)
- Existing execution-log.jsonl schema remains valid (new fields are additive)
- Existing orchestrator-config.yml remains valid
- Existing routing.yaml remains valid (fallback chains are additive)
- Extension.yml registration is additive

### Process Constraints

- Constitution must be updated before new code is written (new code must comply with v2.0)
- Shared libraries must exist before engine can be built
- Recipe schema must be designed before scripts can be refactored
- Each phase independently dispatchable with zero-context task plans

## Open Questions

### Resolved During Analysis

1. **Engine technology?** — Resolved: Bash script, not Python. Consistent with stack.
2. **Hook default behavior?** — Resolved: Block by default. Orchestrator hooks are safety gates.
3. **Recipe merging vs override?** — Resolved: Override-in-full. No merging across levels.
4. **Constitution version?** — Resolved: 2.0.0 MAJOR bump.
5. **Error category count?** — Resolved: 6 categories (CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO).
6. **Agent instruction schema enforcement?** — Resolved: Aspirational principle with progressive migration.
7. **Antipattern lifecycle?** — Resolved: Permanent, no decay. Separate from knowledge entries.
8. **Existing script compatibility?** — Resolved: Standalone mode via ORCH_RUN_ID detection.

### Remaining Open Questions

- **Recipe YAML parsing depth**: How deeply nested can recipe YAML be while remaining parseable with grep/sed/awk? May need to constrain schema to 2 levels of nesting max. To be resolved during P02 design.
- **Hook script discovery**: Should hooks be discovered from a directory (`hooks/{point}/*.sh`) or only from hooks.yaml? Directory discovery is simpler but less controllable. hooks.yaml is explicit but requires maintenance. Likely hooks.yaml-only for control. To be confirmed during P04 design.
- **Checkpoint format**: Should checkpoints be a single JSON file updated after each task, or a directory of per-task checkpoint files? Single file is simpler; per-task is more crash-resilient. To be resolved during P03 design.
