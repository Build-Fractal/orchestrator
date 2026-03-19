# APM Utilization Review -- Iteration 2

## Position Evolution

### Original (UTILIZATION.md)
APM made 9 recommendations pushing the orchestrator to adopt APM primitives (`.prompt.md`, `.context.md`, `.instructions.md`, `SKILL.md`) as canonical formats from P1 onward, arguing that the spec underutilized APM's context management capabilities by deferring all APM involvement to P8. The position treated APM as a co-equal runtime participant rather than a build-time and distribution tool.

### Iteration 1 (UTILIZATION.iteration_1.md)
After cross-review from spec-kit and gh-aw, APM withdrew 3 recommendations (Recs 1, 5, 9), substantially modified 4 (Recs 2, 3, 4, 6), and stood by 2 (Recs 7, 8). The revision drew a clear boundary: APM belongs at the distribution and static context layer, not woven into the orchestrator's dynamic dispatch and knowledge management paths. Canonical artifact locations moved from `.apm/` to `.specify/extensions/orchestrator/`. APM conceded that build-time tools must not be prescribed for runtime problems.

### Iteration 2 (this document)
After reading spec-kit's and gh-aw's meta-reviews of the iteration 1 revision, and after conducting APM's own iteration 1 reviews of their positions, this document incorporates four categories of change:

1. **Locking genuine convergence.** Where both reviewers found APM's revisions genuine and complete, those positions are locked. This applies to the three withdrawals and the core principle that APM is a distribution/static-context tool.
2. **Addressing new concerns.** Both spec-kit and gh-aw raised new concerns about the pluggable adapter pattern (scope creep, ownership ambiguity), the static/dynamic boundary definition (implicit contract, no arbitration), and format naming (soft coupling through `.context.md` naming). These are addressed directly.
3. **Resolving self-contradictions.** APM's iteration 1 review of spec-kit identified that APM had conceded too much on the canonical location question -- accepting `.specify/extensions/orchestrator/` at the same time spec-kit was walking away from it. This incoherence is corrected.
4. **Formally retracting the "dangerous" rating on gh-aw Rec 8.** APM's withdrawal of Rec 1 removed the basis for objecting to the one-phase-per-run CI model. gh-aw correctly noted this retraction was implicit but never formalized.

---

## Current Recommendations (Final Positions)

### Rec 1: Dispatch payloads as APM prompt files
**Status**: Locked (Withdrawn)
**Position**: APM prompt files (`.prompt.md` with `${input:name}` substitution) are the wrong abstraction for the orchestrator's dispatch path. The orchestrator is a spec-kit extension; its dispatch payloads must use spec-kit's command format and be expressible as gh-aw JSON payloads for CI. APM prompt files solve a different problem -- parameterized agent workflow templates for human-initiated runs -- not dynamic, per-dispatch context assembly during autonomous execution.
**Cross-tool consensus**: Full agreement. spec-kit rated the original as dangerous (format invisible to CommandRegistrar), gh-aw rated it as dangerous (no mechanism to resolve APM prompt files at runtime). Both meta-reviews in iteration 1 confirmed the withdrawal as genuine and complete. No residual concern from any party.

---

### Rec 2: Phase summaries -- format and storage
**Status**: Modified (from iteration 1)
**Position**: Phase summaries should be authored as structured Markdown with YAML frontmatter metadata (phase, milestone, timestamp, status, dependencies). The **canonical location** is under the spec-owned orchestrator directory. The exact path -- `.specify/orchestrator/` versus `.specify/extensions/orchestrator/` -- should follow whatever spec-kit's own final position settles on. (See Remaining Disputes below for the path question.)

Format naming: APM drops the recommendation to name these files with the `.context.md` extension. spec-kit correctly identified that using an APM primitive type name as the file extension creates soft coupling -- a gravitational pull toward APM conventions that could allow future APM versions to "discover" them without an explicit export step. Phase summaries should use format-neutral naming (e.g., `phase-summary.md`, `{phase-name}-summary.md`). The format convention -- structured Markdown with YAML frontmatter -- is a shared convention, not an APM-owned format.

The "pluggable storage adapter" concept from iteration 1 is **deferred to P8**. spec-kit correctly flagged it as scope creep: it is a substantial engineering commitment that appeared in neither the original spec nor the original review. For P1-P6, phase summaries are plain files in the spec-kit-owned directory. For P7, gh-aw's `cache-memory` handles CI durability by restoring/persisting the full `.specify/` tree. For P8, if APM distribution requires artifact discovery, the hybrid package build step reads from the canonical location.

**Cross-tool consensus**: Converged. spec-kit accepts structured Markdown with frontmatter as long as the schema is defined by the orchestrator spec, not imported from APM's primitive type specification (PC-1 in spec-kit's review). gh-aw accepts the format convention as long as files are plain text readable without APM tooling (PC-3 in gh-aw's review). APM drops the `.context.md` naming and defers the adapter. The remaining disagreement is only about the canonical path (see Remaining Disputes).

---

### Rec 3: Boundary maps -- orchestrator-native format with P8 SKILL.md generation
**Status**: Locked (Modified from original, stable since iteration 1)
**Position**: Boundary maps should be authored in whatever format best serves the orchestrator's dispatch planning and mechanical verification needs, stored under the spec-kit-owned orchestrator directory. At P8, a build-time transformation step in `apm pack` generates `SKILL.md` files from boundary maps, making phase outputs discoverable through APM's skill system for distribution consumers. The orchestrator never needs to parse or produce APM's SKILL.md format during its own operation.
**Cross-tool consensus**: Full agreement. spec-kit has no objection to build-time SKILL.md generation at P8 (PC-2 in spec-kit's review). gh-aw is neutral -- this is a distribution concern that does not affect CI execution (PC-4 in gh-aw's review). No party contests this position.

---

### Rec 4: Narrowing the "no APM at runtime" constraint
**Status**: Locked (Modified from original, stable since iteration 1)
**Position**: The spec's blanket "Must not import or wrap APM at runtime" should be replaced with: "The orchestrator must not require APM to be installed in dispatched agent environments. The orchestrator MAY declare APM as an optional `requires.tools` dependency in `extension.yml`. When APM is available, the orchestrator's setup commands MAY invoke `apm install` and `apm compile` for enhanced context management. When APM is absent, all core orchestration functionality (dispatch, verification, recovery) must work without it."
**Cross-tool consensus**: Converged. spec-kit accepts APM as an optional `requires.tools` entry with non-blocking warnings (PC-3 in spec-kit's review; HS-4 reinforces that identical P1-P7 functionality without APM is non-negotiable). gh-aw accepts this framing, with the condition that `dependencies:` resolution is a one-time, pre-job operation in CI.

---

### Rec 5: APM `applyTo` patterns for knowledge scope filtering
**Status**: Locked (Withdrawn)
**Position**: `applyTo` is a static, build-time optimization that fundamentally cannot serve the orchestrator's need for dynamic, per-dispatch knowledge scoping. The orchestrator's knowledge scope changes with every dispatch cycle based on current phase, milestone, and task context -- information that does not exist at compilation time. The orchestrator must build its own scope-filtering logic. This is a core competency of an orchestration system, not something to outsource to a build tool.
**Cross-tool consensus**: Full agreement. Both meta-reviews confirmed this as the strongest concession in the revision. spec-kit noted APM articulated the structural reason better than the original cross-review did. No party contests this position.

---

### Rec 6: gh-aw integration -- static/dynamic split
**Status**: Modified (from iteration 1)
**Position**: The P7 CI story should split along the static/dynamic boundary:
- **Static context** (instructions, constitution, coding standards): Served via APM's `dependencies:` field in gh-aw workflow frontmatter, using the orchestrator's hybrid APM package from Rec 8. This runs once at activation time, before the agent job, and produces static files.
- **Dynamic context** (phase summaries, decisions, task-specific knowledge): Served via gh-aw's native persistence -- `cache-memory` for ephemeral cross-run state, `repo-memory` for durable milestone state. The orchestrator does not attempt to vary APM package contents between dispatches.

Two refinements from iteration 1 feedback:

First, the static/dynamic boundary must be **documented as a versioned contract**, not assumed as permanent. spec-kit correctly identified (NC-2) that if constitution or coding standards ever become phase-dependent, the boundary shifts and the integration breaks. APM proposes: the orchestrator spec should include a table defining which artifact categories are "static" (resolved once per orchestration campaign, invariant across dispatches) and which are "dynamic" (varying per dispatch). Changes to this table constitute a breaking change that requires updating both the APM hybrid package and the gh-aw workflow templates.

Second, the temporal dependency on Rec 8 is acknowledged. gh-aw correctly noted that the `dependencies:` integration path does not exist until the hybrid APM package ships at P8. Before P8, CI workflows cannot use `dependencies:` with the orchestrator's APM package. For P7, the static context must be provided through a different mechanism -- either committed to the repo directly or bundled into the workflow definition.

**Cross-tool consensus**: Converged on the split itself. spec-kit accepts the split with the condition that "static" is formally defined (PC-4 in spec-kit's review). gh-aw fully accepts `dependencies:` for static context and contributed the one-time pre-job condition (PC-1 in gh-aw's review). The versioned-contract proposal is new in iteration 2 and addresses both tools' concerns.

---

### Rec 7: `apm pack` for optional milestone snapshots
**Status**: Locked (Unchanged across all iterations)
**Position**: `apm pack` is an optional, supplementary snapshot mechanism for cross-machine state sharing and archival. The orchestrator's primary crash recovery remains the lightweight disk-state-as-truth model (lock files, stale detection, continue files, recovery briefings). `apm pack` adds value for sharing partially-completed orchestration state across machines or CI environments. APM bundles stored via gh-aw's `repo-memory` `upload-asset` pattern provide both APM-compatible unpacking and git-backed durability.
**Cross-tool consensus**: Full agreement. spec-kit accepts as optional (not in the critical recovery path). gh-aw accepts as complementary to `repo-memory`. No party contests this position.

---

### Rec 8: Hybrid APM package at P8
**Status**: Locked (Unchanged, universally supported)
**Position**: At P8, the orchestrator should be packaged with `type: hybrid` in `apm.yml`, shipping both as compilable instructions (for `AGENTS.md`) and as an installable skill (the orchestrator's SKILL.md). The package ships dual manifests (`extension.yml` for spec-kit, `apm.yml` for APM) and includes hooks for multi-runtime deployment. This expands distribution reach through APM registries, enables gh-aw's `dependencies:` field for static context injection, and requires zero changes to spec-kit's extension model.

The P8 build step is where APM adds unique value: it reads orchestrator artifacts from the canonical spec-kit location, transforms boundary maps into SKILL.md files, and produces optimized compiled context for downstream agents. The hybrid package must actually compile orchestrator artifacts into optimized agent context -- not merely ship the extension files in a tarball. This requires that orchestrator artifacts are in a parseable format (structured Markdown with frontmatter, at minimum) and stored in a location APM can read during the build.

**Cross-tool consensus**: Full agreement. This is the most universally supported recommendation across all three tools and all iterations. spec-kit accepts dual-channel distribution with documented authority boundaries. gh-aw sees it as enabling `dependencies:` integration. Both meta-reviews confirmed this without reservation.

---

### Rec 9: Mirror `.specify/` into `.apm/context/`
**Status**: Locked (Withdrawn)
**Position**: Mirroring, symlinking, or dual-writing orchestrator artifacts into `.apm/context/` is rejected. It breaks spec-kit's extension self-containment contract (`specify extension remove` cannot clean up artifacts outside `.specify/`), creates split-brain synchronization hazards, and is architecturally unnecessary given that the P8 hybrid package build step can read from the canonical location at build time.
**Cross-tool consensus**: Full agreement. spec-kit's objection was decisive and APM accepted it without hedging. Both meta-reviews confirmed the withdrawal as genuine and complete.

---

## Convergence Points

After two iterations, the three tools agree on the following positions:

1. **APM is a distribution and static context tool, not a runtime dispatch participant.** APM's value to the orchestrator is at the packaging boundary (P8) and for static context injection (constitution, coding standards, orchestrator instructions). APM has no role in per-dispatch context assembly, dynamic knowledge scoping, or runtime artifact synchronization.

2. **The orchestrator's canonical artifacts live under `.specify/`.** Whether the exact path is `.specify/orchestrator/` or `.specify/extensions/orchestrator/` is still under discussion (see Remaining Disputes), but all three tools agree the path must be under `.specify/` and must be fully cleaned up by `specify extension remove`.

3. **The hybrid APM package at P8 is the correct and sufficient integration point.** Dual manifests, dual distribution channels, build-time transformation of orchestrator artifacts into APM primitives. No tool contests this.

4. **`apm pack` is supplementary, not critical-path.** Optional milestone snapshots and archival, complementary to gh-aw's `repo-memory`.

5. **The static/dynamic split governs CI integration.** APM's `dependencies:` for static context, gh-aw's `cache-memory`/`repo-memory` for dynamic context. The split needs formal documentation but the architectural principle is agreed.

6. **gh-aw's one-phase-per-run is the correct Tier C CI model.** APM formally retracts its "dangerous" rating. The withdrawal of Rec 1 removed the source of the conflict; the one-phase-per-run model does not conflict with any of APM's surviving recommendations.

7. **The orchestrator defines its own formats; APM adapts at distribution time.** Phase summaries, boundary maps, and knowledge files use whatever format the orchestrator needs. APM reads and transforms at the P8 build step. APM does not dictate canonical format or naming.

8. **No APM dependency in the critical dispatch path.** The orchestrator functions identically for P1-P7 with or without APM installed. APM is optional via `requires.tools`.

---

## Remaining Disputes

### Dispute 1: Canonical artifact path -- `.specify/orchestrator/` vs. `.specify/extensions/orchestrator/`

**The problem**: APM's iteration 1 revision adopted `.specify/extensions/orchestrator/` as the canonical location for phase summaries and boundary maps (Revised Recs 2, 3). But spec-kit's own iteration 1 revision *withdrew* its Rec 3 (which had proposed `.specify/extensions/orchestrator/`), conceding that the spec's original `.specify/orchestrator/` flat path is superior for multi-tool compatibility. APM accepted a position that spec-kit itself was walking away from.

**APM's hard stance**: The exact path within `.specify/` is not APM's primary concern. APM's concern is that whatever path is chosen, it must be stable, documented, and accessible to APM's build step at P8. APM defers to spec-kit on the precise path, but notes the iteration 1 positions are incoherent and need reconciliation. spec-kit's own meta-review (HS-1) clarifies: "The non-negotiable is that the path is under `.specify/`, not that it follows the extension subdirectory convention precisely. The exact path within `.specify/` is negotiable." APM accepts this framing.

**Counter-positions**: spec-kit prefers `.specify/orchestrator/` for multi-tool simplicity. gh-aw has no strong opinion on the path as long as the full `.specify/` tree is restored from `cache-memory` in CI.

**Gap**: Narrow. This is a naming decision, not an architectural one. It should be resolved by the spec author, not by the tools.

### Dispute 2: APM discovery of orchestrator artifacts before P8

**The problem**: If orchestrator knowledge artifacts (phase summaries, decisions, boundary maps) are canonically stored under `.specify/` and APM cannot discover them until the P8 build step, then APM's context optimization engine provides zero value during P1-P7 -- the period when the orchestrator is being built and iterated.

**APM's hard stance**: APM must have *some* discovery path for orchestrator knowledge from P1, not just P8. This does not require artifacts to be stored in `.apm/`. It requires a defined mechanism -- even a simple one -- that makes orchestrator knowledge visible to `apm compile` during development. APM's iteration 1 review of spec-kit proposed three concrete mechanisms:
1. A symlink from `.apm/context/orchestrator/` to the canonical `.specify/` path, created and managed by the orchestrator extension's own setup command and removed by its cleanup. This satisfies spec-kit's self-containment requirement (the extension owns the symlink lifecycle), APM's discovery requirement (the path exists), and single-source-of-truth (no copied data).
2. An APM integrator (`SpeckitOrchestratorIntegrator`) that reads artifacts from the canonical `.specify/` location during `apm compile` and processes them into APM's compilation output. The orchestrator does not need to know about APM at all -- APM reads the orchestrator's output unilaterally.
3. A convention where `apm compile` accepts a `--include-paths` flag or config entry that tells it to scan additional directories beyond `.apm/`.

**Counter-positions**: spec-kit insists that artifacts outside `.specify/` must be extension-managed and cleaned up by `specify extension remove` (HS-1, HS-2). spec-kit also insists on no build-time APM dependency in any critical runtime path (HS-4), though APM notes that `apm compile` is not a runtime path -- it is a developer tool that runs when the developer chooses. gh-aw has no stake in this dispute (it only matters for local development, not CI).

**Gap**: Medium. The principle is agreed (APM should be able to compile orchestrator context when present). The mechanism is not. Option 2 (APM integrator that reads from `.specify/` at compile time) is the least invasive -- it requires no changes to the orchestrator or to spec-kit's extension contract, only an APM-side enhancement. APM believes this should be the resolution path.

### Dispute 3: Ownership of the pluggable storage adapter

**The problem**: APM's iteration 1 proposed a "pluggable storage adapter" that mirrors artifacts between spec-kit's canonical location, APM's discovery path, and gh-aw's `cache-memory`. Both meta-reviews flagged this as underspecified and load-bearing. spec-kit called it scope creep (NC-1). gh-aw noted that no tool is taking ownership of building it (NC-1).

**APM's current position**: The adapter as originally conceived is withdrawn as a P1 concern. For P1-P6, there is no adapter -- files live in `.specify/` and are read directly. For P7 CI, gh-aw's restore-execute-persist lifecycle handles the `.specify/` tree without any adapter. The remaining question is only about P8 distribution.

At P8, if the adapter is needed, APM takes ownership of the APM-discovery piece through the integrator mechanism (Dispute 2 above). gh-aw offered to contribute a `cache-memory` adapter specification (PC-5 in gh-aw's review). spec-kit contributes the canonical storage contract (what lives where and in what format).

**Counter-positions**: spec-kit wants the adapter deferred entirely to P8. gh-aw is willing to contribute the `cache-memory` specification if the adapter is built. Both agree the adapter should not be a P1 concern.

**Gap**: Narrow. All three tools agree on deferral. The remaining question is who builds what at P8, which is a P8 planning concern, not a design dispute.

### Dispute 4: Dual-authority arbitration for phase summaries

**The problem**: spec-kit's modified Rec 8 declares a dual-authority model -- spec-kit is authoritative for extension machinery, APM is authoritative for context primitives. Phase summaries sit in both categories: they are extension state (the orchestrator reads and writes them during dispatch) and they are agent-consumable context (downstream agents need them for decision-making). Under the dual-authority model, which tool governs phase summaries?

**APM's position**: The mold-vs-casting split resolves this cleanly. spec-kit governs the *templates* (document shapes, structural schemas) and the *lifecycle* (creation, storage, deletion tied to `specify extension remove`). APM governs the *filled artifacts* once they are produced -- compilation, optimization, and distribution of agent-consumable content. spec-kit owns the mold; APM works with the casting. This maps to the dual-authority model without jurisdictional overlap.

**Counter-positions**: spec-kit has not explicitly accepted or rejected the mold/casting framing. gh-aw has no stake (phase summaries in CI are handled by cache-memory regardless of which tool claims authority).

**Gap**: Medium. The framing is proposed but not agreed. It needs explicit acceptance from spec-kit to close.

---

## Proposed Compromises

### Compromise 1: APM builds an integrator for `.specify/` discovery, no changes required from spec-kit or the orchestrator

To resolve Dispute 2, APM proposes building a `SpeckitOrchestratorIntegrator` within APM's own `BaseIntegrator` framework. This integrator would:
- Discover orchestrator artifacts at the canonical `.specify/` location during `apm compile`.
- Process them into APM's compilation output (AGENTS.md, scoped context) alongside all other project context.
- Require no changes to the orchestrator's code, spec-kit's extension contract, or the `.specify/` directory layout.
- Operate unilaterally: the orchestrator does not need to know about APM. APM reads the orchestrator's artifacts because they are files on disk. No symlinks, no mirroring, no dual-write.
- Degrade gracefully: if `.specify/orchestrator/` does not exist, the integrator does nothing.

This respects spec-kit's HS-1 (canonical location stays under `.specify/`), HS-2 (`specify extension remove` cleans up everything because APM never writes to `.specify/`), and HS-4 (no APM dependency in the critical path). It gives APM P1 discovery without requiring any cooperation from spec-kit.

### Compromise 2: Defer the storage adapter to P8 with explicit ownership assignments

To resolve Dispute 3, all three tools agree: no adapter before P8. At P8 planning time, the work is split along tool expertise:
- APM builds the `.apm/context/` adapter (reading from `.specify/` at build time).
- gh-aw contributes the `cache-memory` adapter specification (serialization format, cache key naming, restore/persist lifecycle).
- spec-kit documents the canonical storage contract (what artifacts exist, where they live, what their schemas are).

This distributes design work to each tool's domain and prevents the adapter from becoming an unowned obligation.

### Compromise 3: Formalize the static/dynamic boundary as a table in the spec

To resolve the implicit contract concern in Rec 6, APM proposes that the orchestrator spec include an artifact classification table:

| Artifact | Classification | Rationale |
|----------|---------------|-----------|
| Constitution | Static | Set once per orchestration campaign, invariant across dispatches |
| Coding standards | Static | Project-level, not phase-dependent |
| Orchestrator instructions | Static | Describe the orchestrator's own behavior, not per-task |
| Phase summaries | Dynamic | Updated at every phase transition, consumed per-dispatch |
| Decisions register | Dynamic | Accumulates during orchestration, queried per-dispatch |
| Per-task knowledge | Dynamic | Assembled dynamically for each dispatch |
| Boundary maps | Dynamic | Evolve as phases complete, consumed by downstream phases |

Changes to this table are a breaking change to the APM/gh-aw integration and require updating both the hybrid package and CI workflow templates. This gives the static/dynamic split formal standing rather than leaving it as an implicit assumption.

### Compromise 4: Accept spec-kit's template authority, claim filled-artifact compilation

To resolve Dispute 4, APM formally proposes the mold/casting split as the arbitration rule for the dual-authority model:
- **spec-kit authority**: Structural templates (document shapes), lifecycle (creation/storage/deletion), extension contract compliance.
- **APM authority**: Compilation and distribution of filled artifacts -- once the orchestrator produces a phase summary by filling in a template, that filled artifact is agent-consumable context and falls under APM's compilation jurisdiction when APM is present.

This is not a new claim -- it is the logical conclusion of the universally agreed Rec 8 (hybrid package compiles orchestrator artifacts). The compromise simply extends the same principle to pre-P8 `apm compile` runs during development.

---

## Lessons Across Iterations

### 1. Genuine withdrawals build more credibility than strategic concessions

APM's three withdrawals in iteration 1 (Recs 1, 5, 9) were the most effective moves in the entire review process. Both meta-reviews explicitly noted the quality of the reasoning behind the withdrawals -- particularly Rec 5, where APM articulated the structural flaw better than the original cross-reviews did. The lesson: withdrawing a bad recommendation with clear reasoning about *why* it was wrong builds more trust than defending it with caveats.

### 2. Conceding too much creates incoherence

APM's iteration 1 accepted `.specify/extensions/orchestrator/` as the canonical location at the same time spec-kit was withdrawing its own recommendation for that path. Over-conceding to avoid conflict produced a contradictory position. The lesson: each revision must be grounded in the tool's own architectural needs, not in a desire to accommodate every critique. Accommodation without analysis leads to positions no tool actually holds.

### 3. The static/dynamic boundary is the most important architectural decision in the spec

This emerged as the core organizing principle across all three tools' revisions. APM owns static context. gh-aw owns CI execution and dynamic persistence. spec-kit owns the orchestrator's runtime behavior and extension contract. Virtually every dispute can be resolved by asking "is this artifact static or dynamic?" The boundary needs formal definition (see Compromise 3), but the principle is the single most valuable outcome of the two-iteration process.

### 4. APM's unique value is at the distribution boundary, and that is enough

The universal agreement on Rec 8 confirms that APM does not need to be in the orchestrator's runtime path to add significant value. Distribution, context compilation, multi-runtime deployment, registry discoverability -- these are substantial capabilities that neither spec-kit nor gh-aw provides. The original review's mistake was trying to extend APM's reach into runtime dispatch, diluting the strong message about distribution value with weak claims about runtime involvement.

### 5. Attribution matters in multi-tool negotiations

gh-aw correctly noted (NC-2 in its meta-review) that APM's "Lessons Learned" attributed a consensus that only spec-kit drove. APM's Lesson 2 ("the host tool's conventions are canonical") was spec-kit's argument, not gh-aw's. gh-aw's constraints are about CI execution mechanics, not convention primacy. Going forward, APM will be precise about which tool's feedback drove which revision, rather than framing all feedback as a unified consensus.

### 6. The review process works when tools engage with structural arguments, not just preferences

The two iterations produced genuine convergence because all three tools engaged with the *structural* reasons behind disagreements -- static vs. dynamic, build-time vs. runtime, canonical vs. derived -- rather than arguing from tool-preference alone. The strongest moments in the process were when a tool acknowledged a structural flaw in its own reasoning (APM on Rec 5, spec-kit on Rec 3, gh-aw on Recs 2/3). The weakest moments were when tools defended positions by restating their own capabilities rather than engaging with the architectural constraint being raised.
