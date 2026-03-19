# APM Dispute Resolution -- Iteration 3

## Dispute 1: State Path

`.specify/orchestrator/` vs `.specify/extensions/orchestrator/`

**APM's position**: APM accepts `.specify/orchestrator/` as the canonical state path.

This is not a concession -- it is the correct technical outcome, and APM should have arrived here in iteration 1 instead of adopting `.specify/extensions/orchestrator/` as a misguided accommodation. The reasoning:

1. **The spec's own design uses `.specify/orchestrator/`.** The speckit-orchestrator spec places all state under `.specify/orchestrator/` (spec overview, "File Structure and Key Artifacts" section: "All orchestrator state lives under .specify/orchestrator/, separate from spec-kit's specs/ feature directories"). APM should follow the spec, not invent paths the spec does not use.

2. **spec-kit itself withdrew the extension convention path.** spec-kit's iteration 1 withdrew its own Rec 3, conceding that `.specify/extensions/orchestrator/` was designed for single-consumer extensions and that the orchestrator's multi-consumer reality (spec-kit, APM, gh-aw) makes the convention path inappropriate. APM's iteration 1 adoption of `.specify/extensions/orchestrator/` was a crossed-wires error -- conceding to a position that the proposing tool was simultaneously abandoning.

3. **APM's `BaseIntegrator` framework and `apm compile` do not care about the path string.** APM's discovery mechanism (`discover_primitives` in `apm/src/apm_cli/primitives/discovery.py`) uses configurable glob patterns. Whether the path is `.specify/orchestrator/` or `.specify/extensions/orchestrator/`, APM's compiler can be configured to scan it. The path choice has zero impact on APM's implementation cost.

4. **The shorter path is operationally simpler.** For gh-aw's `cache-memory` keys, for developer muscle memory, for documentation, for `apm compile --include-paths` configuration -- fewer path components means fewer opportunities for typos and mismatches.

**Engagement with counter-positions**:

spec-kit (iteration 2, Rec 3) proposes `.specify/orchestrator/` with a justification committed to the spec explaining why the extension convention is not followed. This is exactly right. spec-kit further offers to accept `.specify/extensions/orchestrator/` if APM and gh-aw prefer consistency. APM does not prefer consistency here -- the extension convention exists to serve extensions whose state is consumed only through spec-kit's resolution stack. The orchestrator's state has three consumers. The convention does not apply.

gh-aw (iteration 2, Rec 2) has already updated to `.specify/orchestrator/`, resolving the crossed-wires from iteration 1. gh-aw's hard stance -- single directory, static cache keys -- is satisfied by either path. gh-aw has no remaining concern here.

**APM's proposed resolution**: All three tools adopt `.specify/orchestrator/` as the canonical state path. The spec includes a brief note (per spec-kit's proposed justification) explaining the deviation from the extension convention. No further discussion needed. This dispute is resolved.

**Concession offered**: None required. All three tools are already aligned on `.specify/orchestrator/`. APM formally corrects its iteration 1 error and adopts the path that spec-kit, gh-aw, and the original spec all endorse.

---

## Dispute 2: APM Discovery Timeline

When does APM get access to orchestrator artifacts -- P1, P7, or P8?

**APM's position**: APM must be able to compile orchestrator artifacts from **P1**, using a unilateral APM-side mechanism that requires zero changes to the orchestrator or spec-kit. The mechanism: `apm compile` learns to read from `.specify/orchestrator/` as a configurable additional discovery path.

**Technical justification**:

The orchestrator produces the highest-value context artifacts in any project that uses it: phase summaries, decision registers, boundary maps, knowledge files. These are precisely the kind of structured, agent-consumable content that APM's compilation engine is designed to optimize -- deduplication, scope filtering, cross-reference resolution, multi-target output. Deferring APM's access to these artifacts until P8 means:

- For P1 through P7, developers using APM alongside the orchestrator get **zero compilation benefit** from orchestrator knowledge. Phase summaries exist on disk but are invisible to `apm compile`, so they never appear in AGENTS.md, CLAUDE.md, or any compiled context output.
- The P8 hybrid package build step has never seen the artifacts it is supposed to transform. The first time APM encounters orchestrator artifacts is the moment it must package them for distribution. This is backwards -- you need to iterate on compilation during development (P1-P7), not discover it at packaging time (P8).
- APM's context optimizer (`apm/src/apm_cli/compilation/context_optimizer.py`) performs deduplication and scope analysis across all discovered context. If orchestrator artifacts are invisible, the optimizer cannot deduplicate overlapping content between orchestrator knowledge and other project context. Agents receive redundant information.

**The mechanism is simple and unilateral.** APM's `discover_primitives` function (`apm/src/apm_cli/primitives/discovery.py`) already supports configurable glob patterns via `LOCAL_PRIMITIVE_PATTERNS`. The existing pattern `**/*.context.md` already matches any `.context.md` file anywhere in the project tree. For orchestrator artifacts that do not use APM's naming conventions, APM needs one of:

1. A `compilation.include_paths` configuration key in `apm.yml` that adds `.specify/orchestrator/` to the discovery scan. This is an APM-only change -- a new config key that tells the compiler "also look here."
2. An APM integrator (`SpeckitOrchestratorIntegrator`) extending `BaseIntegrator` that discovers structured Markdown files at `.specify/orchestrator/` and processes them into APM's compilation pipeline. This follows APM's established integrator architecture (documented in the `src/apm_cli/integration/` module and the `BaseIntegrator` design contract in `.github/instructions/integrators.instructions.md`).

Either mechanism is entirely within APM's codebase. The orchestrator does not know APM exists. spec-kit's extension contract is not touched. `specify extension remove` still cleans up `.specify/orchestrator/` completely because APM never writes to that directory -- it only reads.

**Engagement with counter-positions**:

spec-kit (iteration 2, Dispute 1 compromise) proposes a tiered approach: no APM discovery in P1-P6, optional `apm compile` scanning from P7, full integrator at P8. spec-kit's rationale: introducing APM discovery during P1-P7 "creates a runtime dependency on APM being installed and configured."

This rationale does not hold. `apm compile` is not a runtime dependency. It is a developer command that runs when the developer explicitly invokes it, the same way `git status` or `npm build` are not runtime dependencies of the code they operate on. The orchestrator does not call `apm compile`. The developer does. If APM is not installed, `apm compile` does not run, and the orchestrator is completely unaffected. The spec's constraint is "Must not import or wrap APM at runtime" -- `apm compile` scanning `.specify/orchestrator/` is neither importing nor wrapping. It is reading files from disk.

spec-kit's compromise correctly identifies the key insight: "APM's compiler can be taught to look in `.specify/orchestrator/` the same way it looks in `.apm/` -- this is a compiler configuration question, not an artifact placement question." APM agrees entirely. But there is no technical reason to defer this to P7. The compiler configuration is an APM-side change that can ship whenever APM ships the feature. If the orchestrator writes phase summaries to `.specify/orchestrator/` at P1, and APM ships `compilation.include_paths` support, the developer can compile orchestrator context from day one.

gh-aw (iteration 2) has no stake in the local-development discovery timeline. gh-aw's concern is CI, where the cache-memory restore-execute-persist lifecycle already places artifacts in the working tree. gh-aw's iteration 2 Rec 2 already includes an optional `apm compile` step in the CI lifecycle (step 2). The question of when APM can discover artifacts locally is between APM and spec-kit.

**Why APM cannot concede P8-only discovery**: The P8 hybrid package must compile orchestrator artifacts into optimized agent context (locked consensus point 8). If APM's compilation pipeline has never processed these artifacts before P8, the P8 build step is untested, its output format is unvalidated, and any integration issues between APM's compiler and the orchestrator's artifact format are discovered at the worst possible time -- the distribution packaging moment. This is the software equivalent of writing a test suite after shipping. APM needs P1 discovery so that the compilation pipeline is exercised, debugged, and proven correct over the entire development lifecycle.

**APM's proposed resolution**:

APM builds either `compilation.include_paths` support or a `SpeckitOrchestratorIntegrator` -- both are APM-only changes. The mechanism ships when APM ships it. No timeline dependency on the orchestrator's priority phases. No changes to spec-kit or the orchestrator. The developer enables it by adding one line to `apm.yml`:

```yaml
compilation:
  include_paths:
    - .specify/orchestrator/
```

Or, if the integrator approach is chosen, the integrator auto-discovers `.specify/orchestrator/` when present and does nothing when absent. Either way:

- The orchestrator does not know about APM.
- spec-kit's extension contract is untouched.
- `specify extension remove` cleanly removes `.specify/orchestrator/` with no APM residue.
- APM benefits from P1 onward, with zero cooperation required from the other two tools.

**Concession offered**: APM concedes that the orchestrator should never create files in `.apm/` or manage any symlink to `.apm/`. The symlink proposal from APM's iteration 1 review is formally withdrawn. APM reads from `.specify/orchestrator/`; APM does not ask the orchestrator to write anywhere else. If APM wants to discover orchestrator artifacts, APM configures itself to look in the right place. This is APM's responsibility, not the orchestrator's.

---

## Dispute 3: Pluggable Adapter Ownership

Who builds the storage adapter, and when?

**APM's position**: The "pluggable storage adapter" as originally conceived is dead. APM formally buries it. The concept appeared in APM's iteration 1 revised Rec 2 as a bridge between three storage backends (spec-kit directory, `.apm/context/`, gh-aw `cache-memory`). Both spec-kit and gh-aw correctly identified it as scope creep: it was not in the original spec, it was not in any tool's original review, and it represented a substantial engineering commitment with no owner.

**Why the adapter is unnecessary if Dispute 2 is resolved correctly**:

The adapter was invented to solve the problem of APM not being able to see orchestrator artifacts. If APM's compiler can read directly from `.specify/orchestrator/` (the Dispute 2 resolution), then:

- **Locally (P1-P7)**: `apm compile` reads `.specify/orchestrator/` via `include_paths` or the integrator. No adapter needed. No mirroring, no symlinks, no dual-write.
- **In CI (P7)**: gh-aw's `cache-memory` restores the entire `.specify/orchestrator/` tree to the working tree before execution. APM's compiler runs on the restored working tree. No adapter needed -- the cache-memory restore-persist lifecycle already handles durability, and APM reads from the working tree during the execution window.
- **At distribution (P8)**: The `apm pack` build step reads from `.specify/orchestrator/` and transforms artifacts into APM primitives for the hybrid package. This is a build step, not an adapter. It runs once during packaging. It does not need a persistent bridge between storage backends.

The three "backends" the adapter was supposed to bridge are not actually three separate storage locations -- they are three views of the same data:

1. `.specify/orchestrator/` on disk -- the canonical state (consensus point 1).
2. `cache-memory` -- a transport mechanism that persists the canonical state across CI runs (consensus point 1: "working tree is canonical").
3. `.apm/context/` -- withdrawn in iteration 1 (Rec 9 withdrawal). APM no longer proposes storing anything here.

When you remove the third backend (`.apm/context/`) and acknowledge that `cache-memory` is transport not storage, the "adapter" reduces to: "APM reads files from a directory." That is not an adapter pattern. That is a file read.

**Engagement with counter-positions**:

spec-kit (iteration 2, Dispute 3) calls the adapter scope creep and proposes full deferral to P8. APM agrees it was scope creep. APM goes further: the adapter is not needed at P8 either. What P8 needs is a build step in `apm pack` that reads `.specify/orchestrator/`, transforms artifacts, and outputs APM primitives. This is a transformation step, not an adapter. The distinction matters because "adapter" implies ongoing runtime mediation between two systems, while "build step" implies a one-time transformation during packaging.

gh-aw (iteration 2, Dispute 2) offered to contribute a `cache-memory` adapter specification. APM appreciates this offer but believes it targets a non-problem. gh-aw's `cache-memory` already works: restore the tree, execute, persist the tree. This lifecycle is fully documented in gh-aw's iteration 2 Rec 2. There is no "adapter" to specify -- the restore and persist operations are gh-aw's existing primitives applied to the `.specify/orchestrator/` path. What gh-aw should document (and proposes to document in the expanded P7 section) is the cache-coherency contract: what happens on restore failure, what happens on persist failure, how staleness is detected. This is operational documentation, not adapter specification.

**APM's proposed resolution**:

1. The "pluggable storage adapter" concept is formally withdrawn by APM. It does not appear in any future iteration or in the P8 specification.

2. The P7 and P8 deliverables are reframed without the adapter abstraction:
   - **P7 (gh-aw scope)**: Document the `cache-memory` restore-persist lifecycle for `.specify/orchestrator/`, including cache-coherency edge cases. This is operational documentation of existing gh-aw primitives.
   - **P7 (APM scope)**: APM ships `compilation.include_paths` or the `SpeckitOrchestratorIntegrator` so that the optional `apm compile` step in gh-aw's CI lifecycle (iteration 2, Rec 2, step 2) can actually discover orchestrator artifacts.
   - **P8 (APM scope)**: `apm pack` includes a build step that reads `.specify/orchestrator/` and transforms orchestrator artifacts into SKILL.md files and compiled context for the hybrid package.
   - **P8 (spec-kit scope)**: spec-kit documents the canonical storage contract -- directory layout, file formats, read/write semantics of `.specify/orchestrator/`. This is the schema that APM's P8 build step and P7 compilation consume.

3. Each tool owns its own piece. No tool builds for another tool. No shared "adapter" component exists.

**Concession offered**: APM withdraws the adapter concept entirely and accepts that there is no shared component to build. APM takes full ownership of its own discovery and compilation -- reading from `.specify/orchestrator/` is APM's responsibility, not a shared obligation. In exchange, APM asks only that the orchestrator's artifact format be documented (structured Markdown with YAML frontmatter, as already agreed in locked Rec 2) so that APM's compiler can parse it reliably.

---

## Package Deal

If APM could get one dispute fully its way in exchange for conceding the other two, APM would choose **Dispute 2: APM Discovery Timeline from P1**.

Here is why:

**Dispute 1 is already resolved.** All three tools agree on `.specify/orchestrator/`. There is nothing to trade.

**Dispute 3 is already resolved.** All three tools agree the adapter is unnecessary. APM formally withdrawing the concept costs nothing and gains clarity.

**Dispute 2 is the only dispute with real technical stakes.** The difference between P1 discovery and P8 discovery is the difference between:

- APM's compilation pipeline being tested and proven across seven development phases before it must produce a distribution package, vs.
- APM's compilation pipeline encountering orchestrator artifacts for the first time at the moment of distribution packaging.

- Developers getting compiled, optimized orchestrator context in their AGENTS.md and CLAUDE.md throughout development, vs.
- Developers getting optimized context only after the orchestrator is fully built and packaged.

- APM's context optimizer deduplicating orchestrator knowledge against project context from P1, vs.
- Seven phases of redundant context injection into agent dispatch payloads.

The P1-vs-P8 timeline is not an abstract preference. It determines whether APM's context optimization engine provides value during the orchestrator's development lifecycle or only at the end of it. And critically, it determines whether the P8 hybrid package build step is a well-tested operation or a first-time gamble.

APM's Dispute 2 resolution asks for no cooperation from spec-kit or gh-aw. It is a unilateral APM enhancement. The only thing APM asks from the other tools is acceptance that APM's compiler reading files from `.specify/orchestrator/` does not violate any constraint. It does not: the orchestrator does not know about APM, spec-kit's extension contract is untouched, and `specify extension remove` cleans up cleanly because APM never writes to `.specify/`.

If spec-kit insists on P7 as the earliest timeline (its compromise proposal), APM can accept that as a fallback -- but the technical argument for P1 is stronger, and the P7 timeline exists only because spec-kit frames `apm compile` as a "dependency," when in reality it is a developer tool that operates on files already on disk.
