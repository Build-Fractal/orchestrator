# UTILIZATION.iteration_1.md -- Spec-Kit Revised Position

**Spec under review**: `specs/001-speckit-orchestrator/spec.md`
**Reviewer perspective**: spec-kit extension system (the framework the orchestrator extends)
**Iteration**: 1 (post cross-review)
**Date**: 2026-03-18

---

## 1. Recommendation Disposition

Each recommendation from the original UTILIZATION.md is listed below with its disposition after considering cross-review feedback from APM and gh-aw.

---

### Recommendation 1: Leverage spec-kit's configuration infrastructure instead of custom `config.json`

**Status: Modified**

**Original**: Replace the custom configuration approach (FR-040, FR-041) with the documented multi-layer config system. Create an `orchestrator-config.yml` template deployed to `.specify/extensions/orchestrator/`, use `defaults` in `extension.yml` for sane defaults, support `.local.yml` overrides, and `SPECKIT_ORCHESTRATOR_*` env vars for CI overrides.

**Cross-review criticism (APM 1.2)**: Any configuration stored inside APM-managed directories will be destroyed on `apm install` due to the always-overwrite policy. User-mutable config must live outside APM's deployment radius.

**Cross-review criticism (gh-aw 1.3)**: The recommendation conflates static configuration with dynamic runtime state. Static config (tier defaults, verification commands) belongs in spec-kit's config system. Dynamic orchestration state (current phase, active blockers) must not live in config layers -- it changes per-run and would go stale in CI.

**Concessions**: Both criticisms identify real problems. APM's always-overwrite policy means config files deployed inside the extension directory are not safe for user mutation. gh-aw correctly observes that the original recommendation did not distinguish between static configuration and dynamic state.

**Revised recommendation**: Use spec-kit's multi-layer config system for *static configuration only* -- settings that humans author and change rarely (default tier, verification commands, context verbosity, git isolation preferences). The layering is: `extension.yml` `defaults` section provides factory defaults, `orchestrator-config.yml` at project root (outside APM's deployment radius) provides project-level overrides, `orchestrator-config.local.yml` (gitignored) provides developer preferences, `SPECKIT_ORCHESTRATOR_*` env vars provide CI/per-run overrides. Dynamic orchestration state (current phase, active blockers, execution checkpoints) belongs exclusively in `.specify/orchestrator/` as runtime state files, governed by the disk-only state principle. The extension directory `.specify/extensions/orchestrator/` contains only immutable extension code and default templates -- never user-mutable configuration.

---

### Recommendation 2: Provide a companion preset for template overrides

**Status: Withdrawn**

**Cross-review criticism (gh-aw 1.2)**: Preset-based template overrides create implicit environmental dependencies. A dispatched worker relying on an orchestrator-aware `plan-template` being present in the repo's preset stack will silently produce wrong output if the preset is not installed, is overridden by a different preset, or is absent in a CI/fork environment. This directly violates Constitution Principle 4 ("Plans Assume Zero Context").

**Cross-review criticism (APM 1.4)**: Both spec-kit's template resolution stack and APM's compilation pipeline want to own the template/artifact pipeline through incompatible mechanisms. Dual-homing templates without clear ownership creates drift.

**Concession**: gh-aw's criticism is decisive. The orchestrator's own constitution requires that plans assume zero ambient context. Template overrides are ambient context by definition -- they modify command behavior through environmental state rather than explicit input. If a dispatched task produces different output depending on which templates happen to be installed, the orchestrator has violated its own core principle. This is not a CI-only concern; even locally, a user who has not installed the preset gets different behavior than one who has, with no explicit indication of why. The preset approach optimizes for convenience at the expense of predictability.

gh-aw's alternative -- that orchestrator context should be injected into the *input* to commands, not into the *templates* commands use -- is more principled and more consistent with the constitution. Templates should remain generic; orchestrator context travels with the dispatch payload.

---

### Recommendation 3: Register orchestrator output templates as extension templates

**Status: Modified**

**Original**: Roadmap, phase plan, task plan, phase summary, and task summary templates should be placed in `.specify/extensions/orchestrator/templates/` so they participate in spec-kit's template resolution stack, enabling project-level overrides without forking the extension.

**Cross-review criticism (APM 1.4)**: Templates that spec-kit commands consume at runtime belong in the resolution stack, but knowledge artifacts that agents need for context belong in APM's context/instruction pipeline. These are different artifact categories.

**Cross-review criticism (gh-aw 2.2)**: Templates should be used for *formatting* (how output is structured) but not for *context* (what information is available). Orchestrator context should be injected explicitly, not through the template environment.

**Concession**: The original recommendation lumped together two distinct artifact categories: (a) structural formatting templates (how a roadmap or phase summary is laid out) and (b) context-bearing templates (templates that embed orchestrator state like milestone references or boundary maps). gh-aw is right that category (b) violates zero-context assumptions.

**Revised recommendation**: Register *structural formatting templates* (roadmap layout, phase summary format, task summary format) as extension templates in `.specify/extensions/orchestrator/templates/`. These define output shape, not content, and are appropriately overridable via the resolution stack. Do NOT embed orchestrator context (milestone references, phase scope, boundary maps) in templates. Orchestrator context is always injected explicitly into command inputs by the orchestrator's dispatch logic. This preserves the resolution stack's value (projects can customize output formatting) without creating hidden context dependencies.

---

### Recommendation 4: Declare `requires.commands` in the extension manifest

**Status: Surviving**

**Cross-review criticism (APM 2.3)**: `requires.commands` and `apm.yml` dependencies are two dependency declaration systems that do not know about each other. A user installing through one channel gets one set of validations but not the other.

**Cross-review criticism (gh-aw 2.4)**: `requires.commands` protects local installs but provides no safety net for CI execution. gh-aw workflows that dispatch spec-kit commands have no pre-flight check.

**Rebuttal**: Both criticisms are accurate descriptions of limitations, but neither argues against including `requires.commands`. They argue for *additional* validation in other contexts. APM's position (Section 2.3 resolution) explicitly agrees: "Both declarations should exist." gh-aw's position proposes adding a `check-prerequisites` step to CI workflows -- which is additive, not contradictory. The recommendation stands as written because it addresses the spec-kit installation path. The spec should additionally document that CI environments need their own prerequisite validation (per gh-aw's suggestion) and APM installations need `apm.yml` dependencies (per APM's suggestion). These are complementary validations at different layers, not competing approaches.

---

### Recommendation 5: Add `config_schema` to the extension manifest

**Status: Surviving**

**Cross-review criticism (gh-aw 2.5)**: A strict JSON Schema validates configuration at install time but cannot account for per-run overrides that CI dispatch enables. A developer might want to run a specific phase with `context_verbosity: full` without changing the installed config.

**Rebuttal**: The schema validates *defaults and project configuration*, not per-run overrides. Per-run overrides (whether via `SPECKIT_ORCHESTRATOR_*` env vars or workflow dispatch inputs) operate at a higher precedence layer that bypasses the schema by design. This is how JSON Schema validation works in every configuration system -- it validates the persisted configuration file, not the runtime-merged result. gh-aw's concern is valid in principle but the resolution is already built into the precedence model described in Recommendation 1 (revised): `workflow input > env var > local override > project config > extension defaults`. The schema validates the bottom two layers. Upper layers are unconstrained. The recommendation stands.

---

### Recommendation 6: Verify `before_tasks` and `before_implement` hook support in the manifest schema

**Status: Surviving**

**Cross-review criticism (APM 2.1)**: If `before_*` hooks turn out to be unsupported in the extension manifest schema, the orchestrator loses two of its four hook attachment points. APM proposes packaging hooks as APM hook JSON files under `.apm/hooks/` as a fallback.

**Cross-review criticism (gh-aw 2.1)**: For CI execution, hooks are irrelevant because each spec-kit command runs in its own workflow. The spec must support both local hooks and workflow-level orchestration.

**Rebuttal**: This recommendation is a *verification step*, not an architectural commitment. It asks the spec author to confirm whether `before_*` hooks are supported in the manifest schema before building on them. Both cross-reviews agree this verification is needed -- they propose different fallback strategies if the answer is "no." APM proposes its hook JSON system; gh-aw proposes that hook logic and workflow dispatch logic express the same semantics in two paradigms.

The recommendation stands because the verification is necessary regardless of the fallback path. I add one clarification: if `before_*` hooks are confirmed unsupported in the manifest, the fallback should be command composition (as the spec already proposes in its hybrid strategy), not APM hook JSON deployment. APM's hook system operates on IDE-level events (pre-commit, file-save), which is a fundamentally different hook surface from spec-kit's SDD lifecycle hooks. Deploying SDD lifecycle hooks through APM's IDE-event system would conflate two unrelated hook categories. The spec-kit cross-review of APM (Section 1.3) already made this argument and it holds.

---

### Recommendation 7: Reconcile skill folder architecture with spec-kit's command model

**Status: Modified**

**Original**: Map the skill folder concept (FR-028) onto spec-kit's extension primitives: trigger descriptions become command `description` fields, helper scripts go in `scripts/`, templates go in `templates/`, references go in `docs/`, preferences use the config system. Eliminate the parallel "skill folder" abstraction and map directly to what spec-kit provides.

**Cross-review criticism (APM 1.1)**: APM's skill integrator expects an intact folder with a root `SKILL.md` containing `name` and `description` frontmatter. There is no APM primitive for scattered command/scripts/templates directories that together constitute one logical unit. The skill folder is the packaging contract that enables multi-agent distribution. Spec-kit commands are the authoring format; APM skill folders are the distribution format. They serve different lifecycle phases and must coexist.

**Cross-review criticism (gh-aw 1.4)**: The skill folder defines the dispatch payload contract -- the complete, self-contained package of instructions, scripts, templates, and references a fresh agent context needs to execute a task. Dissolving skill folders into scattered extension subdirectories means there is no longer a single unit answering "what does a dispatched worker need to execute this command?"

**Concession**: The original recommendation was too aggressive. "Eliminate the parallel abstraction" was wrong. Both APM and gh-aw identify real architectural functions that the skill folder serves beyond what spec-kit's extension primitives provide: APM needs it as a deployment unit; the dispatch model needs it as a payload boundary.

However, spec-kit's concern remains valid: the extension system has no native concept of "skill folders," and the orchestrator is fundamentally a spec-kit extension. The skill folder cannot replace or override spec-kit's extension model -- it must coexist with it.

**Revised recommendation**: Preserve the skill folder as a cohesive unit but ensure it is *dual-registered* with spec-kit's extension system. Each skill folder contains: (a) a `SKILL.md` for APM's deployment pipeline, (b) a corresponding command `.md` file for spec-kit's command registration, (c) helper scripts, templates, and references co-located in the folder. The spec-kit extension manifest (`extension.yml`) registers each command by pointing to the command `.md` within the skill folder. APM's manifest (`apm.yml`) registers each skill folder as a deployable unit. The folder is the shared physical structure; each system reads the entry point it understands. This replaces "eliminate the parallel abstraction" with "the skill folder is the shared unit that both systems index into differently."

---

### Recommendation 8: Clarify the command composition mechanism

**Status: Surviving**

**Original**: The spec should specify whether orchestrator wrapping of `specify`, `plan`, and `clarify` means: (a) new `speckit.orchestrator.*` commands that internally delegate to the standard workflow, or (b) preset-based overrides that replace the standard commands. Recommendation favored option (a).

**Cross-review criticism (gh-aw 1.1)**: The wrapping model assumes a single long-running agent session. This is incompatible with CI dispatch where each workflow run is a discrete, stateless unit. The spec must decide whether orchestration commands compose within a session or dispatch across sessions.

**Cross-review support (APM 2.2)**: APM explicitly agrees with option (a) -- new commands, not overrides. APM adds that the spec should commit to option (a) and add a constraint: "The orchestrator MUST NOT override or replace core spec-kit commands via presets."

**Rebuttal of gh-aw's criticism**: gh-aw's concern is about the dispatch model, not about the composition mechanism. Option (a) -- new `speckit.orchestrator.*` commands that internally delegate -- is compatible with both session-local execution and CI dispatch. In local execution, the orchestrator command runs and delegates to the standard workflow within the same session. In CI, the orchestrator dispatches a workflow that executes the standard spec-kit command with orchestrator context injected via the dispatch payload. The "new command" model is the abstraction; how that command is invoked (locally or via dispatch) is a runtime concern.

The recommendation stands, strengthened by APM's explicit endorsement. I adopt APM's proposed constraint: "The orchestrator MUST NOT override or replace core spec-kit commands via presets." This eliminates option (b) definitively and removes the ambiguity gh-aw is concerned about. The command composition mechanism is option (a): new `speckit.orchestrator.*` commands that delegate to standard spec-kit workflows with orchestrator context injected.

---

### Recommendation 9: Define command aliases for ergonomic access

**Status: Surviving**

No cross-review criticism was directed at this recommendation. Both APM and gh-aw focused on structural and architectural concerns; command aliases are an ergonomic detail neither disputed. The recommendation stands as written.

---

### Recommendation 10: Plan for community catalog submission

**Status: Modified**

**Original**: Include in the implementation plan a step to submit the orchestrator to `catalog.community.json` once stable, making it discoverable via `specify extension search`.

**Cross-review criticism (APM 1.3)**: The community catalog is a discovery index, not a package manager -- it has no lockfile, no version pinning, no dependency graph, no CI bundle story. Positioning it as "primary distribution" means the orchestrator's complex deployment scenarios fall back to manual management. APM should be the distribution and lifecycle management system; the catalog should be a discoverability listing.

**Cross-review criticism (gh-aw 2.3)**: Three distribution mechanisms (spec-kit catalog, APM package, gh-aw workflow files) create confusion. A developer who installs via catalog does not get gh-aw workflows; one who copies gh-aw workflows does not get spec-kit commands.

**Concession**: APM is right that the original wording ("primary discovery mechanism") overstated the catalog's role. The catalog is a discoverability listing, not a distribution system. It does not replace APM's lifecycle management capabilities (lockfile, version pinning, transitive dependencies).

**Revised recommendation**: Submit the orchestrator to `catalog.community.json` as a *discoverability listing* -- the catalog entry points users to the canonical installation methods. For full lifecycle management (version pinning, lockfile tracking, CI bundles), the installation path is `apm install speckit-orchestrator`. For standalone spec-kit usage without APM, the fallback is `specify extension add <url>`. The catalog entry documents both paths and recommends APM for teams, with `specify extension add` for individual developers who do not use APM. This aligns with the spec's own priority ordering: APM packaging is a delivery concern (US8), not a distribution channel competing with the catalog.

---

## 2. New Recommendations

Cross-reviews from APM and gh-aw revealed gaps not addressed in the original UTILIZATION.md.

---

### New Recommendation A: Define a clear boundary between static configuration and dynamic runtime state

**Source**: gh-aw cross-review (Section 1.3) and APM cross-review (Section 1.2)

Both cross-reviews independently identified that the original UTILIZATION.md failed to distinguish between configuration (changes rarely, human-authored, version-controlled on main) and state (changes per-run, machine-authored, version-controlled in state directory or memory branch). The spec should draw this boundary explicitly:

- **Static configuration** lives in spec-kit's config system (extension defaults, project config, local overrides, env vars). Examples: default tier, verification commands, context verbosity, git isolation preference, dispatch budget, duration budget.
- **Dynamic runtime state** lives in `.specify/orchestrator/`. Examples: current phase, active blockers, execution log, lock files, phase summaries, knowledge accumulation, decisions register.

No configuration setting should change during orchestration execution. No runtime state should be stored in configuration files. The spec should add a table mapping each FR-040/FR-041 setting to either "config" or "state" to make this distinction concrete.

---

### New Recommendation B: Design the orchestration protocol as runtime-agnostic, with runtime adapters for platform-specific implementation

**Source**: gh-aw cross-review (Section 1.1, Summary) and spec-kit's own cross-review of gh-aw (Section 1.1, 1.4, Summary)

gh-aw's strongest insight is that the orchestrator must work across two fundamentally different execution models: within-session composition (local) and cross-session dispatch (CI). Spec-kit's own cross-review of gh-aw proposed a "Runtime Adapter" concept. This should become a formal recommendation.

The spec should define the orchestration protocol as a set of abstract operations: dispatch-task, verify-completion, advance-state, recover-from-crash, inject-context. Each operation has a defined input/output contract. Runtime adapters implement these operations using platform-native primitives:

- **Local adapter**: dispatch-task = subagent/new-session; verify-completion = shell commands on disk state; recover-from-crash = lock file detection; inject-context = command input assembly.
- **gh-aw adapter**: dispatch-task = `dispatch-workflow`; verify-completion = workflow run status + artifact checks; recover-from-crash = concurrency groups; inject-context = dispatch payload inputs.

The core orchestrator logic operates exclusively on the abstract operations. The runtime adapter is selected at invocation time based on the execution environment. This preserves spec-kit's runtime-agnostic extension model while giving gh-aw the platform-native integration it needs.

---

### New Recommendation C: Adopt APM's proposed constraint on core command non-interference

**Source**: APM cross-review (Section 2.2)

APM proposes that the spec add an explicit constraint: "The orchestrator MUST NOT override or replace core spec-kit commands via presets." This is a stronger form of what Recommendation 8 already implies, but making it a formal constraint prevents future drift toward option (b) (preset overrides) as the codebase evolves. The constraint should appear in the spec's constraints section alongside existing architectural constraints.

---

### New Recommendation D: Define which spec deliverables are committed to the repo vs. externally managed

**Source**: spec-kit's own cross-review of APM (Section 2.4)

The spec does not state whether the extension files are committed to the repository (typical for spec-kit extensions) or installed from an external package at CI time. This decision has cascading effects: if committed, `apm pack` is unnecessary for CI (files are already present in the checkout); if externally managed, either `apm install` at CI time or `apm pack` for offline environments is required. The spec should make this explicit. Spec-kit's recommendation: the extension should be committed to the repository, consistent with spec-kit's convention that extension state is version-controlled. APM packaging then serves team onboarding and initial setup, not CI artifact distribution.

---

## 3. Position Summary

The original UTILIZATION.md contained 10 recommendations. After cross-review:

| Disposition | Count | Recommendations |
|-------------|-------|-----------------|
| **Surviving** | 5 | #4 (`requires.commands`), #5 (`config_schema`), #6 (verify `before_*` hooks), #8 (command composition -- option a), #9 (aliases) |
| **Modified** | 4 | #1 (config infrastructure -- now with static/dynamic split and APM-safe placement), #3 (extension templates -- now formatting-only, no context embedding), #7 (skill folders -- coexistence not elimination), #10 (catalog -- discoverability not primary distribution) |
| **Withdrawn** | 1 | #2 (companion preset for template overrides -- violates zero-context principle) |
| **New** | 4 | A (config vs. state boundary), B (runtime-agnostic protocol with adapters), C (non-interference constraint), D (committed vs. external management) |

**Revised overall stance**: The orchestrator is first and foremost a spec-kit extension, and its core architecture must remain runtime-agnostic and grounded in spec-kit's extension primitives. This position has not changed. What has changed is the recognition that the skill folder concept serves real architectural functions (APM deployment unit, dispatch payload boundary) that spec-kit's extension model does not natively address, and that these must coexist rather than be eliminated. The original UTILIZATION.md was too aggressive in asserting spec-kit's model as the sole organizational principle.

The most significant revision is the withdrawal of Recommendation 2 (preset-based template overrides). gh-aw's criticism -- that ambient template overrides violate the orchestrator's own Constitution Principle 4 ("Plans Assume Zero Context") -- is correct and was not adequately considered in the original review. Context must travel explicitly with dispatch payloads, not implicitly through the template environment. This is a principled concession: it weakens spec-kit's template resolution stack's role in the orchestrator but strengthens the orchestrator's constitutional consistency.

The most significant addition is New Recommendation B (runtime-agnostic protocol with adapters). Both cross-reviews surfaced the tension between local and CI execution models. The runtime adapter pattern resolves this by making the orchestration protocol the source of truth and letting each runtime implement it with native primitives. This is architecturally consistent with spec-kit's position (extensions are runtime-agnostic) while giving gh-aw the design-time consideration it correctly demands.

The configuration story is now cleaner: static configuration through spec-kit's multi-layer system (with APM-safe file placement), dynamic state in `.specify/orchestrator/`, and a clear boundary between the two. This addresses concerns from both APM (overwrite safety) and gh-aw (config/state conflation).

Spec-kit's extension system remains the canonical organizational model for the orchestrator's architecture. APM packaging and gh-aw CI integration are delivery and runtime concerns that wrap this architecture -- they do not replace it.
