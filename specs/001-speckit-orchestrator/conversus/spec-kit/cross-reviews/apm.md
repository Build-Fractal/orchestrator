# Cross-Review of APM's UTILIZATION.md

**Reviewer**: spec-kit (the SDD framework the orchestrator extends)
**Reviewing**: APM's utilization review of spec `001-speckit-orchestrator`
**Date**: 2026-03-18

---

## 1. Dangerous Contradictions

### 1.1 Skill Folder Architecture: APM's Endorsement vs. spec-kit's Extension Model

APM's review validates the spec's skill folder architecture at face value, calling the structure "structurally compatible with APM's skill integration pipeline" (APM Section 2, alignment point on FR-028) and recommending that each skill folder map to APM's skill integration contract with `SKILL.md` frontmatter, bundled resources, and agentskills.io naming validation (APM Recommendation 2). APM then asks the spec to go further: ship `.instructions.md` files, context primitives, hook JSON files, and compilation targets (Recommendations 5, 6, 7, 8) -- all APM-native packaging artifacts layered on top of the skill folder model.

**The conflict**: spec-kit's review identifies the skill folder concept as fundamentally orthogonal to the extension system (spec-kit Section 4, Off-Base Assumption on FR-028). Spec-kit extensions package commands as individual markdown files in a `commands/` directory, with scripts in `scripts/`, templates in `templates/`, and configuration via the extension config system. There is no "skill folder" primitive in spec-kit's extension model. The trigger-phrased `SKILL.md`, progressive-disclosure gotchas sections, and self-contained folder-per-command structure are APM/GSD-2 patterns, not spec-kit patterns. Spec-kit's Recommendation 7 explicitly asks the spec to *eliminate* the parallel skill folder abstraction and map directly onto spec-kit's own extension primitives: command descriptions become `description` fields, helper scripts go in `scripts/`, templates participate in the resolution stack, and references go in `docs/`.

**Why this is dangerous**: APM's recommendations assume the skill folder architecture is settled and build additional APM packaging infrastructure on top of it. If the spec follows APM's guidance and defines `apm.yml` manifests, skill naming validation, context primitives, and instruction files all organized around skill folders, it will cement a packaging model that is structurally incompatible with spec-kit's extension system. The orchestrator would then have *two* conflicting organizational models: APM skill folders for distribution and spec-kit extension directories for runtime. Artifacts would need to exist in both structures or be translated between them. This is not a theoretical concern -- APM's Recommendation 2 explicitly asks the spec to "map each skill folder to APM's skill integration contract," which would formalize the skill folder as the canonical structure and relegate spec-kit's extension model to an afterthought.

**Spec-kit's position**: The extension model is the canonical structure. The orchestrator is first and foremost a spec-kit extension. APM packaging is a distribution concern (P8, the lowest priority user story). The skill folder structure must be reconciled with spec-kit's extension primitives *first*, and then APM packaging can wrap whatever structure results. APM should deploy what the extension system produces, not define a parallel structure that the extension system must conform to.

---

### 1.2 Configuration Ownership: APM's Always-Overwrite vs. spec-kit's Multi-Layer Config

APM's review correctly identifies that `config.json` inside a skill folder will be overwritten on `apm install` due to APM's always-overwrite policy for package-owned files (APM Section 4, Off-Base Assumption on `config.json`). APM recommends separating user configuration from skill-folder configuration (APM Recommendation 3), placing active config at `.specify/orchestrator/config.json` and treating skill folder `config.json` as a defaults template.

**The conflict**: Spec-kit's review also flags the configuration approach as problematic, but for a different reason and with a different solution (spec-kit Section 3, Missed Opportunity on configuration management). Spec-kit has a complete multi-layer configuration infrastructure already built: extension defaults in `extension.yml`, project config (`orchestrator-config.yml`), local overrides (`orchestrator-config.local.yml`, gitignored), and environment variable overrides (`SPECKIT_ORCHESTRATOR_*`). Spec-kit's Recommendation 1 asks the spec to use this existing system. APM's recommendation creates a *third* configuration path -- a `.specify/orchestrator/config.json` file that is neither APM-managed (it is outside the skill folder) nor spec-kit-managed (it does not use the extension config system).

**Why this is dangerous**: If both recommendations are followed, the orchestrator ends up with three configuration sources: APM skill folder `config.json` (defaults template, overwritten on install), spec-kit's multi-layer config system (extension defaults, project config, local overrides, env vars), and APM's proposed `.specify/orchestrator/config.json` (active user config). The spec already defines FR-040 (first-run config) and FR-041 (per-invocation overrides), which map naturally to spec-kit's config layers. Adding a freestanding JSON file in the orchestrator state tree creates ambiguity about which config source wins and fragments the configuration surface across three systems.

**Spec-kit's position**: Configuration must flow through spec-kit's extension config system. This is the only system that provides the multi-layer precedence, local overrides (gitignored for developer preferences), and environment variable support that FR-040 and FR-041 require. APM's skill folder `config.json` can serve as the source for `defaults` in `extension.yml`, but user-facing configuration lives in spec-kit's config infrastructure, not in a standalone JSON file.

---

### 1.3 Hook Distribution: APM's Cross-Agent Hook JSON vs. spec-kit's Hook Registration

APM's review recommends packaging orchestrator hooks as APM hook JSON files under `.apm/hooks/` so that `apm install` deploys them to `.github/hooks/`, `.claude/settings.json`, and `.cursor/hooks.json` automatically (APM Recommendation 5). APM frames this as a missed opportunity for "cross-agent hook deployment."

**The conflict**: The spec's hooks are spec-kit extension hooks, registered via `extension.yml` and executed by spec-kit's hook system at four defined lifecycle points (FR-031, spec lines 263, 475). Spec-kit's hook execution model works through `.specify/extensions.yml` and the command template parsing that reads `hooks.before_tasks`, `hooks.after_tasks`, etc. The hooks are Markdown command invocations within spec-kit's own lifecycle, not IDE-level event handlers. APM's hook integration system deploys JSON files that trigger on IDE-level events (file save, pre-commit, etc.) -- a fundamentally different hook surface. Deploying the orchestrator's lifecycle hooks through APM's hook system would bypass spec-kit's extension registration entirely and create a parallel hook execution path that the spec-kit framework does not control or coordinate.

**Why this is dangerous**: Spec-kit's own review raises concerns about the `before_tasks` and `before_implement` hooks, noting a discrepancy between what the API reference documents as standard events and what the command templates actually parse (spec-kit Section 4, Off-Base Assumption on hook points). The hook registration path matters -- it determines validation, execution order, and conditional activation. If APM deploys hooks through its own JSON system alongside spec-kit's extension hook registration, the orchestrator would have hooks firing from two different systems with no coordination. A hook registered in `extension.yml` and also deployed as an APM hook JSON would execute twice, or the two instances might have different conditional logic, or one might be validated while the other is not.

**Spec-kit's position**: Orchestrator hooks are spec-kit extension hooks. They are registered in `extension.yml`, validated by the extension system, and executed by spec-kit's command templates. APM has no role in hook deployment for a spec-kit extension. If the orchestrator additionally wants to provide IDE-level hooks (e.g., a pre-commit check for scope enforcement), those are a separate concern from the SDD lifecycle hooks and should be explicitly designed as such, not conflated with the four extension lifecycle hooks.

---

### 1.4 Constitution Injection: APM Compile vs. Spec-Kit's Own Constitution Authority

APM's review recommends leveraging APM's constitution injection into `AGENTS.md` during compilation -- "hash-verified, idempotent, drift-aware" -- to ensure the orchestrator's constitution is always present in compiled instruction files (APM Section 3, Missed Opportunity on `apm compile`). APM frames this as replacing "manual management" of the constitution file at `.specify/memory/constitution.md`.

**The conflict**: The spec explicitly places the constitution at `.specify/memory/constitution.md` (Assumptions, spec line 466) and states it "governs all orchestrator behavior." Spec-kit's own `analyze` command treats the constitution as the highest authority for cross-artifact consistency analysis (referenced in spec-kit's documentation table: `templates/commands/analyze.md` -- "constitution authority"). The constitution's location and management are a spec-kit concern: it lives in spec-kit's `.specify/` state tree, is read by spec-kit commands, and governs spec-kit's SDD workflow.

**Why this is dangerous**: APM's constitution injection compiles the constitution into `AGENTS.md` or `CLAUDE.md` as part of `apm compile`. This means the constitution's authoritative representation would shift from spec-kit's `.specify/memory/constitution.md` (read directly by spec-kit commands and the orchestrator at runtime) to APM's compiled output (a derived artifact). If `apm compile` produces a stale or incorrectly merged version of the constitution, the compiled agents file would contain a different constitution than what spec-kit reads from `.specify/memory/`. The spec's Principle 6 -- "State On Disk Is Truth" -- means the `.specify/memory/constitution.md` file is the source of truth, not a compiled derivative. APM's injection would create a second source of truth for the constitution that drifts from the first.

**Spec-kit's position**: The constitution lives in `.specify/memory/constitution.md` and is read directly by spec-kit commands and the orchestrator. It is not a compile-time artifact. If APM wants to surface the constitution to agents that only read `AGENTS.md`, that is an APM concern for APM-only workflows, but it must not become the authoritative path for the orchestrator's constitution management.

---

## 2. Tensions

### 2.1 Distribution Channel Priority: APM Package vs. spec-kit Community Catalog

APM's entire review is oriented around making the orchestrator a first-class APM package: `apm.yml` manifest (Recommendation 1), `apm pack` for CI (Recommendation 4), version pinning and lockfile strategy (Recommendation 9), and compilation target strategy (Recommendation 8). Spec-kit's review recommends community catalog submission via `catalog.community.json` (spec-kit Recommendation 10) and the `.extensionignore` file for clean distribution (spec-kit Section 3).

**The tension**: These are not incompatible -- the orchestrator can be distributed through both channels. But they create priority tension. APM's recommendations would have the spec define `apm.yml`, compilation targets, bundle strategies, and lockfile semantics as spec deliverables. Spec-kit's recommendations would have the spec focus on extension packaging (`.extensionignore`, `requires.commands`, `config_schema`, catalog listing). The spec assigns APM packaging as P8 (lowest priority) and manual spec-kit extension install as the fallback (FR-036). If the implementation plan front-loads APM packaging concerns, it diverts effort from the core extension infrastructure.

**Resolution path**: The spec should sequence these explicitly. First, the orchestrator is a correct spec-kit extension (manifest, commands, hooks, config, templates). Second, it is listed in the community catalog. Third, it is wrapped as an APM package. APM packaging adds distribution reach but should not shape the extension's internal structure. `apm.yml` can be defined as a deliverable without making APM's packaging constraints (skill naming validation, compilation targets, bundle formats) into functional requirements.

---

### 2.2 Template and Artifact Ownership: APM Context Primitives vs. spec-kit Template Resolution Stack

APM recommends packaging knowledge artifacts (KNOWLEDGE.md, DECISIONS.md, phase summaries) as `.context.md` files for APM's context linking system (APM Recommendation 6) and shipping `.instructions.md` files with `applyTo` patterns for orchestrator state files (APM Recommendation 7). Spec-kit recommends registering output templates as extension templates in the resolution stack (spec-kit Recommendation 3) and providing a companion preset for template overrides (spec-kit Recommendation 2).

**The tension**: Both systems want to own how the orchestrator's templates and artifacts are discovered, loaded, and customized. APM's context linking resolves markdown links during install/compile. Spec-kit's template resolution stack resolves templates at command execution time with a defined precedence (presets > extensions > core). If the orchestrator's roadmap template is both an APM context primitive (resolved by `apm compile`) and a spec-kit extension template (resolved by the template stack), the two resolution systems could produce different results or load different versions of the same template.

**Resolution path**: Separate the concerns by artifact type. *Output templates* (roadmap, phase plan, task summary formats) are spec-kit extension templates -- they participate in the resolution stack and are overridable by presets. *Distribution packaging* (how the extension is installed, what files are deployed where) is APM's domain. APM's context primitives and instruction files are useful for projects that use APM but do not use spec-kit -- but the orchestrator is a spec-kit extension by definition, so its templates should go through spec-kit's system first and APM can wrap whatever the extension provides.

---

### 2.3 Install vs. Compile Distinction for Orchestrator Artifacts

APM's review notes that the spec does not distinguish between install-time and compile-time artifacts (APM Section 4, Off-Base Assumption on `apm install` vs. `apm compile`). APM recommends the spec define which deliverables are install-time (skills, hooks deployed to IDE directories) and which are compile-time (instructions merged into AGENTS.md). APM's Recommendation 8 asks the spec to define a compilation target strategy.

**The tension**: Spec-kit's extension system does not have this install/compile distinction. Extensions are installed via `specify extension add`, which copies the extension to `.specify/extensions/{ext-id}/` and registers it. There is no separate "compile" step that merges extension content into a monolithic instruction file. Spec-kit commands read extension configuration and templates at execution time. APM's install/compile model is a packaging concern that does not map onto spec-kit's extension lifecycle.

**Resolution path**: Acknowledge that the install/compile distinction is APM-specific and define it only in the APM packaging layer, not in the core extension architecture. The extension's functional requirements (FR-028 through FR-032) should describe what the extension provides and how it integrates with spec-kit. A separate APM packaging section (under US8) can specify which of those artifacts are install-time vs. compile-time in APM's model, without contaminating the extension's own design.

---

### 2.4 `apm pack` for CI vs. spec-kit Extension as Sufficient for GitHub Agentic Workflows

APM recommends `apm pack --archive` as the mechanism for CI artifact distribution in US7 (APM Recommendation 4), arguing that sandboxed gh-aw runners need self-contained bundles. The spec's US7 describes GitHub Agentic Workflows that read project state from the repository and execute phases.

**The tension**: If the orchestrator is a spec-kit extension already installed in the repository (files committed to `.specify/extensions/orchestrator/`), it is already available in CI without APM bundling. The spec-kit extension files are checked into the repo and cloned by the CI runner. `apm pack` adds value only if the extension is NOT committed to the repo and must be installed at CI time from an external source. The spec does not specify whether the extension is committed or externally managed.

**Resolution path**: The spec should state explicitly whether the extension files are committed to the repository (most spec-kit extensions are) or installed from an external package at runtime. If committed, `apm pack` is unnecessary for CI -- the files are already there. If externally managed, then either `apm install` at CI time or `apm pack` for offline environments is needed. This is a deployment model decision that should be made in the spec, not assumed by either reviewer.

---

### 2.5 MCP Server Exposure vs. Disk-Only State Principle

APM suggests the orchestrator could benefit from MCP server integration for state querying, progress dashboards, or external verification (APM Section 3, Missed Opportunity on MCP servers). Spec-kit's alignment notes emphasize the "state on disk is truth" principle (spec-kit Section 2, alignment point on FR-019/FR-020) and the spec's constraint that no in-memory state may survive across sessions (spec line 477).

**The tension**: An MCP server is a running process that exposes tools via a protocol. If the orchestrator's state is queried through an MCP server rather than by reading files from disk, it introduces a live process as an intermediary between the agent and the state. The MCP server would need to read from disk and serve the results, but it also introduces a process that could have stale state, crash independently, or provide a different view than what the files show. This does not violate the disk-only principle if the MCP server is purely a read-through layer, but it adds operational complexity that the spec's design philosophy deliberately avoids.

**Resolution path**: If an MCP tool is useful (e.g., `orchestrator-status` as an MCP tool for quick queries from any agent), it should be explicitly stateless -- every call reads from disk with no caching. And it should be optional, not required. The spec's FR-038 and FR-039 already require progress overview to be derivable entirely from disk state, so the MCP server would be a convenience wrapper, not a new capability.

---

## 3. Safe Agreements

### 3.1 APM Is Not a Runtime Dependency

Both reviews agree that the spec correctly positions APM as a distribution mechanism, not a runtime dependency. APM's review praises FR-033 and FR-036 (APM Section 2, first alignment point). Spec-kit's review does not raise APM runtime coupling as a concern because the spec is clear about it. The graceful degradation path (manual install via `specify extension add` when APM is absent) is sound and both reviewers endorse it.

---

### 3.2 Multi-Agent Compatibility Without Agent-Specific Code Paths

Both reviews validate FR-032's requirement that the orchestrator work across all spec-kit-supported agents without agent-specific code paths. APM notes this aligns with its multi-target deployment model (APM Section 2, alignment point on FR-032). Spec-kit notes this aligns with its universal command format and CommandRegistrar system (spec-kit Section 2, alignment point on FR-032). The spec's design here satisfies both systems' requirements.

---

### 3.3 Separate State Tree at `.specify/orchestrator/`

Both reviews endorse the spec's decision to place orchestrator state in a separate tree from spec-kit's `specs/` directory (FR-019). APM does not raise concerns about this path. Spec-kit explicitly validates it as following existing convention (spec-kit Section 2, alignment point on FR-019). This separation cleanly delineates spec artifacts (owned by spec-kit) from orchestrator state (owned by the extension) and prevents either system's state management from interfering with the other.

---

### 3.4 Disk-Based State Machine and File-Presence Triggers

Both reviews endorse the file-presence-based state machine (FR-020) and the "state on disk is truth" principle. APM does not challenge this design. Spec-kit explicitly validates it as architecturally consistent with how spec-kit derives status from file existence (spec-kit Section 2, alignment point on disk-only state). This is a foundational agreement -- both systems operate on the same principle that the filesystem is the authoritative state store.
