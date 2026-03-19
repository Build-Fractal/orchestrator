# spec-kit Iteration 1 Review of APM's Revised Position

## What Changed (APM: original -> revised)

APM's original UTILIZATION.md made 9 recommendations, all pushing the orchestrator to adopt APM primitives (`.prompt.md`, `.context.md`, `.instructions.md`, `SKILL.md`) as canonical formats from P1 onward. The revised position (`UTILIZATION.iteration_1.md`) makes the following material changes:

- **3 recommendations withdrawn** (Recs 1, 5, 9): Dispatch payloads as APM prompt files, `applyTo` for knowledge scoping, and mirroring `.specify/` into `.apm/context/`.
- **3 recommendations modified** (Recs 2, 3, 4): Phase summaries, boundary maps, and the runtime constraint all narrowed in scope. Canonical locations moved from `.apm/` to `.specify/extensions/orchestrator/`. APM formats relegated to build-time exports or P8 distribution transformations.
- **1 recommendation modified** (Rec 6): gh-aw integration split along a static/dynamic boundary.
- **2 recommendations unchanged** (Recs 7, 8): Optional `apm pack` for snapshots and hybrid package at P8.

The executive summary explicitly states: "APM belongs at the distribution and static context layer, not woven into the orchestrator's dynamic dispatch and knowledge management paths." This is a fundamental shift from the original position, which argued APM primitives should be adopted "from P1 onward rather than bolted on at P8."

---

## Contradictions Resolved

### DC-1 (original): Mirror `.specify/orchestrator/` into `.apm/context/` (Rec 9)

**Status: Genuinely resolved.**

APM withdrew this recommendation entirely, citing spec-kit's objection as "decisive." The revised position explicitly acknowledges: (a) the extension self-containment contract is a hard constraint, (b) artifacts in `.apm/context/orchestrator/` would be orphaned by `specify extension remove`, and (c) the split-brain concern is a real synchronization hazard. APM's proposed alternative -- handling APM discovery at P8 through the hybrid package's compilation step -- is exactly the resolution path spec-kit suggested.

This is a clean withdrawal with no hedging. The underlying architectural concern (APM artifact discovery) is deferred to P8 where it belongs, not smuggled back in through another mechanism.

### DC-3 (original): Use APM `applyTo` patterns for knowledge scope filtering (Rec 5)

**Status: Genuinely resolved.**

APM withdrew this recommendation and called it "the most clearly wrong recommendation in the original review." The revised position acknowledges the fundamental structural incompatibility spec-kit identified: `applyTo` is a static, build-time optimization that cannot serve per-dispatch dynamic scoping. APM's language here is unambiguous -- "the orchestrator must build its own scope-filtering logic (which is a core competency of an orchestration system, not something to outsource to a build tool)."

This withdrawal goes beyond simply accepting spec-kit's criticism. APM internalized the principle: the orchestrator's knowledge scoping is a runtime concern, not a build-time concern, and runtime concerns belong to the orchestrator, not to APM.

---

## Contradictions Unresolved

### DC-2 (original): Model dispatch payloads as APM `.prompt.md` files (Rec 1)

**Status: Withdrawn but partially resurrected through Rec 2.**

APM withdrew Rec 1 cleanly -- the revised position acknowledges that APM's `.prompt.md` format is the wrong abstraction for dynamic dispatch context assembly and that the format is invisible to spec-kit's command pipeline. This is a genuine withdrawal.

However, the revised Rec 2 introduces a subtler version of the same concern. The revised position states: "the `.context.md` format itself (structured Markdown with YAML frontmatter) is a sound authoring format for phase summaries regardless of where they are stored." While this is technically true (structured Markdown with frontmatter is a reasonable format for many things), the specific mention of `.context.md` as the format -- an APM primitive type name -- introduces normative pressure to adopt APM's format conventions even when the canonical location has been correctly moved to spec-kit's extension directory.

This is not a dangerous contradiction. The revised Rec 2 correctly places canonical storage under `.specify/extensions/orchestrator/` and correctly makes APM discovery a build-time export. But it does smuggle in APM's naming convention for the file format, which creates soft coupling: if the orchestrator names its files `.context.md` and structures them with APM-compatible frontmatter, it is de facto authoring APM primitives in spec-kit's directory tree. A future APM version could then "discover" them without the explicit build-time export step, eroding the boundary.

**Assessment**: The location and lifecycle concerns are resolved. The format naming creates a mild gravitational pull toward APM conventions that spec-kit should resist by using format-neutral file naming (e.g., `phase-summary.md` rather than `phase-summary.context.md`).

---

## New Concerns

### NC-1: The "pluggable storage adapter" pattern (Revised Rec 2) introduces unspecified complexity

The revised Rec 2 proposes "a pluggable storage adapter layer" that supports three backends: local spec-kit directory, `.apm/context/` for APM discovery, and gh-aw `cache-memory` for CI. This is an architecturally clean concept, but it is a substantial engineering commitment that was not present in either the original spec or in APM's original recommendation.

The original recommendation was simple (even if wrong): "put files in `.apm/context/`." The revised recommendation asks the orchestrator to build an abstraction layer over three different storage backends. This is feature scope creep introduced through the revision process. The orchestrator spec already has a simple, effective state model (disk-state-as-truth with files under a single directory tree). Adding a pluggable adapter layer to serve three different tool ecosystems' discovery mechanisms is a P8+ concern, not a P1 concern.

**Assessment**: The adapter pattern should be explicitly deferred. P1-P6 should write phase summaries as plain files in `.specify/orchestrator/`. P8 can add adapter logic if and when APM distribution requires it.

### NC-2: The static/dynamic split in Revised Rec 6 is sound but creates an implicit contract

The revised Rec 6 splits gh-aw integration along a static/dynamic boundary: APM's `dependencies:` field handles static context (constitution, coding standards), while gh-aw's native persistence handles dynamic context (phase summaries, decisions). This is a well-reasoned split.

The concern is that this split creates an implicit contract between APM and the orchestrator about what counts as "static" versus "dynamic." If a future orchestrator version wants to make coding standards phase-dependent (different standards for different phases), or if the constitution evolves during an orchestration run, the static/dynamic boundary shifts and the APM integration breaks. The split is not inherently wrong, but it needs to be documented as a versioned contract, not assumed as a permanent architectural truth.

### NC-3: The "Lessons Learned" section overstates APM's concessions in a way that frames future negotiations

APM's Lesson 2 states: "The host tool's conventions are the canonical conventions." This is a strong statement that, taken at face value, would mean spec-kit's conventions always win when there is a conflict. But this is immediately qualified by Lesson 3: "Static vs. dynamic is the correct integration boundary." This qualification reintroduces APM's jurisdiction over anything classified as "static context" -- which is a broad category that could expand over time.

The framing is: "spec-kit owns everything, except APM owns static context." That "except" clause is doing a lot of work. It is not a new concern per se (it follows logically from the revisions), but it is worth noting that APM has conceded the runtime/dispatch territory while staking a clear claim on the static context territory -- and the boundary between the two is not formally defined.

---

## Hard Stances (Non-Negotiable from spec-kit's Perspective)

### HS-1: Canonical artifact location must be within `.specify/`

APM's revised position correctly moves canonical locations to `.specify/extensions/orchestrator/`. This must remain non-negotiable. Any mechanism that places canonical orchestrator artifacts outside the `.specify/` tree -- whether through mirroring, symlinking, dual-writing, or "pluggable adapters" -- must treat the `.specify/` location as the source of truth and everything else as a derived export. APM accepted this in the revision, and spec-kit will hold them to it.

Note: spec-kit's own revised position (UTILIZATION.iteration_1.md) withdrew Rec 3, accepting that `.specify/orchestrator/` (the spec's original flat path) is superior to `.specify/extensions/orchestrator/` (the convention-correct path) for multi-tool compatibility. This is an area where spec-kit itself made a concession. The non-negotiable is that the path is under `.specify/`, not that it follows the extension subdirectory convention precisely. The exact path within `.specify/` is negotiable.

### HS-2: `specify extension remove` must clean up everything the orchestrator installed

This is the operational test for HS-1. If any artifact produced by the orchestrator survives `specify extension remove orchestrator`, the extension contract is broken. APM's revised position respects this (Rec 9 withdrawal explicitly cites this concern). The concern is that future revisions or P8 implementation could introduce artifacts outside `.specify/` that escape cleanup. This must remain a gate criterion for any APM integration proposal.

### HS-3: The orchestrator's dispatch mechanism must not depend on APM formats

APM withdrew Rec 1 (dispatch payloads as `.prompt.md`) and Rec 5 (`applyTo` for scoping). These withdrawals must be treated as permanent. The orchestrator's dispatch -- the most critical runtime path -- must use spec-kit-native or format-neutral mechanisms. If APM ever re-proposes format adoption for the dispatch path, spec-kit's position is unchanged: dispatch payloads must be expressible as spec-kit command files or format-neutral Markdown, not APM primitives with APM-specific frontmatter.

### HS-4: No build-time APM dependency in any critical runtime path

The revised Rec 4 states: "When APM is absent, all core orchestration functionality (dispatch, verification, recovery) must work without it." This is correct and non-negotiable from spec-kit's perspective. APM is an optional enhancement for distribution and static context management. The orchestrator must function identically -- not in a degraded mode, but identically for all P1-P7 functionality -- with or without APM installed. The only functionality that may require APM is P8 distribution packaging itself.

---

## Possible Compromises

### PC-1: APM-compatible frontmatter in phase summaries (meeting Revised Rec 2 halfway)

spec-kit can accept that phase summaries use structured YAML frontmatter with metadata fields (phase, milestone, timestamp, status, dependencies) as long as the frontmatter schema is defined by the orchestrator spec, not imported from APM's primitive type specification. If APM's `.context.md` frontmatter schema happens to be a superset of the orchestrator's schema, that is convenient for P8 but should not drive the orchestrator's design. The orchestrator defines its frontmatter; APM adapts at distribution time.

### PC-2: SKILL.md generation from boundary maps at P8 (Revised Rec 3)

APM's revised Rec 3 is acceptable as stated. Boundary maps in the orchestrator's own format, stored under `.specify/orchestrator/boundaries/`, with a build-time transformation to `SKILL.md` at P8. spec-kit has no objection to APM generating derivative artifacts from orchestrator data at distribution time, as long as the orchestrator's own format is not constrained by what SKILL.md can express.

### PC-3: Optional `requires.tools` declaration for APM (Revised Rec 4)

spec-kit can accept APM as an optional `requires.tools` entry in `extension.yml`. This means `specify extension add orchestrator` will emit a non-blocking warning if APM is not installed, but installation proceeds normally. The orchestrator may include an `speckit.orchestrator.setup` command that optionally invokes `apm install` when APM is detected. This is acceptable as long as no core orchestrator functionality is gated behind the APM setup step.

### PC-4: Static context via APM for CI (Revised Rec 6)

The static/dynamic split for gh-aw integration is a reasonable compromise. spec-kit can accept that APM's `dependencies:` field serves static context (constitution, coding standards, orchestrator instructions) in CI workflows, while dynamic context flows through gh-aw's native persistence. The condition is that the definition of "static" must be documented and versioned: if the boundary shifts, both tools must explicitly agree on the new boundary rather than APM unilaterally expanding the category.

### PC-5: Dual-channel distribution (Revised Rec 8)

spec-kit's own revised position (UTILIZATION.iteration_1.md, Revised Rec 8) already accepted dual-channel distribution with documented authority boundaries. spec-kit catalog is authoritative for extension machinery; APM is authoritative for context primitives. This is an area of genuine consensus. The remaining detail to nail down is the canonical installation sequence for CI, which should be documented once P7/P8 are implemented.

---

## Summary Assessment

APM's revision is substantive, not cosmetic. The three withdrawals (Recs 1, 5, 9) address the exact contradictions spec-kit flagged, and the reasoning demonstrates genuine internalization of the underlying principles rather than mere language softening. The "Lessons Learned" section articulates the correct boundary: APM belongs at distribution and static context, not at runtime dispatch.

The remaining concerns are second-order:

1. Format naming in Revised Rec 2 creates soft coupling (mild, manageable).
2. The pluggable adapter pattern is scope creep (should be deferred to P8).
3. The static/dynamic boundary is implicit and could drift (needs formal documentation).

None of these rise to the level of "dangerous contradiction." The iteration process worked: spec-kit flagged three genuine architectural violations, APM acknowledged all three, and the revised position draws a defensible boundary between APM's jurisdiction (static context, distribution) and spec-kit's jurisdiction (runtime dispatch, extension lifecycle, canonical artifact storage).

One note on symmetry: spec-kit's own revised position (UTILIZATION.iteration_1.md) withdrew 3 of its 10 recommendations (Recs 2, 3, 4) -- the exact same count as APM. Both tools withdrew their most prescriptive recommendations that attempted to claim exclusive jurisdiction over shared concerns (configuration format, state layout, command behavior). The iteration process produced genuine convergence, not unilateral capitulation by either side.
