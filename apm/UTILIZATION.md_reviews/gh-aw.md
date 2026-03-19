# APM Review of gh-aw's Recommendations

## Dangerous Contradictions

### 1. Recommendation #2 (cache-memory as CI-mode state persistence) conflicts with APM's disk-as-truth model

gh-aw recommends that when running in CI, the `.specify/orchestrator/` artifact tree should be persisted as "structured JSON files in gh-aw cache-memory (multiple named caches)." APM's review (Recommendation #9) recommends mirroring `.specify/orchestrator/` context into `.apm/context/` so that `apm compile` can discover and optimize it.

These two recommendations are directly incompatible. If the orchestrator's state lives in gh-aw's `cache-memory` (mounted at `/tmp/gh-aw/cache-memory/`), it is invisible to APM. APM's primitive discovery scans `.apm/` and `.github/` directories (`apm/docs/src/content/docs/introduction/key-concepts.md`, lines 86-125). APM's compilation engine reads from `apm_modules/` and `.apm/` (`apm/docs/src/content/docs/guides/compilation.md`, lines 56-58). Neither path includes `/tmp/` or any gh-aw cache mount point.

If the spec follows gh-aw's advice and puts decisions, knowledge, and phase summaries into cache-memory, then APM's context optimization engine cannot compile those artifacts into dispatch payloads. The orchestrator would need to build its own context assembly system -- exactly what APM's review says should be avoided. Following gh-aw's recommendation #2 directly undermines APM recommendations #1, #2, #3, and #5.

**Severity: Dangerous.** The spec must choose one canonical persistence location for context artifacts. If cache-memory is used for CI durability, the artifacts must be copied back into `.apm/context/` (or `.specify/orchestrator/`) before APM compilation can operate on them.

### 2. Recommendation #8 (one-phase-per-run model) makes APM's prompt-based dispatch unusable

gh-aw recommends that Tier C CI execution adopt a "one-phase-per-run" model where each scheduled workflow run advances one phase, persists state to cache-memory, and exits. APM's review (Recommendation #1) recommends modeling each task dispatch as a `.prompt.md` file with `${input:name}` parameter substitution.

These models are structurally incompatible. APM's prompt system (`apm/docs/src/content/docs/guides/agent-workflows.md`, lines 14-16) executes `.prompt.md` files through AI runtimes in a single invocation. The `${input:name}` substitution happens at invocation time. If the orchestrator runs one phase per scheduled trigger and exits, there is no persistent process to invoke APM prompts in sequence. Each scheduled run would need to: (a) reconstruct which prompt to run from cache-memory state, (b) generate the prompt file dynamically, and (c) invoke it once -- turning APM's reusable prompt system into a single-use generation target.

More concretely: APM's prompt files are authored artifacts with declared parameters. gh-aw's one-phase-per-run model requires dynamically generated dispatch payloads that vary per run. APM prompts are designed to be static and reusable; the one-phase-per-run pattern needs them to be ephemeral and unique.

**Severity: Dangerous.** If the spec adopts one-phase-per-run, it should not attempt to use APM's `.prompt.md` system for task dispatch in CI mode. The two dispatch models are fundamentally different: APM prompts are pre-authored templates; gh-aw's campaign model is a state machine that generates work dynamically each run.

### 3. Recommendation #3 (repo-memory for knowledge consolidation) creates a split-brain for knowledge artifacts

gh-aw recommends storing compressed milestone summaries in `repo-memory` on an orphan branch (e.g., `memory/orchestrator`). APM's review (Recommendation #2) recommends writing phase summaries as `.context.md` files in `.apm/context/phases/` with proper frontmatter so they are discoverable by `apm compile`.

If knowledge consolidation artifacts live on a git orphan branch, they are not present in the working tree. APM's primitive discovery (`apm/docs/src/content/docs/introduction/key-concepts.md`, lines 86-125) only scans the working tree. APM cannot compile artifacts that exist on a different git branch. The orchestrator would have two separate knowledge stores: one on an orphan branch (readable by gh-aw), one in `.apm/context/` (readable by APM). Keeping them in sync would require custom tooling that neither gh-aw nor APM provides.

**Severity: Dangerous.** Consolidated knowledge must live in the working tree if APM is to compile it. If repo-memory is used for durable CI persistence, a pre-compile step must check out those artifacts into the working tree.


## Tensions

### 1. Recommendation #1 (call-workflow/dispatch-workflow for Tier C) vs. APM's runtime-agnostic dispatch

gh-aw recommends mapping Tier C dispatch to `call-workflow` (synchronous) and `dispatch-workflow` (async). APM's review (Recommendation #1) recommends modeling dispatch payloads as `.prompt.md` files that "automatically integrate with all APM-supported runtimes."

These are not contradictory -- they operate at different layers. APM prompts define *what* an agent should do; gh-aw workflows define *how* and *when* it runs. However, there is tension in the dispatch model: APM's `.prompt.md` files are self-contained artifacts with parameter slots, while gh-aw's `call-workflow` and `dispatch-workflow` expect a markdown workflow file with gh-aw frontmatter (`on:`, `engine:`, `safe-outputs:`). A `.prompt.md` is not a valid gh-aw workflow. The spec would need an adapter layer that wraps APM prompts inside gh-aw workflow frontmatter for CI execution.

This is manageable. APM's gh-aw integration doc (`apm/docs/src/content/docs/integrations/gh-aw.md`, lines 20-73) already describes how gh-aw workflows can declare APM `dependencies:` in frontmatter. The natural pattern is: gh-aw workflow frontmatter handles trigger/engine/deps, the body references the APM prompt. But the spec needs to explicitly acknowledge this adapter pattern rather than treating gh-aw dispatch and APM prompts as equivalent.

### 2. Recommendation #6 (stop-after and concurrency for budget enforcement) vs. APM's compile-time scope model

gh-aw recommends using `stop-after` and `concurrency` groups for the spec's dispatch and duration budgets. APM has no concept of runtime budgets -- it is a build-time tool. APM's compilation engine optimizes context *placement* but has no mechanism for limiting *execution* time or *dispatch* count.

This is not a conflict but a scope tension. If the spec adopts gh-aw's budget enforcement for CI, it must also provide a local equivalent (the spec's `config.json` budgets). The risk is that budget enforcement semantics diverge between local mode (spec-native) and CI mode (gh-aw-native), creating configuration drift. The spec should define a single budget schema that maps to gh-aw primitives in CI and to its own enforcement locally.

### 3. Recommendation #5 (steps/post-steps for verification) vs. APM's hooks system

gh-aw recommends mapping per-task verification to `steps:` / `post-steps:` blocks. APM has its own hooks system (`.apm/hooks/`) that fires on lifecycle events like `PostToolUse` and `Stop` (`apm/docs/src/content/docs/introduction/key-concepts.md`, lines 352-383). The spec also describes its own verification model (must-haves, mechanical checks).

Three verification systems is two too many. If the spec uses gh-aw `post-steps:` for CI and APM hooks for local execution, the verification logic must be duplicated or abstracted. The spec's own per-task verification (lint, test, build commands) is the simplest model -- it should be the single source, invoked by gh-aw `post-steps:` in CI and by the orchestrator's verification step locally. Neither gh-aw's nor APM's hook systems should own the verification logic; they should be invocation mechanisms only.

### 4. Recommendation #10 (expand P7 to full CI integration design) vs. APM's recommendation to keep P8 lightweight

gh-aw wants P7 (GitHub Workflows) expanded into a full CI integration design section. APM's review endorses P8 (APM Packaging) as correctly sequenced at the end, with APM primitives used informally from P1 onward. If P7 becomes a heavy design section with deep gh-aw integration, it risks pulling CI concerns forward into the spec's core architecture -- adding complexity before the orchestrator's core loop is proven.

This is a sequencing tension, not a contradiction. Both tools want their integration addressed, but APM argues for gradual adoption (use primitives early, formalize packaging last) while gh-aw argues for upfront CI architecture. The spec should acknowledge both perspectives: use APM primitives informally from P1 (no spec changes needed), define the gh-aw CI mapping at P7 (requires spec changes), formalize APM packaging at P8.


## Synergies

### 1. gh-aw's isolated mode directly serves APM's clean-context dispatch

gh-aw's recommendation of using `isolated: true` mode for dispatch contexts (referenced indirectly via `call-workflow`) aligns perfectly with APM's recommendation #1 (dispatch payloads as `.prompt.md` with minimal context). APM's gh-aw integration doc (`apm/docs/src/content/docs/integrations/gh-aw.md`, lines 142-156) explicitly describes isolated mode clearing existing `.github/` directories before unpacking APM bundles. This is exactly the "minimal context payload" pattern the spec describes at line 80-82: each dispatch gets only declared dependencies, no instruction pollution from the host repo.

### 2. gh-aw's single-job constraint validates APM's pre-compilation model

gh-aw's "Off-Base Assumptions" section correctly identifies that the single-job execution model prevents multi-phase loops within one workflow run. This constraint actually strengthens APM's position: since each workflow run gets one shot, the context must be pre-compiled and optimized before the agent starts. This is exactly what `apm compile` does. APM bundles (`apm pack`) are designed for sandboxed environments with no network access (`apm/docs/src/content/docs/guides/pack-distribute.md`, lines 247-251) -- they pre-resolve the full dependency tree. The single-job constraint makes APM's compile-then-run model not just useful but necessary.

### 3. gh-aw's campaign pattern complements APM's milestone-as-package model

gh-aw's recommendation #8 (one-phase-per-run campaign model) and APM's recommendation #7 (`apm pack` for milestone snapshots) are naturally complementary. Each campaign run could: (a) unpack the previous milestone's APM bundle for context, (b) execute one phase, (c) pack the updated state as a new bundle. The APM bundle becomes the checkpoint artifact between campaign runs, providing both crash recovery (APM recommendation #7) and cross-run state (gh-aw recommendation #8). This pattern uses both tools at their strengths: APM for context packaging, gh-aw for execution scheduling.

### 4. gh-aw's TaskOps validates APM's tiered primitive strategy

gh-aw's recommendation #9 (reference TaskOps for Tier B CI implementation) maps cleanly onto APM's primitive types. TaskOps Phase 1 (research) maps to APM `.context.md` generation. Phase 2 (planning) maps to APM `.prompt.md` authoring. Phase 3 (execution) maps to APM skill consumption. This alignment means the same APM primitives serve both local Tier B (developer-driven) and CI Tier B (TaskOps-driven), with gh-aw providing the scheduling layer.

### 5. gh-aw's verification via post-steps validates APM's hooks integration pattern

gh-aw's recommendation #5 (map verification to `steps:` / `post-steps:`) and APM's hooks system (`.apm/hooks/`) both solve the same problem: running deterministic checks outside the agent sandbox. While the tension section above notes the duplication risk, the underlying design agreement is a synergy. Both tools agree that verification must be mechanical, must run outside the agent's self-assessment, and must gate progression. The spec can define verification commands once and invoke them through whichever mechanism is available (gh-aw post-steps in CI, APM hooks or direct shell locally).


## Verdict

**Overall: 4 safe, 3 risky (tensions), 3 dangerous.**

Of gh-aw's 10 recommendations:

| # | Recommendation | APM Assessment |
|---|---|---|
| 1 | Map Tier C dispatch to call-workflow + dispatch-workflow | **Tension** -- Compatible at different layers, but needs explicit adapter pattern between APM prompts and gh-aw workflow frontmatter |
| 2 | Adopt cache-memory as CI-mode state persistence | **Dangerous** -- Artifacts in cache-memory are invisible to APM's primitive discovery and compilation engine |
| 3 | Use repo-memory for knowledge consolidation | **Dangerous** -- Orphan-branch storage is invisible to APM's working-tree-only discovery model |
| 4 | Replace PID-based crash recovery with workflow-run-status | **Safe** -- APM has no opinion on crash recovery mechanisms; this is purely a CI concern |
| 5 | Map verification to steps/post-steps | **Tension** -- Risk of duplicating verification logic across gh-aw post-steps, APM hooks, and spec-native checks |
| 6 | Use stop-after and concurrency for budget enforcement | **Tension** -- APM has no runtime budget concept; risk of configuration drift between local and CI budget enforcement |
| 7 | Define status querying via GitHub Projects | **Safe** -- APM has no status querying mechanism; this fills a gap without conflict |
| 8 | Adopt one-phase-per-run model for Tier C CI | **Dangerous** -- Makes APM's pre-authored `.prompt.md` dispatch model unusable; requires dynamically generated payloads per run |
| 9 | Reference TaskOps for Tier B CI implementation | **Safe** -- Maps cleanly onto APM primitive types; validates APM's tiered model |
| 10 | Expand P7 to full CI integration design | **Safe** -- Sequencing tension with APM's gradual-adoption preference, but no architectural conflict |

**The three dangerous contradictions share a root cause:** gh-aw assumes CI-mode state and artifacts should live in gh-aw-managed storage (cache-memory, repo-memory, dynamic workflow state), while APM assumes all agent-consumable context should live in the working tree under `.apm/` or `.github/` directories where APM's discovery and compilation can reach it. The spec must resolve this by designating one canonical storage location and defining explicit sync mechanisms for the other.

**Recommended resolution:** Treat the working tree (`.specify/orchestrator/` and `.apm/context/`) as the canonical state location for both local and CI execution. In CI mode, use gh-aw's `cache-memory` as a *caching/durability* layer that persists the working-tree artifacts across ephemeral runners, not as a *primary* storage location. On each CI run: restore from cache to working tree, execute, write results to working tree, persist working tree back to cache. This preserves APM's discovery model while gaining gh-aw's cross-run persistence.
