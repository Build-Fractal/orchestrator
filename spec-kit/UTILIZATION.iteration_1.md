# spec-kit Utilization Review -- Reviewed & Revised

## Executive Summary

The original review identified 10 actionable recommendations for aligning the speckit-orchestrator spec with spec-kit's extension model, template resolution, preset system, configuration conventions, and catalog distribution. The cross-review by APM and gh-aw exposed a consistent blind spot: the original recommendations were written from a spec-kit-centric perspective and did not account for the orchestrator living at the intersection of three tools with overlapping jurisdiction over context injection, configuration, state layout, and distribution.

Three recommendations are withdrawn (Rec 2, 3, 4). These were the most prescriptive -- they told the orchestrator to move state, replace config formats, and override core commands using spec-kit's proprietary mechanisms. Both APM and gh-aw independently flagged these as dangerous, for different but reinforcing reasons: APM cannot see artifacts buried in `.specify/`, and gh-aw cannot cache artifacts scattered across feature directories. The lesson is clear: spec-kit should not claim exclusive ownership of orchestrator state, config, or command behavior when the orchestrator must serve all three ecosystems.

Four recommendations are modified (Rec 1, 6, 8, 9) to explicitly acknowledge multi-tool constraints. Three survive unchanged (Rec 5, 7, 10) -- both reviewers marked these as safe or synergistic.

---

## Recommendation Status

### Rec 1: Register orchestrator templates in the extension's templates/ directory

**Original**: Place roadmap, phase-summary, task-summary, and decision-register templates in the extension's `templates/` directory so they participate in spec-kit's four-tier resolution stack and enable preset-based customization.

**APM says**: Tension (T-2). APM's primitive system has its own override mechanism (local primitives override dependency primitives). A user who customizes a template via a spec-kit preset would not see that change reflected in APM's compiled output, and vice versa. APM proposes a split: spec-kit owns template shapes (before fill), APM owns filled artifacts (actual context consumed by agents).

**gh-aw says**: Tension. In CI, the workspace is a fresh checkout. Template resolution that depends on locally installed presets or user-level overrides may not be available unless the workflow's `steps:` block explicitly installs spec-kit extensions. Template customization via presets creates an invisible maintenance surface for CI verification.

**Revised position**: MODIFY. The recommendation stands in principle -- orchestrator templates should be registered in the extension's `templates/` directory to participate in spec-kit's resolution stack. However, the recommendation must be narrowed in scope. The templates registered here are structural templates (the shapes of documents before they are filled in), not the filled runtime artifacts. The spec should document that: (a) spec-kit's resolution stack governs template shapes, (b) filled artifacts live at a location accessible to all three tools (see Rec 3 withdrawal), and (c) CI workflows using gh-aw must include extension installation in their `steps:` block if they depend on preset-customized templates.

---

### Rec 2: Replace config.json with orchestrator-config.yml and a .template.yml

**Original**: Use spec-kit's standard extension configuration system to get layered overrides, environment variable injection (`SPECKIT_ORCHESTRATOR_*`), and local gitignored overrides.

**APM says**: Dangerous (DC-2). Locking the orchestrator's configuration into spec-kit's extension config format creates a hard dependency on spec-kit's config resolution. APM cannot manage or override orchestrator settings through its own dependency/compilation pipeline. The orchestrator cannot serve two configuration masters. APM argues the spec's original `config.json` is actually more neutral than either tool's proprietary format.

**gh-aw says**: Tension. gh-aw workflows pass configuration via frontmatter fields, `steps:` blocks, and `workflow_dispatch` inputs -- not via spec-kit's layered config resolution. There is no "local override" layer in CI (the runner is ephemeral), and env var injection happens through GitHub Actions secrets, not through `SPECKIT_ORCHESTRATOR_*`.

**Revised position**: WITHDRAW. Both reviewers independently identified that this recommendation locks the orchestrator into spec-kit's configuration ecosystem in a way that creates real problems for APM's manifest model and gh-aw's CI execution model. APM is right that the original `config.json` (or a format-neutral YAML/JSON file that both tools can consume) is a better starting point than spec-kit's proprietary layered config system. The orchestrator should use a neutral configuration format that can be consumed by spec-kit's extension config resolver, APM's primitive frontmatter, and gh-aw's frontmatter/environment mechanism without requiring any single tool's resolution stack as a hard dependency.

---

### Rec 3: Move extension-owned state from .specify/orchestrator/ to .specify/extensions/orchestrator/

**Original**: Follow spec-kit's extension convention for state placement. Extension-scoped state goes to `.specify/extensions/orchestrator/`, feature-scoped runtime state goes to `.specify/specs/{feature}/orchestrator/`.

**APM says**: Dangerous (DC-3). APM discovers primitives in `.apm/` and `apm_modules/` -- it does not scan `.specify/` at all. If the orchestrator buries all state under `.specify/extensions/orchestrator/`, none of those artifacts will be discoverable by APM compilation, link resolution, or any agent runtime reading APM-produced context. APM's position: internal runtime state can live wherever spec-kit conventions dictate, but agent-consumable context must also be present under `.apm/context/` or linked there.

**gh-aw says**: Dangerous. gh-aw's `cache-memory` tool persists directory subtrees as GitHub Actions cache artifacts between workflow runs. This works cleanly when orchestrator state lives in a single, predictable directory tree (`.specify/orchestrator/`) that can be cached as a unit. Scattering state across `.specify/extensions/orchestrator/`, `.specify/specs/feature-a/orchestrator/`, `.specify/specs/feature-b/orchestrator/` makes cache configuration fragile -- each feature needs its own cache entry, cache keys become dynamic, and restoration requires discovery logic. gh-aw's position: the spec's current single-directory approach is the correct design for CI compatibility.

**Revised position**: WITHDRAW. This was the recommendation where both reviewers were most aligned in their opposition, and they are right. The original recommendation prioritized spec-kit convention compliance over practical multi-tool accessibility. The orchestrator's state should remain in a single, predictable directory tree (`.specify/orchestrator/` as the spec originally proposed) for two reasons: (1) gh-aw can cache it as a unit with stable keys, and (2) APM can mirror or symlink agent-consumable artifacts from that known location into `.apm/context/`. Scattering state across feature directories to follow spec-kit's extension convention would create real problems for both CI caching and APM primitive discovery. The spec-kit extension convention was designed for extensions whose state is only consumed through spec-kit's own resolution -- the orchestrator's state has a wider audience.

---

### Rec 4: Use a companion preset instead of command composition for core command wrapping

**Original**: Ship a `speckit-orchestrator-preset` that overrides `/speckit.specify`, `/speckit.clarify`, and `/speckit.plan` to include orchestrator context preambles, using spec-kit's native override mechanism.

**APM says**: Dangerous (DC-1). APM already solves context injection through its compilation and primitive system. A preset that physically replaces core command template files creates a hard fork that embeds orchestrator-specific logic into spec-kit's command layer. If APM also injects context, agents receive it twice -- once from the preset-overridden template, once from compiled AGENTS.md. The two injection paths drift independently. APM's position: use namespaced commands (`speckit.orchestrator.plan`, etc.) that invoke unmodified core commands.

**gh-aw says**: Dangerous. If a preset silently overrides what `/speckit.specify` or `/speckit.plan` does at install time, the CI workflow cannot reason about what those commands will actually execute. gh-aw's `steps:` and `post-steps:` depend on knowing exactly what runs between them. A preset that rewrites core command behavior introduces invisible mutation that breaks gh-aw's verification model. gh-aw's position: use namespaced commands that make behavior visible and auditable.

**Revised position**: WITHDRAW. This was the most unanimously opposed recommendation. Both reviewers flagged it as dangerous for completely different reasons -- APM because it duplicates context injection, gh-aw because it breaks deterministic verification -- and both arrived at the same alternative: use namespaced commands. The original recommendation even acknowledged this as option (a) ("register its own parallel commands, e.g., `speckit.orchestrator.plan` that calls `/speckit.plan` internally") before recommending option (b) (the preset approach). The cross-review makes clear that option (a) is the correct path. The orchestrator should register `speckit.orchestrator.specify`, `speckit.orchestrator.clarify`, and `speckit.orchestrator.plan` as namespaced commands that invoke the unmodified core commands with orchestrator context injected. No preset, no command overriding.

---

### Rec 5: Declare requires.commands in extension.yml

**Original**: List all core SDD commands the orchestrator depends on (`speckit.specify`, `speckit.clarify`, `speckit.plan`, `speckit.tasks`, `speckit.implement`) in the extension manifest.

**APM says**: Synergy (S-1). APM's dependency system operates at the package level, not the command level. Having spec-kit validate command-level dependencies at install time provides a safety layer that APM's coarser-grained package dependencies cannot. The two checks are complementary.

**gh-aw says**: Synergy. Explicit command dependencies make it possible for a gh-aw workflow's `steps:` block to validate that the spec-kit installation has all required commands before the agent starts, enabling fast failure rather than mid-execution discovery.

**Revised position**: STAND. Both reviewers marked this as safe and synergistic. No modification needed.

---

### Rec 6: Declare subagent dispatch as a requires.tools dependency

**Original**: Declare subagent dispatch capability (e.g., Claude Code's `claude --continue`) as a `requires.tools` dependency in extension.yml so users are warned during installation if their runtime lacks subagent support.

**APM says**: Tension (T-4). APM has no equivalent capability-declaration mechanism in `apm.yml`. Users installing via APM would not receive the same warning. This creates asymmetric UX between install paths. Not dangerous, just incomplete.

**gh-aw says**: Tension. In CI, "subagent dispatch" works differently -- gh-aw provides `call-workflow` and `dispatch-workflow` as its dispatch primitives, which are fundamentally different from spawning a local subprocess. The `requires.tools` declaration would correctly warn local users but says nothing about CI dispatch capabilities.

**Revised position**: MODIFY. The recommendation stands for the spec-kit installation path -- declaring `requires.tools` for subagent dispatch is the right thing for local users. However, the spec should acknowledge that: (a) this warning only fires through spec-kit's `specify extension add` path, not through APM installation, and (b) CI dispatch via gh-aw uses a fundamentally different mechanism (`call-workflow`/`dispatch-workflow`) that is not covered by `requires.tools`. The orchestrator should document local vs. CI dispatch as distinct capability requirements, and the `requires.tools` declaration should be framed as covering the local case only.

---

### Rec 7: Integrate /speckit.analyze into the phase review stage

**Original**: Invoke `/speckit.analyze` for cross-artifact consistency checks during the orchestrator's spec compliance review stage.

**APM says**: Synergy (S-2). If the orchestrator writes phase summaries as APM `.context.md` files and boundary maps as `SKILL.md` files, `/speckit.analyze` would be validating artifacts already integrated into APM's context graph. Analysis results could feed back as `.context.md` entries for downstream phases.

**gh-aw says**: Synergy. If `/speckit.analyze` is a well-defined command with a predictable exit code, it is an ideal candidate for gh-aw's `post-steps:` verification block. This moves the orchestrator toward concrete, invokable verification commands rather than agent judgment.

**Revised position**: STAND. Both reviewers marked this as synergistic. No modification needed. This recommendation actually strengthens both APM's context validation loop and gh-aw's deterministic verification layer.

---

### Rec 8: Publish to the spec-kit community catalog

**Original**: Publish the orchestrator to the spec-kit community catalog for `specify extension add orchestrator` installation, rather than treating APM packaging (P8) as the primary distribution mechanism.

**APM says**: Tension (T-1). Both distribution channels can coexist, but they create divergent user experiences. A user who installs via `specify extension add` gets spec-kit's config system and template resolution. A user who installs via `apm install` gets APM primitives, compilation, and lockfile tracking. The two paths would produce different file layouts and potentially different behavior.

**gh-aw says**: Tension. CI workflows that depend on the orchestrator need one canonical installation path. Having two competing channels without a clear "CI canonical" choice creates confusion for workflow authors.

**Revised position**: MODIFY. The recommendation to publish to the spec-kit catalog stands -- the orchestrator is a spec-kit extension and should be discoverable through spec-kit's native channel. However, the original recommendation's framing ("rather than treating APM packaging as the primary distribution mechanism") was wrong. The revised position: publish to both channels, but document which is authoritative for what. The spec-kit catalog is authoritative for the extension machinery (commands, hooks, template registration). APM is authoritative for context primitives (compiled context, skill files, prompt workflows). For CI via gh-aw, the spec should document a single canonical installation sequence in the workflow's `steps:` block that covers both.

---

### Rec 9: Design hook registrations to be forward-compatible

**Original**: Register hooks at all four currently-wired points and document that additional hooks will be registered as spec-kit adds them. Avoid hardcoding the hook count.

**APM says**: Tension (T-3). APM has its own hook system (`PreToolUse`, `PostToolUse`, `Stop`, etc.) operating at a different abstraction level (agent tool invocations vs. SDD workflow steps). A `before_implement` spec-kit hook could interact unpredictably with an APM `PreToolUse` hook. The two hook systems must be clearly documented to avoid interference.

**gh-aw says**: Synergy. More hooks at SDD lifecycle boundaries means more natural points for gh-aw's `steps:`/`post-steps:` verification mapping.

**Revised position**: MODIFY. The recommendation stands in principle -- the orchestrator should absolutely design for hook expansion rather than hardcoding the current count. The modification: the spec should explicitly document that spec-kit hooks operate at the SDD workflow level (before/after plan, specify, clarify, tasks, implement) while APM hooks operate at the agent tool-use level (PreToolUse, PostToolUse). These are complementary, not competing, but the orchestrator must document which hooks fire when so that users deploying both APM and spec-kit hook scripts can reason about execution order. The spec should include a hook interaction matrix showing where both systems' hooks could fire during a single orchestrator operation.

---

### Rec 10: Add tags for catalog discoverability

**Original**: Include tags such as `orchestration`, `autonomous`, `multi-phase`, `dispatch`, `knowledge-management` in the extension.yml.

**APM says**: Synergy (S-3). Harmless and helpful. Rich metadata in both manifests (`extension.yml` for spec-kit catalog, `apm.yml` for APM ecosystem) makes the package findable through both channels.

**gh-aw says**: Synergy. Better discoverability helps gh-aw workflow authors find and install the extension. Neutral for CI execution.

**Revised position**: STAND. Both reviewers marked this as safe. No modification needed.

---

## Withdrawn Recommendations

### Rec 2: Replace config.json with orchestrator-config.yml

Withdrawn because the recommendation locked the orchestrator into spec-kit's proprietary configuration resolution stack, creating hard conflicts with APM's manifest model and gh-aw's CI configuration mechanism. The orchestrator should use a format-neutral configuration file that can be consumed by all three tools without requiring any single tool's resolution chain as a dependency.

### Rec 3: Move state to .specify/extensions/orchestrator/

Withdrawn because scattering state across spec-kit's extension and feature directory conventions makes the orchestrator invisible to APM's primitive discovery and breaks gh-aw's static cache-key model. The spec's original single-directory approach (`.specify/orchestrator/`) is superior for multi-tool compatibility.

### Rec 4: Use a companion preset for core command wrapping

Withdrawn because silently overriding core SDD commands via presets duplicates APM's context injection (causing double-injection and drift) and breaks gh-aw's deterministic verification boundaries (making it impossible to audit what a command actually executes). Both reviewers independently recommended the same alternative: namespaced commands.

---

## Modified Recommendations

### Rec 1 (Modified): Register orchestrator templates in the extension's templates/ directory

**What changed**: Scope narrowed. The extension's `templates/` directory should contain structural templates only (document shapes before fill-in). The recommendation now explicitly states that: (a) spec-kit's resolution stack governs template shapes, not filled runtime artifacts, (b) filled artifacts live at a location accessible to all three tools, and (c) CI workflows must include extension installation in their `steps:` block when depending on preset-customized templates.

### Rec 6 (Modified): Declare subagent dispatch as a requires.tools dependency

**What changed**: Scope clarified. The `requires.tools` declaration covers the local execution path only. The spec must document that CI dispatch via gh-aw uses a fundamentally different mechanism (`call-workflow`/`dispatch-workflow`) not covered by this declaration. The orchestrator should document local vs. CI dispatch as distinct capability requirements.

### Rec 8 (Modified): Publish to the spec-kit community catalog

**What changed**: Framing corrected. The original recommendation positioned spec-kit's catalog as an alternative to APM packaging. The revised position: publish to both channels with documented authority boundaries. Spec-kit catalog is authoritative for extension machinery (commands, hooks, templates). APM is authoritative for context primitives. For CI, document a single canonical installation sequence.

### Rec 9 (Modified): Design hook registrations to be forward-compatible

**What changed**: Multi-system awareness added. The recommendation now requires the spec to document that spec-kit hooks and APM hooks operate at different abstraction levels (SDD workflow vs. agent tool-use) and include a hook interaction matrix showing where both systems' hooks could fire during a single orchestrator operation.

---

## Surviving Recommendations

### Rec 5: Declare requires.commands in extension.yml

Both reviewers marked this as synergistic. spec-kit validates command-level dependencies at install time, APM validates package-level dependencies. The two checks are complementary and non-overlapping. gh-aw benefits from the explicit dependency list for deterministic pre-checks in `steps:` blocks.

### Rec 7: Integrate /speckit.analyze into the phase review stage

Both reviewers marked this as synergistic. APM benefits because `/speckit.analyze` validates artifacts already in APM's context graph. gh-aw benefits because a concrete command with a predictable exit code maps cleanly to `post-steps:` verification blocks. This recommendation strengthens the orchestrator's value proposition for all three tools.

### Rec 10: Add tags for catalog discoverability

Both reviewers marked this as safe and complementary. Tags in `extension.yml` serve spec-kit's catalog; equivalent metadata in `apm.yml` serves APM's ecosystem. No conflict, no modification needed.

---

## Lessons Learned

**1. spec-kit's extension conventions assume spec-kit is the only consumer.** The extension system's state layout (`.specify/extensions/{id}/`), configuration system (layered YAML with `SPECKIT_*` env vars), and command override mechanism (presets replacing core command files) were all designed for a world where spec-kit is the sole tool managing the developer's workflow. When the orchestrator must also serve APM's primitive discovery and gh-aw's CI execution model, those conventions create real conflicts. The review should have evaluated each recommendation against the question: "Does this make the orchestrator less accessible to tools that are not spec-kit?"

**2. The most dangerous recommendations were the most "correct" from a single-tool perspective.** Recs 2, 3, and 4 were all textbook-correct advice for building a well-behaved spec-kit extension. They followed the documented conventions, used the intended mechanisms, and would produce a clean integration within spec-kit's ecosystem. The problem is that textbook-correct advice for one tool can be actively harmful when the artifact lives in a multi-tool environment. This is the central tension the original review missed entirely.

**3. Both reviewers converged on "namespaced commands over command overrides."** APM arrived at this conclusion from a context-injection deduplication angle. gh-aw arrived at it from a deterministic-verification angle. When two tools with completely different architectures and concerns both reject the same recommendation and propose the same alternative, that is a strong signal. The original review should have given more weight to option (a) in Rec 4 rather than recommending option (b).

**4. State layout is a multi-tool coordination problem, not a convention compliance problem.** The original review treated state layout as a question of following spec-kit's extension conventions. The cross-review revealed it is actually a question of which tools need to read that state and how they discover files. APM discovers via `.apm/`, gh-aw discovers via static cache keys, and spec-kit discovers via `.specify/`. A single directory tree at a well-known location, with tool-specific mirroring or symlinking as needed, is more practical than conforming to any one tool's preferred layout.

**5. CI execution is a first-class constraint, not an afterthought.** The original review made zero mentions of CI execution. gh-aw's review made clear that CI runners are ephemeral, cache keys must be static, configuration injection works differently, and command behavior must be auditable. Any recommendation that assumes a persistent local development environment -- layered config overrides, installed presets, user-level template overrides -- needs a documented CI fallback path. Future reviews should explicitly evaluate each recommendation against the CI execution model.
