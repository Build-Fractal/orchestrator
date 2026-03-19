# gh-aw Iteration 1 Review of APM's Revised Position

## What Changed (APM: original --> revised)

APM made significant structural changes to its position. Here is the factual diff:

| Rec | Original | Revised | Nature of Change |
|-----|----------|---------|------------------|
| 1 | Model dispatch payloads as `.prompt.md` files with `${input:name}` | **Withdrawn** | Full concession |
| 2 | Write phase summaries as `.context.md` in `.apm/context/phases/` | Canonical location moved to `.specify/extensions/orchestrator/`. `.context.md` format retained as recommendation. Pluggable adapter for APM discovery at build time. | Substantive modification |
| 3 | Write boundary maps as `SKILL.md` in `.apm/skills/{phase-name}/` | Orchestrator picks its own native format. `SKILL.md` generation deferred to P8 build-time transformation. | Substantive modification |
| 4 | Narrow "no APM at runtime" constraint | APM declared optional via `requires.tools`. Core functionality must work without APM. | Substantive modification |
| 5 | Use `applyTo` patterns for knowledge scope filtering | **Withdrawn** | Full concession |
| 6 | Reference APM's gh-aw integration for P7 | Split into static (APM via `dependencies:`) and dynamic (gh-aw native persistence) paths. | Substantive modification |
| 7 | `apm pack` for milestone snapshots | **Unchanged** -- "optional, supplementary" language made explicit | Clarification only |
| 8 | Hybrid APM package at P8 | **Unchanged** | No change |
| 9 | Mirror `.specify/` into `.apm/context/` | **Withdrawn** | Full concession |

**Summary**: 3 withdrawn, 4 substantively modified, 2 unchanged. This is a genuine revision, not a cosmetic reword.

## Contradictions Resolved

### DC-1 (APM Rec 1: dispatch payloads as `.prompt.md`) -- RESOLVED

gh-aw flagged this as dangerous because `.prompt.md` with `${input:name}` substitution would require APM CLI at dispatch time, and gh-aw has no mechanism to discover or resolve APM prompt files. APM withdrew entirely, stating: "Both reviewers correctly identify that this recommendation asks the orchestrator to adopt an APM-specific format for its most critical runtime path."

This is a clean resolution. APM did not soften the language -- it acknowledged the structural incompatibility and removed the recommendation. The revised position explicitly recognizes that APM prompt files "solve a different problem (parameterized agent workflow templates for human-initiated runs) than what the orchestrator needs (dynamic, per-dispatch context assembly during autonomous execution)."

**Verdict**: Genuinely resolved. No residual concern.

### DC-2 (APM Rec 5: `applyTo` patterns for knowledge scope filtering) -- RESOLVED

gh-aw flagged this as dangerous because `applyTo` is static, build-time scope filtering that cannot vary per-dispatch in the single-job model. APM withdrew entirely, calling it "the most clearly wrong recommendation" and correctly identifying the root flaw: "APM's `applyTo` compilation is a static, build-time optimization that cannot serve the orchestrator's need for dynamic, per-dispatch knowledge scoping."

This is the strongest concession in the document. APM not only withdrew but articulated the structural reason better than the original cross-review did.

**Verdict**: Genuinely resolved. No residual concern.

### DC-3 (APM Rec 6: inversion of dependency direction via `dependencies:` + `isolated`) -- PARTIALLY RESOLVED

gh-aw flagged this as dangerous because `dependencies:` + `isolated: true` resolves a fixed set of APM primitives at activation time and cannot express per-dispatch context variation. APM's revision splits the recommendation along the static/dynamic boundary: use `dependencies:` for static context (instructions, constitution, coding standards), and use gh-aw's native persistence for dynamic context (phase summaries, decisions, per-task knowledge).

The static/dynamic split is the right architectural move. However, the resolution introduces a dependency on Rec 8 (hybrid package at P8) being completed first -- worker workflows can only use `dependencies:` with the orchestrator's APM package after P8 ships. Before P8, the `dependencies:` integration path does not exist. APM's revised Rec 6 reads as if this capability is available now, but it is gated on P8.

**Verdict**: Architecturally resolved. The static/dynamic boundary is correct. The temporal dependency on P8 should be acknowledged but is not a blocking concern.

## Contradictions Unresolved

There are no unresolved contradictions from the original three dangerous flags. All three received genuine treatment. However, there is one tension that persists from the original review cycle and was not fully addressed by the revision:

### Persistent Tension: One-phase-per-run model (APM's original "Dangerous" rating of gh-aw Rec 8)

In its cross-review of gh-aw's recommendations (the `UTILIZATION.md_reviews/gh-aw.md` file), APM rated gh-aw's Rec 8 (one-phase-per-run model) as "Dangerous" because it "Makes APM's pre-authored `.prompt.md` dispatch model unusable; requires dynamically generated payloads per run."

APM's revised UTILIZATION document (iteration 1) does not revisit this rating. It withdraws Rec 1 (which was the `.prompt.md` dispatch recommendation) but never explicitly reconciles the withdrawal of Rec 1 with its dangerous-rating of gh-aw's Rec 8. The logic chain should be: if APM no longer proposes `.prompt.md` for dispatch, then APM's objection to one-phase-per-run (which was based on incompatibility with `.prompt.md`) should also be withdrawn. But this is not stated.

gh-aw's own revised position (iteration 1) addressed this by clarifying that one-phase-per-run does not require dynamically *generating* prompts -- it requires dynamically *selecting* which pre-authored prompt to run. This distinction matters and APM's revision does not engage with it.

This is not a blocking concern for gh-aw because APM's withdrawal of Rec 1 effectively removes the source of the conflict. But the cross-review rating was never formally retracted, which could cause confusion in subsequent iterations.

## New Concerns

### NC-1: The pluggable adapter pattern (Revised Recs 2 and 6) risks becoming a design-time agreement that never gets built

APM's revised Recs 2 and 6 both rely on a "pluggable storage adapter" that mirrors artifacts between the canonical spec-kit location and both APM discovery paths and gh-aw cache-memory. This adapter appears in three places across the revision:

- Rec 2: "provide a pluggable adapter layer that can mirror them to `.apm/context/` for local APM discovery or serialize them to `cache-memory` for gh-aw CI execution"
- Rec 6: static context via APM `dependencies:`, dynamic context via gh-aw native persistence
- Lesson 3: "Static vs. dynamic is the correct integration boundary"

The concern is not that the architecture is wrong -- it is sound. The concern is that the adapter is the most complex integration component proposed across all three tools, and no tool is taking ownership of building it. APM says it is a spec-kit-owned extension concern. gh-aw says it is outside the CI execution layer. spec-kit (based on its own review) considers `.specify/extensions/orchestrator/` the canonical location and expects tools to read from there.

If nobody builds the adapter, the "pluggable" architecture collapses into "APM cannot discover orchestrator artifacts in CI" -- which is the same problem the original Rec 9 (mirroring) was trying to solve.

**Risk level**: Medium. This is a design-time concern, not an architectural conflict. But it should be called out in the spec so that P7 and P8 each have a clear scope boundary for who builds which adapter.

### NC-2: APM's "Lessons Learned" section implicitly claims gh-aw agrees with positions gh-aw did not endorse

Lesson 3 states: "Static vs. dynamic is the correct integration boundary." gh-aw agrees with this characterization.

However, Lesson 2 states: "The host tool's conventions are the canonical conventions" and that "APM can consume these artifacts through build-time exports and distribution-time transformations, but it cannot dictate the canonical format or location."

gh-aw did not make this argument. gh-aw's position was about CI execution constraints (single-job model, ephemeral runners, cache-memory as transport). The "host tool's conventions are canonical" argument came from spec-kit. APM's Lesson 2 is correct, but it attributes a consensus that only spec-kit drove. This is a minor concern about intellectual honesty in the revision, not an architectural problem.

## Hard Stances (Non-Negotiable from gh-aw's Perspective)

### HS-1: The single-job execution model is a hard platform constraint, not a design preference

APM's revision never explicitly acknowledges the single-job constraint. It withdraws the recommendations that were incompatible with it (Recs 1 and 5), which is good. But the revision frames these withdrawals as "build-time tools must not be prescribed for runtime problems" (Lesson 1) rather than "gh-aw's execution model makes multi-step APM resolution within a workflow run structurally impossible."

gh-aw's position: any spec recommendation that requires multiple APM CLI invocations within a single CI workflow run is not just inadvisable -- it is impossible. The single-job model means one agent runs once. There is no loop. There is no "run `apm compile`, then dispatch, then `apm compile` again." APM's revised framing treats this as a philosophical principle ("build-time tools shouldn't do runtime things") rather than what it actually is: a hard platform constraint that gh-aw's compiler enforces.

This distinction matters for future iterations. If someone proposes "just run `apm compile` in a `steps:` block before the agent starts," that is fine -- it runs once, before the agent, as a pre-computation. If someone proposes "run `apm compile` between dispatches to update context," that is impossible because there are no "between dispatches" within a single run. The constraint is structural, not philosophical.

### HS-2: `cache-memory` and `repo-memory` are the only viable cross-run persistence mechanisms in CI

APM's revision correctly identifies the working tree as canonical and `cache-memory` as a durability layer. gh-aw agrees with this framing. But the hard stance is: in CI, there is no alternative. The working tree on an ephemeral runner is destroyed after each job. The only mechanisms for cross-run state are:

- `cache-memory` (TTL-based, fast, scoped to the workflow)
- `repo-memory` (git-backed orphan branch, durable, shared across workflows)
- GitHub Actions artifacts (downloadable, have retention limits)
- Git commits to the main branch (durable but noisy)

APM cannot provide cross-run persistence in CI. `apm install` and `apm compile` run within a single job and their output exists only for the duration of that job. If the spec adopts APM primitives for static context (as revised Rec 6 proposes), those primitives must be re-resolved from the APM package on every CI run, or their output must be cached via `cache-memory`.

gh-aw does not object to APM resolution running in `steps:` blocks or via `dependencies:` frontmatter. But gh-aw insists that the cross-run durability mechanism for any APM-produced artifacts in CI must be a gh-aw primitive (`cache-memory` or `repo-memory`), not an APM mechanism. APM has no cross-run persistence story for CI.

### HS-3: The one-phase-per-run campaign model is the only viable Tier C architecture in CI

This was the most contested recommendation in the original cross-review cycle. APM rated it "Dangerous." spec-kit rated it "Dangerous." gh-aw stands by it.

APM's revision does not explicitly address this, but the withdrawal of Rec 1 (`.prompt.md` dispatch) removes the architectural conflict that APM cited. spec-kit's concerns were about session continuity (hooks, extension commands) -- gh-aw's revised Rec 8 addresses those by restoring the full `.specify/` tree at the start of each run.

The hard stance: there is no alternative architecture for autonomous multi-phase orchestration in GitHub Actions. The platform does not support long-running processes, cross-job agent state, or looping dispatch within a single job. The one-phase-per-run model is not gh-aw's preference -- it is the only thing the platform allows. Any spec design that assumes a different CI execution model for Tier C will fail at implementation time.

## Possible Compromises

### PC-1: APM resolution via `dependencies:` frontmatter for static context (gh-aw accepts)

APM's revised Rec 6 proposes that worker workflows declare the orchestrator's APM package via `dependencies:` for static context injection. gh-aw fully accepts this. The `dependencies:` field already supports APM packages and runs resolution at activation time (before the agent job). This is a clean integration point that uses both tools at their strengths: APM resolves the package, gh-aw executes the workflow.

gh-aw's only condition: the `dependencies:` resolution must be treated as a one-time, pre-job operation. It runs once and produces static files. It cannot be re-invoked mid-job to change context.

### PC-2: `apm pack` bundles stored in `repo-memory` for milestone archival (gh-aw accepts)

APM's Rec 7 (`apm pack` for milestone snapshots) and gh-aw's `repo-memory` are naturally complementary. An APM bundle stored via `repo-memory`'s `upload-asset` pattern provides both APM-compatible unpacking and git-backed durability. gh-aw fully accepts this integration.

### PC-3: Phase summary format could follow `.context.md` conventions without requiring APM tooling (gh-aw could accept)

APM's revised Rec 2 proposes structured Markdown with YAML frontmatter as the phase summary format, stored canonically in spec-kit's extension directory. gh-aw could accept this format convention if:

1. The format is a convention (structured Markdown with frontmatter), not a dependency (requiring `apm compile` to process).
2. The files are plain text readable without APM tooling -- any tool that can parse YAML frontmatter and Markdown can consume them.
3. In CI, the files are serialized to/from `cache-memory` without requiring APM-specific processing.

If the `.context.md` format meets these criteria (and based on APM's documentation, it does -- it is just Markdown with YAML frontmatter), gh-aw has no objection to adopting the format as a shared convention. The objection was never to the format -- it was to the requirement that `apm compile` process the files.

### PC-4: Build-time SKILL.md generation at P8 (gh-aw is neutral)

APM's revised Rec 3 defers SKILL.md generation to a P8 build-time transformation. gh-aw has no opinion on this -- it is a distribution concern that does not affect CI execution. If the build step generates valid files that downstream APM consumers can use, it neither helps nor hinders gh-aw's CI integration.

### PC-5: gh-aw could provide a `cache-memory` adapter specification for the pluggable storage pattern

If the "pluggable adapter" from APM's revised Recs 2 and 6 is going to be built, gh-aw could contribute the `cache-memory` adapter specification: the serialization format, the cache key naming scheme, the restore/persist lifecycle hooks. This would be gh-aw's contribution to the adapter pattern, with APM contributing the `.apm/context/` adapter specification and spec-kit contributing the canonical storage contract.

This compromise requires all three tools to agree on the adapter interface, but it distributes the design work along tool-expertise boundaries.
