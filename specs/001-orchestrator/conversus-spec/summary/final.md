# Conversus Final Summary: speckit-orchestrator Spec Review

**Date**: 2026-03-19
**Spec**: `specs/001-orchestrator/spec.md`
**Process**: 3 tool perspectives (APM, spec-kit, gh-aw) x 3 iterations

---

## Process

| Artifact Type | Count |
|---|---|
| Tool perspectives | 3 (APM, spec-kit, gh-aw) |
| Initial UTILIZATION reviews | 3 |
| Cross-reviews (tool-on-tool) | 6 |
| Iteration 1 revised positions | 3 |
| Dispute documents (iteration 3) | 3 |
| **Total artifacts produced** | **15** |

Each initial review contained 5 sections (Executive Summary, Alignment, Missed Opportunities, Off-Base Assumptions, Actionable Recommendations). APM produced 9 recommendations, spec-kit produced 10, gh-aw produced 10. Cross-reviews identified dangerous contradictions, tensions, and safe agreements. Iteration 1 revisions included disposition of every recommendation (surviving, modified, withdrawn) plus new recommendations. Dispute documents captured the 4 unresolved disagreements per tool after convergence.

---

## Recommendation Scorecard

| Tool | Original Recs | Withdrawn | Modified | Surviving | New (Iter 1) |
|---|---|---|---|---|---|
| **APM** | 9 | 1 (Rec 4: `apm pack` for CI) | 5 (Recs 2, 3, 5, 6, 8) | 3 (Recs 1, 7, 9) | 3 (A: dual-entry layout, B: deployment boundary, C: dispatch interface) |
| **spec-kit** | 10 | 1 (Rec 2: companion preset) | 4 (Recs 1, 3, 7, 10) | 5 (Recs 4, 5, 6, 8, 9) | 4 (A: config/state boundary, B: runtime adapter, C: non-interference constraint, D: committed vs. external) |
| **gh-aw** | 10 | 1 (Rec 5: create-agent-session) | 7 (Recs 1, 2, 3, 4, 6, 7, 8, 9) | 1 (Rec 10: SpecOps) | 3 (A: runtime adapter interface, B: co-specify US-7/US-8, C: config/state separation) |
| **Totals** | **29** | **3** | **16** | **9** | **10** |

gh-aw underwent the most revision -- 7 of 10 original recommendations were modified, almost entirely in the direction of converting gh-aw-specific primitives into runtime adapter implementations of portable abstractions.

---

## Dangerous Contradictions Found

Across the 6 cross-reviews, **16 dangerous contradictions** were identified and categorized:

### By Category

| Category | Count | Examples |
|---|---|---|
| **Runtime coupling / platform lock-in** | 5 | CI-first architecture (gh-aw) vs. runtime-agnostic (APM, spec-kit); `create-agent-session` hardcoding Copilot; `dispatch-workflow` as core primitive; GitHub sub-issues as work hierarchy; repo-memory as primary state |
| **Architectural ownership / organizational model** | 4 | Skill folder elimination (spec-kit) vs. preservation (APM, gh-aw); template resolution stack vs. APM compilation targets; community catalog vs. APM as primary distribution; constitution injection (APM) vs. spec-kit authority |
| **Configuration / state management conflicts** | 4 | APM always-overwrite vs. spec-kit multi-layer config; config.json placement across three systems; repo-memory vs. disk state; skill folder config.json overwrite breaking CI continuity |
| **Hook system conflicts** | 2 | APM hook JSON bypassing spec-kit extension hooks; APM IDE hooks absent in CI execution |
| **CI distribution model conflicts** | 1 | `apm pack` bundles vs. gh-aw native dependency resolution |

### By Cross-Review Pair

| Reviewer | Reviewed | Contradictions |
|---|---|---|
| APM | spec-kit | 4 (skill folders, config ownership, catalog vs. APM distribution, template ownership) |
| APM | gh-aw | 4 (CI-first vs. runtime-agnostic, lock files vs. concurrency groups, repo-memory vs. disk state, Copilot lock-in) |
| spec-kit | APM | 4 (skill folder endorsement, config paths, hook distribution, constitution injection) |
| spec-kit | gh-aw | 4 (CI as primary runtime, repo-memory eliminates inspectability, sub-issues platform coupling, dispatch-workflow eliminates portability) |
| gh-aw | APM | 4 (APM hooks bypass deterministic-agentic pattern, compile-time constitution vs. runtime state, `apm pack` vs. native resolution, config overwrite in CI) |
| gh-aw | spec-kit | 4 (command wrapping vs. CI dispatch, preset templates vs. dispatch isolation, extension config vs. repo-memory, skill folder dissolution vs. payload contract) |

---

## Systemic Contradictions

Five architectural tensions cut across all three tools and recurred throughout the process:

### 1. Install-Time vs. Runtime Artifact Ownership

APM solves problems at install time (compiled instructions, deployed hooks, pre-packed bundles). gh-aw solves problems at runtime (dynamic dispatch, repo-memory, workflow-level verification). spec-kit operates at command execution time (template resolution, hook firing, config loading). Each tool naturally gravitates toward making its lifecycle phase the primary solution surface. This produced repeated clashes where one tool's install-time solution broke another tool's runtime expectations (APM's compiled constitution going stale, APM's always-overwrite destroying runtime config, gh-aw's repo-memory being invisible to APM's file discovery).

### 2. Platform-Native Optimization vs. Runtime Portability

gh-aw's strongest features (dispatch-workflow, call-workflow, concurrency groups, sub-issues, repo-memory) are GitHub Actions-native. Using them makes CI orchestration robust but couples the architecture to one platform. The spec requires support for 17+ agents across multiple runtimes. Every gh-aw recommendation was modified to become an adapter implementation rather than a core primitive. The tension remains in the adapter interface design: how rich can the interface be before it implicitly assumes CI-grade capabilities?

### 3. Organizational Model Primacy

Three systems need to "read" the orchestrator's directory tree: spec-kit (commands, scripts, templates), APM (skill folders with SKILL.md), and gh-aw (dispatch payload units). Each system's natural directory layout is different. The skill folder debate consumed more cross-review energy than any other single topic. spec-kit asserts the extension model is canonical; APM asserts the skill folder is the shared unit; gh-aw argues the dispatch payload is what matters and both physical structures are secondary.

### 4. State Persistence Across Execution Contexts

The orchestrator must work identically in local sessions (files persist naturally) and CI (working tree is ephemeral). The spec's "State On Disk Is Truth" principle is universally accepted, but CI requires an additional persistence layer. gh-aw's repo-memory was rejected as primary storage but remains necessary for CI crash recovery. The adapter interface's persistence contract is agreed upon in principle but underspecified in practice.

### 5. Configuration Authority Fragmentation

Three systems have configuration infrastructure: spec-kit's multi-layer config, APM's deployment and compilation pipeline, and gh-aw's workflow inputs and repo-memory. A naive integration produces three config sources with unclear precedence. The resolution (static config in spec-kit's system, dynamic state in `.specify/orchestrator/`, APM-deployed files as immutable defaults) is agreed upon but adds a documentation and cognitive burden the spec does not yet address.

---

## Convergence Achieved

After the full process (initial reviews, cross-reviews, iteration 1, disputes), all three tools agree on these positions:

### 1. Disk state at `.specify/orchestrator/` is the sole source of truth

All external representations (GitHub sub-issues, GitHub Projects boards, repo-memory branches) are read-only projections of disk state, never authoritative sources. gh-aw conceded repo-memory as primary storage. APM conceded that runtime-generated knowledge artifacts cannot be context-linked at install time.

### 2. The orchestrator is a spec-kit extension first

APM's revised stance: "The orchestrator is a spec-kit extension that APM distributes. Not an APM package that happens to run in spec-kit." gh-aw's revised stance: "The orchestrator's core architecture must be runtime-agnostic." The extension model is the canonical organizational structure; APM packaging and gh-aw CI integration wrap it.

### 3. A runtime adapter interface is architecturally necessary

All three tools independently converged on a pluggable adapter layer. The orchestrator's core logic programs against abstract operations (dispatch, verify, persist, recover). Runtime-specific adapters (gh-aw for CI, local subprocess for development, future adapters for new runtimes) implement those operations using platform-native primitives.

### 4. Static configuration and dynamic runtime state must be explicitly separated

Static config (tier defaults, verification commands, context verbosity) flows through spec-kit's multi-layer config system. Dynamic state (current phase, execution log, decisions register, knowledge file) lives exclusively in `.specify/orchestrator/`. No configuration changes during orchestration. No runtime state is stored in configuration files.

### 5. The orchestrator MUST NOT override or replace core spec-kit commands

New `speckit.orchestrator.*` commands delegate to standard spec-kit workflows with injected context. Preset-based command replacement is prohibited. All three tools endorse this constraint without reservation.

### 6. `create-agent-session` / `assign-to-agent` must not be hardcoded as the dispatch mechanism

gh-aw withdrew this recommendation entirely. The orchestrator dispatches to whatever agent the consumer has configured. Copilot-specific primitives may be used as internal adapter implementation details, never as spec prescriptions.

### 7. Verification must be mechanical, runtime-agnostic, and protocol-defined

The verification protocol (what checks run, what constitutes passing, how results are recorded) is defined once. The execution mechanism varies by runtime (spec-kit hooks locally, workflow steps in CI). The verification ladder (static, command, behavioral, human) is accepted by all three tools.

### 8. APM is not a runtime dependency

APM's role ends at install time. The orchestrator runs as a spec-kit extension using spec-kit's command execution model. `apm install` deploys artifacts; the orchestrator never invokes APM at runtime. Graceful degradation via `specify extension add` works when APM is absent.

---

## Remaining Disputes

### Dispute 1: Skill Folder Directory Structure

**APM**: The skill folder is a "shared architectural unit" that all three systems index into as equals. A `skills/` directory parallels `commands/` with `SKILL.md` files. No single system's organizational preferences dominate.

**spec-kit**: The extension model is canonical. `SKILL.md` files are APM distribution metadata that belong *inside* the command's resource directory (e.g., `commands/orchestrate-auto/SKILL.md`), not in a parallel `skills/` tree. One hierarchy, two readers.

**gh-aw**: The dual-entry-point model adds maintenance burden. `SKILL.md` duplicates metadata from command frontmatter and `extension.yml`. APM should derive skill metadata from command frontmatter at install time rather than requiring a permanent parallel file.

**Status**: Three incompatible positions. spec-kit and gh-aw both resist a parallel `skills/` directory but for different reasons (spec-kit wants extension primacy; gh-aw wants no duplication). APM insists on a `SKILL.md` as a required packaging artifact.

### Dispute 2: `.instructions.md` as Primary vs. Supplementary Agent Guidance

**APM**: `.instructions.md` files with `applyTo` patterns are APM's distinctive capability for file-editing-time agent guidance. They fill a gap spec-kit's template system cannot address (no spec-kit command is running when an agent directly edits a state file).

**spec-kit**: Format validation and documentation for state files is an extension responsibility, delivered through command-level validation and extension docs. APM `.instructions.md` may provide supplementary guidance but must not be framed as the primary mechanism, as that creates a soft APM runtime dependency.

**Status**: Agreement on the capability's value, disagreement on primacy. APM says "primary mechanism for a real gap"; spec-kit says "supplementary convenience, not primary for a core concern."

### Dispute 3: Runtime Adapter Interface Richness

**gh-aw**: The interface must support capability tiers -- a required base tier (single dispatch, completion, result collection) and an optional enhanced tier (batch dispatch, concurrency control, typed validation, progress reporting). Without batch dispatch and concurrency hints, the CI adapter cannot express parallel task fan-out through the interface.

**APM**: The interface should have a lean core contract (three operations: dispatch, signal, collect) with optional capabilities that adapters declare support for. Capability-negotiation pattern, not gh-aw-shaped.

**spec-kit**: The interface should define five platform-neutral operations (dispatch-task, await-completion, collect-result, signal-failure, inject-context). Platform-specific capabilities belong in adapter configuration, not in the interface contract.

**Status**: All agree on the pattern (core + optional). Disagree on how much is core, how much is optional, and whether batch dispatch / concurrency are interface-level or adapter-internal concerns.

### Dispute 4: Distribution Model (APM-Managed vs. Committed Extension)

**APM**: Both models (APM-managed with `.gitignore` and committed-to-repo) should be supported. Neither should be declared canonical. APM's lifecycle management (lockfile, version pinning, upgrade diffing) provides real value beyond initial setup.

**spec-kit**: The extension should be committed to the repository per spec-kit convention. APM serves team onboarding and initial setup. US-7 and US-8 remain separate deliverables with sequential dependency, not a joint deliverable.

**gh-aw**: US-7 (CI execution) and US-8 (APM packaging) should be co-specified as a joint deliverable since CI execution depends on APM packaging.

**Status**: Three different positions on delivery model. spec-kit wants committed + sequential delivery. APM wants dual-model support. gh-aw wants joint delivery of US-7 and US-8.

### Dispute 5: Specification Propagation

**gh-aw**: The spec has no mechanism for handling upstream changes that invalidate downstream plans. When phase 2's boundary map reveals phase 3's plan is invalid, the orchestrator silently operates on stale plans. This must be a functional requirement.

**APM**: Silent -- neither endorsed nor disputed.

**spec-kit**: Silent -- neither endorsed nor disputed.

**Status**: gh-aw identifies a genuine gap. The other two tools have not responded. The specific mechanism (SpecOps, local re-planning, stale-plan detection) is negotiable, but the requirement itself has not been acknowledged.

---

## Actionable Spec Changes

Prioritized by convergence strength (unanimous agreement first, then majority, then single-tool-identified gaps).

### P1: Unanimous Convergence (implement immediately)

**1. Add FR: Runtime Adapter Interface**
Add a functional requirement defining a runtime adapter interface with abstract operations: dispatch-task, await-completion, collect-result, signal-failure, inject-context. Specify that the orchestrator's core logic programs against this interface. Define that runtime adapters (local, gh-aw CI, future) implement these operations using platform-native primitives. Include a capability-negotiation mechanism for optional enhanced operations (batch dispatch, concurrency control, progress projection). Reference: all three tools' New Recommendations (APM-C, spec-kit-B, gh-aw-A).

**2. Add Constraint: "The orchestrator MUST NOT override or replace core spec-kit commands via presets"**
Add this to the Constraints section alongside existing architectural constraints. The command composition mechanism is explicitly option (a): new `speckit.orchestrator.*` commands that delegate to standard spec-kit workflows with injected context. Reference: APM cross-review Section 2.2, spec-kit Rec 8, gh-aw iteration 1 acceptance.

**3. Add Architecture Section: Static Configuration vs. Dynamic Runtime State**
Add an explicit boundary table mapping each config/state item to its category and location. Static config (tier defaults, verification commands, context verbosity, git isolation, dispatch budget, duration budget) in spec-kit's multi-layer config system. Dynamic state (current phase, execution log, decisions register, knowledge file, lock files, phase summaries) exclusively in `.specify/orchestrator/`. Add the rule: "No configuration setting changes during orchestration execution. No runtime state is stored in configuration files." Reference: APM revised Rec 3, spec-kit New Rec A, gh-aw New Rec C.

**4. Add Constraint: "All state management, dispatch, and verification abstractions MUST be implementable in both local and CI execution contexts without forking the core logic"**
This is the CI compatibility design constraint that replaces gh-aw's original request to elevate US-7 priority. It ensures CI-awareness from the start without promoting any specific CI platform. Reference: spec-kit Tension 2.3 resolution, gh-aw revised Rec 8.

**5. Revise FR-040/FR-041: Route configuration through spec-kit's multi-layer config system**
Replace the custom `config.json` approach with: `extension.yml` defaults section for factory defaults, `orchestrator-config.yml` at project root for project overrides (outside APM deployment radius), `orchestrator-config.local.yml` (gitignored) for developer preferences, `SPECKIT_ORCHESTRATOR_*` env vars for CI/per-run overrides. Add explicit constraint: "User-mutable configuration MUST NOT reside in APM-managed directories." Reference: spec-kit Rec 1 (revised), APM Rec 3 (revised).

### P2: Strong Majority / Important Gaps

**6. Add NFR: Deployment Directory Boundary**
Add a non-functional requirement or architecture constraint: `.specify/extensions/orchestrator/` is the APM/extension deployment target (overwritten on install). `.specify/orchestrator/` is the runtime state directory (never touched by APM). No APM primitive may target paths under `.specify/orchestrator/`. No runtime operation may modify files under `.specify/extensions/orchestrator/`. Reference: APM New Rec B, cross-review convergence.

**7. Add `requires.commands` to extension manifest**
Declare `requires.commands` listing `speckit.tasks`, `speckit.plan`, `speckit.specify`, `speckit.clarify`, `speckit.implement`, `speckit.analyze` in `extension.yml`. Document that CI environments need their own prerequisite validation (e.g., a `check-prerequisites` workflow step) and APM installations need `apm.yml` dependencies. These are complementary validations at different layers. Reference: spec-kit Rec 4, gh-aw Tension 2.4.

**8. Add `config_schema` to extension manifest**
Define a JSON Schema for orchestrator configuration in `extension.yml`: `default_tier` (enum: A/B/C/null), `verification_commands` (array of strings), `context_verbosity` (enum: minimal/standard/full), `git_isolation` (boolean), `dispatch_budget` (integer or null), `duration_budget` (string or null). Schema validates persisted configuration, not per-run overrides. Reference: spec-kit Rec 5.

**9. Add US-8 Deliverable: `apm.yml` manifest definition**
Define the orchestrator's `apm.yml` contents as a concrete US-8 deliverable: `name: speckit-orchestrator`, `version`, `type`, dependencies, scripts. Specify `target: detect` (compile for detected agent runtimes only). Document that in CI environments only `.github/` targets are relevant. Version pinning acceptance scenarios should cover both `@main` (branch tracking for development) and `#v1.0.0` (tag pinning for stable releases). Reference: APM Rec 1 (surviving), Rec 8 (revised), Rec 9 (revised).

### P3: Valuable Additions (address after core architecture)

**10. Add FR: Specification Propagation / Artifact Invalidation**
When a phase's outputs change boundary maps or constraints affecting subsequent phases, the orchestrator must detect the invalidation and trigger re-planning for affected downstream phases. The implementation mechanism is a runtime adapter concern. Reference: gh-aw Rec 10 (SpecOps), gh-aw Dispute 2.

**11. Revise FR-028: Reconcile skill folder architecture with spec-kit extension model**
Define how the orchestrator's command/skill structure serves both spec-kit's extension model and APM's skill deployment. At minimum: each command has a spec-kit command `.md` as its authoritative definition, and APM skill metadata is derived or co-located (exact layout to be resolved per Dispute 1). Helper scripts, templates, and references are co-located with commands. Reference: spec-kit Rec 7 (revised), APM Rec 2 (revised).

**12. Register structural formatting templates as extension templates**
Roadmap layout, phase summary format, and task summary format templates go in `.specify/extensions/orchestrator/templates/` for project-level overrides via spec-kit's resolution stack. Do NOT embed orchestrator context (milestone references, phase scope, boundary maps) in templates. Orchestrator context is always injected explicitly into command inputs. Reference: spec-kit Rec 3 (revised).

---

## Key Concessions

### APM Concessions

| Conceded | Reason |
|---|---|
| `apm pack` for CI distribution (Rec 4, withdrawn) | Incorrect assumption about gh-aw sandboxing model. The activation job has network access and runs `apm install` natively. Packed bundles are redundant and introduce stale-artifact risk. |
| SDD lifecycle hooks as APM hook JSON (Rec 5, modified) | Conflated two different hook systems. Spec-kit SDD hooks fire during command execution; APM hooks fire on IDE events. Repackaging one as the other would cause double-execution or semantic mismatch. APM hooks now limited to IDE-level guard concerns. |
| Knowledge artifacts as install-time context primitives (Rec 6, modified) | Runtime-generated artifacts are empty at install time. Context-linking an empty KNOWLEDGE.md is pointless. Separated into install-time templates (format schemas) and runtime instances (populated content). |
| `target: all` compilation (Rec 8, modified) | Wastes disk space in CI by deploying to agent directories gh-aw cannot use. Accepted `target: detect` and confined compilation targets to APM packaging layer (US-8). |
| Skill folder as settled structure layered with APM packaging (Rec 2, modified) | Treated the spec's skill folder design as pre-settled. Accepted that spec-kit's extension model must be reconciled with first, then APM packaging wraps the result. |

### spec-kit Concessions

| Conceded | Reason |
|---|---|
| Companion preset for template overrides (Rec 2, withdrawn) | gh-aw's criticism was decisive: ambient template overrides violate the orchestrator's own Constitution Principle 4 ("Plans Assume Zero Context"). Templates that modify command behavior through environmental state are exactly what the constitution prohibits. |
| "Eliminate the parallel skill folder abstraction" (Rec 7, modified) | Both APM and gh-aw identified real architectural functions the skill folder serves (APM deployment unit, dispatch payload boundary) that spec-kit's extension primitives do not natively address. Accepted coexistence rather than elimination. |
| Community catalog as "primary discovery mechanism" (Rec 10, modified) | APM correctly noted the catalog is a discovery index, not a package manager. It has no lockfile, version pinning, or dependency graph. Reframed as discoverability listing, with APM as the lifecycle management system. |

### gh-aw Concessions

| Conceded | Reason |
|---|---|
| "Design for CI as the primary runtime" (Off-base assumption, withdrawn) | Both APM and spec-kit converged: the orchestrator is a spec-kit extension first, supporting 17+ agents. CI is one execution context among many. Tier A and B (majority of usage) will run locally. Designing CI-first optimizes for the minority case. |
| "Spec's dispatch is custom plumbing" (Off-base assumption, withdrawn) | The spec's abstract dispatch model is a runtime-portable interface, not custom plumbing. Building dispatch locally means invoking a subagent, which is trivial. The abstraction is sound. |
| `create-agent-session` / `assign-to-agent` for task execution (Rec 5, withdrawn) | Directly contradicts FR-032 (multi-agent compatibility). Hardcodes Copilot as the execution agent. The orchestrator must dispatch to whatever agent the consumer configures. |
| Repo-memory as primary state location (Rec 3, modified) | The state machine depends on file presence at known working-tree paths. Repo-memory branches are invisible to the working tree. APM cannot discover files on memory branches. Accepted `.specify/orchestrator/` as sole authoritative location, with repo-memory as CI persistence mechanism. |
| GitHub sub-issues as work hierarchy representation (Rec 1, modified) | Disk state is truth per Constitution Principle 6. GitHub issues are platform-specific and invisible to non-GitHub agents. Accepted sub-issues as one-directional read-only projection of disk state. |
| Lock files replaced by concurrency groups (Rec 7, modified) | Lock files record execution state for crash recovery, not just mutual exclusion. Concurrency groups handle only mutual exclusion. These are complementary, not substitutes. Accepted lock files as universal mechanism with concurrency groups layered on top in CI. |
| US-7 elevated to P2-P3 (Rec 8, modified) | Conflated CI compatibility (design constraint) with CI delivery (milestone priority). Accepted spec-kit's framing: CI compatibility as a cross-cutting design constraint from the start, but CI delivery remains at P7. |

---

*Generated by the Conversus process on 2026-03-19. This summary synthesizes 15 artifacts produced across 3 iterations by 3 independent tool perspectives reviewing the speckit-orchestrator specification.*
