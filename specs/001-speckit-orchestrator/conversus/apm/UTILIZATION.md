# APM Utilization Review: Speckit-Orchestrator Spec

**Reviewer perspective**: APM (Agent Package Manager)
**Spec under review**: `specs/001-speckit-orchestrator/spec.md`
**Date**: 2026-03-18

---

## 1. Executive Summary

The speckit-orchestrator spec describes an ambitious multi-phase orchestration extension for spec-kit that adds milestone/phase/task hierarchy, autonomous dispatch, crash recovery, and knowledge generation to spec-driven development. APM appears in two explicit user stories: **User Story 7** (GitHub Agentic Workflows runtime, P7) and **User Story 8** (APM Packaging, P8). The spec correctly identifies APM as the distribution mechanism and gh-aw integration layer, and it explicitly avoids making APM a runtime dependency (FR-033, FR-036). This is a sound architectural decision — the orchestrator should be self-contained at runtime while leveraging APM purely for packaging and distribution.

However, the spec's treatment of APM is thin relative to what APM actually offers. User Story 8 is three acceptance scenarios totaling nine lines. There is no mention of APM's skill integration pipeline, hook integration system, context linking, compilation targets, or the `apm pack` distribution workflow — all of which directly serve the orchestrator's stated skill architecture (FR-028 through FR-030). The spec designs an elaborate skill folder structure (SKILL.md, scripts/, templates/, references/, config.json) but does not account for how APM's install pipeline discovers, validates, deploys, and tracks these artifacts. This creates a gap: the skill architecture is designed in isolation from its primary distribution channel.

The playbook (`speckit-orchestrator-playbook.md`) references APM research (subagent 3) and mentions APM packaging in the specification prompt, but the spec itself internalizes almost none of APM's concrete mechanisms. The result is a spec that is correct about what APM is *not* (not a runtime dependency) but underspecified about what APM *is* (the packaging, deployment, and lifecycle management system for the orchestrator's skills, hooks, and instructions).

---

## 2. Alignment (What the Spec Gets Right)

- **APM is not a runtime dependency (FR-033, line ~266; FR-036, line ~271)**: The spec explicitly states "Must not import, invoke, or wrap GSD-2 or APM binaries at runtime" and provides a graceful degradation path where manual installation via `specify extension add` works when APM is absent. This aligns with APM's design as an install-time tool, not a runtime framework. (Ref: APM README.md — "Declare your project's agentic dependencies once in `apm.yml`, and every developer who clones your repo gets a fully configured agent setup in seconds.")

- **Skill folder structure matches APM's skill expectations (FR-028, lines ~257-259; playbook lines ~411-423)**: The spec's skill folder design (SKILL.md + scripts/ + templates/ + references/) is structurally compatible with APM's skill integration pipeline, which copies entire skill folders to `.github/skills/{skill-name}/`, `.claude/skills/`, etc. (Ref: `guides/skills.md`, "Skill Folder Naming" and "Bundled Resources" sections.)

- **GitHub Agentic Workflows integration references APM frontmatter dependencies (User Story 7, lines ~127-141)**: The spec correctly identifies that gh-aw workflows can declare APM packages in frontmatter, enabling CI-based orchestration with APM-managed context. This directly maps to APM's gh-aw integration. (Ref: `integrations/gh-aw.md`, "Frontmatter Dependencies" section.)

- **Trigger-phrased skill descriptions (FR-029, line ~258)**: The spec requires "Use when..." phrasing for SKILL.md descriptions, which aligns with APM's skill discovery model where agents scan skill descriptions to determine invocation. (Ref: `guides/skills.md`, "Required Frontmatter" — name and description fields are what agents parse.)

- **Multi-agent compatibility (FR-032, line ~264; SC-007, line ~432)**: The spec requires the orchestrator to work across multiple agent runtimes without agent-specific code paths. This aligns with APM's multi-target deployment model (`.github/` for Copilot, `.claude/` for Claude, `.cursor/` for Cursor, `.opencode/` for OpenCode). (Ref: `integrations/ide-tool-integration.md`, full deployment matrix.)

---

## 3. Missed Opportunities

- **No `apm.yml` manifest specification for the orchestrator package**: User Story 8 says "installable via APM (`apm install speckit-orchestrator`)" but the spec never defines the `apm.yml` that would make this work. APM requires `name` and `version` fields (MUST-level per manifest schema Section 3.1-3.2), plus `dependencies.apm` for any transitive packages and `dependencies.mcp` for MCP servers. The spec should define the orchestrator's `apm.yml` as a concrete deliverable. (Spec: User Story 8, lines ~143-156. APM ref: `reference/manifest-schema.md`, Section 2 "Document Structure".)

- **No hook integration via APM's hook pipeline**: The spec defines four hook points in `extension.yml` (before_tasks, after_tasks, before_implement, after_implement, lines ~57-81 of extension.yml) and mentions on-demand hooks for phase scope enforcement and verification logging (playbook lines ~451-454). APM has a full hook integration system that deploys hook JSON files to `.github/hooks/`, `.claude/settings.json`, and `.cursor/hooks.json` — including script path rewriting and cross-platform deployment. The spec's hooks are designed only for spec-kit's extension system and miss APM's hook distribution entirely. (APM ref: `introduction/key-concepts.md`, "Hooks" section; `integrations/ide-tool-integration.md`, "Automatic Hook Integration" section.)

- **No `apm compile` constitution injection strategy**: The spec mentions a constitution file at `.specify/memory/constitution.md` (Assumptions, line ~466) and Principle 1 requires context minimization. APM already has constitution injection into `AGENTS.md` during compilation (hash-verified, idempotent, drift-aware). The orchestrator could leverage this to ensure the constitution is always present in compiled instruction files without manual management. The spec never mentions this integration. (APM ref: `guides/compilation.md`, "Constitution Injection" section; `introduction/key-concepts.md`, "Spec Kit Constitution Injection (Phase 0)" section.)

- **No `apm pack` bundle strategy for CI distribution**: User Story 7 describes GitHub Agentic Workflows execution but does not mention APM bundles. APM's `apm pack` produces self-contained bundles that work without APM, Python, or network access — exactly what sandboxed gh-aw runners need. The spec should reference `apm pack --archive` as the mechanism for CI artifact distribution. (Spec: User Story 7, lines ~127-141. APM ref: `guides/pack-distribute.md`, "Agentic workflows" section; `integrations/gh-aw.md`, "Using APM Bundles" section.)

- **No context linking for knowledge artifacts**: The spec produces KNOWLEDGE.md, DECISIONS.md, phase summaries, and other structured artifacts (FR-024 through FR-027, lines ~250-254). APM's context linking system allows primitives to reference `.context.md` files via markdown links, which are resolved during install and compilation. The orchestrator's knowledge artifacts could be packaged as `.context.md` files with links from instructions and agents, enabling automatic context graph construction. The spec does not explore this. (APM ref: `introduction/key-concepts.md`, "Context Linking" section, lines ~399-452.)

- **No instruction primitives defined for the orchestrator package**: APM's most powerful compilation feature is instructions with `applyTo` glob patterns — targeted guidance that loads automatically based on file type. The orchestrator manages `.specify/orchestrator/` state files (YAML frontmatter markdown, JSONL logs, JSON lock files). The package could ship `.instructions.md` files with patterns like `applyTo: ".specify/orchestrator/**/*.md"` to provide agent guidance when editing orchestrator state. The spec does not consider this. (APM ref: `introduction/key-concepts.md`, "Instructions" section; `guides/compilation.md`, "The Context Pollution Problem" section.)

- **No `apm pack --format plugin` consideration**: APM supports a plugin format (`plugin.json`) that provides an alternative packaging model with custom component paths, MCP server definitions, and multi-platform discovery. The orchestrator could be distributed as both an APM package and a plugin, maximizing compatibility. The spec does not evaluate which format is more appropriate. (APM ref: `guides/plugins.md`, full document.)

- **No version pinning or lockfile strategy for the orchestrator as a dependency**: When other projects install the orchestrator via APM, they need reproducible builds. The spec does not discuss versioning strategy, tag management, or how `apm.lock.yaml` tracks the orchestrator's deployed files. This matters because the orchestrator deploys scripts (`.sh` files) that must match the skill SKILL.md they accompany. (APM ref: `guides/dependencies.md`, "Reproducible Builds with apm.lock.yaml" section; `reference/manifest-schema.md`, Section 6 "Lockfile".)

- **No MCP server declarations**: The orchestrator's skill architecture includes helper scripts and could benefit from MCP server integration for state querying, progress dashboards (FR-038), or external verification. APM's `dependencies.mcp` supports self-defined servers. The spec does not consider whether any orchestrator capabilities should be exposed as MCP tools. (APM ref: `reference/manifest-schema.md`, Section 4.2; `integrations/ide-tool-integration.md`, "MCP Integration" section.)

---

## 4. Off-Base Assumptions

- **Assumption that APM deployment is a simple "install and done" operation (User Story 8, lines ~143-156)**: The spec's three acceptance scenarios treat APM installation as a black box: "skills are deployed to the IDE-native command directories for all detected agents." In reality, APM's install pipeline involves target detection (which `.github/`, `.claude/`, `.cursor/`, `.opencode/` directories exist), skill folder naming validation (1-64 chars, lowercase alphanumeric + hyphens per agentskills.io spec), collision detection with existing files, and lockfile tracking of every deployed file. The orchestrator's skill names (e.g., `orchestrator-auto`, `orchestrator-verify`) happen to be valid, but the spec does not acknowledge these constraints or test against them. (APM ref: `guides/skills.md`, "Skill Folder Naming" section.)

- **Assumption that skill folder `config.json` is user-facing persistent configuration (FR-028, line ~257; FR-040, lines ~284-285; playbook line ~423)**: The spec describes `config.json` inside each skill folder as storing user preferences that persist across sessions. APM's skill integration copies the entire skill folder to `.github/skills/{name}/` or `.claude/skills/{name}/`. If a user modifies `config.json` in the deployed location and then runs `apm install` again, APM will overwrite it (always-overwrite policy for package-owned files). User-specific configuration must live outside the skill folder (e.g., in `.specify/orchestrator/config.json` as the spec's own FR-040 suggests) to survive APM reinstalls. The skill folder `config.json` should be a schema/defaults template, not the active configuration. (APM ref: `integrations/ide-tool-integration.md`, "Auto-Integration Works" — "Always Overwrite: Package-owned files are always copied fresh".)

- **Partial understanding of `apm install` vs `apm compile` distinction**: The playbook's research prompt (subagent 3, lines ~260-264) correctly identifies this distinction as "CRITICAL," but the spec itself does not reflect it. The spec mentions APM packaging (US8) without specifying whether the orchestrator's deliverables are `install`-time artifacts (prompts, agents, skills, hooks — deployed to IDE directories) or `compile`-time artifacts (instructions — merged into AGENTS.md/CLAUDE.md). The orchestrator's skills and commands are install-time; any instructions it ships would be compile-time. This matters because the two pipelines have different collision detection, cleanup, and tracking semantics. (APM ref: `guides/compilation.md`, opening paragraph and "Tool Compatibility" table.)

---

## 5. Actionable Recommendations

1. **Define the orchestrator's `apm.yml` manifest as a spec deliverable.** Add a new functional requirement (or extend FR-028) specifying the exact `apm.yml` contents: `name: speckit-orchestrator`, `version: 0.1.0`, `type: hybrid` (since it ships both skills and instructions), dependencies (none for runtime, but declare if it depends on a spec-kit APM package), and scripts for common operations. Reference: `reference/manifest-schema.md`, Section 2 and Appendix A.

2. **Map each skill folder to APM's skill integration contract.** For each of the six skill categories (orchestrator-auto, -verify, -scaffold, -review, -recover, -status), specify that: (a) the root `SKILL.md` has `name` and `description` frontmatter per APM's required format, (b) skill names conform to agentskills.io validation (1-64 chars, lowercase-hyphenated), and (c) the folder structure matches APM's expectations for bundled resources. Add this to FR-028 or as a new FR. Reference: `guides/skills.md`, "SKILL.md Format" section and "Skill Folder Naming" section.

3. **Separate user configuration from skill-folder configuration.** Revise FR-040 to clarify that the active user configuration lives at `.specify/orchestrator/config.json` (outside the APM-managed skill folder), while each skill's `config.json` is a defaults/schema template. Document that `apm install` overwrites skill folder contents. Reference: `integrations/ide-tool-integration.md`, "Always Overwrite" policy.

4. **Add `apm pack` as the CI distribution mechanism for User Story 7.** Extend the GitHub Agentic Workflows acceptance scenarios to include: "Given the orchestrator is packaged with APM, When a gh-aw workflow declares it as a frontmatter dependency, Then the gh-aw activation job runs `apm install && apm pack`, and the agent job unpacks the bundle with zero network access." This closes the gap between the orchestrator and sandboxed CI execution. Reference: `guides/pack-distribute.md`, "Agentic workflows" section; `integrations/gh-aw.md`, "Using APM Bundles" section.

5. **Leverage APM's hook integration for cross-agent hook deployment.** The spec's four hooks (before_tasks, after_tasks, before_implement, after_implement) are spec-kit extension hooks, but the orchestrator also describes on-demand hooks for phase scope enforcement, verification logging, and destructive operation warnings. Package these as APM hook JSON files under `.apm/hooks/` so that `apm install` deploys them to `.github/hooks/`, `.claude/settings.json`, and `.cursor/hooks.json` automatically. Reference: `introduction/key-concepts.md`, "Hooks" section; `integrations/ide-tool-integration.md`, "Automatic Hook Integration" section.

6. **Package knowledge artifacts as APM context primitives.** The KNOWLEDGE.md, DECISIONS.md, and phase summary templates should be authored as `.context.md` files that other primitives can link to. This enables APM's context linking and compilation to include orchestrator knowledge in agents' instruction sets when relevant. Reference: `introduction/key-concepts.md`, "Context Linking" section.

7. **Ship `.instructions.md` files for orchestrator state file editing.** Create instructions with `applyTo: ".specify/orchestrator/**"` that guide agents on state file format requirements (YAML frontmatter schemas, JSONL log format, lock file structure). This leverages APM's most distinctive feature — targeted context loading based on file patterns — and ensures agents editing orchestrator state get the right guidance automatically. Reference: `guides/compilation.md`, context efficiency optimization; `introduction/key-concepts.md`, "Instructions" section.

8. **Define the orchestrator's compilation target strategy.** The spec should state whether `apm compile` for the orchestrator produces AGENTS.md, CLAUDE.md, or both. Since the orchestrator must work across all spec-kit-supported agents (FR-032), the recommended target is `all`. Add this to the `apm.yml` manifest as `target: all`. Reference: `reference/manifest-schema.md`, Section 3.6 "target"; `guides/compilation.md`, "Multi-Agent Output" section.

9. **Add version pinning acceptance scenarios to User Story 8.** Extend US8 to verify that: (a) `apm install speckit-orchestrator#v0.1.0` pins to a specific tag, (b) `apm.lock.yaml` records the exact commit SHA and all deployed files, and (c) `apm uninstall` cleanly removes all orchestrator-deployed artifacts. This ensures the orchestrator is a first-class APM citizen, not just a package that happens to have an `apm.yml`. Reference: `guides/dependencies.md`, "Reproducible Builds" section; `reference/manifest-schema.md`, Section 6 "Lockfile".

---

## 6. Referenced APM Documentation

| Document | Path |
|----------|------|
| APM README | `apm/README.md` |
| Key Concepts (Primitive Types, Skills, Hooks, Context Linking, Constitution Injection) | `apm/docs/src/content/docs/introduction/key-concepts.md` |
| Compilation Guide (Multi-agent output, Context pollution, Constitution injection, Tool compatibility) | `apm/docs/src/content/docs/guides/compilation.md` |
| Dependencies Guide (apm.yml, Lockfile, Transitive resolution, Local path packages) | `apm/docs/src/content/docs/guides/dependencies.md` |
| Skills Guide (SKILL.md format, Folder naming, Bundled resources, Sub-skill promotion) | `apm/docs/src/content/docs/guides/skills.md` |
| Pack & Distribute Guide (apm pack, Bundles, CI distribution, Agentic workflows) | `apm/docs/src/content/docs/guides/pack-distribute.md` |
| Manifest Schema Reference (apm.yml fields, Lockfile spec, Dependency formats) | `apm/docs/src/content/docs/reference/manifest-schema.md` |
| Primitive Types Reference (Source tracking, Conflict detection, Priority system) | `apm/docs/src/content/docs/reference/primitive-types.md` |
| GitHub Agentic Workflows Integration (Frontmatter deps, Isolated mode, Bundles) | `apm/docs/src/content/docs/integrations/gh-aw.md` |
| IDE & Tool Integration (Install vs compile, Hook integration, Multi-target deployment) | `apm/docs/src/content/docs/integrations/ide-tool-integration.md` |
| Plugins Guide (plugin.json, Custom paths, MCP servers, Multi-platform discovery) | `apm/docs/src/content/docs/guides/plugins.md` |
| Integrator Architecture (.github/instructions/) | `apm/.github/instructions/integrators.instructions.md` |
