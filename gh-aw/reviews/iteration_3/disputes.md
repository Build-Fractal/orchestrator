# gh-aw Dispute Resolution -- Iteration 3

## Dispute 1: State Path

`.specify/orchestrator/` vs `.specify/extensions/orchestrator/`

**gh-aw's position**: `.specify/orchestrator/` is correct. gh-aw concedes this dispute entirely and aligns with spec-kit's revised position.

**Technical justification**: gh-aw's cache-memory primitive operates by restoring and persisting directory trees keyed by a static cache key. The key is generated from the workflow ID and a cache identifier (see `pkg/workflow/cache.go`, `generateDefaultCacheKey()`). The key format is `memory-{id}-${{ env.GH_AW_WORKFLOW_ID_SANITIZED }}-${{ github.run_id }}`, with restore keys that match by prefix to find the latest prior run's cache. What matters for gh-aw is that the directory being cached is a single, predictable path. Both `.specify/orchestrator/` and `.specify/extensions/orchestrator/` satisfy this requirement identically. gh-aw has no technical reason to prefer one over the other.

However, gh-aw does have an operational reason to prefer `.specify/orchestrator/`. In the CI run lifecycle (Rec 2), the `steps:` block restores the cached tree, runs extension installation, and then hands control to the agent. If the path follows the extension convention (`.specify/extensions/orchestrator/`), there is an implicit coupling: the cache key derivation must know spec-kit's extension directory convention, and any future change to that convention (e.g., versioned extension directories) would break the cache key. With `.specify/orchestrator/`, the path is a well-known constant that the CI workflow can hardcode without depending on spec-kit's internal conventions.

**Engagement with counter-positions**: APM adopted `.specify/extensions/orchestrator/` in iteration 1 as a concession to spec-kit, then spec-kit walked away from it simultaneously. APM's iteration 2 correctly identifies this as an incoherence and defers to spec-kit on the final path. APM's only hard requirement is that the path be stable, documented, and accessible to `apm compile` at build time -- `.specify/orchestrator/` satisfies all three. There is no remaining counter-position to engage with; all three tools have now converged on the same path through independent reasoning.

**gh-aw's proposed resolution**: The spec adopts `.specify/orchestrator/` as the canonical state path. The spec includes a brief rationale (the orchestrator has multi-tool consumers; the extension convention path was designed for single-consumer extensions). The `specify extension list` and `specify extension info` commands discover orchestrator state via the extension manifest's `state_dir` field, not by path convention. This is spec-kit's own proposed resolution, and gh-aw endorses it without modification.

**Concession offered**: gh-aw abandons `.specify/extensions/orchestrator/` which it adopted in iteration 1 as a concession to spec-kit. This is not a real concession since spec-kit itself withdrew the position, but gh-aw formally acknowledges that its iteration 1 adoption of that path was premature -- it should have waited for spec-kit to confirm rather than anticipating spec-kit's preference.

---

## Dispute 2: APM Discovery Timeline

When does APM get access to orchestrator artifacts? P1 vs P7 vs P8.

**gh-aw's position**: APM should get read access to orchestrator artifacts at P7 via `apm compile` scanning `.specify/orchestrator/` by convention. gh-aw has no stake in whether APM gets access earlier (P1-P6) for local development -- that is between APM and spec-kit. gh-aw's concern is strictly about the CI lifecycle and when APM compilation fits into it.

**Technical justification**: The CI run lifecycle documented in Rec 2 is:

1. Restore `.specify/orchestrator/` from `cache-memory`
2. (Optional) Run `apm compile` if the orchestrator is installed as an APM hybrid package
3. Install/verify spec-kit extension
4. Execute orchestrator logic
5. Persist `.specify/orchestrator/` back to `cache-memory`

Step 2 is where APM compilation runs in CI. For this step to produce meaningful output, `apm compile` must be able to read orchestrator artifacts from the restored working tree. The mechanism is straightforward: `apm compile` reads from `.specify/orchestrator/` because the files are there on disk after cache-memory restoration. No symlinks, no mirroring, no adapter. APM's compiler simply needs to know the path.

The `dependencies:` field in gh-aw workflow frontmatter (documented in `docs/src/content/docs/reference/dependencies.md`) already provides the integration seam for APM. The compiler emits `apm pack` in the activation job and `apm unpack` in the agent job. If the orchestrator's hybrid APM package is listed in `dependencies:`, APM context is compiled and available before the agent runs. But this requires the hybrid package to exist (P8). Before P8, APM compilation of orchestrator artifacts in CI is a manual step in the `steps:` block, not an automated `dependencies:` resolution.

**Engagement with counter-positions**:

*APM's position*: APM wants discovery from P1, arguing that deferring to P8 means APM's context optimization engine provides zero value during the entire build-and-iterate period. APM proposed three mechanisms: a symlink from `.apm/context/orchestrator/`, an APM integrator that reads `.specify/orchestrator/` directly, or an `--include-paths` flag for `apm compile`.

gh-aw's assessment: APM's option 2 (the `SpeckitOrchestratorIntegrator` that reads from `.specify/orchestrator/` unilaterally during `apm compile`) is the correct mechanism. It requires no changes to the orchestrator, no changes to spec-kit, no symlinks, and no artifacts outside `.specify/`. It is a pure APM-side enhancement. The question of when this integrator ships is an APM implementation timeline question, not an architectural one. If APM ships the integrator at P1, APM gets P1 discovery. If APM ships it at P7, APM gets P7 discovery. The architecture does not constrain the timeline; APM's own development schedule does.

*spec-kit's position*: spec-kit proposes a tiered approach -- no APM discovery mechanism for P1-P6, optional `apm compile` scanning from P7, proper integrator at P8. spec-kit's hard stance is no canonical artifacts outside `.specify/`.

gh-aw's assessment: spec-kit's tiered approach is correct for the spec document, but the tier boundaries are spec-kit's to enforce, not the spec's. The spec should state: "Orchestrator artifacts are canonical at `.specify/orchestrator/`. External tools that wish to compile or transform these artifacts may read from this path. The orchestrator does not create artifacts outside `.specify/` for the benefit of external tools." This is a statement of the storage contract, not a timeline restriction. When APM builds its integrator is APM's decision.

**gh-aw's proposed resolution**: The spec documents the storage contract (canonical artifacts at `.specify/orchestrator/`, readable by any tool, no artifacts created outside `.specify/` by the orchestrator). The P7 CI lifecycle includes an optional `apm compile` step that runs after cache restoration and before extension installation. APM builds its own `SpeckitOrchestratorIntegrator` to read from the canonical path -- this is an APM deliverable, not a spec deliverable or a spec-kit deliverable. The timeline for when APM ships the integrator is APM's own business. The spec merely ensures the path is stable and the artifacts are in a parseable format (structured Markdown with YAML frontmatter, as already agreed).

For the `dependencies:` integration (the automated path where APM context is compiled during workflow activation), this requires the P8 hybrid package. The P7 section documents the manual `apm compile` step as a bridge for CI workflows that want APM context optimization before P8 ships.

**Concession offered**: gh-aw drops its iteration 2 framing that treated this as a "P7 vs P8" question. The real answer is: APM gets access whenever APM builds the integrator. The spec's only obligation is to document a stable storage contract and parseable artifact format. gh-aw will document the CI lifecycle step where `apm compile` runs, regardless of whether APM has shipped the integrator yet -- the step is optional and degrades gracefully (if `apm compile` is not installed or the integrator does not exist, the step is a no-op).

---

## Dispute 3: Adapter Ownership

Who builds the pluggable storage adapter, and when?

**gh-aw's position**: The "pluggable storage adapter" concept as originally framed by APM (supporting three backends: spec-kit directory, `.apm/context/`, gh-aw `cache-memory`) should be dissolved. It is not a single adapter. It is three independent, tool-scoped responsibilities that happen to touch the same artifacts. Framing them as one "adapter" creates an unowned coordination obligation. Framing them as three independent specifications, each owned by the tool that operates the backend, produces three owned deliverables with no coordination gap.

**Technical justification**: gh-aw's cache-memory does not need an adapter to persist `.specify/orchestrator/`. It already does this. The `cache-memory` primitive works by uploading and downloading GitHub Actions artifacts keyed by workflow run ID (see `pkg/workflow/cache.go`, `CacheMemoryConfig` and `CacheMemoryEntry`). The cache entry specifies a directory path and allowed file extensions. To persist `.specify/orchestrator/`, a workflow declares a `cache-memory` entry with the orchestrator's state directory as the path. The restore step downloads the latest matching artifact; the persist step uploads the current directory contents. There is no "adapter" -- it is configuration.

Here is what an orchestrator workflow's cache-memory entry would look like in gh-aw frontmatter:

```yaml
cache-memory:
  - id: orchestrator-state
    key: orchestrator-${{ env.GH_AW_WORKFLOW_ID_SANITIZED }}
    description: Orchestrator state directory for cross-run persistence
    allowed-extensions: [".md", ".json", ".jsonl", ".yaml", ".yml", ".txt"]
```

This is standard gh-aw cache-memory usage. No adapter, no new abstraction, no coordination with APM or spec-kit. The orchestrator state is restored at the start of the run and persisted at the end. The cache key uses a static prefix (`orchestrator-`) plus the workflow ID, ensuring each orchestrator workflow has its own cache namespace.

APM's `.apm/context/` discovery is similarly not an adapter -- it is APM's `SpeckitOrchestratorIntegrator` reading from a known path during `apm compile`. APM owns this entirely.

spec-kit's storage contract is the only piece that needs to be documented in the spec itself: what files exist in `.specify/orchestrator/`, what their schemas are, and which ones are safe to read concurrently (all of them, per the spec's concurrent-read requirement).

**Engagement with counter-positions**:

*APM's current position*: APM has already largely conceded this. APM's iteration 2 states: "The adapter as originally conceived is withdrawn as a P1 concern. For P1-P6, there is no adapter -- files live in `.specify/` and are read directly. For P7 CI, gh-aw's restore-execute-persist lifecycle handles the `.specify/` tree without any adapter." APM takes ownership of the APM-discovery piece through its integrator mechanism and defers the rest. This is convergent with gh-aw's position.

*spec-kit's current position*: spec-kit calls the adapter "scope creep" and wants it deferred entirely to P8 or dissolved. spec-kit's iteration 2 states: "This dispute is a derivative of Dispute 1 [discovery timeline]. If the discovery timeline dispute is resolved, the adapter concept either becomes unnecessary or becomes a concrete P8 deliverable." This is also convergent.

The convergence across all three tools is clear. The dispute survives only because the label "pluggable storage adapter" continues to exist as an unassigned design artifact. Dissolving the label into three tool-scoped specifications closes the dispute.

**gh-aw's proposed resolution**: The spec's expanded P7 section documents three independent specifications, each owned by the tool that operates the relevant backend:

1. **Canonical storage contract (spec-kit owns)**: Document the directory layout, file formats, schemas, and concurrent-read safety guarantees of `.specify/orchestrator/`. This is the "what exists" specification. It belongs in the orchestrator spec itself, reviewed by spec-kit.

2. **CI persistence configuration (gh-aw owns)**: Document the `cache-memory` entry configuration for persisting `.specify/orchestrator/` across CI runs. This is a standard gh-aw frontmatter block -- key naming, retention policy, allowed extensions, restore/persist lifecycle. gh-aw contributes this as part of its P7 CI architecture documentation. It is not an adapter; it is workflow configuration.

3. **Build-time discovery integration (APM owns)**: Document the `SpeckitOrchestratorIntegrator` that reads orchestrator artifacts from `.specify/orchestrator/` during `apm compile`. APM builds this in its own `BaseIntegrator` framework. It runs during the optional `apm compile` step in the CI lifecycle (step 2 of Rec 2) and during local development whenever the developer runs `apm compile`. APM contributes this specification as part of its P8 deliverable, but may ship the integrator earlier if it chooses.

No "pluggable storage adapter" concept is specified in the orchestrator spec. The spec documents the storage contract. Each tool documents its own interaction with that contract in its own P7/P8 deliverables.

**Concession offered**: gh-aw withdraws its iteration 2 offer to contribute a "cache-memory adapter specification" (PC-5 from the iteration 1 review of APM). There is no adapter to specify. gh-aw will instead contribute a concrete cache-memory frontmatter example and lifecycle documentation for the P7 section, which is more useful and more specific than an abstract adapter specification.

---

## Package Deal

If gh-aw could get one dispute fully its way in exchange for conceding the other two, it would choose **Dispute 3: dissolving the adapter concept**.

Here is why:

**Dispute 1 (state path) is already resolved.** All three tools have converged on `.specify/orchestrator/` through independent reasoning. There is nothing to trade. Claiming this as a "win" would be taking credit for a consensus that spec-kit drove.

**Dispute 2 (discovery timeline) is an APM implementation question, not an architectural one.** gh-aw's position is that the spec should document a stable storage contract and let APM decide when to build its integrator. Whether APM gets discovery at P1, P7, or P8 does not affect gh-aw's CI architecture. gh-aw can concede any timeline APM and spec-kit agree on because the CI lifecycle step for `apm compile` is already optional.

**Dispute 3 (adapter ownership) is the one that matters for CI architecture.** If the "pluggable storage adapter" survives as a concept in the spec, it becomes an unowned design artifact that blocks P7 implementation. The P7 section cannot document the CI lifecycle if it depends on an adapter that nobody has committed to building. Dissolving the adapter into three tool-scoped specifications -- each owned by the tool that understands its own backend -- unblocks P7 authorship. gh-aw can document its cache-memory configuration without waiting for APM to define its discovery mechanism. APM can build its integrator without waiting for gh-aw to define a serialization format. spec-kit can document the storage contract without waiting for either consumer to formalize their read patterns.

The package deal logic: Dispute 1 costs nothing (already settled). Dispute 2 costs nothing (gh-aw is neutral on the timeline). Dispute 3 has real implementation consequences for P7. gh-aw trades the two disputes that do not affect it for the one that does.

But in practice, all three disputes appear to be converging naturally. The package deal framing may be unnecessary. If forced to declare: gh-aw concedes Disputes 1 and 2 unconditionally and asks that Dispute 3 be resolved by dissolving the adapter concept into tool-scoped specifications as described above.
