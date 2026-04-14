---
schema_version: "1.0"
type: roadmap
milestone: "M004"
feature_ref: "004-engine-architecture"
feature_spec: "specs/004-engine-architecture/spec.md"
vision: "Replace implicit agent-driven coordination with a mechanical engine layer that threads run context, emits structured events, enforces safety rails, and executes hooks — all driven by declarative YAML recipes — establishing the integration seam for Conversus deliberation gates."
tier: "C"
created_at: "2026-04-10T22:00:00Z"
updated_at: "2026-04-10T22:00:00Z"
---

## Phases

- [x] **P01**: Constitution v2.0 and Antipattern Register — "The constitution contains 13 principles (7 original + 6 new), an amended Principle II requiring structured events, and an ANTIPATTERNS.md exists at the root with at least 2 entries referencing real observed incidents from M001-M003."
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces:
      - `.specify/memory/constitution.md` — updated to v2.0.0 with principles VIII-XIII and amended Principle II
      - `ANTIPATTERNS.md` — append-only antipattern register at orchestrator root
      - Sync Impact Report in constitution HTML comment
    - Consumes: nothing (governance phase, no code dependencies)

- [x] **P02**: Shared Libraries — "A developer can `source lib/errors.sh` to get `emit_result` with typed error kinds, `source lib/events.sh` to get `emit_event` with structured output, and `source lib/run-context.sh` to initialize a deterministic run context with run_id and timestamps — all Bash 3.2 compatible with double-sourcing guards."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `scripts/lib/errors.sh` — error taxonomy (CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO), `emit_result` function, double-sourcing guard
      - `scripts/lib/events.sh` — `emit_event` function producing `EVENT:{type} timestamp=... key=value` lines, event type registry, double-sourcing guard
      - `scripts/lib/run-context.sh` — `init_run_context` function setting ORCH_RUN_ID, ORCH_STARTED_AT, ORCH_FORCE, ORCH_DRY_RUN, double-sourcing guard
      - `scripts/lib/guards.sh` — safety rail functions: `guard_payload_sanity`, `guard_budget`, `guard_output_sanity`, `guard_phase_complete`, double-sourcing guard
      - `scripts/lib/hooks.sh` — `run_hooks` function: reads hooks.yaml, creates frozen snapshot, executes hook scripts with timeout, handles block/warn behavior, double-sourcing guard
    - Consumes:
      - `.specify/memory/constitution.md` (from P01) — new libraries must comply with constitution v2.0

- [x] **P03**: Engine Core — "Running `bash scripts/engine/run.sh M001 P02` dispatches all pending tasks in phase P02 sequentially, emitting SESSION_START/TASK_START/TASK_COMPLETE/PHASE_COMPLETE events, checkpointing after each task, and blocking on safety rail or hook failures."
  - Risk: high
  - Depends: P02
  - Boundary Map:
    - Produces:
      - `scripts/engine/run.sh` — pipeline coordinator (~200-300 lines) with task loop, run context init, event emission, hook dispatch, safety rails, checkpointing, --dry-run support
      - `scripts/engine/checkpoint.sh` — checkpoint write/read/detect for crash recovery
      - Checkpoint file format at `.specify/orchestrator/{milestone}/engine-checkpoint.json`
    - Consumes:
      - `scripts/lib/errors.sh` (from P02)
      - `scripts/lib/events.sh` (from P02)
      - `scripts/lib/run-context.sh` (from P02)
      - `scripts/lib/guards.sh` (from P02)
      - `scripts/lib/hooks.sh` (from P02)
      - Existing scripts: `scripts/dispatch/build-context.sh`, `scripts/dispatch/compress-payload.sh`, `scripts/dispatch/select-model.sh`, `scripts/verify/check-must-haves.sh`, `scripts/lifecycle/record-result.sh`

- [x] **P04**: YAML Recipe Schema and Default Recipe — "A default `templates/context-recipe.yaml` declares 7 sections (state, knowledge, decisions, upstream, scope, task_plan, constraints) with source type, priority, order, and filter config; `templates/hooks.yaml` declares 4 lifecycle hook points; routing.yaml is extended with fallback chains — all parseable by grep/sed/awk without jq."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `templates/context-recipe.yaml` — default context recipe with section declarations, compression config, manifest config
      - `templates/hooks.yaml` — default hook configuration with 4 lifecycle points and built-in guard hooks
      - `scripts/lib/recipe-parser.sh` — YAML recipe reader functions: `parse_recipe_sections`, `parse_recipe_compression`, `read_recipe_field`, double-sourcing guard
      - Extended `templates/routing.yaml` — adds `fallback` arrays per tier, `classification` rules block
      - Recipe schema documentation in spec
    - Consumes:
      - `.specify/memory/constitution.md` (from P01) — recipe design must comply with Principle X (Templating Over Inference) and Principle IX (Reproducibility)

- [x] **P05**: Recipe-Driven Script Refactor — "build-context.sh reads context-recipe.yaml to determine which sections to assemble and in what order; compress-payload.sh reads the compression block to determine graduated steps; select-model.sh reads fallback chains from routing.yaml — all three scripts produce identical output to their pre-refactor versions when given the default recipe."
  - Risk: high
  - Depends: P02, P03, P04
  - Boundary Map:
    - Produces:
      - Refactored `scripts/dispatch/build-context.sh` — recipe interpreter (~150 lines) with per-source-type handler functions
      - Refactored `scripts/dispatch/compress-payload.sh` — reads compression config from recipe
      - Refactored `scripts/dispatch/select-model.sh` — reads fallback chains from routing.yaml, implements retry-on-fallback
      - `scripts/dispatch/lib/section-handlers.sh` — handler functions for each section source type (computed, index, file, phase_summaries, phase_plan, template), double-sourcing guard
    - Consumes:
      - `templates/context-recipe.yaml` (from P04)
      - `scripts/lib/recipe-parser.sh` (from P04)
      - `scripts/lib/errors.sh` (from P02) — emit_result on completion
      - `scripts/lib/events.sh` (from P02) — emit_event for section assembly progress
      - `scripts/lib/run-context.sh` (from P02) — deterministic timestamps
      - Extended `templates/routing.yaml` (from P04) — fallback chains
      - Existing knowledge scripts: scope-filter.sh, traverse-graph.sh, resolve-entries.sh, increment-hits.sh

- [x] **P06**: Existing Script Integration — "All 8 engine-path scripts (build-context, compress-payload, select-model, check-must-haves, record-result, record-telemetry, aggregate-metrics, phase-transition) source lib/errors.sh and lib/events.sh, emit at least one event, and emit a RESULT line — while continuing to work standalone when ORCH_RUN_ID is unset."
  - Risk: medium
  - Depends: P02
  - Boundary Map:
    - Produces:
      - Updated `scripts/verify/check-must-haves.sh` — sources lib/errors.sh and lib/events.sh, emits events and result
      - Updated `scripts/lifecycle/record-result.sh` — sources libs, adds run_id and error_kind to JSONL entries
      - Updated `scripts/telemetry/record-telemetry.sh` — sources libs, emits events
      - Updated `scripts/telemetry/aggregate-metrics.sh` — sources libs, groups by error_kind, emits result
      - Updated `scripts/state/phase-transition.sh` — sources libs, emits events for state transitions
      - Updated `scripts/dispatch/classify-complexity.sh` — sources libs, emits result
      - Standalone detection pattern: `if [ -n "${ORCH_RUN_ID:-}" ]; then ... fi`
    - Consumes:
      - `scripts/lib/errors.sh` (from P02)
      - `scripts/lib/events.sh` (from P02)

- [x] **P07**: Conformance and Diagnostics Extension — "run-doctor.sh includes 3 new checks: recipe conformance (all recipe sections have valid source types), event conformance (all engine-path scripts emit at least one EVENT line), and constitution v2.0 compliance (new principles referenced in plans) — results appended to doctor-history.jsonl."
  - Risk: low
  - Depends: P02, P03, P04, P05, P06
  - Boundary Map:
    - Produces:
      - `scripts/diagnostics/check-recipe.sh` — validates context-recipe.yaml structure (sections have required fields, source types are known, priorities are valid)
      - `scripts/diagnostics/check-events.sh` — verifies engine-path scripts contain emit_event calls (static analysis via grep)
      - `scripts/diagnostics/check-constitution.sh` — verifies constitution v2.0 principles are referenced in phase plans
      - Updated `scripts/diagnostics/run-doctor.sh` — runs new checks alongside existing ones
      - Updated `extension.yml` — registers new scripts
    - Consumes:
      - `templates/context-recipe.yaml` (from P04)
      - `templates/hooks.yaml` (from P04)
      - `scripts/lib/errors.sh` (from P02) — new diagnostics emit structured results
      - All updated scripts (from P05, P06) — for event conformance checking

## Cross-Cutting Concerns

- **Bash 3.2 compatibility (NFR-200)** — P02, P03, P04, P05, P06, P07. P02 establishes the pattern in shared libraries. All subsequent phases conform. No associative arrays, no readarray, no mapfile, no process substitution as redirection target.

- **Double-sourcing guards (NFR-203)** — P02, P04, P05. Every new library file includes `[ -n "${_LIBNAME_SOURCED:-}" ] && return 0` guard. Pattern established in M002 knowledge libraries.

- **Standalone compatibility (NFR-204)** — P05, P06. Scripts detect engine-managed mode via `ORCH_RUN_ID` environment variable. When unset, scripts use inline timestamps and plain stdout. When set, scripts use run context and emit structured events.

- **YAML parsing without jq (NFR-202)** — P04, P05. Recipe schema constrained to 2 levels of nesting max. Array values use comma-separated inline format or repeated keys. No arbitrary nesting or complex structures.

- **Atomic writes (inherited from M002)** — P03. Checkpoint files use temp-file-then-mv pattern.

- **Error logging conventions** — P02, P03, P04, P05, P06, P07. P02 establishes the `emit_result` and `emit_event` conventions. All subsequent phases follow.

## Dependency Graph

```
P01 ──→ P02 ──→ P03
 │        │       │
 │        │       └──────────────────┐
 │        │                          │
 │        ├──→ P06                   │
 │        │                          │
 └──→ P04 ──────────────────────→ P05
                                     │
P06 ─────────────────────────────→ P07
P05 ─────────────────────────────→ P07
```

Expanded view:

```
P01 (Constitution v2.0)
 │
 ├──→ P02 (Shared Libraries)
 │     │
 │     ├──→ P03 (Engine Core)
 │     │     │
 │     │     └───────────────────┐
 │     │                         │
 │     └──→ P06 (Script Integration)
 │           │                   │
 └──→ P04 (YAML Recipes)        │
       │                         ▼
       └─────────────────→ P05 (Recipe-Driven Refactor)
                                 │
                                 ▼
                           P07 (Conformance & Diagnostics)
```

Three tracks converge:
- Track A: P01 → P02 → P03 (engine foundation)
- Track B: P01 → P04 (recipe design, parallel to Track A after P01)
- Track C: P02 → P06 (script integration, parallel to P03 and P04)
- Convergence: P05 requires P02 + P03 + P04; P07 requires P02 + P03 + P04 + P05 + P06

## Execution Order

1. **P01** (Constitution v2.0) — no dependencies. Low risk. Must complete first because all subsequent phases must comply with v2.0 principles.
2. **P02** (Shared Libraries) and **P04** (YAML Recipes) — can execute concurrently after P01. P02 depends on P01 (libraries must comply). P04 depends on P01 (recipe design must comply with Principle X, XI). Medium risk for P02, high risk for P04 (YAML parsing in Bash 3.2).
3. **P03** (Engine Core) and **P06** (Script Integration) — can execute concurrently. P03 depends on P02 (sources all libraries). P06 depends on P02 (sources errors and events libs). High risk for P03, medium risk for P06.
4. **P05** (Recipe-Driven Refactor) — depends on P02, P03, P04. High risk (complete refactor of 3 core dispatch scripts). Executes after P03 and P04 both complete.
5. **P07** (Conformance & Diagnostics) — depends on all prior phases. Low risk (read-only analysis). Executes last.

## Validation

- **No conflicting producers**: PASS — Each phase produces distinct files. P02 produces lib/*.sh. P03 produces engine/*.sh. P04 produces templates/*.yaml and lib/recipe-parser.sh. P05 refactors dispatch/*.sh. P06 updates non-dispatch scripts. P07 produces diagnostics/*.sh. No overlapping producers.

- **All consumed items have producers**: PASS — P02 consumes constitution (P01). P03 consumes all P02 libraries. P04 consumes constitution (P01). P05 consumes P02 libraries + P04 recipes + existing scripts. P06 consumes P02 libraries. P07 consumes outputs from all prior phases. All dependencies satisfied.

- **DAG is acyclic**: PASS — Topological sort yields: {P01} → {P02, P04} → {P03, P06} → {P05} → {P07}. No back-edges or cycles.

- **Demo sentence coverage**: PASS — All 7 phases have concrete, testable demo sentences. P01: constitution version + antipattern file. P02: source libraries and use functions. P03: run engine command with events. P04: YAML files exist and are parseable. P05: refactored scripts produce identical output. P06: updated scripts emit events while working standalone. P07: doctor runs new checks.
