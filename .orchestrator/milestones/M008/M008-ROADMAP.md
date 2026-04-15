---
schema_version: "1.0"
type: roadmap
milestone: "M008"
feature_ref: "008-standalone-orchestrator"
feature_spec: "specs/008-standalone-orchestrator/spec.md"
vision: "Transform the orchestrator into a standalone, multi-runtime extension that automatically calibrates process intensity to the work at hand."
tier: "C"
created_at: "2026-04-14T00:00:00Z"
updated_at: "2026-04-14T00:00:00Z"
---

## Phases

- [x] **P01**: Adaptive Intensity Engine — "A developer describes a task and the orchestrator recommends Quick, Standard, or Full intensity with reasoning, factoring in scope, risk signals, and detected environment capabilities."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces:
      - `scripts/engine/intensity-analyze.sh` — scope/risk/complexity analyzer that reads a natural-language description and outputs an intensity recommendation with reasoning
      - `scripts/dispatch/detect-capabilities.sh` (refactored) — probes environment for graph DB, MCP servers, CI pipelines; outputs a capability profile
      - `scripts/engine/intensity-recommend.sh` — recommendation engine that combines scope analysis + risk signals + capability profile → Quick/Standard/Full with confidence and reasoning
      - `templates/intensity-metadata.md` — intensity metadata schema (data structure that flows through all pipeline stages as YAML frontmatter)
      - `scripts/engine/context-pressure.sh` — context window pressure evaluator with configurable warn/decompose/refuse thresholds
    - Consumes: nothing

- [x] **P02**: Dispatch Interface & Backend Adapters — "A task dispatched through the orchestrator returns a structured result with completion status and artifacts, regardless of whether it executed via Claude Code's Agent tool or Codex CLI's SDK."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces:
      - `scripts/dispatch/dispatch-interface.sh` — uniform dispatch entry point: accepts task plan + context payload + intensity metadata, routes to registered backend, returns structured result
      - `scripts/dispatch/adapters/backend/local-agent.sh` — Claude Code Agent tool backend adapter
      - `scripts/dispatch/adapters/backend/local-codex.sh` — Codex CLI SDK backend adapter
      - `scripts/dispatch/backend-registry.sh` — discover and register available dispatch backends
      - `templates/dispatch-result.md` — dispatch result schema (completion status, artifacts list, structured errors)
      - `templates/dispatch-error.md` — structured error schema (error type, retry eligibility, escalation guidance)
    - Consumes: nothing

- [x] **P03**: Intensity-Aware Pipeline Scaling — "Every pipeline stage — discussion, research, planning, verification, knowledge generation, and dispatch — adjusts its depth and breadth based on the active intensity level, and a developer can override intensity mid-workflow without restarting."
  - Risk: high
  - Depends: P01, P02
  - Boundary Map:
    - Produces:
      - `scripts/engine/intensity-gate.sh` — stage-level gate that reads intensity metadata and returns which sub-steps to execute/skip for the current stage
      - Refactored pipeline stages: `commands/discuss.md`, `commands/plan-phase.md`, `commands/dispatch.md`, `commands/verify.md`, `commands/auto.md` — each reads intensity metadata and scales behavior
      - `scripts/engine/intensity-override.sh` — mid-workflow intensity override that updates metadata for remaining stages while preserving completed stage outputs
      - `scripts/knowledge/intensity-knowledge.sh` — intensity-aware knowledge generation (summaries-only at Quick, full pipeline at Full)
    - Consumes:
      - `templates/intensity-metadata.md` (P01) — intensity schema that each stage reads
      - `scripts/engine/intensity-recommend.sh` (P01) — initial recommendation that seeds the workflow
      - `scripts/dispatch/dispatch-interface.sh` (P02) — dispatch stage integration carries intensity metadata through to backends

- [x] **P04**: State & Namespace Independence — "The orchestrator stores all state in its own `.orchestrator/` directory, uses the `orchestrator:*` command namespace, and completes a full workflow without spec-kit installed."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - `scripts/state/resolve-root.sh` — resolves the orchestrator state root: checks config for custom root, falls back to `.orchestrator/` (standalone) or `.specify/orchestrator/` (spec-kit mode)
      - `scripts/state/detect-speckit.sh` — detects whether spec-kit is installed; toggles integration mode
      - `scripts/state/config-system.sh` — unified configuration system: reads/writes orchestrator settings from the resolved state root
      - `scripts/migrate/migrate-state.sh` — migrates state from `.specify/orchestrator/` → `.orchestrator/` for existing users
      - Refactored `scripts/state/derive-phase.sh` — uses `resolve-root.sh` instead of hardcoded `.specify/orchestrator/` path
      - `scripts/state/namespace-aliases.sh` — maps `speckit.orchestrator.*` commands to `orchestrator:*` namespace for backward compatibility
    - Consumes: nothing

- [x] **P05**: Runtime & Format Adapters — "The same orchestrator command produces equivalent state files and artifacts whether invoked from Claude Code, Codex CLI, or Cursor, and the runtime is auto-detected without developer configuration."
  - Risk: medium
  - Depends: P02, P04
  - Boundary Map:
    - Produces:
      - `scripts/dispatch/adapters/runtime/claude-code.sh` — Claude Code runtime adapter: CLAUDE.md integration, `~/.claude/commands/` skill registration, settings.json hook wiring
      - `scripts/dispatch/adapters/runtime/codex.sh` — Codex CLI runtime adapter: AGENTS.md integration, `~/.codex/skills/` registration, config.toml hook wiring
      - `scripts/dispatch/adapters/runtime/cursor.sh` — Cursor runtime adapter: rules-based integration (best-effort)
      - `scripts/dispatch/adapters/format/native.sh` — orchestrator's native lightweight task format adapter
      - `scripts/dispatch/adapters/format/speckit.sh` — spec-kit tasks.md/plan.md format adapter (one-directional read)
      - `scripts/dispatch/detect-runtime.sh` — auto-detects current runtime from environment signals
    - Consumes:
      - `scripts/dispatch/dispatch-interface.sh` (P02) — format adapters produce task payloads that dispatch consumes; runtime adapters register backends via the dispatch interface
      - `scripts/state/resolve-root.sh` (P04) — runtime adapters map to the canonical state location
      - `scripts/state/namespace-aliases.sh` (P04) — runtime adapters expose commands under the `orchestrator:*` namespace

- [x] **P06**: Multi-Runtime Packaging — "A developer installs the orchestrator with a single command on any supported runtime, and each orchestrator command is discoverable as a native skill in that runtime."
  - Risk: medium
  - Depends: P04, P05
  - Boundary Map:
    - Produces:
      - `packaging/SKILL.md` — SKILL.md format specification (open standard for cross-runtime skill discovery)
      - `packaging/skills/` — individual skill files for each orchestrator command, one per command
      - `packaging/bundle/` — plugin bundle structure (all skills + hooks + config in one installable unit)
      - `packaging/install/install-claude-code.sh` — Claude Code installer
      - `packaging/install/install-codex.sh` — Codex CLI installer
      - `packaging/install/install-cursor.sh` — Cursor installer
      - `scripts/lifecycle/check-update.sh` — version check script (compares installed vs latest, reports update instructions)
    - Consumes:
      - `scripts/dispatch/adapters/runtime/*.sh` (P05) — installers need runtime adapter details to wire up correctly per runtime
      - `scripts/state/namespace-aliases.sh` (P04) — skill files reference the `orchestrator:*` namespace
      - `scripts/state/resolve-root.sh` (P04) — installers configure the state root

- [x] **P07**: Init, Onboarding & Spec-Kit Bridge — "A developer runs `orchestrator:init` in any project and within two minutes has a working configuration, project instruction file, and can immediately execute their first orchestrated workflow."
  - Risk: medium
  - Depends: P01, P05, P06
  - Boundary Map:
    - Produces:
      - `commands/init.md` — `orchestrator:init` command definition
      - `scripts/lifecycle/init-project.sh` — project detection, capability probe, config generation, instruction file generation
      - `templates/project-instruction.md` — project instruction file template (runtime-discoverable context)
      - `scripts/lifecycle/detect-project.sh` — scans project structure for frameworks, languages, CI config, existing tools
      - `scripts/lifecycle/reinit-handler.sh` — handles re-initialization: detects existing config, offers update/reset, preserves context
    - Consumes:
      - `scripts/dispatch/detect-capabilities.sh` (P01) — init runs capability detection during setup
      - `scripts/dispatch/adapters/runtime/*.sh` (P05) — init generates runtime-specific instruction files
      - `scripts/dispatch/detect-runtime.sh` (P05) — init detects which runtime is active
      - `packaging/install/*.sh` (P06) — init verifies installation completeness

## Cross-Cutting Concerns

- **Intensity metadata propagation** — P01, P02, P03, P05, P07. P01 defines the intensity metadata schema; all consuming phases must conform to it. The schema flows as YAML frontmatter through state files and as parameters through dispatch payloads. P03 is the integration phase that wires it into every pipeline stage; P05 ensures format adapters preserve it; P07 sets initial defaults during init.

- **Structured error handling** — P02, P03, P05, P07. P02 establishes the dispatch error schema; P03 extends it for pipeline stage errors; P05 uses it for runtime adapter failures; P07 uses it for init errors. All error returns must include error type, whether retry is appropriate, and escalation guidance.

- **Configuration system** — P01, P04, P05, P06, P07. P04 establishes the unified configuration system (resolve-root, read-config, write-config); all other phases read from and write to it. P01 stores intensity thresholds, P05 stores runtime-specific settings, P06 stores update preferences, P07 writes initial configuration during init.

- **State directory resolution** — P04, P05, P06, P07. P04 produces `resolve-root.sh`; all downstream phases must use it instead of hardcoded paths. No phase may assume `.specify/orchestrator/` or `.orchestrator/` directly — always call `resolve-root.sh`.

## Dependency Graph

```
P01 ──────────────────────→ P03
                              ↑
P02 ──────────────────────→ P03
  └──→ P05 ──→ P06 ──→ P07
        ↑              ↗
P04 ──→ P05      P01 ─┘
  └──────→ P06
```

Parallel opportunities:
- Wave 1: P01, P02, P04 (all independent)
- Wave 2: P03, P05 (P03 needs P01+P02; P05 needs P02+P04)
- Wave 3: P06 (needs P04+P05)
- Wave 4: P07 (needs P01+P05+P06)

## Execution Order

1. **P01, P02, P04** — all independent, execute concurrently. P01 and P02 are both high-risk and on the critical path; starting them together maximizes early risk retirement. P04 is medium-risk but has no dependencies and unblocks P05/P06.
2. **P03, P05** — execute concurrently once wave 1 completes. P03 (high-risk integration) wires intensity into all pipeline stages using P01+P02. P05 (medium-risk) implements runtime/format adapters using P02+P04. These are independent of each other.
3. **P06** — depends on P04+P05. Packages the orchestrator for multi-runtime distribution. Cannot start until runtime adapters (P05) and namespace (P04) are established.
4. **P07** — depends on P01+P05+P06. The onboarding capstone: init command, project detection, first-run experience. Runs last because it integrates outputs from across the milestone.

## Validation

- **No conflicting producers**: PASS — no two phases produce the same artifact. P01 produces the intensity engine scripts, P02 produces the dispatch interface scripts, P04 produces state resolution scripts. The `scripts/dispatch/` directory is shared between P02 (backend adapters) and P05 (runtime/format adapters) but they produce different files within it.
- **All consumed items have producers**: PASS — every consumed item maps to a produces entry in an upstream phase. Verified: P03 consumes P01's intensity schema + P02's dispatch interface; P05 consumes P02's dispatch interface + P04's resolve-root and namespace; P06 consumes P05's runtime adapters + P04's namespace; P07 consumes P01's capability probe + P05's runtime detection + P06's installers.
- **DAG is acyclic**: PASS — topological sort confirms: P01→P03, P02→P03, P02→P05, P04→P05, P04→P06, P05→P06, P01→P07, P05→P07, P06→P07. No back edges.
- **Demo sentence coverage**: PASS — all 7 phases have concrete, observable demo sentences describing what a developer can verify when the phase is complete.
