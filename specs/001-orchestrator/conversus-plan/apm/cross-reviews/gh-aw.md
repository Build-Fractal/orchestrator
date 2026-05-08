# APM Cross-Review of gh-aw's Review

**Cross-reviewer**: APM (Agent Package Manager)
**Reviewing**: gh-aw review of speckit-orchestrator implementation plan
**Date**: 2026-03-19

---

## Dangerous Contradictions

### DC-1: APM Scripts as CI Entry Points vs. gh-aw's Precomputation Steps

gh-aw recommends running `derive-phase.sh` as an `on.steps:` deterministic precomputation step (gh-aw Recommendation 5), feeding its output as a job output that gates the agent invocation. APM recommends registering the same script as an APM script (`apm run status`) to provide a CI-friendly entry point (APM Recommendation 7). These two recommendations produce a direct conflict at the gh-aw adapter layer: if the CI workflow invokes `derive-phase.sh` via `apm run status`, it introduces an APM CLI dependency on the CI runner, violating the plan's "no APM runtime dependencies" constraint and adding installation overhead to every ephemeral runner. If the workflow invokes the script directly as an `on.steps:` precomputation, the APM script registration becomes dead weight in CI -- the named entry point is never used where it matters most. The resolution must be explicit: APM scripts are the local/interactive invocation path, gh-aw `on.steps:` is the CI invocation path, and both must invoke the same underlying script by path. Neither review states this dual-path contract, risking implementations that depend on only one invocation model.

### DC-2: APM Compilation for Dispatch Payloads vs. gh-aw's Fixed-Prompt-at-Dispatch Model

APM recommends using `apm compile` for constitution injection and scope-filtered context assembly during dispatch payload construction (APM Missed Opportunities 1, 2; Recommendations 4, 5). gh-aw's review reveals that once a gh-aw workflow is dispatched, the markdown prompt is fixed -- there is no mid-execution context injection (gh-aw Off-Base Assumption 2). This creates a dangerous sequencing constraint that neither review fully articulates: APM compilation must run *before* dispatch, producing a complete, self-contained prompt that includes all constitution, instructions, and scoped knowledge. But APM compilation is designed as an install-time or pre-commit operation, not a per-dispatch operation. Running `apm compile` on every task dispatch (potentially 70+ times per milestone) introduces latency and requires the APM CLI on the dispatch host. If the orchestrator uses APM compilation for payload assembly, the gh-aw adapter must either pre-compile all possible dispatch variants at install time (combinatorial explosion) or accept APM CLI as a dispatch-time dependency (contradicting the no-runtime-dependency constraint). This contradiction means one of the two approaches must yield: either dispatch payloads are assembled by custom scripts (as the plan proposes) with APM compilation limited to install-time CLAUDE.md generation, or the plan must redefine APM compilation as a dispatch-time operation and accept the dependency.

### DC-3: Lock File Design -- Two Incompatible Liveness Models

gh-aw correctly identifies that PID-based lock detection is meaningless on ephemeral CI runners and recommends replacing it with `github.run_id` + API status checks (gh-aw Off-Base Assumption 1, Recommendation 2). APM's review does not address the lock file at all, implicitly accepting the plan's PID-based model as sufficient. The danger is that the lock file schema (data-model.md lines 237-249) is a single structure that must serve both local and CI contexts. If the gh-aw adapter stores `run_id` where the local adapter stores `pid`, the `derive-phase.sh` script -- which both reviews agree is the state derivation entry point -- must branch on adapter type to interpret the lock file. Neither review proposes a polymorphic lock schema or an adapter-specific liveness-check interface. Without this, the lock file becomes a silent correctness hazard: local runs checking `run_id` as if it were a PID (always "dead," always recovering), or CI runs checking `pid` on an ephemeral runner (always stale, always recovering). The adapter interface must define a `check_liveness(lock_data) -> bool` operation that each adapter implements, and the lock schema must include an `adapter_type` discriminator field.

---

## Tensions

### T-1: Depth of APM Integration vs. Minimal Dependency Surface

APM's review pushes for deeper integration: compilation for constitution injection, `.instructions.md` for scope filtering, context linking for knowledge artifacts, hooks for verification, scripts for CI entry points. gh-aw's review independently pushes for deeper gh-aw integration: repo-memory for persistence, staged mode for verification, deterministic steps for state derivation, concurrency discriminators for fan-out, protected-files configuration. The plan explicitly constrains itself to "no GSD-2 or APM runtime dependencies" and positions itself as a spec-kit extension first. Both reviews are independently correct in their recommendations, but the cumulative effect of adopting both would make the orchestrator deeply coupled to two external systems' feature sets, potentially creating an integration surface larger than the orchestrator's own logic. The tension is not that either review is wrong, but that the plan needs an explicit integration budget -- how many external-system concepts can the orchestrator absorb before it becomes a thin wrapper around APM + gh-aw rather than an independent extension?

### T-2: Static Install-Time Assets (APM) vs. Dynamic Runtime State (gh-aw)

APM's core argument is that its primitives are install-time artifacts: instructions, skills, context files, and compiled output are all static files on disk after `apm install` (APM Off-Base Assumption 3). gh-aw's core argument is that the orchestrator's CI environment is ephemeral and state must be actively persisted across runs via repo-memory or cache-memory (gh-aw Missed Opportunity 5, Recommendation 3). These two worldviews create a tension around the orchestrator's knowledge artifacts. APM wants KNOWLEDGE.md and DECISIONS.md formatted as `.context.md` files with link resolution (APM Missed Opportunity 3). gh-aw needs these same files committed to a `memory/orchestrator` branch for cross-run persistence (gh-aw Recommendation 3). The file format and storage location serve different masters: APM's context linking needs files in the working tree at predictable paths; gh-aw's repo-memory needs files on a separate branch. The orchestrator must decide whether knowledge artifacts live in the working tree (APM-friendly, local-first) or on repo-memory branches (gh-aw-friendly, CI-first), and the non-primary path must have an explicit sync mechanism.

### T-3: APM's SKILL.md Requirement vs. gh-aw's Workflow Discoverability

APM flags that SKILL.md derivation from command frontmatter does not exist and demands an explicit `SKILL.md` for agent discoverability (APM Off-Base Assumption 1, Recommendation 2). gh-aw's review does not mention SKILL.md at all -- in gh-aw's world, discoverability is achieved through workflow files in `.github/workflows/` with descriptive frontmatter, not through a separate skill manifest. This tension matters because the orchestrator targets multiple agents: Claude Code discovers capabilities via SKILL.md (APM's model), while gh-aw workflows discover capabilities via workflow frontmatter and `gh aw list` (gh-aw's model). The plan's AD-6 resolution ("command frontmatter is the single source of truth, APM derives SKILL.md") attempted to bridge both models but, as APM correctly notes, the derivation mechanism does not exist. The orchestrator needs two separate discoverability paths -- SKILL.md for IDE agents and workflow frontmatter for CI agents -- and must maintain them in sync.

### T-4: Verification Pipeline Ownership

APM suggests supplementary `PostToolUse` hooks for per-file-write verification (APM Recommendation 9). gh-aw suggests staged mode for verification dry runs in CI (gh-aw Recommendation 9). The plan uses spec-kit hooks at 4 lifecycle points (research.md R-010). All three approaches target verification at different granularities (per-write, per-dispatch-preview, per-phase), but none of the reviews or the plan establishes a clear ownership model for the verification pipeline. If all three mechanisms are active simultaneously, a single file write could trigger: (1) an APM `PostToolUse` hook, (2) a spec-kit `after-task` hook, and (3) a gh-aw staged-mode preview on the next dispatch. The tension is not feature conflict but governance: which verification layer has authority to block progress, which is advisory, and what happens when they disagree?

### T-5: Budget Enforcement -- Advisory vs. Hard Limits

APM's review does not address budget enforcement at all, implicitly accepting the plan's advisory model. gh-aw explicitly recommends mapping `dispatch_budget` and `duration_budget` to hard CI limits: `timeout-minutes` and `stop-after` (gh-aw Recommendation 10). This creates a tension between local and CI execution models. Locally, budgets are advisory because the human operator can override them. In CI, gh-aw can enforce them mechanically through workflow timeouts. If the orchestrator treats budgets as advisory everywhere, CI runs can exhaust GitHub Actions minutes without guardrails. If the orchestrator enforces them as hard limits everywhere, local development loses the flexibility to exceed budgets when the human decides it is warranted. The plan needs an explicit `budget_enforcement` config field: `advisory` (local default) vs. `enforced` (CI default), with the adapter responsible for the enforcement mechanism.

---

## Safe Agreements

### SA-1: Disk-State-is-Truth is Architecturally Sound

Both reviews independently validate the plan's AD-2 principle. APM confirms that the deployment boundary separation (`.specify/extensions/orchestrator/` vs. `.specify/orchestrator/`) correctly accounts for APM's always-overwrite semantics (APM Alignment, first bullet). gh-aw confirms that the `.specify/orchestrator/` state tree maps naturally to repo-memory branches for CI persistence (gh-aw Alignment, first bullet). The file-based state machine is the correct foundational choice -- it satisfies APM's install-time overwrite model (state is never in the blast radius), gh-aw's persistence model (files can be committed to repo-memory branches), and spec-kit's file-oriented extension model. No design change needed; both reviews agree the plan is correct here.

### SA-2: The Adapter Interface is the Correct Abstraction Boundary

Both reviews accept AD-3 (Runtime Adapter Interface) as the right integration strategy and focus their criticism on its *underspecification* rather than its existence. APM's review implicitly validates the adapter by recommending APM scripts as the local adapter's CI-friendly entry point (APM Recommendation 7). gh-aw's review explicitly validates the adapter by providing concrete specifications for what the gh-aw adapter must implement (gh-aw Recommendations 1-4, 6-8). The agreement is: the adapter interface is the correct place to absorb the differences between local execution and CI execution. The disagreements are about what operations belong in the interface and how specific adapters implement them -- which is exactly the kind of detail the adapter abstraction is designed to encapsulate.

### SA-3: The Plan Underspecifies the `apm.yml` Manifest

APM flags that `apm.yml` is listed as a deliverable but has no concrete schema (APM Recommendation 1). gh-aw does not address `apm.yml` directly but its recommendations for the gh-aw adapter contract (dispatch mode, concurrency config, repo-memory config, protected-files config) all represent configuration that belongs in a manifest-level specification. Both reviews agree, from different angles, that the plan's treatment of distribution and configuration metadata is insufficient -- APM because the manifest is literally empty, gh-aw because the adapter configuration has no home. The manifest must be fleshed out to serve both as APM's distribution contract and as the adapter configuration surface.
