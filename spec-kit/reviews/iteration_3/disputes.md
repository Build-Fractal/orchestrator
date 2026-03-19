# spec-kit Dispute Resolution -- Iteration 3

## Dispute 1: State Path

**`.specify/orchestrator/` vs `.specify/extensions/orchestrator/`**

### spec-kit's position

The canonical state path should be `.specify/orchestrator/`.

This is not a preference -- it is a technical consequence of how spec-kit's extension system actually works in code.

**Evidence from the implementation.** The `ExtensionManager` class in `src/specify_cli/extensions.py` (line 387) hardcodes the extensions directory:

```python
self.extensions_dir = project_root / ".specify" / "extensions"
```

When an extension is installed via `install_from_directory` (line 529), its files are placed at:

```python
dest_dir = self.extensions_dir / manifest.id
```

This means `specify extension add orchestrator` would place the extension's own files (extension.yml, commands/, templates/) at `.specify/extensions/orchestrator/`. The `ExtensionRegistry` tracks installed extensions via a `.registry` JSON file at `.specify/extensions/.registry`. The `remove()` method (line 621) cleans up by calling `shutil.rmtree(extension_dir)` on `.specify/extensions/{id}/`.

**The critical distinction.** `.specify/extensions/orchestrator/` is where the extension's *installable artifacts* live (manifest, commands, templates, config). This is managed entirely by `ExtensionManager` -- it writes there during install, it removes everything there during uninstall. The orchestrator's *runtime state* (roadmaps, phase summaries, decisions register, knowledge file, execution logs, lock files, continue files) is a completely different category of data. Placing runtime state inside `.specify/extensions/orchestrator/` means that `specify extension remove orchestrator` would destroy all accumulated project knowledge -- every phase summary, every decision, every knowledge entry -- as a side effect of uninstalling the extension.

This is not a theoretical concern. The spec explicitly states (see overview, "File Structure and Key Artifacts" section): "All orchestrator state lives under `.specify/orchestrator/`, separate from spec-kit's feature directories." The spec's own design already accounts for this separation.

**The multi-consumer argument is secondary but reinforcing.** The primary reason for `.specify/orchestrator/` is the install/uninstall lifecycle hazard. The multi-consumer benefit (APM compilation, gh-aw cache persistence, the orchestrator's own dispatch logic all read from the same path without going through spec-kit's extension resolution) is a supporting argument, not the main one.

### Engagement with counter-positions

**APM's position** (iteration 2): APM explicitly defers to spec-kit on the precise path, stating "The exact path within `.specify/` is not APM's primary concern" and "APM defers to spec-kit on the precise path." APM's only requirement is that the path be "stable, documented, and accessible to APM's build step at P8." `.specify/orchestrator/` satisfies all three.

**gh-aw's position** (iteration 2): gh-aw already moved to `.specify/orchestrator/` in its Rec 2 revision, stating explicitly: "gh-aw now aligns with spec-kit's revised position: `.specify/orchestrator/` is the canonical path. This resolves the crossed-wires issue." gh-aw's only requirement is a single, static cache key -- satisfied by either path.

**The actual state of the dispute.** This dispute is functionally resolved. All three tools have converged on `.specify/orchestrator/` in their iteration 2 positions. APM defers to spec-kit. gh-aw has already updated its recommendation. The only reason this remains listed as a "dispute" is the iteration 1 crossed-wires incoherence, which all three tools have acknowledged and corrected. There is no remaining disagreement on the substance.

### spec-kit's proposed resolution

`.specify/orchestrator/` is the canonical state path for orchestrator runtime state. `.specify/extensions/orchestrator/` continues to be managed by `ExtensionManager` for the extension's own installable artifacts (manifest, commands, templates, config files). The extension manifest's metadata should include a `state_dir` field pointing to `.specify/orchestrator/` so that `specify extension info orchestrator` can discover and display runtime state without relying on path convention.

On `specify extension remove orchestrator`:
- `.specify/extensions/orchestrator/` is deleted (extension machinery, commands, config)
- `.specify/orchestrator/` is NOT deleted (accumulated project knowledge)
- A user-facing message warns that orchestrator state at `.specify/orchestrator/` was preserved and can be manually removed

This is implementable as a one-line condition in `ExtensionManager.remove()` that checks for a `state_dir` field in the manifest and emits a warning rather than deleting external state directories.

### Concession offered

None needed. All three tools already agree. This dispute should be formally closed.

---

## Dispute 2: APM Discovery Timeline

**When does APM get access to orchestrator artifacts? P1 vs P7 vs P8**

### spec-kit's position

APM should have a discovery path from P1, but it must be APM's responsibility to build and maintain, with zero changes required from the orchestrator or spec-kit.

spec-kit's iteration 2 proposed a tiered compromise (P1-P6: no discovery, P7: optional `apm compile` scanning `.specify/orchestrator/`, P8: full integrator). This was overly restrictive. After reading APM's iteration 2 more carefully, spec-kit now recognizes that APM's proposed Option 2 -- an APM-side integrator that reads from `.specify/orchestrator/` at compile time -- fully satisfies spec-kit's constraints while giving APM what it needs.

**Why spec-kit can move here.** spec-kit's hard stances from iteration 2 were:

1. No canonical artifacts outside `.specify/` -- APM Option 2 does not create any artifacts outside `.specify/`. The integrator reads from `.specify/orchestrator/` and writes into APM's own compilation output. The orchestrator never touches `.apm/`.

2. `specify extension remove` must clean up everything the extension installed -- APM Option 2 requires no extension-managed artifacts. APM reads files that the orchestrator writes; the orchestrator does not create symlinks, mirrors, or dual-writes for APM's benefit.

3. No build-time APM dependency in the critical runtime path -- `apm compile` is a developer-initiated command, not a runtime dependency. The orchestrator functions identically whether or not `apm compile` has ever been run.

All three hard stances are preserved. The reason spec-kit's iteration 2 proposed deferring to P7 was the fear of symlinks, mirrors, or dual-writes. APM's Option 2 avoids all of those.

**The structural argument.** Phase summaries, decisions, and knowledge files are plain files on disk at a well-known path. Any tool can read files on disk. APM's compiler reading `.specify/orchestrator/` is no different from a developer opening those files in an editor, or from gh-aw's `cache-memory` persisting that directory. Read access to the working tree is not a dependency relationship -- it is the working tree being canonical (locked consensus point 1).

### Engagement with counter-positions

**APM's position** (iteration 2): APM proposed three mechanisms (symlink, integrator, `--include-paths` flag) and stated that Option 2 (the integrator) "is the least invasive -- it requires no changes to the orchestrator or to spec-kit's extension contract, only an APM-side enhancement." APM is correct. This is the right mechanism.

**gh-aw's position** (iteration 2): gh-aw explicitly stated it "has no stake in this dispute (it only matters for local development, not CI)." Confirmed -- gh-aw is not a party here.

**Where spec-kit's iteration 2 went wrong.** spec-kit conflated "APM discovery" with "APM dependency." Allowing APM to read files at a known path does not create a dependency from the orchestrator on APM. The orchestrator has no idea APM exists. It writes files for its own purposes. If APM happens to read those files, that is APM's business. spec-kit's iteration 2 instinct to block read access until P7 was a category error -- treating file visibility as an architectural coupling when it is simply a consequence of both tools operating on the same working tree.

### spec-kit's proposed resolution

1. **From P1 onward**, orchestrator artifacts at `.specify/orchestrator/` are readable by any tool, including APM's compiler. This is not a "discovery mechanism" -- it is a consequence of the working tree being canonical (locked consensus point 1).

2. **APM builds and maintains** a `SpeckitOrchestratorIntegrator` in APM's own codebase, following APM's `BaseIntegrator` pattern. This integrator reads from `.specify/orchestrator/`, processes artifacts into APM's compilation output, and degrades gracefully when the path does not exist.

3. **The orchestrator spec documents the directory layout** (which files live where, what their schemas are) in its expanded P7 section as part of the canonical storage contract. APM's integrator depends on this documented layout. Changes to the layout are a breaking change that APM must track -- the same way APM tracks any upstream schema change.

4. **No changes to spec-kit's extension system.** No `--include-paths` flag, no symlinks, no extension-managed artifacts outside `.specify/orchestrator/`.

5. **The P8 hybrid package build step** uses the same integrator, not a separate mechanism. P8 does not introduce new discovery -- it packages the compilation output for distribution.

### Concession offered

spec-kit concedes its iteration 2 position that APM discovery should be deferred to P7. APM should have compile-time access from P1. In exchange, APM must accept that this access is unilateral and APM-maintained -- the orchestrator and spec-kit make zero accommodations. If APM's integrator breaks because the orchestrator changes its file layout, that is APM's problem to fix, the same as any downstream consumer of an upstream schema.

---

## Dispute 3: Pluggable Adapter Ownership

**Who builds the storage adapter, and when?**

### spec-kit's position

There is no adapter to build. The concept should be formally retired, not deferred.

**Why the adapter was proposed in the first place.** APM's iteration 1 introduced the "pluggable storage adapter" as a bridge between three storage locations: spec-kit's canonical directory, APM's discovery path, and gh-aw's `cache-memory`. The adapter was meant to keep artifacts synchronized across these locations during execution.

**Why it is now unnecessary.** The resolution of Dispute 2 eliminates the adapter's entire reason for existence:

- APM discovery is handled by APM's own integrator reading from the canonical `.specify/orchestrator/` path. There is no synchronization required because there is no second copy. APM reads the source directly.

- gh-aw's `cache-memory` is a transport layer (locked consensus point 1). It persists and restores the `.specify/orchestrator/` directory as an opaque blob. It does not need an "adapter" -- it needs a cache key and a directory path. gh-aw already documented the restore/persist lifecycle in its Rec 2 (iteration 2).

- The orchestrator writes to `.specify/orchestrator/` and reads from `.specify/orchestrator/`. It has exactly one storage location. There is nothing to "adapt."

The adapter pattern was solving a problem that only existed under the assumption that artifacts needed to live in multiple locations simultaneously. With all three tools agreeing that the working tree is canonical and that each tool reads from the same path, the multi-location assumption is gone. The problem is gone. The solution is unnecessary.

### Engagement with counter-positions

**APM's position** (iteration 2): APM already withdrew the adapter as a P1 concern, stating "The adapter as originally conceived is withdrawn as a P1 concern. For P1-P6, there is no adapter -- files live in `.specify/` and are read directly." APM then proposed deferring to P8 with ownership assignments. But APM's own proposed resolution for Dispute 2 (the `SpeckitOrchestratorIntegrator`) eliminates the need for even a P8 adapter. The integrator IS the mechanism that replaces the adapter -- it reads from `.specify/orchestrator/` at build time and produces APM-discoverable output. There is no intermediate adapter layer.

**gh-aw's position** (iteration 2): gh-aw offered to contribute a `cache-memory` adapter specification. But gh-aw's `cache-memory` is not an adapter -- it is a generic CI persistence mechanism. It already knows how to persist and restore directory trees. The "specification" gh-aw offered to contribute is just documentation of how `cache-memory` is configured for the orchestrator's directory (cache key naming, what directory to persist). This belongs in the expanded P7 section as CI configuration documentation, not as an "adapter specification."

**spec-kit's position** (iteration 2): spec-kit proposed deferring the adapter to P8 and noted it was "a derivative of Dispute 1." With Dispute 2 resolved, this derivative collapses.

### spec-kit's proposed resolution

1. **Formally retire the "pluggable storage adapter" concept.** It is not deferred to P8 -- it is removed from the design vocabulary. No adapter is needed at any phase.

2. **What remains is concrete, tool-specific work:**
   - APM builds its `SpeckitOrchestratorIntegrator` (APM's Dispute 2 resolution, which spec-kit now endorses). This is an APM component, not a shared "adapter."
   - gh-aw documents `cache-memory` configuration for `.specify/orchestrator/` in the P7 section. This is CI configuration documentation, not an adapter specification.
   - spec-kit documents the canonical storage contract (directory layout, file schemas) in the orchestrator spec's P7 section. This is already a committed deliverable from locked consensus point 6.

3. **Each tool owns its own integration work.** No shared "adapter" layer, no cross-tool coordination beyond the documented storage contract.

### Concession offered

spec-kit concedes that the individual pieces of work APM and gh-aw identified (integrator, cache configuration, storage contract) are real deliverables. The concession is purely terminological and architectural: these are not "adapters" forming a shared abstraction layer. They are independent, tool-specific integrations that each read from the same documented file layout. The distinction matters because "adapter" implies a shared interface that must be coordinated across tools, while the actual work is each tool independently consuming a documented directory structure.

---

## Package Deal

If spec-kit could get one dispute fully its way in exchange for conceding the other two, it would choose **Dispute 1 (State Path)**.

The reasoning: Dispute 1 has a hard technical constraint (the `ExtensionManager.remove()` lifecycle hazard) that cannot be worked around. If runtime state lives at `.specify/extensions/orchestrator/`, then uninstalling the extension destroys accumulated project knowledge. This is a data loss scenario with no recovery path. The other two disputes are about coordination timing and terminology -- important, but recoverable if the initial decision is wrong.

However, this package deal is academic. Dispute 1 is already resolved by consensus -- all three tools converged on `.specify/orchestrator/` in iteration 2. Dispute 2 is resolvable by spec-kit accepting APM's Option 2 (which spec-kit now does). Dispute 3 dissolves once Dispute 2 is resolved. All three disputes should close in this iteration without requiring a package deal.

The actual concession spec-kit makes in this iteration is on Dispute 2: moving from "defer APM discovery to P7" to "APM can read from P1 onward, as long as it is APM-maintained." This is a genuine shift from spec-kit's iteration 2 position, driven by recognizing that APM's Option 2 satisfies every hard stance spec-kit articulated. The iteration 2 deferral was motivated by fear of architectural coupling; Option 2 creates none.
