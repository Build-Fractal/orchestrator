# gh-aw Iteration 1 Review of spec-kit's Revised Position

## What Changed (spec-kit: original -> revised)

spec-kit's revision (UTILIZATION.iteration_1.md) made the following structural changes to its original 10 recommendations:

- **Withdrew 3 recommendations** (Rec 2, 3, 4) -- the config format lock-in, the state directory scattering, and the preset-based command overriding. These were the exact three that gh-aw flagged as dangerous (gh-aw flagged Rec 3 and Rec 4; Rec 2 was flagged as a tension by gh-aw but as dangerous by APM, and spec-kit withdrew it based on the combined pressure).
- **Modified 4 recommendations** (Rec 1, 6, 8, 9) to add multi-tool awareness caveats.
- **Stood by 3 recommendations** (Rec 5, 7, 10) that both reviewers had marked as synergistic.

The Lessons Learned section is notably self-critical, with spec-kit explicitly acknowledging that its extension conventions "assume spec-kit is the only consumer" and that "the most dangerous recommendations were the most correct from a single-tool perspective."

## Contradictions Resolved

### Original Dangerous Contradiction #1: Preset-based command overriding (Rec 4) -- RESOLVED

gh-aw's original review flagged this as the most dangerous recommendation. A preset that silently overrides what `/speckit.specify` or `/speckit.plan` does at install time breaks gh-aw's deterministic verification model -- `steps:` and `post-steps:` depend on knowing exactly what runs between them, and invisible command mutation makes that impossible.

spec-kit's response: **Full withdrawal.** spec-kit explicitly states that "both reviewers flagged it as dangerous for completely different reasons" and that "both arrived at the same alternative: use namespaced commands." The revised position adopts namespaced commands (`speckit.orchestrator.specify`, `speckit.orchestrator.clarify`, `speckit.orchestrator.plan`) as the correct path. This is exactly what gh-aw asked for.

**Verdict: Genuinely resolved.** spec-kit did not soften the language -- it abandoned the recommendation entirely and adopted gh-aw's proposed alternative verbatim. The Lessons Learned section even acknowledges that the original review "should have given more weight to option (a) in Rec 4 rather than recommending option (b)." This is a real concession, not a reword.

### Original Dangerous Contradiction #2: State directory scattering (Rec 3) -- RESOLVED

gh-aw's original review flagged that scattering orchestrator state across `.specify/extensions/orchestrator/`, `.specify/specs/feature-a/orchestrator/`, `.specify/specs/feature-b/orchestrator/` would break gh-aw's `cache-memory` persistence model. gh-aw's cache keys are declared statically at compile time; dynamic feature-directory discovery is not viable.

spec-kit's response: **Full withdrawal.** spec-kit explicitly states that "this was the recommendation where both reviewers were most aligned in their opposition, and they are right." The revised position accepts the spec's original single-directory approach (`.specify/orchestrator/`) and acknowledges that gh-aw needs to "cache it as a unit with stable keys."

**Verdict: Genuinely resolved.** Again, not a softening -- a complete reversal. spec-kit accepts that its own extension convention (state under `.specify/extensions/{id}/`) is wrong for this case because "the orchestrator's state has a wider audience" than spec-kit alone.

## Contradictions Unresolved

Both of gh-aw's original dangerous contradictions were genuinely resolved. There are no unresolved contradictions from the original cross-review.

However, there is one **latent inconsistency** that emerged from the combination of spec-kit's Rec 3 withdrawal and gh-aw's own iteration 1 revision. spec-kit withdrew Rec 3 and accepted `.specify/orchestrator/` as the canonical state directory. But gh-aw's own revised Rec 2 (UTILIZATION.iteration_1.md, Rec 2 revised) states: "The `.specify/extensions/orchestrator/` directory (per spec-kit's extension convention) is the canonical state location in both local and CI modes."

This means gh-aw's revised position adopted spec-kit's *original* recommendation (`.specify/extensions/orchestrator/`) as canonical at the same time that spec-kit was withdrawing that recommendation in favor of `.specify/orchestrator/`. The two tools' revised positions now disagree on the state directory path:

- **spec-kit revised**: `.specify/orchestrator/` (the spec's original choice) -- because scattering across extension subdirectories breaks CI caching
- **gh-aw revised**: `.specify/extensions/orchestrator/` (spec-kit's original recommendation) -- adopted as a concession to spec-kit's extension conventions

This is a crossed-wires situation, not a genuine disagreement. Both tools moved toward the other's position and passed each other in transit. This needs to be reconciled in iteration 2, but it is not a hard impasse -- it is a coordination problem where the canonical path simply needs to be agreed upon once.

## New Concerns

### 1. spec-kit's Rec 1 modification introduces CI setup burden without specifying ownership

spec-kit's revised Rec 1 states that "CI workflows using gh-aw must include extension installation in their `steps:` block if they depend on preset-customized templates." This is accurate but creates an unspecified burden: who authors and maintains that `steps:` block? If the orchestrator spec ships a recommended gh-aw workflow template, that template needs to include `specify extension add orchestrator` (and any companion presets) in its `steps:` block. If it does not, every CI user reinvents this setup independently.

This is a new concern because the original Rec 1 did not mention CI at all. The modification adds CI awareness (good) but defers the implementation detail (who writes the `steps:` block) without assigning ownership.

**gh-aw's position**: The orchestrator spec's expanded P7 section (Rec 10, which spec-kit endorsed) should include a canonical `steps:` block for CI setup, including extension installation. This is a documentation requirement, not an architectural one.

### 2. spec-kit's Rec 8 modification ("publish to both channels") needs a CI-canonical designation

spec-kit's revised Rec 8 says "publish to both channels, but document which is authoritative for what." It specifies that "the spec-kit catalog is authoritative for the extension machinery" and "APM is authoritative for context primitives." But it does not specify which installation path is canonical for CI.

gh-aw's original concern was precisely this: "The spec needs to pick one canonical installation path for CI or support both explicitly." The revision acknowledges the concern but stops short of answering it. "Document a single canonical installation sequence in the workflow's `steps:` block that covers both" is the right direction, but does not say what that sequence is.

**gh-aw's position**: For CI via gh-aw, the canonical installation sequence should be: (1) `specify extension add orchestrator` (installs commands, hooks, templates), then (2) whatever APM step installs context primitives. The spec-kit catalog path comes first because hooks and template resolution must be available before the agent runs. This is a sequencing opinion, not a hard stance.

### 3. Hook interaction matrix (Rec 9 modification) may be over-engineering

spec-kit's revised Rec 9 adds a requirement for "a hook interaction matrix showing where both systems' hooks could fire during a single orchestrator operation." This is reasonable in principle but risks being speculative documentation. As of the current spec, the orchestrator does not use APM hooks at all -- it only uses spec-kit hooks (before_tasks, after_tasks, before_implement, after_implement). Documenting a hook interaction matrix for hypothetical APM hook interactions is premature until APM hooks are actually wired into the orchestrator.

**gh-aw's position**: Document the existing hook execution order (spec-kit hooks only). Add the interaction matrix when APM hooks are integrated. Premature cross-system documentation drifts faster than the implementation it describes.

## Hard Stances (Non-Negotiable from gh-aw's Perspective)

### 1. Namespaced commands over core command overrides -- CONFIRMED AND LOCKED

spec-kit's withdrawal of Rec 4 and adoption of namespaced commands is exactly the outcome gh-aw requires. This is now locked: the orchestrator MUST use `speckit.orchestrator.{command}` namespaced commands that call core SDD commands internally, never presets or any other mechanism that silently mutates core command behavior. This is non-negotiable because gh-aw's deterministic verification model (`steps:` -> agent work -> `post-steps:`) requires that what the workflow prompt says happens is what actually happens. Invisible command mutation at any layer is incompatible with CI auditability.

If spec-kit's preset system evolves in the future to support transparent wrapping (where the original command is guaranteed to run unmodified and the preset only adds pre/post context), gh-aw would reconsider. But as the preset system works today -- replacing core command template files at install time -- it is fundamentally incompatible with deterministic verification.

### 2. Single-directory state tree for static cache-key compatibility

The orchestrator's state must live in a single, predictable directory tree that can be addressed with a static cache key at compile time. Whether that path is `.specify/orchestrator/` or `.specify/extensions/orchestrator/` is negotiable (see the crossed-wires issue above). What is not negotiable is that it must be ONE path, not scattered across feature directories or split between extension and feature trees.

gh-aw's `cache-memory` keys are declared in workflow frontmatter and compiled into GitHub Actions YAML at build time. They cannot be dynamically computed at runtime. Any state layout that requires runtime discovery of which directories contain orchestrator state is incompatible with gh-aw's compilation model.

### 3. The single-job execution model is a platform constraint, not a design choice

spec-kit flagged gh-aw's Rec 8 (one-phase-per-run) as dangerous. gh-aw's iteration 1 stood by this recommendation with corrected implementation details. This remains non-negotiable because it is not gh-aw's preference -- it is a hard limitation of the GitHub Actions agentic workflow execution model. The orchestrator's multi-phase dispatch loop cannot run as a single agentic workflow. This is documented in gh-aw's own source (`create-agentic-workflow.md`, lines 131-149) as an explicit "CANNOT do" constraint.

spec-kit's concerns about hook session continuity and extension reinstallation per run are valid *implementation problems* that need solutions, but they do not change the platform constraint. The solutions (restore `.specify/` tree from cache, verify extension installation at run start) are spelled out in gh-aw's revised Rec 8 and are practical. The alternative -- pretending the dispatch loop can run in a single job -- would result in a CI integration that simply does not work.

## Possible Compromises

### 1. State directory path: gh-aw will accept spec-kit's convention if it is a single directory

As noted in the "Contradictions Unresolved" section, the two tools' revised positions crossed wires on the state directory path. gh-aw is willing to accept either `.specify/orchestrator/` or `.specify/extensions/orchestrator/` -- the specific path does not matter to gh-aw. What matters is that it is one path. If spec-kit decides to reinstate its extension convention (`.specify/extensions/orchestrator/`) as the canonical location, gh-aw will adopt it, provided there is no scattering across feature directories.

The compromise: spec-kit picks the path based on its extension conventions. gh-aw accepts whatever single path is chosen and uses it as the cache key root. The spec documents this as the canonical state directory for all three tools.

### 2. Template registration with documented CI setup requirements

spec-kit's modified Rec 1 (register templates in the extension's templates/ directory) is acceptable to gh-aw if the orchestrator spec includes a documented CI setup sequence in the P7 section. gh-aw does not object to template registration in principle -- it objects to undocumented CI setup dependencies. If the spec says "CI workflows must run `specify extension add orchestrator` in their `steps:` block before the agent executes," and the P7 section includes a reference workflow template showing this, gh-aw's concern is addressed.

### 3. Dual distribution channel with CI sequencing documented

spec-kit's modified Rec 8 (publish to both spec-kit catalog and APM) is acceptable if the P7 section documents the CI installation sequence. gh-aw's preference is spec-kit-first (because hooks and commands must be available before the agent runs), but gh-aw does not claim authority over installation ordering. If spec-kit and APM agree on a sequence, gh-aw will wire it into the recommended `steps:` block.

### 4. Hook interaction documentation can be deferred

gh-aw is willing to accept spec-kit's modified Rec 9 (forward-compatible hook design) without the hook interaction matrix, deferring that documentation until APM hooks are actually integrated into the orchestrator. This reduces speculative documentation burden while preserving the forward-compatibility principle.

### 5. Budget authority: gh-aw accepts spec-kit config as the single source

gh-aw's own iteration 1 already conceded that budgets should be defined in spec-kit's config system with gh-aw as the enforcement mechanism. This is not a new compromise -- it was already in gh-aw's revised Rec 6. Noting it here for completeness: gh-aw does not claim budget configuration authority. It claims budget enforcement authority in CI, reading values from whatever config the spec designates.
