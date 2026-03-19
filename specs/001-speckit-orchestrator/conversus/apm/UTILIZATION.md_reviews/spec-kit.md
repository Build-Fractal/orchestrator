# Cross-Review of Spec-Kit's UTILIZATION.md

**Reviewer**: APM (Agent Package Manager)
**Subject**: Spec-Kit's capability review of the speckit-orchestrator spec
**Date**: 2026-03-18

---

## 1. Dangerous Contradictions

### 1.1 Skill Folder Architecture: "Eliminate the parallel abstraction" vs. APM's primary delivery mechanism

Spec-Kit's recommendation 7 (Section 5, item 7) instructs the spec to "eliminate the parallel 'skill folder' abstraction and map directly to what spec-kit provides," decomposing skill folders into spec-kit's `commands/`, `scripts/`, `templates/`, `docs/`, and config primitives. APM's review (Section 3, bullet 6; Section 5, recommendation 2) treats the skill folder as the atomic deployment unit that APM's install pipeline discovers, validates, copies, and tracks via `apm.lock.yaml`. APM deploys intact skill folders to `.github/skills/{name}/`, `.claude/skills/{name}/`, `.cursor/skills/{name}/`, etc.

**Why this is dangerous**: If the orchestrator eliminates skill folders in favor of spec-kit's scattered command/scripts/templates model, APM has nothing to deploy. APM's skill integrator expects a folder with a root `SKILL.md` containing `name` and `description` frontmatter. There is no APM primitive for "a command markdown file in a `commands/` directory plus some scripts in a `scripts/` directory plus some templates in a `templates/` directory that together constitute one logical unit." The skill folder is not a parallel abstraction to be eliminated -- it is the packaging contract that enables multi-agent distribution. Spec-kit's commands are the *authoring* format; APM's skill folders are the *distribution* format. They serve different lifecycle phases and must coexist.

**APM's position**: The skill folder structure (FR-028) must be preserved as the APM-facing packaging boundary. Each skill folder maps to one `commands/*.md` file in spec-kit's extension model. The `SKILL.md` is the APM entry point; the command markdown is the spec-kit entry point. Both exist in the same folder. Recommendation 7 should be revised to "map spec-kit's extension primitives *into* the skill folder structure" rather than the reverse.

### 1.2 Configuration: spec-kit's multi-layer config vs. APM's always-overwrite policy

Spec-Kit's recommendation 1 (Section 5, item 1) proposes replacing the spec's `config.json` with spec-kit's multi-layer configuration system: `extension.yml` defaults, `orchestrator-config.yml`, `.local.yml` overrides, and `SPECKIT_ORCHESTRATOR_*` env vars. APM's review (Section 4, bullet 2; Section 5, recommendation 3) warns that any configuration stored inside APM-managed directories will be destroyed on `apm install` due to the always-overwrite policy, and recommends active configuration live at `.specify/orchestrator/config.json` (outside the skill folder).

**Why this is dangerous**: Spec-kit's recommendation routes all configuration through infrastructure that lives partially inside the extension directory (`.specify/extensions/orchestrator/`). If this directory overlaps with APM's deployment target, `apm install` will overwrite user customizations on every install cycle. Spec-kit's `.local.yml` convention (gitignored) mitigates this for git but not for APM's file-level overwrite. A user who tunes `orchestrator-config.yml` in an APM-deployed location loses their changes the next time anyone runs `apm install`.

**APM's position**: Configuration layering is fine, but the live config layer must be outside APM's deployment radius. The spec-kit config infrastructure can provide defaults and schema validation at install time, but the mutable user-facing configuration file must live at `.specify/orchestrator/config.json` (or `orchestrator-config.yml` if that naming is preferred) in a location APM does not own. Spec-kit's recommendation should add an explicit carve-out: "User-mutable configuration MUST NOT reside in APM-managed directories."

### 1.3 Community Catalog as primary distribution vs. APM packaging as primary distribution

Spec-Kit's recommendation 10 (Section 5, item 10) and missed opportunity 8 (Section 3, bullet 8) advocate submitting the orchestrator to spec-kit's community extension catalog (`catalog.community.json`) as the "primary discovery mechanism for spec-kit extensions," positioning APM packaging as a secondary channel. APM's review (Section 3, bullet 1; Section 5, recommendation 1) treats `apm.yml` and `apm install speckit-orchestrator` as the primary distribution path, with `specify extension add` as the graceful-degradation fallback.

**Why this is dangerous**: If the community catalog becomes the canonical distribution channel, the orchestrator loses APM's lockfile tracking, collision detection, version pinning, transitive dependency resolution, `apm pack` for CI bundles, and multi-agent deployment. The spec-kit catalog is a discovery index, not a package manager -- it has no lockfile, no version pinning, no dependency graph, and no CI bundle story. Positioning it as primary distribution means the orchestrator's most complex deployment scenarios (CI via gh-aw, monorepo multi-agent setups, reproducible team onboarding) fall back to manual management.

**APM's position**: The community catalog is a discovery mechanism and should be listed as such. APM is the distribution and lifecycle management system. The correct framing is: users discover the orchestrator via spec-kit's catalog or documentation, then install it via `apm install speckit-orchestrator` for full lifecycle management, or via `specify extension add` for standalone spec-kit usage. Recommendation 10 should be reframed from "primary distribution" to "discoverability listing."

### 1.4 Template resolution stack ownership vs. APM compilation targets

Spec-Kit's recommendations 2 and 3 (Section 5, items 2-3) propose that the orchestrator's output templates (roadmap, phase plan, task plan, summaries) be registered in spec-kit's template resolution stack at `.specify/extensions/orchestrator/templates/`, making them overridable via presets. APM's review (Section 5, recommendations 6-7) proposes that these same artifacts be packaged as APM `.context.md` primitives with context links, and as `.instructions.md` files with `applyTo` patterns, so that `apm compile` includes them in agent instruction sets.

**Why this is dangerous**: Both systems want to own the template/artifact pipeline but through incompatible mechanisms. Spec-kit's template resolution stack is a runtime lookup chain (presets > extensions > core) evaluated when spec-kit commands execute. APM's compilation pipeline is a build-time merge that produces static instruction files. If the orchestrator's templates live only in spec-kit's resolution stack, APM cannot compile them into agent instructions. If they live only as APM context primitives, spec-kit cannot override them via presets. Dual-homing the templates without a clear ownership model creates drift -- a template updated in one system but not the other.

**APM's position**: Templates that spec-kit commands consume at runtime (spec-template, plan-template, tasks-template overrides) belong in spec-kit's resolution stack. Knowledge artifacts that agents need for context (KNOWLEDGE.md patterns, DECISIONS.md schemas, phase summary formats) belong in APM's context/instruction pipeline. These are different artifact categories serving different consumers. The spec should draw this line explicitly rather than having both systems claim the full artifact set.

---

## 2. Tensions

### 2.1 Hook registration: spec-kit's `before_*` uncertainty vs. APM's hook deployment certainty

Spec-Kit's off-base assumption 1 (Section 4, bullet 1) raises a legitimate concern: `before_tasks` and `before_implement` are parsed by core command templates but are not listed as standard hook events in the API reference. Spec-kit recommends verifying manifest-level support (recommendation 6). APM's review (Section 5, recommendation 5) proposes additionally packaging orchestrator hooks as APM hook JSON files under `.apm/hooks/` for cross-agent deployment.

**Tension**: If `before_*` hooks turn out to be unsupported in the extension manifest schema, the orchestrator loses two of its four hook attachment points in spec-kit's system. APM's hook deployment could serve as a fallback mechanism, but APM hooks and spec-kit hooks have different execution models (APM hooks are agent-native; spec-kit hooks are command-template-parsed). Running the same logical hook through both systems creates double-execution risk.

**Resolution path**: Treat spec-kit hooks and APM hooks as serving different scopes. Spec-kit hooks fire during SDD command execution (within the spec-kit workflow). APM hooks fire during agent lifecycle events (pre-commit, pre-push, file-open patterns). The orchestrator needs both, but they should not overlap. If `before_*` spec-kit hooks are unsupported, the orchestrator should use command composition (as the spec already proposes) for the spec-kit workflow side, and APM hooks for the agent lifecycle side.

### 2.2 Command composition mechanism: new commands vs. preset overrides

Spec-Kit's off-base assumption 3 (Section 4, bullet 3) and recommendation 8 identify an ambiguity: the spec does not clarify whether orchestrator wrapping means new `speckit.orchestrator.specify` commands (option a) or preset-based overrides replacing `speckit.specify` (option b). Spec-kit favors option (a). APM's skill model implicitly assumes option (a) as well, since each skill folder maps to one distinct command.

**Tension**: While both reviewers lean toward option (a), spec-kit's recommendation to "clarify the mechanism" leaves open the possibility that the spec author chooses option (b). If the spec adopts preset overrides, APM's skill deployment model breaks -- APM deploys skills as new commands, not as overrides of existing ones. APM has no mechanism to deploy a preset that replaces a core spec-kit command.

**Resolution path**: The spec should commit to option (a) -- new `speckit.orchestrator.*` commands that internally delegate to standard spec-kit workflows. This is compatible with both spec-kit's extension model and APM's skill deployment. Add an explicit constraint: "The orchestrator MUST NOT override or replace core spec-kit commands via presets."

### 2.3 `requires.commands` declaration vs. APM dependency declarations

Spec-Kit's recommendation 4 proposes declaring `requires.commands` in the extension manifest (listing `speckit.tasks`, `speckit.plan`, etc.) so the extension system validates command availability at install time. APM's review proposes declaring dependencies in `apm.yml` under `dependencies.apm` for transitive package resolution.

**Tension**: These are two dependency declaration systems that don't know about each other. When installing via APM, `apm install` does not evaluate spec-kit's `requires.commands`. When installing via `specify extension add`, the extension system does not evaluate `apm.yml` dependencies. A user installing through one channel gets one set of validations but not the other.

**Resolution path**: Both declarations should exist. `requires.commands` validates at the spec-kit layer; `apm.yml` dependencies validate at the APM layer. They protect against different failure modes (missing spec-kit commands vs. missing APM packages). The spec should document that both are required and explain which validation fires in which installation path.

### 2.4 State directory ownership at `.specify/orchestrator/`

Both reviews agree that `.specify/orchestrator/` is the correct location for orchestrator runtime state (spec-kit Section 2, bullet 4; APM Section 2, bullet 1 implicit via FR-019). However, spec-kit sees this as an extension state directory governed by spec-kit's extension file system conventions, while APM sees it as a runtime state directory that must be outside APM's deployment radius.

**Tension**: If APM deploys any files to `.specify/orchestrator/` during `apm install` (e.g., initial state templates, default config), those files become APM-managed and subject to overwrite. But the orchestrator also writes runtime state to this directory (phase files, lock files, JSONL logs). The boundary between "APM-deployed scaffolding" and "runtime-generated state" is unclear.

**Resolution path**: APM should deploy to `.specify/extensions/orchestrator/` (extension code, templates, defaults). Runtime state should live at `.specify/orchestrator/` (untouched by APM). The spec already proposes this separation in FR-019; both reviews should explicitly endorse it and ensure no APM primitive targets the runtime state directory.

### 2.5 Distribution format: extension archive vs. APM package

Spec-kit's review implicitly assumes the orchestrator is distributed as a spec-kit extension (installed via `specify extension add <url>`). APM's review assumes it is distributed as an APM package (installed via `apm install speckit-orchestrator`). The spec's User Story 8 promises both, but the two formats have different directory layouts, different metadata schemas, and different install behaviors.

**Tension**: Maintaining two distribution formats (spec-kit extension structure + APM package structure) doubles the packaging surface. The `extension.yml` manifest and the `apm.yml` manifest describe overlapping but non-identical metadata. Keeping them in sync is a maintenance burden that the spec does not acknowledge.

**Resolution path**: Use a single source directory structure that satisfies both systems. The `extension.yml` serves spec-kit; the `apm.yml` serves APM. Both point to the same `commands/`, `skills/`, `scripts/` directories. Add a CI check that validates both manifests against their respective schemas. The spec should include a deliverable for the dual-manifest directory layout.

---

## 3. Safe Agreements

### 3.1 Disk-only state and file-presence-based state machine

Both reviews endorse the spec's principle that state on disk is truth (spec-kit Section 2, bullet 5; APM Section 2, bullet 1). Spec-kit cites alignment with SDD philosophy where specs are source of truth. APM's constitution principle 6 ("State On Disk Is Truth") directly mirrors this. The file-presence-based state machine (FR-020) is compatible with both systems -- spec-kit can check file existence to derive status, and APM's lockfile tracks deployed files without interfering with runtime state files.

### 3.2 Zero overhead for Tier A

Both reviews agree that Tier A (single context window) work should bypass orchestration entirely and run standard spec-kit with no additional ceremony (spec-kit Section 2, bullet 6; APM implicit via the principle that APM is not a runtime dependency). Neither system adds overhead when the orchestrator determines the work is simple enough for direct execution. This is a clean agreement with no hidden conflicts.

### 3.3 Multi-agent compatibility without agent-specific code paths

Spec-kit endorses FR-032's requirement for universal agent support (Section 2, bullet 3), citing the `CommandRegistrar`'s format conversion. APM endorses it (Section 2, bullet 5), citing multi-target deployment to `.github/`, `.claude/`, `.cursor/`, `.opencode/`. Both systems achieve agent universality through their own mechanisms (spec-kit via command format conversion, APM via multi-target install), and neither requires the orchestrator to contain agent-specific logic. The approaches are complementary, not competing.

### 3.4 APM is not a runtime dependency

Both reviews affirm that the orchestrator should not require APM at runtime (spec-kit Section 2, bullet 1 implicit -- the extension model does not reference APM at runtime; APM Section 2, bullet 1 explicit). The orchestrator runs as a spec-kit extension using spec-kit's command execution model. APM's role ends at install time. This is the most foundational agreement between the two reviews and the one the spec itself gets most clearly right.

---

## Summary

The most critical conflict is over the skill folder architecture (1.1). Spec-kit wants to dissolve skill folders into its native primitives; APM needs skill folders intact as deployment units. This must be resolved before implementation begins -- the directory structure is a foundational decision that cascades into every other packaging and distribution choice. The resolution is coexistence: skill folders contain both APM's `SKILL.md` and spec-kit's command markdown, with each system reading the entry point it understands.

The configuration ownership conflict (1.2) is resolvable with a clear rule: APM-deployed directories are immutable post-install; user-mutable config lives elsewhere. The distribution channel tension (1.3) is resolvable with clear role assignment: spec-kit catalog for discovery, APM for lifecycle management. The template ownership conflict (1.4) is resolvable by categorizing artifacts by consumer: spec-kit owns runtime templates, APM owns compile-time context.

The tensions are real but navigable. The safe agreements provide a solid foundation -- both systems agree on the fundamental principles (disk state, zero overhead, multi-agent, install-time-only APM) and diverge mainly on mechanism, not intent.
