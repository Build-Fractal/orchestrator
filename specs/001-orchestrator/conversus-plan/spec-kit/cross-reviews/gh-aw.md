# Cross-Review: spec-kit reviewing gh-aw's review

**Cross-reviewer**: spec-kit (extension system, commands, hooks, templates, configuration)
**Reviewing**: gh-aw's review of the speckit-orchestrator implementation plan
**Date**: 2026-03-19

---

## Dangerous Contradictions

### DC-1: State persistence location -- disk paths vs repo-memory branches

gh-aw recommends mapping `.specify/orchestrator/` state files to a `repo-memory` branch (`memory/orchestrator` branch with specific file-globs, gh-aw rec #3). spec-kit's entire extension model assumes `.specify/orchestrator/` is a local filesystem directory that commands read and write directly -- every spec-kit command template resolves paths relative to the working tree, and the hook system passes local file paths to hook handlers.

If the gh-aw adapter persists state to a git branch instead of the working tree, then spec-kit hooks firing `after_tasks` or `after_implement` will find stale or empty state at `.specify/orchestrator/` because the canonical state lives on a different branch. Conversely, if state is kept in the working tree for spec-kit's benefit, the repo-memory sync becomes a mirror rather than the source of truth, violating gh-aw's recommendation that repo-memory IS the persistence layer.

**Resolution required**: The plan must define a single source-of-truth rule. Either (a) the working tree is always canonical and repo-memory is a durability sync performed by the adapter after local writes, or (b) repo-memory is canonical and the adapter hydrates the working tree before each run. Option (a) preserves spec-kit's filesystem assumptions. Option (b) breaks them. This must be decided before implementation or the two systems will corrupt each other's view of orchestrator state.

### DC-2: Verification architecture -- checklist system vs staged mode vs precomputation steps

spec-kit's review (rec #7) recommends connecting phase must-haves to spec-kit's existing checklist system, where `/speckit.implement` gates on checklist completion before proceeding. gh-aw's review recommends two separate verification mechanisms: staged mode for dry-run previews of safe outputs (gh-aw rec #9) and deterministic `on.steps:` precomputation for state derivation (gh-aw rec #5).

These are three distinct verification mechanisms targeting the same verification ladder (R-006). If all three are implemented, the orchestrator has: (1) checklist files that must pass before `/speckit.implement` runs, (2) a staged-mode preview that shows what CI would produce without executing, and (3) a shell-script precomputation step that derives state before the agent is invoked. The ordering and authority relationships are undefined. Does a passing checklist override a failing staged preview? Does the precomputation step check checklist status or operate independently? Can a human-tier verification (R-006) be satisfied by staged mode alone?

**Resolution required**: The verification ladder must assign each tier to exactly one mechanism. Proposal: static checks (tier 1) = precomputation step; command checks (tier 2) = checklist system; behavioral checks (tier 3) = staged mode; human checks (tier 4) = manual review. Without this mapping, implementers will build overlapping systems that produce contradictory pass/fail signals.

### DC-3: Config file placement -- project root vs extension directory vs repo-memory

spec-kit's review (rec #3) says `orchestrator-config.yml` must move from the project root to `.specify/extensions/orchestrator/orchestrator-config.yml` to follow spec-kit's convention. gh-aw's review (rec #3) says orchestrator state (which includes config-derived runtime state) should be persisted to a `repo-memory` branch. The original plan places config at the project root.

Three locations, three reviews, three answers. If config lives in `.specify/extensions/orchestrator/`, gh-aw's repo-memory file-glob (`memory/orchestrator/*.yml`) will not capture it -- it is outside the glob scope. If config lives at the project root, spec-kit's config resolution (`ExtensionManager.get_config()`) will not find it. If config is persisted to repo-memory alongside state, edits require branch operations instead of a simple file edit.

**Resolution required**: Separate config (user-authored, rarely changes) from state (machine-authored, changes every run). Config follows spec-kit's convention at `.specify/extensions/orchestrator/orchestrator-config.yml`. State follows the plan's `.specify/orchestrator/` path. The gh-aw adapter syncs state (not config) to repo-memory. Config is committed to the main branch like any other project file.

---

## Tensions

### T-1: Script execution model -- frontmatter declaration vs CI precomputation steps

spec-kit's review (rec #2) says scripts like `derive-phase.sh` must be declared in command frontmatter via the `scripts:` field, enabling spec-kit's cross-platform path rewriting and `{SCRIPT}` placeholder substitution. gh-aw's review (rec #5) says `derive-phase.sh` should run as an `on.steps:` precomputation step before the agent is invoked, saving an AI engine invocation.

These are not contradictory -- one is about declaration, the other about execution context -- but they pull the script design in different directions. If the script is declared in frontmatter, it is invoked by the agent as part of command execution. If it runs as a precomputation step, it executes before the agent and the agent receives its output as a job parameter. The same script cannot easily serve both roles without being aware of its execution context, and the plan currently assumes a single `scripts/state/derive-phase.sh` that works in both environments.

**Impact**: The script needs a thin wrapper or environment detection (`if [ -n "$GITHUB_ACTIONS" ]; then ...`) to handle both contexts. The frontmatter declaration should still exist for local execution, and the gh-aw adapter should invoke the same script in its precomputation step. This is solvable but adds complexity the plan does not account for.

### T-2: Command chaining -- handoffs frontmatter vs dispatch-workflow primitives

spec-kit's review (rec #5) says the `auto` command's state machine loop should use `handoffs` frontmatter to declare transitions between commands (e.g., auto -> plan-phase -> dispatch -> verify). gh-aw's review (rec #1) says the adapter must choose between `dispatch-workflow` (async) and `call-workflow` (sync) for task dispatch and that `dispatch-workflow` is the only viable option for large milestones.

The tension: `handoffs` are a presentation-layer mechanism -- they tell the agent "here are your next options" -- while `dispatch-workflow` is an execution-layer mechanism that creates independent CI runs. The `auto` command's loop must work locally (where handoffs drive the agent through sequential commands) AND in CI (where each iteration may be a separate workflow run triggered by schedule or repository_dispatch). A single command definition cannot express both models through the same mechanism.

**Impact**: The `auto` command likely needs two code paths: a local mode that uses handoffs for the agent to drive the loop interactively, and a CI mode where the adapter translates each handoff into a dispatch. The adapter interface (AD-3) should document this dual-mode expectation.

### T-3: Lock file design -- local PID vs CI run-ID

gh-aw correctly identifies (off-base #1) that PID-based lock detection is meaningless on ephemeral CI runners and recommends `run_id`-based liveness. spec-kit's review does not challenge the lock file design at all because from spec-kit's perspective (local agent execution), PID-based locking works fine.

The tension is not about who is right (both are, in their respective contexts) but about the lock file schema itself. The plan defines a single `orchestrator.lock` format (data-model.md lines 237-249) with a `pid` field. If the lock file gains a `run_id` field for CI and keeps `pid` for local, the two adapters produce structurally different lock files. A local run reading a CI-produced lock file (or vice versa, in mixed workflows) must understand both liveness signals.

**Impact**: The lock file schema needs a `runtime` field (`"local"` or `"ci"`) that tells the reader which liveness check to perform. This is a data model change that affects both adapters.

### T-4: Session lifetime -- long-lived local vs ephemeral CI

gh-aw's off-base #4 identifies that a single CI run cannot drive a full milestone due to `timeout-minutes` limits and recommends re-entry via scheduled triggers. spec-kit's review implicitly assumes a long-lived local session where the agent drives the `auto` loop to completion in one sitting.

Neither review is wrong, but the auto command's design must explicitly support both: continuous execution locally and incremental re-entry in CI. The current plan (plan.md line 68) describes `auto` as a single loop. gh-aw wants it decomposed into per-iteration scheduled runs. If the loop is decomposed for CI, local mode must still support the continuous version -- otherwise the local UX degrades to "run auto, it does one step, run auto again."

**Impact**: The `auto` command needs a `--continuous` flag (default for local adapter) vs single-step mode (default for CI adapter). The adapter interface should declare which mode it supports.

### T-5: inject-context operation viability

gh-aw's review (off-base #2, rec #6) declares `inject-context` not implementable in CI and recommends marking it `not_supported`. spec-kit's review does not address `inject-context` at all because spec-kit commands do not have a mid-execution injection mechanism either -- spec-kit commands are single-pass prompt templates.

The tension: if `inject-context` is `not_supported` in the gh-aw adapter AND has no natural analog in spec-kit's command model, then it may be dead weight in the adapter interface. The orchestrator should not define an operation that no adapter can implement. However, there may be local-only adapters (e.g., a Claude Code adapter) where injecting context into a running agent session is possible via tool use or prompt appending.

**Impact**: The adapter interface should classify `inject-context` as an optional capability with a clear degradation path. The orchestrator's state machine must never require injection for correctness -- it must work with fire-and-forget dispatch.

---

## Safe Agreements

### SA-1: Disk-state-is-truth (AD-2) is the correct foundation

Both reviews endorse AD-2. spec-kit's alignment section confirms that `.specify/orchestrator/` for runtime state mirrors spec-kit's own `.specify/memory/` pattern. gh-aw's alignment section confirms that disk state maps naturally to repo-memory branches. The disagreement is about persistence mechanisms (filesystem vs git branch), not about the principle itself. The file-based state machine design is sound for both local and CI execution.

### SA-2: The 4-level config precedence model (R-004) is correctly designed

spec-kit's alignment section confirms R-004 matches the config layers in EXTENSION-API-REFERENCE.md. gh-aw's alignment section confirms R-004 parallels gh-aw's environment variable hierarchy. Both reviews accept the precedence order (env vars > local override > project config > extension defaults) without modification. This is a settled design decision.

### SA-3: The execution-log.jsonl append-only format is the right choice

gh-aw explicitly endorses the JSONL format as matching its MemoryOps best practice for time-series data. spec-kit does not challenge it. The append-only property is valuable for both local debugging (tail the log) and CI persistence (append to repo-memory without merge conflicts). No review suggests an alternative format.

### SA-4: The extension boundary -- new commands, not core overrides -- is correct

spec-kit's alignment section confirms AD-5 (no core command overrides) correctly positions the orchestrator as an extension rather than a preset. gh-aw's review does not challenge this boundary either -- its recommendations all target adapter behavior and CI dispatch, not core command modification. Both reviews agree the orchestrator should add capabilities without altering spec-kit's existing commands.
