# gh-aw Utilization Review -- Iteration 2

## Position Evolution

### Original (UTILIZATION.md)
gh-aw's original review identified 10 recommendations for deeper integration between the speckit-orchestrator spec and gh-aw's CI primitives. The core thesis: gh-aw provides mature orchestration, caching, dispatch, and monitoring capabilities that the spec treats as a one-paragraph appendix. The review catalogued missed opportunities (call-workflow, cache-memory, repo-memory, campaign pacing, TaskOps, GitHub Projects) and flagged off-base assumptions (single-job execution model constraints, PID-based crash detection in CI, filesystem concurrency assumptions).

The original review had a consistent blind spot: it recommended moving state and configuration into gh-aw-native locations (cache-memory, repo-memory, gh-aw frontmatter) without accounting for how APM and spec-kit discover and operate on artifacts. Three recommendations (#2, #3, #8) were flagged as dangerous by both reviewers for the same root cause -- placing canonical state outside the working tree.

### Iteration 1 (UTILIZATION.iteration_1.md)
After cross-review, gh-aw withdrew 0 recommendations, modified 5, and stood by 5. All five modifications followed a single structural correction: gh-aw primitives were repositioned from canonical storage/state locations to CI execution and durability mechanisms. The working tree became canonical; gh-aw became the transport layer.

Key shifts:
- cache-memory: from "CI-mode state persistence layer" to "durability layer that restores/persists the working tree across ephemeral runners"
- repo-memory: from "primary knowledge consolidation store" to "secondary disaster recovery backup"
- call-workflow/dispatch-workflow: from "the dispatch mechanism" to "CI-mode implementation of an abstract dispatch interface"
- post-steps: from "the verification mechanism" to "CI adapter for spec-owned verification commands"
- stop-after/concurrency: from "budget enforcement configuration" to "CI enforcement mechanisms consuming spec-kit-owned budget config"

gh-aw stood firm on Rec 8 (one-phase-per-run) as a hard platform constraint, not a design preference.

### Iteration 2 (this document)
Both APM and spec-kit reviewed gh-aw's iteration 1 and found the modifications genuine. APM formally dropped its "dangerous" rating on the one-phase-per-run model after withdrawing its own Rec 1 (`.prompt.md` for dispatch), removing the source of the original conflict. spec-kit accepted the campaign pattern as a viable (though not sole) CI architecture with corrected implementation details.

The remaining issues from iteration 1 reviews are narrow and actionable: a crossed-wires problem on the state directory path, underspecification of the abstract dispatch interface, cache-coherency edge cases, and the question of who builds the pluggable adapter. No fundamental architectural disagreements survive.

This iteration locks positions where consensus exists, addresses the narrow remaining concerns, and proposes specific compromises for the few genuine disputes.

---

## Current Recommendations (Final Positions)

### Rec 1: Abstract dispatch interface with gh-aw as CI backend
**Status**: Locked
**Position**: The spec should define an abstract dispatch interface for Tier C that is agent-runtime-agnostic. When running in CI with gh-aw, that interface maps to `call-workflow` (synchronous worker execution) and `dispatch-workflow` (async fire-and-forget). The interface should have a concrete minimum specification: (a) an input schema defining what data a dispatch payload must carry, (b) an output contract defining what a completed dispatch must return, and (c) two reference implementations -- local shell execution and gh-aw CI execution. APM `.prompt.md` files define what the worker does; gh-aw workflow frontmatter defines how and when it runs. The adapter pattern (gh-aw workflow declares APM `dependencies:` in frontmatter, body references the APM prompt) is the correct integration seam.

**Cross-tool consensus**: All three tools agree on the abstract interface approach. APM raised NC-2 in its iteration 1 review: the abstract interface is underspecified and risks becoming an open-ended design task. APM proposed constraining it with the minimum specification (input schema, output contract, two reference implementations). gh-aw accepts this constraint and incorporates it into the recommendation. spec-kit endorsed the abstract interface in its original review and has not objected to the minimum specification approach. This recommendation is fully converged.

### Rec 2: Working tree as canonical state, cache-memory as CI durability layer
**Status**: Modified (path updated)
**Position**: The orchestrator's canonical state directory is `.specify/orchestrator/` in both local and CI modes. In CI, gh-aw's `cache-memory` provides cross-run durability for the working tree on ephemeral runners. The CI run lifecycle is:

1. Restore `.specify/orchestrator/` tree from `cache-memory`
2. (Optional) Run `apm compile` if the orchestrator is installed as an APM hybrid package, to regenerate optimized context from restored artifacts
3. Install/verify the spec-kit extension (`specify extension add orchestrator`)
4. Execute orchestrator logic, reading and writing to the working tree
5. Persist `.specify/orchestrator/` tree back to `cache-memory`

If step 5 fails (persist-to-cache failure after successful execution), the next run restores stale state from cache. The expanded P7 section should document this cache-coherency contract: what happens when restore fails (cold start, treat as fresh initialization), what happens when persist fails (next run gets stale state, orchestrator must detect and reconcile via disk-state checksums or timestamps), and whether the orchestrator should verify cache freshness before starting work.

**Cross-tool consensus**: All three tools agree that the working tree is canonical and cache-memory is a transport/durability layer. APM confirmed this resolves its original dangerous flag (DC-1). spec-kit confirmed the same (DC-1). APM raised NC-1: the lifecycle needs an explicit step for `apm compile`. gh-aw accepts this and adds it as step 2 (optional, only when APM hybrid package is installed). spec-kit raised NC-1: cache-coherency edge cases for persist failures. gh-aw accepts this concern and adds cache-coherency documentation requirements to the P7 section scope.

**Path change**: gh-aw's iteration 1 used `.specify/extensions/orchestrator/` (adopted as a concession to spec-kit's extension conventions). spec-kit's own iteration 1 withdrew that convention and reverted to `.specify/orchestrator/`, arguing the orchestrator's state has a wider audience than spec-kit alone. Both tools moved toward each other's position and crossed in transit. gh-aw now aligns with spec-kit's revised position: `.specify/orchestrator/` is the canonical path. This resolves the crossed-wires issue identified in gh-aw's iteration 1 review of spec-kit.

### Rec 3: Knowledge consolidation in working tree, repo-memory as backup
**Status**: Locked
**Position**: Compressed milestone summaries live in `.specify/orchestrator/consolidated/` (working tree), making them visible to APM compilation, spec-kit template resolution, and `specify extension info`. `repo-memory` may be used as a secondary backup mechanism for knowledge that needs to survive branch resets or force-pushes, but any `repo-memory` content must be checked out into the working tree before other tools operate on it. This is a disaster recovery mechanism, not a primary storage strategy.

**Cross-tool consensus**: Fully converged. APM confirmed this genuinely resolves its original dangerous flag (DC-3), calling it "a genuine withdrawal of the original position." spec-kit confirmed the same (DC-3), accepting that `repo-memory` as a write-behind backup that requires explicit checkout is the right framing. No new concerns raised by either tool in iteration 1.

### Rec 4: Replace PID-based crash recovery with workflow-run-status recovery
**Status**: Locked
**Position**: In CI, crash detection uses `gh run list`/`gh run view` to check the status of the last orchestrator run. State recovery reads the last-known state from the restored working tree (via the cache-memory pattern from Rec 2). Re-trigger via `workflow_dispatch`. No PID files or stale lock detection in CI.

**Cross-tool consensus**: Fully converged from the original review. Both APM and spec-kit confirmed this is orthogonal to their concerns. No changes across any iteration.

### Rec 5: Spec-owned verification commands, post-steps as CI adapter
**Status**: Locked
**Position**: The spec defines verification commands (lint, test, build) in its own configuration as the single source of truth. In CI mode, these commands are wired into gh-aw `post-steps:` blocks for guaranteed deterministic execution outside the agent sandbox. Locally, the same commands are invoked by spec-kit hooks or by the orchestrator's own verification step. The verification logic is owned by the spec; `post-steps:` and spec-kit hooks are invocation adapters for their respective execution contexts.

**Cross-tool consensus**: Fully converged. spec-kit confirmed this matches its hard stance (HS-2): "spec-kit hooks are the canonical verification mechanism; CI adapters invoke them, not replace them." APM has no verification mechanism and defers to this model. No new concerns raised in iteration 1.

### Rec 6: Spec-kit config as budget authority, gh-aw as CI enforcement
**Status**: Locked
**Position**: Budgets (dispatch count, duration limits, concurrency caps) are defined in the spec's configuration system (spec-kit's layered config: defaults > project config > local overrides > env vars) as the single source of truth. The CI integration layer reads these budgets at compile time and translates them into gh-aw frontmatter (`stop-after`, `concurrency` groups, `safe-outputs.*.max`). gh-aw enforces budgets at runtime in CI; the spec's own enforcement applies locally. A single schema definition prevents configuration drift.

**Cross-tool consensus**: Fully converged. spec-kit confirmed this matches its hard stance (HS-3): "Configuration authority flows from the spec's own config system, not from CI infrastructure." APM has no runtime budget concept and defers. No new concerns raised in iteration 1.

### Rec 7: GitHub Projects as optional CI status visualization
**Status**: Locked
**Position**: `execution-log.jsonl` remains the canonical status artifact per the spec's disk-state philosophy. When running in CI with gh-aw, progress can additionally be tracked via `update-project` and `create-project-status-update` safe outputs on a GitHub Projects board. This is explicitly optional and does not replace file-based status. The spec should state both mechanisms and their relationship.

**Cross-tool consensus**: Fully converged. spec-kit's original tension was addressed by the "optional, not replacement" framing. APM has no status mechanism and defers. No new concerns raised in iteration 1.

### Rec 8: One-phase-per-run model for Tier C CI execution
**Status**: Modified (clarifications added)
**Position**: The single-job execution model is a hard platform constraint. The one-phase-per-run campaign pattern is the recommended architecture for Tier C in CI. The implementation details are:

- State lives in the working tree at `.specify/orchestrator/` (Rec 2)
- spec-kit extensions are installed/verified at the start of each run (step 3 of the Rec 2 lifecycle)
- The orchestrator selects which pre-authored prompt to execute based on phase state read from disk (dynamic selection, not dynamic generation)
- The scheduling model uses gh-aw's campaign pattern with scheduled triggers

**Separation of orchestration logic from agent execution**: spec-kit's NC-2 correctly identifies that the iteration 1 description blurred the line between orchestration logic and agent execution. The clarified model: a `steps:` block (deterministic, non-agentic) reads the restored working tree, determines the current phase, and sets environment variables or writes a phase-selection file. The agentic workflow then executes the specific unit of work for that phase. The `steps:` block is the orchestration selector; the agent is the executor. This separation is explicit and avoids embedding phase-routing logic inside the LLM agent.

**Session continuity for hooks**: spec-kit correctly identified that hooks fire in a cold-start environment where the agent has no conversational context from prior phases. For hooks that run shell commands (lint, test, build via `post-steps:`), this is irrelevant. For hooks that depend on the agent understanding why it is at a particular point, this is a genuine degradation. gh-aw's position: this degradation is inherent to any multi-run architecture on an ephemeral platform and is not solvable at the CI layer. The orchestrator's disk-state-as-truth design mitigates it -- the agent reconstructs context from artifacts, not from conversational memory. If this mitigation is insufficient for specific hooks, those hooks should be redesigned to be context-independent (reading their required context from disk artifacts rather than relying on session state).

**Alternative architectures**: spec-kit noted that the one-phase-per-run model is not the only alternative to a single-run dispatch loop. Traditional GitHub Actions workflows with matrix jobs, or chained `workflow_dispatch` invocations, are also possible. gh-aw acknowledges these alternatives exist. gh-aw's position: the campaign pattern is the recommended architecture because it is the only one that uses agentic workflows (LLM agents). The alternatives (traditional workflows, matrix jobs) are not agentic -- they are conventional CI automation. If the orchestrator's CI mode only needs conventional automation (run these shell commands in this order), then a traditional workflow suffices and gh-aw's agentic workflow primitives are unnecessary. If the orchestrator needs an LLM agent to reason about phase transitions, evaluate task results, and make dispatch decisions, then the one-phase-per-run campaign pattern is the only viable architecture. The expanded P7 section should document both paths and when each is appropriate.

**Cross-tool consensus**: APM formally dropped its "dangerous" rating, conceding that the withdrawal of its own Rec 1 (`.prompt.md` for dispatch) removed the primary conflict. APM stated: "The one-phase-per-run model is not dangerous to APM's revised position. gh-aw's standing firm here is defensible." spec-kit accepted it as a viable architecture with caveats: it should be documented as the recommended approach (not the only option), session continuity limitations should be explicit, extension installation cost per run should be benchmarked, and alternative architectures should be mentioned as escape hatches. gh-aw accepts all four caveats and incorporates them.

### Rec 9: Reference TaskOps for Tier B CI implementation
**Status**: Locked
**Position**: Tier B maps to gh-aw's TaskOps pattern for CI execution: Phase 1 (research agent investigates), Phase 2 (planner creates scoped issues with human review gate), Phase 3 (issues assigned to Copilot agents for execution). Both APM and spec-kit confirmed alignment.

**Cross-tool consensus**: Fully converged from the original review. No changes across any iteration.

### Rec 10: Expand P7 to full CI integration design
**Status**: Modified (scope expanded)
**Position**: The spec's P7 section needs expansion from one paragraph to a full CI integration design. The section should cover:

1. The single-job execution model constraint and what agentic workflows cannot do
2. The abstract dispatch interface (Rec 1) with minimum specification (input schema, output contract, two reference implementations)
3. The working-tree-as-canonical-state pattern (Rec 2) including the full CI run lifecycle and cache-coherency contract
4. spec-kit extension installation sequence on ephemeral runners (canonical `steps:` block)
5. APM compilation step placement in the CI lifecycle (optional, when hybrid package is installed)
6. The one-phase-per-run campaign architecture (Rec 8) with the orchestration/execution separation clarified
7. Alternative CI architectures (traditional workflows, matrix jobs) and when each is appropriate
8. Budget enforcement translation from spec config to gh-aw frontmatter (Rec 6)
9. Hook execution behavior in cold-start CI environments and known limitations
10. Dual distribution channel installation sequencing (spec-kit catalog first, then APM)

**Cross-tool consensus**: Unanimously endorsed across all iterations. spec-kit proposed collaborative authorship (PC-3 in its iteration 1 review): spec-kit contributes extension lifecycle requirements, gh-aw contributes CI execution architecture, APM contributes distribution and context compilation requirements. gh-aw accepts this collaborative model. This is the single most important deliverable from the entire review process.

---

## Convergence Points

After two iterations, all three tools agree on the following positions. These are locked and should not be reopened.

1. **The working tree is canonical for all agent-consumable artifacts.** gh-aw's cache-memory and repo-memory are transport/durability mechanisms, not canonical storage. APM discovery and spec-kit resolution operate on the working tree during execution. This was the central architectural dispute of the original review cycle, and it is fully resolved.

2. **Configuration authority flows from the spec's config system.** Budgets, verification commands, dispatch caps, and concurrency limits are defined in the orchestrator's configuration. gh-aw frontmatter and APM manifests consume these values via mechanical translation. No tool claims configuration authority for the orchestrator.

3. **Verification is spec-owned with CI adapters.** The spec defines what to verify. spec-kit hooks invoke verification locally. gh-aw `post-steps:` invoke verification in CI. Neither adapter replaces or overrides the spec-owned commands.

4. **Namespaced commands, not core command overrides.** The orchestrator uses `speckit.orchestrator.{command}` namespaced commands. Presets that silently mutate core command behavior are incompatible with CI auditability. This was spec-kit's withdrawal of its own Rec 4, unanimously endorsed.

5. **Single-directory state tree.** The orchestrator's state lives at `.specify/orchestrator/` (not scattered across feature directories or split between extension trees). gh-aw needs a single, static cache key; APM needs a predictable discovery path; spec-kit can teach its extension commands to discover state at a non-default path via the extension manifest.

6. **P7 needs major expansion.** One paragraph is insufficient. The expanded section is a joint deliverable with contributions from all three tools along their domain expertise boundaries.

7. **The single-job execution model is a hard platform constraint.** The spec's multi-phase dispatch loop cannot run as a single agentic workflow. This was acknowledged by both APM and spec-kit. The constraint shapes all CI architecture decisions.

8. **APM's hybrid package at P8 is the distribution integration point.** APM's value to the orchestrator is at the distribution boundary. APM should not be in the orchestrator's critical dispatch path. The hybrid package (dual manifests, distribution through APM registries, static context injection via gh-aw `dependencies:`) is the correct and sufficient APM integration point.

9. **TaskOps maps cleanly to Tier B.** No tool has objected to this mapping across any iteration.

10. **Abstract dispatch interface with concrete backends.** The dispatch mechanism is runtime-agnostic at the interface level, with gh-aw providing the CI backend and local shell execution providing the local backend.

---

## Remaining Disputes

### Dispute 1: Extension installation cost per CI run -- unquantified

spec-kit's iteration 1 review raised this directly: "the revision does not quantify or bound this cost. If `specify extension add orchestrator` involves downloading from a catalog, resolving dependencies, registering commands into agent directories, and validating `requires.commands` -- that is nontrivial setup time on every single CI run."

**gh-aw's position**: The cache-memory restoration should handle the heavy lifting -- the extension files are already in the cached working tree from the previous run. The question is whether cache restoration is sufficient or whether extension install-time registration logic must re-execute. gh-aw cannot answer this because the installation cost is a spec-kit implementation detail. gh-aw's hard stance is only that the installation must fit within the `steps:` block (pre-agent, deterministic, bounded time). If extension installation takes 30 seconds, that is acceptable. If it takes 5 minutes, the one-phase-per-run model becomes impractical for frequent scheduled triggers.

**Counter-position (spec-kit)**: Extension installation on a cold runner may need to download from the catalog, resolve dependencies, and run registration. This cost needs to be benchmarked and bounded.

**Gap**: Neither tool has benchmarked this. It is an empirical question, not an architectural one. The expanded P7 section should document the expected installation cost and whether cache restoration eliminates the need for full re-installation.

### Dispute 2: Who builds the pluggable storage adapter

APM's revised Recs 2 and 6 rely on a "pluggable adapter" that mirrors artifacts between the canonical spec-kit location and both APM discovery paths and gh-aw cache-memory. gh-aw's iteration 1 review of APM flagged this: "no tool is taking ownership of building it."

**gh-aw's position**: gh-aw offered (PC-5 in iteration 1 review of APM) to contribute the `cache-memory` adapter specification -- the serialization format, cache key naming scheme, and restore/persist lifecycle hooks. APM should contribute the `.apm/context/` adapter specification. spec-kit should contribute the canonical storage contract. This distributes design work along tool-expertise boundaries.

**Counter-position (APM)**: APM acknowledged this is a medium-risk design-time concern, not an architectural conflict, but did not claim ownership of the APM adapter portion.

**Gap**: Ownership is unassigned. If nobody builds the adapter, APM cannot discover orchestrator artifacts in CI, which is the same problem APM's withdrawn Rec 9 (mirroring) was trying to solve. The P7/P8 sections should assign adapter ownership explicitly.

### Dispute 3: Session continuity for non-trivial hooks in cold-start CI environments

spec-kit raised this in its iteration 1 review: hooks that depend on the agent understanding *why* it is at a particular point fire in an environment where the agent's conversational context is empty. The hook has no access to reasoning or intermediate state that led to the current phase.

**gh-aw's position**: This degradation is inherent to any multi-run architecture on an ephemeral platform. The orchestrator's disk-state-as-truth design mitigates it (the agent reconstructs context from artifacts). If specific hooks require session context, they should be redesigned to be context-independent. gh-aw cannot provide session continuity across separate CI runs -- the platform does not support it.

**Counter-position (spec-kit)**: The degradation should be documented explicitly so that hook authors know the CI limitations. Some hooks may need a "CI-safe" designation indicating they work correctly in cold-start environments.

**Gap**: This is a documentation and design-pattern concern, not an architectural disagreement. gh-aw and spec-kit agree the degradation exists; the question is how to document and mitigate it. gh-aw proposes: the P7 section includes a "CI hook limitations" subsection that lists which hook execution patterns work in cold-start environments and which require session context that is unavailable.

---

## Proposed Compromises

### Compromise 1: Extension installation -- benchmark and document, do not block on architecture

gh-aw proposes that the P7 section include a performance budget for CI setup (the `steps:` block before the agent runs). spec-kit benchmarks extension installation cost. If cache restoration eliminates re-installation (because the extension files are already in the working tree), document that. If re-registration is required even when files are cached, document the expected cost and set a hard ceiling (e.g., 60 seconds). If the cost exceeds the ceiling, spec-kit investigates a "fast-verify" mode that skips download/dependency resolution and only validates the extension is intact.

This is an empirical question that should not block the spec. Include it in the P7 section as a performance requirement with a validation plan.

### Compromise 2: Adapter ownership -- assign in the P7/P8 scope boundary

gh-aw proposes explicit ownership assignment in the expanded P7 and P8 sections:
- **P7 scope (gh-aw)**: cache-memory adapter -- serialization format, cache key naming, restore/persist lifecycle. gh-aw owns this because it owns the cache-memory primitive.
- **P8 scope (APM)**: APM discovery adapter -- build-time export that reads from `.specify/orchestrator/` and produces APM-discoverable output. APM owns this because it owns the discovery pipeline.
- **Spec scope (spec-kit)**: Canonical storage contract -- the directory layout, file formats, and read/write semantics of `.specify/orchestrator/`. spec-kit owns this because it owns the extension system.

Each tool contributes its adapter specification as part of its own priority deliverable. No tool builds another tool's adapter.

### Compromise 3: Hook CI limitations -- joint documentation in P7

gh-aw and spec-kit jointly document a "CI Hook Execution" subsection in P7 that specifies:
- Hooks that run shell commands (lint, test, build) work identically in CI and local modes via `post-steps:`.
- Hooks that depend on agent conversational context degrade in CI because each run is a cold start. These hooks should include a "context reconstruction" preamble that reads required context from disk artifacts (phase summaries, decision registers, execution logs).
- Hook authors should test hooks in both local and CI modes. A hook that only works in local mode should be documented as "local-only."

This addresses spec-kit's concern without requiring gh-aw to provide session continuity that the platform cannot support.

### Compromise 4: One-phase-per-run as recommended, not sole -- document escape hatches

gh-aw accepts spec-kit's framing: the campaign pattern is the *recommended* CI architecture for Tier C, not the *only* option. The P7 section should document:
- **Recommended**: One-phase-per-run campaign pattern using agentic workflows (for when the orchestrator needs LLM reasoning at phase transitions)
- **Alternative A**: Traditional GitHub Actions workflow with matrix jobs and step dependencies (for when phase transitions are deterministic and do not require LLM reasoning)
- **Alternative B**: Chained `workflow_dispatch` invocations with explicit state handoff (for when phases are independent and can be triggered manually or by external systems)

gh-aw's hard stance is only that the campaign pattern is the correct architecture *when agentic workflows are used*. If the spec decides certain phase transitions do not need agentic execution, the alternatives are valid.

---

## Lessons Across Iterations

### 1. The most productive disagreements were about layer boundaries, not capabilities

The original review cycle was dominated by "gh-aw can do X, so the spec should use X." The most valuable outcome of two iterations is not a list of gh-aw features the spec should adopt -- it is a clear articulation of which layer each tool occupies. gh-aw is the CI execution and durability layer. spec-kit is the extension and configuration authority. APM is the distribution and context optimization layer. The spec owns the domain logic. Once these boundaries were established, most "dangerous" ratings dissolved because the tools stopped competing for the same layer.

### 2. Hard platform constraints are the most valuable contribution a CI tool can make

gh-aw's single most impactful contribution across all iterations was not a feature recommendation -- it was the warning that the spec's multi-phase dispatch loop cannot run as a single agentic workflow. Both APM and spec-kit acknowledged this as "extremely valuable." The lesson: when reviewing a spec as a CI tool, leading with platform constraints (what cannot work) is more valuable than leading with capabilities (what can work). The constraints shape the architecture; the capabilities fill in the implementation.

### 3. Moving toward another tool's position requires checking whether they moved too

The crossed-wires incident on the state directory path (gh-aw adopted `.specify/extensions/orchestrator/` as a concession to spec-kit at the same time spec-kit was withdrawing that path in favor of `.specify/orchestrator/`) is a process lesson. When two tools revise simultaneously without reading each other's revisions, they can diverge while both trying to converge. The iteration model (read all revisions before writing the next one) is the correct fix, and this iteration applies it.

### 4. Withdrawing a recommendation removes its downstream conflicts

APM's withdrawal of Rec 1 (`.prompt.md` for dispatch) automatically removed APM's basis for rating gh-aw's Rec 8 as "dangerous." Neither APM nor gh-aw noticed this in iteration 1 -- APM's meta-review in iteration 1 identified it and formally conceded the point. The lesson: when assessing whether a conflict persists, always check whether the premises of the conflict still hold after both sides' revisions. Many "unresolved" disputes are actually resolved by upstream withdrawals.

### 5. Empirical questions should not be treated as architectural disputes

The extension installation cost dispute (Dispute 1) is not an architectural disagreement -- it is an unasked empirical question. Both tools agree on the architecture (install in `steps:` block, use cached working tree). They disagree on whether the cost is acceptable, but neither has measured it. Two iterations of review cannot resolve an empirical question. The correct action is to benchmark and document, not to argue about whether it will be fast enough. The review process is most productive when it distinguishes architectural disagreements (which can be resolved by argument) from empirical unknowns (which can only be resolved by measurement).
