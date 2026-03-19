# spec-kit Utilization Review -- speckit-orchestrator

## Executive Summary

The speckit-orchestrator spec demonstrates strong understanding of spec-kit's SDD workflow and extension model at a conceptual level, but makes several assumptions about hook coverage that do not match the actual implementation. Spec-kit currently implements four hook points (before_tasks, after_tasks, before_implement, after_implement), not the "four available hook points" the spec cites -- which happens to be numerically correct but misleadingly implies coverage of the full SDD lifecycle. The spec's plan to use "command composition" for specify, clarify, and plan is the correct workaround, but the review below identifies concrete ways to deepen integration with templates, presets, the catalog system, and the constitution mechanism.

## Alignment (What We Are Getting Right)

- **Extension manifest requirement (spec line 281)**: The spec correctly identifies that the orchestrator "must be a valid spec-kit extension with an extension.yml manifest." This aligns with the extension system's core contract defined in `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 18-68) and `spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md` (lines 17-61).

- **Hook integration at task/implement boundaries (spec line 230)**: The spec correctly identifies the four implemented hook points: before_tasks, after_tasks, before_implement, after_implement. These are the exact hooks wired into the core command templates at `spec-kit/templates/commands/tasks.md` (lines 27-57, 100-127) and `spec-kit/templates/commands/implement.md` (lines 18-48, 174-201).

- **Command composition for hookless SDD steps (spec line 232-233)**: The spec acknowledges that specify, clarify, and plan lack native hooks and proposes wrapping those commands with orchestrator context injection. This is an accurate reading of the current state -- no hooks exist in `spec-kit/templates/commands/specify.md`, `spec-kit/templates/commands/clarify.md`, or `spec-kit/templates/commands/plan.md`.

- **Namespaced command pattern (spec line 281)**: The requirement for an extension.yml manifest means commands will follow the `speckit.{extension-id}.{command}` pattern as enforced by `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (line 44): `^speckit\.[a-z0-9-]+\.[a-z0-9-]+$`.

- **Disk-state-only architecture (spec lines 122, 285)**: The orchestrator's principle that "disk state is the sole source of truth" aligns well with spec-kit's own design where hook state, registry state, and template resolution are all file-based rather than in-memory.

- **Agent runtime agnosticism (spec line 234)**: The spec states the orchestrator "works with all spec-kit-supported agent runtimes without agent-specific code paths." This aligns with how spec-kit's `CommandRegistrar` in `spec-kit/src/specify_cli/agents.py` handles per-agent format conversion transparently, so extensions write universal Markdown commands and the registrar handles the rest.

- **Constitution as a governance input (spec lines 183, 304)**: The spec references the constitution file as a governing document for orchestrator behavior, which aligns with spec-kit's `/speckit.constitution` command and its storage at `.specify/memory/constitution.md`.

## Missed Opportunities

- **Template resolution stack not leveraged**: The orchestrator spec defines its own artifact templates (roadmap, phase summary, task summary, decisions register, knowledge file) but does not mention integrating with spec-kit's template resolution system. Spec-kit supports a four-tier resolution stack (overrides > presets > extensions > core) documented in `spec-kit/presets/ARCHITECTURE.md` (lines 9-36) and `spec-kit/presets/README.md` (lines 7-14). The orchestrator should register its templates (roadmap-template.md, phase-summary-template.md, etc.) through the extension's `templates/` directory so that presets can customize orchestrator artifacts without forking the extension. Currently, the spec makes no mention of templates at all.

- **Preset compatibility not addressed**: Presets can override both templates and commands at install time, as documented in `spec-kit/presets/README.md` (lines 22-24) and `spec-kit/presets/ARCHITECTURE.md` (lines 44-70). The orchestrator should be designed so its commands and templates are preset-overridable. For example, an organization could create a "compliance-orchestrator" preset that adds mandatory sign-off gates to phase reviews. The spec is silent on preset interaction.

- **Extension configuration system underutilized**: Spec-kit provides a layered configuration system (defaults in extension.yml > project config > local overrides > environment variables) as documented in `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 486-531) and `spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md` (lines 286-331). The orchestrator's `config.json` (spec line 224) should be implemented as spec-kit extension config (`orchestrator-config.yml` with a `.template.yml`) rather than a custom JSON file. This gives users layered overrides, environment variable injection (SPECKIT_ORCHESTRATOR_*), and local gitignored overrides for free.

- **Catalog and distribution not mentioned**: The spec lists "APM Packaging" as P8 priority (spec line 278) but does not mention spec-kit's own extension catalog system for distribution. The orchestrator should publish to the community catalog (`spec-kit/extensions/catalog.community.json`) and be installable via `specify extension add orchestrator`. See `spec-kit/extensions/README.md` (lines 97-138) and `spec-kit/extensions/EXTENSION-PUBLISHING-GUIDE.md` for the submission process.

- **The `before_commit` and `after_commit` hook events are not considered**: The API reference (`spec-kit/extensions/EXTENSION-API-REFERENCE.md`, lines 556-557) documents `before_commit` and `after_commit` events. The orchestrator could use `after_commit` to automatically update execution logs or trigger phase-boundary checks when a developer commits within an orchestrated phase. These hooks are documented but not yet wired into core command templates, so they would need to be treated as future integration points.

- **`/speckit.analyze` and `/speckit.checklist` not referenced**: The spec mentions the core SDD flow (specify > clarify > plan > tasks > implement) but does not reference `/speckit.analyze` (cross-artifact consistency and coverage analysis) or `/speckit.checklist` (quality validation). These are documented in the README (`spec-kit/README.md`, lines 320-322). The orchestrator's two-stage phase review (spec compliance + code quality) would be a natural place to invoke `/speckit.analyze` and `/speckit.checklist` as part of automated verification.

- **Extension `requires.commands` declaration**: The extension manifest schema allows declaring which core spec-kit commands the extension depends on (`spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md`, lines 37-38). The orchestrator should declare dependencies on all core SDD commands it wraps or invokes: `speckit.specify`, `speckit.clarify`, `speckit.plan`, `speckit.tasks`, `speckit.implement`.

- **Extension `requires.tools` for subagent dispatch**: The orchestrator's autonomous dispatch requires the ability to spawn subagent contexts. This is an external tool dependency that should be declared in the `requires.tools` section of extension.yml, per `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 36-41). This ensures `specify extension add orchestrator` warns users if their agent runtime lacks subagent support.

## Off-Base Assumptions

- **"Four available hook points" is misleadingly precise (spec line 230)**: The spec states hooks are available at "spec-kit's four available hook points (before_tasks, after_tasks, before_implement, after_implement)." While this is numerically accurate for the hooks currently wired into core command templates, the API reference at `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 554-557) also documents `before_commit` and `after_commit` as standard events. More importantly, the development guide at `spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md` (lines 199-200) marks `after_implement` as "(future)" in the hook point documentation, suggesting the hook system is still evolving. The spec should not treat the current hook count as fixed; it should design for hook expansion.

- **Orchestrator state directory placement (spec line 122, 206)**: The spec places all orchestrator state under `.specify/orchestrator/` and describes this as "separate from spec-kit's feature directories." However, spec-kit's extension system expects extension-specific state to live under `.specify/extensions/{extension-id}/` as documented in `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 784-810). Placing orchestrator state in a completely separate `.specify/orchestrator/` path breaks the self-contained extension convention. Extension config belongs in `.specify/extensions/orchestrator/`, and if the orchestrator needs feature-scoped state, it should be co-located with the feature spec directory (e.g., `.specify/specs/{feature}/orchestrator/`).

- **"Hook composition" is not a spec-kit concept (spec line 232)**: The spec describes "command composition -- for SDD steps without hooks (plan, specify, clarify), orchestrator commands wrap spec-kit commands, injecting orchestrator context before delegating." While this is a valid implementation approach, it is not an established pattern in spec-kit's extension model. Extensions provide new commands under their own namespace; they do not wrap or intercept core commands. The correct spec-kit mechanism for altering how core commands behave is through presets (`spec-kit/presets/README.md`, lines 22-24), which can override core command files at install time. The orchestrator should either (a) register its own parallel commands (e.g., `speckit.orchestrator.plan` that calls `/speckit.plan` internally) or (b) ship a companion preset that overrides the core commands to include orchestrator context injection.

- **Config as JSON (spec line 224)**: The spec describes `config.json` for orchestrator configuration. Spec-kit extensions use YAML configuration files (`{ext-id}-config.yml`) as the standard format, documented in `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 486-488) and `spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md` (lines 286-305). Using JSON would be inconsistent with the ecosystem and would not benefit from spec-kit's layered config resolution (project > local > env vars).

## Actionable Recommendations

1. **Register orchestrator templates in the extension's templates/ directory.** The roadmap template, phase-summary template, task-summary template, and decision-register template should be placed in the extension's `templates/` directory so they participate in spec-kit's template resolution stack. This enables preset-based customization.
   - Spec reference: lines 204-224 (file structure)
   - spec-kit reference: `spec-kit/presets/ARCHITECTURE.md` (lines 9-36)

2. **Replace `config.json` with `orchestrator-config.yml` and a `.template.yml`.** Use spec-kit's standard extension configuration system to get layered overrides, environment variable injection (`SPECKIT_ORCHESTRATOR_*`), and local gitignored overrides out of the box.
   - Spec reference: line 224 (config.json mention)
   - spec-kit reference: `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 486-531)

3. **Move extension-owned state from `.specify/orchestrator/` to `.specify/extensions/orchestrator/`.** For feature-scoped runtime state (roadmaps, phase summaries, execution logs), use `.specify/specs/{feature}/orchestrator/` to co-locate with spec-kit's feature directory convention.
   - Spec reference: lines 122, 206 (state directory)
   - spec-kit reference: `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 784-810)

4. **Use a companion preset instead of "command composition" for core command wrapping.** Ship a `speckit-orchestrator-preset` that overrides `/speckit.specify`, `/speckit.clarify`, and `/speckit.plan` to include orchestrator context preambles. This uses spec-kit's native override mechanism rather than inventing a wrapping pattern.
   - Spec reference: lines 232-233 (command composition)
   - spec-kit reference: `spec-kit/presets/README.md` (lines 22-24), `spec-kit/presets/scaffold/commands/speckit.specify.md`

5. **Declare `requires.commands` in extension.yml.** List all core SDD commands the orchestrator depends on: `speckit.specify`, `speckit.clarify`, `speckit.plan`, `speckit.tasks`, `speckit.implement`.
   - Spec reference: line 281 (valid spec-kit extension)
   - spec-kit reference: `spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md` (lines 37-38)

6. **Declare subagent dispatch as a `requires.tools` dependency.** Agent runtimes that support subagent spawning (e.g., Claude Code's `claude --continue`) should be declared as a required tool so users are warned during installation if their runtime cannot support autonomous dispatch.
   - Spec reference: lines 76-91 (autonomous dispatch)
   - spec-kit reference: `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 36-41)

7. **Integrate `/speckit.analyze` into the phase review stage.** The orchestrator's two-stage phase review (spec compliance, then code quality) should invoke `/speckit.analyze` for cross-artifact consistency checks as part of the spec compliance stage.
   - Spec reference: lines 113-119 (per-phase review)
   - spec-kit reference: `spec-kit/README.md` (lines 320-321)

8. **Publish to the spec-kit community catalog.** Rather than treating APM packaging (P8) as the primary distribution mechanism, the orchestrator should also be listed in the spec-kit community catalog for `specify extension add orchestrator` installation.
   - Spec reference: line 278 (P8 APM Packaging)
   - spec-kit reference: `spec-kit/extensions/README.md` (lines 97-138)

9. **Design hook registrations to be forward-compatible.** The extension.yml should register hooks at all four currently-wired points (before_tasks, after_tasks, before_implement, after_implement) and document that additional hooks (before_plan, after_plan, before_specify, after_specify) will be registered as spec-kit adds them. Avoid hardcoding the hook count.
   - Spec reference: line 230 (four hook points)
   - spec-kit reference: `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 554-557)

10. **Add `tags` for catalog discoverability.** The extension.yml should include tags such as `orchestration`, `autonomous`, `multi-phase`, `dispatch`, `knowledge-management` for catalog search.
    - Spec reference: line 281 (valid extension)
    - spec-kit reference: `spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md` (lines 57-61)

## Referenced spec-kit Documentation

- `spec-kit/README.md` -- Core SDD workflow, slash commands, extension/preset overview
- `spec-kit/AGENTS.md` -- Agent support matrix and integration guide
- `spec-kit/spec-driven.md` -- SDD methodology and philosophy
- `spec-kit/extensions/README.md` -- Extension catalog, community extensions, submission process
- `spec-kit/extensions/EXTENSION-API-REFERENCE.md` -- Manifest schema, Python API, hook system, CLI commands, file layout
- `spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md` -- Extension creation guide, hook points, config, testing
- `spec-kit/extensions/EXTENSION-USER-GUIDE.md` -- User-facing extension management
- `spec-kit/extensions/EXTENSION-PUBLISHING-GUIDE.md` -- Catalog submission process
- `spec-kit/extensions/RFC-EXTENSION-SYSTEM.md` -- Extension system design, architecture, resolved questions
- `spec-kit/extensions/template/extension.yml` -- Extension manifest template
- `spec-kit/extensions/selftest/extension.yml` -- Self-test extension example
- `spec-kit/presets/README.md` -- Preset system overview, stacking, resolution
- `spec-kit/presets/ARCHITECTURE.md` -- Template resolution stack, command registration, catalog system
- `spec-kit/templates/commands/tasks.md` -- Core tasks command with hook wiring
- `spec-kit/templates/commands/implement.md` -- Core implement command with hook wiring
- `spec-kit/src/specify_cli/extensions.py` -- Extension manager, hook executor implementation
