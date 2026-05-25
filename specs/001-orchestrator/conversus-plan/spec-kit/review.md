# Spec-Kit Perspective Review: Speckit-Orchestrator Implementation Plan

**Reviewer**: spec-kit (extension system, commands, hooks, templates, configuration)
**Date**: 2026-03-19
**Artifacts Reviewed**: data-model.md, plan.md, quickstart.md, research.md

---

## Executive Summary

The speckit-orchestrator plan demonstrates strong alignment with spec-kit's extension model in its core architecture decisions -- particularly AD-1 (spec-kit extension first), AD-5 (no core command overrides), and AD-6 (command frontmatter as single source). The 10-command registration, 4-hook integration, and multi-layer config design all respect the extension system's conventions and boundaries. However, the plan underutilizes several spec-kit capabilities that already exist, mischaracterizes one hook point, introduces a configuration path that deviates from spec-kit's standard layout, and leaves gaps in how it will compose with spec-kit's existing SDD workflow. The orchestrator is the most ambitious extension attempted on the platform -- getting the integration surface right now prevents painful refactoring later.

---

## Alignment

- **Command naming convention is correct.** All 10 commands follow the `speckit.orchestrator.*` pattern (plan.md, Project Structure), matching the `^speckit\.[a-z0-9-]+\.[a-z0-9-]+$` regex enforced by the Extension API Reference (EXTENSION-API-REFERENCE.md, line 100-106).

- **Hook usage at 4 lifecycle points matches available spec-kit hook events exactly.** The plan targets `before_tasks`, `after_tasks`, `before_implement`, `after_implement` (research.md, R-010). These are the exact 4 hook points implemented in spec-kit's core command templates (templates/commands/tasks.md lines 29 and 101; templates/commands/implement.md lines 20 and 175).

- **Extension deployment directory boundary (AD-7) correctly separates concerns.** `.specify/extensions/orchestrator/` for the extension code vs `.specify/orchestrator/` for runtime state mirrors spec-kit's own separation of `.specify/extensions/` (managed by install) from `.specify/memory/` (managed at runtime).

- **Multi-layer config precedence aligns with spec-kit's documented pattern.** R-004's four levels (env vars > local override > project config > extension defaults) match the config layers in EXTENSION-API-REFERENCE.md lines 517-521 and EXTENSION-DEVELOPMENT-GUIDE.md lines 310-314.

- **All hooks use `optional: true` for non-orchestrated projects.** This follows spec-kit's fail-safe design principle (RFC-EXTENSION-SYSTEM.md, Design Principle 2: "Fail-Safe Defaults" -- missing extensions gracefully degrade, skip hooks). The plan explicitly states hooks no-op when orchestration is inactive (research.md, R-010 final paragraph).

- **AD-5 prohibition on core command overrides respects spec-kit's preset/extension boundary.** Spec-kit's README distinguishes extensions (new capabilities) from presets (customize existing workflows). The orchestrator correctly positions itself as an extension adding new commands, not a preset overriding core templates.

---

## Missed Opportunities

1. **The plan ignores spec-kit's existing `handoffs` frontmatter mechanism.** The `/speckit.plan` command template already declares structured handoffs (`handoffs:` in frontmatter, plan.md lines 4-10 of spec-kit's template). The orchestrator's command composition model (R-010: "orchestrator commands wrapping spec-kit commands") reinvents this. The `handoffs` field supports `label`, `agent`, `prompt`, and `send` keys -- this is the native mechanism for command-to-command delegation that the orchestrator's dispatch and auto commands should leverage.

2. **The `scripts` frontmatter field in command definitions is not utilized.** Spec-kit commands support `scripts: { sh: ..., ps: ... }` in frontmatter (EXTENSION-DEVELOPMENT-GUIDE.md lines 229-237), with automatic path rewriting during registration. The plan places scripts at `scripts/state/`, `scripts/dispatch/`, etc. but never references them through the frontmatter mechanism. This means the orchestrator's commands cannot benefit from spec-kit's cross-platform script resolution or the `{SCRIPT}` placeholder substitution that core commands use.

3. **No `agent_scripts` usage for agent context updates.** Spec-kit's `/speckit.plan` template uses `agent_scripts: { sh: scripts/bash/update-agent-context.sh __AGENT__ }` to update CLAUDE.md or equivalent agent context files. The orchestrator should use this mechanism when phase completions or milestone state changes require agent context updates -- particularly relevant since the CLAUDE.md in `spec-kit-orc/` already shows "Recent Changes" entries.

4. **The `$ARGUMENTS` placeholder is not mentioned in any command design.** Every spec-kit command template uses `$ARGUMENTS` for user input (EXTENSION-DEVELOPMENT-GUIDE.md line 245; every core command template begins with a `## User Input` section containing `$ARGUMENTS`). The quickstart shows commands accepting inline arguments (`/speckit.orchestrator.evaluate` followed by a description), but the plan never specifies how commands will handle this standard mechanism.

5. **No use of spec-kit's `requires.commands` manifest field.** The extension.yml schema supports declaring dependencies on core commands (`requires: commands: ["speckit.tasks"]`, EXTENSION-DEVELOPMENT-GUIDE.md line 37). The orchestrator wraps `speckit.plan`, `speckit.specify`, and `speckit.clarify` via command composition (R-010), yet the plan does not declare these as required commands in the manifest. This means spec-kit cannot validate that the necessary core commands exist before installation.

6. **Checklist integration is absent.** Spec-kit's `/speckit.checklist` command generates validation checklists, and `/speckit.implement` checks checklist completion status before execution (implement.md lines 54-79). The orchestrator's verification ladder (R-006) reinvents a parallel verification system without connecting to spec-kit's native checklist mechanism. Phase must-haves could be expressed as checklists, enabling both human and mechanical verification through the existing system.

7. **Template override mechanism is unused.** Spec-kit supports a runtime template resolution stack: project-local overrides > presets > extensions > core (README, lines 331-348). The orchestrator's 15 templates (roadmap, phase-plan, task-plan, summaries, etc.) could be overridable by users through this mechanism, but the plan treats them as fixed assets. A team wanting to customize the phase summary format or dispatch prompt structure has no documented path.

8. **No `.extensionignore` file planned.** The EXTENSION-DEVELOPMENT-GUIDE.md documents `.extensionignore` for excluding dev-only files during installation (lines 337-393). The orchestrator has `tests/`, `fixtures/`, `specs/`, and `docs/` directories that should not be copied to `.specify/extensions/orchestrator/` on install. Without an `.extensionignore`, these files bloat the installed extension.

9. **The `config_schema` field in extension.yml is not utilized for validation.** The extension manifest supports a `config_schema` field for JSON Schema validation of extension configuration (EXTENSION-DEVELOPMENT-GUIDE.md line 220). The orchestrator defines 6 config fields (default_tier, verification_commands, context_verbosity, git_isolation, dispatch_budget, duration_budget) with specific types and enums, yet the plan does not mention schema-based validation.

---

## Off-Base Assumptions

1. **The plan claims 4 hook points but names them inconsistently with spec-kit's actual implementation.** Research.md R-010 states hooks are available at `before_tasks`, `after_tasks`, `before_implement`, `after_implement`. This is correct per the template source. However, the EXTENSION-API-REFERENCE.md also lists `before_commit` and `after_commit` (line 556-557), meaning there are potentially 6 hook points, not 4. The plan's hook integration table (R-010) should account for `before_commit` and `after_commit` -- these could be valuable for orchestrator state persistence (writing lock files, committing summaries).

2. **Configuration file placement deviates from spec-kit conventions.** The plan places `orchestrator-config.yml` at the project root (plan.md line 59; data-model.md line 28). Spec-kit's standard config location is `.specify/extensions/{extension-id}/{extension-id}-config.yml` (EXTENSION-API-REFERENCE.md lines 486-487, EXTENSION-DEVELOPMENT-GUIDE.md line 103). While FR-070 requires config outside APM's deployment radius, spec-kit's own config path is already outside APM's radius (APM manages the extension deployment, not the `.specify/extensions/{id}/` config files). Placing config at project root breaks the convention that every other extension follows and makes the orchestrator a special case.

3. **The quickstart's install command `specify extension add speckit-orchestrator` assumes catalog availability.** Spec-kit catalogs require extensions to be published and listed in `catalog.json` or `catalog.community.json` (EXTENSION-PUBLISHING-GUIDE.md). For initial development, the install path should be `specify extension add --dev /path/to/orchestrator` (EXTENSION-DEVELOPMENT-GUIDE.md line 109). The quickstart should lead with the `--dev` install path and mention catalog installation as a future distribution option.

4. **The plan assumes `condition` expressions in hooks will be evaluated by spec-kit.** R-010 does not discuss how hook conditions work, but spec-kit's actual implementation explicitly states that LLMs do NOT evaluate `condition` expressions -- hooks with non-empty conditions are skipped, and condition evaluation is deferred to HookExecutor (tasks.md lines 23-25, implement.md lines 23-25). If the orchestrator relies on conditional hook execution (e.g., "only trigger if orchestration is active"), it must use prompt-based gating (`optional: true` with descriptive prompt text), not the `condition` field.

---

## Actionable Recommendations

1. **(P1) Declare `requires.commands` in extension.yml.** Add `requires: commands: ["speckit.plan", "speckit.tasks", "speckit.implement", "speckit.clarify", "speckit.specify"]` to the manifest. This lets spec-kit validate dependencies at install time and produces clear error messages if core commands are missing. Source: EXTENSION-DEVELOPMENT-GUIDE.md line 37.

2. **(P1) Use the `scripts` frontmatter field in command markdown files.** Each orchestrator command that invokes helper scripts should declare them in frontmatter (`scripts: { sh: ../../scripts/state/derive-phase.sh }`). This enables spec-kit's path rewriting during registration (EXTENSION-DEVELOPMENT-GUIDE.md lines 264-278) and the `{SCRIPT}` placeholder in command bodies. Without this, commands will need hardcoded paths to `.specify/extensions/orchestrator/scripts/`, which is fragile.

3. **(P1) Move `orchestrator-config.yml` to `.specify/extensions/orchestrator/orchestrator-config.yml`.** This follows spec-kit's config convention. The local override (`orchestrator-config.local.yml`) goes in the same directory and is gitignored. If the concern is APM overwriting this directory, note that spec-kit's own install process preserves user config files -- `ExtensionManager.install_from_directory()` handles this (EXTENSION-API-REFERENCE.md lines 215-218). Document the config path in the extension's `provides.config` manifest section.

4. **(P1) Add `$ARGUMENTS` handling to all command definitions.** Every command should include a `## User Input` section with `$ARGUMENTS` per spec-kit convention. This is how all core commands accept inline user input. The `evaluate`, `discuss`, and `dispatch` commands in particular need this for the user to pass context (e.g., `/speckit.orchestrator.evaluate Build a multi-tenant data pipeline...` as shown in quickstart.md).

5. **(P2) Leverage `handoffs` frontmatter for command chaining.** The orchestrator's `auto` command drives a state machine loop that dispatches to `plan-phase`, `dispatch`, `verify`, etc. Declare these transitions as `handoffs` in command frontmatter so spec-kit agents can present them as structured options. Example for `auto.md`: `handoffs: [{ label: "Plan Next Phase", agent: "speckit.orchestrator.plan-phase", prompt: "Plan the next unplanned phase" }]`.

6. **(P2) Create `.extensionignore` to exclude development artifacts.** Add entries for `tests/`, `specs/`, `docs/` source, `fixtures/`, `.planning/`, and any CI configuration. Without this, `specify extension add --dev` will copy test fixtures and spec artifacts into `.specify/extensions/orchestrator/`, wasting disk and polluting the install.

7. **(P2) Connect phase must-haves to spec-kit's checklist system.** Generate checklist files (using spec-kit's `checklist-template.md` format) from phase must-haves. This allows `/speckit.implement` to gate on checklist completion via its built-in checklist verification (implement.md lines 54-79), unifying the orchestrator's verification with spec-kit's native mechanism rather than running a parallel system.

8. **(P2) Add `config_schema` to extension.yml for config validation.** Define a JSON Schema for the 6 config fields. This enables spec-kit to validate user-provided config at load time and provide clear error messages for invalid values (e.g., `default_tier: "D"` would fail enum validation). Source: EXTENSION-DEVELOPMENT-GUIDE.md line 220.

9. **(P3) Consider `before_commit` and `after_commit` hooks.** The orchestrator could use `before_commit` to validate that the current phase's must-haves are satisfied before allowing a commit, and `after_commit` to update execution-log.jsonl or advance state. These hooks are listed in EXTENSION-API-REFERENCE.md line 556-557 but are not utilized by the plan.

10. **(P3) Make templates overridable through spec-kit's template resolution stack.** Place orchestrator templates in a location that participates in spec-kit's template resolution (project-local overrides > presets > extensions > core). This allows teams to customize summary formats, dispatch prompt structures, or roadmap layouts without forking the extension. Document which templates are designed for override vs. which are internal-only.

---

## Referenced Documentation

| Document | Location | Relevance |
|----------|----------|-----------|
| Extension API Reference | `<redacted-monorepo>/spec-kit/extensions/EXTENSION-API-REFERENCE.md` | Manifest schema, hook events, config layers, file system layout |
| Extension Development Guide | `<redacted-monorepo>/spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md` | Command format, scripts frontmatter, handoffs, config loading, .extensionignore |
| RFC Extension System | `<redacted-monorepo>/spec-kit/extensions/RFC-EXTENSION-SYSTEM.md` | Hook registration, execution model, design principles |
| Template: tasks.md | `<redacted-monorepo>/spec-kit/templates/commands/tasks.md` | Hook checking implementation, before_tasks/after_tasks patterns |
| Template: implement.md | `<redacted-monorepo>/spec-kit/templates/commands/implement.md` | Hook checking, checklist verification, before_implement/after_implement |
| Template: plan.md | `<redacted-monorepo>/spec-kit/templates/commands/plan.md` | Handoffs frontmatter, agent_scripts, {SCRIPT} placeholder |
| Template extension.yml | `<redacted-monorepo>/spec-kit/extensions/template/extension.yml` | Reference extension manifest with all fields |
| Selftest extension.yml | `<redacted-monorepo>/spec-kit/extensions/selftest/extension.yml` | Minimal real extension example |
| Template command example.md | `<redacted-monorepo>/spec-kit/extensions/template/commands/example.md` | Command file format with $ARGUMENTS, frontmatter, steps |
| spec-kit README | `<redacted-monorepo>/spec-kit/README.md` | Core workflow, extension vs preset distinction, template resolution stack |
