# APM Iteration 1 Review of spec-kit's Revised Position

## What Changed (spec-kit: original -> revised)

spec-kit's iteration 1 document (`UTILIZATION.iteration_1.md`) made the following changes to its original 10 recommendations:

**Withdrawn (3)**:
- Rec 2 (replace config.json with spec-kit extension config YAML) -- withdrawn, acknowledges a format-neutral config is better.
- Rec 3 (move state to `.specify/extensions/orchestrator/`) -- withdrawn, concedes the spec's original `.specify/orchestrator/` single-directory approach is superior for multi-tool compatibility.
- Rec 4 (use a companion preset to override core SDD commands) -- withdrawn, adopts namespaced commands as the correct approach.

**Modified (4)**:
- Rec 1 (register templates in extension's templates/ directory) -- scope narrowed to structural templates only, not filled runtime artifacts.
- Rec 6 (subagent dispatch as requires.tools) -- scoped to local execution only, acknowledges CI dispatch works differently.
- Rec 8 (publish to spec-kit catalog) -- reframed from "instead of APM" to "both channels, documented authority boundaries."
- Rec 9 (forward-compatible hooks) -- added requirement for a hook interaction matrix documenting spec-kit vs. APM hook levels.

**Unchanged (3)**:
- Rec 5 (declare requires.commands) -- stood as synergy.
- Rec 7 (integrate /speckit.analyze) -- stood as synergy.
- Rec 10 (tags for discoverability) -- stood as synergy.

---

## Contradictions Resolved

### DC-1 (Companion preset for command wrapping): GENUINELY RESOLVED

This was the strongest resolution. spec-kit fully withdrew Rec 4 and adopted the exact alternative APM proposed: namespaced commands (`speckit.orchestrator.plan`, etc.) that invoke unmodified core commands. spec-kit's lessons-learned section explicitly states: "When two tools with completely different architectures and concerns both reject the same recommendation and propose the same alternative, that is a strong signal."

This is an honest withdrawal. No hedge, no softened language, no "we still think presets have value." The preset approach is dead, and namespaced commands are the agreed path. APM's core concern -- that presets would duplicate context injection and create drift with APM's compilation output -- is fully addressed.

### DC-2 (Replace config.json with spec-kit extension config): GENUINELY RESOLVED

spec-kit withdrew Rec 2 and conceded that the spec's original `config.json` is more neutral than either tool's proprietary format. The revised position explicitly says: "APM is right that the original `config.json` (or a format-neutral YAML/JSON file that both tools can consume) is a better starting point than spec-kit's proprietary layered config system."

This is a clean concession. APM's concern that locking config into spec-kit's resolution stack would prevent APM from managing orchestrator settings through its own pipeline is fully addressed by the move to a neutral format.

### DC-3 (Move state to .specify/extensions/orchestrator/): PARTIALLY RESOLVED -- SEE UNRESOLVED SECTION

spec-kit withdrew Rec 3, but the revised position introduces a new stance that only partially addresses APM's concern. See "Contradictions Unresolved" below.

---

## Contradictions Unresolved

### DC-3 evolved into a new conflict: spec-kit claims `.specify/extensions/orchestrator/` as the canonical location in its own revised APM recommendations

This is the critical issue that demands close reading across documents.

In spec-kit's iteration 1 of its *own* utilization review (`UTILIZATION.iteration_1.md`), Rec 3 for state layout is indeed withdrawn. spec-kit concedes that `.specify/orchestrator/` (the spec's original single directory) is the right approach over scattering state across `.specify/extensions/orchestrator/` and `.specify/specs/{feature}/orchestrator/`.

However, spec-kit's review of *APM's* recommendations (`spec-kit/UTILIZATION.md_reviews/apm.md`) takes a different position. In that document, spec-kit's review of APM's Rec 2 (phase summaries) and Rec 3 (boundary maps) states:

- T-2 resolution: "The canonical location must be within `.specify/extensions/orchestrator/`. APM discovery can be served by a build-time copy or symlink."
- T-3 resolution: "Boundary maps should be authored in whatever format the orchestrator needs for its own dispatch and verification logic, stored under spec-kit's extension directories."

And APM's own iteration 1 (`apm/UTILIZATION.iteration_1.md`) accepted this framing in its revised Rec 2 and Rec 3:

- Revised Rec 2: "The canonical location is under spec-kit's extension directory (`.specify/extensions/orchestrator/phases/`)"
- Revised Rec 3: "stored under `.specify/extensions/orchestrator/boundaries/`"

So here is the contradiction: **APM conceded too much in its own iteration 1.** spec-kit withdrew its own Rec 3 (acknowledging `.specify/extensions/orchestrator/` is wrong for multi-tool scenarios), but APM simultaneously adopted `.specify/extensions/orchestrator/` as the canonical location in its revised Recs 2 and 3. APM accepted a position that spec-kit itself was walking away from.

The net result is incoherent. spec-kit says the single `.specify/orchestrator/` directory is better for multi-tool compatibility (its Rec 3 withdrawal), but APM says agent-consumable artifacts live canonically in `.specify/extensions/orchestrator/` (its revised Recs 2-3), and APM further says mirroring into `.apm/context/` should be handled only at P8 build time (its withdrawn Rec 9).

**Why this matters for APM**: If agent-consumable context (phase summaries, boundary maps, decisions) lives canonically in `.specify/extensions/orchestrator/` and APM cannot mirror it until P8, then for phases P1 through P7, APM compilation is completely blind to orchestrator knowledge. APM's entire value proposition for this project -- context optimization, scope-filtered compilation, multi-runtime distribution -- is deferred to the last phase. That is not a compromise; that is capitulation.

**APM's hard stance**: The canonical location question and the APM-visibility question are inseparable. If artifacts live somewhere APM cannot see them, APM cannot optimize, compile, or distribute them. The resolution must provide a path for APM discovery from P1, not just P8.

---

## New Concerns

### 1. The "pluggable storage adapter" concept is underspecified and load-bearing

APM's revised Rec 2 introduces a "pluggable storage adapter layer" that can mirror phase summaries to `.apm/context/` for local APM discovery or serialize them to `cache-memory` for gh-aw CI execution. This concept appeared in neither the original APM review nor the original spec-kit review -- it was invented during the iteration to bridge the canonical-location gap.

The concern: this adapter is now the sole mechanism connecting APM to orchestrator knowledge, but it has no specification. Who builds it? Is it part of the orchestrator extension, part of APM, or a third artifact? When does it run -- at `apm compile` time, at orchestrator setup time, or continuously? If it is a build-time adapter, it has the same static-vs-dynamic problem that killed APM's original Rec 5 (applyTo patterns). If it is a runtime adapter, it reintroduces the runtime APM dependency that the spec prohibits.

This adapter concept needs to be challenged or specified before it becomes the load-bearing bridge between two tools that cannot see each other's artifacts.

### 2. spec-kit's "Lessons Learned" section subtly repositions APM as secondary

spec-kit's iteration 1 includes five "Lessons Learned" that frame the overall negotiation. Lesson 2 states: "The most dangerous recommendations were the most 'correct' from a single-tool perspective." This is presented as self-criticism, but it applies asymmetrically. spec-kit's "textbook-correct" advice (Recs 2, 3, 4) was withdrawn because it conflicted with APM and gh-aw. APM's "textbook-correct" advice (Recs 1, 5, 9) was withdrawn for the same reason. But spec-kit's framing implies its withdrawals were acts of generosity ("we gave ground for multi-tool harmony"), while APM's withdrawals were corrections of genuine flaws ("build-time tools must not be prescribed for runtime problems").

Lesson 2 from APM's own iteration is more honest: "The host tool's conventions are the canonical conventions." APM acknowledged that the orchestrator is a spec-kit extension first. spec-kit's iteration never acknowledges that APM has legitimate authority over context management and distribution. This asymmetry in framing does not change the technical outcome of this round, but it signals that spec-kit may resist further APM claims in future iterations by appealing to "multi-tool harmony" while actually defaulting to spec-kit primacy.

### 3. The revised Rec 8 creates a dual-authority model with no arbitration

spec-kit's modified Rec 8 states: "The spec-kit catalog is authoritative for extension machinery (commands, hooks, templates). APM is authoritative for context primitives (compiled context, skill files, prompt workflows)."

This split sounds clean but masks a jurisdictional gap. Phase summaries are both "extension machinery" (the orchestrator reads and writes them during dispatch, a core extension function) and "context primitives" (they are agent-consumable knowledge that should be compiled and distributed). Under the dual-authority model, which tool is authoritative for phase summaries? spec-kit claims them as extension state; APM claims them as context. The answer matters because it determines the canonical format, canonical location, and which tool's lifecycle governs creation and deletion.

---

## Hard Stances (Non-Negotiable from APM's Perspective)

### 1. APM must have a discovery path for orchestrator knowledge artifacts from P1

Deferring APM's ability to compile and distribute orchestrator context to P8 is unacceptable. The orchestrator's phase summaries, decisions register, and knowledge files are the highest-value context artifacts in any project using the orchestrator. If APM cannot see them until the last development phase, the entire benefit of APM's context optimization engine is unavailable during the period when the orchestrator is being built and iterated.

This does not mean artifacts must be canonically stored in `.apm/`. It means there must be a defined, working mechanism -- whether symlinks, a copy step in the orchestrator's own commands, or a lightweight integration in `apm compile` -- that makes orchestrator knowledge visible to APM from the first phase. The mechanism can be simple. It cannot be absent.

### 2. APM's compilation must not be bypassed for agent-consumable context

If the orchestrator produces context that agents consume, that context should flow through APM's compilation pipeline when APM is present. This is not about format ownership; it is about optimization. APM's compilation engine deduplicates, scopes, and optimizes context mathematically. An orchestrator that produces agent context outside APM's pipeline forces agents to consume unoptimized, potentially duplicated, unscoped knowledge -- degrading every downstream agent's performance.

The orchestrator can author in any format it wants. But when APM is installed and `apm compile` runs, the output must include orchestrator knowledge alongside all other project context. This is the "enhanced context management" that APM's revised Rec 4 promises. If there is no path for compilation to discover orchestrator artifacts, the "enhanced" qualifier is empty.

### 3. The hybrid package at P8 must be a real integration, not a wrapper

Both sides agree on Rec 8 (hybrid APM package). But "agreement" on a future deliverable is cheap. The hard stance is that the P8 hybrid package must actually compile orchestrator artifacts into optimized agent context -- not just ship the extension files in a tarball. This requires that the orchestrator's artifacts are in a format APM can process (structured Markdown with frontmatter, at minimum) and stored in a location APM can discover (or discoverable through a declared convention). If P1-P7 decisions about format and location make P8 compilation impossible or shallow, Rec 8 consensus is hollow.

---

## Possible Compromises

### 1. A `.apm/context/orchestrator/` symlink managed by the orchestrator extension itself

Instead of APM mirroring (which spec-kit rightly rejected as split-brain) or P8-only build-time export (which defers APM value too long), the orchestrator extension could create and manage a symlink from `.apm/context/orchestrator/` pointing to `.specify/orchestrator/` (or wherever the canonical state lives). The symlink is created by the orchestrator's own setup command (`speckit.orchestrator.init`), not by APM. The symlink is removed by `specify extension remove` because the orchestrator's cleanup logic owns it. This satisfies spec-kit's self-containment requirement (the extension manages its own symlink), APM's discovery requirement (`.apm/context/orchestrator/` exists and is scannable), and the single-source-of-truth requirement (no copied data, just a pointer).

APM would need to handle symlinked directories in its discovery path, which it likely already does. spec-kit would need to accept that an extension can create files outside `.specify/` as part of its own setup, which is a minor convention extension but not a contract violation if the extension also cleans up.

### 2. Accept spec-kit's structural-template ownership, claim filled-artifact compilation

spec-kit's modified Rec 1 distinguishes between structural templates (document shapes) and filled runtime artifacts. APM can concede that spec-kit's template resolution stack governs the shapes -- this is genuinely spec-kit's domain and APM has no competing mechanism for template customization via presets. In exchange, APM claims the filled artifacts: once the orchestrator produces a phase summary, decision entry, or boundary map by filling in a template, that filled artifact is agent-consumable context and falls under APM's compilation jurisdiction. spec-kit governs the mold; APM governs the casting.

This maps cleanly to the dual-authority model from Rec 8 and avoids the jurisdictional gap identified in "New Concerns" above.

### 3. Co-define the "pluggable storage adapter" as an APM integrator

Rather than leaving the adapter concept underspecified, APM could offer to implement it as a new integrator in APM's `BaseIntegrator` framework (per the integrator architecture conventions in `apm/.github/instructions/integrators.instructions.md`). A `SpeckitOrchestratorIntegrator` would discover artifacts at the orchestrator's canonical location, process them into APM primitive format, and deploy them into `.apm/context/` as part of the normal `apm install` / `apm compile` pipeline. This makes the adapter concrete, gives it a home in APM's well-tested integrator infrastructure, and avoids the underspecification risk. It also means the orchestrator itself does not need to know about APM at all -- APM's integrator reads the orchestrator's output and handles the translation.

This approach respects the spec's constraint that the orchestrator does not import or wrap APM. APM reads the orchestrator's artifacts; the orchestrator does not write APM's formats.

### 4. Accept the hook-level separation with a documented interaction model

spec-kit's modified Rec 9 proposes a hook interaction matrix. APM should accept this and contribute to defining it. The two hook systems genuinely operate at different abstraction levels (SDD workflow steps vs. agent tool invocations) and are complementary, not competing. APM's concern about unpredictable interaction is valid but manageable through documentation rather than architectural change. This is a low-cost concession that builds goodwill.
