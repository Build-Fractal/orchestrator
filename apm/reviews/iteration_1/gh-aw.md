# APM Iteration 1 Review of gh-aw's Revised Position

## What Changed (gh-aw: original -> revised)

gh-aw's original UTILIZATION.md made 10 recommendations. After cross-review, gh-aw withdrew 0, modified 5 (#1, #2, #3, #5, #6), and stood by 5 (#4, #7, #8, #9, #10).

The modifications all follow a single structural correction: gh-aw primitives are repositioned from **canonical storage/state locations** to **CI execution and durability mechanisms**. Specifically:

- **Rec 2**: `cache-memory` changed from "primary state persistence" to "durability layer that persists the working tree across ephemeral runners." The working tree (`.specify/extensions/orchestrator/`) is now canonical.
- **Rec 3**: `repo-memory` changed from "primary knowledge consolidation store" to "secondary durable backup." Knowledge consolidation now produces files in the working tree.
- **Rec 1**: `call-workflow`/`dispatch-workflow` changed from "the dispatch mechanism" to "the CI-mode implementation of an abstract dispatch interface."
- **Rec 5**: `post-steps:` changed from "the verification mechanism" to "a CI adapter for spec-owned verification commands."
- **Rec 6**: `stop-after`/`concurrency` changed from "the budget enforcement configuration" to "CI enforcement mechanisms consuming spec-kit-owned budget configuration."

gh-aw also added a "Lessons Learned" section containing five self-reflections, the most significant being: "gh-aw's review was too focused on 'what gh-aw can do' and not enough on 'what the spec needs.'"

## Contradictions Resolved

### DC-1 (cache-memory as primary state) -- GENUINELY RESOLVED

APM's original flag: Artifacts in `cache-memory` (mounted at `/tmp/gh-aw/cache-memory/`) are invisible to APM's primitive discovery engine. If orchestrator state lives there, APM cannot compile it.

gh-aw's revised position (Rec 2): The working tree is canonical. `cache-memory` is a durability layer with a defined lifecycle -- restore to working tree, execute, persist back. The CI run lifecycle is explicitly documented as: (1) restore `.specify/` tree from `cache-memory`, (2) execute reading/writing to working tree, (3) persist `.specify/` tree back to `cache-memory`.

**Assessment**: This is a genuine architectural concession, not a rewording. The revised model places artifacts where APM can find them (the working tree) during the execution window, and uses `cache-memory` only for transport between ephemeral runs. APM's discovery runs during step (2), when artifacts are in the working tree. The contradiction is resolved.

### DC-3 (repo-memory for knowledge consolidation) -- GENUINELY RESOLVED

APM's original flag: Orphan-branch storage is invisible to APM's working-tree-only discovery model. Two separate knowledge stores would require custom sync tooling.

gh-aw's revised position (Rec 3): Knowledge consolidation lives in the working tree (`.specify/extensions/orchestrator/consolidated/`). `repo-memory` is explicitly downgraded to "a disaster recovery mechanism, not a primary storage strategy." Any `repo-memory` content must be checked out into the working tree before other tools operate on it.

**Assessment**: This is a genuine withdrawal of the original position. gh-aw originally said "store compressed milestone summaries via `repo-memory` on a dedicated orphan branch" -- now it says "knowledge consolidation produces files in the working tree." The phrasing "backup" and "disaster recovery" makes the hierarchy unambiguous. The contradiction is resolved.

## Contradictions Unresolved

### DC-2 (one-phase-per-run model) -- PARTIALLY RESOLVED, CORE TENSION REMAINS

APM's original flag: The one-phase-per-run model makes APM's pre-authored `.prompt.md` dispatch model unusable. APM prompts are static templates with parameter slots; the one-phase-per-run pattern needs dynamically generated payloads.

gh-aw's revised position (Rec 8): "Stand (with important qualifications)." gh-aw argues the single-job execution model is a hard platform constraint, defends the one-phase-per-run architecture as the only viable Tier C CI model, but corrects the storage model per Rec 2. gh-aw adds a specific rebuttal: "the one-phase-per-run model does not require dynamically *generating* prompts. It requires dynamically *selecting* which pre-authored prompt to run based on the current phase state."

**Assessment of the rebuttal**: gh-aw's distinction between dynamic generation and dynamic selection is architecturally meaningful and partially addresses the concern. If the orchestrator pre-authors a prompt per phase (e.g., `research.prompt.md`, `implement.prompt.md`, `verify.prompt.md`) and each CI run selects one based on state, then APM's prompt system is usable -- the prompts are static, the selection is dynamic. This is a legitimate narrowing of the conflict.

However, APM must acknowledge a symmetry problem here. In APM's own iteration 1 revision (`UTILIZATION.iteration_1.md`), APM **withdrew Rec 1 entirely** (model dispatch payloads as APM prompt files), conceding that ".prompt.md format is designed for parameterized agent workflow templates, not for dynamic dispatch context assembly during autonomous execution." If APM withdrew its own recommendation to use `.prompt.md` for dispatch, it cannot simultaneously claim that gh-aw's model "makes APM's `.prompt.md` dispatch model unusable" -- APM itself has acknowledged that `.prompt.md` was the wrong abstraction for dispatch.

The remaining tension is narrower than originally flagged: it is not about whether `.prompt.md` works for dispatch (both sides now agree it does not), but about whether the one-phase-per-run model creates any new barriers for APM's surviving recommendations (Rec 7 pack, Rec 8 hybrid package). It does not. `apm pack` can snapshot state between campaign runs. The hybrid package provides static context at activation time. Neither requires multi-phase execution within a single run.

**Revised assessment**: The original "dangerous" rating was correct given the original positions, but APM's own withdrawal of Rec 1 removes the primary conflict. The one-phase-per-run model is **not dangerous to APM's revised position**. gh-aw's standing firm here is defensible. APM concedes this point.

## New Concerns

### NC-1: The "restore-execute-persist" lifecycle for cache-memory assumes APM compilation happens during the execution window

gh-aw's revised Rec 2 defines a CI lifecycle: (1) restore `.specify/` tree from cache, (2) execute, (3) persist back to cache. APM's primitive discovery and `apm compile` must run during step (2) for the resolution of DC-1 to hold.

But gh-aw's revised Rec 8 says each CI run "(a) restores the full `.specify/` working tree from cache, (b) installs/verifies the spec-kit extension, (c) advances one phase using whatever APM prompt or spec-kit command is appropriate, (d) persists the updated working tree back to cache."

There is no explicit step for `apm compile` in this lifecycle. If the orchestrator's hybrid package (Rec 8) needs compiled context, and `apm compile` must run on the restored working tree before phase execution, this must be documented as step (b.5) or similar. The revised position assumes APM discovery "just works" when artifacts are in the working tree, but `apm compile` is not automatic -- it must be explicitly invoked.

This is not dangerous, but it is an implementation gap in the revised lifecycle definition. gh-aw should specify when APM compilation occurs in the CI run sequence, or explicitly state that `apm compile` is handled by gh-aw's `dependencies:` activation (which runs APM resolution before the agent job starts).

### NC-2: The abstract dispatch interface (revised Rec 1) is underspecified

gh-aw's revised Rec 1 says the spec should define "an abstract dispatch interface" with gh-aw as one backend. This is architecturally sound but introduces a new design obligation that was not in the original recommendation. The original said "use `call-workflow`/`dispatch-workflow`" -- concrete and implementable. The revision says "define an abstract interface" -- a design task that could stall the spec if not scoped.

This is not a conflict with APM, but it is a risk the revision introduced. The abstract interface needs to be constrained enough that it can be specified in the P7 section without becoming a multi-sprint design effort.

## Hard Stances (Non-Negotiable from APM's Perspective)

### HS-1: The working tree must be canonical for all agent-consumable artifacts

This is the principle underlying all three original dangerous contradictions. gh-aw's revisions accept this principle for Recs 2 and 3. APM considers this resolved and non-negotiable going forward: any future gh-aw proposal that moves agent-consumable artifacts out of the working tree during the execution window will be rejected. The working tree is where APM discovers, compiles, and optimizes context. This is not negotiable.

gh-aw's revised position explicitly agrees: "The working tree remains canonical; gh-aw provides the mechanism for persisting that working tree across ephemeral CI runs." This is the correct formulation.

### HS-2: APM's hybrid package at P8 is the distribution integration point

Both tools' iteration 1 revisions agree that APM's value to the orchestrator is at the distribution boundary (Rec 8, universally supported). APM holds firm that the hybrid package model -- dual manifests (`extension.yml` + `apm.yml`), distribution through APM registries, static context injection via gh-aw `dependencies:` -- is the correct and sufficient APM integration point. APM will not accept proposals that require APM to be in the orchestrator's critical dispatch path.

This is a hard stance APM holds against itself as much as against gh-aw. APM's own withdrawn recommendations (1, 5, 9) all attempted to insert APM into the runtime dispatch path. APM accepts that this was wrong.

### HS-3: Build-time exports, not runtime mirroring, for APM discoverability

APM withdrew its own Rec 9 (mirror `.specify/` into `.apm/context/`) after spec-kit's decisive objection about extension self-containment. The replacement model -- build-time export at P8 that reads from spec-kit's canonical location and produces APM-discoverable output -- is APM's hard stance. No runtime mirroring, no symlinks, no dual-write for APM's benefit. If APM needs to discover orchestrator artifacts, it reads them from the working tree at compile time or generates them from the P8 package build.

## Possible Compromises

### PC-1: APM can accept the one-phase-per-run model without qualification

As analyzed in the "Contradictions Unresolved" section, APM's original objection to Rec 8 was predicated on APM's Rec 1 (`.prompt.md` for dispatch), which APM has since withdrawn. The one-phase-per-run model does not conflict with any of APM's surviving recommendations. APM can formally drop the "dangerous" rating on Rec 8 and accept it as the correct CI architecture for Tier C.

This is not a concession -- it is an acknowledgment that the original conflict no longer exists given both tools' revised positions.

### PC-2: APM can accept gh-aw's `cache-memory` as the CI durability mechanism without requiring APM-specific integration

gh-aw's revised cache lifecycle (restore -> execute -> persist) is sufficient for APM's needs. APM does not need `cache-memory` to have APM-aware serialization or special handling for `.apm/` directories. As long as the full `.specify/` tree (which may contain APM-generated artifacts from a prior `apm compile`) is restored to the working tree before execution, APM's compilation model works. APM will not request changes to gh-aw's cache implementation.

### PC-3: The CI run lifecycle could include an explicit APM compilation step as an optional optimization

Rather than requiring `apm compile` in the CI lifecycle (which would make APM a hard dependency), APM proposes: if the orchestrator is installed as a hybrid package (Rec 8), the CI lifecycle may optionally include an `apm compile` step between working-tree restoration and phase execution. This step regenerates optimized context files from the restored artifacts. If APM is not available, the orchestrator falls back to its own context assembly. This is consistent with APM's revised Rec 4 ("When APM is absent, all core orchestration functionality must work without it").

### PC-4: gh-aw's abstract dispatch interface should have a concrete minimum specification

To address NC-2, APM suggests the abstract dispatch interface be specified with at minimum: (a) an input schema (what data a dispatch payload must carry), (b) an output contract (what a completed dispatch must return), and (c) two reference implementations (local shell execution + gh-aw CI execution). This prevents the interface from becoming an open-ended design exercise while ensuring both local and CI execution paths are covered.
