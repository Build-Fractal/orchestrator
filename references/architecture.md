# Architecture Reference

> Progressive disclosure reference for the speckit-orchestrator architecture.
> Self-contained — read this document to understand the engine pipeline, data flow,
> state machine, and subsystem relationships without cross-referencing source code.

> Audience: contributors, extenders

## Overview

spec-kit-orchestrator is a spec-kit extension that adds autonomous multi-phase orchestration to spec-kit's spec-driven development workflow. It decomposes large features into milestones, phases, and tasks, then dispatches each task to a fresh agent context with a purpose-built payload. The orchestrator never holds long-running state in memory — all state is derived from file presence on disk under `.specify/orchestrator/`.

The system is structured as markdown commands (agent instruction documents in `commands/`), Bash 3.2+ helper scripts (organized by concern in `scripts/`), output templates (`templates/`), and reference documentation (`references/`). It registers with spec-kit via `extension.yml`, which declares 12 commands, 5 lifecycle hooks, and over 40 helper scripts. The extension requires spec-kit >= 0.1.0 and uses git for version control but has no runtime dependency on GSD-2 or APM.

The architecture follows 7 governing principles from the project constitution (`.specify/memory/constitution.md`), with Context Minimization (fresh context per task), State On Disk Is Truth (file-presence state machine), and Knowledge Compounds (persistent learning across milestones) being the most architecturally significant.

---

## Engine Pipeline

The engine (`scripts/engine/run.sh`) is the mechanical coordinator that executes a phase's tasks in sequence. It accepts a milestone and phase as arguments, discovers pending tasks, and runs each through a 7-stage pipeline.

```
  ┌─────────┐   ┌──────────┐   ┌─────────┐   ┌──────────┐
  │  1 Init  │──▶│  2 Hook  │──▶│ 3 Build │──▶│4 Compress│
  └─────────┘   └──────────┘   └─────────┘   └──────────┘
                                                    │
  ┌──────────┐   ┌──────────┐   ┌──────────┐        │
  │ 7 Record │◀──│ 6 Verify │◀──│5 Dispatch│◀───────┘
  └──────────┘   └──────────┘   └──────────┘
```

### Stage 1 — Init

Parses CLI arguments (`--dry-run`, `--force`, milestone, phase), initializes the run context via `scripts/lib/run-context.sh` (deterministic run ID, frozen timestamps), resolves the phase directory, and discovers pending tasks. A task is pending when its `T##-PLAN.md` exists but no sibling `T##-SUMMARY.md` is present. The engine also calls `scripts/dispatch/select-model.sh` to resolve the model ID and context budget from `templates/routing.yaml` for the "standard" complexity tier.

If a prior engine checkpoint exists (via `scripts/engine/checkpoint.sh`), crash-recovery detection fires and the engine skips tasks that completed before the crash.

### Stage 2 — Hook (PRE_DISPATCH)

Fires the `PRE_DISPATCH` lifecycle hook via `scripts/lib/hooks.sh`. Hooks receive a frozen, read-only snapshot of the phase directory (`chmod 444`). If a hook blocks (returns non-zero), the task is skipped with outcome "blocked" and the engine moves to the next task. Hook tampering (modifying the snapshot) triggers an unconditional `HOOK_VIOLATION` that is never downgraded, even under `--force`.

### Stage 3 — Build

Assembles the dispatch payload by calling `scripts/dispatch/build-context.sh`. This script reads a context recipe (`templates/context-recipe.yaml` or an override) and dispatches each section to a handler in `scripts/dispatch/lib/section-handlers.sh`. Sections include knowledge entries, decisions, scope/constraints, upstream phase summaries, the task plan, and computed state. The result is a structured markdown document with YAML frontmatter, a manifest table (section names, line ranges, token estimates, priorities), and the section bodies ordered for cache efficiency (static sections first, dynamic sections last).

For phase-planning payloads (when `TASK_ID=PHASE_PLAN`), a separate code path assembles the feature spec, context draft, roadmap excerpt, upstream summaries, decisions, and knowledge.

### Stage 4 — Compress

Calls `scripts/dispatch/compress-payload.sh` to fit the payload within the model's context budget. Compression is recipe-driven with three graduated steps applied in order until the token count is under budget:

1. **drop_optional** — Remove sections marked "optional" in the manifest.
2. **summarize** — Truncate `###` subsections within upstream summaries to a max word count.
3. **drop_lowest_confidence** — Remove knowledge entries sorted by confidence ascending.

The task plan section is never truncated. After compression, the manifest table is rebuilt to reflect the surviving sections with updated line ranges and token estimates.

### Stage 5 — Dispatch

Runs pre-dispatch safety guards (`guard_payload_sanity` and `guard_budget` from `scripts/lib/guards.sh`) to verify the payload meets minimum size thresholds and the session has not exceeded cost or duration caps. Emits a `DISPATCH_START` event with the selected model, estimated token count, and payload size. In dry-run mode, writes a stub to the output file; in real mode, the actual agent invocation is a stub placeholder (real dispatch is deferred to a future milestone). Guards can be force-overridden with `--force` except for hook violations.

### Stage 6 — Verify

Runs post-dispatch output sanity (`guard_output_sanity`) to ensure the agent produced non-trivial output, then calls `scripts/verify/check-must-haves.sh` against the phase directory. Must-have verification is a 3-category static check: Truths (grep patterns evaluated against the project), Artifacts (file existence with optional `min lines` and `contains` constraints), and Key Links (cross-file reference validation). After verification, `POST_VERIFY` hooks fire.

### Stage 7 — Record

Appends a structured JSON line to the execution log (`execution-log.jsonl`) via `scripts/lifecycle/record-result.sh` with milestone, phase, task, outcome, verification result, model, payload size, and run ID. Fires `POST_DISPATCH` hooks (non-blocking on failure). Writes an engine checkpoint via `scripts/engine/checkpoint.sh` so a crashed session can resume from the last completed task. Emits `TASK_COMPLETE` with the verify-gated outcome.

After all tasks complete, the engine runs `PRE_ADVANCE` hooks and the `guard_phase_complete` guard before emitting `PHASE_COMPLETE`. On success, the checkpoint is cleared.

---

## Data Flow

This section traces the end-to-end data flow for a single task dispatch, from recipe resolution through state advancement.

### 1. Recipe Resolution

The engine calls `build-context.sh` with the orchestrator root, milestone, phase, and task IDs. The script resolves the context recipe using FR-211 specificity: it checks for overrides at the task, phase, milestone, and project levels, falling back to `templates/context-recipe.yaml`. The recipe defines which sections to include, their source handlers, display order, priority, and compression strategy.

### 2. Section Assembly

The recipe's `sections:` block is parsed by `scripts/lib/recipe-parser.sh` into a pipe-delimited list of section definitions. Each section is dispatched to a handler function (in `scripts/dispatch/lib/section-handlers.sh`) that reads the appropriate state files and emits a `## Heading` markdown block. Key handlers:

- **knowledge** — Reads `KNOWLEDGE-INDEX.md`, filters entries by scope via `scripts/dispatch/scope-filter.sh`, traverses related entries via `scripts/knowledge/traverse-graph.sh`, resolves full entry content via `scripts/knowledge/resolve-entries.sh`, and increments hit counts.
- **scope** — Reads the phase plan's must-haves, artifacts, and boundary map.
- **upstream** — Reads completed phase summaries for dependency phases listed in the roadmap.
- **task_plan** — Reads the raw `T##-PLAN.md` content.
- **state** — Computes current state via `scripts/state/derive-phase.sh` and reads config values.

Sections are reordered by a display-order map for cache-friendly layout: static/rarely-changing sections (knowledge, decisions) first, dynamic sections (task plan, state) last.

### 3. Manifest and Frontmatter

The assembled sections are wrapped with YAML frontmatter (`schema_version`, `type: dispatch-prompt`), a title line, and a manifest table. The manifest lists each section's name, line range, estimated token count, and priority (required, filtered, or optional). This manifest enables the compression stage to make informed decisions about what to drop.

### 4. Compression

`compress-payload.sh` reads the manifest to identify optional sections and knowledge entries, then applies graduated compression steps from the recipe until the payload fits the context budget (default: 30,000 tokens for standard tier, configurable via `templates/routing.yaml`). The compressed payload has its manifest rebuilt to reflect surviving sections.

### 5. Guard and Dispatch

The engine runs `guard_payload_sanity` (minimum 100 characters) and `guard_budget` (cumulative cost and duration caps, disabled by default). If guards pass, the payload is dispatched to the selected model. The dispatch emits telemetry events for observability.

### 6. Verification and Recording

The output is checked by `guard_output_sanity`, then `check-must-haves.sh` runs the phase plan's must-have checks. Results are recorded to the execution log as a JSON line via `record-result.sh`. The engine writes a checkpoint and fires post-dispatch hooks.

### 7. State Advancement

After all tasks in the phase complete, the engine checks `guard_phase_complete` and fires `PRE_ADVANCE` hooks. On success, the file-presence state machine naturally advances: the presence of all `T##-SUMMARY.md` files moves the derived state from `executing` to `verifying`, and so on through the lifecycle.

---

## State Machine

The orchestrator uses a **file-presence state machine** with 10 canonical states. State is never stored as a field — it is derived deterministically by `scripts/state/derive-phase.sh`, which examines which files exist under `.specify/orchestrator/milestones/{M###}/` and returns the first matching rule in priority order.

| Priority | Derived State | Triggering Condition |
|----------|---------------|----------------------|
| 1 | `pre-planning` | Milestone directory absent or empty |
| 2 | `discussing` | `M###-CONTEXT.md` exists with `status: draft` |
| 3 | `planning` | No `M###-ROADMAP.md`, or active phase has no `P##-PLAN.md` |
| 4 | `replanning` | Any phase marked stale in the roadmap |
| 5 | `executing` | Active phase has task plans without matching summaries |
| 6 | `verifying` | All tasks done, no `P##-VERIFICATION.md` |
| 7 | `summarizing` | Verified, no `P##-SUMMARY.md` |
| 8 | `validating` | All phases complete, no `M###-VALIDATION.md` |
| 9 | `completing` | Validated, no `M###-SUMMARY.md` |
| 10 | `complete` | `M###-SUMMARY.md` exists |

The derivation script is intentionally tier-agnostic. Tier-specific gates (e.g., "Tier C requires discussion before planning") are enforced at the command layer, not the state derivation layer.

Tier B uses a 6-state subset: `pre-planning` > `planning` > `executing` > `verifying` > `summarizing` > `complete`. Tier C uses the full 10-state machine with discussion, replanning, validation, and completing states.

For the complete state transition diagram, tier-conditional behavior, and crash recovery semantics, see [State Machine](state-machine.md).

---

## File Layout

```
spec-kit-orchestrator/
├── extension.yml                      # Extension manifest (commands, hooks, scripts)
├── CLAUDE.md                          # Project instructions
├── CHANGELOG.md                       # Version history
├── commands/                          # Agent instruction documents (12 commands)
│   ├── auto.md                        #   Autonomous execution loop
│   ├── consolidate.md                 #   Knowledge consolidation
│   ├── discuss.md                     #   Pre-planning discussion
│   ├── dispatch.md                    #   Single task dispatch
│   ├── doctor.md                      #   Diagnostics runner
│   ├── evaluate.md                    #   Scope/tier classification
│   ├── migrate.md                     #   Data migration
│   ├── plan-phase.md                  #   Phase plan generation
│   ├── resume.md                      #   Crash/pause recovery
│   ├── roadmap.md                     #   Roadmap generation
│   ├── status.md                      #   Progress reporting
│   └── verify.md                      #   Must-have verification
├── scripts/                           # Bash helper scripts
│   ├── lib/                           #   Shared libraries
│   │   ├── errors.sh                  #     Error kind registry
│   │   ├── events.sh                  #     Structured event emission
│   │   ├── guards.sh                  #     Safety rail functions
│   │   ├── hash.sh                    #     Content hashing
│   │   ├── hooks.sh                   #     Hook lifecycle dispatcher
│   │   ├── manifest-builder.sh        #     Payload manifest table builder
│   │   ├── payload-transforms.sh      #     Token estimation utilities
│   │   ├── recipe-parser.sh           #     YAML recipe parser (pure bash)
│   │   ├── run-context.sh             #     Run ID and timestamp management
│   │   └── verdicts.sh                #     Hook verdict parsing
│   ├── engine/                        #   Engine pipeline
│   │   ├── run.sh                     #     Main 7-stage pipeline
│   │   ├── checkpoint.sh              #     Crash-recovery checkpoints
│   │   └── test-resume.sh             #     Resume integration test
│   ├── state/                         #   State derivation
│   │   ├── derive-phase.sh            #     10-state file-presence derivation
│   │   ├── find-active-milestone.sh   #     Active milestone detection
│   │   ├── read-config.sh             #     Config file reader
│   │   └── read-roadmap.sh            #     Roadmap parser
│   ├── dispatch/                      #   Payload construction
│   │   ├── build-context.sh           #     Recipe-driven context assembly
│   │   ├── classify-complexity.sh     #     Task complexity classification
│   │   ├── compress-payload.sh        #     Graduated payload compression
│   │   ├── detect-capabilities.sh     #     Host capability detection
│   │   ├── scope-filter.sh            #     Knowledge/decision scope filtering
│   │   ├── select-model.sh            #     Model routing with fallback chains
│   │   └── lib/
│   │       └── section-handlers.sh    #     Per-section content handlers
│   ├── verify/                        #   Verification subsystem
│   │   ├── check-must-haves.sh        #     Tier 1 static verification
│   │   ├── check-boundary-map.sh      #     Cross-phase boundary checks
│   │   ├── check-external-mods.sh     #     External modification detection
│   │   ├── check-scope.sh             #     Scope compliance checks
│   │   ├── run-commands.sh            #     Tier 2 command execution
│   │   └── validate-milestone.sh      #     Milestone-level validation
│   ├── knowledge/                     #   Knowledge lifecycle
│   │   ├── append-decision.sh         #     Decision register append
│   │   ├── append-knowledge.sh        #     Knowledge entry append
│   │   ├── archive-entry.sh           #     Entry archival
│   │   ├── compute-staleness.sh       #     Staleness scoring
│   │   ├── consolidate-artifacts.sh   #     Post-milestone consolidation
│   │   ├── create-entry.sh            #     New knowledge entry creation
│   │   ├── detect-overlap.sh          #     Entry deduplication
│   │   ├── increment-hits.sh          #     Usage tracking
│   │   ├── promote-entry.sh           #     Confidence promotion
│   │   ├── rebuild-index.sh           #     Index regeneration
│   │   ├── resolve-entries.sh         #     Entry content resolution
│   │   ├── supersede-entry.sh         #     Entry supersession
│   │   ├── traverse-graph.sh          #     Related-entry graph traversal
│   │   ├── update-confidence.sh       #     Confidence adjustment
│   │   ├── update-entry.sh            #     Entry updates
│   │   ├── write-summary.sh           #     Summary generation
│   │   └── lib/
│   │       ├── detail-utils.sh        #       Detail field utilities
│   │       ├── index-utils.sh         #       Index manipulation
│   │       └── staleness.sh           #       Staleness computation
│   ├── lifecycle/                     #   Session and phase lifecycle
│   │   ├── auto-loop.sh              #     Autonomous execution loop
│   │   ├── budget-checker.sh          #     Budget enforcement
│   │   ├── check-settings-state.sh    #     Settings validation
│   │   ├── context-monitor.sh         #     Context weight tracking
│   │   ├── evaluate-preflight.sh      #     Evaluate command pre-checks
│   │   ├── generate-permissions.sh    #     Autonomy permission generation
│   │   ├── lock-manager.sh            #     Session locking
│   │   ├── mark-complete.sh           #     Phase/milestone completion
│   │   ├── phase-transition.sh        #     Phase advancement
│   │   ├── record-result.sh           #     Execution log append
│   │   ├── recovery-briefing.sh       #     Crash recovery context
│   │   ├── rollback-phase.sh          #     Phase rollback
│   │   ├── scaffold.sh                #     Directory structure creation
│   │   ├── stuck-detector.sh          #     Stuck task detection
│   │   ├── sync-roadmap.sh            #     Roadmap state synchronization
│   │   └── write-permissions.sh       #     Permission file writer
│   ├── telemetry/                     #   Observability
│   │   ├── record-telemetry.sh        #     Per-dispatch telemetry
│   │   └── aggregate-metrics.sh       #     Session-level aggregation
│   ├── diagnostics/                   #   Doctor subsystem
│   │   ├── run-doctor.sh              #     Diagnostics runner
│   │   ├── check-constitution.sh      #     Constitution consistency
│   │   ├── check-cost-spikes.sh       #     Cost anomaly detection
│   │   ├── check-events.sh            #     Event consistency
│   │   ├── check-hashes.sh            #     Content hash validation
│   │   ├── check-instructions.sh      #     Instruction schema checks
│   │   ├── check-orphaned.sh          #     Orphaned artifact detection
│   │   ├── check-permissions.sh       #     Permission file checks
│   │   ├── check-plans.sh             #     Plan consistency
│   │   ├── check-providers.sh         #     Provider convention checks
│   │   ├── check-recipe.sh            #     Recipe validation
│   │   ├── check-run-ids.sh           #     Run ID consistency
│   │   ├── check-scope.sh             #     Scope mismatch detection
│   │   └── check-stale.sh             #     Stale knowledge detection
│   ├── migrate/                       #   Migration subsystem
│   │   ├── migrate.sh                 #     Migration coordinator
│   │   ├── adapter-interface.sh       #     Adapter protocol
│   │   ├── adapters/                  #     Source format adapters
│   │   ├── lib/                       #     Migration utilities
│   │   └── transform/                 #     Data transformers
│   └── util/                          #   Shared utilities
│       ├── check-plan-exists.sh       #     Plan file existence check
│       ├── classify-command.sh        #     Command classification
│       ├── detect-milestone-id.sh     #     Milestone ID detection
│       └── json-field.sh              #     JSON field extraction
├── templates/                         # Output templates and config defaults
│   ├── context-recipe.yaml            #   Section assembly recipe
│   ├── routing.yaml                   #   Model routing configuration
│   ├── hooks.yaml                     #   Lifecycle hook definitions
│   ├── autonomy-defaults.yaml         #   Autonomy permission defaults
│   ├── orchestrator-config-default.yml #  Default configuration
│   ├── dispatch-prompt.md             #   Dispatch payload template
│   ├── task-plan.md                   #   Task plan template
│   ├── phase-plan.md                  #   Phase plan template
│   ├── phase-summary.md              #   Phase summary template
│   ├── task-summary.md               #   Task summary template
│   ├── milestone-summary.md          #   Milestone summary template
│   ├── evaluation.md                  #   Tier evaluation template
│   ├── roadmap.md                     #   Roadmap template
│   ├── context-draft.md              #   Discussion context template
│   ├── verification-report.md        #   Verification report template
│   ├── recovery-briefing.md          #   Crash recovery template
│   ├── spec-compliance-review.md     #   Spec review template
│   ├── continue-file.md              #   Pause/resume template
│   ├── instruction-schema.md         #   Agent instruction format
│   └── claude-settings.json          #   Claude-specific settings
├── references/                        # Progressive disclosure documentation
│   ├── architecture.md                #   System architecture (this document)
│   ├── state-machine.md               #   10-state lifecycle
│   ├── verification-ladder.md         #   4-tier verification protocol
│   ├── tier-definitions.md            #   Tier A/B/C classification
│   ├── file-formats.md                #   State file format contracts
│   ├── installation.md                #   Setup guide
│   └── provider-convention.md         #   Agent provider conventions
├── tests/                             # Test suites
│   ├── test-s01-structure.sh          #   Structural tests
│   ├── test-s02-state-machine.sh      #   State derivation tests
│   ├── test-s03-design-artifacts.sh   #   Design artifact tests
│   ├── test-s04-core-commands.sh      #   Command tests
│   ├── test-s05-autonomous-mode.sh    #   Autonomous mode tests
│   ├── test-s06-knowledge-lifecycle.sh #  Knowledge lifecycle tests
│   ├── test-s07-integration.sh        #   Integration tests
│   ├── test-s08-auto-safety.sh        #   Auto safety tests
│   └── fixtures/                      #   Test fixture data
├── specs/                             # Feature specifications
├── knowledge/                         # Knowledge archive
├── docs/                              # Additional documentation
└── .specify/                          # spec-kit project state
    ├── memory/                        #   Constitution and memory
    ├── orchestrator/                  #   Orchestrator runtime state
    │   ├── KNOWLEDGE.md               #     Global knowledge file
    │   └── milestones/                #     Per-milestone state
    └── scripts/                       #   spec-kit scripts
```

---

## Subsystem Map

### M001 — Foundation

M001 delivered the v0.1.0 base: the core orchestration pipeline from evaluate through consolidate. Key contributions:

- **State Machine** (`scripts/state/derive-phase.sh`, `scripts/state/read-roadmap.sh`) — File-presence state derivation with 10 canonical states. The roadmap parser extracts phase metadata (status, risk, dependencies) from the structured roadmap format.
- **Core Commands** (`commands/evaluate.md` through `commands/consolidate.md`) — 10 agent instruction documents covering the full milestone lifecycle: evaluate, discuss, roadmap, plan-phase, dispatch, auto, verify, status, resume, consolidate.
- **Verification** (`scripts/verify/check-must-haves.sh`, `scripts/verify/run-commands.sh`) — Tier 1 static verification (truths, artifacts, key links) and Tier 2 configured command execution.
- **Lifecycle Management** (`scripts/lifecycle/scaffold.sh`, `scripts/lifecycle/lock-manager.sh`, `scripts/lifecycle/record-result.sh`) — Directory scaffolding, session locking with crash detection, and structured execution logging.
- **Knowledge** (`scripts/knowledge/write-summary.sh`, `scripts/knowledge/append-decision.sh`, `scripts/knowledge/append-knowledge.sh`, `scripts/knowledge/consolidate-artifacts.sh`) — Summary generation, decision/knowledge append, and post-milestone consolidation.
- **Test Suite** — 7 test suites with 334 assertions covering structure, state machine, design artifacts, commands, autonomous mode, knowledge lifecycle, and integration.

### M002 — Knowledge Architecture

M002 added the indexed knowledge system with graph traversal, telemetry, model routing, and diagnostics.

- **Knowledge Index** (`scripts/knowledge/create-entry.sh`, `scripts/knowledge/rebuild-index.sh`, `scripts/knowledge/traverse-graph.sh`, `scripts/knowledge/resolve-entries.sh`) — Structured knowledge entries with `MEM###` IDs, YAML frontmatter (confidence, scope, relates_to), index rebuilding, and graph traversal for related-entry discovery.
- **Knowledge Lifecycle** (`scripts/knowledge/update-entry.sh`, `scripts/knowledge/promote-entry.sh`, `scripts/knowledge/supersede-entry.sh`, `scripts/knowledge/archive-entry.sh`) — Entry updates, confidence promotion, supersession chains, and archival with staleness computation.
- **Scope Filtering** (`scripts/dispatch/scope-filter.sh`) — Filters knowledge and decision entries by milestone/phase scope and dependency graph for targeted payload inclusion.
- **Telemetry** (`scripts/telemetry/record-telemetry.sh`, `scripts/telemetry/aggregate-metrics.sh`) — Per-dispatch telemetry recording (tokens, cost, cache hit rate) and session-level metric aggregation.
- **Model Routing** (`scripts/dispatch/select-model.sh`, `scripts/dispatch/classify-complexity.sh`, `templates/routing.yaml`) — Tier-based model selection (heavy/standard/light) with fallback chains and context budget configuration.
- **Diagnostics** (`scripts/diagnostics/run-doctor.sh` and 5 initial checks) — Orphaned artifact detection, stale knowledge identification, scope mismatch flagging, and cost spike analysis.

### M003 — Migration

M003 built the migration subsystem for importing data from other workflow tools.

- **Migration Framework** (`scripts/migrate/migrate.sh`, `scripts/migrate/adapter-interface.sh`) — Adapter-based migration coordinator that detects source format (GSD v1, GSD v2, spec-kit) and transforms data into orchestrator format.
- **Adapters and Transforms** (`scripts/migrate/adapters/`, `scripts/migrate/transform/`) — Source-specific adapters and data transformation pipelines.
- **Migrate Command** (`commands/migrate.md`) — Agent instruction document for running migrations with dry-run support.

### M004 — Engine

M004 built the mechanical engine pipeline that automates the dispatch-verify-record loop.

- **Engine Pipeline** (`scripts/engine/run.sh`) — The 7-stage pipeline described in the Engine Pipeline section above. Accepts `--dry-run` and `--force` flags, supports `ORCH_RUN_SEED` for reproducible runs.
- **Checkpoint System** (`scripts/engine/checkpoint.sh`) — Atomic JSON checkpoint write/read/detect/clear for crash recovery. Checkpoints record run ID, milestone, phase, last completed task, outcome, and timestamp.
- **Shared Libraries** (`scripts/lib/errors.sh`, `scripts/lib/events.sh`, `scripts/lib/guards.sh`, `scripts/lib/hooks.sh`, `scripts/lib/run-context.sh`) — Error kind registry (CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO), structured event emission with a canonical 18-type registry, safety guards (payload sanity, budget, output sanity, phase complete), hook lifecycle dispatcher with sandbox enforcement, and deterministic run context initialization.
- **Recipe System** (`scripts/lib/recipe-parser.sh`, `templates/context-recipe.yaml`) — Pure-bash YAML recipe parser and the default context recipe defining section selection, ordering, and compression strategy.

### M005 — Hardening

M005 hardened the system for production use with additional diagnostics, provider conventions, and autonomy permissions.

- **Extended Diagnostics** (`scripts/diagnostics/check-instructions.sh`, `scripts/diagnostics/check-providers.sh`, `scripts/diagnostics/check-constitution.sh`, `scripts/diagnostics/check-events.sh`, `scripts/diagnostics/check-hashes.sh`, `scripts/diagnostics/check-run-ids.sh`, `scripts/diagnostics/check-plans.sh`, `scripts/diagnostics/check-recipe.sh`, `scripts/diagnostics/check-permissions.sh`) — Instruction schema validation, provider convention compliance, constitution consistency, event registry drift detection, content hash verification, run ID consistency, plan structural checks, recipe validation, and permission file checks.
- **Provider Convention** (`references/provider-convention.md`) — Reference document defining how agent providers integrate with the orchestrator's dispatch and verification protocols.
- **Autonomy Permissions** (`scripts/lifecycle/generate-permissions.sh`, `scripts/lifecycle/write-permissions.sh`, `templates/autonomy-defaults.yaml`) — Permission generation based on tier and mode (minimal/standard/full), with configurable deny and allow patterns.
- **Payload Infrastructure** (`scripts/lib/payload-transforms.sh`, `scripts/lib/manifest-builder.sh`, `scripts/dispatch/lib/section-handlers.sh`) — Token estimation utilities, manifest table construction, and per-section content handler dispatch.
- **Verdict System** (`scripts/lib/verdicts.sh`) — Hook verdict parsing for structured pass/fail/warn outcomes from lifecycle hooks.

---

## Cross-References

- [State Machine](state-machine.md) — Full 10-state lifecycle with transition diagram and tier-conditional behavior
- [File Formats](file-formats.md) — State file format contracts for all orchestrator artifacts
- [Verification Ladder](verification-ladder.md) — 4-tier verification protocol (static, commands, behavioral, human)
- [Tier Definitions](tier-definitions.md) — Tier A/B/C classification criteria and feature availability
- [Installation](installation.md) — Setup guide for installing the extension into a consumer project
- [Provider Convention](provider-convention.md) — Agent provider integration protocol
