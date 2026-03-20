# APM Cross-Review of Spec-Kit's Review

**Cross-Reviewer**: APM (Agent Package Manager)
**Target Review**: spec-kit's review of speckit-orchestrator implementation plan
**Date**: 2026-03-19

---

## Dangerous Contradictions

### 1. Config File Placement: Both Reviews Agree It Should Move, But to Incompatible Locations

**Spec-kit says** (Off-Base Assumptions #2):
> "Move `orchestrator-config.yml` to `.specify/extensions/orchestrator/orchestrator-config.yml`. This follows spec-kit's config convention... spec-kit's own install process preserves user config files -- `ExtensionManager.install_from_directory()` handles this."

**APM says** (Alignment, Config Outside APM Radius):
> "User-mutable config (`orchestrator-config.yml`, `orchestrator-config.local.yml`) is explicitly placed outside APM-managed directories, with the constraint 'User-mutable config MUST NOT reside in APM-managed directories (FR-070)' at line 126. This directly addresses the APM-overwrite problem."

**Why this is dangerous**: Spec-kit wants config inside `.specify/extensions/orchestrator/`, claiming its install process preserves user config. APM's deployment model is always-overwrite -- `apm install` replaces the contents of the target directory. The plan's AD-7 explicitly states `.specify/extensions/orchestrator/` is the "APM/extension deployment target (overwritten on install)." If the team follows spec-kit's recommendation and moves config there, `apm install --update` will destroy user configuration. Spec-kit's `ExtensionManager.install_from_directory()` may preserve config, but APM's integrator does not -- it overwrites. The dual installation path (quickstart.md lines 12-20) means both install mechanisms must be safe. Placing config inside the APM deployment radius breaks one of the two advertised install paths.

**Resolution required**: Either (a) APM's integrator must learn to preserve designated config files during install (feature work), (b) spec-kit's install path becomes the only supported path (contradicts quickstart), or (c) config stays at project root as the plan currently specifies and spec-kit documents this as an accepted deviation from convention.

---

### 2. SKILL.md: Derive at Install Time vs. Author Manually -- Neither Reviewer's Path Exists Today

**Spec-kit says** (Missed Opportunity #1):
> "The plan ignores spec-kit's existing `handoffs` frontmatter mechanism... The orchestrator's command composition model (R-010: 'orchestrator commands wrapping spec-kit commands') reinvents this."

Spec-kit does not directly address the SKILL.md question, implicitly accepting AD-6's "command frontmatter as single source" by focusing on how commands should use spec-kit's own frontmatter fields (`handoffs`, `scripts`, `$ARGUMENTS`).

**APM says** (Off-Base Assumptions #1):
> "The plan states 'APM derives skill metadata from command frontmatter at install time.' This is not how APM currently works. APM's skill integration copies existing `SKILL.md` files... APM does not have a facility to synthesize `SKILL.md` from non-SKILL frontmatter at install time."

**Why this is dangerous**: AD-6 is listed as a unanimous convergence point across all three tool perspectives. But APM's own review reveals the "derive at install time" capability does not exist. Meanwhile, spec-kit's review accepts command frontmatter as authoritative and pushes for deeper use of spec-kit-native frontmatter fields (`handoffs`, `scripts`, `$ARGUMENTS`) -- none of which map to APM's `SKILL.md` format. If the team builds the extension relying on AD-6, they get zero skill discoverability through APM because the derivation pipeline is missing. If they follow APM's recommendation to author a manual `SKILL.md`, they create the parallel hierarchy that spec-kit and gh-aw rejected in the conversus process. The "unanimous convergence" on AD-6 was built on a false premise about APM's capabilities.

**Resolution required**: Either (a) APM builds the frontmatter-to-SKILL.md derivation feature before the orchestrator ships, (b) a single root-level `SKILL.md` is authored as a summary document (not per-command, avoiding the parallel hierarchy problem), or (c) the team accepts that APM skill discoverability is deferred to a later release.

---

### 3. `.instructions.md` Role: "Supplementary" vs. "Primary Mechanism" -- Opposite Recommendations

**Spec-kit says** (Missed Opportunity #6, implicitly via checklist integration):
> "Phase must-haves could be expressed as checklists, enabling both human and mechanical verification through the existing system."

Spec-kit's review does not recommend `.instructions.md` at all -- it pushes all guidance through spec-kit's own primitives (frontmatter fields, checklists, templates, hooks). The plan's D2 position ("supplementary, not primary... avoids soft APM runtime dependency per spec-kit's position") aligns with spec-kit's stance.

**APM says** (Off-Base Assumptions #2):
> "This mischaracterizes the relationship. APM instructions are deployed by `apm install` into `.github/instructions/` or equivalent target directories... The `.instructions.md` files are static assets, not a runtime dependency. The plan's concern about 'soft APM runtime dependency' conflates install-time integration with runtime dependency. Instructions could serve as the orchestrator's primary mechanism for injecting file-pattern-scoped guidance."

**Why this is dangerous**: APM recommends `.instructions.md` as a primary mechanism for scope-filtered context (P2 recommendation #4). Spec-kit's entire review pushes in the opposite direction -- use spec-kit frontmatter, checklists, and templates as the primary guidance channel. If the team follows APM's recommendation, the orchestrator's guidance lives in `.github/instructions/` files that spec-kit's template resolution stack cannot see. If they follow spec-kit's recommendation, agents that natively consume `.instructions.md` (Copilot, Claude Code) miss the scope-filtered guidance. The two systems have non-overlapping visibility: spec-kit templates are visible to the spec-kit command runner; APM instructions are visible to the AI agent's native instruction loader. The orchestrator needs both, but neither review acknowledges the other's distribution channel.

**Resolution required**: Explicitly document a two-channel strategy: spec-kit frontmatter/templates for command-time guidance (what the agent sees when running a slash command), APM `.instructions.md` for ambient guidance (what the agent sees when editing files in the orchestrator's state directory). Neither is "primary" -- they serve different moments in the execution lifecycle.

---

### 4. Hook Count: 4 vs. 6 -- Verification Integration at Commit Time

**Spec-kit says** (Off-Base Assumptions #1):
> "The plan claims 4 hook points but names them inconsistently with spec-kit's actual implementation... the EXTENSION-API-REFERENCE.md also lists `before_commit` and `after_commit` (line 556-557), meaning there are potentially 6 hook points, not 4."

**APM says** (Alignment, implicitly accepting the plan's 4-hook model):
> APM's review does not question the hook count. It accepts R-010's 4-hook integration and instead suggests supplementing with APM's own `PostToolUse` hooks (P3 recommendation #9): "For agents that support APM hooks natively (Claude, Copilot), register `PostToolUse` hooks on `write_file` events to trigger lightweight verification checks."

**Why this is dangerous**: The orchestrator's verification architecture (R-006) needs a commit-time gate. Spec-kit says this gate already exists natively via `before_commit` / `after_commit` hooks. APM suggests building a parallel gate via `PostToolUse` hooks on file writes. If both are implemented, verification runs twice at different granularities with potentially conflicting results. If neither is implemented (because each reviewer assumes the other's mechanism is "supplementary"), the commit-time verification gap persists. More critically, spec-kit's `before_commit` hook could block commits when must-haves fail, while APM's `PostToolUse` hook fires per file write -- these are fundamentally different enforcement points with different failure semantics (blocking commit vs. warning after write).

**Resolution required**: Choose one commit-time verification mechanism as canonical. Spec-kit's `before_commit` is the natural fit since the orchestrator is a spec-kit extension first (AD-1). APM's `PostToolUse` hooks, if used at all, should serve as early-warning signals, not enforcement gates.

---

## Productive Tensions

### 1. Custom Scripts vs. Platform Primitives

Spec-kit identifies 9 missed opportunities where the orchestrator reinvents spec-kit capabilities (`handoffs`, `scripts` frontmatter, `agent_scripts`, `$ARGUMENTS`, `requires.commands`, checklists, template overrides, `.extensionignore`, `config_schema`). APM identifies 8 missed opportunities where the orchestrator reinvents APM capabilities (compilation, instructions, context linking, scripts, hooks, lockfile, package type, target config).

Both reviews are correct. The orchestrator's ~20 custom bash scripts implement functionality that partially exists in both platforms. The tension is productive because each platform's primitives cover a different slice of the problem. Spec-kit's frontmatter fields solve command-time metadata; APM's compilation solves context assembly; neither alone replaces the full `build-context.sh` + `scope-filter.sh` pipeline. The resolution is not "pick one platform's primitives" but "map each custom script to the platform primitive that best fits, and keep custom code only for orchestrator-specific logic that neither platform addresses."

### 2. Extension Purity vs. Distribution Richness

Spec-kit's review consistently pushes for deeper integration with spec-kit's native mechanisms -- every recommendation routes through spec-kit's extension system. APM's review consistently pushes for richer APM manifest utilization -- scripts, compilation, instructions, lockfile. The tension: the more deeply the orchestrator integrates with spec-kit primitives, the less value APM's distribution model adds beyond file copying. Conversely, the richer the APM manifest, the more the extension looks like an APM package that happens to run in spec-kit -- exactly what AD-1 prohibits.

This tension is healthy. It forces the team to draw a clear line: spec-kit owns runtime behavior (commands, hooks, templates, checklists). APM owns distribution behavior (install, update, lock, compile context for non-spec-kit agents). Custom scripts own orchestrator-specific logic (state derivation, dispatch payload assembly, scope filtering). Each domain has a clear owner.

### 3. Condition-Based vs. Prompt-Based Hook Gating

Spec-kit flags (Off-Base Assumptions #4) that hook `condition` expressions are NOT evaluated by LLMs -- hooks with non-empty conditions are skipped. The orchestrator must use `optional: true` with descriptive prompt text for gating, not the `condition` field. APM's review does not flag this at all, instead suggesting additional APM hooks as supplementary gates. The tension: the orchestrator needs reliable gating (only fire hooks when orchestration is active), but the two reviews surface different gating mechanisms (spec-kit's prompt-based gating vs. APM's event-based hooks) without acknowledging that the underlying gating problem is the same. This forces an explicit design for "how does the orchestrator decide whether to activate" that works across both hook systems.

### 4. Quickstart Installation Path

Spec-kit correctly flags (Off-Base Assumptions #3) that `specify extension add speckit-orchestrator` assumes catalog availability and should lead with `--dev` for initial development. APM's review flags (P1 recommendation #1) that without a concrete `apm.yml`, the `apm install` path is non-functional. Both are saying the quickstart advertises install paths that do not work today, but from different angles. The productive tension: the quickstart needs to be honest about what works now (`--dev` local install) vs. what works later (catalog + APM), and the plan needs to sequence manifest work (both `extension.yml` and `apm.yml`) before claiming either install path is functional.

### 5. Template Overridability

Spec-kit recommends (Missed Opportunity #7) making the orchestrator's 15 templates overridable through spec-kit's template resolution stack. APM recommends (P3 recommendation #10) formatting knowledge artifacts as `.context.md` for cross-tool discoverability. Both want the orchestrator's outputs to be customizable and discoverable, but through incompatible mechanisms. Spec-kit's template resolution stack is spec-kit-specific; APM's context linking is APM-specific. A template that participates in spec-kit's resolution stack cannot simultaneously be a `.context.md` that APM's link resolver traverses. The tension forces a decision: which artifacts are templates (customizable) and which are context (linkable)?

---

## Safe Agreements

### 1. Deployment Boundary Separation Is Correct and Non-Negotiable

Both reviews explicitly validate AD-7's strict separation between `.specify/extensions/orchestrator/` (deployment target, overwritable) and `.specify/orchestrator/` (runtime state, never touched by install).

**Spec-kit** (Alignment #3): "Extension deployment directory boundary (AD-7) correctly separates concerns... mirrors spec-kit's own separation of `.specify/extensions/` (managed by install) from `.specify/memory/` (managed at runtime)."

**APM** (Alignment #1): "The strict separation between `.specify/extensions/orchestrator/` (APM-managed deployment target, overwritten on install) and `.specify/orchestrator/` (runtime state, never touched by install) correctly accounts for APM's always-overwrite deployment semantics. This is the single most important APM concern and the plan gets it right."

This is the foundational architectural decision and both platforms confirm it works for their respective install/update models.

### 2. AD-1 (Spec-Kit Extension First) Is the Correct Organizational Principle

Both reviews accept that the orchestrator is a spec-kit extension that APM distributes, not the reverse.

**Spec-kit** (Alignment #6): "AD-5 prohibition on core command overrides respects spec-kit's preset/extension boundary... The orchestrator correctly positions itself as an extension adding new commands, not a preset overriding core templates."

**APM** (Alignment #4): "The decision that skill metadata lives in command markdown frontmatter and APM derives `SKILL.md` at install time is a pragmatic resolution." And (Alignment #6): "The resolution -- committed extension is default, APM-managed is supported but not canonical -- correctly positions APM's value as upgrade management and dependency resolution rather than runtime control."

This agreement means the team can confidently build the extension to spec-kit's conventions first and layer APM distribution support on top, without needing to reconcile conflicting organizational models.

### 3. Multi-Layer Config Precedence Is Sound

Both reviews validate R-004's four-level config precedence (env vars > local override > project config > extension defaults).

**Spec-kit** (Alignment #4): "Multi-layer config precedence aligns with spec-kit's documented pattern... match the config layers in EXTENSION-API-REFERENCE.md."

**APM** (Alignment #2): "User-mutable config... is explicitly placed outside APM-managed directories... This directly addresses the APM-overwrite problem."

The disagreement is about where the config file lives (Dangerous Contradiction #1), not about the precedence model itself. The four-layer resolution order is safe to implement as specified.

---

## Summary

The most urgent integration risk is **config file placement** (Contradiction #1): spec-kit and APM give directly opposing recommendations, and following the wrong one breaks one of the two advertised install paths. The second-most urgent is the **SKILL.md derivation gap** (Contradiction #2): a "unanimous" architecture decision rests on a capability that does not exist in APM today. Both require explicit decisions before implementation begins.

The productive tensions point toward a clear ownership model: spec-kit owns runtime, APM owns distribution, custom scripts own orchestrator-specific logic. Drawing this line explicitly will resolve most of the "missed opportunity" items from both reviews by making it clear which platform's primitive applies to each concern.
