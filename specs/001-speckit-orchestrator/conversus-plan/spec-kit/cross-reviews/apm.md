# Spec-Kit Cross-Review of APM's Review

**Cross-reviewer**: spec-kit
**Reviewing**: APM's review of speckit-orchestrator implementation planning artifacts
**Date**: 2026-03-19

---

## Dangerous Contradictions

These are points where APM's review and spec-kit's review give guidance that, if both followed, would produce an incoherent or broken implementation.

### DC-1: Config file placement -- project root vs `.specify/extensions/orchestrator/`

APM's review endorses the plan's placement of `orchestrator-config.yml` at the project root, framing it as correct because it keeps user-mutable config "outside APM-managed directories" (Alignment, "Config Outside APM Radius"; Off-Base #2 is absent -- APM does not flag this). Spec-kit's review calls this placement a deviation from spec-kit's config convention and recommends moving it to `.specify/extensions/orchestrator/orchestrator-config.yml` (Off-Base #2, Recommendation #3), noting that spec-kit's own install process preserves user config files in that location.

**Why this is dangerous**: If the implementer follows APM's implicit endorsement and places config at project root, every other spec-kit extension will have config inside `.specify/extensions/{id}/` while the orchestrator is a special case. If the implementer follows spec-kit's recommendation, APM's concern about overwrite safety must be re-validated -- APM's review specifically praised the "outside APM-managed directories" constraint (FR-070) and never acknowledged that `.specify/extensions/{id}/` config files survive APM reinstalls. Following both reviews simultaneously is impossible without resolving which directory owns user config.

**Resolution needed**: Determine whether APM's `apm install` overwrites everything under `.specify/extensions/orchestrator/` (in which case project root is correct) or whether spec-kit's `ExtensionManager.install_from_directory()` preserves config files during install (in which case the spec-kit path is correct). These are factual claims about two different install code paths that may both be right -- the key question is which install path is canonical for the orchestrator.

### DC-2: `.instructions.md` as primary mechanism vs supplementary

APM's review (Off-Base #2) argues that `.instructions.md` files are static assets deployed at install time with no runtime dependency on APM, and should be the orchestrator's **primary** mechanism for injecting scoped guidance. APM's Recommendation #4 (P2) proposes authoring `.apm/instructions/` files with `applyTo` patterns as a replacement for the orchestrator's custom scope filtering.

Spec-kit's review does not mention `.instructions.md` at all but identifies the equivalent need through a different mechanism: spec-kit's `scripts` frontmatter field (Missed Opportunity #2), `handoffs` frontmatter (Missed Opportunity #1), and the `$ARGUMENTS` placeholder (Missed Opportunity #4) as the native ways commands receive scoped context and chain behavior.

**Why this is dangerous**: These are two competing context injection architectures. APM wants file-pattern-scoped static instructions that agents load automatically. Spec-kit wants command-level frontmatter mechanisms that agents process during command execution. If the implementer adopts APM's `.instructions.md` as "primary" while also adopting spec-kit's `scripts` frontmatter and `handoffs`, the orchestrator will have two parallel systems for injecting context into agent sessions -- one via APM's instruction loading and one via spec-kit's command execution model. They operate at different lifecycle points (agent startup vs. command invocation) and could deliver contradictory or redundant guidance.

**Resolution needed**: Decide which layer owns runtime context injection. The natural boundary is: APM `.instructions.md` for static, always-applicable rules (e.g., "files in `.specify/orchestrator/` use YAML frontmatter"), and spec-kit frontmatter mechanisms for dynamic, command-specific context (e.g., "this dispatch should include phase P02's must-haves"). The reviews must agree on this split rather than each claiming primacy for their own mechanism.

### DC-3: Verification architecture -- APM hooks vs spec-kit checklist system

APM's review (Recommendation #9, P3) suggests registering `PostToolUse` APM hooks on file write events to trigger lightweight verification, framing it as "defense-in-depth" supplementing spec-kit's 4 hook points.

Spec-kit's review (Missed Opportunity #6) identifies that the orchestrator's verification ladder reinvents a parallel verification system and recommends connecting phase must-haves to spec-kit's native checklist system, using `/speckit.implement`'s built-in checklist gating (implement.md lines 54-79).

**Why this is dangerous**: APM hooks fire per-tool-use (every file write), spec-kit checklists gate at lifecycle boundaries (before implement proceeds). If both are adopted without coordination, verification runs at two granularities with two different data models -- APM hooks checking must-haves against individual file writes, and spec-kit checklists checking must-haves as a batch before implementation proceeds. A phase could pass APM's per-write hooks (each file individually looks correct) but fail spec-kit's checklist gate (the aggregate is incomplete), or vice versa. Worse, the orchestrator's own verification ladder (R-006) is a third system. Three verification architectures in one extension is a maintenance disaster.

**Resolution needed**: Choose one primary verification mechanism (spec-kit checklists are the strongest candidate since they already gate `/speckit.implement`) and designate the others as explicitly optional, documenting when each fires and what it checks. The orchestrator's R-006 verification ladder should be the implementation of spec-kit's checklist verification, not a parallel system, and APM hooks should only be considered if there is a demonstrated gap in checklist coverage.

---

## Tensions

These are points where both reviews are individually valid but create friction or trade-offs that the implementer must navigate.

### T-1: APM compilation vs spec-kit command composition for dispatch payload

APM recommends using `apm compile` for constitution injection and context assembly (Missed Opportunity #1, Recommendation #5), arguing that the orchestrator's `build-context.sh` reinvents APM's compilation system. Spec-kit recommends using `scripts` frontmatter (Missed Opportunity #2) and `handoffs` (Missed Opportunity #1) -- the native spec-kit mechanisms for command-to-command context flow.

Both are valid: APM compilation is excellent at assembling static context with drift detection, and spec-kit's frontmatter mechanisms are excellent at runtime command chaining. The tension is that dispatch payload construction sits at the boundary -- it needs both static context (constitution, project knowledge) and dynamic context (current phase state, filtered scope). Using APM compilation for the static portion and spec-kit frontmatter for the dynamic portion is architecturally clean but means the dispatch payload is assembled by two different systems, which complicates debugging and testing.

### T-2: SKILL.md authorship vs command frontmatter derivation

APM (Off-Base #1, Recommendation #2) correctly notes that APM cannot currently derive SKILL.md from command frontmatter at install time -- this capability does not exist. APM insists on a manually authored root-level SKILL.md.

Spec-kit's review does not address SKILL.md directly, but its emphasis on command frontmatter as the single source of truth for command metadata (Missed Opportunity #2, #4) implicitly supports the plan's AD-6 decision that skill metadata derives from command definitions rather than being maintained separately.

The tension: APM needs a SKILL.md today for skill discoverability across agent platforms, and the plan's "derive at install time" approach requires APM feature work. But spec-kit's principle of command frontmatter as single source of truth means maintaining a separate SKILL.md creates a second source of truth that can drift from the actual command definitions. The short-term fix (author SKILL.md manually) creates the long-term problem (two sources of truth for command metadata).

### T-3: Extension manifest completeness -- APM's `apm.yml` vs spec-kit's `extension.yml`

APM's Recommendation #1 (P1) demands a concrete `apm.yml` with typed dependencies, compilation settings, scripts, and target configuration. Spec-kit's Recommendation #1 (P1) demands `requires.commands` in `extension.yml`, Recommendation #8 demands `config_schema`, and Missed Opportunity #5 flags missing command dependency declarations.

Both are P1 priorities. Both are right. The tension is that the orchestrator now has two manifest files to maintain (`apm.yml` and `extension.yml`) with partially overlapping concerns (both declare the package name, version, and dependencies). The risk is not contradiction but drift -- the `apm.yml` declares one set of capabilities and the `extension.yml` declares another, and there is no mechanism ensuring they stay synchronized.

### T-4: Hook coverage -- 4 hooks, 6 hooks, or APM hooks

Spec-kit's Off-Base #1 notes that spec-kit actually has 6 hook points (including `before_commit` and `after_commit`), not just the 4 the plan targets. APM's Recommendation #9 suggests adding `PostToolUse` APM hooks for verification. The plan targets 4 spec-kit hooks.

All three positions are defensible, but the implementer must decide how many hook integration points to build and maintain. Each additional hook point increases the testing surface and the number of code paths where orchestrator state can change. The tension is between completeness (use all available hooks for maximum control) and simplicity (the plan's 4 hooks may be the right minimal set).

### T-5: Lockfile and reproducibility scope

APM (Recommendation #3, P1) demands `apm.lock.yaml` for reproducible installations, treating version pinning as critical. Spec-kit's review does not mention lockfiles at all -- from spec-kit's perspective, the extension is either committed into `.specify/extensions/` (the default per AD-7/D4) or installed via `specify extension add`, and spec-kit's own install model does not use lockfiles.

The tension: the plan already resolved this in D4 ("committed extension is default, APM-managed is supported but not canonical"). If the committed-extension path is primary, APM's lockfile concern is real only for the secondary APM-managed path. But APM treats lockfile as P1, which could drive design decisions (lockfile-aware directory structures, version metadata in extension files) that add complexity to the primary committed-extension path where they provide no value.

---

## Safe Agreements

These are points where both reviews align and the implementer can proceed with confidence.

### SA-1: Deployment boundary separation is correct and non-negotiable

Both reviews independently validate the separation between `.specify/extensions/orchestrator/` (managed by install, overwritable) and `.specify/orchestrator/` (runtime state, never touched by install). APM calls this "the single most important APM concern" (Alignment, "Deployment Boundary"). Spec-kit confirms it "mirrors spec-kit's own separation of `.specify/extensions/` from `.specify/memory/`" (Alignment, bullet 3). This decision (AD-7) is load-bearing and both reviews agree it is correct. Proceed without modification.

### SA-2: The orchestrator is a spec-kit extension that APM distributes, not the reverse

APM's Alignment section explicitly endorses "Extension-First, APM-Distributes Model" (D4) and states APM's value is "upgrade management and dependency resolution rather than runtime control." Spec-kit's Alignment confirms "AD-5 prohibition on core command overrides respects spec-kit's preset/extension boundary" and the extension-first positioning. Both reviews agree that spec-kit is the runtime host, APM is the distribution mechanism, and the orchestrator should not depend on either at runtime beyond what the spec-kit extension API provides. This architectural decision is safe to treat as settled.

### SA-3: Command naming and registration conventions are correct

APM validates the dual installation path (`specify extension add` and `apm install`) and the command frontmatter approach (AD-6). Spec-kit validates the `speckit.orchestrator.*` naming pattern against the enforced regex and confirms hook usage at the 4 targeted lifecycle points matches spec-kit's implementation. Neither review raises concerns about the fundamental command registration design. The 10-command surface area and naming scheme can proceed as planned.
