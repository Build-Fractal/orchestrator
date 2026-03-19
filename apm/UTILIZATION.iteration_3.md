# APM Utilization Review -- Iteration 3 (Final)

## Position Evolution

**Original (UTILIZATION.md):** APM made 9 recommendations pushing the orchestrator to adopt APM primitives (`.prompt.md`, `.context.md`, `.instructions.md`, `SKILL.md`) as canonical formats from P1 onward, treating APM as a co-equal runtime participant rather than a build-time and distribution tool.

**Iteration 1 (UTILIZATION.iteration_1.md):** After cross-review, APM withdrew 3 recommendations (Recs 1, 5, 9), substantially modified 4 (Recs 2, 3, 4, 6), and stood by 2 (Recs 7, 8). The revision drew a clear boundary: APM belongs at the distribution and static context layer, not woven into the orchestrator's dynamic dispatch. Canonical artifact locations moved from `.apm/` to `.specify/extensions/orchestrator/`.

**Iteration 2 (UTILIZATION.iteration_2.md):** Locked 10 convergence points with spec-kit and gh-aw. Corrected the path incoherence (APM had adopted `.specify/extensions/orchestrator/` while spec-kit was simultaneously withdrawing that path). Deferred the pluggable storage adapter. Formally retracted the "dangerous" rating on gh-aw Rec 8. Identified 4 remaining disputes, of which 3 proceeded to formal dispute resolution (Dispute 4, dual-authority arbitration, was implicitly resolved by the mold/casting framing converging with Rec 8 consensus).

**Iteration 3 (this document):** All 3 disputes resolved by convergence. All three tools independently arrived at the same conclusions through structural reasoning: `.specify/orchestrator/` as the canonical path (Dispute 1), APM unilateral read access from P1 via a `SpeckitOrchestratorIntegrator` (Dispute 2), and formal retirement of the pluggable storage adapter concept (Dispute 3). No human arbitration required.

---

## Dispute Resolutions

### Dispute 1: State Path -- RESOLVED

**Dispute:** Should orchestrator runtime state live at `.specify/orchestrator/` or `.specify/extensions/orchestrator/`?

**Resolution:** `.specify/orchestrator/` is the canonical state path. All three tools converged independently:

- **APM** accepted `.specify/orchestrator/` as the correct technical outcome, acknowledging its iteration 1 adoption of `.specify/extensions/orchestrator/` was a crossed-wires error -- conceding to a position that spec-kit was simultaneously abandoning. APM's compiler uses configurable glob patterns; the path string has zero implementation cost impact.

- **spec-kit** provided the decisive technical argument: `.specify/extensions/orchestrator/` is managed by `ExtensionManager.remove()` via `shutil.rmtree()`. Placing runtime state there means `specify extension remove orchestrator` would destroy all accumulated project knowledge (phase summaries, decisions, knowledge entries). The spec's own design already places state at `.specify/orchestrator/` for this reason.

- **gh-aw** aligned on operational grounds: a well-known constant path avoids coupling cache key derivation to spec-kit's internal extension directory convention, which could break if that convention ever changes.

**Agreed implementation:** The spec adopts `.specify/orchestrator/` with a brief rationale explaining the deviation from the extension convention. The extension manifest includes a `state_dir` field pointing to `.specify/orchestrator/` for tooling discoverability. On `specify extension remove orchestrator`, the extension's installable artifacts at `.specify/extensions/orchestrator/` are deleted, but accumulated state at `.specify/orchestrator/` is preserved with a user-facing warning.

---

### Dispute 2: APM Discovery Timeline -- RESOLVED

**Dispute:** When does APM get access to orchestrator artifacts for compilation -- P1, P7, or P8?

**Resolution:** APM gets read access from P1 onward, via a unilateral APM-side mechanism that requires zero changes to the orchestrator or spec-kit.

- **APM** argued that deferring discovery to P8 means the hybrid package build step encounters orchestrator artifacts for the first time at packaging -- untested, unvalidated, and at the worst possible moment. APM proposed a `SpeckitOrchestratorIntegrator` extending `BaseIntegrator` that reads from `.specify/orchestrator/` during `apm compile`, degrades gracefully when the path does not exist, and never writes to `.specify/`. APM formally withdrew the symlink proposal from iteration 1.

- **spec-kit** conceded its iteration 2 position (defer to P7). spec-kit recognized that APM's Option 2 (the integrator) satisfies every hard stance spec-kit articulated: no artifacts outside `.specify/`, no extension-managed artifacts for APM, no build-time dependency in the runtime path. spec-kit's key realization: "`apm compile` scanning `.specify/orchestrator/` is no different from a developer opening those files in an editor" -- read access to the working tree is not a dependency relationship. spec-kit's iteration 2 instinct to block read access until P7 was a category error: treating file visibility as architectural coupling.

- **gh-aw** reframed the question: the discovery timeline is an APM implementation timeline question, not an architectural one. The spec documents a stable storage contract; when APM ships its integrator is APM's decision. The CI lifecycle already includes an optional `apm compile` step (Rec 2, step 2) that degrades to a no-op if the integrator is not installed.

**Agreed implementation:** APM builds a `SpeckitOrchestratorIntegrator` in APM's own `BaseIntegrator` framework. The integrator discovers structured Markdown files at `.specify/orchestrator/`, processes them into APM's compilation pipeline, and produces output in APM's own compilation directory. The orchestrator does not know APM exists. spec-kit's extension contract is untouched. `specify extension remove` cleans up cleanly because APM never writes to `.specify/`. The spec documents the storage contract (directory layout, file schemas) so APM's integrator has a stable upstream schema to consume. APM accepts that if the orchestrator changes its file layout, that is APM's problem to track -- the same as any downstream consumer of an upstream schema.

---

### Dispute 3: Adapter Ownership -- RESOLVED

**Dispute:** Who builds the pluggable storage adapter that bridges spec-kit's canonical directory, APM's discovery path, and gh-aw's `cache-memory`?

**Resolution:** Nobody builds it. The "pluggable storage adapter" concept is formally retired -- not deferred to P8, removed from the design vocabulary entirely.

- **APM** recognized that the adapter was invented to solve the problem of APM not being able to see orchestrator artifacts. With Dispute 2 resolved (APM reads directly from `.specify/orchestrator/`), the adapter's entire reason for existence is eliminated. The three "backends" the adapter was supposed to bridge are not three separate storage locations -- they are three views of the same data: `.specify/orchestrator/` on disk (the canonical state), `cache-memory` (a transport mechanism), and `.apm/context/` (withdrawn in iteration 1). With the third backend gone and the second being transport rather than storage, the "adapter" reduces to "APM reads files from a directory."

- **spec-kit** concurred that the individual deliverables APM and gh-aw identified (integrator, cache configuration, storage contract) are real work, but the concession is terminological and architectural: these are independent, tool-specific integrations that each read from the same documented file layout, not components of a shared adapter abstraction. "Adapter" implies a shared interface requiring cross-tool coordination; the actual work is each tool independently consuming a documented directory structure.

- **gh-aw** argued that dissolving the adapter label into three tool-scoped specifications unblocks P7 implementation. Each tool can document its own interaction with `.specify/orchestrator/` without waiting for the others.

**Agreed implementation:** The spec's expanded P7 section documents three independent, tool-scoped specifications:

1. **Canonical storage contract (spec-kit owns):** Directory layout, file formats, schemas, and concurrent-read safety guarantees of `.specify/orchestrator/`.
2. **CI persistence configuration (gh-aw owns):** `cache-memory` entry configuration for persisting `.specify/orchestrator/` across CI runs -- key naming, retention policy, allowed extensions, restore/persist lifecycle. Standard gh-aw frontmatter, not a new abstraction.
3. **Build-time discovery integration (APM owns):** The `SpeckitOrchestratorIntegrator` reading from `.specify/orchestrator/` during `apm compile`. APM builds this in its own `BaseIntegrator` framework.

No "pluggable storage adapter" concept appears in the orchestrator spec. Each tool owns its own piece.

---

## Final Recommendations (All Iterations Cumulative)

### Recommendations APM Stands Behind

1. **Rec 1: Dispatch payloads as APM prompt files** -- WITHDRAWN (locked from iteration 1). APM prompt files are the wrong abstraction for the orchestrator's dispatch path. Dispatch payloads must use spec-kit's command format, expressible as gh-aw JSON payloads for CI.

2. **Rec 2: Phase summaries -- structured Markdown with YAML frontmatter** -- MODIFIED (locked from iteration 2, path clarified in iteration 3). Phase summaries use structured Markdown with YAML frontmatter (phase, milestone, timestamp, status, dependencies). Canonical location: `.specify/orchestrator/`. Format-neutral naming (e.g., `phase-summary.md`), not APM's `.context.md` extension. The schema is defined by the orchestrator spec, not imported from APM's primitive type specification.

3. **Rec 3: Boundary maps -- orchestrator-native format with P8 SKILL.md generation** -- LOCKED (from iteration 1). Boundary maps use whatever format best serves the orchestrator's dispatch planning. At P8, `apm pack` transforms boundary maps into SKILL.md files for distribution. The orchestrator never parses or produces SKILL.md during operation.

4. **Rec 4: No APM at runtime -- narrowed to "not required, optionally beneficial"** -- LOCKED (from iteration 1). The orchestrator must not require APM to be installed in dispatched agent environments. APM may be declared as an optional `requires.tools` dependency in `extension.yml`. When present, setup commands may invoke `apm install` and `apm compile`. When absent, all core orchestration functionality works without it.

5. **Rec 5: APM `applyTo` patterns for knowledge scope filtering** -- WITHDRAWN (locked from iteration 1). `applyTo` is a static, build-time optimization that cannot serve the orchestrator's need for dynamic, per-dispatch knowledge scoping. The orchestrator builds its own scope-filtering logic.

6. **Rec 6: gh-aw integration -- static/dynamic split** -- MODIFIED (locked from iteration 2). Static context (instructions, constitution, coding standards) served via APM's `dependencies:` field in gh-aw workflow frontmatter using the hybrid package. Dynamic context (phase summaries, decisions, task-specific knowledge) served via gh-aw's `cache-memory`/`repo-memory`. The static/dynamic boundary documented as a versioned contract (artifact classification table) in the spec. Changes to this table are a breaking change. Pre-P8, static context is committed to the repo or bundled into workflow definitions; `dependencies:` integration requires the hybrid package.

7. **Rec 7: `apm pack` for optional milestone snapshots** -- UNCHANGED (locked from iteration 1). Optional, supplementary snapshot mechanism for cross-machine state sharing and archival. The orchestrator's primary crash recovery remains disk-state-as-truth. `apm pack` is complementary, not critical-path.

8. **Rec 8: Hybrid APM package at P8** -- UNCHANGED (locked from iteration 1). The orchestrator ships as `type: hybrid` in `apm.yml` with dual manifests (`extension.yml` for spec-kit, `apm.yml` for APM). The P8 build step reads from `.specify/orchestrator/`, transforms boundary maps into SKILL.md files, and produces optimized compiled context. The hybrid package must actually compile orchestrator artifacts, not merely ship extension files in a tarball.

9. **Rec 9: Mirror `.specify/` into `.apm/context/`** -- WITHDRAWN (locked from iteration 1). Mirroring, symlinking, or dual-writing orchestrator artifacts into `.apm/context/` is rejected. Breaks spec-kit's self-containment contract, creates split-brain hazards, and is unnecessary given the P8 build step reads from the canonical location.

### New Positions Established Through Dispute Resolution

10. **APM discovery from P1 via `SpeckitOrchestratorIntegrator`** -- NEW (iteration 3). APM builds a `SpeckitOrchestratorIntegrator` extending `BaseIntegrator` that reads orchestrator artifacts from `.specify/orchestrator/` during `apm compile`. The integrator is APM-maintained, requires zero changes to the orchestrator or spec-kit, and degrades gracefully when `.specify/orchestrator/` does not exist. The same integrator powers both local development compilation and the P8 hybrid package build step.

11. **Formal retirement of the pluggable storage adapter** -- NEW (iteration 3). The adapter concept that appeared in APM's iteration 1 is formally removed from the design vocabulary. It is not deferred; it is eliminated. Each tool owns its own integration with `.specify/orchestrator/` independently.

12. **Symlink proposal withdrawal** -- NEW (iteration 3). The symlink from `.apm/context/orchestrator/` to `.specify/orchestrator/`, proposed in APM's iteration 1 review of spec-kit, is formally withdrawn. APM does not ask the orchestrator to write anywhere other than `.specify/orchestrator/`. If APM wants to discover orchestrator artifacts, APM configures itself to look in the right place.

---

## Final Consensus Points (10 from Iteration 2 + 3 from Iteration 3)

### Locked from Iteration 2

1. **APM is a distribution and static context tool, not a runtime dispatch participant.** APM's value to the orchestrator is at the packaging boundary (P8) and for static context injection. APM has no role in per-dispatch context assembly, dynamic knowledge scoping, or runtime artifact synchronization.

2. **The orchestrator's canonical artifacts live under `.specify/`.** The exact path is `.specify/orchestrator/` (resolved in iteration 3, see below). The path is fully cleaned up by `specify extension remove` for extension machinery, with accumulated state preserved and a user-facing warning.

3. **The hybrid APM package at P8 is the correct and sufficient integration point.** Dual manifests, dual distribution channels, build-time transformation of orchestrator artifacts into APM primitives. No tool contests this.

4. **`apm pack` is supplementary, not critical-path.** Optional milestone snapshots and archival, complementary to gh-aw's `repo-memory`.

5. **The static/dynamic split governs CI integration.** APM's `dependencies:` for static context, gh-aw's `cache-memory`/`repo-memory` for dynamic context. The split is formally documented as a versioned contract.

6. **gh-aw's one-phase-per-run is the correct Tier C CI model.** APM formally retracted its "dangerous" rating. The one-phase-per-run model does not conflict with any of APM's surviving recommendations.

7. **The orchestrator defines its own formats; APM adapts at distribution time.** Phase summaries, boundary maps, and knowledge files use whatever format the orchestrator needs. APM reads and transforms at the P8 build step (and during `apm compile` via the integrator from P1). APM does not dictate canonical format or naming.

8. **No APM dependency in the critical dispatch path.** The orchestrator functions identically for P1-P7 with or without APM installed. APM is optional via `requires.tools`.

9. **The static/dynamic boundary artifact classification table belongs in the spec.** Changes to which artifacts are classified as static vs. dynamic constitute a breaking change to the APM/gh-aw integration.

10. **Attribution matters in multi-tool negotiations.** Each tool's feedback is credited precisely rather than framed as a unified consensus.

### New from Iteration 3

11. **`.specify/orchestrator/` is the canonical state path (not `.specify/extensions/orchestrator/`).** Driven by the `ExtensionManager.remove()` lifecycle hazard (data loss on uninstall), the spec's own design, and operational simplicity. The extension convention path was designed for single-consumer extensions; the orchestrator has three consumers. All three tools converged independently.

12. **APM gets unilateral read access to `.specify/orchestrator/` from P1.** APM builds its own `SpeckitOrchestratorIntegrator` to read from the canonical path during `apm compile`. No changes to the orchestrator or spec-kit. The spec documents a stable storage contract (directory layout, file schemas); APM consumes it. `apm compile` is a developer tool, not a runtime dependency -- the orchestrator does not know APM exists.

13. **The pluggable storage adapter is retired, not deferred.** There is no shared adapter component. Each tool independently consumes the documented `.specify/orchestrator/` directory structure: spec-kit documents the storage contract, gh-aw documents `cache-memory` configuration, APM builds its integrator. Three owned deliverables with no coordination gap.

---

## Remaining Disputes for Human Arbitration

None. All disputes resolved.

The three disputes from iteration 2 all reached full convergence in iteration 3 through independent structural reasoning by each tool:

- **Dispute 1 (State Path):** Unanimous on `.specify/orchestrator/`. All three tools arrived at this position independently -- APM by recognizing its iteration 1 adoption of the extension convention path was a crossed-wires error, spec-kit by demonstrating the `ExtensionManager.remove()` data loss hazard, and gh-aw by identifying the operational benefit of decoupling cache keys from spec-kit's internal conventions.

- **Dispute 2 (APM Discovery Timeline):** Unanimous on P1 access via APM's unilateral integrator. The key shift was spec-kit conceding its iteration 2 deferral to P7, recognizing that APM's Option 2 satisfies every hard stance spec-kit articulated and that read access to the working tree is not a dependency relationship.

- **Dispute 3 (Adapter Ownership):** Unanimous on formal retirement. The concept was invented to solve a problem (APM cannot see orchestrator artifacts) that no longer exists once Dispute 2 is resolved. All three tools independently concluded that the three "backends" the adapter was supposed to bridge are not three separate storage locations but three views of the same data.

---

## Iteration 3 Observations

### The dispute process worked because the disputes were genuine, not strategic

All three disputes turned out to have the same structure: a concept (path convention, timeline restriction, adapter abstraction) that existed because of assumptions that the iteration 2 convergence had already invalidated. The disputes were not competing preferences but residual artifacts of earlier positions. Once each tool re-examined the dispute in light of the locked consensus points, the resolution was obvious.

### spec-kit's concession on Dispute 2 was the pivotal move

spec-kit moving from "defer APM discovery to P7" to "APM can read from P1" was the only genuine position shift in iteration 3. It unlocked the cascade: P1 discovery made the adapter unnecessary (Dispute 3), and the adapter's dissolution confirmed that each tool owns its own integration work -- reinforcing the clean separation that made Dispute 1 easy to close.

### The final architecture is cleaner than any single tool proposed

No single tool's original position would have produced this outcome. APM's original position (APM primitives everywhere, runtime involvement) was overreach. spec-kit's original instinct to defer all APM involvement to P8 was too restrictive. gh-aw's neutral posture on local development meant it could not have driven the discovery timeline question. The three-iteration process produced a design where each tool does exactly what it is good at: spec-kit owns the storage contract, gh-aw owns CI persistence, APM owns compilation and distribution. The orchestrator writes files for its own purposes. Other tools read those files for theirs. No adapters, no mirrors, no runtime coupling.
