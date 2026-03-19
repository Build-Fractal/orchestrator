# APM Utilization Review -- Reviewed & Revised

## Executive Summary

The original APM review made 9 recommendations for deeper APM integration into the speckit-orchestrator, arguing that APM primitives (`.prompt.md`, `.context.md`, `.instructions.md`, `SKILL.md`) should be adopted from P1 onward rather than bolted on at P8. Both cross-reviewers exposed a fundamental overreach in this position: **APM's recommendations repeatedly conflated build-time artifact management with runtime dispatch behavior**, proposing that the orchestrator adopt APM formats as canonical representations for artifacts that must be dynamically assembled during autonomous execution.

After cross-review, 3 of the 9 recommendations are withdrawn entirely, 3 are substantially modified, and 3 survive (one unchanged, two strengthened by cross-review feedback). The net effect is a much clearer boundary: APM belongs at the **distribution and static context layer** (packaging, constitution injection, coding standards propagation), not woven into the orchestrator's **dynamic dispatch and knowledge management paths**.

## Recommendation Status

### Rec 1: Model dispatch payloads as APM prompt files
**Original**: Each task dispatch should generate a `.prompt.md` file with YAML frontmatter and `${input:name}` parameter substitution, using APM's prompt system for runtime-level dispatch context assembly.
**spec-kit says**: Dangerous -- APM `.prompt.md` files use a different frontmatter schema than spec-kit command files. The orchestrator's dispatch payloads would be invisible to spec-kit's CommandRegistrar, template resolution stack, and preset override system. This creates a parallel content format inside a spec-kit extension that bypasses the host tool's entire pipeline.
**gh-aw says**: Dangerous -- gh-aw is not an "APM-supported runtime." Its dispatch model uses JSON payloads via `dispatch-workflow` inputs or `steps:` pre-computed data written to `/tmp/gh-aw/agent/`. There is no mechanism for gh-aw to discover or resolve APM prompt files with parameter substitution at runtime. Following this advice adds a runtime APM dependency to every dispatch.
**Revised position**: **Withdraw.** Both reviewers correctly identify that this recommendation asks the orchestrator to adopt an APM-specific format for its most critical runtime path. The orchestrator is a spec-kit extension first; its dispatch payloads must use spec-kit's command format and be expressible as gh-aw JSON payloads for CI. APM prompt files are the wrong abstraction here -- they solve a different problem (parameterized agent workflow templates for human-initiated runs) than what the orchestrator needs (dynamic, per-dispatch context assembly during autonomous execution).

---

### Rec 2: Write phase summaries as `.context.md` files
**Original**: Phase summaries should be written as APM context files in `.apm/context/phases/` with proper frontmatter, making them discoverable by `apm compile`.
**spec-kit says**: Tension -- phase summaries are the orchestrator's primary knowledge persistence mechanism, read and written during every phase transition. Placing them in `.apm/context/phases/` puts them outside spec-kit's managed tree. The canonical location must be within `.specify/extensions/orchestrator/`. APM discovery can be served by a build-time copy or symlink.
**gh-aw says**: Tension -- good for local development, insufficient for CI. gh-aw needs phase summaries in `cache-memory` or `repo-memory`, not the filesystem. Suggests a dual-write approach with a pluggable storage adapter.
**Revised position**: **Modify.** The original recommendation was wrong about the canonical location. Phase summaries must live under spec-kit's extension directory (`.specify/extensions/orchestrator/`), not `.apm/context/phases/`. However, the `.context.md` format itself (structured Markdown with YAML frontmatter) is a sound authoring format for phase summaries regardless of where they are stored. The revised recommendation: author phase summaries as structured Markdown with frontmatter metadata (phase, milestone, timestamp, status), store them canonically under spec-kit's extension directory, and provide a pluggable adapter layer that can mirror them to `.apm/context/` for local APM discovery or serialize them to `cache-memory` for gh-aw CI execution. The format is useful; the original storage location was wrong.

---

### Rec 3: Write boundary maps as SKILL.md files
**Original**: Each phase's boundary map should be authored as a `SKILL.md` in `.apm/skills/{phase-name}/`, using APM's skill format for discoverability.
**spec-kit says**: Tension -- boundary maps are consumed by the orchestrator itself during dispatch planning and mechanical verification. Forcing them into APM's SKILL.md format means the orchestrator must parse APM's format to read its own data structures, or maintain two copies. The format should serve the orchestrator's needs first.
**gh-aw says**: Tension -- SKILL.md files require workspace filesystem access. In gh-aw's single-job model, they must be committed to the repo for CI visibility, adding friction to dynamic orchestration.
**Revised position**: **Modify.** The original recommendation put APM's distribution format ahead of the orchestrator's operational needs. Boundary maps are the orchestrator's own data structures, consumed during dispatch planning and verification. They should be authored in whatever format best serves those operations, stored under spec-kit's extension directory. At P8, a build-time transformation can generate `SKILL.md` files from boundary maps for APM distribution -- making phase outputs discoverable by downstream agents through APM's skill system without requiring the orchestrator to use APM's format as its canonical representation. The generation step belongs in `apm pack`, not in the orchestrator's core logic.

---

### Rec 4: Narrow the "no APM at runtime" constraint
**Original**: Rewrite spec line 286 from "Must not import or wrap APM at runtime" to "Must not require APM to be installed in dispatched agent environments. The orchestrator MAY use APM CLI at setup/configuration time."
**spec-kit says**: Tension -- rewording is reasonable, but spec-kit already has its own setup mechanism (`specify extension add`, `extension.yml`, `requires.tools`). If the orchestrator requires `apm install` as a separate step, it creates a two-step installation process that breaks spec-kit extension UX. Resolution: declare APM as an optional `requires.tools` entry and handle APM setup within the orchestrator's own commands.
**gh-aw says**: Tension -- safe for local execution, but adds overhead in CI where `apm install && apm compile` would run on ephemeral runners for every workflow run. gh-aw's `dependencies:` frontmatter already handles static APM resolution at activation time.
**Revised position**: **Modify.** The core insight in the original recommendation remains valid: the spec's blanket prohibition conflates build-time tooling with runtime coupling. But both reviewers correctly identify that the rewording must be more precise about *when* APM runs and *who* initiates it. Revised constraint: "The orchestrator must not require APM to be installed in dispatched agent environments. The orchestrator MAY declare APM as an optional `requires.tools` dependency in `extension.yml`. When APM is available, the orchestrator's setup commands MAY invoke `apm install` and `apm compile` for enhanced context management. When APM is absent, all core orchestration functionality (dispatch, verification, recovery) must work without it." This preserves the original intent, respects spec-kit's installation lifecycle, and avoids making APM a hard gate on any critical path.

---

### Rec 5: Use APM `applyTo` patterns for knowledge scope filtering
**Original**: Instead of building custom scope-tag filtering, write knowledge entries as `.instructions.md` files with `applyTo` patterns and let APM's compilation engine handle scope optimization automatically.
**spec-kit says**: Dangerous -- this converts a dynamic runtime operation into a static build-time dependency. The orchestrator's knowledge scoping runs during autonomous dispatch, constructing context payloads dynamically per-task. `apm compile` is a one-time build-time operation. Either it must re-run before every dispatch (destroying performance) or the filtering becomes static and wrong.
**gh-aw says**: Dangerous -- `applyTo` patterns are designed for static, repository-level instruction scoping, not dynamic per-dispatch filtering. In gh-aw's single-job model, you cannot change which patterns are active between dispatches within a workflow run. Per-dispatch scope filtering in CI is achieved through `cache-memory` and explicit file references.
**Revised position**: **Withdraw.** Both reviewers independently identified the same fundamental flaw: APM's `applyTo` compilation is a static, build-time optimization that cannot serve the orchestrator's need for dynamic, per-dispatch knowledge scoping. This was the most clearly wrong recommendation in the original review. The orchestrator's knowledge scope changes with every dispatch cycle based on current phase, milestone, and task context -- information that does not exist at compilation time. The orchestrator must build its own scope-filtering logic (which is a core competency of an orchestration system, not something to outsource to a build tool).

---

### Rec 6: Reference APM's gh-aw integration for GitHub Workflows story
**Original**: The P7 story should build on APM's existing gh-aw integration, using gh-aw's frontmatter `dependencies:` field and `isolated: true` mode for clean dispatch contexts.
**spec-kit says**: Tension -- useful concepts to port, but the implementation should not depend on APM's gh-aw frontmatter format. The orchestrator should design its CI integration using spec-kit's own extension command system.
**gh-aw says**: Dangerous -- the `dependencies:` + `isolated: true` pattern installs a fixed set of APM primitives at activation time. It cannot express "for this particular dispatch, include these specific phase summaries." Dynamic per-dispatch context in gh-aw uses `cache-memory` and `repo-memory`, not static APM packages.
**Revised position**: **Modify.** The original recommendation was partially right and partially wrong. It was right that the orchestrator should not design a parallel gh-aw integration from scratch when patterns already exist. It was wrong about the mechanism: `dependencies:` + `isolated` is the correct pattern for *static* orchestrator context (instructions, constitution, coding standards) but the wrong pattern for *dynamic* dispatch context (phase summaries, decisions, per-task knowledge). Revised recommendation: The P7 story should use gh-aw's `dependencies:` field with the orchestrator's APM package (from Rec 8) for static context injection into worker workflows. Dynamic, per-dispatch context should use gh-aw's native persistence mechanisms (`cache-memory` for ephemeral state, `repo-memory` for durable state). The orchestrator should not attempt to vary APM package contents between dispatches. This splits the integration along the static/dynamic boundary rather than attempting to force everything through APM's resolution pipeline.

---

### Rec 7: Consider `apm pack` for milestone snapshots
**Original**: The crash recovery design should evaluate using `apm pack --archive` to create self-contained snapshots of orchestration state at phase boundaries, providing recovery and cross-machine state sharing.
**spec-kit says**: Tension -- acceptable as an optional export, dangerous if in the critical recovery path. The orchestrator's reliability mechanisms must not depend on external tools. Lightweight file-based recovery (which the spec already describes) should be the primary mechanism.
**gh-aw says**: Synergy -- complements gh-aw's `repo-memory`. Milestone snapshots packed as APM bundles and stored via `repo-memory`'s `upload-asset` pattern provide both APM-compatible unpacking and git-backed durability.
**Revised position**: **Stand**, with a clarification. Both reviewers agree this has value, and the only concern (spec-kit's) is about criticality. The original recommendation already said "evaluate using," not "require." To make this explicit: `apm pack` is an **optional, supplementary** snapshot mechanism for cross-machine state sharing and archival. The orchestrator's primary crash recovery must remain the lightweight disk-state-as-truth model described in the spec (lock files, stale detection, continue files, recovery briefings). `apm pack` adds value for a different use case: sharing partially-completed orchestration state across machines or CI environments, and creating durable milestone archives via gh-aw's `repo-memory`.

---

### Rec 8: Publish the orchestrator as a hybrid APM package at P8
**Original**: When P8 arrives, package the orchestrator with `type: hybrid` in `apm.yml`, shipping both as compilable instructions and as an installable skill, with hooks for multi-runtime deployment.
**spec-kit says**: Safe -- dual-manifest approach (`extension.yml` + `apm.yml`) is compatible with spec-kit's extension model. Spec-kit only looks for `extension.yml` and ignores other files. This expands distribution reach without requiring spec-kit changes.
**gh-aw says**: Synergy -- enables gh-aw's `dependencies:` integration for static context. Worker workflows authored as gh-aw agentic workflows get orchestrator context injected automatically at activation time.
**Revised position**: **Stand.** This is the most universally supported recommendation across all three reviews. Both cross-reviewers see it as beneficial or neutral. The hybrid package at P8 is the correct integration point for APM: it adds a distribution channel without changing the orchestrator's core architecture, respects spec-kit's extension model, and enables gh-aw's static context injection. No modification needed.

---

### Rec 9: Mirror `.specify/orchestrator/` context into `.apm/context/`
**Original**: The orchestrator should maintain a symlink or copy strategy that mirrors consumable artifacts into `.apm/context/orchestrator/` for APM primitive discovery.
**spec-kit says**: Dangerous -- creates split-brain state with three possible artifact locations. Breaks `specify extension remove` because artifacts live outside the extension manager's purview. Violates spec-kit's self-contained extension contract.
**gh-aw says**: Tension (low risk) -- good for APM discovery, orthogonal to gh-aw's `cache-memory` model. Suggests a dual-write approach with pluggable storage adapters.
**Revised position**: **Withdraw.** spec-kit's objection is decisive here. The extension self-containment contract is a hard constraint: when a user runs `specify extension remove orchestrator`, everything the orchestrator installed must be removed. Artifacts in `.apm/context/orchestrator/` would be orphaned because they live outside `.specify/`'s management. The split-brain concern (same data in `.specify/orchestrator/`, `.specify/extensions/orchestrator/`, and `.apm/context/orchestrator/`) is a real synchronization hazard. If APM discovery of orchestrator artifacts is desired, it should be handled at P8 through the hybrid package's compilation step -- a one-time build operation that reads from spec-kit's canonical location and produces APM-discoverable output. No runtime mirroring.

---

## Withdrawn Recommendations

**Rec 1 (Dispatch payloads as APM prompt files)**: Withdrawn because APM's `.prompt.md` format is designed for parameterized agent workflow templates, not for dynamic dispatch context assembly during autonomous execution. The format is invisible to spec-kit's command pipeline and incompatible with gh-aw's JSON payload model. Both cross-reviewers flagged this as dangerous.

**Rec 5 (APM `applyTo` patterns for knowledge scope filtering)**: Withdrawn because `applyTo` is a static, build-time optimization that fundamentally cannot serve the orchestrator's per-dispatch dynamic scoping needs. This was the most clearly flawed recommendation -- it asked a runtime system to delegate a core competency to a build tool. Both cross-reviewers independently identified the same structural problem.

**Rec 9 (Mirror `.specify/` into `.apm/context/`)**: Withdrawn because it breaks spec-kit's extension self-containment contract and creates a split-brain state for artifacts. The `specify extension remove` lifecycle cannot clean up artifacts stored outside `.specify/`. APM discovery should be handled at the distribution boundary (P8), not through runtime mirroring.

## Modified Recommendations

### Rec 2 (Revised): Phase summaries as structured Markdown with pluggable storage

Phase summaries should be authored as structured Markdown with YAML frontmatter metadata (phase, milestone, timestamp, status, dependencies). The **canonical location** is under spec-kit's extension directory (`.specify/extensions/orchestrator/phases/`), not `.apm/context/phases/`. A pluggable storage adapter layer should support:
- **Local development**: Read/write directly from the canonical spec-kit location.
- **APM discovery**: At `apm compile` time (or via the P8 hybrid package), copy relevant summaries into `.apm/context/` for APM-aware agents. This is a build-time export, not a runtime mirror.
- **CI execution**: Serialize summaries to gh-aw `cache-memory` or `repo-memory` for cross-run persistence.

**What changed**: Canonical location moved from `.apm/context/phases/` to `.specify/extensions/orchestrator/phases/`. Added pluggable adapter concept. Made APM discovery a build-time export rather than a runtime concern.

### Rec 3 (Revised): Boundary maps in orchestrator-native format with SKILL.md generation at P8

Boundary maps should be authored in whatever format best serves the orchestrator's dispatch planning and mechanical verification needs, stored under `.specify/extensions/orchestrator/boundaries/`. At P8, when the orchestrator is packaged as a hybrid APM package, a build-time transformation step should generate `SKILL.md` files from boundary maps. This makes phase outputs discoverable through APM's skill system for distribution consumers without requiring the orchestrator to adopt APM's format as its canonical representation.

**What changed**: Removed the requirement to author boundary maps as SKILL.md files. Moved SKILL.md generation to a P8 build-time transformation. Canonical format and location determined by orchestrator needs, not APM conventions.

### Rec 4 (Revised): Narrowed constraint with spec-kit lifecycle integration

The spec's "Must not import or wrap APM at runtime" should be replaced with: "The orchestrator must not require APM to be installed in dispatched agent environments. The orchestrator MAY declare APM as an optional `requires.tools` dependency in `extension.yml`. When APM is available, the orchestrator's setup commands MAY invoke `apm install` and `apm compile` for enhanced context management. When APM is absent, all core orchestration functionality (dispatch, verification, recovery) must work without it."

**What changed**: Added explicit optional semantics. Integrated with spec-kit's `requires.tools` mechanism. Added the hard constraint that core functionality must work without APM. Addressed gh-aw's concern about CI overhead by making clear that APM is never in the critical dispatch path.

### Rec 6 (Revised): Split gh-aw integration along static/dynamic boundary

The P7 story should use gh-aw's `dependencies:` field with the orchestrator's APM hybrid package (from Rec 8) for **static** context injection: instructions, constitution, coding standards. Worker workflows declare the orchestrator package with `isolated: true` for clean context. **Dynamic** per-dispatch context (phase summaries, decisions, task-specific knowledge) should use gh-aw's native persistence: `cache-memory` for ephemeral cross-run state, `repo-memory` for durable milestone state. The orchestrator should not attempt to vary APM package contents between dispatches.

**What changed**: Split the recommendation into static (APM-served) and dynamic (gh-aw-native) paths. Removed the suggestion that all context flows through APM's gh-aw integration. Acknowledged that `dependencies:` resolves once at activation time and cannot express per-dispatch variation.

## Surviving Recommendations

### Rec 7: `apm pack` for optional milestone snapshots (Unchanged)

Both cross-reviewers found this recommendation acceptable (spec-kit: manageable tension; gh-aw: synergy). The key qualifier -- "optional, supplementary" rather than "in the critical recovery path" -- was already present in the original recommendation's language ("should evaluate using"). The orchestrator's primary crash recovery remains the lightweight disk-state model. `apm pack` adds value for cross-machine state sharing and durable archival, complementing gh-aw's `repo-memory` for CI scenarios.

### Rec 8: Hybrid APM package at P8 (Unchanged, strengthened)

This was the only recommendation rated "safe" by spec-kit and "synergy" by gh-aw. It is the correct integration point for APM: the distribution boundary. The hybrid package approach (shipping both `extension.yml` and `apm.yml`) expands the orchestrator's distribution reach through APM registries, enables gh-aw's `dependencies:` field for worker context injection, and requires zero changes to spec-kit's extension model. This recommendation is strengthened by cross-review consensus: it validates the principle that APM's value to the orchestrator is at the packaging and distribution layer, not the runtime dispatch layer.

## Lessons Learned

**1. Build-time tools must not be prescribed for runtime problems.** The three withdrawn recommendations (1, 5, 9) all shared a common flaw: they asked the orchestrator to use APM's build-time mechanisms (`apm compile`, `applyTo` patterns, primitive discovery) for what are fundamentally runtime operations (per-dispatch context assembly, dynamic knowledge scoping, live artifact synchronization). APM's compilation model runs once and produces static output. The orchestrator's dispatch model runs continuously and produces dynamic, per-task-varying output. These are structurally incompatible, and the original review failed to recognize the boundary.

**2. The host tool's conventions are the canonical conventions.** The orchestrator is a spec-kit extension. Its artifacts must live where spec-kit expects them (`.specify/extensions/orchestrator/`), use formats spec-kit can process, and participate in spec-kit's lifecycle (`specify extension add/remove`). APM can consume these artifacts through build-time exports and distribution-time transformations, but it cannot dictate the canonical format or location. The original review implicitly treated APM as the primary tool and spec-kit as a secondary concern -- the inverse of reality.

**3. Static vs. dynamic is the correct integration boundary.** The most productive outcome of the cross-review is a clear taxonomy: APM is excellent for static context (coding standards, constitution, orchestrator instructions, phase boundary documentation) that is resolved once and does not change between dispatches. It is the wrong tool for dynamic context (per-dispatch knowledge, evolving phase summaries, task-specific decisions) that must vary with every orchestration cycle. The revised recommendations (especially Rec 6) now respect this boundary explicitly.

**4. Distribution is where APM adds unique, uncontested value.** The universal agreement on Rec 8 (hybrid package at P8) confirms that APM's strongest contribution to the orchestrator is as a distribution mechanism -- making the orchestrator installable via `apm install` and discoverable through APM registries. This is value that neither spec-kit nor gh-aw provides on their own. The original review correctly identified this but diluted the message by also claiming APM should own the orchestrator's runtime context management.

**5. Cross-tool reviews expose single-tool tunnel vision.** The original APM review saw every orchestrator problem through APM's lens: knowledge scoping became `applyTo` patterns, dispatch payloads became `.prompt.md` files, boundary maps became `SKILL.md` files. This is natural but wrong. An orchestrator that lives at the intersection of three tools (spec-kit, APM, gh-aw) must use each tool for what it does best, not adopt one tool's abstractions for everything. The cross-review process was essential for exposing this bias.
