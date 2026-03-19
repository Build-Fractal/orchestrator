# spec-kit Utilization Review -- Iteration 2

## Position Evolution

**Original review (UTILIZATION.md)**: Produced 10 recommendations from a pure spec-kit-centric perspective. Every recommendation assumed spec-kit was the sole tool governing the orchestrator's extension lifecycle, state layout, configuration, and distribution. The review correctly identified real integration gaps (missing template registration, no preset compatibility, no catalog publishing) but framed them as compliance requirements rather than collaborative design decisions.

**Iteration 1 revision (UTILIZATION.iteration_1.md)**: Cross-reviews from APM and gh-aw exposed a consistent blind spot: spec-kit's extension conventions were designed for extensions consumed exclusively through spec-kit's own resolution machinery. The orchestrator has three consumers. Three recommendations were withdrawn (Rec 2: config format lock-in, Rec 3: state directory scattering, Rec 4: preset-based command overriding). Four were modified to add multi-tool awareness. Three survived unchanged as synergy points. The revision acknowledged that the most "textbook-correct" advice from a single-tool perspective was the most harmful in a multi-tool context.

**Iteration 2 (this document)**: APM and gh-aw's meta-reviews of the iteration 1 revision identified three categories of remaining issues: (1) a crossed-wires state directory problem where tools passed each other in transit, (2) APM's legitimate concern about artifact discoverability being deferred to P8, and (3) second-order coordination questions (CI setup ownership, hook matrix timing, dual-authority arbitration). This iteration resolves the crossed-wires issue, addresses APM's discovery timeline concern, locks consensus positions, and defines concrete compromises for the remaining disputes.

---

## Current Recommendations (Final Positions)

### Rec 1: Register orchestrator structural templates in the extension's templates/ directory

**Status**: Locked (modified from original, stable across iterations)

**Position**: The orchestrator's structural templates (roadmap-template.md, phase-summary-template.md, task-summary-template.md, decision-register-template.md) should be registered in the extension's `templates/` directory to participate in spec-kit's four-tier resolution stack (overrides > presets > extensions > core). These are document shapes before fill-in, not filled runtime artifacts. Preset-based customization of these shapes is a legitimate spec-kit capability that organizations should be able to use (e.g., a "compliance-orchestrator" preset adding mandatory sign-off sections to phase summaries). CI workflows using gh-aw must include `specify extension add orchestrator` in their `steps:` block before the agent executes if they depend on template customization.

**Cross-tool consensus**: APM agrees with the structural-template/filled-artifact distinction (APM iteration 1 proposed this split and spec-kit adopted it). gh-aw accepts template registration provided the CI setup dependency is documented in the spec's P7 section. All three tools agree.

**Iteration 2 refinement**: gh-aw's iteration 1 meta-review raised a valid concern about *who owns* the CI setup `steps:` block documentation. spec-kit's position: the orchestrator spec's expanded P7 section (which all three tools endorse expanding) must include a canonical `steps:` block showing extension installation. This is a documentation deliverable for P7, not an architectural decision. The orchestrator spec author writes it; all three tools review it.

---

### Rec 2: Use format-neutral configuration

**Status**: Locked (withdrawn in iteration 1, stable)

**Position**: Withdrawn. The orchestrator should use a format-neutral configuration file (the spec's original `config.json` or a YAML/JSON file that is not bound to any single tool's resolution stack). spec-kit's proprietary layered config system (`SPECKIT_ORCHESTRATOR_*` env vars, local gitignored overrides, project > local > env var resolution) should not be imposed on the orchestrator when APM's manifest model and gh-aw's CI configuration mechanism need to consume the same settings.

**Cross-tool consensus**: All three tools agree. APM explicitly confirmed this as genuinely resolved. gh-aw's budget-authority concession (gh-aw reads budget values from whatever config the spec designates) further validates the format-neutral approach.

---

### Rec 3: State directory location

**Status**: Modified (withdrawn in iteration 1, now refined to resolve crossed-wires problem)

**Position**: The orchestrator's canonical state directory is `.specify/orchestrator/` -- a single directory tree at a well-known location under `.specify/`. This is neither spec-kit's extension convention path (`.specify/extensions/orchestrator/`) nor a path outside `.specify/`. It is the spec's original design, which both APM and gh-aw independently validated as superior for multi-tool compatibility.

**Cross-tool consensus**: This is where the crossed-wires problem from iteration 1 must be resolved. The situation:

- spec-kit iteration 1: Withdrew Rec 3, accepting `.specify/orchestrator/` as the canonical path (the spec's original design).
- gh-aw iteration 1: Adopted `.specify/extensions/orchestrator/` as canonical, thinking it was conceding to spec-kit's extension convention.
- APM iteration 1: Also adopted `.specify/extensions/orchestrator/` as canonical in revised Recs 2 and 3, again thinking it was conceding to spec-kit.

Both APM and gh-aw conceded to a position that spec-kit itself was simultaneously withdrawing. APM's iteration 1 meta-review correctly identified this incoherence.

**spec-kit's resolution**: The canonical path is `.specify/orchestrator/`. This is what spec-kit's iteration 1 withdrawal endorsed, and the reasoning is sound: the orchestrator's state has consumers beyond spec-kit (APM compilation, gh-aw cache persistence, the orchestrator's own dispatch logic). The extension convention path (`.specify/extensions/{id}/`) was designed for extensions whose state is only consumed through spec-kit's own resolution. The orchestrator does not fit that assumption. gh-aw's hard stance (single directory tree, static cache keys) is fully satisfied. The `specify extension list` and `specify extension info` commands can discover orchestrator state at this non-standard path via the extension manifest's metadata.

**What APM and gh-aw should do**: Update their revised positions to use `.specify/orchestrator/` instead of `.specify/extensions/orchestrator/`. This is a path string change in their recommendations, not an architectural change -- the properties both tools require (single directory, predictable location, under `.specify/`) are preserved either way.

---

### Rec 4: Namespaced commands over command overriding

**Status**: Locked (withdrawn in iteration 1, stable)

**Position**: Withdrawn. The orchestrator must use namespaced commands (`speckit.orchestrator.specify`, `speckit.orchestrator.clarify`, `speckit.orchestrator.plan`) that invoke unmodified core SDD commands with orchestrator context injected. No presets, no command overriding, no silent mutation of core command behavior. This was the most unanimously rejected recommendation in the original review.

**Cross-tool consensus**: All three tools agree. This was the strongest resolution across all iterations. APM confirmed it as genuinely resolved with "no hedge, no softened language, no 'we still think presets have value.'" gh-aw confirmed it as locked and non-negotiable. spec-kit's own iteration 1 Lessons Learned explicitly acknowledged that "both reviewers converged on namespaced commands over command overrides" and that the original recommendation should never have preferred option (b) over option (a).

---

### Rec 5: Declare requires.commands in extension.yml

**Status**: Locked (unchanged across all iterations)

**Position**: The orchestrator's extension.yml must declare dependencies on all core SDD commands it invokes: `speckit.specify`, `speckit.clarify`, `speckit.plan`, `speckit.tasks`, `speckit.implement`. This provides install-time validation that complements APM's package-level dependency checks and enables gh-aw workflows to validate command availability before agent execution.

**Cross-tool consensus**: All three tools marked this as synergistic from the original review onward. No modifications across two iterations.

---

### Rec 6: Declare subagent dispatch as requires.tools (local execution only)

**Status**: Locked (modified in iteration 1, stable)

**Position**: The extension.yml should declare subagent dispatch capability (e.g., Claude Code's `claude --continue`) as a `requires.tools` dependency for the local execution path. This causes `specify extension add orchestrator` to emit a non-blocking warning when the user's agent runtime lacks subagent support. The declaration explicitly does not cover CI dispatch, which uses gh-aw's `call-workflow`/`dispatch-workflow` primitives -- a fundamentally different mechanism. The orchestrator spec should document local and CI dispatch as distinct capability requirements.

**Cross-tool consensus**: APM noted the asymmetric UX (APM installation would not show the same warning) but accepted it as a non-dangerous tension. gh-aw accepted the local/CI dispatch distinction. All three tools agree on the scoped declaration.

---

### Rec 7: Integrate /speckit.analyze into the phase review stage

**Status**: Locked (unchanged across all iterations)

**Position**: The orchestrator's two-stage phase review (spec compliance check, then code quality check) should invoke `/speckit.analyze` for cross-artifact consistency checks during the spec compliance stage. This is a concrete, invokable command with a predictable exit code that maps cleanly to both APM's context validation loop and gh-aw's `post-steps:` verification blocks.

**Cross-tool consensus**: All three tools marked this as synergistic from the original review onward. No modifications across two iterations.

---

### Rec 8: Dual-channel distribution with documented authority boundaries

**Status**: Modified (refined from iteration 1 to address CI sequencing and jurisdictional gap)

**Position**: The orchestrator should be published to both the spec-kit community catalog (`specify extension add orchestrator`) and as an APM package. The authority split: the spec-kit catalog is authoritative for extension machinery (commands, hooks, template registration, extension lifecycle). APM is authoritative for context primitives (compiled context, skill files, prompt workflows, distribution packaging). For CI via gh-aw, the canonical installation sequence is: (1) `specify extension add orchestrator` first (installs commands, hooks, templates that must be available before agent execution), then (2) APM context installation if APM is present.

**Cross-tool consensus**: The dual-channel model is agreed upon by all three tools. gh-aw's iteration 1 meta-review raised two refinements that spec-kit now incorporates:

1. **CI sequencing**: gh-aw proposed spec-kit-first installation because hooks and template resolution must be available before the agent runs. spec-kit agrees -- this is the correct sequencing. The P7 section should document this explicitly.

2. **Jurisdictional gap on phase summaries**: APM's iteration 1 meta-review identified that phase summaries are simultaneously "extension machinery" (the orchestrator reads/writes them during dispatch) and "context primitives" (they are agent-consumable knowledge). Under the dual-authority model, which tool is authoritative? spec-kit's position: phase summaries are extension state during orchestration runtime and become context primitives at distribution time. The orchestrator owns them during P1-P7 execution. APM's compilation transforms them into optimized agent context at P8. This is the structural-template/filled-artifact distinction applied to lifecycle rather than format: the same artifact crosses the authority boundary when its lifecycle phase changes.

---

### Rec 9: Forward-compatible hook design with documented interaction model

**Status**: Modified (refined based on gh-aw's deferral argument)

**Position**: The orchestrator should register hooks at all currently-wired spec-kit hook points (before_tasks, after_tasks, before_implement, after_implement) and design its extension.yml to accommodate additional hooks (before_plan, after_plan, before_specify, after_specify) as spec-kit adds them. The hook count should not be hardcoded.

**Cross-tool consensus**: All three tools agree on forward-compatible hook design. The disagreement was on the hook interaction matrix:

- spec-kit iteration 1: Proposed a hook interaction matrix showing where spec-kit hooks and APM hooks could fire during a single orchestrator operation.
- gh-aw iteration 1 meta-review: Argued this is premature -- the orchestrator does not use APM hooks today, and speculative cross-system documentation drifts faster than the implementation it describes.
- APM iteration 1 meta-review: Accepted the hook-level separation and was willing to contribute to defining the matrix.

**Revised position**: spec-kit accepts gh-aw's deferral argument. Document the existing hook execution order (spec-kit hooks only) now. Add the APM hook interaction matrix when APM hooks are actually integrated into the orchestrator. This avoids speculative documentation while preserving the design principle that both hook systems should be documented when they coexist. The forward-compatibility requirement (design for hook expansion) remains unchanged.

---

### Rec 10: Add tags for catalog discoverability

**Status**: Locked (unchanged across all iterations)

**Position**: The extension.yml should include tags (`orchestration`, `autonomous`, `multi-phase`, `dispatch`, `knowledge-management`) for catalog search discoverability. Equivalent metadata should appear in `apm.yml` for APM's ecosystem.

**Cross-tool consensus**: All three tools marked this as safe and complementary from the original review onward. No modifications across two iterations.

---

## Convergence Points

After two iterations of review, all three tools now agree on the following positions:

1. **Namespaced commands are the correct pattern.** The orchestrator uses `speckit.orchestrator.{command}` commands that invoke unmodified core SDD commands. No presets, no command overriding, no silent mutation. This was the strongest convergence signal in the entire process -- two tools with completely different architectures (APM: context deduplication concern, gh-aw: deterministic verification concern) independently proposed the identical alternative.

2. **Configuration must be format-neutral.** The orchestrator's config file is not bound to spec-kit's layered resolution, APM's manifest frontmatter, or gh-aw's workflow frontmatter. Each tool consumes the neutral config through its own mechanism. gh-aw explicitly conceded budget-definition authority to the spec's config system, with gh-aw handling enforcement in CI.

3. **State must live in a single directory tree under `.specify/`.** No scattering across feature directories. No primary storage outside `.specify/`. The exact path (`.specify/orchestrator/` vs `.specify/extensions/orchestrator/`) needs final alignment (see Remaining Disputes), but the single-tree and under-`.specify/` constraints are universally agreed.

4. **Structural templates vs. filled artifacts is the correct ownership split.** spec-kit governs document shapes (templates, resolution stack, preset customization). Filled runtime artifacts are governed by whoever consumes them -- the orchestrator during execution, APM during distribution compilation.

5. **`requires.commands` in extension.yml is valuable.** Install-time command dependency validation provides a safety layer that complements APM's package-level checks and enables gh-aw fast-failure in CI.

6. **`/speckit.analyze` integration strengthens all three tools.** A concrete verification command with a predictable exit code serves spec-kit's hook system, APM's context validation, and gh-aw's `post-steps:` blocks simultaneously.

7. **Dual-channel distribution with spec-kit-first CI sequencing.** Publish to both catalogs. spec-kit installation comes first in CI because hooks and commands must be available before agent execution.

8. **The working tree is canonical in all execution modes.** CI persistence mechanisms (cache-memory, repo-memory, artifact upload) are transport layers, not storage layers. During execution, the agent reads from and writes to the working tree. This was gh-aw's most significant architectural concession and is now a shared invariant.

9. **Hook forward-compatibility with deferred interaction matrix.** Design for hook expansion. Document existing spec-kit hooks now. Add cross-system interaction documentation when APM hooks are integrated.

---

## Remaining Disputes

### Dispute 1: APM artifact discoverability timeline (P1 vs. P8)

**spec-kit's position**: APM compilation of orchestrator artifacts is a P8 concern. During P1-P7, the orchestrator writes phase summaries, decisions, and knowledge files to `.specify/orchestrator/` in whatever format serves its own dispatch logic. APM should not have a discovery path into these artifacts until the distribution packaging phase, because: (a) the orchestrator is a spec-kit extension whose artifacts live under `.specify/`, (b) `specify extension remove` must clean up everything the orchestrator installed, and artifacts symlinked or mirrored into `.apm/` would escape that cleanup, and (c) introducing APM discovery during P1-P7 creates a runtime dependency on APM being installed and configured.

**APM's counter-position**: Deferring APM discovery to P8 means APM's context optimization engine (deduplication, scope filtering, compilation) is unavailable during the entire period the orchestrator is being built and iterated. Phase summaries are the highest-value context artifacts in any orchestrated project. APM proposed a symlink from `.apm/context/orchestrator/` to `.specify/orchestrator/` managed by the orchestrator's own setup command, which would satisfy discovery without copying data.

**Why this survives two rounds**: The underlying tension is genuine. spec-kit prioritizes extension self-containment (everything the extension installs, it must clean up; no artifacts outside `.specify/`). APM prioritizes context discoverability (if high-value context exists, APM must be able to compile and distribute it). These are both legitimate architectural principles that conflict when applied to the same artifacts. Neither tool has proposed a mechanism that fully satisfies both constraints.

**spec-kit's hard stance**: No canonical artifacts outside `.specify/`. Any mechanism that places orchestrator state outside `.specify/` -- symlinks, mirrors, dual-writes -- must be owned and cleaned up by the orchestrator extension, not by APM. If the orchestrator creates a symlink at `.apm/context/orchestrator/`, the orchestrator's cleanup must remove it. This is the operational test for self-containment.

### Dispute 2: The exact canonical state path (`.specify/orchestrator/` vs `.specify/extensions/orchestrator/`)

**spec-kit's position**: `.specify/orchestrator/` (the spec's original design). This path does not follow spec-kit's extension convention, but the convention was designed for single-consumer extensions. The orchestrator has three consumers.

**APM's and gh-aw's counter-position**: Both adopted `.specify/extensions/orchestrator/` in their iteration 1 revisions, thinking they were conceding to spec-kit. Since spec-kit simultaneously withdrew in the opposite direction, the positions crossed.

**Why this survives**: This is a coordination problem, not a design disagreement. Both paths satisfy every stated constraint (single directory, under `.specify/`, static cache keys). The dispute is purely about which string all three tools commit to. spec-kit believes `.specify/orchestrator/` is correct because it explicitly signals that this extension's state has a wider audience than spec-kit alone. But spec-kit will accept `.specify/extensions/orchestrator/` if APM and gh-aw prefer consistency with the extension convention over the multi-consumer signal.

### Dispute 3: The "pluggable storage adapter" concept

**spec-kit's position**: The adapter pattern introduced in APM's revised Rec 2 (supporting three backends: spec-kit directory, `.apm/context/`, gh-aw `cache-memory`) is scope creep. It was not in the original spec, not in any tool's original review, and represents a substantial engineering commitment. P1-P6 should write phase summaries as plain files in `.specify/orchestrator/`. Adapter logic, if needed, belongs at P8.

**APM's counter-position**: APM proposed this adapter as the bridge between canonical storage and multi-tool discovery. Without it, APM cannot compile orchestrator artifacts until P8.

**spec-kit's assessment**: This dispute is a derivative of Dispute 1. If the discovery timeline dispute is resolved, the adapter concept either becomes unnecessary (if P8 discovery is accepted) or becomes a concrete P8 deliverable (if earlier discovery is negotiated). The adapter should not be specified as a P1 architectural commitment.

---

## Proposed Compromises

### Compromise for Dispute 1 (Discovery Timeline)

spec-kit proposes a tiered approach:

**P1-P6**: The orchestrator writes artifacts to `.specify/orchestrator/` in its own format. No APM discovery mechanism. APM is not a dependency during active orchestration. This preserves extension self-containment and ensures the orchestrator works identically with or without APM installed.

**P7 (CI integration)**: As part of the expanded P7 section that all three tools endorse, the CI workflow documentation includes a post-orchestration step where `apm compile` can optionally scan `.specify/orchestrator/` if APM is installed. This is not a symlink or mirror -- it is APM's own compilation step reading from a known path. The orchestrator does not create anything in `.apm/`; APM's compiler discovers artifacts at `.specify/orchestrator/` by convention. This satisfies APM's discovery need without the orchestrator touching APM's directory tree.

**P8 (Distribution)**: The hybrid APM package includes a proper integrator (APM's proposed `SpeckitOrchestratorIntegrator`) that transforms orchestrator artifacts into optimized APM context primitives for distribution.

This tiered approach gives APM compilation access from P7 (not P8) without introducing symlinks, mirrors, or artifacts outside `.specify/`. The key insight: APM's compiler can be taught to look in `.specify/orchestrator/` the same way it looks in `.apm/` -- this is a compiler configuration question, not an artifact placement question. The orchestrator does not need to know about APM at all.

### Compromise for Dispute 2 (Canonical Path)

spec-kit proposes that the spec author makes the final call between `.specify/orchestrator/` and `.specify/extensions/orchestrator/`. Both paths work. To break the tie, spec-kit recommends `.specify/orchestrator/` with the following justification committed to the spec:

> The orchestrator's state directory uses `.specify/orchestrator/` rather than `.specify/extensions/orchestrator/` because the orchestrator's state is consumed by multiple tools (spec-kit, APM, gh-aw) and the extension convention path was designed for single-consumer extensions. The `specify extension list` command discovers orchestrator state through the extension manifest's `state_dir` field rather than path convention.

If APM and gh-aw prefer `.specify/extensions/orchestrator/` for consistency, spec-kit will accept it. This is a path string, not an architecture.

### Compromise for Dispute 3 (Pluggable Storage Adapter)

Defer the adapter concept entirely. It is not needed if Compromise 1 is accepted (APM's compiler reads `.specify/orchestrator/` directly at P7). If APM determines at P8 that a more sophisticated transformation layer is needed for distribution packaging, that is a P8 implementation detail -- not a P1 architectural commitment that the orchestrator must build.

APM's proposed `SpeckitOrchestratorIntegrator` (built in APM's own `BaseIntegrator` framework) is the right implementation vehicle if an adapter is ever needed. It lives in APM's codebase, reads the orchestrator's output, and translates it into APM primitives. The orchestrator never needs to know it exists. This respects the spec's constraint that the orchestrator does not import or wrap APM.

---

## Lessons Across Iterations

**1. Withdrawals were the most productive moves in the entire process.** spec-kit withdrew 3 of 10 recommendations; APM withdrew 3 of 9. Every withdrawal was genuine, not cosmetic, and every withdrawal eliminated a real architectural conflict. The process worked because tools were willing to abandon "correct" advice that turned out to be single-tool correct. The willingness to withdraw -- not the quality of the original analysis -- determined convergence quality.

**2. The crossed-wires problem reveals that concurrent revision without synchronization creates new conflicts.** When spec-kit withdrew its Rec 3 (accepting `.specify/orchestrator/`) while APM and gh-aw adopted spec-kit's original Rec 3 (`.specify/extensions/orchestrator/`) as concessions, the three tools ended iteration 1 with an inconsistency that none intended. Multi-tool review processes need a mechanism for signaling withdrawals before counter-parties commit to concessions based on the withdrawn position.

**3. spec-kit's extension conventions are designed for a single-consumer world.** This was the most important lesson from iteration 1, and it deepened in iteration 2. The state layout convention, the config resolution stack, the preset override mechanism, and the extension directory hierarchy all assume spec-kit is the only tool that reads extension state. When an extension has multiple consumers, spec-kit's conventions become constraints rather than aids. This is not a flaw in the conventions -- they serve single-consumer extensions well. It is a recognition that the orchestrator is a qualitatively different kind of extension.

**4. "Authority boundary" framing masks lifecycle transitions.** The dual-authority model (spec-kit authoritative for extension machinery, APM authoritative for context primitives) initially seemed clean but obscured a real question: what happens when the same artifact transitions from one authority domain to another? Phase summaries are extension state during orchestration and context primitives during distribution. The lifecycle transition is the interesting question, not the static authority assignment. Future cross-tool designs should model artifact lifecycles rather than drawing static jurisdictional boundaries.

**5. CI execution constraints are architectural constraints, not deployment details.** gh-aw's hard stances -- single-directory state trees, static cache keys, one-phase-per-run scheduling, ephemeral runners requiring cold-start extension installation -- are not preferences. They are platform constraints of GitHub Actions agentic workflows. spec-kit's iteration 1 did not fully appreciate this. The one-phase-per-run model is not gh-aw's design choice; it is what the platform allows. Arguing against it is arguing against the execution environment, not against gh-aw's design judgment.

**6. The strongest convergence signals come from independent derivation of the same alternative.** Namespaced commands were independently proposed by APM (from a context deduplication angle) and gh-aw (from a deterministic verification angle). When two tools with completely different architectures arrive at the same solution for different reasons, that solution is almost certainly correct. Future reviews should weight independently-derived consensus higher than negotiated consensus.
