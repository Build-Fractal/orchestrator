# Spec-Kit Disputes Document

**Author**: spec-kit (extension system, commands, hooks, templates, configuration)
**Phase**: Disputes (post-revision)
**Date**: 2026-03-19
**Input**: Revised positions from APM, spec-kit, and gh-aw

---

## Remaining Disputes

### Dispute 1: Config file placement is resolved with a phantom consensus

All three revisions claim the config placement question is settled, but they settled on different things.

- **APM revision** (New-2): Instructs that APM-deployed instructions must be committed to the repo, with a post-install step of `git add .github/instructions/`. APM's entire model treats `.specify/extensions/orchestrator/` as always-overwrite (the argument that killed spec-kit's Rec 3). APM never addresses where `orchestrator-config.yml` ends up -- it only defends the "outside APM radius" constraint.
- **gh-aw revision** (New Rec B): States config follows "spec-kit's convention at `.specify/extensions/orchestrator/orchestrator-config.yml`" and is committed to the main branch. This directly contradicts the reason spec-kit withdrew Rec 3 -- APM's always-overwrite semantics for that directory.
- **spec-kit revision** (Rec 3 Withdrawn): Accepted project-root placement because APM's always-overwrite semantics make `.specify/extensions/orchestrator/` unsafe for user config.

gh-aw's New Rec B reopens the question that spec-kit conceded. If `.specify/extensions/orchestrator/` is safe for config (gh-aw's position), then spec-kit's original Rec 3 was correct and should not have been withdrawn. If it is unsafe (APM's position, which spec-kit accepted), then gh-aw's New Rec B is wrong. These cannot both be true.

**Spec-kit's position**: The withdrawal of Rec 3 was based on APM's factual claim about always-overwrite semantics. That claim has not been retracted. Until APM confirms that `apm install` preserves files matching a configurable exclusion pattern (e.g., `*-config.yml`, `*-config.local.yml`) inside `.specify/extensions/orchestrator/`, the project-root placement stands. gh-aw's New Rec B should be amended to either (a) acknowledge that config lives at the project root and specify its repo-memory exclusion from there, or (b) present evidence that APM's overwrite concern does not apply to config files. The plan cannot proceed with two revisions asserting contradictory answers to the same question.

### Dispute 2: The `deterministic` annotation in frontmatter is premature standardization

Both spec-kit (New-3) and gh-aw (New Rec C) converged on adding a `deterministic: true|false` annotation to script declarations in command frontmatter. gh-aw provides a concrete YAML example. This looks tidy, but it introduces a new frontmatter field into spec-kit's command format that has no consumer today.

Spec-kit's command runner does not inspect a `deterministic` flag. It runs all scripts identically through the `{SCRIPT}` placeholder mechanism. The only consumer of this annotation would be the gh-aw adapter's compile step, which reads frontmatter to decide what to hoist into `on.steps:`. This means:

1. The annotation is gh-aw-specific optimization metadata embedded in spec-kit's command format.
2. Every future spec-kit extension that declares scripts must now decide whether to include `deterministic:`, even if it has no CI adapter.
3. The classification itself is fragile. A script that is deterministic today (pure filesystem reads) may become interactive tomorrow (needs to prompt for disambiguation). The annotation becomes stale.

**Spec-kit's position**: The classification is useful information, but it belongs in the gh-aw adapter's configuration (e.g., `adapter.yml` listing which scripts to hoist), not in spec-kit's command frontmatter schema. The adapter already knows which scripts it wants to precompute -- it can maintain that list without polluting the command format. If a future spec-kit version adds native precomputation support, the annotation can be standardized then with proper schema evolution. Embedding it now creates a maintenance burden for a single adapter's optimization preference.

### Dispute 3: The two-channel context injection strategy obscures a priority question

All three revisions converged on a "two-channel" model: APM `.instructions.md` for ambient context, spec-kit frontmatter for command-time context. Spec-kit's own revision (New-1) endorsed this split and stated "neither channel is primary." APM's revision (Rec 4 Modified) agrees. This consensus is real but masks an unresolved operational question: what happens when the two channels conflict?

Consider a concrete scenario: APM's ambient instructions state "Files in `.specify/orchestrator/` use strict YAML frontmatter -- do not add freeform markdown above the frontmatter fence." A spec-kit command template for `plan-phase` includes a `## Context` section above the frontmatter that the agent should populate with narrative reasoning before writing the phase plan file. The ambient instruction says "no freeform markdown above the fence." The command template says "write freeform markdown above the fence." The agent must choose.

The "neither is primary" framing provides no tiebreaker. In practice, command-time context must override ambient context because the command has narrower, more specific intent. But this priority rule is not stated anywhere in the revised positions.

**Spec-kit's position**: The two-channel model is correct, but the plan must add an explicit priority rule: **command-time context (spec-kit frontmatter) overrides ambient context (APM instructions) when they conflict.** This is consistent with the specificity principle that governs CSS, DNS, and every other layered resolution system. Ambient context sets defaults; command context overrides them. Without this rule, the "two-channel" model is a description of the problem, not a solution. APM's revision should acknowledge this priority, and the plan should document it in the adapter interface contract.

### Dispute 4: Verification tier assignment is agreed in principle but unspecified in interface

All three revisions converged on a four-tier verification model: static checks (precomputation), command checks (spec-kit checklists), behavioral checks (gh-aw staged mode), and human review. This is good. But the convergence is at the conceptual level only -- no revision specifies the interface contract that makes it operational.

Specifically:
- **Who calls what?** The precomputation step (tier 1) runs before the agent. The checklist gate (tier 2) runs inside the agent session. Staged mode (tier 3) runs inside CI with `staged: true`. These three tiers have three different callers (CI runner, spec-kit command runner, gh-aw safe-outputs system). There is no documented sequence or data flow between them.
- **What is the failure protocol?** APM's revision (New-3) says R-006 scripts "run within the `before_commit` hook." gh-aw's revision (Rec 9 Modified) says staged mode is "advisory, not blocking -- a failing staged preview escalates to human review." Spec-kit's revision (Rec 7 Modified) says checklists are "the authoritative gate." But if tier 1 passes, tier 2 passes, and tier 3 fails (advisory), does the commit proceed? The answer depends on whether "advisory" means "logged but ignored" or "escalated and paused."
- **Where are results stored?** Each tier presumably writes results somewhere. The plan's `execution-log.jsonl` is append-only and could record all tier results, but no revision specifies the schema for verification entries.

**Spec-kit's position**: The four-tier model is the right architecture, but it needs a verification interface specification before implementation. At minimum: (1) an ordered sequence diagram showing which tier runs when relative to the command lifecycle, (2) a failure disposition for each tier (block, warn, escalate), and (3) a result schema for verification entries in the execution log. Without these, implementers will build four independent verification systems that happen to be labeled "tiers" -- exactly the "three overlapping systems" problem the convergence was meant to solve.

---

## Convergence

### Convergence 1: Working tree is canonical; repo-memory is durability sync

All three revisions independently arrived at the same state persistence model. gh-aw (Rec 3 Revised, New Rec A) defines the hydrate-execute-persist sequence. Spec-kit (New-5) states "the working tree is always canonical." APM (Rec 10 Withdrawn rationale) acknowledges that runtime-generated artifacts on repo-memory branches do not fit its link resolution model, implicitly endorsing working-tree canonicality. This is the most important architectural convergence in the process: the filesystem at `.specify/orchestrator/` is the single source of truth during execution, and every tool reads from and writes to it. The adapter is responsible for syncing to durable storage after execution completes. This resolves DC-1 from the cross-review phase definitively.

### Convergence 2: Spec-kit checklists are the primary verification gate

APM withdrew hooks (Rec 9) and explicitly named spec-kit checklists as "the right primary mechanism." gh-aw scoped staged mode to tier 3 (advisory behavioral preview). Spec-kit's revision assigns checklists to tier 2 (the authoritative gate for "is this phase ready to ship?"). All three revisions agree that `/speckit.implement` gating on checklist completion is the enforcement mechanism. The dispute above (Dispute 4) concerns the operational specification of this agreement, not the agreement itself.

### Convergence 3: Dual-path script invocation with adapter-chosen execution context

All three revisions converged on the same script invocation model: one script file, multiple invocation paths. Spec-kit frontmatter declares the script for local execution. APM registers it as an `apm run` alias for interactive use. gh-aw invokes it directly as an `on.steps:` precomputation step in CI. The script itself is context-agnostic -- same inputs (filesystem state), same outputs (derived state). The adapter chooses the invocation path appropriate to its runtime. This resolves the cross-review tension between spec-kit's frontmatter declaration and gh-aw's precomputation hoisting by recognizing they are complementary, not competing.

### Convergence 4: SKILL.md as a single package-level summary

APM (Rec 2 Modified) proposed a single summary-level `SKILL.md` that describes the orchestrator's overall capability, not per-command skill files. Spec-kit (New-2) reached the same position: one root-level `SKILL.md` listing all 10 commands with one-line descriptions, marked for future replacement by automated derivation. Neither gh-aw's revision objects. The parallel-hierarchy concern (10 individual SKILL files drifting from frontmatter) is avoided. The remaining gap -- automated `SKILL.md` generation from frontmatter -- is acknowledged as APM roadmap work, not a blocker for this extension.

### Convergence 5: The dependency matrix replaces "no runtime dependency" rhetoric

APM (Rec 8 Modified) proposed an explicit dependency matrix showing when each tool runs, what it is required for, and when it can be skipped. gh-aw (New Rec D) independently proposed the same three-column breakdown (runtime, build-time, CI runner). Spec-kit's revision does not contest either. The blanket "no APM runtime dependencies" and "no GSD-2 runtime dependencies" constraints are replaced by a precise statement of lifecycle dependencies. This eliminates the ambiguity that plagued the cross-review phase, where both APM and gh-aw claimed "no runtime dependency" while imposing build-time steps.

---

## Final Position Statement

The conversus process achieved what it was designed to achieve. Three tools with overlapping concerns -- distribution (APM), CI orchestration (gh-aw), and runtime command execution (spec-kit) -- entered the process with 30 recommendations that frequently contradicted each other. After cross-review and revision, the contradictions narrowed to four disputes, all of which are scoping and interface questions rather than architectural disagreements.

The five convergence points establish a solid architectural foundation:

1. The working tree is truth. Adapters sync; they do not own.
2. Spec-kit checklists gate readiness. Everything else is informational or supplementary.
3. Scripts are declared once, invoked through adapter-appropriate paths.
4. Discoverability metadata lives in one summary file, not a parallel hierarchy.
5. Dependencies are explicit and lifecycle-scoped, not hidden behind "no dependency" claims.

The four remaining disputes are real but bounded:

1. Config placement has a phantom consensus that must be resolved with a factual determination about APM's overwrite behavior.
2. The `deterministic` annotation is a good idea in the wrong location -- it belongs in adapter config, not command frontmatter.
3. The two-channel context model needs a priority rule, not just a partitioning scheme.
4. The verification tiers need an interface specification, not just a conceptual assignment.

None of these disputes block the plan's overall architecture. They block specific implementation details that must be resolved in the plan revision. My recommendation is to resolve them in order: Dispute 1 first (it affects file layout), Dispute 4 second (it affects the verification scripts), Dispute 3 third (it affects the context injection documentation), and Dispute 2 last (it is an optimization that can be deferred).

Spec-kit's role in this extension is clear: it is the runtime host. The orchestrator's commands execute through spec-kit's command runner, gate on spec-kit's checklists, fire spec-kit's hooks, and resolve paths through spec-kit's template system. APM distributes and compiles at install time. gh-aw adapts for CI. The boundaries are drawn. The remaining work is to specify the interfaces at those boundaries precisely enough that three independent implementations can interoperate without surprise.
