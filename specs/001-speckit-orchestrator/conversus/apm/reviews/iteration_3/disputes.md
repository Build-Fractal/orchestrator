# APM Disputes Document -- Iteration 3

**Author**: APM (Agent Package Manager)
**Date**: 2026-03-19
**Scope**: Remaining disagreements after iteration 1 revisions across APM, spec-kit, and gh-aw

---

## Part 1: Remaining Disputes

### Dispute 1: The skill folder is a first-class architectural unit, not a secondary index into spec-kit primitives

**Claim being disputed**: spec-kit Recommendation 7 (revised) frames skill folders as a "shared physical structure that both systems index into differently," but the framing still treats spec-kit's extension primitives (`commands/`, `scripts/`, `templates/`) as the canonical organizational model with skill folders as a coexistence concession. The revised language -- "Preserve the skill folder as a cohesive unit but ensure it is *dual-registered* with spec-kit's extension system" -- positions registration-with-spec-kit as a requirement imposed on the skill folder, not a symmetric relationship.

**spec-kit's position**: The extension system has no native concept of "skill folders." The orchestrator is fundamentally a spec-kit extension. The skill folder cannot replace or override spec-kit's extension model -- it must coexist with it. The `extension.yml` registers each command by pointing to the command `.md` within the skill folder.

**APM counter-argument**: My New Recommendation A proposed a concrete dual-entry-point directory layout where neither system's organizational model dominates. The skill folder is the physical unit. Both `extension.yml` (spec-kit) and `apm.yml` (APM) index into it using their own entry points. gh-aw's revised Recommendation 2 independently validated this: the dispatch payload boundary is the skill folder, not a scattered set of spec-kit extension subdirectories. The skill folder serves three consumers (APM packaging, gh-aw dispatch, spec-kit command registration), and the directory layout must serve all three equally. Calling it a "spec-kit extension that APM and gh-aw index into" vs. "a shared unit that all three systems index into" is not a terminological quibble -- it determines who gets to restructure the folder when requirements conflict. If the skill folder is "a spec-kit extension first," then spec-kit's organizational preferences (flat `commands/` directory, separate `scripts/` directory) take priority over APM's and gh-aw's need for co-located, self-contained units. If it is a shared unit, no single system's preferences dominate.

**Proposed resolution**: The spec should define the skill folder as a **shared architectural unit** that all three systems index into, with no system's organizational model taking structural priority. The folder layout is a spec deliverable (my New Rec A) that explicitly annotates which files each system reads. Structural changes to the folder require demonstrating compatibility with all three consumers. This is coexistence as equals, not coexistence as guest-in-host.

---

### Dispute 2: `.instructions.md` files for state file format guidance are not replaceable by spec-kit templates

**Claim being disputed**: spec-kit Recommendation 3 (revised) limits extension templates to "structural formatting templates" registered in spec-kit's template resolution stack. spec-kit's cross-review of APM (Tension 2.2) proposes that output templates be registered in spec-kit's resolution stack rather than as APM instruction primitives. This implicitly subsumes the use case APM's Recommendation 7 addresses.

**spec-kit's position**: Templates should be registered as extension templates in `.specify/extensions/orchestrator/templates/` so they participate in spec-kit's template resolution stack. The resolution stack provides project-level overrides without forking the extension. APM's `.instructions.md` mechanism is an install-time artifact that does not participate in spec-kit's runtime resolution.

**APM counter-argument**: spec-kit's template resolution stack and APM's `.instructions.md` solve fundamentally different problems. spec-kit templates are consumed by spec-kit commands at execution time: the `plan` command loads a plan template, fills it, and produces output. APM instructions are consumed by agents at file-editing time: when an agent opens `.specify/orchestrator/phase-001/lock.yml`, the `.instructions.md` with `applyTo: ".specify/orchestrator/**/*.yml"` injects guidance about YAML frontmatter schema and allowed state transitions. No spec-kit command is running in this scenario -- the agent is directly editing a file. spec-kit has no mechanism for this. The template resolution stack does not activate when an agent opens an arbitrary file; it activates when a spec-kit command executes. These are different trigger surfaces: command-execution-time vs. file-access-time. My Recommendation 7 specifically targets the file-access-time case, and spec-kit's revised Recommendation 3 does not address it because it cannot -- it is outside spec-kit's execution model. The `.instructions.md` mechanism is not competing with spec-kit's templates; it operates in a gap spec-kit's architecture does not cover.

**Proposed resolution**: The spec should explicitly distinguish two artifact categories: (a) **command templates** -- consumed by spec-kit commands during execution, registered in the template resolution stack, overridable by projects; (b) **file-editing instructions** -- consumed by agents when directly editing state files, deployed by APM as `.instructions.md` with `applyTo` patterns, providing schema guidance and format constraints. Category (a) belongs to spec-kit. Category (b) belongs to APM. There is no overlap because the trigger conditions are different.

---

### Dispute 3: The runtime adapter interface must be specified at the right level of abstraction -- not lowest-common-denominator, but not gh-aw-shaped either

**Claim being disputed**: gh-aw's New Recommendation A defines a runtime adapter interface with five contracts (dispatch, persistence, crash recovery, verification execution, progress projection). gh-aw's final position statement adds: "The interface should enable each runtime to bring its full capabilities." While this sounds neutral, the proposed interface contracts are shaped by gh-aw's own primitives. "Dispatch returns a handle for monitoring completion and collecting results" maps to workflow run monitoring. "Verification execution may use `call-workflow` for parallel review workflows" is gh-aw leaking into the interface definition.

**gh-aw's position**: The runtime adapter interface should be rich enough that gh-aw can use dispatch-workflow, call-workflow, concurrency groups, and all its other primitives without working around the abstraction. A lowest-common-denominator interface that only supports what local execution can do would neuter the CI adapter.

**APM counter-argument**: I agree that a lowest-common-denominator interface is wrong. My New Recommendation C proposed a dispatch interface with three elements: payload format, completion signaling, and result collection. This is deliberately minimal not because I want to neuter gh-aw, but because the interface should define *what* adapters must do, not *how capable* they may be. An adapter that returns a richer result than the interface requires is fine -- the interface defines the minimum contract, and adapters are free to exceed it. gh-aw's five-contract interface risks encoding CI-specific concerns (persistence checkpointing, progress projection) into the core abstraction. Local execution does not need a persistence contract (files just persist) or a progress projection contract (the terminal is the progress display). Making these core interface contracts forces local adapters to implement no-op stubs for CI-specific concerns. The correct design: a lean interface that defines the universal operations (dispatch, signal completion, collect results), with optional extension points that capable adapters can implement. gh-aw implements all extension points; a local subprocess adapter implements only the core.

**Proposed resolution**: The runtime adapter interface should have a **core contract** (dispatch, completion signaling, result collection -- three operations that every adapter must implement) and **optional capabilities** (persistence checkpointing, progress projection, parallel verification, concurrency management -- that adapters declare support for and the orchestrator uses when available). This is the capability-negotiation pattern, not lowest-common-denominator and not gh-aw-shaped. The orchestrator asks the adapter "do you support parallel verification?" and uses it if available, falling back to sequential verification if not.

---

### Dispute 4: Distribution model -- APM install vs. committed extension with APM as wrapper

**Claim being disputed**: spec-kit New Recommendation D states "the extension should be committed to the repository, consistent with spec-kit's convention that extension state is version-controlled. APM packaging then serves team onboarding and initial setup, not CI artifact distribution." This frames APM as a bootstrap tool that runs once and then becomes irrelevant -- the committed extension is the artifact, not the APM package.

**spec-kit's position**: spec-kit extensions are typically committed to the repository. The extension files live in `.specify/extensions/orchestrator/` and are version-controlled on main. APM is useful for initial installation and for pulling updates, but the committed files are the source of truth. In CI, the files are already present in the checkout, so `apm install` is unnecessary.

**APM counter-argument**: If the committed extension is the source of truth and `apm install` is unnecessary after initial setup, then APM's core value propositions -- lockfile tracking, version pinning, dependency graph resolution, transitive dependency management, and clean uninstall -- are reduced to one-time-use features. This misunderstands how APM works in practice. `apm.lock.yaml` records the exact commit SHA of every installed package. When the orchestrator releases v0.2.0 with breaking changes, `apm install speckit-orchestrator@v0.2.0` performs a controlled upgrade: it knows what v0.1.0 deployed, diffs it against v0.2.0, removes stale files, deploys new ones, and updates the lockfile. If the extension is "just committed files," upgrades become manual: the user must know which files to delete, which to update, which are new. This is the problem APM exists to solve. Furthermore, if the orchestrator depends on other APM packages (e.g., shared context files, agent instructions from other extensions), transitive dependency resolution requires APM to be active, not a one-time bootstrap. The committed-extension model works for simple, dependency-free extensions. The orchestrator -- with its skill folders, instructions, context files, and potential dependencies on shared packages -- is not a simple extension.

**Proposed resolution**: The spec should support both models without declaring either as canonical: (a) **APM-managed** -- `apm install` deploys the extension, `apm.lock.yaml` tracks it, `apm install` upgrades it. The extension directory is in `.gitignore` and APM is the lifecycle manager. This is the recommended model for teams and projects with multiple APM-managed packages. (b) **Committed** -- the extension is committed to the repo after initial `apm install`. APM is used for upgrades (`apm install --upgrade`) but the committed files are version-controlled. This is the fallback for individual developers or projects that do not use APM broadly. The spec should document both models and let the consumer choose. It should not prescribe "committed" as the default just because that is spec-kit's convention for simpler extensions.

---

## Part 2: Points of Convergence

After iteration 1 revisions, all three tools now agree on the following positions.

### Convergence 1: Disk state at `.specify/orchestrator/` is the sole source of truth for orchestration state

All three tools agree that the orchestrator's runtime state (current phase, active blockers, execution log, lock files, knowledge, decisions) lives exclusively at `.specify/orchestrator/` on the working tree. APM accepted this from the start (Constitution Principle 6). gh-aw conceded that repo-memory cannot be the primary state location (Rec 3 revised). spec-kit's New Recommendation A explicitly draws the boundary. No tool proposes an alternative state location. External systems (GitHub Projects, repo-memory branches) are projection/cache layers, never the source of truth.

### Convergence 2: The orchestrator must be runtime-agnostic with a pluggable adapter layer

All three tools independently converged on the runtime adapter pattern. APM proposed a "dispatch interface abstraction" (New Rec C). spec-kit proposed "runtime-agnostic protocol with runtime adapters" (New Rec B). gh-aw proposed a "Runtime Adapter Interface" (New Rec A). The details differ (see Dispute 3), but the architectural pattern is unanimous: the orchestrator's core logic programs against abstract operations, and runtime-specific adapters (gh-aw for CI, local subprocess for development) implement those operations using platform-native primitives. This was the single strongest convergence across the entire cross-review process.

### Convergence 3: Static configuration and dynamic runtime state must be explicitly separated

All three tools agree that the spec currently conflates configuration and state. APM's revised Rec 3 draws the boundary: mutable config outside APM's deployment radius, runtime state in `.specify/orchestrator/`. spec-kit's New Rec A provides the concrete split: settings that humans author (tier defaults, verification commands) go in config; artifacts that the orchestrator machine-authors (current phase, execution log) go in state. gh-aw's New Rec C validates the same distinction from the CI perspective: config is pre-set, state needs persistence management between workflow runs. The three-way agreement is complete on the principle; implementation details (which config system, which precedence layers) have minor differences but no fundamental disagreement.

### Convergence 4: The orchestrator MUST NOT override or replace core spec-kit commands

APM proposed this as an explicit constraint (cross-review Section 2.2). spec-kit adopted it verbatim in New Rec C: "The orchestrator MUST NOT override or replace core spec-kit commands via presets." gh-aw's revised Rec 8 accepts option (a) -- new `speckit.orchestrator.*` commands that delegate -- as compatible with both local and CI execution. All three tools agree that command composition (new commands that wrap standard workflows) is the correct pattern, and preset-based command replacement is prohibited.

### Convergence 5: `create-agent-session` / `assign-to-agent` must not be hardcoded as the dispatch mechanism

gh-aw withdrew Rec 5 entirely, accepting that Copilot-specific primitives violate FR-032 (multi-agent compatibility). APM's cross-review identified this as a Contradiction 1.4. spec-kit's cross-review of gh-aw flagged the same issue. All three tools agree: the orchestrator dispatches to whatever agent the consumer has configured; it never selects a specific vendor. If a team uses Copilot, the gh-aw adapter may use `create-agent-session` as an internal implementation detail, but this is a consumer choice, not a spec prescription.

---

## Part 3: Final Position Statement

### Non-negotiable positions

1. **The `apm.yml` manifest must be a spec deliverable.** This is the contract that enables every downstream APM integration. No cross-review argued against its existence. Without it, US-8 has acceptance scenarios with no concrete artifact definition.

2. **`.instructions.md` with `applyTo` patterns is APM's mechanism for file-editing-time agent guidance, and it is not replaceable by spec-kit's template resolution stack.** These solve different problems at different trigger points. The spec must acknowledge both artifact categories.

3. **User-mutable configuration must not reside in APM-managed directories.** Any file APM deploys is subject to overwrite on reinstall. This is a hard constraint of APM's deployment model, not a preference. Config files that users edit must live outside APM's deployment radius.

4. **The skill folder is a shared architectural unit, not a spec-kit extension that other tools index into.** Three systems consume it; no single system's organizational preferences should dominate its structure.

### Where I am flexible

1. **Compilation target strategy**: I accept `target: detect` over `target: all`, and I accept that compilation targets are an APM packaging concern confined to US-8, not a core functional requirement.

2. **Version pinning mode**: I accept branch-based tracking as the default during development, with tag-based pinning reserved for stable releases. The acceptance scenarios should cover both.

3. **Distribution model**: I am willing to support both APM-managed and committed-extension models, as long as the spec does not declare committed-as-default in a way that marginalizes APM's lifecycle management capabilities.

4. **Runtime adapter interface scope**: I am flexible on whether the adapter interface has three contracts or five, as long as the design follows capability-negotiation (core + optional extensions) rather than encoding any single runtime's primitives into the core contract.

5. **Hook deployment**: I accept that SDD lifecycle hooks belong exclusively in spec-kit's extension system. APM hooks are limited to IDE-level guard concerns (pre-commit validation, manual-edit warnings) that operate outside spec-kit's lifecycle.
