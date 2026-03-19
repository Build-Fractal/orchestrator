# gh-aw Review of spec-kit's Recommendations

## Dangerous Contradictions

### 1. Recommendation #4: "Use a companion preset instead of command composition for core command wrapping"

spec-kit recommends shipping a `speckit-orchestrator-preset` that **overrides** the core SDD commands (`/speckit.specify`, `/speckit.clarify`, `/speckit.plan`) to inject orchestrator context preambles. This means modifying the behavior of spec-kit's core commands globally when the preset is installed.

**Why this is dangerous for gh-aw**: gh-aw's CI execution model runs each agentic workflow as a single, stateless GitHub Actions job (`.github/aw/create-agentic-workflow.md`, lines 131-149). When the orchestrator runs in CI via gh-aw, it must have predictable, deterministic behavior from the core SDD commands. If a preset silently overrides what `/speckit.specify` or `/speckit.plan` does at install time, the CI workflow cannot reason about what those commands will actually execute. gh-aw's `steps:` (pre-execution deterministic steps) and `post-steps:` (post-execution verification) depend on knowing exactly what runs in between. A preset that rewrites core command behavior introduces invisible mutation that breaks gh-aw's verification model.

Furthermore, gh-aw's own review (Recommendation #5) explicitly recommends mapping verification commands to `steps:` and `post-steps:` blocks. If the preset silently injects orchestrator context into core commands, those injections bypass gh-aw's deterministic step boundary -- the orchestrator context would run inside the agent sandbox rather than in the auditable `steps:` layer.

**The safe alternative**: spec-kit's own review acknowledges the orchestrator should "register its own parallel commands (e.g., `speckit.orchestrator.plan` that calls `/speckit.plan` internally)" as option (a). This is compatible with gh-aw because the workflow prompt can explicitly call the namespaced orchestrator command, making the behavior visible and auditable in the workflow definition.

- spec-kit reference: Recommendation #4, citing `spec-kit/presets/README.md` (lines 22-24)
- gh-aw reference: `.github/aw/create-agentic-workflow.md` (lines 131-149), `.github/aw/github-agentic-workflows.md` (line 153, `steps:` / `post-steps:`)

### 2. Recommendation #3: "Move extension-owned state from `.specify/orchestrator/` to `.specify/extensions/orchestrator/`"

spec-kit recommends moving all orchestrator state into `.specify/extensions/orchestrator/` (for extension-scoped state) and `.specify/specs/{feature}/orchestrator/` (for feature-scoped runtime state). This scatters orchestrator state across multiple directory trees.

**Why this is dangerous for gh-aw**: gh-aw's `cache-memory` tool persists entire directory subtrees as GitHub Actions cache artifacts between workflow runs (`.github/aw/github-agentic-workflows.md`, lines 1267-1327). The gh-aw review (Recommendation #2) specifically recommends using `cache-memory` with multiple named caches: "one for roadmap, one for decisions, one for execution log." This model works cleanly when orchestrator state lives in a single, predictable directory tree (`.specify/orchestrator/`) that can be cached as a unit.

If state is scattered across `.specify/extensions/orchestrator/`, `.specify/specs/feature-a/orchestrator/`, `.specify/specs/feature-b/orchestrator/`, etc., the cache-memory configuration becomes fragile. Each feature's orchestrator state would need its own cache entry, cache keys would need to be dynamic based on the active feature, and cache restoration would need to discover which feature directories contain orchestrator state. This directly conflicts with gh-aw's design where cache keys are declared statically in the workflow frontmatter at compile time.

The spec's current approach -- a single `.specify/orchestrator/` tree -- is the correct design for CI compatibility. It maps cleanly to one or two `cache-memory` entries with stable keys.

- spec-kit reference: Recommendation #3, citing `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 784-810)
- gh-aw reference: `.github/aw/github-agentic-workflows.md` (lines 1284-1327), gh-aw UTILIZATION Recommendation #2

## Tensions

### 1. Recommendation #2: "Replace `config.json` with `orchestrator-config.yml` and a `.template.yml`"

spec-kit recommends using its standard YAML-based extension configuration system with layered overrides (project > local > env vars via `SPECKIT_ORCHESTRATOR_*`). This is a reasonable convention within the spec-kit ecosystem.

**Tension with gh-aw**: gh-aw workflows pass configuration to agents via frontmatter fields, `steps:` blocks that write JSON payloads, and `workflow_dispatch` inputs -- not via spec-kit's layered config resolution. In CI, there is no "local override" layer (the runner is ephemeral), and environment variable injection happens through GitHub Actions secrets/variables, not through `SPECKIT_ORCHESTRATOR_*` conventions.

This is a tension rather than a contradiction because both systems can coexist: the orchestrator could use spec-kit's YAML config when running locally and fall back to gh-aw's frontmatter/environment mechanism in CI. But the spec needs to explicitly document this dual-config path. If the spec only implements spec-kit's config system and ignores gh-aw's, the CI integration will require ad-hoc workarounds.

- spec-kit reference: Recommendation #2, citing `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 486-531)
- gh-aw reference: `.github/aw/github-agentic-workflows.md` (frontmatter schema, `steps:` configuration)

### 2. Recommendation #1: "Register orchestrator templates in the extension's templates/ directory"

spec-kit recommends placing roadmap templates, phase-summary templates, etc. in the extension's `templates/` directory so they participate in spec-kit's four-tier template resolution stack (overrides > presets > extensions > core).

**Tension with gh-aw**: When running in CI via gh-aw, the workspace is a fresh git checkout. Template resolution that depends on locally installed presets, user-level overrides, or extension installation state may not be available unless the workflow's `steps:` block explicitly installs spec-kit extensions before the agent runs. gh-aw's `steps:` can handle this, but it adds a setup burden that the spec does not acknowledge.

More importantly, template customization via presets (where an organization could override orchestrator templates) creates a maintenance surface that is invisible to gh-aw workflows. If a preset changes the roadmap template format, the gh-aw workflow's `post-steps:` verification commands might break because they expect the original format. This is manageable but requires the spec to document that CI verification must be template-format-aware.

- spec-kit reference: Recommendation #1, citing `spec-kit/presets/ARCHITECTURE.md` (lines 9-36)
- gh-aw reference: `.github/aw/github-agentic-workflows.md` (line 152-153, `steps:` / `post-steps:`)

### 3. Recommendation #8: "Publish to the spec-kit community catalog"

spec-kit recommends publishing to its own community catalog for `specify extension add orchestrator` installation, rather than treating APM as the primary distribution mechanism (P8).

**Tension with gh-aw**: gh-aw workflows that depend on the orchestrator extension would need the extension to be installed in the CI environment. If the orchestrator is distributed via spec-kit's catalog, the workflow would need `specify extension add orchestrator` in its `steps:` block. If it is distributed via APM, the installation mechanism is different. The spec needs to pick one canonical installation path for CI or support both explicitly. Having two competing distribution channels without a clear "CI canonical" choice creates confusion for workflow authors.

This is a mild tension -- both channels can work -- but the spec should declare which one is the recommended path for CI environments.

- spec-kit reference: Recommendation #8, citing `spec-kit/extensions/README.md` (lines 97-138)
- gh-aw reference: `.github/aw/github-agentic-workflows.md` (`steps:` for pre-execution setup)

### 4. Recommendation #6: "Declare subagent dispatch as a `requires.tools` dependency"

spec-kit recommends declaring subagent dispatch capability (e.g., Claude Code's `claude --continue`) as a `requires.tools` dependency in the extension manifest.

**Tension with gh-aw**: In gh-aw's CI execution model, "subagent dispatch" does not work the same way as in a local terminal. gh-aw provides `call-workflow` (compile-time fan-out to worker workflows) and `dispatch-workflow` (runtime async dispatch) as its dispatch primitives. These are fundamentally different from spawning a local subprocess. The `requires.tools` declaration for subagent dispatch would correctly warn local users whose agent runtime lacks the capability, but it says nothing about whether gh-aw's dispatch primitives are available. The spec needs a parallel mechanism (perhaps `requires.ci-capabilities` or a runtime detection check) to declare CI dispatch requirements.

- spec-kit reference: Recommendation #6, citing `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 36-41)
- gh-aw reference: `.github/aw/github-agentic-workflows.md` (lines 875-893, `dispatch-workflow` and `call-workflow`)

## Synergies

### 1. Recommendation #5: "Declare `requires.commands` in extension.yml"

spec-kit recommends declaring all core SDD commands the orchestrator depends on (`speckit.specify`, `speckit.clarify`, `speckit.plan`, `speckit.tasks`, `speckit.implement`) in the extension manifest.

**Why this helps gh-aw**: Explicit command dependencies make it possible for a gh-aw workflow's `steps:` block to validate that the spec-kit installation has all required commands before the agent starts. This is exactly the kind of deterministic pre-check that gh-aw's campaign pattern recommends (`.github/aw/campaign.md`, lines 64-98, "Goal-aware early exit"). A `steps:` block could run `specify extension check orchestrator` and fail fast if dependencies are missing, rather than discovering the problem mid-execution inside the agent sandbox.

- spec-kit reference: Recommendation #5
- gh-aw reference: `.github/aw/campaign.md` (lines 64-98)

### 2. Recommendation #7: "Integrate `/speckit.analyze` into the phase review stage"

spec-kit recommends invoking `/speckit.analyze` for cross-artifact consistency checks during the orchestrator's spec compliance review stage.

**Why this helps gh-aw**: gh-aw's own review (Recommendation #5) maps the spec's verification model to `post-steps:` deterministic commands. If `/speckit.analyze` is a well-defined command with a predictable exit code, it is an ideal candidate for inclusion in a `post-steps:` verification block. The more the orchestrator's verification relies on concrete, invokable commands (rather than agent judgment), the better it maps to gh-aw's deterministic verification layer. This recommendation moves the orchestrator in exactly the right direction for CI compatibility.

- spec-kit reference: Recommendation #7, citing `spec-kit/README.md` (lines 320-321)
- gh-aw reference: `.github/aw/github-agentic-workflows.md` (line 153, `post-steps:`)

### 3. Recommendation #9: "Design hook registrations to be forward-compatible"

spec-kit recommends designing hook registrations to expand as spec-kit adds new hook points (before_plan, after_plan, before_specify, after_specify), rather than hardcoding the current count of four.

**Why this helps gh-aw**: If the orchestrator gains hooks at more SDD lifecycle boundaries, gh-aw workflows can leverage those hooks for finer-grained `steps:` / `post-steps:` verification mapping. For example, a `before_plan` hook could trigger a deterministic pre-check in `steps:`, and an `after_plan` hook could trigger a `post-steps:` validation. More hooks mean more natural boundaries for gh-aw's hybrid deterministic+agentic execution model.

- spec-kit reference: Recommendation #9, citing `spec-kit/extensions/EXTENSION-API-REFERENCE.md` (lines 554-557)
- gh-aw reference: `.github/aw/github-agentic-workflows.md` (lines 152-153)

### 4. Recommendation #10: "Add `tags` for catalog discoverability"

This is a neutral recommendation about catalog metadata. It neither helps nor hinders gh-aw's model. Listed here as a synergy because better discoverability makes it easier for gh-aw workflow authors to find and install the orchestrator extension.

## Verdict

Of spec-kit's 10 recommendations:

- **2 are dangerous** (#3 state directory scattering, #4 preset-based command overriding). Following these would break gh-aw's cache-memory persistence model and its deterministic verification boundaries, respectively. The orchestrator should keep its state in a single directory tree and use namespaced commands rather than silently overriding core SDD commands.

- **4 are tensions** (#1 template registration, #2 config format, #6 requires.tools for subagent dispatch, #8 catalog distribution). These pull in a different direction from gh-aw but can coexist if the spec explicitly documents the CI execution path alongside the local execution path. The risk is that spec-kit's recommendations are designed for the local-first experience and do not account for CI constraints -- the spec needs dual-path documentation for each of these.

- **4 are safe or synergistic** (#5 requires.commands, #7 /speckit.analyze integration, #9 forward-compatible hooks, #10 catalog tags). These either directly strengthen gh-aw's CI integration model or are neutral.

**Overall assessment**: spec-kit's review is thorough and internally consistent from the spec-kit ecosystem perspective, but it does not consider CI execution constraints at any point. The two dangerous recommendations would create real integration problems if followed without modification. The orchestrator spec should treat gh-aw's CI execution model as a first-class constraint when evaluating spec-kit's recommendations -- particularly around state layout and command interception.
