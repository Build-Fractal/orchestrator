---
schema_version: "1.0"
type: context-draft
milestone: "M008"
status: finalized
created_at: "2026-04-14T00:00:00Z"
finalized_at: "2026-04-14T00:00:00Z"
---

## Architectural Decisions

### AD-01: Three-Axis Adapter Architecture

The orchestrator uses three independent adapter axes:

- **Format adapters** — translate between the orchestrator's native lightweight task format and external formats (spec-kit tasks.md/plan.md). Allows the orchestrator to consume work defined in any supported format without coupling core logic to a specific schema.
- **Runtime adapters** — bridge the orchestrator's commands and conventions to each agent runtime's native patterns (instruction files, command discovery, hook mechanisms). Each runtime adapter handles: where commands live, how project instructions are discovered, and how hooks are registered.
- **Backend adapters** — implement the dispatch interface for a specific execution mechanism. Each adapter accepts a task plan + context payload and returns a structured result + artifacts. The orchestrator core never knows which backend executed the task.

This decomposition keeps concerns orthogonal — changing how tasks are formatted doesn't affect how they're dispatched, and adding a new runtime doesn't require new dispatch backends.

### AD-02: Dispatch Interface Contract (M010 Seam)

The dispatch interface is the single most important abstraction in M008. It must be:

- **Input**: task plan (what to do) + context payload (what the agent needs to know) + intensity metadata (how much verification/knowledge to generate)
- **Output**: completion status + generated artifacts + structured errors (if any)
- **Backend-agnostic**: the orchestrator core calls the same interface regardless of whether execution happens via Claude Code Agent tool, Codex SDK, or future Managed Agents API

This is the explicit seam M010 plugs into. The interface must accommodate cloud backends (parallel workers, async results, shared filesystems) without breaking changes. Design it for the cloud case; the local case is a simplification.

### AD-03: Intensity Engine as Pipeline Gate

The adaptive intensity engine runs as a dedicated evaluation step early in the pipeline — after the developer describes their task but before any orchestration begins. It:

1. Analyzes the natural-language description for scope markers, risk signals, and complexity indicators
2. Probes the environment for available capabilities (graph DB, MCP servers, CI)
3. Produces a recommendation (Quick / Standard / Full) with reasoning
4. Presents the recommendation to the developer for accept/override

The intensity level then flows as metadata through every pipeline stage. Each stage checks the intensity and adjusts its behavior: skip entirely (Quick skips discussion), reduce depth (Standard uses on-demand research vs Full's pre-planning research), or engage fully.

Intensity is not a mode switch — it's a continuous parameter that each stage interprets independently. This allows mid-workflow override without restarting: changing intensity only affects stages that haven't run yet.

### AD-04: Fresh Context Per Dispatch Unit (Principle V)

Every dispatched task gets a fresh agent context with a purpose-built payload. The payload contains:

- The task plan (what to do, must-haves, acceptance criteria)
- Relevant project context (instruction file, file paths, key decisions)
- Intensity metadata (how much verification to perform, whether to generate knowledge artifacts)
- Nothing else — no conversation history, no prior task results, no orchestrator internals

This is the core execution discipline. Parallel dispatch of independent tasks is the default when dependency graphs allow it. The orchestrator builds the minimal sufficient context for each task and trusts the agent to execute within that scope.

Context window pressure detection is built into the dispatch layer: if a task's payload approaches context limits, the orchestrator decomposes it into smaller units rather than sending a bloated payload that degrades output quality.

### AD-05: Packaging as SKILL.md Open Standard (Tier 1 + Tier 2)

Two packaging tiers for M008:

- **Tier 1 — Skills**: Individual SKILL.md files that any supported runtime can discover and load. This is the primary distribution format. Each orchestrator command becomes a skill file.
- **Tier 2 — Plugin bundle**: An installable package that bundles all skills + hooks + configuration into a single install action. Provides the "one command install" experience.

MCP server (Tier 3) deferred to a later milestone — it adds complexity without proportional adoption value at this stage.

### AD-06: Runtime Support — Claude Code + Codex CLI + Cursor

M008 targets three runtimes:

1. **Claude Code** (all surfaces: CLI, desktop, web, IDE extensions) — primary runtime, deepest integration
2. **Codex CLI** (OpenAI) — second-class but fully functional, validates multi-runtime architecture
3. **Cursor** — third runtime, validates that the adapter layer generalizes beyond the two primary runtimes

Gemini CLI deferred — its skill/instruction conventions are less established. The adapter architecture supports adding it later without structural changes.

## Scope Boundaries

### In Scope

- Adaptive intensity engine (Quick/Standard/Full) with scope, risk, and complexity analysis
- Intensity-aware scaling of all pipeline stages (discussion, research, planning, verification, knowledge, dispatch)
- Three-axis adapter layer (format, runtime, backend) with implementations for native + spec-kit formats, Claude Code + Codex + Cursor runtimes, and local-agent + local-codex backends
- Backend-agnostic dispatch interface designed to accommodate M010 cloud backends
- Standalone state directory (`.orchestrator/`) with configurable root
- `orchestrator:*` command namespace with alias layer for migration
- SKILL.md packaging format + plugin bundle installer
- `orchestrator:init` onboarding command with project detection, capability probing, and project instruction file generation
- Spec-kit integration mode (optional, one-directional: orchestrator reads spec-kit artifacts, writes its own state)
- Context window pressure detection and automatic task decomposition
- Self-update check mechanism (detect new versions, provide update instructions)
- Backward-compatible migration path from spec-kit extension mode

### Out of Scope

- Gemini CLI runtime adapter (deferred — adapter architecture supports future addition)
- MCP server for state queries (Tier 3 packaging — deferred)
- Cloud dispatch backends (M010 — but the interface they plug into IS in scope)
- Full bidirectional spec-kit sync (one-directional read is sufficient)
- Auto-update mechanism (check + instructions, not silent auto-update)
- Rebranding / new product name (temporary "orchestrator" name continues)
- Claude Cowork integration (different audience)

## Design Constraints

### DC-01: Bash 3.2+ / POSIX sh Compatibility

Maintain Bash 3.2+ compatibility. Rationale: macOS ships Bash 3.2 by default, and many developers don't install newer versions. Going standalone means we can't assume any toolchain beyond what the OS provides. This constrains the adapter and intensity engine implementations (no associative arrays, no `readarray`, no `|&`).

### DC-02: File-Based State, No Daemons

All state and configuration must be file-based and version-controllable. No daemon processes, no databases, no network services required for core operation. This is Principle VI (State On Disk Is Truth) extended to the standalone context.

### DC-03: Zero Runtime Dependencies on Spec-Kit

Spec-kit is optional, never required. Every code path must work without spec-kit present. The spec-kit format adapter is loaded only when spec-kit artifacts are detected and integration mode is enabled.

### DC-04: Dispatch Interface Must Be Cloud-Ready

The dispatch adapter interface must accept "task plan + payload" and return "result + artifacts" without any assumption about local execution. Specifically:
- No assumption that the agent has filesystem access during execution (cloud agents use container filesystems)
- No assumption about synchronous completion (cloud dispatch may be async with polling)
- No assumption about single-threaded execution (cloud dispatch may run parallel workers)

Design for the hardest case (cloud/async/parallel); local dispatch is a simplification that happens to complete synchronously on a shared filesystem.

### DC-05: Quality Over Speed

This milestone prioritizes output quality and user experience over time-to-build. Specifically:
- The intensity engine should err toward recommending more ceremony when uncertain, not less
- Research and planning phases should be thorough at Standard and Full intensity — extra context gathering pays for itself in execution quality
- Context window utilization should be monitored and managed — better to decompose a task than to send a bloated context that produces worse output
- Parallel subagent dispatch is preferred wherever dependency graphs allow — fresh contexts with focused payloads produce better results than sequential execution in an accumulating context

### DC-06: Adoption-Friendly Design

Every design decision should reduce friction for new users:
- Sensible defaults that work out of the box (no required configuration beyond init)
- Progressive disclosure: Quick mode is simple, Standard adds ceremony gradually, Full is comprehensive
- Clear error messages that explain what went wrong and what to do next
- The onboarding flow must produce a working setup in under 2 minutes

### DC-07: Constitution Alignment

All design and execution must align with the governing constitution (v2.1.0), particularly:
- **I (Context Minimization)**: Dispatch payloads contain the minimum context needed, never more
- **IV (Plans Assume Zero Context)**: Every task plan is self-contained, executable by an agent with no prior conversation
- **V (Fresh Context Per Unit)**: Every dispatch creates a new agent context
- **VI (State On Disk Is Truth)**: No in-memory state that isn't also on disk
- **VII (Knowledge Compounds)**: Intensity levels control how much knowledge is generated, but knowledge is always captured at every level
- **XIV (No Speculative Complexity)**: Don't build flexibility that wasn't asked for
- **XV (Surgical Precision)**: Every change traces to a requirement

## Open Questions

### OQ-01: Intensity Signal Weighting (Resolved: Research During P01)

How should the intensity engine weight different signals? Options:
- Scope-dominant: scope is primary, risk is a modifier that can only increase intensity
- Balanced: scope and risk contribute equally
- Risk-dominant: risk signals override scope (a one-line change to auth code gets Full intensity)

**Resolution approach**: Research during P01 with examples from the existing codebase. The M007 knowledge graph may provide historical data on which tasks benefited most from higher intensity. Lean toward scope-dominant with risk as an escalation signal — this matches developer intuition (small task = small ceremony) while catching high-risk edge cases.

### OQ-02: Cursor Adapter Depth (Resolved: Best-Effort)

Cursor's extension/rule system differs significantly from Claude Code's command model and Codex's AGENTS.md convention. How deep does the Cursor adapter go?

**Resolution**: Best-effort adapter that maps orchestrator commands to Cursor's rule files. If Cursor's conventions evolve during M008, the adapter can be updated without affecting the core architecture. Cursor is the "third runtime proves generalization" case, not a primary target.

### OQ-03: Context Window Pressure Thresholds (Resolved: Research During P01)

At what context utilization percentage should the orchestrator intervene (decompose tasks, trim payloads)?

**Resolution approach**: Research during P01. Initial hypothesis: warn at 60% utilization, decompose at 75%, refuse to dispatch above 85%. These thresholds should be configurable and intensity-aware (Quick mode has tighter thresholds to stay fast, Full mode can use more context for richer payloads).
