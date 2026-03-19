# gh-aw Utilization Review -- Reviewed & Revised

## Executive Summary

The original gh-aw review identified 10 recommendations for deeper integration between the speckit-orchestrator spec and gh-aw's CI primitives. The core thesis was sound: gh-aw provides mature orchestration, caching, dispatch, and monitoring capabilities that the spec ignores, and the spec's CI integration section (one paragraph) is dangerously underspecified.

However, the cross-reviews from APM and spec-kit exposed a consistent blind spot: **gh-aw's recommendations repeatedly prioritized CI-native storage and execution patterns over the working-tree and extension-directory conventions that APM and spec-kit require for their discovery and compilation pipelines.** Three recommendations (#2, #3, #8) were flagged as dangerous by both reviewers, all sharing the same root cause -- moving state out of the `.specify/` and `.apm/` trees into locations invisible to those tools.

After synthesis, I am **withdrawing 0 recommendations**, **modifying 5**, and **standing by 5**. The modifications all follow the same correction: gh-aw primitives should serve as the CI execution and durability layer, not as the canonical storage or state location. The working tree remains canonical; gh-aw provides the mechanism for persisting that working tree across ephemeral CI runs.

## Recommendation Status

### Rec 1: Map Tier C dispatch to `call-workflow` + `dispatch-workflow`
**Original**: Revise spec's Autonomous Dispatch (lines 75-91) to use `call-workflow` for synchronous and `dispatch-workflow` for async CI execution.
**APM says**: Tension -- Compatible at different layers, but APM `.prompt.md` files are not valid gh-aw workflows. An adapter pattern is needed to wrap APM prompts inside gh-aw workflow frontmatter.
**spec-kit says**: Tension -- Deeply coupling to gh-aw primitives makes the orchestrator a gh-aw-specific extension, degrading the experience for Cursor, Windsurf, or Gemini CLI users. The spec should define an abstract dispatch interface with gh-aw as one backend.
**Revised position**: **Modify.** Both reviewers are right that the recommendation was too coupled. The spec should define an abstract dispatch interface (as spec-kit suggests) and treat `call-workflow`/`dispatch-workflow` as the CI-mode implementation of that interface, not the primary dispatch mechanism. APM's adapter pattern (gh-aw frontmatter wrapping APM prompts) is the correct integration seam. The recommendation stands as a CI-mode implementation detail, not as an architectural primitive.

### Rec 2: Adopt `cache-memory` as the CI-mode state persistence layer
**Original**: Persist `.specify/orchestrator/` artifacts as structured JSON in gh-aw `cache-memory` when running in CI.
**APM says**: Dangerous -- Artifacts in `cache-memory` (mounted at `/tmp/gh-aw/cache-memory/`) are invisible to APM's primitive discovery engine, which only scans `.apm/` and `.github/`. This directly undermines APM's context optimization and compilation.
**spec-kit says**: Dangerous -- Moves state entirely off disk into an opaque cache layer, breaking spec-kit's template resolution, config layering, extension introspection, and the spec's own "disk state is the sole source of truth" mandate (spec lines 122-123).
**Revised position**: **Modify.** I concede this was wrong as stated. Both tools correctly identify that `cache-memory` is not a suitable *primary* storage location -- it is ephemeral, has TTL-based eviction, and is invisible to both APM and spec-kit discovery. The corrected recommendation follows APM's proposed resolution: the working tree (`.specify/orchestrator/` or `.specify/extensions/orchestrator/`) is the canonical state location in both local and CI modes. In CI, `cache-memory` serves as a *durability layer* that persists the working tree across ephemeral runners: restore from cache to working tree at the start of each run, write results to working tree during execution, persist working tree back to cache at the end. This preserves APM's discovery model and spec-kit's disk-state-as-truth while gaining gh-aw's cross-run persistence.

### Rec 3: Use `repo-memory` for knowledge consolidation
**Original**: Store compressed milestone summaries via `repo-memory` on a dedicated orphan branch (e.g., `memory/orchestrator`).
**APM says**: Dangerous -- Orphan-branch storage is invisible to APM's working-tree-only discovery model. APM cannot compile artifacts that exist on a different git branch.
**spec-kit says**: Dangerous -- Moves orchestrator knowledge outside `.specify/`, making it invisible to `specify extension list`, `specify extension info`, and the orchestrator's own dispatch loop that "derives its complete state by reading files on disk."
**Revised position**: **Modify.** Both tools are correct that orphan-branch storage creates a split-brain problem. The corrected recommendation: knowledge consolidation produces files in the working tree (e.g., `.specify/extensions/orchestrator/consolidated/` per spec-kit convention). `repo-memory` can be used as a *secondary* durable backup mechanism for knowledge that needs to survive branch resets or force-pushes, but it must not be the primary location. Any knowledge in `repo-memory` must be checked out into the working tree before APM compilation or spec-kit template resolution operates on it. This is a backup strategy, not a primary storage strategy.

### Rec 4: Replace PID-based crash recovery with workflow-run-status recovery
**Original**: In CI, use `gh run list`/`gh run view` for crash detection instead of PID files and stale locks.
**APM says**: Safe -- APM has no opinion on crash recovery; this is purely a CI concern.
**spec-kit says**: Safe -- spec-kit has no opinion on lock file implementation; the suggestion to use workflow run status checks is sound and complementary to the local approach.
**Revised position**: **Stand.** Both reviewers agree this is orthogonal to their concerns. The recommendation stands unchanged.

### Rec 5: Map verification to `steps:` / `post-steps:`
**Original**: Use gh-aw's `post-steps:` block for the spec's per-task verification (lint, test, build).
**APM says**: Tension -- Risk of three verification systems (gh-aw `post-steps:`, APM hooks, spec-native checks). Verification logic should be owned by the spec, with gh-aw and APM as invocation mechanisms only.
**spec-kit says**: Tension -- `post-steps:` are deterministic shell steps that are guaranteed to run; spec-kit hooks are LLM-mediated Markdown instructions that depend on agent compliance. These are different execution models. Spec-kit hooks should be canonical; `post-steps:` should be the CI optimization.
**Revised position**: **Modify.** Both reviewers converge on the same insight: the spec should own the verification commands, and both gh-aw and APM should be invocation mechanisms. The corrected recommendation: the spec defines verification commands in its own configuration (the lint/test/build commands from the phase plan). In CI mode, these are wired into gh-aw `post-steps:` blocks for guaranteed deterministic execution. Locally, they are invoked by spec-kit hooks or by the orchestrator's own verification step. The verification logic lives in exactly one place (the spec's config); `post-steps:` and hooks are adapters.

### Rec 6: Use `stop-after` and `concurrency` for budget enforcement
**Original**: Map the spec's dispatch and duration budgets to gh-aw's `on.stop-after` and `concurrency` groups.
**APM says**: Tension -- APM has no runtime budget concept. Risk of budget configuration drift between local mode (spec-native) and CI mode (gh-aw-native).
**spec-kit says**: Tension -- If budgets exist in both spec-kit's layered config system (`orchestrator-config.yml`) and gh-aw frontmatter (`on.stop-after`), which is authoritative?
**Revised position**: **Modify.** Both reviewers independently flag the dual-source-of-truth problem. The corrected recommendation: budgets are defined in the spec's configuration (spec-kit's `orchestrator-config.yml` as the single source of truth). The CI integration layer reads those budgets at compile time and translates them into gh-aw frontmatter values (`stop-after`, `concurrency`). gh-aw primitives are the *enforcement mechanism* in CI, not the *configuration location*. This prevents configuration drift by ensuring a single authoritative budget definition with mechanical translation to the CI layer.

### Rec 7: Define status querying via GitHub Projects
**Original**: Track CI-mode progress via `update-project` and `create-project-status-update` safe outputs on a GitHub Projects board.
**APM says**: Safe -- APM has no status querying mechanism; this fills a gap without conflict.
**spec-kit says**: Tension -- File-based status (`execution-log.jsonl`) should remain canonical per spec-kit's disk-state philosophy. GitHub Projects is a web-based dashboard with a GitHub infrastructure dependency that not all spec-kit users will have.
**Revised position**: **Stand** (with a minor clarification from spec-kit). Spec-kit's concern is valid: the file-based execution log must remain the canonical status mechanism. GitHub Projects is an optional CI-mode enhancement, not a replacement. The original recommendation already framed this as a CI-mode feature, but the clarification is useful: the spec should explicitly state that `execution-log.jsonl` is the primary status artifact and GitHub Projects is an opt-in visualization layer when running in CI with gh-aw.

### Rec 8: Adopt one-phase-per-run model for Tier C CI execution
**Original**: Each scheduled CI run advances one phase, persists state to `cache-memory`, and exits. The next trigger picks up where the last left off.
**APM says**: Dangerous -- Makes APM's pre-authored `.prompt.md` dispatch model unusable. APM prompts are static templates with parameter slots; the one-phase-per-run model requires dynamically generated payloads that vary per run.
**spec-kit says**: Dangerous -- Breaks spec-kit hook execution (hooks fire within a session context that does not exist across separate CI jobs), extension command registration (must be reinstalled each run on ephemeral runners), and template resolution (depends on installed presets and extensions).
**Revised position**: **Stand** (with important qualifications). This is where I respectfully disagree with both reviewers on the core recommendation while fully accepting their implementation concerns. The single-job execution model is a hard constraint documented in gh-aw's own source (`create-agentic-workflow.md`, lines 131-149). The spec's multi-phase dispatch loop *cannot* run as a single agentic workflow -- this is not a design choice, it is a platform limitation. The one-phase-per-run model (or its equivalent: the campaign pattern) is the only viable architecture for Tier C in CI.

However, both reviewers correctly identify that the *implementation details* of Rec #8 were wrong: persisting state to `cache-memory` (fixed in Rec #2's revision) and ignoring session continuity for hooks and extensions. The corrected implementation: each CI run (a) restores the full `.specify/` working tree from cache (the revised Rec #2 pattern), (b) installs/verifies the spec-kit extension, (c) advances one phase using whatever APM prompt or spec-kit command is appropriate for that phase, (d) persists the updated working tree back to cache. The one-phase-per-run scheduling model survives; the storage model is corrected per Rec #2.

As for APM's concern about dynamic vs. static prompts: the one-phase-per-run model does not require dynamically *generating* prompts. It requires dynamically *selecting* which pre-authored prompt to run based on the current phase state. The orchestrator reads state, determines the current phase, selects the corresponding `.prompt.md`, and executes it. The prompts themselves remain static templates.

### Rec 9: Reference TaskOps for Tier B CI implementation
**Original**: Map Tier B (developer-driven structured handoff) to gh-aw's TaskOps pattern for CI execution.
**APM says**: Safe -- Maps cleanly onto APM primitive types (research to `.context.md`, planning to `.prompt.md`, execution to skill consumption).
**spec-kit says**: Safe -- A CI-specific implementation detail for how Tier B steps get dispatched in an unattended context. Does not conflict with spec-kit's extension model.
**Revised position**: **Stand.** Both reviewers agree this is beneficial and orthogonal to their concerns. The recommendation stands unchanged.

### Rec 10: Expand P7 to full CI integration design
**Original**: The spec's P7 (GitHub Workflows) is one paragraph. Given 10+ relevant gh-aw capabilities, it needs a dedicated section.
**APM says**: Safe -- Sequencing tension with APM's gradual-adoption preference, but no architectural conflict. APM argues for using primitives informally from P1 and formalizing at P8.
**spec-kit says**: Safe and beneficial -- A detailed CI section would need to address spec-kit extension installation, template resolution, and hook execution in CI, preventing implementation-time surprises.
**Revised position**: **Stand.** Both reviewers endorse expanding P7, with APM noting a sequencing preference (which is about when to formalize, not whether to). The recommendation stands. The expanded P7 section should explicitly address: (a) the single-job execution model constraint, (b) the working-tree-as-canonical-state pattern from revised Rec #2, (c) the abstract dispatch interface from revised Rec #1, (d) spec-kit extension installation on ephemeral runners, and (e) how APM prompts are wrapped in gh-aw workflow frontmatter.

## Withdrawn Recommendations

None. All 10 recommendations survive in either original or modified form.

## Modified Recommendations

### Rec 1 (revised): Abstract dispatch interface with gh-aw as CI backend

The spec should define an abstract dispatch interface for Tier C that is agent-runtime-agnostic (per spec-kit's extension model). When running in CI with gh-aw, that interface maps to `call-workflow` (synchronous worker execution) and `dispatch-workflow` (async fire-and-forget). APM `.prompt.md` files define *what* the worker does; gh-aw workflow frontmatter defines *how* and *when* it runs. The adapter pattern from APM's gh-aw integration doc (gh-aw workflow declares APM `dependencies:` in frontmatter, body references the APM prompt) is the correct integration seam. The spec should document this adapter explicitly in the expanded P7 section.

### Rec 2 (revised): Working tree as canonical state, `cache-memory` as CI durability layer

The `.specify/extensions/orchestrator/` directory (per spec-kit's extension convention) is the canonical state location in both local and CI modes. In CI, gh-aw's `cache-memory` provides cross-run durability for the working tree on ephemeral runners, not as primary storage. The CI run lifecycle is: (1) restore `.specify/` tree from `cache-memory`, (2) execute orchestrator logic reading/writing to the working tree, (3) persist `.specify/` tree back to `cache-memory`. This preserves APM's primitive discovery, spec-kit's file-based introspection, and the spec's disk-state-as-truth mandate while gaining gh-aw's cross-run persistence.

### Rec 3 (revised): Knowledge consolidation in working tree, `repo-memory` as backup

Compressed milestone summaries live in `.specify/extensions/orchestrator/consolidated/` (working tree), making them visible to APM compilation, spec-kit template resolution, and `specify extension info`. `repo-memory` may be used as a secondary backup mechanism for knowledge that needs to survive branch resets or force-pushes, but any `repo-memory` content must be checked out into the working tree before other tools operate on it. This is a disaster recovery mechanism, not a primary storage strategy.

### Rec 5 (revised): Spec-owned verification commands, `post-steps:` as CI adapter

The spec defines verification commands (lint, test, build) in its own configuration as the single source of truth. In CI mode, these commands are wired into gh-aw `post-steps:` blocks for guaranteed deterministic execution outside the agent sandbox. Locally, the same commands are invoked by spec-kit hooks or by the orchestrator's own verification step. The verification logic is owned by the spec; `post-steps:` and spec-kit hooks are invocation adapters for their respective execution contexts.

### Rec 6 (revised): Spec-kit config as budget authority, gh-aw as CI enforcement

Budgets (dispatch count, duration limits, concurrency caps) are defined in spec-kit's `orchestrator-config.yml` using the standard layered config system (defaults > project config > local overrides > env vars). The CI integration layer reads these budgets at compile time and translates them into gh-aw frontmatter (`stop-after`, `concurrency` groups, `safe-outputs.*.max`). gh-aw enforces budgets at runtime in CI; the spec's own enforcement applies locally. A single schema definition prevents configuration drift.

## Surviving Recommendations

### Rec 4: Replace PID-based crash recovery with workflow-run-status recovery (unchanged)

In CI, crash detection uses `gh run list`/`gh run view` to check the status of the last orchestrator run. State recovery reads the last-known state from the restored working tree (via the revised `cache-memory` pattern from Rec #2). Re-trigger via `workflow_dispatch`. No PID files or stale lock detection in CI. Both APM and spec-kit confirmed this is orthogonal to their concerns.

### Rec 7: GitHub Projects as optional CI status visualization (unchanged, with clarification)

`execution-log.jsonl` remains the canonical status artifact per spec-kit's disk-state philosophy. When running in CI with gh-aw, progress can additionally be tracked via `update-project` and `create-project-status-update` safe outputs on a GitHub Projects board. This is explicitly optional and does not replace file-based status. The spec should state both mechanisms and their relationship.

### Rec 8: One-phase-per-run model for Tier C CI execution (defended, with corrected implementation)

The single-job execution model is a hard platform constraint. The one-phase-per-run campaign pattern remains the only viable architecture for Tier C in CI. The implementation details are corrected: state lives in the working tree (Rec #2 revised), spec-kit extensions are installed/verified at the start of each run, and the orchestrator selects which pre-authored APM prompt to execute based on phase state (not dynamically generated payloads). The scheduling model survives; the storage and session management model is corrected.

### Rec 9: Reference TaskOps for Tier B CI implementation (unchanged)

Tier B maps naturally to TaskOps: Phase 1 (research) generates context, Phase 2 (planning) creates scoped issues, Phase 3 (execution) assigns issues to Copilot agents. Both APM and spec-kit confirmed alignment with their respective primitive models.

### Rec 10: Expand P7 to full CI integration design (unchanged, with enhanced scope)

P7 needs a dedicated section covering: the single-job execution model constraint, the abstract dispatch interface (Rec #1 revised), the working-tree-as-canonical-state pattern (Rec #2 revised), spec-kit extension installation on ephemeral runners (from spec-kit's DC-2 feedback), APM prompt-to-workflow adapter pattern (from APM's tension #1), and the one-phase-per-run campaign architecture (Rec #8).

## Lessons Learned

**1. gh-aw has a CI-native bias that other tools do not share.** gh-aw naturally thinks in terms of ephemeral runners, cache artifacts, and GitHub-specific infrastructure. Both APM and spec-kit are working-tree-first tools that expect all meaningful state to be discoverable by scanning the filesystem. When gh-aw recommends moving state into `cache-memory` or `repo-memory`, it is solving a real durability problem (ephemeral runners lose state between runs) but doing so in a way that breaks the contracts of the other tools. The lesson: gh-aw should position its storage primitives as *transport and durability* mechanisms, not as *canonical locations*.

**2. The adapter pattern is the correct integration seam.** APM's observation that `.prompt.md` files are not valid gh-aw workflows, and spec-kit's observation that `post-steps:` are not portable hooks, both point to the same architectural insight: gh-aw primitives belong behind an adapter layer. The orchestrator defines what to do (via spec-kit commands and APM prompts); gh-aw defines how to execute it in CI. These are different layers and should be treated as such.

**3. The single-job constraint is gh-aw's most valuable contribution, and both reviewers acknowledged it.** The warning that the spec's multi-phase dispatch loop cannot run as a single agentic workflow was flagged as "extremely valuable" by spec-kit and implicitly validated by APM (whose analysis of Rec #8's incompatibility with `.prompt.md` assumes the one-phase-per-run model is correct). gh-aw's domain expertise about CI execution constraints is where it adds the most unique value to the orchestrator spec.

**4. Prioritizing configuration authority matters.** Both APM and spec-kit independently flagged the dual-source-of-truth problem with budgets (Rec #6) and verification (Rec #5). When three tools all have configuration systems, the spec must designate a single authority and make the others adapters. The cross-review made clear that spec-kit's extension config system should be that authority for the orchestrator, with gh-aw and APM consuming configuration rather than defining it.

**5. gh-aw's review was too focused on "what gh-aw can do" and not enough on "what the spec needs."** Several recommendations (particularly #2 and #3) read as "here is a gh-aw feature that maps to a spec concept" without adequately weighing whether adopting that feature would break invariants of the other tools in the ecosystem. Future reviews should start from the spec's architectural constraints (disk-state-as-truth, extension directory conventions, runtime agnosticism) and work backward to gh-aw capabilities, rather than the other way around.
