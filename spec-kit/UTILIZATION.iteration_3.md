# spec-kit Utilization Review -- Iteration 3 (Final)

## Position Evolution

**Original review (UTILIZATION.md)**: Produced 10 recommendations from a pure spec-kit-centric perspective, treating spec-kit as the sole governance tool for the orchestrator's extension lifecycle, state layout, configuration, and distribution. Correctly identified real integration gaps but framed every recommendation as a spec-kit compliance requirement.

**Iteration 1 (UTILIZATION.iteration_1.md)**: Cross-reviews from APM and gh-aw exposed that spec-kit's extension conventions assumed a single-consumer world. Three recommendations withdrawn (config format lock-in, state directory scattering, preset-based command overriding). Four modified for multi-tool awareness. Three survived unchanged as synergy points. The most "textbook-correct" single-tool advice turned out to be the most harmful in the multi-tool context.

**Iteration 2 (UTILIZATION.iteration_2.md)**: Resolved the crossed-wires state directory problem, locked 10 consensus points, and defined concrete compromises for 3 remaining disputes: (1) canonical state path, (2) APM discovery timeline, (3) pluggable storage adapter ownership. spec-kit proposed a tiered discovery approach (no APM access until P7) and deferred the adapter to P8.

**Iteration 3 (this document)**: All three disputes resolved. spec-kit conceded on the APM discovery timeline (from P7 to P1), recognizing that APM reading files from a known path is not an architectural dependency. The adapter concept was formally retired by all three tools. The state path dispute, which was already functionally resolved in iteration 2, was formally closed with implementation-level justification from spec-kit's own `ExtensionManager` code.

---

## Dispute Resolutions

### Dispute 1: State Path -- RESOLVED

**Final position**: `.specify/orchestrator/` is the canonical state path for orchestrator runtime state. `.specify/extensions/orchestrator/` is managed by `ExtensionManager` for the extension's own installable artifacts (manifest, commands, templates, config files).

**How convergence was reached**: This dispute was functionally resolved in iteration 2, with all three tools having independently arrived at `.specify/orchestrator/`. The iteration 3 dispute filings confirmed this convergence and added implementation-level precision.

spec-kit provided the strongest technical justification: the `ExtensionManager.remove()` method calls `shutil.rmtree(extension_dir)` on `.specify/extensions/{id}/`. If runtime state (roadmaps, phase summaries, decisions, knowledge files) lived inside `.specify/extensions/orchestrator/`, uninstalling the extension would destroy all accumulated project knowledge with no recovery path. The spec's own design already accounts for this separation ("All orchestrator state lives under `.specify/orchestrator/`, separate from spec-kit's specs/ feature directories").

APM confirmed that its `BaseIntegrator` framework and `apm compile` use configurable glob patterns and do not care about the path string. gh-aw confirmed that its `cache-memory` primitive only needs a single, static cache key and a directory path -- satisfied by either candidate path.

**Operational semantics of `specify extension remove orchestrator`**:
- `.specify/extensions/orchestrator/` is deleted (extension machinery: manifest, commands, config)
- `.specify/orchestrator/` is NOT deleted (accumulated project knowledge)
- A user-facing message warns that orchestrator state was preserved and can be manually removed

**The extension manifest's `state_dir` field** points to `.specify/orchestrator/` so that `specify extension info orchestrator` discovers runtime state without relying on path convention.

No concessions were needed. All three tools agreed.

---

### Dispute 2: APM Discovery Timeline -- RESOLVED

**Final position**: APM may compile orchestrator artifacts from P1 onward, using a unilateral APM-side mechanism (either `compilation.include_paths` in `apm.yml` or a `SpeckitOrchestratorIntegrator` built on APM's `BaseIntegrator` framework). This requires zero changes to the orchestrator or to spec-kit's extension contract.

**How convergence was reached**: spec-kit's iteration 2 proposed deferring APM discovery to P7 out of concern that earlier access would create an architectural coupling between the orchestrator and APM. In iteration 3, spec-kit recognized this was a category error: `apm compile` reading files from a known path is not a dependency relationship. The orchestrator does not know APM exists. It writes files for its own purposes. If APM reads those files, that is a consequence of the working tree being canonical (locked consensus point 8), not an import or coupling.

APM proposed its Option 2 (a `SpeckitOrchestratorIntegrator` that reads from `.specify/orchestrator/` at compile time). This mechanism satisfies every hard stance spec-kit articulated in iteration 2:
1. No canonical artifacts outside `.specify/` -- the integrator reads from `.specify/orchestrator/` and writes into APM's own compilation output; the orchestrator never touches `.apm/`.
2. `specify extension remove` must clean up everything the extension installed -- APM Option 2 requires no extension-managed artifacts outside `.specify/orchestrator/`.
3. No build-time APM dependency in the runtime path -- `apm compile` is a developer-initiated command, not a runtime dependency.

gh-aw had no stake in the local-development timeline and confirmed that the CI lifecycle step for `apm compile` is already optional and degrades gracefully.

**spec-kit's concession**: spec-kit moved from "defer APM discovery to P7" to "APM can read from P1 onward, as long as it is entirely APM-maintained." This was the only genuine position shift spec-kit made in iteration 3.

**Constraints on the resolution**:
- The orchestrator does not create files in `.apm/` or manage any symlink to `.apm/`. APM's iteration 1 symlink proposal is formally dead.
- APM builds and maintains its own integrator. If the orchestrator changes its file layout, that is APM's problem to track -- the same as any downstream consumer of an upstream schema.
- The orchestrator spec documents the directory layout (file locations, schemas) in its expanded P7 section as the canonical storage contract. APM's integrator depends on this documented layout.
- The P8 hybrid package build step uses the same integrator, not a separate mechanism. P8 does not introduce new discovery; it packages the compilation output for distribution.

---

### Dispute 3: Adapter Ownership -- RESOLVED

**Final position**: The "pluggable storage adapter" concept is formally retired. It does not appear in any future iteration or in the orchestrator specification at any phase. The individual pieces of work it was meant to encompass are reframed as three independent, tool-scoped deliverables.

**How convergence was reached**: All three tools independently concluded that the adapter was solving a problem that no longer exists. The adapter was invented to synchronize artifacts across three storage locations (`.specify/orchestrator/`, `.apm/context/`, gh-aw `cache-memory`). With the resolution of Dispute 2:
- APM reads directly from `.specify/orchestrator/` via its integrator. No second copy to synchronize.
- gh-aw's `cache-memory` is a transport layer, not a storage location. It persists and restores the `.specify/orchestrator/` directory as an opaque blob.
- The third "backend" (`.apm/context/`) was withdrawn in APM's iteration 1 (Rec 9 withdrawal).

When the three "backends" reduce to one canonical location plus one transport mechanism, the adapter reduces to "read files from a directory." That is not an adapter pattern.

APM formally buried the concept. gh-aw dissolved it into tool-scoped specifications. spec-kit confirmed it was a derivative of Dispute 2 that collapsed when Dispute 2 was resolved.

**What remains as concrete deliverables**:
1. **Canonical storage contract (spec-kit owns)**: Document the directory layout, file formats, schemas, and concurrent-read safety guarantees of `.specify/orchestrator/` in the orchestrator spec's P7 section.
2. **CI persistence configuration (gh-aw owns)**: Document `cache-memory` entry configuration for persisting `.specify/orchestrator/` across CI runs -- key naming, retention policy, allowed extensions, restore/persist lifecycle. This is standard gh-aw frontmatter configuration, not an adapter specification.
3. **Build-time discovery integration (APM owns)**: Build the `SpeckitOrchestratorIntegrator` in APM's `BaseIntegrator` framework to read orchestrator artifacts during `apm compile`. This runs during the optional `apm compile` step in the CI lifecycle and during local development.

Each tool owns its own piece. No shared "adapter" layer. No cross-tool coordination beyond the documented storage contract.

---

## Final Recommendations (All Iterations Cumulative)

### 1. Register orchestrator structural templates in the extension's templates/ directory
**Status**: Locked from iteration 1

The orchestrator's structural templates (roadmap-template.md, phase-summary-template.md, task-summary-template.md, decision-register-template.md) are registered in the extension's `templates/` directory to participate in spec-kit's four-tier resolution stack (overrides > presets > extensions > core). These are document shapes before fill-in, not filled runtime artifacts. Preset-based customization of these shapes is a legitimate spec-kit capability. CI workflows must include `specify extension add orchestrator` in their `steps:` block before agent execution. The orchestrator spec's expanded P7 section includes the canonical `steps:` block showing extension installation.

### 2. Use format-neutral configuration
**Status**: Locked from iteration 1 (withdrawn)

Withdrawn. The orchestrator uses a format-neutral configuration file not bound to any single tool's resolution stack. spec-kit's proprietary layered config system is not imposed. All three tools consume the neutral config through their own mechanisms. gh-aw reads budget values from whatever config the spec designates.

### 3. State directory: `.specify/orchestrator/` for runtime state, `.specify/extensions/orchestrator/` for extension machinery
**Status**: Locked from iteration 3

The orchestrator's canonical runtime state directory is `.specify/orchestrator/`. This path explicitly signals that the orchestrator's state has consumers beyond spec-kit. The extension convention path `.specify/extensions/orchestrator/` is reserved for ExtensionManager-managed installable artifacts (manifest, commands, templates, config). Extension removal destroys the latter; the former is preserved with a user warning. The extension manifest's `state_dir` field enables discovery without path convention.

### 4. Namespaced commands over command overriding
**Status**: Locked from iteration 1 (withdrawn)

Withdrawn. The orchestrator uses namespaced commands (`speckit.orchestrator.specify`, `speckit.orchestrator.clarify`, `speckit.orchestrator.plan`) that invoke unmodified core SDD commands with orchestrator context injected. No presets, no command overriding, no silent mutation of core command behavior. This was the strongest convergence signal in the entire process -- two tools with completely different architectures independently proposed the identical alternative for different reasons.

### 5. Declare requires.commands in extension.yml
**Status**: Locked from iteration 1 (unchanged)

The orchestrator's extension.yml declares dependencies on all core SDD commands it invokes: `speckit.specify`, `speckit.clarify`, `speckit.plan`, `speckit.tasks`, `speckit.implement`. Install-time validation complements APM's package-level dependency checks and enables gh-aw fast-failure in CI.

### 6. Declare subagent dispatch as requires.tools (local execution only)
**Status**: Locked from iteration 1

The extension.yml declares subagent dispatch capability (e.g., Claude Code's `claude --continue`) as a `requires.tools` dependency for the local execution path. This causes a non-blocking warning when the user's agent runtime lacks subagent support. CI dispatch uses gh-aw's `call-workflow`/`dispatch-workflow` primitives and is explicitly excluded from this declaration.

### 7. Integrate /speckit.analyze into the phase review stage
**Status**: Locked from iteration 1 (unchanged)

The orchestrator's two-stage phase review invokes `/speckit.analyze` for cross-artifact consistency checks during the spec compliance stage. A concrete verification command with a predictable exit code that serves spec-kit's hook system, APM's context validation, and gh-aw's `post-steps:` blocks simultaneously.

### 8. Dual-channel distribution with spec-kit-first CI sequencing
**Status**: Locked from iteration 2

The orchestrator is published to both the spec-kit community catalog and as an APM package. Authority split: spec-kit is authoritative for extension machinery (commands, hooks, template registration, extension lifecycle); APM is authoritative for context primitives (compiled context, skill files, prompt workflows, distribution packaging). CI installation sequence: (1) `specify extension add orchestrator` first, then (2) APM context installation if APM is present. Phase summaries are extension state during orchestration runtime (P1-P7) and become context primitives at distribution time (P8) -- the same artifact crosses the authority boundary when its lifecycle phase changes.

### 9. Forward-compatible hook design with documented execution order
**Status**: Locked from iteration 2

The orchestrator registers hooks at all currently-wired spec-kit hook points and designs its extension.yml to accommodate additional hooks as spec-kit adds them. The existing hook execution order (spec-kit hooks only) is documented now. The APM hook interaction matrix is added when APM hooks are actually integrated into the orchestrator. This avoids speculative documentation while preserving the design principle that both hook systems should be documented when they coexist.

### 10. Add tags for catalog discoverability
**Status**: Locked from iteration 1 (unchanged)

The extension.yml includes tags (`orchestration`, `autonomous`, `multi-phase`, `dispatch`, `knowledge-management`) for catalog search discoverability. Equivalent metadata appears in `apm.yml` for APM's ecosystem.

### 11. APM discovery from P1 via unilateral APM-side integrator
**Status**: Locked from iteration 3

APM's compiler may read from `.specify/orchestrator/` from P1 onward using a `SpeckitOrchestratorIntegrator` or `compilation.include_paths` configuration -- both entirely within APM's codebase. The orchestrator does not know about APM. spec-kit's extension contract is untouched. No symlinks, mirrors, or artifacts outside `.specify/`. The orchestrator spec documents the canonical storage contract (directory layout, file schemas) in P7; APM's integrator consumes this documented layout. The P8 build step uses the same integrator for distribution packaging.

### 12. Retirement of the pluggable storage adapter concept
**Status**: Locked from iteration 3

The "pluggable storage adapter" is formally retired from the design vocabulary. It is replaced by three independent, tool-scoped deliverables: spec-kit documents the storage contract, gh-aw documents `cache-memory` configuration for CI persistence, APM builds its own integrator for discovery and compilation. No shared adapter layer exists. Each tool owns its own integration with the documented `.specify/orchestrator/` directory structure.

---

## Final Consensus Points (10 from iteration 2 + 3 from iteration 3)

The following positions are agreed upon by all three tools (spec-kit, APM, gh-aw) after three iterations of review:

1. **Namespaced commands are the correct pattern.** The orchestrator uses `speckit.orchestrator.{command}` commands that invoke unmodified core SDD commands. No presets, no command overriding, no silent mutation. Independently derived by APM and gh-aw for different reasons.

2. **Configuration must be format-neutral.** The orchestrator's config file is not bound to any single tool's resolution stack. Each tool consumes the neutral config through its own mechanism.

3. **State lives in a single directory tree at `.specify/orchestrator/`.** Not `.specify/extensions/orchestrator/` (which is reserved for extension installable artifacts managed by `ExtensionManager`). The shorter path avoids the `ExtensionManager.remove()` lifecycle hazard, signals multi-consumer status, and decouples from spec-kit's internal extension directory convention.

4. **Structural templates vs. filled artifacts is the correct ownership split.** spec-kit governs document shapes (templates, resolution stack, preset customization). Filled runtime artifacts are governed by whoever consumes them.

5. **`requires.commands` in extension.yml is valuable.** Install-time command dependency validation provides a safety layer that complements APM's package-level checks and enables gh-aw fast-failure in CI.

6. **`/speckit.analyze` integration strengthens all three tools.** A concrete verification command with a predictable exit code serves spec-kit's hook system, APM's context validation, and gh-aw's `post-steps:` blocks simultaneously.

7. **Dual-channel distribution with spec-kit-first CI sequencing.** Publish to both catalogs. spec-kit installation comes first in CI because hooks and commands must be available before agent execution.

8. **The working tree is canonical in all execution modes.** CI persistence mechanisms (cache-memory, repo-memory, artifact upload) are transport layers, not storage layers. During execution, the agent reads from and writes to the working tree.

9. **Hook forward-compatibility with deferred interaction matrix.** Design for hook expansion. Document existing spec-kit hooks now. Add cross-system interaction documentation when APM hooks are integrated.

10. **Tags and metadata for dual-catalog discoverability.** Both extension.yml and apm.yml carry semantic tags.

11. **APM discovery from P1 via unilateral, APM-maintained mechanism.** APM's compiler reads `.specify/orchestrator/` using its own integrator or configuration. No changes to the orchestrator or spec-kit. No artifacts outside `.specify/`. The spec documents the storage contract; APM consumes it. *(New from iteration 3)*

12. **The pluggable storage adapter is retired.** There is no shared adapter component. Each tool builds its own integration with the documented storage contract: spec-kit documents the layout, gh-aw configures cache-memory, APM builds its integrator. *(New from iteration 3)*

13. **Extension removal preserves runtime state.** `specify extension remove orchestrator` destroys extension machinery at `.specify/extensions/orchestrator/` but preserves accumulated project knowledge at `.specify/orchestrator/`, with a user-facing warning. *(New from iteration 3, derived from the state path resolution)*

---

## Remaining Disputes for Human Arbitration

None. All disputes resolved.

The three disputes from iteration 2 were resolved through convergence in iteration 3:

- **Dispute 1 (State Path)**: All three tools independently arrived at `.specify/orchestrator/` through different reasoning paths (spec-kit: lifecycle hazard, APM: path is irrelevant to its implementation, gh-aw: decouples from spec-kit internal conventions). No negotiation was needed; the positions had already converged.

- **Dispute 2 (APM Discovery Timeline)**: spec-kit conceded from P7 to P1, recognizing that APM's proposed mechanism (a unilateral integrator that reads from a known path) satisfies every hard stance spec-kit articulated. The key insight was that file visibility on a shared working tree is not architectural coupling.

- **Dispute 3 (Adapter Ownership)**: The adapter concept was retired by all three tools once Dispute 2 was resolved. The problem the adapter was meant to solve -- synchronizing artifacts across multiple storage locations -- ceased to exist when all tools agreed on a single canonical location with read access for everyone.

---

## Summary of spec-kit's Concessions Across All Iterations

For the record, here is what spec-kit gave up over three iterations, and why:

| Iteration | Concession | Reason |
|---|---|---|
| 1 | Withdrew config format lock-in (Rec 2) | spec-kit's layered config system assumes single-tool consumption; the orchestrator has three consumers |
| 1 | Withdrew state directory scattering (Rec 3) | The extension convention path was designed for single-consumer extensions |
| 1 | Withdrew preset-based command overriding (Rec 4) | Silent mutation of core commands is incompatible with both APM's context deduplication and gh-aw's deterministic verification |
| 2 | Accepted deferred hook interaction matrix | Speculative cross-system documentation drifts faster than the implementation it describes |
| 2 | Accepted spec-kit-first CI sequencing as a documentation deliverable | The P7 section is the right place to specify installation order |
| 3 | Moved APM discovery from P7 to P1 | APM reading files from a known path is not a dependency; it is a consequence of the working tree being canonical |

Every concession was genuine and driven by technical reasoning from the other tools, not by negotiation pressure. The review process worked because all three tools were willing to abandon single-tool-correct advice when it conflicted with multi-tool reality.
