# spec-kit Review of APM's Recommendations

## Dangerous Contradictions

### DC-1: APM Recommendation #9 -- Mirror `.specify/orchestrator/` into `.apm/context/`

**APM recommendation (Rec #9):** "The orchestrator should maintain a symlink or copy strategy that mirrors consumable artifacts (decisions register, knowledge file, active phase summary) into `.apm/context/orchestrator/` so APM's primitive discovery can find and compile them."

**Conflict:** This directly violates spec-kit's extension directory convention and creates a split-brain state for orchestrator artifacts. Spec-kit's extension system requires extension-specific state to live under `.specify/extensions/{extension-id}/` (EXTENSION-API-REFERENCE.md, lines 784-810). The spec-kit UTILIZATION review (Rec #3) already flagged that even the spec's proposed `.specify/orchestrator/` path is wrong -- the correct path is `.specify/extensions/orchestrator/`.

APM's recommendation goes further in the wrong direction: it asks the orchestrator to maintain *a second copy* of artifacts under `.apm/context/orchestrator/`, which is entirely outside the `.specify/` tree. This creates three possible locations for the same data (`.specify/orchestrator/`, `.specify/extensions/orchestrator/`, `.apm/context/orchestrator/`) with no clear canonical source. If the orchestrator follows APM's advice here, it breaks spec-kit's self-contained extension convention, introduces symlink fragility, and means the extension cannot be cleanly removed via `specify extension remove orchestrator` because artifacts live outside the extension manager's purview.

**Severity:** Dangerous. Following this advice breaks `specify extension remove`, breaks the self-contained extension contract, and introduces synchronization bugs between mirrored locations.

**spec-kit docs:** `spec-kit/extensions/EXTENSION-API-REFERENCE.md` lines 784-810 (file system layout); `spec-kit/extensions/RFC-EXTENSION-SYSTEM.md` "Architecture Overview" section (directory structure).

---

### DC-2: APM Recommendation #1 -- Model dispatch payloads as APM `.prompt.md` files

**APM recommendation (Rec #1):** "Each task dispatch should generate a `.prompt.md` file with YAML frontmatter declaring `input:` parameters for the task-specific variables (phase context, upstream summaries, decisions). APM's prompt system already supports `${input:name}` parameter substitution."

**Conflict:** This recommendation asks the orchestrator to author its dispatch payloads as APM primitives with APM-specific frontmatter syntax (`${input:name}` parameter substitution, APM `applyTo` patterns). The orchestrator spec (line 283) explicitly states: "Must not import or wrap GSD-2 or APM at runtime -- principles are ported, not dependencies." While APM's review argues this constraint is "too broad," following Rec #1 would make the orchestrator's core dispatch mechanism -- the most critical runtime path -- dependent on APM's prompt format specification.

More fundamentally, spec-kit extensions author commands as universal Markdown files with spec-kit's own frontmatter format (`description`, `tools`, `scripts` fields per EXTENSION-DEVELOPMENT-GUIDE.md lines 226-237). APM `.prompt.md` files use a different frontmatter schema. An orchestrator that generates APM `.prompt.md` files would be producing artifacts that spec-kit's `CommandRegistrar` cannot process, that spec-kit's template resolution stack cannot find, and that do not participate in spec-kit's preset override system. The orchestrator's dispatch payloads would be invisible to spec-kit's entire toolchain.

**Severity:** Dangerous. This creates a parallel content authoring format inside a spec-kit extension that bypasses spec-kit's command registration, template resolution, and preset override systems entirely.

**spec-kit docs:** `spec-kit/extensions/EXTENSION-DEVELOPMENT-GUIDE.md` lines 224-258 (command file format); `spec-kit/presets/ARCHITECTURE.md` lines 9-36 (template resolution stack); `spec-kit/extensions/EXTENSION-API-REFERENCE.md` lines 416-478 (command file format).

---

### DC-3: APM Recommendation #5 -- Use APM `applyTo` patterns instead of orchestrator scope filtering

**APM recommendation (Rec #5):** "Instead of building custom scope-tag filtering (spec lines 162-163), write knowledge entries as `.instructions.md` files with `applyTo` patterns that match the phase's file scope. APM's compilation engine will handle the optimization automatically."

**Conflict:** This recommendation asks the orchestrator to delegate its knowledge scoping -- a core runtime behavior -- to APM's compilation engine. The orchestrator's knowledge management is not a build-time concern; it runs during autonomous dispatch, constructing context payloads dynamically as each task is dispatched. APM's `apm compile` is a build-time operation that runs once and produces static output. The orchestrator needs to scope knowledge entries *per-dispatch* based on the current phase, milestone, and task context -- information that changes with every dispatch cycle.

If the orchestrator writes knowledge entries as APM `.instructions.md` files and relies on `apm compile` for filtering, then either (a) `apm compile` must be re-run before every single task dispatch (destroying the orchestrator's performance and creating a build-time dependency on APM during autonomous execution), or (b) the filtering becomes static and wrong, injecting stale or irrelevant knowledge into dispatch payloads.

This also contradicts spec-kit's own architecture: spec-kit does not use APM's `applyTo` patterns anywhere in its template resolution or hook system. Introducing APM instruction files into a spec-kit extension creates a dependency on a tool that spec-kit itself does not integrate with at the extension level.

**Severity:** Dangerous. This converts a dynamic runtime operation into a static build-time dependency, breaking autonomous dispatch performance and creating an undeclared runtime dependency on APM's compilation engine.

**spec-kit docs:** The extension system has no concept of APM `.instructions.md` files or `applyTo` patterns. Spec-kit's knowledge/memory convention is `.specify/memory/constitution.md` (README.md, line 519) and extension-specific config under `.specify/extensions/{ext-id}/` (EXTENSION-API-REFERENCE.md lines 484-531).

---

## Tensions

### T-1: APM Recommendation #4 -- Narrow the "no APM at runtime" constraint

**APM recommendation (Rec #4):** "Rewrite spec line 286 from 'Must not import or wrap APM at runtime' to 'Must not require APM to be installed in dispatched agent environments. The orchestrator MAY use APM CLI at setup/configuration time.'"

**Tension:** APM's proposed rewording is technically reasonable -- using `apm install` during initial setup is qualitatively different from requiring APM during dispatch. However, spec-kit's extension model already has its own setup/configuration mechanism: `specify extension add` handles installation, `extension.yml` handles configuration, and `requires.tools` handles declaring external tool dependencies (EXTENSION-API-REFERENCE.md lines 36-41). If the orchestrator declares APM as a `requires.tools` dependency, the spec-kit extension installer will already warn users who lack it.

The tension is about where the line sits: spec-kit expects extensions to be self-contained packages that work within spec-kit's lifecycle (`specify extension add`, `specify extension remove`). If the orchestrator requires `apm install` as a separate setup step outside the spec-kit lifecycle, it creates a two-step installation process that breaks user expectations set by every other spec-kit extension.

**Resolution path:** If APM integration is desired, declare it as an optional `requires.tools` entry in `extension.yml` and handle the APM setup within the orchestrator's own commands (e.g., `speckit.orchestrator.setup` that optionally runs `apm install` if APM is present). Do not make APM a hard prerequisite for the extension to function.

---

### T-2: APM Recommendation #2 -- Write phase summaries as `.context.md` files in `.apm/context/phases/`

**APM recommendation (Rec #2):** "Phase summaries should be written as APM context files in `.apm/context/phases/` with proper frontmatter."

**Tension:** Phase summaries are the orchestrator's primary knowledge persistence mechanism, read and written during every phase transition. APM wants them in `.apm/context/phases/`; spec-kit wants extension artifacts under `.specify/extensions/orchestrator/` or co-located with the feature at `.specify/specs/{feature}/orchestrator/`. These are different directories with different ownership semantics.

The deeper tension: APM treats context files as build-time artifacts that get compiled into `AGENTS.md`. Spec-kit treats extension artifacts as runtime files that participate in the template resolution stack and are managed by `specify extension remove`. If phase summaries live in `.apm/`, they exist outside spec-kit's management and cleanup paths. If they live in `.specify/`, APM's discovery cannot find them.

**Resolution path:** The orchestrator should store phase summaries in spec-kit's directory structure (`.specify/extensions/orchestrator/` or `.specify/specs/{feature}/orchestrator/`). If APM distribution is added at P8, a build-time step can copy or symlink these into `.apm/context/` as part of `apm compile` -- but the canonical location must be within spec-kit's managed tree.

---

### T-3: APM Recommendation #3 -- Write boundary maps as `SKILL.md` files in `.apm/skills/`

**APM recommendation (Rec #3):** "Each phase's boundary map should be authored as a `SKILL.md` in `.apm/skills/{phase-name}/`."

**Tension:** Boundary maps are a core orchestrator concept -- they declare what each phase produces and what downstream phases consume. APM wants these as `SKILL.md` files (a specific APM primitive type with its own format). But boundary maps are consumed by the orchestrator itself during dispatch planning and mechanical verification, not by APM's skill discovery system.

Writing boundary maps in APM's `SKILL.md` format would mean the orchestrator must parse APM's skill format to read its own data structures, or maintain two copies (one in APM format for APM discovery, one in the orchestrator's own format for dispatch). Neither approach is clean.

**Resolution path:** Boundary maps should be authored in whatever format the orchestrator needs for its own dispatch and verification logic, stored under spec-kit's extension directories. At P8, an APM packaging step can generate `SKILL.md` files from boundary maps as a distribution-time transformation.

---

### T-4: APM Recommendation #6 -- Reference APM's gh-aw integration for GitHub Workflows story

**APM recommendation (Rec #6):** "The P7 story should build on APM's existing gh-aw integration rather than designing a parallel approach. Specifically, leverage gh-aw's frontmatter `dependencies:` field to declare the orchestrator's APM package."

**Tension:** This pulls the orchestrator's CI integration toward APM's gh-aw integration model, which uses APM-specific frontmatter (`dependencies:` fields that reference APM packages). Spec-kit does not have a native gh-aw integration -- this would be entirely new territory. The tension is whether the orchestrator's GitHub Workflow mode should be designed as a spec-kit-native pattern (using spec-kit's own extension and command system) or as an APM-flavored pattern (using gh-aw frontmatter and APM package declarations).

**Resolution path:** The orchestrator should design its GitHub Workflow integration using spec-kit's own extension command system. The gh-aw `isolated` mode concept (dispatching agents with clean context) is a useful *idea* to port, but the implementation should not depend on APM's gh-aw integration or frontmatter format. This aligns with the spec's own constraint: "principles are ported, not dependencies."

---

### T-5: APM Recommendation #7 -- Use `apm pack` for milestone snapshots

**APM recommendation (Rec #7):** "The crash recovery design should evaluate using `apm pack --archive` to create self-contained snapshots of orchestration state at phase boundaries."

**Tension:** This is a mild tension. The orchestrator's crash recovery (spec lines 170-178) is designed around disk-state-as-truth: lock files, stale detection, continue files, and recovery briefings. These are lightweight, file-based mechanisms. `apm pack` creates enriched bundles with lockfiles and traceability -- a heavier-weight approach that introduces an APM dependency in the crash recovery path.

If `apm pack` is used for recovery and APM is not installed (or the pack format changes), crash recovery breaks. The orchestrator's reliability mechanisms must not have external tool dependencies.

**Resolution path:** The orchestrator should implement its own lightweight snapshotting (which the spec already describes). At P8, if APM packaging is added, `apm pack` could be an *optional* additional export format for sharing state across machines, but it must not be in the critical path for crash recovery.

---

## Synergies

### S-1: P8 packaging as a hybrid APM package (APM Rec #8)

APM's recommendation to package the orchestrator as a `type: hybrid` APM package at P8 is well-aligned with spec-kit's model. Spec-kit already acknowledges that extensions can be distributed through multiple channels -- the community catalog (`catalog.community.json`), direct URLs, and local development mode. Adding APM as a third distribution channel does not conflict with spec-kit's extension system as long as the APM package installs *into* `.specify/extensions/orchestrator/` with a valid `extension.yml`. APM's hybrid package type supports shipping both an `extension.yml` and an `apm.yml`, which is the correct dual-identity approach.

This recommendation strengthens spec-kit's position because it expands the orchestrator's distribution reach without requiring changes to spec-kit's extension manager.

---

### S-2: Disk-as-truth alignment (APM "Alignment" section)

APM correctly identifies that its lockfile-based approach (`apm.lock.yaml` recording `deployed_files`) is philosophically compatible with spec-kit's file-based state model and the orchestrator's disk-state-as-truth architecture. This shared design principle means the two tools will not fight over state management semantics, even if they are used together in the same project.

---

### S-3: Constitution injection is already wired (APM "Alignment" section)

APM notes that constitution injection during `apm compile` already propagates the constitution to `AGENTS.md`. This is genuinely useful: if a project uses both APM and spec-kit, the orchestrator's constitutional governance will automatically flow into APM-compiled agent contexts without extra work. This strengthens the orchestrator's governance model in APM-using projects.

---

### S-4: Extension manifest dual-identity (APM "Alignment" section)

APM correctly notes that the orchestrator can ship both `extension.yml` (for spec-kit) and `apm.yml` (for APM distribution) without conflict. This is accurate -- spec-kit's extension manager only looks for `extension.yml` and ignores other files. The two manifests can coexist in the same directory with zero interference.

---

## Verdict

APM's review contains 9 actionable recommendations. From spec-kit's perspective:

| # | Recommendation | Assessment | Risk Level |
|---|---------------|-----------|------------|
| 1 | Dispatch payloads as APM `.prompt.md` files | **Dangerous** -- bypasses spec-kit's command format, template resolution, and preset system | High |
| 2 | Phase summaries as `.context.md` in `.apm/context/` | **Risky** -- puts artifacts outside spec-kit's managed tree; usable only as a secondary export, not canonical location | Medium |
| 3 | Boundary maps as `SKILL.md` in `.apm/skills/` | **Risky** -- forces APM format on orchestrator's own data structures; usable only as a distribution-time export | Medium |
| 4 | Narrow "no APM at runtime" constraint | **Tension** -- rewording is reasonable but must not create a two-step install that breaks spec-kit extension UX | Low-Medium |
| 5 | Use APM `applyTo` for knowledge scope filtering | **Dangerous** -- converts dynamic runtime scoping into static build-time compilation, breaks autonomous dispatch | High |
| 6 | Reference APM's gh-aw integration for P7 | **Tension** -- useful concepts to port, but implementation should not depend on APM's gh-aw frontmatter | Medium |
| 7 | Use `apm pack` for milestone snapshots | **Tension** -- acceptable as an optional export, dangerous if in the critical recovery path | Low-Medium |
| 8 | Publish as hybrid APM package at P8 | **Safe** -- dual-manifest approach is compatible with spec-kit's extension model | Low |
| 9 | Mirror `.specify/` artifacts into `.apm/context/` | **Dangerous** -- breaks extension self-containment, cleanup, and creates split-brain state | High |

**Summary:**

- **Safe:** 1 recommendation (Rec #8)
- **Tension (manageable with care):** 4 recommendations (Recs #4, #6, #7, and #2/#3 if relegated to export-only)
- **Dangerous:** 3 recommendations (Recs #1, #5, #9)

**Overall assessment:** APM's review is thorough and well-researched, but it consistently overreaches by asking the orchestrator to adopt APM primitives (`.prompt.md`, `.context.md`, `.instructions.md`, `SKILL.md`) as the *canonical* format for orchestrator artifacts. This approach would make the orchestrator an APM extension that happens to also be a spec-kit extension, rather than a spec-kit extension that can optionally be distributed via APM. The orchestrator's primary identity must be as a spec-kit extension, using spec-kit's formats, directories, and lifecycle conventions. APM integration belongs at the distribution boundary (P8), not woven into the core dispatch and knowledge management paths (P1-P6).

The three dangerous recommendations (#1, #5, #9) share a common pattern: they ask the orchestrator to place artifacts or logic outside spec-kit's managed directories and format conventions. Following any of them would make the orchestrator uninstallable via `specify extension remove`, invisible to spec-kit's preset system, and dependent on APM for core functionality -- all of which contradict the spec's own design constraints and spec-kit's extension contract.
