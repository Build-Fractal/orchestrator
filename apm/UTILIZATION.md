# APM Utilization Review -- speckit-orchestrator

## Executive Summary

The speckit-orchestrator spec correctly positions APM packaging as a P8 (final) story, which is appropriate since the orchestrator must first be a functional spec-kit extension before it becomes a distributable package. However, the spec underutilizes APM's primitives system throughout its core architecture -- context injection, knowledge management, and dispatch payloads all map directly onto APM capabilities that could be leveraged from P1 onward rather than bolted on at P8. The spec also makes an incorrect assumption about runtime independence when its "Must not import or wrap ... APM at runtime" constraint conflates build-time dependency management with runtime coupling.

## Alignment (What We're Getting Right)

- **P8 as final story for distribution packaging is correctly sequenced.** The spec (line 277) places "APM Packaging -- One-command install distribution" as the last priority. This aligns with APM's philosophy of shipping fast and iterating -- the orchestrator should prove its value as a spec-kit extension before worrying about `apm install speckit-orchestrator`. APM supports this via virtual subdirectory packages (`apm/docs/src/content/docs/reference/manifest-schema.md`, section 4.1.3), meaning the orchestrator can be distributed as part of a larger spec-kit monorepo without needing its own standalone repo.

- **Extension manifest model aligns with APM's plugin detection.** The spec (line 228) requires the orchestrator to be "a valid spec-kit extension with extension.yml manifest." APM already handles multiple manifest formats -- `apm.yml`, `plugin.json`, and `SKILL.md` auto-detection (`apm/docs/src/content/docs/guides/dependencies.md`, lines 26-31). When P8 arrives, the orchestrator could ship both `extension.yml` (for spec-kit) and `apm.yml` (for APM distribution) without conflict. APM's hybrid package type (`apm/docs/src/content/docs/reference/manifest-schema.md`, section 3.7) was designed for exactly this dual-identity use case.

- **Disk-as-truth model is compatible with APM's lockfile approach.** The spec's commitment to deriving state from disk (line 122-126) aligns with APM's own design: `apm.lock.yaml` records `deployed_files` as a manifest of what was installed, and `apm pack` reads the lockfile rather than scanning disk (`apm/docs/src/content/docs/guides/pack-distribute.md`, lines 36-37). Both systems treat the filesystem as the canonical record rather than maintaining in-memory state.

- **Constitution injection is already integrated.** The spec references a constitution file governing orchestrator behavior (line 304). APM already supports spec-kit constitution injection during `apm compile` -- the constitution is placed at the top of `AGENTS.md` with hash-based drift detection (`apm/docs/src/content/docs/introduction/key-concepts.md`, lines 516-533). This means the orchestrator's constitutional governance is automatically propagated to all agent contexts via APM compilation.

## Missed Opportunities

- **Dispatch context payloads should use APM primitives, not bespoke files.** The spec (lines 80-82) describes constructing "minimal context payloads" for each dispatch: task plan, phase plan excerpt, relevant upstream summaries, applicable decisions, and constitution principles. Every one of these maps to an APM primitive type:
  - Task plan -> `.prompt.md` (agent workflow with parameters) -- see `apm/docs/src/content/docs/introduction/key-concepts.md`, lines 147-161
  - Upstream summaries -> `.context.md` (optimized project knowledge) -- see `apm/docs/src/content/docs/introduction/key-concepts.md`, lines 200-213
  - Decisions register -> `.memory.md` (persistent team/project information) -- see `apm/docs/src/content/docs/introduction/key-concepts.md`, lines 335-350
  - Constitution principles -> `memory/constitution.md` (already supported) -- see `apm/docs/src/content/docs/introduction/key-concepts.md`, lines 516-533

  By authoring these as APM primitives with proper frontmatter (especially `applyTo` patterns for instructions), the orchestrator could use `apm compile` to produce optimized, scope-filtered context for each dispatch rather than building a bespoke context assembly system. APM's context optimization engine (`apm/docs/src/content/docs/guides/compilation.md`, lines 108-126) already solves the "minimal relevant context" problem mathematically.

- **Knowledge file scope filtering duplicates APM's instruction targeting.** The spec (lines 162-163) describes scope tags on knowledge entries (project-wide, milestone-specific, phase-specific) to control injection into dispatch payloads. APM instructions already have `applyTo` glob patterns that achieve the same purpose -- scoping content to specific file patterns or directory subtrees (`apm/docs/src/content/docs/introduction/key-concepts.md`, lines 132-145). If knowledge entries were written as `.instructions.md` files with `applyTo` patterns scoped to the relevant phase directories, APM's compilation engine would handle scope filtering automatically with mathematical optimization.

- **Phase boundary maps are a natural fit for APM skills.** Boundary maps (line 69-71) declare what each phase produces and what downstream phases consume -- function signatures, type definitions, endpoints, file paths. This is precisely what APM skills (`SKILL.md`) are designed for: package meta-guides that help AI agents understand what a package/module does and how to leverage its content (`apm/docs/src/content/docs/guides/skills.md`, lines 7-14). Each completed phase could produce a skill file describing its outputs, which downstream phases consume as installed skills.

- **Orchestrator file management could extend BaseIntegrator.** The spec describes extensive file management: deploying phase plans, summaries, decision registers, knowledge files, and lock files to `.specify/orchestrator/`. APM's integrator architecture (`apm/.github/instructions/integrators.instructions.md`) provides battle-tested infrastructure for exactly this: collision detection, manifest-based sync, path security, link resolution, and file discovery. The BaseIntegrator pattern (`apm/src/apm_cli/integration/base_integrator.py`) handles managed-file tracking, cleanup of empty parent directories, and O(1) collision detection -- all problems the orchestrator will need to solve for its own file tree.

- **Phase dependencies map to APM's transitive dependency resolution.** The spec (line 68) describes dependency declarations between phases. APM already has a dependency resolver that handles transitive trees with depth tracking, conflict detection, and declaration-order priority (`apm/docs/src/content/docs/guides/dependencies.md`, lines 450-455). If each phase were modeled as a virtual APM package with its own `apm.yml` declaring dependencies on upstream phases, the orchestrator could reuse APM's resolver rather than building a separate dependency graph engine.

- **`apm pack` could serve crash recovery and resume.** The spec (lines 176-178) describes graceful pause/resume via a "continue file." APM's `apm pack` produces self-contained bundles with enriched lockfiles that snapshot the exact resolved state (`apm/docs/src/content/docs/guides/pack-distribute.md`, lines 8-14, 146-178). A milestone checkpoint could be packed as an APM bundle, providing both crash recovery and the ability to share partially-completed orchestration state across machines or CI environments.

- **The GitHub Agentic Workflows integration (spec line 237-238) should reference APM's existing gh-aw integration.** APM already has a documented, native integration with gh-aw through frontmatter `dependencies:` fields and the apm-action (`apm/docs/src/content/docs/integrations/gh-aw.md`). The spec's description of running the orchestrator as a GitHub Agentic Workflow should build on this rather than designing a parallel integration path. Specifically, gh-aw's `isolated` mode (line 142-156 of the gh-aw doc) directly supports the orchestrator's need to dispatch agents with only declared context and no instruction pollution from the host repo.

## Off-Base Assumptions

- **"Must not import or wrap ... APM at runtime" is too broad.** The spec (line 286) states the orchestrator "Must not import or wrap GSD-2 or APM at runtime -- principles are ported, not dependencies." This conflates two different things. APM is a build-time/install-time tool -- `apm install` runs once to deploy primitives, `apm compile` runs once to generate context files. Neither runs during agent execution. The orchestrator can absolutely declare APM packages as dependencies and run `apm install` as part of its setup without creating a runtime dependency. An agent dispatched by the orchestrator does not need APM installed to read the `.apm/` primitives or compiled `AGENTS.md` that APM deployed. The constraint should be "Must not require APM to be installed in the dispatched agent's environment" rather than "Must not use APM at all."

- **P8 implies APM is only about distribution, but APM's value starts at context management.** The spec treats APM packaging (P8, line 277) as purely a distribution concern -- "one-command install." But APM's primary value is context management (instructions, skills, prompts, agents, context files) and context optimization (mathematical compilation), not just distribution. The orchestrator should use APM primitives for context authoring from P1 onward, with P8 adding only the packaging/distribution layer on top.

- **The `.specify/orchestrator/` file tree ignores APM's established directory conventions.** The spec (line 206) places all state under `.specify/orchestrator/`. APM has established conventions for where agent context lives -- `.apm/` for primitives, `apm_modules/` for dependencies, `.github/`/`.claude/` for deployed files (`apm/docs/src/content/docs/introduction/key-concepts.md`, lines 86-125). The orchestrator's knowledge files, decision registers, and phase summaries are agent-consumable context, and placing them outside APM's discovery paths means they won't be found by `apm compile` or integrated by `apm install`. At minimum, the orchestrator should symlink or copy relevant context artifacts into `.apm/context/` for discoverability.

## Actionable Recommendations

1. **Model dispatch payloads as APM prompt files.** Each task dispatch (spec lines 80-82) should generate a `.prompt.md` file with YAML frontmatter declaring `input:` parameters for the task-specific variables (phase context, upstream summaries, decisions). APM's prompt system (`apm/docs/src/content/docs/guides/agent-workflows.md`, lines 160-187) already supports `${input:name}` parameter substitution, and these prompts would automatically integrate with all APM-supported runtimes.

2. **Write phase summaries as `.context.md` files.** Phase summaries (spec lines 153-155) should be written as APM context files in `.apm/context/phases/` with proper frontmatter. This makes them automatically discoverable by `apm compile` and injectable into downstream agent contexts via APM's link resolution system (`apm/docs/src/content/docs/introduction/key-concepts.md`, lines 399-436).

3. **Write boundary maps as SKILL.md files.** Each phase's boundary map (spec line 69-71) should be authored as a `SKILL.md` in `.apm/skills/{phase-name}/`. This uses APM's skill format (`apm/docs/src/content/docs/guides/skills.md`, lines 92-110) and makes phase outputs discoverable by downstream agents through the standard skill discovery path.

4. **Narrow the "no APM at runtime" constraint.** Rewrite spec line 286 from "Must not import or wrap ... APM at runtime" to "Must not require APM to be installed in dispatched agent environments. The orchestrator MAY use APM CLI at setup/configuration time." This preserves the intent (no runtime coupling to dispatched agents) while allowing the orchestrator to leverage `apm install` and `apm compile` during its own initialization.

5. **Use APM's instruction `applyTo` patterns for knowledge scope filtering.** Instead of building custom scope-tag filtering (spec lines 162-163), write knowledge entries as `.instructions.md` files with `applyTo` patterns that match the phase's file scope. APM's compilation engine (`apm/docs/src/content/docs/guides/compilation.md`, lines 108-158) will handle the optimization automatically. For example, a phase-specific pattern could be authored with `applyTo: ".specify/orchestrator/M001/P002/**"`.

6. **Reference APM's gh-aw integration for the GitHub Workflows story.** The P7 story (spec line 277, "GitHub Workflows -- CI-based overnight orchestration") should build on APM's existing gh-aw integration (`apm/docs/src/content/docs/integrations/gh-aw.md`) rather than designing a parallel approach. Specifically, leverage gh-aw's frontmatter `dependencies:` field to declare the orchestrator's APM package and use `isolated: true` mode for clean dispatch contexts.

7. **Consider APM `apm pack` for milestone snapshots.** The crash recovery design (spec lines 176-178) should evaluate using `apm pack --archive` to create self-contained snapshots of orchestration state at phase boundaries. The enriched lockfile in the bundle (`apm/docs/src/content/docs/guides/pack-distribute.md`, lines 150-178) provides built-in traceability and the bundle can be consumed without APM installed (`apm unpack` or plain `tar xzf`).

8. **Publish the orchestrator as a hybrid APM package at P8.** When P8 arrives, the orchestrator should be packaged with `type: hybrid` in `apm.yml` (`apm/docs/src/content/docs/reference/manifest-schema.md`, section 3.7). This means it ships both as compilable instructions (for `AGENTS.md`) and as an installable skill (the orchestrator's `SKILL.md` helps agents understand the orchestration framework). The package should include the orchestrator's hooks in `.apm/hooks/` so they deploy to all APM-supported runtimes automatically.

9. **Mirror `.specify/orchestrator/` context into `.apm/context/`.** The orchestrator should maintain a symlink or copy strategy that mirrors consumable artifacts (decisions register, knowledge file, active phase summary) into `.apm/context/orchestrator/` so APM's primitive discovery (`apm/docs/src/content/docs/reference/primitive-types.md`, lines 49-57) can find and compile them. This ensures all agent runtimes benefit from orchestrator context, not just those that know to look in `.specify/`.

## Referenced APM Documentation

- `apm/README.md` -- Project overview, dependency declaration syntax, distribution methods
- `apm/.github/copilot-instructions.md` -- Development workflow, project philosophy
- `apm/.github/instructions/integrators.instructions.md` -- BaseIntegrator architecture, performance guidance
- `apm/src/apm_cli/integration/base_integrator.py` -- Collision detection, managed file tracking, IntegrationResult
- `apm/docs/src/content/docs/introduction/key-concepts.md` -- Primitive types, file structure, context linking, constitution injection
- `apm/docs/src/content/docs/introduction/how-it-works.md` -- Three-layer architecture, compilation flow
- `apm/docs/src/content/docs/reference/manifest-schema.md` -- apm.yml spec, dependency formats, package types, lockfile structure
- `apm/docs/src/content/docs/reference/primitive-types.md` -- Enhanced discovery, source tracking, conflict resolution
- `apm/docs/src/content/docs/guides/skills.md` -- SKILL.md format, installation, sub-skill promotion
- `apm/docs/src/content/docs/guides/compilation.md` -- Context optimization engine, applyTo patterns, distributed placement
- `apm/docs/src/content/docs/guides/dependencies.md` -- Dependency resolution, transitive deps, conflict detection, MCP support
- `apm/docs/src/content/docs/guides/pack-distribute.md` -- Bundle creation, lockfile enrichment, offline distribution
- `apm/docs/src/content/docs/guides/org-packages.md` -- Layered composition, org-wide standards distribution
- `apm/docs/src/content/docs/guides/plugins.md` -- Plugin detection, manifest synthesis, MCP server definitions
- `apm/docs/src/content/docs/guides/agent-workflows.md` -- Script execution, prompt parameters, runtime management
- `apm/docs/src/content/docs/integrations/ide-tool-integration.md` -- Multi-runtime deployment, spec-kit integration
- `apm/docs/src/content/docs/integrations/gh-aw.md` -- GitHub Agentic Workflows integration, isolated mode, bundle workflow
