# Implementation Plan: Speckit-Orchestrator Extension

**Branch**: `001-speckit-orchestrator` | **Date**: 2026-03-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-speckit-orchestrator/spec.md`

## Summary

Build a spec-kit extension that adds autonomous multi-phase orchestration to spec-kit's SDD workflow. The orchestrator introduces a milestone/phase/task hierarchy above spec-kit's existing task model, a file-based state machine for tracking progress, a runtime adapter interface for dispatching work to fresh agent contexts, mechanical verification gates, and continuous knowledge generation. The extension is implemented entirely as markdown command templates + bash scripts — no compiled code. All state lives on disk under `.specify/orchestrator/`. The design was refined through two 3-tool conversus processes: (1) spec-level review producing 15 artifacts with 8 convergence positions, and (2) plan-level review producing 15 additional artifacts with 8 convergence positions, 13 new recommendations, and resolution of 20 dangerous contradictions.

## Technical Context

**Language/Version**: Markdown (spec-kit command format) + Bash 4+ / POSIX sh (helper scripts)
**Primary Dependencies**: spec-kit >=0.1.0 (extension host), git (version control, worktree isolation), jq (optional, JSON parsing in scripts)
**Storage**: File-based state machine — YAML frontmatter + markdown body files, JSONL append-only logs, JSON lock files. All state at `.specify/orchestrator/`
**Testing**: Shell-based integration tests (BATS or plain bash assert scripts) + `/speckit.analyze` for cross-artifact consistency
**Target Platform**: Any OS with bash/sh and a spec-kit-supported AI agent (Claude Code, Copilot, Cursor, Gemini CLI, OpenCode)
**Project Type**: spec-kit extension (markdown commands + shell scripts + YAML manifest)
**Performance Goals**: State derivation <1s from disk reads; dispatch prompt construction <2s; verification checks <5s per phase
**Constraints**: Every task must fit one context window; all state recoverable from disk; commands must be idempotent; dispatch payloads scope-filtered (not whole-file injection)

### Dependency Matrix

| System | When It Runs | Required At |
|--------|-------------|-------------|
| **spec-kit** | Always | Runtime — extension host, command execution, hook system |
| **APM** | Install/update only | `apm install` deploys extension; `apm compile` generates instruction files. Never invoked at orchestration runtime. |
| **gh-aw** | Workflow compile only | `gh aw compile` converts workflow markdown to Actions YAML. Never invoked during task dispatch. |
| **CI runner deps** | Runtime (CI only) | git, bash, jq — no APM CLI, no gh-aw CLI required on runners |

**Scale/Scope**: 10 commands, ~20 helper scripts, ~15 templates, 1 extension manifest, 1 APM manifest, ~5 reference documents. Target: orchestrate projects with up to 5 milestones × 10 phases × 7 tasks each

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Evidence |
|---|-----------|--------|----------|
| I | Context Minimization | PASS | Scope-filtered knowledge injection (FR-062, FR-063). Dispatch payloads contain only task plan + relevant upstream summaries + scoped decisions/knowledge. Context verbosity is configurable (FR-050). |
| II | Evidence Before Claims | PASS | Per-task mechanical verification of must-haves (FR-016). Verification ladder: static → command → behavioral → human (FR-018). Two-stage phase review (FR-015). No self-assessment accepted. |
| III | Design Before Code | PASS | This plan exists. Tier C requires finalized context draft before roadmap (FR-056). Every phase plans before executing. |
| IV | Plans Assume Zero Context | PASS | Task plans include exact file paths, complete code, exact commands with expected output (FR-011). Dispatch payloads are self-contained (FR-012). |
| V | Fresh Context Per Unit | PASS | Each task dispatches to fresh agent context via runtime adapter (FR-013, FR-067). Subagents never inherit orchestrator session history (FR-012). |
| VI | State On Disk Is Truth | PASS | All state at `.specify/orchestrator/` (FR-019). State machine derives phase from file presence (FR-020). Lock files for crash detection (FR-021). No in-memory state across sessions. |
| VII | Knowledge Compounds | PASS | Mandatory phase summaries (FR-024). Append-only DECISIONS.md (FR-025) and KNOWLEDGE.md (FR-026). Knowledge consolidation compresses artifacts (FR-027). Hierarchical placement by scope (FR-062). |

**Gate Result: PASS** — All 7 principles satisfied. No violations to track.

## Project Structure

### Documentation (this feature)

```text
specs/001-speckit-orchestrator/
├── plan.md              # This file
├── research.md          # Phase 0: resolved technical decisions
├── data-model.md        # Phase 1: entity model and state file schemas
├── quickstart.md        # Phase 1: developer getting-started guide
├── contracts/           # Phase 1: command interface contracts
│   ├── extension-manifest.md
│   ├── runtime-adapter.md
│   └── state-files.md
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
extension.yml                          # spec-kit extension manifest (the deliverable)
orchestrator-config.yml                # Project-level config (user-mutable, outside APM radius)
orchestrator-config.local.yml          # Local dev overrides (gitignored)
apm.yml                                # APM package manifest (distribution)
SKILL.md                               # Root-level skill summary for APM discovery
.extensionignore                       # Excludes specs/, docs/, .planning/, tests/unit/ from extension install
commands/                              # spec-kit command definitions (markdown + frontmatter)
│   ├── evaluate.md                    # Scope triage (Tier A/B/C)
│   ├── discuss.md                     # Pre-planning context capture
│   ├── roadmap.md                     # Spec → phases with boundary maps
│   ├── plan-phase.md                  # Phase → tasks with must-haves
│   ├── dispatch.md                    # Execute one task in fresh context
│   ├── auto.md                        # State machine loop
│   ├── verify.md                      # Must-haves verification
│   ├── status.md                      # Progress dashboard
│   ├── resume.md                      # Crash/pause recovery
│   └── consolidate.md                 # Knowledge compression + archival
scripts/                               # Helper scripts (composed by commands)
│   ├── state/
│   │   ├── derive-phase.sh            # Read disk → determine state machine phase
│   │   ├── read-roadmap.sh            # Parse roadmap YAML frontmatter + checkboxes
│   │   ├── read-config.sh             # Multi-layer config resolution
│   │   └── check-lock.sh             # Lock file status (stale/active/none)
│   ├── dispatch/
│   │   ├── build-context.sh           # Construct minimal dispatch payload
│   │   ├── scope-filter.sh            # Filter KNOWLEDGE/DECISIONS by scope
│   │   └── detect-capabilities.sh     # Runtime capability detection
│   ├── verify/
│   │   ├── check-must-haves.sh        # Mechanical artifact/truth/link checks
│   │   ├── check-boundary-map.sh      # Cross-phase interface verification
│   │   └── run-commands.sh            # Execute configured verification commands
│   ├── knowledge/
│   │   ├── write-summary.sh           # Generate task/phase/milestone summary
│   │   ├── append-decision.sh         # Append to DECISIONS.md
│   │   ├── append-knowledge.sh        # Append to KNOWLEDGE.md
│   │   └── consolidate-artifacts.sh   # Compress + archive
│   └── lifecycle/
│       ├── scaffold.sh                # Create milestone directory structure
│       ├── advance-state.sh           # Persist state transition to disk
│       ├── write-lock.sh              # Create/update lock file
│       └── write-continue.sh          # Create continue file for graceful pause
templates/                             # Output templates (copied + filled by agent)
│   ├── roadmap.md                     # Milestone roadmap layout
│   ├── phase-plan.md                  # Phase plan with must-haves
│   ├── task-plan.md                   # Task plan with verification criteria
│   ├── task-summary.md                # T##-SUMMARY.md frontmatter + body
│   ├── phase-summary.md               # P##-SUMMARY.md frontmatter + body
│   ├── milestone-summary.md           # M###-SUMMARY.md frontmatter + body
│   ├── dispatch-prompt.md             # Context payload for fresh agent dispatch
│   ├── recovery-briefing.md           # Crash recovery context synthesis
│   ├── continue-file.md               # Graceful pause resume point
│   ├── context-draft.md               # Discussion context capture
│   ├── verification-report.md         # Must-haves check results
│   └── spec-compliance-review.md      # Phase review prompt
references/                            # Progressive disclosure docs
│   ├── state-machine.md               # Full state machine definition + transitions
│   ├── verification-ladder.md         # Static → command → behavioral → human
│   ├── tier-definitions.md            # A/B/C behavior differences
│   └── file-formats.md               # All file format specifications
docs/                                  # Extension documentation
│   ├── getting-started.md
│   └── configuration.md
tests/                                 # Integration tests
│   ├── test-scaffold.sh
│   ├── test-state-derivation.sh
│   ├── test-config-resolution.sh
│   ├── test-scope-filter.sh
│   └── fixtures/                      # Test fixtures (sample state trees)
```

**Structure Decision**: Flat extension layout following spec-kit conventions. Commands at `commands/`, helper scripts at `scripts/` (organized by concern), templates at `templates/`, references at `references/`. No parallel `skills/` tree — command markdown is the authoritative definition; one manually-maintained root `SKILL.md` provides package-level discoverability (per conversus convergence and arbitration revision of AD-6).

## Architecture Decisions (from Conversus Process)

These 8 decisions represent unanimous convergence across all 3 tool perspectives (APM, spec-kit, gh-aw) after 15 review artifacts and 3 iterations:

### AD-1: Spec-Kit Extension First
The orchestrator is a spec-kit extension that APM distributes. Not an APM package that happens to run in spec-kit. The extension model (`extension.yml`, command registration, hook system) is the canonical organizational structure.

### AD-2: Disk State is Sole Source of Truth
`.specify/orchestrator/` is the authoritative state location. External representations (GitHub sub-issues, Projects boards, repo-memory branches) are read-only projections, never authoritative sources. Runtime-generated knowledge artifacts live here, separate from the extension's deployment directory.

### AD-3: Runtime Adapter Interface
A pluggable adapter layer with 5 core operations: `dispatch-task`, `await-completion`, `collect-result`, `signal-failure`, `inject-context`. Runtime adapters (local subprocess, gh-aw CI, future runtimes) implement these using platform-native primitives. Core orchestrator logic never branches on runtime identity.

### AD-4: Static Config / Dynamic State Separation
Static config flows through spec-kit's multi-layer config system (extension defaults → project overrides → local overrides → env vars). Dynamic state lives exclusively in `.specify/orchestrator/`. The two domains never overlap. No config changes during orchestration execution.

### AD-5: No Core Command Overrides
New `speckit.orchestrator.*` commands delegate to standard spec-kit workflows with injected context. Preset-based command replacement is prohibited. Command composition for steps without hooks (plan, specify, clarify).

### AD-6: Manual SKILL.md, No Derivation (Revised by Arbitration)
One manually-maintained root-level `SKILL.md` as the package-level discoverability surface. Command frontmatter remains authoritative for per-command behavior. APM derivation from frontmatter does not exist today — building it violates Principle 3 (Design Before Code). When APM ships derivation, adopt it then. `SKILL.md` is updated at milestone boundaries as part of the release checklist.

### AD-7: Three-Bucket Separation (Extended by Arbitration)
Three concerns with non-overlapping write ownership and different lifecycles:

| Bucket | Location | Write Owner | Lifecycle |
|--------|----------|-------------|-----------|
| Deployment | `.specify/extensions/orchestrator/` | Package manager (APM / specify) | Replaced on install/upgrade |
| Runtime state | `.specify/orchestrator/` | Orchestrator | Written during execution |
| Configuration | Project root (`orchestrator-config.yml`) | Developer | Created once, evolved over time |

No bucket's owner can corrupt another bucket's contents. This resolves the install-time-overwrite vs. runtime-config-persistence tension structurally.

### AD-8: Mechanical Verification Protocol
Verification is runtime-agnostic and protocol-defined. What checks run and what constitutes passing is defined once. Execution varies by runtime (spec-kit hooks locally, workflow steps in CI). The verification ladder (static → command → behavioral → human) is universal.

## Manifest Authority Boundaries

| Concern | Authoritative Source | Other References |
|---------|---------------------|-----------------|
| Command registration | `extension.yml` | — |
| Hook declarations | `extension.yml` | — |
| Config schema | `extension.yml` | — |
| spec-kit compatibility | `extension.yml` | — |
| Distribution metadata | `apm.yml` | — |
| Compilation settings | `apm.yml` | — |
| Script aliases | `apm.yml` | — |
| Multi-agent targets | `apm.yml` | — |
| Name, version, description | `extension.yml` (source of truth) | `apm.yml` must match |

A CI check should validate consistency between overlapping fields.

## apm.yml Manifest

```yaml
name: speckit-orchestrator
version: 0.1.0
type: hybrid
description: Autonomous multi-phase orchestration for spec-kit
target: all

compilation:
  exclude:
    - ".specify/orchestrator/**"

dependencies:
  - spec-kit

scripts:
  status: "bash scripts/state/derive-phase.sh"
  verify: "bash scripts/verify/check-must-haves.sh"
  scaffold: "bash scripts/lifecycle/scaffold.sh"
```

## Hydrate-Execute-Persist Adapter Contract

The gh-aw CI adapter follows a mandatory three-phase sequence for every workflow run:

1. **Hydrate** — Pull state from durable storage (repo-memory branch) into `.specify/orchestrator/` before any command or hook runs
2. **Execute** — All reads/writes target the working tree. `.specify/orchestrator/` is the canonical source of truth during execution
3. **Persist** — Commit working tree state to durable storage after execution, including after all spec-kit hooks fire

The local adapter's hydrate/persist phases are no-ops (files persist naturally).

## CI Dispatch Mode

| Adapter | Mode | Behavior |
|---------|------|----------|
| `local-sequential` | `continuous` | Drives the full state machine loop in one session |
| `local-subprocess` | `continuous` | Same, but dispatches tasks to fresh subagent contexts |
| `gh-aw-ci` | `step` | Advances one unit per scheduled workflow run; re-enters via `schedule` or `repository_dispatch` |

The `auto` command detects mode from the adapter. CI cannot drive a full milestone in one run due to timeout caps. Each CI dispatch workflow MUST include `concurrency: { job-discriminator: ${{ inputs.task_id }} }` to prevent fan-out cancellations.

## Verification Ownership Model

Replaces standalone verification ladder with spec-kit-integrated 4-tier model:

| Tier | Mechanism | When | Failure Disposition |
|------|-----------|------|-------------------|
| 1. Static | Deterministic scripts (`check-must-haves.sh`, `check-boundary-map.sh`) | Before agent (precomputation in CI, `{SCRIPT}` locally) | **Block** — phase cannot proceed |
| 2. Command | spec-kit checklists gating `/speckit.implement` | Inside agent session, at implement boundary | **Block** — implementation cannot start |
| 3. Behavioral | gh-aw staged mode (`staged: true`) | CI only, after implementation | **Escalate** — pause and surface to human |
| 4. Human | Manual review | When mechanical verification is insufficient | **Human decides** |

R-006 verification scripts are the implementation of spec-kit checklist verification (tier 2), not a parallel system. APM hooks are excluded entirely (APM withdrew this recommendation). Tiers execute in order; each tier must pass before the next runs.

## Command Design Requirements

All orchestrator commands MUST include:
- **`$ARGUMENTS` handling**: A `## User Input` section processing `$ARGUMENTS` per spec-kit convention
- **`scripts` frontmatter**: Commands invoking helper scripts declare them (`scripts: { sh: ../../scripts/state/derive-phase.sh }`) for spec-kit's path rewriting and `{SCRIPT}` placeholder substitution
- **`handoffs` frontmatter**: Declare command transitions (e.g., `auto` → `plan-phase` → `dispatch` → `verify`). Handoffs are presentation-layer for local execution; the CI adapter extracts target command names and ignores prompt/send context. Receiving commands are self-sufficient via disk state (AD-2).

## Context Injection Priority Rules

Two channels exist for injecting context into agent sessions:

1. **Ambient channel** (APM `.instructions.md`): Static, file-pattern-scoped rules. MUST NOT reference orchestrator runtime state, phase identity, or command arguments. Deployed at install time.
2. **Command-time channel** (spec-kit frontmatter/templates): Dynamic, command-specific context. Handles phase scope, dispatch payloads, verification criteria.

**Priority rule**: Command-time context overrides ambient context on conflict.

**CI merge semantics**: The adapter's `build-context.sh` merges both channels into a single dispatch payload. Command context takes precedence. Instructions MUST be committed to the repo for CI runners (not dynamically generated).

## Remaining Disputes (from Conversus)

### Disputes from Spec-Level Conversus

| # | Dispute | Plan Position | Rationale |
|---|---------|---------------|-----------|
| D1 | Skill folder directory structure | Command-centric: one root `SKILL.md` summary, not per-command files | spec-kit + gh-aw agree. APM accepted single root SKILL.md. |
| D2 | `.instructions.md` primacy | Supplementary (ambient only), not primary. Extension validation is primary. | Avoids soft APM runtime dependency. APM conceded scope. |
| D3 | Adapter interface richness | 5 core operations (Removed by arbitration — adapters MAY optimize internally but the 5-operation interface is fixed) | Satisfies all three: lean core (APM), platform-neutral (spec-kit), discoverable (gh-aw). |
| D4 | Distribution model | Committed extension is default. APM-managed supported but not canonical. | Matches spec-kit convention. |
| D5 | Spec propagation | FR-073 in spec. Detection at roadmap reassessment. | gh-aw's gap is valid and addressed. |

### Disputes from Plan-Level Conversus

| # | Dispute | Plan Position | Rationale |
|---|---------|---------------|-----------|
| PD1 | Config file placement | Project root (`orchestrator-config.yml`). Accepted deviation from spec-kit convention. | APM's always-overwrite makes `.specify/extensions/` unsafe for user config. If APM clarifies manifest-scoped overwrite, revisit. |
| PD2 | `deterministic` script annotation | Adapter config, not command frontmatter | gh-aw-specific optimization; pollutes spec-kit schema for all extensions. Adapter maintains classification list. |
| PD3 | Two-channel context merge for CI | `build-context.sh` merges ambient + command-time; command wins on conflict | All three positions compatible when priority rule is explicit. |
| PD4 | Verification tier interface | 4-tier model with ordered sequence and failure dispositions defined above | Operational spec added per spec-kit's request. |

### Arbitration Resolution (Post-Conversus)

All disputes above were resolved by a post-conversus arbitration where the speckit-orchestrator itself acted as binding arbiter, grounding all decisions in the 7 constitution principles. Full resolution at `conversus-plan/arbitration/resolution.md`.

Key rulings:
- **PD1**: Config at project root. Three-bucket model (AD-7 extended).
- **PD2**: `deterministic` annotation in `extension.yml` `provides.scripts`, not frontmatter or adapter config.
- **SC1**: Resolved by three-bucket separation — tension structurally eliminated.
- **SC5**: Manual root `SKILL.md`, no derivation system. YAGNI until APM ships the capability.
- **D3-EXT**: 5 core adapter operations. NO capability negotiation. Parallel fan-out is adapter-internal, invisible to core. FR-069 rewritten.

## Complexity Tracking

> No constitution violations detected. Table left empty per instructions.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |