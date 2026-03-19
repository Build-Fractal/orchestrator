# spec-kit Iteration 1 Review of gh-aw's Revised Position

## What Changed (gh-aw: original -> revised)

gh-aw withdrew zero recommendations, modified five (Recs 1, 2, 3, 5, 6), and stood by five (Recs 4, 7, 8, 9, 10). The modifications all follow a single structural correction: gh-aw primitives should serve as CI execution and durability mechanisms, not as canonical storage or state locations. The working tree is now acknowledged as canonical.

Specific changes:

- **Rec 1 (dispatch)**: Originally proposed `call-workflow`/`dispatch-workflow` as *the* Tier C dispatch primitives. Now positions them as the CI-mode implementation of an abstract dispatch interface. Accepts spec-kit's runtime-agnostic framing.
- **Rec 2 (cache-memory)**: Originally proposed `cache-memory` as the CI-mode state persistence layer, replacing on-disk artifacts. Now repositions `cache-memory` as a durability layer that restores/persists the working tree across ephemeral runners: restore -> execute -> persist. Canonical state remains in `.specify/extensions/orchestrator/` on disk.
- **Rec 3 (repo-memory)**: Originally proposed `repo-memory` on an orphan branch as the primary location for knowledge consolidation. Now positions it as a secondary backup mechanism. Primary location is the working tree at `.specify/extensions/orchestrator/consolidated/`.
- **Rec 5 (verification)**: Originally proposed `post-steps:` as the verification mechanism. Now accepts that the spec owns verification commands and `post-steps:` is the CI adapter that invokes them.
- **Rec 6 (budgets)**: Originally proposed mapping budgets to gh-aw frontmatter (`stop-after`, `concurrency`). Now accepts spec-kit's config as the single source of truth, with gh-aw frontmatter populated by mechanical translation at compile time.

gh-aw also stood firm on **Rec 8 (one-phase-per-run)**, which was the most contested recommendation, while accepting that its original implementation details (state in `cache-memory`, no session continuity) were wrong.

## Contradictions Resolved

### DC-1 (cache-memory as state persistence) -- GENUINELY RESOLVED

This was the most dangerous contradiction in the original review. gh-aw's original Rec 2 proposed moving `.specify/orchestrator/` artifacts into `cache-memory` as structured JSON files, which would have made all orchestrator state invisible to spec-kit's template resolution, config layering, and extension introspection.

The revision is substantive, not cosmetic. gh-aw now explicitly states: "The `.specify/extensions/orchestrator/` directory (per spec-kit's extension convention) is the canonical state location in both local and CI modes." The `cache-memory` role is narrowed to a transport mechanism: restore working tree at run start, persist working tree at run end. This preserves spec-kit's disk-state-as-truth invariant because the agent always reads and writes to the working tree during execution, never to cache directly.

This is a genuine architectural concession. gh-aw moved from "cache-memory is the CI storage layer" to "the working tree is the storage layer and cache-memory is the persistence transport." The distinction matters: spec-kit's resolution machinery operates on the working tree, so as long as state is in the working tree during execution, spec-kit's contracts are preserved regardless of what mechanism persists that tree across runs.

**Verdict: Resolved.** gh-aw accepted spec-kit's core constraint and restructured its recommendation accordingly.

### DC-3 (repo-memory for knowledge consolidation) -- GENUINELY RESOLVED

gh-aw's original Rec 3 proposed storing compressed milestone summaries on an orphan branch via `repo-memory`, making them invisible to `specify extension list`, `specify extension info`, and the orchestrator's own dispatch loop. The revision accepts that knowledge consolidation must produce files in the working tree (`.specify/extensions/orchestrator/consolidated/`) and that `repo-memory` is only a disaster recovery backup.

The key concession: "Any knowledge in `repo-memory` must be checked out into the working tree before APM compilation or spec-kit template resolution operates on it." This is the right framing. It means `repo-memory` never serves as a primary read path for any tool -- it is a write-behind backup that requires explicit checkout before use.

**Verdict: Resolved.** gh-aw accepted the working-tree-first principle for knowledge consolidation.

## Contradictions Unresolved

### DC-2 (one-phase-per-run model) -- PARTIALLY RESOLVED, CORE TENSION REMAINS

This was flagged as dangerous because it breaks spec-kit hook execution (hooks fire within a session context), extension command registration (must be reinstalled on ephemeral runners each run), and template resolution (depends on installed presets and extensions).

gh-aw's revision addresses the implementation details -- state now lives in the working tree via the corrected Rec 2 pattern, and the revision acknowledges that "spec-kit extensions are installed/verified at the start of each run." However, gh-aw stands firm on the scheduling model itself: each CI run advances one phase, then exits.

The revision did not fully address the session continuity problem. Here is why.

**Hook execution context.** Spec-kit's `HookExecutor` loads project config from `.specify/extensions.yml`, resolves hooks against the local registry, and fires them within a session where the agent has built up command context (it knows what phase it is in, what tasks preceded, what verification results look like). In a one-phase-per-run model, each run is a cold start. The agent loads the extension, reads the restored working tree, and must reconstruct session context from disk artifacts alone. This is *possible* (the orchestrator's disk-state-as-truth design supports it), but it means hooks fire in an environment where the agent's conversational context is empty -- the hook has no access to the reasoning or intermediate state that led to the current phase. For hooks that merely run shell commands (lint, test), this is fine. For hooks that depend on the agent understanding *why* it is at a particular point, this is a degradation.

**Extension installation cost.** gh-aw acknowledges that extensions must be installed/verified at the start of each run. But the revision does not quantify or bound this cost. If `specify extension add orchestrator` involves downloading from a catalog, resolving dependencies, registering commands into agent directories, and validating `requires.commands` -- that is nontrivial setup time on every single CI run. The `cache-memory` restoration helps (the extension files are in the cached working tree), but the question is whether cache restoration alone is sufficient or whether the extension's install-time registration logic must re-execute. This is an unresolved implementation question that could make the one-phase-per-run model unacceptably slow.

**The fundamental tension.** gh-aw correctly identifies that the single-job execution model is a hard platform constraint. The spec's multi-phase dispatch loop genuinely cannot run as a single agentic workflow. This is not disputed. But the one-phase-per-run model is not the *only* alternative. gh-aw presents it as the only viable architecture, but the spec could also:

- Use a traditional GitHub Actions workflow (not an agentic workflow) with matrix jobs and step dependencies for multi-phase execution
- Use a single agentic workflow that dispatches to a traditional workflow for the multi-phase loop
- Use the orchestrator's own dispatch mechanism to chain runs via `workflow_dispatch` with explicit state handoff

gh-aw's campaign pattern (one-phase-per-run with scheduled triggers) is a *valid* architecture, but presenting it as the *only* architecture forecloses design space that the spec should keep open.

**Verdict: Partially resolved.** The implementation details (state storage, extension installation) are corrected. The scheduling model itself is defensible but presented as more inevitable than it is. The session continuity problem for non-trivial hooks is acknowledged but not solved.

## New Concerns

### NC-1: The revised Rec 2 creates a cache-coherency obligation that is not specified

The revised `cache-memory` pattern (restore -> execute -> persist) introduces a cache-coherency problem that the original recommendation did not have (because the original simply used cache as primary storage). If a CI run fails mid-execution after writing partial results to the working tree, the next run restores the pre-failure state from cache (because the persist step never ran). This means the partial work from the failed run is lost -- which is the correct behavior for crash recovery.

But what if the CI run succeeds in its work but fails during the persist-to-cache step? Now the working tree had correct state, the cache has stale state, and the next run restores stale state. gh-aw's revision does not address this edge case. The orchestrator's existing crash recovery model (lock files, recovery briefings) handles local crashes, but cache-persist failures are a new failure mode that exists only in the CI path.

This is not a dealbreaker, but the expanded P7 section should document the cache-coherency contract: what happens when restore fails, what happens when persist fails, whether the orchestrator should verify cache freshness before starting work.

### NC-2: The revised Rec 8 claims the orchestrator "selects which pre-authored prompt to execute" but this conflates orchestrator logic with dispatch logic

gh-aw's revised Rec 8 states: "The orchestrator reads state, determines the current phase, selects the corresponding `.prompt.md`, and executes it. The prompts themselves remain static templates."

This description embeds orchestrator logic (phase state reading, prompt selection) into what gh-aw previously called the "single agentic workflow." But if the workflow is an agentic workflow (an LLM agent runs once and exits), who is performing the "read state, determine phase, select prompt" logic? The agent itself? A `steps:` block before the agent runs? A separate non-agentic workflow that triggers the agentic one?

The revised recommendation blurs the line between orchestration logic and agent execution logic. In the local case, the orchestrator *is* the agent (or at least, the agent executes the orchestrator's commands). In the CI case, there needs to be a clear separation: something non-agentic reads state and decides what to run, then an agentic workflow executes that specific unit of work. This separation is implied but never made explicit.

## Hard Stances (Non-Negotiable from spec-kit's Perspective)

### HS-1: The working tree is the canonical state location in all execution modes

This is spec-kit's foundational architectural invariant. All extension state, configuration, templates, and artifacts must be readable from the working tree via spec-kit's standard resolution machinery. Any CI persistence mechanism (cache-memory, repo-memory, artifact upload) is a transport layer that moves the working tree between runs. During execution, the agent reads from and writes to the working tree, never to a CI-specific storage layer.

gh-aw's revised position now agrees with this. This is documented here as a hard stance to prevent regression in future iterations.

### HS-2: spec-kit hooks are the canonical verification mechanism; CI adapters invoke them, not replace them

The spec should define verification as spec-kit hooks. When running in CI via gh-aw, those hooks can be *additionally* wired into `post-steps:` for guaranteed deterministic execution. But the hooks must exist and function correctly in the absence of gh-aw. A developer using Cursor or Windsurf must get the same verification behavior as one running in CI.

gh-aw's revised Rec 5 now agrees with this framing. This is documented here because the original recommendation would have made verification gh-aw-specific, and the temptation to optimize for CI at the expense of local parity will recur.

### HS-3: Configuration authority flows from the spec's own config system, not from CI infrastructure

Budget definitions, verification commands, dispatch caps, and concurrency limits are defined in the orchestrator's configuration file (format TBD, but consumed through spec-kit's config resolution where available). CI infrastructure (gh-aw frontmatter, GitHub Actions secrets, environment variables) consumes these values via mechanical translation. The spec's config is authoritative; CI config is derived.

gh-aw's revised Rec 6 now agrees. This is documented because configuration drift between local and CI modes is an ongoing risk.

### HS-4: The orchestrator must remain agent-runtime-agnostic

The orchestrator is a spec-kit extension. Spec-kit supports 25+ agent runtimes. The orchestrator must work with all of them without agent-specific code paths (spec line 234). gh-aw's `call-workflow`, `dispatch-workflow`, `cache-memory`, and `post-steps:` are gh-aw-specific primitives. They are valid CI-mode implementations behind an abstract interface, but the orchestrator's command layer must not assume or require them.

gh-aw's revised Rec 1 now frames `call-workflow`/`dispatch-workflow` as a CI backend rather than a primary dispatch mechanism. This is the correct layering.

## Possible Compromises

### PC-1: Accept the one-phase-per-run campaign pattern as the *recommended* (not sole) CI architecture

Spec-kit's objection to Rec 8 was about the implementation details (broken hooks, no session continuity, state in cache) more than the scheduling model itself. With the implementation details corrected (state in working tree, extensions installed per run), the campaign pattern is a viable CI architecture. Spec-kit could accept it as the recommended approach in the expanded P7 section, provided:

- The P7 section documents it as one viable pattern among others (not the only option)
- The session continuity limitations for non-trivial hooks are documented explicitly
- The extension installation cost per run is benchmarked and bounded
- Alternative architectures (traditional workflow with matrix jobs, chained `workflow_dispatch`) are mentioned as escape hatches

### PC-2: Accept `.specify/orchestrator/` as the state directory instead of `.specify/extensions/orchestrator/`

In spec-kit's own iteration 1 revision, Rec 3 (move state to `.specify/extensions/orchestrator/`) was withdrawn because both gh-aw and APM objected to scattering state across spec-kit's extension directory hierarchy. gh-aw's position that the spec's original single-directory approach (`.specify/orchestrator/`) is better for CI caching is well-argued. Spec-kit can accept `.specify/orchestrator/` as the canonical location, acknowledging that the extension convention (`.specify/extensions/{id}/`) was designed for extensions whose state is only consumed through spec-kit's own resolution -- the orchestrator's state has a wider audience.

This is not a concession that costs spec-kit anything material. The `specify extension list` and `specify extension info` commands can be taught to discover orchestrator state at `.specify/orchestrator/` via the extension manifest, even if the path does not follow the default convention. The convention exists to serve discoverability; if discoverability can be achieved by other means, the convention is not load-bearing.

### PC-3: Collaborate on the expanded P7 section as a joint deliverable

gh-aw's Rec 10 (expand P7 to a full CI integration design) was unanimously endorsed by all reviewers. The expanded section needs to address spec-kit extension installation on ephemeral runners, hook execution in cold-start environments, cache-coherency contracts, and the abstract dispatch interface. This is inherently cross-cutting work that benefits from both spec-kit's knowledge of extension lifecycle and gh-aw's knowledge of CI execution constraints.

Spec-kit should contribute the spec-kit-specific requirements (extension install sequence, hook execution prerequisites, config resolution in CI) and gh-aw should contribute the CI-specific architecture (campaign pattern, cache lifecycle, workflow topology). Neither tool can write this section alone without the other's domain expertise.
