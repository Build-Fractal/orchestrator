# gh-aw Utilization Review -- Iteration 3 (Final)

## Position Evolution

**Original (UTILIZATION.md):** gh-aw identified 10 recommendations for deeper CI integration, leading with gh-aw capabilities and proposing cache-memory/repo-memory as canonical state locations -- a consistent blind spot that both APM and spec-kit flagged as dangerous.

**Iteration 1 (UTILIZATION.iteration_1.md):** Withdrew 0 recommendations, modified 5 to reposition gh-aw primitives from canonical storage to transport/durability layer; the working tree became canonical, gh-aw became the CI execution and persistence mechanism behind it.

**Iteration 2 (UTILIZATION.iteration_2.md):** Locked 10 consensus points with APM and spec-kit; all "dangerous" ratings resolved; narrowed remaining disagreements to 3 disputes (state path, APM discovery timeline, adapter ownership) -- none architectural, all tractable.

**Iteration 3 (this document):** All 3 disputes resolved by convergence. All three tools independently arrived at the same positions on all three disputes. No human arbitration required. The review process is complete.

---

## Dispute Resolutions

### Dispute 1: State Path -- RESOLVED

**Dispute:** `.specify/orchestrator/` vs `.specify/extensions/orchestrator/` as the canonical state directory.

**Resolution:** All three tools converge on `.specify/orchestrator/`. This was functionally resolved in iteration 2 -- all three tools had independently moved to this path -- but the formal dispute persisted because of the iteration 1 crossed-wires incident (gh-aw adopted the extension convention path as a concession to spec-kit at the same moment spec-kit was withdrawing it). Iteration 3 closes the loop.

The technical arguments are unanimous:

- **spec-kit** provides the strongest rationale: placing runtime state at `.specify/extensions/orchestrator/` means `ExtensionManager.remove()` (which calls `shutil.rmtree` on the extension directory) would destroy accumulated project knowledge -- phase summaries, decisions, knowledge entries -- as a side effect of uninstalling the extension. This is a data loss hazard with no recovery path. The extension's installable artifacts (manifest, commands, templates) live at `.specify/extensions/orchestrator/`; the orchestrator's runtime state lives at `.specify/orchestrator/`. The `state_dir` field in the extension manifest bridges discovery.

- **APM** confirms the path is immaterial to its implementation (`discover_primitives` uses configurable globs), defers to spec-kit, and notes the shorter path is operationally simpler for cache keys, documentation, and `apm compile` configuration.

- **gh-aw** confirms both paths are equally viable for cache-memory (the cache key is derived from workflow ID, not from the cached directory path) but prefers `.specify/orchestrator/` because it avoids coupling the cache key derivation to spec-kit's extension directory convention, which could change independently.

**gh-aw's final position:** `.specify/orchestrator/` is the canonical state path. The spec includes a brief rationale for the deviation from the extension convention. `specify extension info` discovers runtime state via the `state_dir` manifest field. On `specify extension remove`, runtime state is preserved with a user-facing warning.

### Dispute 2: APM Discovery Timeline -- RESOLVED

**Dispute:** When does APM get compile-time access to orchestrator artifacts? P1, P7, or P8?

**Resolution:** APM gets read access from P1 onward, via a unilateral APM-side mechanism (`compilation.include_paths` config key or a `SpeckitOrchestratorIntegrator`) that requires zero changes to the orchestrator or spec-kit.

All three tools converged:

- **APM** argued for P1 access, proposing its Option 2 (an APM-side integrator reading from `.specify/orchestrator/` during `apm compile`). The key argument: deferring to P8 means APM's compilation pipeline encounters orchestrator artifacts for the first time at the distribution packaging moment, making P8 a first-time gamble rather than a well-tested operation.

- **spec-kit** moved from its iteration 2 position (defer to P7) to accepting P1 access, recognizing that APM's Option 2 violates none of spec-kit's hard stances: no artifacts outside `.specify/`, clean `specify extension remove`, no build-time APM dependency in the runtime path. spec-kit correctly identified its own iteration 2 error: conflating "APM discovery" (read access to files on disk) with "APM dependency" (architectural coupling). Reading files from the working tree is a consequence of the working tree being canonical (locked consensus point 1), not an architectural dependency.

- **gh-aw** has no stake in the local-development discovery timeline. gh-aw's CI lifecycle already includes an optional `apm compile` step (step 2 of the Rec 2 lifecycle) that runs after cache restoration and before extension installation. Whether APM ships the integrator at P1 or P8 does not affect gh-aw's architecture -- the step is optional and degrades gracefully.

**gh-aw's final position:** The spec documents a stable storage contract for `.specify/orchestrator/` (directory layout, file formats, schemas). APM builds its own integrator to read from that path -- this is an APM deliverable on APM's timeline. The CI lifecycle includes the optional `apm compile` step regardless of whether APM has shipped the integrator. The spec's only obligation is a stable, documented, parseable artifact format. When APM ships its integrator is APM's business.

### Dispute 3: Adapter Ownership -- RESOLVED

**Dispute:** Who builds the "pluggable storage adapter" that bridges artifacts between spec-kit's canonical directory, APM's discovery path, and gh-aw's cache-memory?

**Resolution:** The adapter concept is formally retired. It is not deferred -- it is removed from the design vocabulary. All three tools independently concluded the adapter is unnecessary.

The convergence:

- **APM** formally buried the concept it originated: "The 'pluggable storage adapter' as originally conceived is dead." APM's reasoning: with Dispute 2 resolved (APM reads directly from `.specify/orchestrator/`), the three "backends" the adapter was bridging reduce to one canonical location (`.specify/orchestrator/` on disk), one transport mechanism (gh-aw `cache-memory`), and one withdrawn proposal (`.apm/context/`, which APM dropped in iteration 1). An adapter that bridges one location to itself is not an adapter.

- **spec-kit** called the adapter "scope creep" and identified it as a derivative of Dispute 2: "If the discovery timeline dispute is resolved, the adapter concept either becomes unnecessary or becomes a concrete P8 deliverable." With Dispute 2 resolved, the adapter is unnecessary.

- **gh-aw** proposed dissolving the adapter label into three independent, tool-scoped specifications -- each owned by the tool that operates the relevant backend. This was gh-aw's package-deal priority: the adapter concept, if it survived in the spec, would become an unowned design artifact blocking P7 implementation.

**What replaces the adapter:** Three concrete, tool-owned deliverables that require no cross-tool coordination beyond the documented storage contract:

1. **Canonical storage contract (spec-kit owns):** Directory layout, file formats, schemas, and concurrent-read safety guarantees of `.specify/orchestrator/`. Documented in the orchestrator spec's expanded P7 section.

2. **CI persistence configuration (gh-aw owns):** Standard `cache-memory` frontmatter entry for persisting `.specify/orchestrator/` across CI runs, including cache-coherency edge cases (restore failure = cold start; persist failure = next run gets stale state). This is workflow configuration, not an adapter.

3. **Build-time discovery integration (APM owns):** The `SpeckitOrchestratorIntegrator` or `compilation.include_paths` support that reads orchestrator artifacts during `apm compile`. This runs during the optional CI lifecycle step and during local development. APM ships this on its own timeline.

**gh-aw's final position:** No "pluggable storage adapter" exists in the spec or in any tool's deliverables. gh-aw contributes a concrete `cache-memory` frontmatter example and lifecycle documentation for the P7 section. gh-aw withdraws its iteration 2 offer to contribute a "cache-memory adapter specification" (PC-5) -- there is no adapter to specify.

---

## Final Recommendations (All Iterations Cumulative)

1. **Abstract dispatch interface with gh-aw as CI backend.** The spec defines a runtime-agnostic dispatch interface for Tier C with minimum specification (input schema, output contract, two reference implementations: local shell and gh-aw CI). In CI, the interface maps to `call-workflow` (synchronous) and `dispatch-workflow` (async). APM `.prompt.md` defines the work; gh-aw frontmatter defines execution. *(Locked from iteration 2)*

2. **Working tree as canonical state, cache-memory as CI durability layer.** Canonical state at `.specify/orchestrator/`. CI lifecycle: restore from cache-memory, optional `apm compile`, install/verify spec-kit extension, execute orchestrator logic, persist back to cache-memory. Cache-coherency contract documented in P7 (restore failure = cold start, persist failure = stale state with reconciliation). *(Modified in iteration 2 with path correction; dispute resolved in iteration 3)*

3. **Knowledge consolidation in working tree, repo-memory as backup.** Compressed milestone summaries at `.specify/orchestrator/consolidated/`. `repo-memory` as secondary disaster recovery only; content must be checked out to working tree before other tools operate on it. *(Locked from iteration 2)*

4. **Replace PID-based crash recovery with workflow-run-status recovery.** CI crash detection via `gh run list`/`gh run view`. State recovery from restored working tree. Re-trigger via `workflow_dispatch`. No PID files in CI. *(Locked from iteration 1)*

5. **Spec-owned verification commands, post-steps as CI adapter.** The spec defines verification commands as the single source of truth. `post-steps:` invokes them in CI; spec-kit hooks invoke them locally. Neither adapter replaces or overrides the spec-owned commands. *(Locked from iteration 2)*

6. **Spec-kit config as budget authority, gh-aw as CI enforcement.** Budgets defined in spec-kit's layered config system. CI integration reads budgets at compile time and translates to gh-aw frontmatter (`stop-after`, `concurrency`, `safe-outputs.*.max`). Single schema prevents drift. *(Locked from iteration 2)*

7. **GitHub Projects as optional CI status visualization.** `execution-log.jsonl` is the canonical status artifact. GitHub Projects integration via `update-project` and `create-project-status-update` is optional and does not replace file-based status. *(Locked from iteration 2)*

8. **One-phase-per-run model as the recommended Tier C CI architecture.** The single-job execution model is a hard platform constraint. The campaign pattern is recommended when the orchestrator needs LLM reasoning at phase transitions. Alternative architectures (traditional workflows with matrix jobs, chained `workflow_dispatch`) documented as escape hatches for deterministic phase transitions. Orchestration/execution separation: `steps:` block selects the phase (deterministic); agent executes the work (agentic). Session continuity limitations documented explicitly. *(Modified in iteration 2 with clarifications; locked from iteration 2)*

9. **Reference TaskOps for Tier B CI implementation.** Tier B maps to TaskOps: research agent investigates, planner creates scoped issues with human review gate, issues assigned to Copilot agents. *(Locked from iteration 1)*

10. **Expand P7 to full CI integration design.** Joint deliverable with contributions from all three tools. Scope includes: single-job execution model constraint, abstract dispatch interface, working-tree-as-canonical-state lifecycle, spec-kit extension installation sequence, APM compilation step placement, one-phase-per-run campaign architecture, alternative CI architectures, budget enforcement translation, hook execution in cold-start CI environments, dual distribution channel sequencing, CI hook limitations subsection, and the storage contract for `.specify/orchestrator/`. *(Locked from iteration 2; scope expanded through all iterations)*

---

## Final Consensus Points (10 from Iteration 2 + 3 from Iteration 3)

### Locked from Iteration 2

1. **The working tree is canonical for all agent-consumable artifacts.** gh-aw's cache-memory and repo-memory are transport/durability mechanisms, not canonical storage. APM discovery and spec-kit resolution operate on the working tree during execution.

2. **Configuration authority flows from the spec's config system.** Budgets, verification commands, dispatch caps, and concurrency limits are defined in the orchestrator's configuration. gh-aw frontmatter and APM manifests consume these values via mechanical translation.

3. **Verification is spec-owned with CI adapters.** The spec defines what to verify. spec-kit hooks invoke verification locally. gh-aw `post-steps:` invoke verification in CI. Neither adapter replaces the spec-owned commands.

4. **Namespaced commands, not core command overrides.** The orchestrator uses `speckit.orchestrator.{command}` namespaced commands. Presets that silently mutate core command behavior are incompatible with CI auditability.

5. **Single-directory state tree at `.specify/orchestrator/`.** Not scattered across feature directories or split between extension trees. gh-aw needs a static cache key; APM needs a predictable discovery path; spec-kit discovers state via the extension manifest's `state_dir` field.

6. **P7 needs major expansion.** One paragraph is insufficient. The expanded section is a joint deliverable with contributions from all three tools along domain expertise boundaries.

7. **The single-job execution model is a hard platform constraint.** The spec's multi-phase dispatch loop cannot run as a single agentic workflow. This constraint shapes all CI architecture decisions.

8. **APM's hybrid package at P8 is the distribution integration point.** APM's value to the orchestrator is at the distribution boundary. The hybrid package (dual manifests, distribution through APM registries, static context injection via gh-aw `dependencies:`) is the correct and sufficient integration point.

9. **TaskOps maps cleanly to Tier B.** No tool has objected to this mapping across any iteration.

10. **Abstract dispatch interface with concrete backends.** The dispatch mechanism is runtime-agnostic at the interface level, with gh-aw providing the CI backend and local shell execution providing the local backend.

### New from Iteration 3

11. **`.specify/orchestrator/` is the canonical state path (not `.specify/extensions/orchestrator/`).** The extension convention path is reserved for extension installable artifacts (manifest, commands, templates). Runtime state at `.specify/orchestrator/` survives `specify extension remove` and is accessible to all three tools without going through spec-kit's extension resolution. Discovery bridged by `state_dir` manifest field.

12. **APM gets compile-time read access from P1, via a unilateral APM-side mechanism.** The orchestrator and spec-kit make zero accommodations. APM builds and maintains its own integrator (`SpeckitOrchestratorIntegrator` or `compilation.include_paths`). If the integrator breaks due to upstream layout changes, that is APM's problem to fix. Read access to the working tree is a consequence of consensus point 1, not a dependency relationship.

13. **The "pluggable storage adapter" concept is formally retired.** It is not deferred to a future phase -- it is removed from the design vocabulary. Each tool owns its own integration with the documented storage contract: spec-kit owns the contract itself, gh-aw owns cache-memory configuration, APM owns build-time discovery. No shared adapter layer exists.

---

## Remaining Disputes for Human Arbitration

None. All disputes resolved.

The three disputes that entered iteration 3 were resolved by natural convergence -- all three tools independently arrived at the same positions through their own technical reasoning. Dispute 1 (state path) was already resolved in iteration 2 and formally closed here. Dispute 2 (APM discovery timeline) resolved when spec-kit conceded its iteration 2 deferral position after recognizing APM's Option 2 satisfies all hard stances. Dispute 3 (adapter ownership) dissolved as a consequence of Dispute 2's resolution: the adapter was invented to solve the problem of APM not being able to see artifacts, and that problem no longer exists.

The review process across three iterations produced 10 recommendations (0 withdrawn, 5 modified, 5 unchanged), 13 consensus points, and 0 unresolved disputes. The most durable outcome is not any individual recommendation but the layer-boundary model that emerged: gh-aw is the CI execution and durability layer, spec-kit is the extension and configuration authority, APM is the distribution and context optimization layer, and the spec owns the domain logic. This model resolved every "dangerous" rating and every cross-tool conflict by eliminating layer competition.
