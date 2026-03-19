# spec-kit Review of gh-aw's Recommendations

## Dangerous Contradictions

### DC-1: `cache-memory` as CI-mode state persistence layer undermines disk-state-as-truth (Rec #2)

gh-aw Recommendation #2 proposes that when running in CI, the `.specify/orchestrator/` artifact tree should be persisted as structured JSON files in gh-aw `cache-memory` (multiple named caches: one for roadmap, one for decisions, one for execution log).

This directly contradicts spec-kit's foundational architecture. Spec-kit's extension system stores all extension state under `.specify/extensions/{extension-id}/` (EXTENSION-API-REFERENCE.md, lines 784-810; RFC-EXTENSION-SYSTEM.md, "Config File Location" resolved question). The orchestrator's own review (spec-kit UTILIZATION.md, recommendation #3) already flagged that the spec places state in `.specify/orchestrator/` when it should be at `.specify/extensions/orchestrator/` per spec-kit convention.

gh-aw's recommendation goes further in the wrong direction: it moves state *entirely off disk* into an opaque cache layer. This breaks several spec-kit invariants:

- **Template resolution requires files on disk.** Spec-kit's PresetResolver walks a priority stack of on-disk directories (presets/ARCHITECTURE.md, lines 9-36). If orchestrator templates or artifacts live in `cache-memory`, they become invisible to spec-kit's resolution machinery.
- **Extension config layering requires YAML files in known paths.** The four-tier config resolution (defaults > project config > local overrides > env vars) documented in EXTENSION-API-REFERENCE.md lines 486-531 depends on files at `.specify/extensions/{ext-id}/{ext-id}-config.yml`. A JSON blob in `cache-memory` bypasses this entirely.
- **`specify extension list`, `specify extension info`, and hook inspection require the registry and manifest on disk.** If the orchestrator's state is in a GitHub Actions cache, no local tooling can introspect it.
- **The orchestrator spec itself mandates "disk state is the sole source of truth" and "No in-memory state survives across sessions" (spec lines 122-123, 285).** `cache-memory` is ephemeral infrastructure with TTL-based eviction, not a durable source of truth.

If the orchestrator follows this advice, local `specify` CLI commands would see a disconnected or empty state when a developer tries to inspect orchestrator artifacts locally after a CI run. The entire premise of spec-kit's file-based architecture is that a developer can `ls .specify/` and see the full picture.

**Safe alternative:** The CI integration should commit orchestrator state to the repo (on a working branch or via `repo-memory` on an orphan branch) so disk-state-as-truth is preserved. gh-aw's own `repo-memory` (Rec #3) is safer than `cache-memory` because it is git-backed, but even that should be secondary to committing artifacts into the `.specify/` tree directly.

### DC-2: One-phase-per-run model breaks the orchestrator's state machine coherence (Rec #8)

gh-aw Recommendation #8 proposes a "scheduled-trigger model: each scheduled run advances one phase, persists state to `cache-memory`, and exits." This fundamentally changes the orchestrator's architecture from a stateful dispatch loop (spec lines 77-91) to a scheduled cron-style state machine.

From spec-kit's perspective, this creates a dangerous divergence:

- **Hooks fire at phase boundaries.** Spec-kit's hook system (after_tasks, after_implement, before_tasks, before_implement) fires within a single session context where the agent has loaded extension config, resolved templates, and built up command context. If each phase is a separate GitHub Actions job, hook execution happens in a cold-start environment with no spec-kit session continuity. The `HookExecutor` (EXTENSION-API-REFERENCE.md lines 346-381) expects to load project config from `.specify/extensions.yml` and resolve hooks against the local registry -- if the registry was populated in a different CI run, there is no guarantee of consistency.
- **Extension command registration is a one-time install-time operation.** When `specify extension add orchestrator` runs, it registers commands into agent directories (`.claude/commands/`, etc.). In a CI-per-phase model, each run would need to either (a) reinstall the extension every time, or (b) assume the workspace has the extension pre-installed. Neither is guaranteed in ephemeral GitHub Actions runners.
- **Template resolution state depends on installed presets and extensions.** If the orchestrator ships a companion preset (as spec-kit's own review recommends in Rec #4), that preset must be installed in every CI run for template resolution to produce correct artifacts. The one-phase-per-run model multiplies this setup cost and fragility.

The core tension: spec-kit's extension model assumes a persistent workspace where extensions are installed once and used repeatedly. gh-aw's CI model assumes ephemeral runners where each run starts fresh. These are architecturally incompatible without explicit workspace persistence -- which gh-aw's `cache-memory` recommendation (DC-1) does not safely provide.

### DC-3: `repo-memory` for knowledge consolidation conflicts with spec-kit's feature directory convention (Rec #3)

gh-aw Recommendation #3 proposes storing compressed milestone summaries via `repo-memory` on a dedicated orphan branch (e.g., `memory/orchestrator`). This moves orchestrator knowledge artifacts outside the `.specify/` tree entirely.

Spec-kit's extension architecture is built on the convention that all extension state lives under `.specify/extensions/{extension-id}/` (RFC-EXTENSION-SYSTEM.md, Architecture Overview). The preset and template resolution systems walk `.specify/` subtrees exclusively. Knowledge files stored on an orphan branch are invisible to:

- `specify extension list` and `specify extension info` (which inspect `.specify/extensions/`)
- Any spec-kit command that reads orchestrator state (which expects `.specify/` paths)
- The orchestrator's own dispatch loop, which "derives its complete state by reading files on disk" (spec line 122) -- an orphan branch is not "on disk" in the working tree unless explicitly checked out

This creates a split-brain where some orchestrator state is in `.specify/` (the extension manifest, config, commands) and other state is on an orphan branch. A developer running `git status` or `ls .specify/` sees an incomplete picture.

**Safe alternative:** Knowledge consolidation should produce files in `.specify/extensions/orchestrator/consolidated/` or `.specify/specs/{feature}/orchestrator/consolidated/`, keeping everything in the working tree and visible to spec-kit's resolution and introspection mechanisms.

## Tensions

### T-1: `call-workflow` / `dispatch-workflow` as dispatch primitives vs. spec-kit's agent-runtime-agnostic model (Rec #1)

gh-aw Recommendation #1 proposes that Tier C dispatch should use `call-workflow` for synchronous worker execution and `dispatch-workflow` for async fire-and-forget tasks when running as a gh-aw workflow.

This is not a contradiction per se -- the spec already says "the orchestrator can optionally run as a GitHub Agentic Workflow" (spec line 237). However, there is a tension with spec-kit's agent runtime agnosticism:

- Spec-kit supports 25+ agent runtimes (README.md, Supported AI Agents table). The extension system is designed so that "extensions write universal Markdown commands and the registrar handles the rest" (spec-kit UTILIZATION.md, alignment point on agent runtime agnosticism).
- If the orchestrator's Tier C dispatch is deeply coupled to gh-aw's `call-workflow` and `dispatch-workflow` primitives, it becomes a gh-aw-specific extension rather than a universal spec-kit extension. A developer using Cursor, Windsurf, or Gemini CLI would have a degraded Tier C experience.
- The spec already handles this by saying the orchestrator "detects capabilities (subagent dispatch, shell execution, git, CI environment) and selects the best available execution strategy" (spec line 234). This is the right approach. The tension is in how deeply the spec should commit to gh-aw's specific primitives vs. treating them as one backend among many.

**Resolution path:** The orchestrator should define an abstract dispatch interface in its extension commands. The gh-aw integration should be a configuration option or capability detection, not a hardcoded dispatch mechanism. This preserves spec-kit's runtime-agnostic model while still benefiting from gh-aw's CI primitives when available.

### T-2: `steps:` / `post-steps:` for verification vs. spec-kit hook system (Rec #5)

gh-aw Recommendation #5 proposes mapping per-task verification to gh-aw's `steps:` (pre-execution) and `post-steps:` (post-execution) blocks, which "run outside the agent sandbox with full shell access."

Spec-kit already has a hook system that fires at command boundaries (EXTENSION-API-REFERENCE.md, Hook System, lines 532-594). The orchestrator's own review recommends using `before_tasks`/`after_tasks`/`before_implement`/`after_implement` hooks for this purpose.

The tension: gh-aw's `post-steps:` are compiled into the workflow YAML and run as deterministic shell steps. Spec-kit's hooks are LLM-mediated -- they are instructions in Markdown that the agent interprets and executes. These are fundamentally different execution models:

- gh-aw's `post-steps:` are guaranteed to run (they are CI pipeline steps), but they are gh-aw-specific
- spec-kit's hooks are portable across all 25+ agent runtimes, but they depend on the agent faithfully executing the hook instructions

Both approaches are valid for their respective contexts. The danger would be if the spec specifies `post-steps:` as *the* verification mechanism, which would make verification gh-aw-specific and bypass spec-kit's hook system.

**Resolution path:** The spec should define verification as spec-kit hooks (portable) with a documented pattern for wiring those hooks into gh-aw `post-steps:` when running in CI mode. The spec-kit hooks are the canonical mechanism; `post-steps:` is an optimization for the CI path.

### T-3: Campaign pacing controls vs. extension configuration (Rec #6)

gh-aw Recommendation #6 proposes mapping dispatch and duration budgets to gh-aw's `on.stop-after` and `concurrency` groups.

The orchestrator spec already defines budgets in its `config.json` (spec line 192, 224). Spec-kit's own review (Rec #2) recommends replacing `config.json` with `orchestrator-config.yml` using spec-kit's standard layered config system (EXTENSION-API-REFERENCE.md, lines 486-531).

The tension: if budgets are specified in both `orchestrator-config.yml` (spec-kit's config layer) and in gh-aw frontmatter (`on.stop-after`, `concurrency`), which is authoritative? A developer could set a 2-hour budget in spec-kit config but a 30-minute `stop-after` in the gh-aw workflow, creating conflicting constraints with no clear resolution.

**Resolution path:** The spec should define budgets in spec-kit's config system as the single source of truth. The CI integration layer should read those budgets and translate them into gh-aw frontmatter values at compile time, not maintain a parallel configuration.

### T-4: GitHub Projects for status querying vs. filesystem-based status (Rec #7)

gh-aw Recommendation #7 proposes tracking progress via `update-project` and `create-project-status-update` safe outputs on a GitHub Projects board for CI mode.

The orchestrator spec requires "Progress queryable from a second terminal in under 5 seconds" (spec line 259) and defines the execution log (`execution-log.jsonl`, spec line 216) as the primary status artifact.

The tension: spec-kit's model is file-based. A developer queries status by reading files. GitHub Projects is a web-based dashboard. These are complementary rather than conflicting, but if the spec makes Projects the canonical CI-mode status mechanism, it creates a dependency on GitHub infrastructure that not all spec-kit users will have (spec-kit is platform-agnostic -- it works with any Git host).

**Resolution path:** File-based status (execution-log.jsonl) should remain the canonical mechanism per spec-kit's disk-state philosophy. GitHub Projects can be an optional enhancement for CI mode, similar to how the Jira extension is optional for issue tracking.

## Synergies

### S-1: Single-job execution model warning is critical and correct (Off-Base #1)

gh-aw's warning that "the spec's Tier C autonomous dispatch loop cannot run as described within a single agentic workflow run" is extremely valuable. This is a hard constraint that spec-kit's own review did not flag because it is outside spec-kit's domain. The spec's CI integration section (one paragraph at lines 236-238) dangerously underestimates the complexity of mapping the dispatch loop to GitHub Actions. gh-aw's expertise here prevents the orchestrator from shipping a CI integration that simply does not work.

### S-2: Lock file / PID critique is correct for CI (Off-Base #2)

gh-aw's identification that "lock files and PID-based crash detection are not viable in CI" is accurate and does not conflict with spec-kit. Spec-kit has no opinion on lock file implementation -- this is purely orchestrator-internal logic. gh-aw's suggestion to use workflow run status checks (`gh run view`) for the CI path is sound and complementary to the local PID-based approach.

### S-3: TaskOps mapping to Tier B validates the tier model (Rec #9)

gh-aw's observation that Tier B maps naturally to TaskOps (research agent investigates, planner creates scoped issues, issues assigned to Copilot for execution) strengthens the orchestrator's tier model. This mapping does not conflict with spec-kit's extension model -- it is a CI-specific implementation detail for how Tier B steps get dispatched in an unattended context.

### S-4: Phase scope enforcement via prompt + post-steps (Off-Base #4)

gh-aw correctly notes that the Agent Workflow Firewall does not restrict file access within the workspace, and that phase scope enforcement would need to be implemented in agent prompt instructions and verified in `post-steps:`. This aligns with how spec-kit extensions work: commands are Markdown instructions that the agent follows, not sandboxed executables. The enforcement mechanism is the same in both local and CI modes (agent instructions + mechanical post-verification), which is consistent with spec-kit's model.

### S-5: Expanding P7 to a full CI integration design (Rec #10)

gh-aw's recommendation to expand the P7 user story from one paragraph to a full CI integration design is well-aligned with spec-kit's interests. A detailed CI integration section would need to explicitly address how spec-kit extension installation, template resolution, and hook execution work in the CI environment. Without this detail, the CI integration risks breaking spec-kit conventions in ways that are only discovered at implementation time.

## Verdict

Of gh-aw's 10 actionable recommendations:

**Dangerous (3):** Recommendations #2 (cache-memory as state persistence), #3 (repo-memory for knowledge consolidation), and #8 (one-phase-per-run model) directly conflict with spec-kit's file-based, disk-state-as-truth architecture and extension directory conventions. Following these as-written would create state that is invisible to spec-kit's tooling, break template resolution, and fragment the extension model.

**Requires careful adaptation (4):** Recommendations #1 (call-workflow dispatch), #5 (post-steps for verification), #6 (campaign pacing), and #7 (GitHub Projects for status) are valid CI optimizations but must be layered on top of spec-kit's existing mechanisms (hooks, extension config, file-based status), not replace them. Each needs a "spec-kit is canonical, gh-aw is the CI adapter" framing.

**Safe and beneficial (3):** Recommendations #9 (TaskOps for Tier B), #10 (expand P7), and #4 (replace PID-based crash recovery in CI) are either orthogonal to spec-kit's model or actively helpful. The single-job execution model warning (Off-Base #1) and the lock file critique (Off-Base #2) in the analysis section are also valuable contributions that prevent implementation failures.

**Overall assessment:** gh-aw's review demonstrates deep knowledge of the CI execution layer but consistently underweights the constraints imposed by spec-kit's extension model. The three dangerous recommendations all share the same root cause: they prioritize CI-native patterns (ephemeral caches, orphan branches, job-per-phase) over spec-kit's convention that all state lives in the `.specify/` tree. The orchestrator spec must resolve these contradictions by establishing that spec-kit's extension conventions are the primary architecture, with CI integration as an adapter layer that translates between the two models.
