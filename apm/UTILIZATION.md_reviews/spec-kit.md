# APM Review of spec-kit's Recommendations

## Dangerous Contradictions

### DC-1: Recommendation 4 -- "Use a companion preset instead of command composition for core command wrapping"

spec-kit's recommendation 4 tells the orchestrator to ship a companion preset that overrides `/speckit.specify`, `/speckit.clarify`, and `/speckit.plan` with orchestrator context preambles. This directly conflicts with APM's context injection model.

APM already solves the "inject context before a command runs" problem through its compilation and primitive system. When the orchestrator's context artifacts are written as APM primitives (`.instructions.md` with `applyTo` patterns, `.context.md` files, `.prompt.md` workflows), `apm compile` produces optimized AGENTS.md/CLAUDE.md files that every agent runtime reads automatically -- including the agents that execute spec-kit commands. The context is already there when `/speckit.specify` runs; no command override is needed.

spec-kit's preset approach physically replaces core command template files at install time (`spec-kit/presets/README.md`, lines 22-24). This creates a hard fork of the SDD commands that embeds orchestrator-specific logic into spec-kit's own command layer. If APM's compilation also injects context (as our UTILIZATION review recommends), the agent would receive orchestrator context twice: once from the preset-overridden command template, once from the compiled AGENTS.md. Worse, the two injection paths would drift independently -- the preset is a static file replacement, while APM compilation dynamically optimizes context based on the current project structure.

**The conflict**: spec-kit wants to solve context injection by overriding command files at the spec-kit layer. APM wants to solve it by compiling optimized context at the project layer. Following both recommendations simultaneously produces duplication, drift, and unpredictable agent behavior.

**APM's position**: The orchestrator should use APM primitives for context injection (our recommendations 1, 2, 5) and register its own namespaced commands (`speckit.orchestrator.plan`, etc.) that invoke the unmodified core commands. Overriding core spec-kit commands via presets is unnecessary when APM compilation already delivers scoped context to every agent runtime.

- spec-kit reference: UTILIZATION.md recommendation 4 (lines 65-67)
- APM docs: `apm/docs/src/content/docs/guides/compilation.md` (lines 108-126, context optimization engine)
- APM docs: `apm/docs/src/content/docs/introduction/key-concepts.md` (lines 131-145, `applyTo` pattern targeting)

### DC-2: Recommendation 2 -- "Replace config.json with orchestrator-config.yml using spec-kit's extension config system"

spec-kit recommends the orchestrator use spec-kit's layered configuration system (`orchestrator-config.yml` with `.template.yml`) to get layered overrides, environment variable injection (`SPECKIT_ORCHESTRATOR_*`), and local gitignored overrides.

APM has its own configuration system centered on `apm.yml` (manifest schema, `apm/docs/src/content/docs/reference/manifest-schema.md`) with compilation settings, dependency declarations, and script definitions. If the orchestrator is eventually packaged as an APM package (P8), its configuration must be expressible through `apm.yml` fields -- either directly or via the package's own `apm.yml` that consumers inherit.

Locking the orchestrator's configuration into spec-kit's extension config format creates a hard dependency on spec-kit's config resolution at setup time. This means APM cannot manage or override orchestrator settings through its own dependency/compilation pipeline. For example, an org package (`apm/docs/src/content/docs/guides/org-packages.md`) that distributes orchestrator defaults across repositories would need to ship spec-kit YAML config files rather than APM primitives -- breaking APM's single-manifest model where `apm.yml` is the contract between package authors, runtimes, and integrators.

**The conflict**: spec-kit wants orchestrator config in its own YAML format with its own resolution stack. APM wants all package configuration expressible through `apm.yml` and its primitive system. The orchestrator cannot serve two configuration masters.

**APM's position**: The orchestrator should use a format that both systems can consume. At minimum, runtime-relevant settings (verification commands, dispatch budgets, git isolation) should be expressible as APM primitive frontmatter or `apm.yml` fields, with spec-kit's extension config used only for spec-kit-specific integration points (hook registrations, template overrides). The spec's original `config.json` is actually more neutral than either tool's proprietary format.

- spec-kit reference: UTILIZATION.md recommendation 2 (lines 57-59)
- APM docs: `apm/docs/src/content/docs/reference/manifest-schema.md` (section 2, document structure; section 3, top-level fields)

### DC-3: Recommendation 3 -- "Move extension-owned state from .specify/orchestrator/ to .specify/extensions/orchestrator/"

spec-kit recommends moving all orchestrator state into `.specify/extensions/orchestrator/` for extension convention compliance, with feature-scoped state in `.specify/specs/{feature}/orchestrator/`.

APM's UTILIZATION review (recommendation 9) recommends the opposite direction: mirroring consumable orchestrator artifacts into `.apm/context/orchestrator/` so APM's primitive discovery (`apm/docs/src/content/docs/reference/primitive-types.md`, lines 49-57) can find and compile them. APM discovers primitives in `.apm/` and `apm_modules/` -- it does not scan `.specify/` at all.

If the orchestrator follows spec-kit's recommendation and buries all state under `.specify/extensions/orchestrator/`, none of those artifacts -- phase summaries, decisions register, knowledge file -- will be discoverable by APM. They will be invisible to `apm compile`, invisible to APM's link resolution system, and invisible to any agent runtime that reads APM-produced context files.

**The conflict**: spec-kit wants state under `.specify/`. APM wants consumable artifacts under `.apm/`. Following spec-kit's recommendation without also following APM's mirroring recommendation (our recommendation 9) means APM is completely blind to orchestrator context. The orchestrator's knowledge management -- the feature that compounds value across phases -- would be accessible only to agents that happen to know the `.specify/` path convention.

**APM's position**: The orchestrator's internal runtime state (lock files, execution logs, continue files) can live wherever spec-kit conventions dictate. But agent-consumable context (phase summaries, decisions register, knowledge file, boundary maps) must also be present under `.apm/context/` or linked there, so APM compilation can optimize and distribute them. Both recommendations can coexist, but spec-kit's recommendation alone is insufficient.

- spec-kit reference: UTILIZATION.md recommendation 3 (lines 61-63)
- APM docs: `apm/docs/src/content/docs/introduction/key-concepts.md` (lines 86-125, file structure and discovery paths)
- APM UTILIZATION review: recommendation 9 (line 65)


## Tensions

### T-1: Recommendation 8 -- "Publish to the spec-kit community catalog" vs. APM as the distribution mechanism

spec-kit recommends publishing the orchestrator to the spec-kit community catalog (`specify extension add orchestrator`) and suggests this should take priority over APM packaging (P8). APM's UTILIZATION review treats P8 as the final distribution step but emphasizes APM primitives should be used from P1 onward.

Both distribution channels can coexist, but they create a divergent user experience. A user who installs via `specify extension add orchestrator` gets the spec-kit extension with spec-kit's config system and spec-kit's template resolution. A user who installs via `apm install org/speckit-orchestrator` gets APM primitives, APM compilation, APM lockfile tracking, and APM's multi-runtime deployment. The two installation paths would produce different file layouts, different configuration mechanisms, and potentially different behavior.

**The tension**: Neither tool is wrong to want to be the distribution channel. The risk is that the orchestrator ships two parallel installation paths that diverge over time. The mitigation is to ensure one is authoritative (likely spec-kit's `extension add` for the extension machinery, APM for the context primitives) and the other delegates.

- spec-kit reference: UTILIZATION.md recommendation 8 (lines 81-83)
- APM UTILIZATION review: recommendation 8 (line 63)

### T-2: Recommendation 1 -- "Register orchestrator templates in the extension's templates/ directory" vs. APM primitive types

spec-kit recommends the orchestrator register its templates (roadmap, phase-summary, task-summary, decision-register) through spec-kit's template resolution stack (overrides > presets > extensions > core). This enables preset-based customization through spec-kit's mechanism.

APM's UTILIZATION review recommends writing these same artifacts as APM primitive types: phase summaries as `.context.md`, boundary maps as `SKILL.md`, dispatch payloads as `.prompt.md` (our recommendations 1-3). APM's primitive system has its own override mechanism -- local primitives always override dependency primitives, with declaration-order priority for conflicts (`apm/docs/src/content/docs/reference/primitive-types.md`, lines 15-16).

Both override systems would apply to the same conceptual artifacts. A user who customizes the roadmap template via a spec-kit preset would not see that customization reflected in APM's compiled output, because APM reads its own `.context.md` files, not spec-kit's resolved templates. Conversely, a user who overrides via APM's local primitive priority would not affect spec-kit's template resolution.

**The tension**: Both tools offer customization/override mechanisms for the same artifacts. The orchestrator must pick a primary owner for each artifact type and document which override system applies. The most natural split: spec-kit owns the templates (the shapes of documents before they are filled in), APM owns the filled artifacts (the actual context consumed by agents).

- spec-kit reference: UTILIZATION.md recommendation 1 (lines 53-55)
- APM UTILIZATION review: recommendations 1-3 (lines 49-53)

### T-3: Recommendation 9 -- "Design hook registrations to be forward-compatible" and hook expansion

spec-kit recommends the orchestrator register hooks at all four currently-wired points and prepare for future hooks (before_plan, after_plan, before_specify, after_specify). This is reasonable advice for a spec-kit extension.

The tension with APM arises because APM has its own hook system for lifecycle events (`PreToolUse`, `PostToolUse`, `Stop`, `Notification`, `SubagentStop` -- see `apm/docs/src/content/docs/introduction/key-concepts.md`, lines 352-382). If the orchestrator registers hooks in both systems, the interaction between spec-kit hooks (which fire at SDD workflow boundaries) and APM hooks (which fire at tool-use boundaries within agent execution) becomes complex. A `before_implement` spec-kit hook that injects context could interact unpredictably with an APM `PreToolUse` hook that validates tool inputs.

**The tension**: The two hook systems operate at different abstraction levels (SDD workflow steps vs. agent tool invocations). They are not inherently conflicting, but the orchestrator must clearly document which hooks fire when, and ensure that APM hook-deployed scripts (which get rewritten and placed by APM's hook integrator) do not interfere with spec-kit hook-deployed scripts. The risk increases as both hook systems expand.

- spec-kit reference: UTILIZATION.md recommendation 9 (lines 85-87)
- APM docs: `apm/docs/src/content/docs/introduction/key-concepts.md` (lines 352-382, hook system)

### T-4: Recommendation 6 -- "Declare subagent dispatch as a requires.tools dependency"

spec-kit recommends declaring subagent dispatch capability as a `requires.tools` dependency in the extension manifest, so users are warned during `specify extension add` if their runtime cannot support autonomous dispatch.

APM does not have an equivalent capability-declaration mechanism in `apm.yml`. When the orchestrator is distributed as an APM package (P8), APM's install process will not check whether the consumer's agent runtime supports subagent spawning. The capability warning would only fire through spec-kit's installation path.

**The tension**: This creates an asymmetric user experience. Users installing via spec-kit get warned about missing capabilities; users installing via APM do not. The mitigation is straightforward -- the orchestrator's `SKILL.md` (which APM installs) should prominently document the runtime requirement, and APM could evolve to support a `requires` field in `apm.yml` in the future. This is not dangerous, just incomplete.

- spec-kit reference: UTILIZATION.md recommendation 6 (lines 73-75)
- APM docs: `apm/docs/src/content/docs/reference/manifest-schema.md` (no `requires` field exists)


## Synergies

### S-1: Recommendation 5 -- "Declare requires.commands in extension.yml"

spec-kit's recommendation to declare dependencies on core SDD commands (`speckit.specify`, `speckit.clarify`, `speckit.plan`, `speckit.tasks`, `speckit.implement`) in the extension manifest is fully compatible with APM. APM's own dependency system operates at the package level, not the command level. Having spec-kit validate command-level dependencies at extension install time provides a safety layer that APM's coarser-grained package dependencies cannot. The two dependency checks are complementary: spec-kit validates that the right commands exist, APM validates that the right context packages are resolved.

### S-2: Recommendation 7 -- "Integrate /speckit.analyze into the phase review stage"

spec-kit recommends invoking `/speckit.analyze` for cross-artifact consistency checks during the orchestrator's two-stage phase review. This aligns well with APM's model because `/speckit.analyze` would consume the same compiled context that APM produces. If the orchestrator writes phase summaries as `.context.md` files (per APM recommendation 2) and boundary maps as `SKILL.md` files (per APM recommendation 3), `/speckit.analyze` would be validating artifacts that are already integrated into APM's context graph. The analysis results could then feed back as `.context.md` entries for downstream phases.

### S-3: Recommendation 10 -- "Add tags for catalog discoverability"

Adding tags like `orchestration`, `autonomous`, `multi-phase` to the extension manifest is harmless from APM's perspective and actively helpful. When the orchestrator is packaged as an APM hybrid package (our recommendation 8), the `apm.yml` description field serves the same discoverability purpose. Having rich metadata in both manifests (`extension.yml` for spec-kit catalog, `apm.yml` for APM ecosystem) makes the package findable through both channels.

### S-4: The "disk state is the sole source of truth" principle

Both reviews identify this as a strength. spec-kit's extension system is file-based; APM's lockfile, primitive discovery, and compilation are all file-based. The orchestrator's commitment to deriving state from disk (spec line 122) means both tools can observe and act on the same filesystem without coordination. APM can compile orchestrator artifacts that spec-kit placed on disk, and spec-kit can read APM-deployed primitives from `.apm/` and `apm_modules/`. This shared architectural principle is the foundation that makes coexistence possible.

### S-5: Recommendation on before_commit/after_commit hooks

spec-kit identifies `before_commit` and `after_commit` as documented but not-yet-wired hooks. APM's hook integrator already handles `PostToolUse` events that can match on `write_file` tool invocations. The two hook systems serve different levels of the stack. spec-kit's commit hooks would fire at SDD workflow milestones; APM's tool-use hooks fire during agent execution. Both are useful. The orchestrator could use spec-kit's `after_commit` to update execution logs and APM's `PostToolUse` hooks to enforce phase scope restrictions -- the two systems complement rather than replace each other.


## Verdict

Of spec-kit's 10 recommendations:

| # | Recommendation | Assessment | Risk Level |
|---|---|---|---|
| 1 | Register templates in extension templates/ | Tension (T-2) -- needs clear ownership split between template shapes vs. filled artifacts | Low-Medium |
| 2 | Replace config.json with spec-kit extension config | Dangerous (DC-2) -- creates config system conflict with APM's manifest model | High |
| 3 | Move state to .specify/extensions/orchestrator/ | Dangerous (DC-3) -- makes orchestrator context invisible to APM unless mirrored | High |
| 4 | Use companion preset for command wrapping | Dangerous (DC-1) -- duplicates APM's context injection, creates drift | High |
| 5 | Declare requires.commands | Synergy (S-1) -- complements APM's package-level deps | Safe |
| 6 | Declare subagent dispatch as requires.tools | Tension (T-4) -- asymmetric UX between install paths, not dangerous | Low |
| 7 | Integrate /speckit.analyze into phase review | Synergy (S-2) -- strengthens APM's context artifacts | Safe |
| 8 | Publish to spec-kit community catalog | Tension (T-1) -- dual distribution paths need careful coordination | Medium |
| 9 | Design hooks for forward-compatibility | Tension (T-3) -- two hook systems must be documented clearly | Low-Medium |
| 10 | Add tags for catalog discoverability | Synergy (S-3) -- harmless, helpful for both ecosystems | Safe |

**Summary**: 3 recommendations are safe (5, 7, 10). 4 carry manageable tension (1, 6, 8, 9). 3 are dangerous contradictions (2, 3, 4) that would actively undermine APM's context management, compilation, and distribution model if followed without also implementing APM's corresponding recommendations.

The most critical finding: spec-kit's recommendations 2, 3, and 4 collectively push all orchestrator configuration, state, and context injection into spec-kit's proprietary systems. If adopted without the APM mirroring and primitive-authoring recommendations, the orchestrator would be a pure spec-kit extension with no APM integration surface -- making P8 (APM Packaging) a hollow wrapper rather than the deep integration APM's context optimization engine can provide. The orchestrator spec's authors should treat APM and spec-kit as co-equal integration targets and ensure neither tool's recommendations subsume the other's.
