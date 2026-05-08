# UTILIZATION.md -- Spec-Kit Capability Review

**Spec under review**: `specs/001-orchestrator/spec.md`
**Reviewer perspective**: spec-kit extension system (the framework the orchestrator extends)
**Date**: 2026-03-18

---

## 1. Executive Summary

The speckit-orchestrator spec proposes an ambitious multi-phase autonomous orchestration extension built on top of spec-kit's Spec-Driven Development workflow. The spec demonstrates strong familiarity with spec-kit's extension manifest schema, hook system, and command naming conventions. It correctly identifies the hybrid integration strategy -- hooks at the four available lifecycle points plus command composition for steps that lack hooks -- which is the most architecturally sound approach available in the current extension system.

However, the spec treats spec-kit's extension system primarily as a command delivery mechanism and hook attachment surface. It underutilizes several substantive capabilities: the preset system for template customization, the template resolution stack for layered artifact generation, the configuration management infrastructure with multi-layer precedence, and the community catalog ecosystem for distribution. The spec also makes a few assumptions about hook system capabilities and command composition patterns that are either not supported by the current implementation or are subtly incorrect.

The gap between the spec's stated ambitions (autonomous multi-milestone orchestration with crash recovery, knowledge compounding, and cross-phase coordination) and its engagement with spec-kit's actual extension infrastructure suggests that while the *what* is well-defined, the *how it integrates with spec-kit* needs deeper grounding in the framework's documented APIs. The orchestrator will be one of the most complex extensions ever built for spec-kit, and it needs to take full advantage of the scaffolding the framework provides rather than reinventing parallel infrastructure.

---

## 2. Alignment (What the Spec Gets Right)

- **Extension manifest compliance (FR-031, line 263; spec-kit `extensions/EXTENSION-API-REFERENCE.md` manifest schema)**: The spec correctly requires a valid `extension.yml` following schema version 1.0, with `speckit.orchestrator.*` namespaced commands matching the pattern `^speckit\.[a-z0-9-]+\.[a-z0-9-]+$`. This directly aligns with the validation rules documented in the API reference.

- **Hybrid hook + command composition strategy (spec lines 455, 475; spec-kit `extensions/EXTENSION-API-REFERENCE.md` Hook System, `templates/commands/tasks.md` hook execution blocks)**: The spec correctly identifies that spec-kit provides exactly 4 hook points (`before_tasks`, `after_tasks`, `before_implement`, `after_implement`) and that the `specify`, `plan`, and `clarify` commands lack hooks. The hybrid approach -- hooks where available, command composition elsewhere -- is the only viable architecture given the current hook surface. The spec's requirement that hook commands "check whether orchestration is active and no-op when it is not" (line 475) correctly follows the pattern established in spec-kit's hook execution model where hooks are optional and conditional.

- **Multi-agent compatibility (FR-032, line 264; spec-kit `AGENTS.md` supported agents table)**: The spec correctly requires working across all spec-kit-supported agents (17+ agents) without agent-specific code paths. This aligns with spec-kit's universal command format design where commands are authored in Markdown and converted to agent-specific formats (Markdown, TOML, Copilot agent format) by the `CommandRegistrar` during registration.

- **Separate state tree (FR-019, line 230; spec-kit `extensions/EXTENSION-API-REFERENCE.md` file system layout)**: Placing orchestrator state at `.specify/orchestrator/` separate from `specs/` is sound and follows spec-kit's existing convention where extensions store their state under `.specify/extensions/{ext-id}/` and core artifacts live in `specs/`. The spec correctly recognizes that spec artifacts and orchestrator state serve different purposes and should not be co-located.

- **Disk-only state (spec line 477; spec-kit `spec-driven.md` core principles)**: The "state on disk is truth" principle aligns directly with spec-kit's SDD philosophy where specifications are the source of truth and all artifacts are version-controlled. The file-presence-based state machine (FR-020) is architecturally consistent with how spec-kit derives status from file existence (e.g., `check-prerequisites.sh` checks for `tasks.md`, `plan.md` existence).

- **Zero overhead for Tier A (FR-003, line 186; spec-kit standard workflow)**: Correctly routing small work directly to standard spec-kit commands without additional ceremony respects the principle that spec-kit should work with minimal overhead for simple projects. This prevents the extension from degrading the experience for work that doesn't need orchestration.

---

## 3. Missed Opportunities

- **Preset system for template customization (spec-kit `presets/README.md`, `presets/ARCHITECTURE.md`)**: The spec defines elaborate output formats for summaries, roadmaps, phase plans, decisions registers, and knowledge files (lines 380-420) but never considers using spec-kit's preset system to distribute these templates. A `speckit-orchestrator` preset could override `spec-template`, `plan-template`, and `tasks-template` with orchestrator-aware versions, using the template resolution stack (`presets > extensions > core`). This would let the orchestrator customize how specs and plans are generated *through spec-kit's own template machinery* rather than via parallel file generation. The preset system explicitly supports extension template overrides at priority level 3 in the resolution stack (see `presets/ARCHITECTURE.md` line 34).

- **Extension-provided templates via the resolution stack (spec-kit `presets/ARCHITECTURE.md` lines 17-19, `extensions/RFC-EXTENSION-SYSTEM.md` template resolution)**: Extensions can provide templates that sit in the resolution stack between presets and core templates. The orchestrator's roadmap template, phase plan template, task plan template, and summary templates could all be registered as extension templates at `.specify/extensions/orchestrator/templates/`, making them overridable by project-specific presets or local overrides. This is a documented capability the spec does not reference at all.

- **Configuration management infrastructure (spec-kit `extensions/EXTENSION-API-REFERENCE.md` Configuration Schema, lines 481-531; `extensions/EXTENSION-DEVELOPMENT-GUIDE.md` config loading)**: The spec defines first-run configuration (FR-040, line 284) and references a `config.json` file, but does not leverage spec-kit's multi-layer configuration system: extension defaults in `extension.yml` `defaults` section, project config (`orchestrator-config.yml`), local overrides (`orchestrator-config.local.yml`, gitignored), and environment variable overrides (`SPECKIT_ORCHESTRATOR_*`). This infrastructure is already built and documented. The spec should use it rather than inventing a parallel `config.json` approach.

- **`config_schema` for validation (spec-kit `extensions/EXTENSION-DEVELOPMENT-GUIDE.md` line 219, `extensions/RFC-EXTENSION-SYSTEM.md` manifest spec)**: The extension manifest supports an optional `config_schema` field (JSON Schema) for validating extension configuration. Given the orchestrator's complex configuration surface (tier overrides, verification commands, context verbosity, git isolation, dispatch/duration budgets per FR-040/FR-050/FR-065), a schema would provide validation at install time and catch misconfiguration before it surfaces as runtime failures.

- **`requires.commands` field (spec-kit `extensions/EXTENSION-DEVELOPMENT-GUIDE.md` line 37)**: The extension manifest supports declaring dependencies on core spec-kit commands via `requires.commands`. The orchestrator depends heavily on `speckit.tasks`, `speckit.plan`, `speckit.specify`, `speckit.clarify`, `speckit.implement`, and `speckit.analyze`. Declaring these dependencies would allow the extension system to validate that the required commands are present before installation, preventing broken installs.

- **Command aliases (spec-kit `extensions/EXTENSION-API-REFERENCE.md` line 47, `extensions/template/extension.yml` line 51)**: The extension manifest supports `aliases` for commands. The orchestrator commands (e.g., `speckit.orchestrator.triage`, `speckit.orchestrator.status`) could benefit from shorter aliases (e.g., `speckit.triage`, `speckit.orc-status`) for ergonomic daily use. The spec does not mention aliases at all.

- **`.extensionignore` for clean distribution (spec-kit `extensions/EXTENSION-DEVELOPMENT-GUIDE.md` lines 335-393)**: Given the orchestrator's skill folder structure with scripts, templates, references, and configuration (FR-028, line 258), an `.extensionignore` file would exclude development artifacts (tests, CI configs, research docs) from the installed extension. The spec does not consider distribution packaging.

- **`condition` field on hooks (spec-kit `extensions/EXTENSION-API-REFERENCE.md` line 61)**: The hook system supports an optional `condition` field for conditional execution. The spec correctly notes that hooks should no-op when orchestration is not active (line 475), but could use the `condition` field to express this declaratively (e.g., `condition: ".specify/orchestrator exists"`) rather than requiring each hook command to implement its own activation check. This is a future capability noted in the docs but worth designing for.

- **Community catalog listing for discoverability (spec-kit `extensions/EXTENSION-PUBLISHING-GUIDE.md`, `extensions/catalog.community.json`)**: The spec mentions APM packaging (US8) and manual spec-kit extension install as distribution paths but does not consider submission to spec-kit's community extension catalog (`catalog.community.json`), which is the primary discovery mechanism for spec-kit extensions. Given the orchestrator extends spec-kit directly, catalog presence would make it discoverable via `specify extension search orchestrator`.

---

## 4. Off-Base Assumptions

- **Hook points `before_tasks` and `before_implement` may not exist as first-class hook events (spec lines 263, 475; spec-kit `extensions/EXTENSION-API-REFERENCE.md` Hook Events, line 552; `templates/commands/tasks.md` and `templates/commands/implement.md` hook execution blocks)**: The API reference documents standard hook events as `after_tasks`, `after_implement`, `before_commit`, and `after_commit` (API Reference line 552). The core command templates for `tasks.md` and `implement.md` *do* contain code that reads `hooks.before_tasks` and `hooks.before_implement` from `.specify/extensions.yml`, so these events are functional in practice. However, the API reference does not list them as standard events, and the `extension.yml` schema documentation only shows `after_tasks` and `after_implement` as hook events in the development guide (lines 198-200). The spec should acknowledge this discrepancy and verify that `before_*` hooks are fully supported in the manifest validation, not just in the command template parsing. If they are only supported via the `.specify/extensions.yml` config file and not in the `extension.yml` manifest's `hooks` section, the registration path would differ from what the spec assumes.

- **Skill folder architecture is orthogonal to the extension system (FR-028, line 258; spec-kit extension model)**: The spec requires that "each orchestrator command MUST be packaged as a skill folder containing: a trigger-phrased skill description, helper scripts, output templates, reference documents, and a user preferences configuration file." Spec-kit's extension model packages commands as individual markdown files in a `commands/` directory (see `extensions/EXTENSION-DEVELOPMENT-GUIDE.md` line 69, `extensions/template/` structure). The "skill folder" concept with trigger-phrased descriptions, gotchas sections, and progressive-disclosure references is an APM/GSD-2 pattern, not a spec-kit pattern. The extension system has no notion of "skill folders" -- it has commands, config, hooks, and scripts. The spec needs to reconcile this: either map the skill folder concept onto spec-kit's command + config + scripts model, or acknowledge that the skill architecture requires a layer on top of spec-kit's extension primitives.

- **Command composition via wrapping is not a documented extension pattern (spec lines 455, 475; spec-kit extension docs)**: The spec assumes the orchestrator can "wrap" core spec-kit commands (specify, plan, clarify) via command composition. The extension system does not document a command wrapping or composition mechanism. What it *does* support is: (a) extensions providing entirely new commands, and (b) presets overriding existing commands via the preset template resolution stack (see `presets/ARCHITECTURE.md` command registration flow). To actually wrap `/speckit.plan`, the orchestrator would either need to: provide a `speckit.orchestrator.plan` command that internally instructs the LLM to first execute orchestrator logic then delegate to the standard plan workflow, or use a preset to override `speckit.plan` itself. The spec should clarify which mechanism is intended, because they have very different implications for user workflow (one is a new command, the other replaces the existing one).

---

## 5. Actionable Recommendations

1. **Leverage spec-kit's configuration infrastructure instead of custom `config.json`**: Replace the custom configuration approach (FR-040, FR-041) with the documented multi-layer config system. Create an `orchestrator-config.yml` template deployed to `.specify/extensions/orchestrator/`, use `defaults` in `extension.yml` for sane defaults, support `.local.yml` overrides for developer preferences, and `SPECKIT_ORCHESTRATOR_*` env vars for CI overrides. Reference: `extensions/EXTENSION-API-REFERENCE.md` "Configuration Schema" section (lines 481-531) and `extensions/EXTENSION-DEVELOPMENT-GUIDE.md` "Configuration Files" (lines 285-330).

2. **Provide a companion preset for template overrides**: Create a `speckit-orchestrator` preset that overrides `spec-template`, `plan-template`, and `tasks-template` with orchestrator-aware versions. When the orchestrator is active and a Tier B/C project is in progress, these templates would include orchestrator context (milestone reference, phase scope, boundary map section). Install the preset alongside the extension. Reference: `presets/README.md` and `presets/scaffold/preset.yml`.

3. **Register orchestrator output templates as extension templates**: Roadmap, phase plan, task plan, phase summary, and task summary templates should be placed in `.specify/extensions/orchestrator/templates/` so they participate in spec-kit's template resolution stack. This allows projects to override orchestrator templates via local overrides or presets without forking the extension. Reference: `presets/ARCHITECTURE.md` resolution stack (lines 9-18).

4. **Declare `requires.commands` in the extension manifest**: Add `requires.commands` listing `speckit.tasks`, `speckit.plan`, `speckit.specify`, `speckit.clarify`, `speckit.implement`, and `speckit.analyze` to ensure the extension system validates that the necessary core commands are present. Reference: `extensions/EXTENSION-DEVELOPMENT-GUIDE.md` line 37.

5. **Add `config_schema` to the extension manifest**: Define a JSON Schema for orchestrator configuration covering: `default_tier` (enum: A/B/C/null), `verification_commands` (array of strings), `context_verbosity` (enum: minimal/standard/full), `git_isolation` (boolean), `dispatch_budget` (integer or null), `duration_budget` (string or null). This enables validation during `specify extension add`. Reference: `extensions/EXTENSION-DEVELOPMENT-GUIDE.md` line 219.

6. **Verify `before_tasks` and `before_implement` hook support in the manifest schema**: Confirm that the extension system's manifest validation accepts `before_tasks` and `before_implement` as valid hook event names, not just `after_tasks` and `after_implement`. The core command templates parse these events, but the API reference and development guide only document the `after_*` variants as standard events. If manifest-level registration is not supported for `before_*` events, the spec needs to document an alternative registration path (e.g., direct `.specify/extensions.yml` configuration). Reference: `extensions/EXTENSION-API-REFERENCE.md` Hook Events (line 552), compare with `templates/commands/tasks.md` pre-execution hook blocks (lines 26-57).

7. **Reconcile skill folder architecture with spec-kit's command model**: Map the skill folder concept (FR-028) onto spec-kit's extension primitives: (a) the trigger-phrased skill description becomes the command's `description` field with trigger-phrase wording per FR-029, (b) helper scripts go in the extension's `scripts/` directory and are referenced via the command frontmatter's `scripts` field, (c) output templates go in the extension's `templates/` directory and participate in the resolution stack, (d) reference documents go in the extension's `docs/` directory, (e) user preferences configuration uses the extension config system. Eliminate the parallel "skill folder" abstraction and map directly to what spec-kit provides. Reference: `extensions/EXTENSION-DEVELOPMENT-GUIDE.md` command file format (lines 225-278), extension directory structure from `extensions/EXTENSION-API-REFERENCE.md` file system layout (lines 784-811).

8. **Clarify the command composition mechanism**: The spec should specify whether orchestrator wrapping of `specify`, `plan`, and `clarify` means: (a) new `speckit.orchestrator.specify` commands that internally instruct the LLM to run the standard spec-kit workflow with added orchestrator context (new commands coexisting with originals), or (b) preset-based overrides that replace the standard `speckit.specify` command with an orchestrator-augmented version (replacing originals). Option (a) is simpler and less disruptive; option (b) requires a companion preset and affects the user's muscle memory. If using option (a), the command file should include explicit delegation instructions (e.g., "After orchestrator context injection, follow the standard `/speckit.plan` workflow"). Reference: `presets/ARCHITECTURE.md` command registration (lines 44-76).

9. **Define command aliases for ergonomic access**: Add `aliases` to the extension manifest for frequently-used commands. For example: `speckit.orchestrator.triage` could alias to `speckit.triage`, `speckit.orchestrator.status` to `speckit.status`, `speckit.orchestrator.go` to `speckit.go`. Keep aliases short while avoiding collisions with other extensions. Reference: `extensions/EXTENSION-API-REFERENCE.md` line 47.

10. **Plan for community catalog submission**: Include in the implementation plan a step to submit the orchestrator to `catalog.community.json` once stable. This makes it discoverable via `specify extension search` for all spec-kit users without requiring APM. The submission checklist from the publishing guide should be a post-v1.0 task. Reference: `extensions/EXTENSION-PUBLISHING-GUIDE.md` full guide.

---

## 6. Referenced spec-kit Documentation

| Document | Path | Cited For |
|----------|------|-----------|
| Extension API Reference | `spec-kit/extensions/EXTENSION-API-REFERENCE.md` | Manifest schema, hook events, command format, config schema, file system layout |
| Extension Development Guide | `spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md` | Command file format, config files, `.extensionignore`, `requires.commands`, `config_schema`, testing |
| Extension User Guide | `spec-kit/extensions/EXTENSION-USER-GUIDE.md` | Config layers, hook usage, extension lifecycle |
| Extension Publishing Guide | `spec-kit/extensions/EXTENSION-PUBLISHING-GUIDE.md` | Community catalog submission, distribution |
| RFC Extension System | `spec-kit/extensions/RFC-EXTENSION-SYSTEM.md` | Hook system design, command registration, config management, template resolution |
| Extension Template | `spec-kit/extensions/template/extension.yml` | Manifest structure, aliases, hooks, config, tags, defaults |
| Extensions README | `spec-kit/extensions/README.md` | Catalog system, community extensions list |
| Presets README | `spec-kit/presets/README.md` | Template overrides, command overrides, stacking, resolution |
| Presets Architecture | `spec-kit/presets/ARCHITECTURE.md` | Template resolution stack, command registration flow, extension safety check |
| Preset Scaffold | `spec-kit/presets/scaffold/preset.yml` | Preset manifest structure, template + command entries |
| AGENTS.md | `spec-kit/AGENTS.md` | Supported agents, command file formats, directory conventions |
| Spec-Driven Development | `spec-kit/spec-driven.md` | SDD philosophy, command workflow, template-driven quality |
| README.md | `spec-kit/README.md` | Overall framework overview, extension system introduction |
| Core Command: tasks.md | `spec-kit/templates/commands/tasks.md` | Hook execution blocks (before_tasks, after_tasks), task generation workflow |
| Core Command: implement.md | `spec-kit/templates/commands/implement.md` | Hook execution blocks (before_implement, after_implement), implementation workflow |
| Core Command: specify.md | `spec-kit/templates/commands/specify.md` | Spec creation workflow, script integration, handoffs |
| Core Command: plan.md | `spec-kit/templates/commands/plan.md` | Planning workflow, agent context update, phases |
| Core Command: analyze.md | `spec-kit/templates/commands/analyze.md` | Cross-artifact consistency analysis, constitution authority |
| Core Command: checklist.md | `spec-kit/templates/commands/checklist.md` | Requirements quality validation, checklist generation |
| Spec Template | `spec-kit/templates/spec-template.md` | Spec structure, user story format, requirements format |
| Plan Template | `spec-kit/templates/plan-template.md` | Plan structure, constitution check, project structure |
| Selftest Extension | `spec-kit/extensions/selftest/extension.yml` | Real-world minimal extension example |
