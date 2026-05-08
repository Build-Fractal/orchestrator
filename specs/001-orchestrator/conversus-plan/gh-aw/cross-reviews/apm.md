# gh-aw Cross-Review of APM's Review

**Cross-reviewer**: gh-aw (GitHub Agentic Workflows)
**Reviewing**: APM's review of speckit-orchestrator implementation plan
**Date**: 2026-03-19

---

## Dangerous Contradictions

### DC-1: APM compilation as dispatch payload builder vs. gh-aw's fixed-prompt-at-start constraint

APM recommends using `apm compile` for constitution injection and scope-filtered context assembly (Missed Opportunities 1-2, Recommendations 4-5), positioning APM's compilation engine as the mechanism for constructing the orchestrator's dispatch payloads. gh-aw's review identifies that once a workflow is running, the markdown prompt is fixed -- context cannot be injected mid-execution (Off-Base Assumption 2). These two positions create a dangerous design trap: if the orchestrator adopts APM compilation as its context assembly layer, it must run `apm compile` **before** each gh-aw dispatch (producing a static prompt), not as a runtime context-injection mechanism. Neither review makes this sequencing constraint explicit. If implementers read APM's recommendation as "let APM handle context dynamically" and gh-aw's constraint as "prompts are fixed at start," they will build an adapter that attempts compile-then-inject at a point where injection is impossible. The resolution must specify that APM compilation is a **pre-dispatch step** in the gh-aw adapter, producing a fully-resolved prompt that is passed as the workflow's markdown body at dispatch time.

### DC-2: APM `.instructions.md` as scope-filter replacement vs. gh-aw's per-dispatch prompt model

APM's Recommendation 4 proposes replacing the orchestrator's custom `scope-filter.sh` with APM `.instructions.md` files that use `applyTo` glob patterns, arguing that the AI agent's native instruction loading handles scope filtering automatically. gh-aw's review (Missed Opportunity 2) identifies that the gh-aw adapter dispatches tasks as individual workflow runs, each with a self-contained markdown prompt. APM instructions deployed to `.github/instructions/` are loaded by the agent at session start -- but in gh-aw, each dispatched task is a **separate agent session** on an ephemeral runner. Unless the runner checks out the repo with APM-deployed instructions already in place, the instructions do not exist on the runner's filesystem. This means APM's "no runtime dependency" claim (Off-Base Assumption 3) is technically correct for long-lived local sessions but **breaks down in CI** where each run starts from a clean checkout. The orchestrator would need to either: (a) ensure APM instructions are committed to the repo (not just locally deployed), or (b) inline the scoped context into each dispatch payload, which is exactly what `scope-filter.sh` already does. Adopting APM instructions as the primary scoping mechanism while running on gh-aw could silently produce context-free task dispatches.

### DC-3: APM lockfile reproducibility vs. gh-aw's ephemeral runner reality

APM's Recommendation 3 (P1) insists on committing `apm.lock.yaml` for reproducible installations, arguing that without it teams get "non-reproducible orchestrator versions." gh-aw's review (Missed Opportunity 5, Recommendation 3) identifies that gh-aw runners are ephemeral -- each run gets a fresh filesystem with no prior state. These positions collide on a practical question neither review addresses: **who runs `apm install` in CI?** If the gh-aw adapter expects the orchestrator extension to be pre-installed (committed to the repo), then `apm.lock.yaml` is relevant only for the initial setup and the lockfile concern is overstated for CI. If the adapter runs `apm install` on every dispatch to ensure the correct version, then APM becomes a CI runtime dependency -- directly contradicting APM's own assertion that "APM never enters the execution path" (Off-Base Assumption 3). The plan must resolve whether the orchestrator extension is a committed artifact (lockfile pins the setup but APM is not needed in CI) or a CI-installed dependency (APM is a CI runtime dependency despite claims otherwise).

### DC-4: APM hooks for post-write verification vs. gh-aw's safe-outputs model

APM's Recommendation 9 suggests registering `PostToolUse` hooks on `write_file` events to trigger verification checks after each file write, providing "defense-in-depth" verification. gh-aw's review (Missed Opportunity 7, Recommendation 8) identifies that gh-aw enforces a `protected-files` policy where writes to certain paths are blocked by default, and that safe-outputs gate what the agent can create (PRs, issues, etc.). These two verification models conflict: APM hooks fire **after** a write succeeds and run arbitrary scripts, while gh-aw's protected-files policy **prevents** writes from succeeding in the first place. If both are active, an APM `PostToolUse` hook could attempt to verify a file that gh-aw's safe-output policy already blocked, producing confusing error cascades. Worse, if the hook itself tries to write a verification result to a protected path, it triggers a second block. The adapter must define a clear precedence: gh-aw's safe-outputs gate what can be written, and any APM hook verification runs only on writes that gh-aw already permitted.

---

## Tensions

### T-1: APM's "use our compilation engine" vs. gh-aw's "minimize pre-dispatch complexity"

APM advocates for the orchestrator to adopt APM compilation for constitution injection (Recommendation 5), scope-filtered instructions (Recommendation 4), and context linking (Recommendation 10) -- each adding a compilation step to the dispatch pipeline. gh-aw's review emphasizes minimizing the pre-dispatch path: deterministic precomputation steps should be lightweight shell scripts (Recommendation 5), state derivation should avoid AI engine invocations (Missed Opportunity 4), and the dispatch loop should re-enter quickly via scheduled triggers (Recommendation 7). Adding `apm compile` to the pre-dispatch pipeline introduces a dependency on APM's compilation engine (Python, node resolution, context linking), increasing the time and complexity of each dispatch cycle. This is not a contradiction -- both approaches work -- but the tension is real: every second added to the dispatch loop multiplies across 70+ task dispatches in a full milestone. The adapter should benchmark `apm compile` latency vs. the custom bash scripts it replaces.

### T-2: APM's manifest-centric discoverability vs. gh-aw's workflow-centric discoverability

APM wants the orchestrator to be discoverable via `SKILL.md` (Recommendation 2), `apm.yml` scripts (Recommendation 7), and `.instructions.md` files (Recommendation 4) -- all file-based primitives that agents discover through APM's package ecosystem. gh-aw wants the orchestrator to be discoverable as workflow definitions: dispatch triggers, scheduled re-entry loops, precomputation steps, and safe-output configurations. These are parallel discoverability surfaces that do not conflict but create a maintenance burden: every orchestrator capability must be declared in both APM's manifest world and gh-aw's workflow frontmatter world. Neither review proposes a single-source-of-truth for capability declaration.

### T-3: "No APM runtime dependency" framing vs. gh-aw's compile requirement

APM's Off-Base Assumption 3 argues that stating "no APM runtime dependency" is moot because APM is install-time only. gh-aw's Missed Opportunity 3 notes that gh-aw itself has a similar install-time-only concern: frontmatter changes require `gh aw compile`. Both tools claim to be "not runtime dependencies" but both impose pre-execution steps that must happen somewhere in the pipeline. The tension is that the orchestrator plan treats both as pure distribution mechanisms, but both actually require build steps (APM compile, gh-aw compile) that must be wired into the development and CI workflow. The plan should acknowledge that "no runtime dependency" does not mean "no build-time dependency" and document when each compilation must run.

### T-4: APM's `apm run <script>` for CI entry points vs. gh-aw's native `on.steps:` precomputation

APM's Recommendation 7 proposes registering orchestrator operations as APM scripts (`apm run verify`, `apm run status`), specifically arguing this is "especially relevant for the gh-aw CI adapter which needs non-interactive invocation." gh-aw's Recommendation 5 proposes running the same operations as `on.steps:` precomputation steps -- shell commands executed directly as workflow steps, not through any package manager. Both achieve non-interactive invocation, but through fundamentally different mechanisms: `apm run` requires APM to be installed on the runner; `on.steps:` requires only bash. For CI, gh-aw's approach has fewer dependencies and faster execution. For local development, APM's approach provides better discoverability. The adapter should use `on.steps:` in CI and let APM scripts serve as the local development interface.

### T-5: Scope of "state persistence" across the two reviews

APM focuses on state as **package version state** -- lockfiles, manifests, deterministic installations. gh-aw focuses on state as **runtime execution state** -- lock files, execution logs, phase/milestone progress across ephemeral runners. Both use the word "state" and both care about persistence, but they are talking about fundamentally different state lifecycles. APM state changes infrequently (on install/upgrade) and is committed to the repo. gh-aw state changes on every dispatch cycle and must survive across ephemeral runners via repo-memory branches. The plan conflates these under the single `.specify/orchestrator/` directory. A cleaner separation would distinguish APM-managed extension files (versioned, lockfile-pinned) from gh-aw-managed execution state (append-only, repo-memory-persisted).

---

## Safe Agreements

### SA-1: The deployment boundary separation is correct and non-negotiable

Both reviews agree that the strict separation between `.specify/extensions/orchestrator/` (APM-managed, overwritable) and `.specify/orchestrator/` (runtime state, never touched by install) is the correct architectural decision. APM identifies this as "the single most important APM concern" (Alignment, Deployment Boundary). gh-aw's review builds on this by mapping `.specify/orchestrator/` to repo-memory persistence (Alignment, AD-2). Neither review challenges or qualifies this boundary. It is the foundational invariant both tools depend on.

### SA-2: The 5-operation adapter interface needs concrete per-adapter capability declarations

APM does not review the adapter interface in detail but implicitly accepts it by focusing on distribution concerns. gh-aw's review identifies that `inject-context` is not implementable in gh-aw (Off-Base Assumption 2) and that the dispatch mode (async vs. sync) must be specified per-adapter (Missed Opportunity 2, Recommendation 1). APM's Recommendation 2 (SKILL.md) and gh-aw's Recommendation 6 (`inject-context: false`) both point to the same principle: each adapter must declare its actual capabilities honestly, and the orchestrator must degrade gracefully when a capability is absent. The capability declaration model itself is sound; only the per-adapter specifics are missing.

### SA-3: The orchestrator underspecifies its distribution and deployment contract

APM identifies that `apm.yml` is listed as a deliverable but has no concrete content (Recommendation 1, P1). gh-aw identifies that the adapter's workflow compilation requirement, dispatch mode, and persistence configuration are all unspecified (Missed Opportunities 2-3, Recommendations 1-3). Both reviews converge on the same meta-finding: the plan describes the orchestrator's runtime behavior in detail but leaves its packaging, distribution, and deployment contracts as placeholders. This is a shared P1 gap that blocks both APM installation and gh-aw CI integration.

### SA-4: Mechanical verification should leverage each tool's native enforcement rather than custom scripts alone

APM proposes using compilation-based constitution drift detection (Missed Opportunity 1) and PostToolUse hooks (Recommendation 9) as verification supplements. gh-aw proposes staged mode for verification dry runs (Recommendation 9) and protected-files enforcement (Recommendation 8) as verification supplements. Both reviews agree that the orchestrator's custom bash verification scripts (check-must-haves.sh, etc.) are necessary but not sufficient, and that each runtime adapter should wire into its platform's native verification mechanisms. The specific mechanisms differ by platform, but the principle -- layer platform-native enforcement on top of the orchestrator's own verification -- is shared.
