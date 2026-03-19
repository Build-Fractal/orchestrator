# Disputes — Spec-Kit Post-Iteration 1

**Author**: spec-kit (extension framework perspective)
**Date**: 2026-03-19
**Iteration**: 3 (post-revision disputes)
**Addresses**: Remaining disagreements with APM and gh-aw after iteration 1 revisions

---

## Part I: Remaining Disputes

### Dispute 1: Skill Folder as Shared Physical Structure vs. Spec-Kit Extension Primacy

**Claim disputed**: APM (New Recommendation A, Revised Rec 2) proposes a "dual-entry-point directory layout" where `skills/` directories sit alongside `commands/` at the same level, each containing a `SKILL.md` that "references the corresponding command markdown." APM frames this as a peer relationship: "Both systems read from the same source tree with no file duplication."

**APM's position**: The skill folder and the spec-kit command are co-equal entry points into a shared directory structure. The `SKILL.md` and the command `.md` coexist as siblings, each serving its own system. APM's directory layout proposal (New Rec A) places `skills/` as a top-level directory alongside `commands/`, implying structural parity.

**Spec-kit's counter-argument**: This framing smuggles in structural parity where there is a clear hierarchy. The orchestrator is a spec-kit extension. The `extension.yml` manifest is the authoritative registry of what the extension provides. The `commands/` directory is where spec-kit discovers commands -- this is the canonical structure. A `SKILL.md` is an APM distribution artifact that points *into* the canonical structure; it does not occupy the same architectural tier.

APM's proposed layout creates a directory tree where a developer looking at the extension sees two parallel hierarchies (`commands/` and `skills/`) and must understand both systems to navigate the codebase. This violates the principle that the extension should be intelligible to someone who only knows spec-kit. The `SKILL.md` files are distribution metadata -- they belong *within* the command structure they describe, not in a parallel tree.

**Proposed resolution**: The extension directory structure is organized around spec-kit's extension model: `commands/`, `scripts/`, `templates/` are the top-level directories. APM skill entry points (`SKILL.md`) are co-located *inside* the relevant command's resource directory (e.g., `commands/orchestrate-auto/SKILL.md`), not in a parallel `skills/` tree. The `extension.yml` is the source of truth for what exists; `SKILL.md` files are APM's index into that structure. One hierarchy, two readers.

---

### Dispute 2: `.instructions.md` Files as APM-Exclusive Agent Guidance

**Claim disputed**: APM (Rec 7, surviving) argues that `.instructions.md` files with `applyTo` patterns for state file editing guidance represent "APM's most distinctive capability" and that "spec-kit has no equivalent mechanism." APM claims this recommendation is unchallenged and addresses a genuine gap.

**APM's position**: When an agent opens or edits a file matching `.specify/orchestrator/**/*.md`, it should receive APM-deployed `.instructions.md` guidance on YAML frontmatter schemas, state transition rules, and format constraints. This is static format documentation, not runtime state, so staleness concerns do not apply. Neither spec-kit's template system nor gh-aw's runtime model covers this use case.

**Spec-kit's counter-argument**: The claim that "spec-kit has no equivalent mechanism" is inaccurate. Spec-kit extensions can provide contextual documentation through two existing mechanisms: (a) the `docs/` directory within the extension, which agents can reference when working with extension-managed files, and (b) command definitions themselves, which specify input/output schemas and constraints as part of their markdown frontmatter. The orchestrator commands that create and modify state files can embed format requirements directly in their definitions.

More importantly, APM's `.instructions.md` mechanism operates at the IDE/agent-config level -- it injects guidance into agent system prompts when file patterns match. This creates an implicit dependency: the orchestrator's state files are only safe to edit if APM has been installed and has compiled instructions into the agent's configuration. A developer using spec-kit without APM gets no format guidance when editing state files. This makes APM a soft runtime dependency for safe state file editing, which contradicts the spec's requirement that APM is not a runtime dependency.

The correct approach is for the orchestrator's own commands to validate state file formats (the commands already read and write these files) and for format documentation to ship as part of the spec-kit extension's `docs/` directory. APM `.instructions.md` can *additionally* provide this guidance as a convenience layer for APM users, but the spec should not treat it as the primary mechanism for format safety.

**Proposed resolution**: Format validation and documentation for state files is a spec-kit extension responsibility, delivered through command-level validation and extension documentation. APM `.instructions.md` files may provide *supplementary* agent guidance as a convenience for APM consumers but must not be the sole mechanism. The spec should not frame any APM-only capability as the primary solution for a core extension concern.

---

### Dispute 3: Runtime Adapter Interface Richness vs. Lowest-Common-Denominator Risk

**Claim disputed**: gh-aw (Position Summary, final paragraph) states: "A lowest-common-denominator interface that only supports what local execution can do would neuter the CI adapter. The interface should enable each runtime to bring its full capabilities." gh-aw further argues (Revised Rec 2) that the interface design should be "informed by dispatch-workflow's capabilities (typed inputs, compile-time target validation, rate limiting)."

**gh-aw's position**: The runtime adapter interface must be rich enough to expose gh-aw's full capability set -- typed inputs, compile-time validation, rate limiting, concurrency groups, parallel review workflows via `call-workflow`, and artifact-based result collection. Designing the interface around what local execution supports would cripple the CI adapter.

**Spec-kit's counter-argument**: There is a difference between "the interface accommodates platform-native capabilities" and "the interface is designed around one platform's capabilities." gh-aw is correct that the interface should not artificially constrain CI adapters. But the risk flows in both directions: an interface shaped by `dispatch-workflow`'s specific semantics (typed inputs with compile-time validation, rate limiting as a first-class concept) will impose concepts on local adapters that have no meaningful local equivalent.

Rate limiting is a CI infrastructure concern; local execution does not rate-limit subagent spawning. Compile-time target validation is a GitHub Actions concept; there is no equivalent in a local subprocess model. If these become interface-level abstractions, local adapter implementations must either implement no-op stubs for concepts that do not apply or contort local execution to fit CI-derived abstractions.

The correct interface design principle is: define the interface around the *orchestrator's* needs (dispatch a task, know when it finishes, collect its output, handle failure), not around any specific runtime's capabilities. Platform-specific capabilities (rate limiting, concurrency groups, typed inputs) belong in adapter configuration, not in the interface contract. The interface should be narrow and stable; adapters can be as rich as they need to be internally.

**Proposed resolution**: The runtime adapter interface defines five operations: dispatch-task, await-completion, collect-result, signal-failure, inject-context. Each operation has a minimal, platform-neutral contract. Adapters may expose additional platform-specific configuration (gh-aw adapter exposes rate limiting, concurrency groups, `call-workflow` for parallel verification) through adapter-specific configuration, not through interface extension. The interface is designed around the orchestrator's needs; adapters are designed around their platform's capabilities. No adapter is constrained by another adapter's limitations, and no adapter's capabilities inflate the interface that all adapters must implement.

---

### Dispute 4: Co-Specifying US-7 and US-8 as a Joint Deliverable

**Claim disputed**: gh-aw (New Recommendation B) proposes that US-7 (CI execution via gh-aw) and US-8 (APM packaging) should be "co-specified as a joint deliverable," arguing that CI execution depends on APM packaging because gh-aw workflows declare APM frontmatter dependencies.

**gh-aw's position**: Neither US-7 nor US-8 should be delivered without the other. The APM manifest defines what gets packaged, gh-aw adapter workflows are included in the APM package, and installation via any channel produces a working orchestrator with optional CI capabilities.

**Spec-kit's counter-argument**: Bundling US-7 and US-8 as a joint deliverable conflates two independent delivery concerns and creates an artificial coupling that harms the spec's incremental delivery model. The orchestrator must be a fully functional spec-kit extension at US-1 through US-6 -- before either APM packaging or CI execution exists. If US-7 and US-8 are joint, the implication is that neither can be delivered until both are ready, which delays whichever is simpler.

More fundamentally, the dependency claim is overstated. gh-aw workflows can declare dependencies via frontmatter, but those dependencies do not require a finalized APM manifest to function. The activation job runs `apm install`, which needs the package to exist in a registry or repository -- but the package format (`apm.yml`) can be defined incrementally. US-8 defines the packaging contract; US-7 consumes it. This is a sequential dependency (US-7 depends on US-8), not a co-dependency (both depend on each other). Sequential dependencies are handled by priority ordering, which the spec already provides: US-8 at P8, US-7 at P7.

The correct relationship is: US-8 (APM packaging) is a prerequisite for US-7 (CI execution). They do not need to be co-specified. They need to be sequenced correctly, which they already are.

**Proposed resolution**: Maintain US-7 and US-8 as separate deliverables with the existing priority ordering. Add an explicit dependency annotation: "US-7 requires US-8 as a prerequisite." Do not bundle them as a joint deliverable. The spec's incremental delivery model should not be compromised by packaging two user stories that have different scopes, different acceptance criteria, and different consumers.

---

## Part II: Points of Convergence

After iteration 1, the following positions are now shared across all three tools.

### Convergence 1: Disk State Is the Sole Source of Truth

All three tools now agree that `.specify/orchestrator/` on the working tree is the authoritative state location. APM withdrew its context-linking approach for runtime-generated artifacts (Rec 6 modified). gh-aw withdrew repo-memory as primary state storage (Rec 3 modified) and accepted that sub-issues are a read-only projection, not a state source (Rec 1 modified). Spec-kit's position that state files at known disk paths are the universal state mechanism is now unchallenged.

### Convergence 2: The Orchestrator Is a Spec-Kit Extension First

All three tools explicitly state this. APM's revised stance: "The orchestrator is a spec-kit extension that APM distributes. Not an APM package that happens to run in spec-kit." gh-aw's revised stance: "The orchestrator's core architecture must be runtime-agnostic as both APM and spec-kit argue." Spec-kit's position has been consistent throughout. The extension model is the canonical organizational structure; APM packaging and gh-aw CI integration are delivery and runtime concerns that wrap this architecture.

### Convergence 3: Runtime Adapter Pattern for Cross-Platform Support

All three tools independently converged on the need for a runtime adapter interface. APM called it "dispatch interface with gh-aw as one implementation." gh-aw called it "runtime adapter interface" with five contracts (dispatch, persistence, crash recovery, verification, progress). Spec-kit proposed the same pattern in New Recommendation B. The abstraction layer -- where the orchestrator defines portable operations and each platform implements them with native primitives -- is now consensus architecture.

### Convergence 4: Static Configuration vs. Dynamic State Boundary

All three tools agree that configuration and state must be explicitly separated. Spec-kit (New Rec A), APM (Revised Rec 3), and gh-aw (New Rec C) all independently proposed this distinction. Static config (tier defaults, verification commands, context verbosity) flows through spec-kit's multi-layer config system. Dynamic state (current phase, execution log, decisions register) lives in `.specify/orchestrator/`. No configuration setting changes during orchestration execution. No runtime state is stored in configuration files.

### Convergence 5: Orchestrator Must Not Override Core Spec-Kit Commands

APM explicitly proposed the constraint: "The orchestrator MUST NOT override or replace core spec-kit commands via presets." Spec-kit adopted this in its surviving Recommendation 8 (command composition via new `speckit.orchestrator.*` commands, not preset overrides). gh-aw did not challenge this. The orchestrator uses new commands that delegate to standard spec-kit workflows with injected context -- it never replaces or overrides the standard commands themselves.

---

## Part III: Final Position Statement

### Non-Negotiable Positions

1. **Extension model primacy**: The spec-kit extension model (`extension.yml`, `commands/`, `scripts/`, `templates/`) is the canonical organizational structure. APM skill folders and gh-aw workflow files are distribution and runtime artifacts that index into this structure. They do not define a parallel hierarchy at the same tier.

2. **No APM runtime dependency**: The orchestrator must function fully with only spec-kit installed. APM provides distribution convenience and supplementary agent guidance, but no core orchestrator capability may depend on APM being present at runtime. Any mechanism framed as the primary solution for a core concern (like state file format safety) must work without APM.

3. **Interface designed around orchestrator needs, not platform capabilities**: The runtime adapter interface must be derived from what the orchestrator needs to do (dispatch, verify, persist, recover), not from what any specific platform can do. Adapters bring their own richness internally. The interface contract stays narrow and platform-neutral.

4. **Incremental delivery model**: User stories are delivered incrementally with explicit dependency ordering. Co-specifying independent user stories as joint deliverables is an anti-pattern that delays delivery and creates artificial coupling.

### Where I Am Flexible

1. **Skill folder co-location strategy**: I am open to negotiation on exactly where `SKILL.md` files sit within the extension structure, provided the spec-kit extension model remains the primary organizational axis. If APM has a strong technical constraint requiring a specific directory layout for skill discovery, I will accommodate it within the extension hierarchy.

2. **APM `.instructions.md` as supplementary guidance**: I do not object to APM providing `.instructions.md` for agent-contextual guidance. My dispute is only with framing it as the primary mechanism. If it is positioned as an additive convenience layer on top of extension-native format documentation, I have no objection.

3. **Adapter interface surface area**: I am willing to expand the interface beyond five operations if the orchestrator's core logic genuinely requires additional abstractions. My position is about the design principle (derive from orchestrator needs), not about a specific operation count. If gh-aw demonstrates that rate limiting or parallel verification are orchestrator-level concerns rather than adapter-level concerns, I will reconsider.

4. **gh-aw's SpecOps pattern**: I have no objection to gh-aw's Recommendation 10 (SpecOps for specification propagation). It addresses a genuine gap in the spec and is orthogonal to the disputes above. I consider it a reasonable addition.
