# Disputes -- gh-aw Iteration 3

**Author**: GitHub Agentic Workflows (gh-aw)
**Iteration**: 3 (post iteration-1 revisions)
**Date**: 2026-03-19

---

## Remaining Disputes

### Dispute 1: The Runtime Adapter Interface Must Be Rich Enough for Platform-Native Optimization

**Claim I am disputing**: spec-kit's New Recommendation B defines the runtime adapter as "a set of abstract operations: dispatch-task, verify-completion, advance-state, recover-from-crash, inject-context" -- each with "a defined input/output contract." APM's New Recommendation C similarly proposes "a dispatch interface abstraction" with "a payload format, a completion signaling mechanism, and a result collection format."

**The other tools' position**: Both spec-kit and APM frame the adapter interface as a thin abstraction layer. spec-kit's adapter operations are described as simple input/output contracts. APM's dispatch interface is a three-field contract (payload, signal, result). Neither revision specifies that the interface must expose capabilities like parallel fan-out, typed input validation, rate limiting, concurrency discrimination, or conditional execution -- all of which gh-aw's `dispatch-workflow` and `call-workflow` natively provide and which are necessary for production-grade CI orchestration.

**My counter-argument**: A lowest-common-denominator interface that only models what local subprocess spawning can do will force the CI adapter to work *around* the abstraction rather than *through* it. Consider parallel task fan-out: `dispatch-workflow` can dispatch N tasks concurrently with per-task concurrency groups and typed inputs. If the adapter interface only exposes "dispatch one task, get one result," the gh-aw adapter must implement fan-out *outside* the interface, meaning the orchestrator core cannot reason about parallel execution, cannot set concurrency budgets, and cannot optimize phase execution by dispatching independent tasks simultaneously. The interface would be technically correct but architecturally impoverished.

This is not a request to make the interface CI-specific. It is a request to make the interface *capability-aware*. The interface should include:
- **Batch dispatch** (dispatch N tasks, collect N results) -- not just single dispatch
- **Concurrency hints** (max parallel tasks) -- so the adapter can use concurrency groups or subprocess pools
- **Typed input schemas** -- so the adapter can validate payloads before dispatch
- **Progress callbacks** -- so long-running dispatches can report intermediate status

Local adapters can ignore concurrency hints (serial execution is valid). But if the interface lacks these capabilities, the CI adapter becomes a parallel system that happens to share a payload format, rather than a first-class implementation of the orchestrator's dispatch model.

**Proposed resolution**: The spec should define the adapter interface with capability tiers: a required base tier (single dispatch, completion signal, result collection) that all adapters must implement, and an optional enhanced tier (batch dispatch, concurrency control, typed validation, progress reporting) that adapters may implement. The orchestrator core queries adapter capabilities at initialization and adjusts its execution strategy accordingly. This prevents lowest-common-denominator constraints without requiring all adapters to implement CI-grade features.

---

### Dispute 2: SpecOps Propagation Remains Unaddressed

**Claim I am disputing**: Neither APM's iteration 1 nor spec-kit's iteration 1 addresses gh-aw's Recommendation 10 (SpecOps pattern for specification propagation). APM's revision does not mention it. spec-kit's revision does not mention it. My own iteration 1 flagged it as "Surviving unchanged -- unchallenged and addresses a real gap." The silence continues.

**The other tools' position**: By omission, both tools implicitly accept the recommendation or consider it out of scope. Neither provides an alternative mechanism for how boundary map changes in phase N propagate to phase N+1's planning, or how spec changes propagate to implementation repositories in a multi-repo setup.

**My counter-argument**: The spec describes creating boundary maps (FR-010), phase plans, and task plans, but never describes what happens when these artifacts change *after* downstream phases have already been planned. In a real project, phase 2's boundary map may reveal that phase 3's original plan is invalid. Without a propagation mechanism, the orchestrator silently operates on stale plans. This is not a CI-specific concern -- it affects local execution equally. The SpecOps pattern (specification change triggers downstream plan invalidation and re-planning) is one solution. There may be others. But the gap itself has not been acknowledged by either APM or spec-kit.

I am not insisting on SpecOps as the only solution. I am insisting that the spec must address specification propagation as a problem. The current spec assumes plans are created once and executed linearly. Real orchestration is iterative: upstream changes invalidate downstream plans.

**Proposed resolution**: The spec should add a functional requirement addressing artifact invalidation and re-planning. When a phase's outputs change boundary maps or constraints that affect subsequent phases, the orchestrator must detect the invalidation and trigger re-planning for affected downstream phases. The implementation mechanism (SpecOps workflows, local re-planning commands, or a hybrid) is a runtime adapter concern. The requirement itself is universal.

---

### Dispute 3: Repo-Memory as CI Coordination Cache Is Being Dismissed Too Quickly

**Claim I am disputing**: Both APM and spec-kit converged on restricting repo-memory to a secondary role. My own iteration 1 conceded that `.specify/orchestrator/` on the working tree is the sole authoritative state location. However, the revised framing from both APM and spec-kit treats repo-memory as barely relevant -- APM's Recommendation 6 (revised) relegates it to "runtime instances persisted via gh-aw's repo-memory" as an afterthought, and spec-kit's New Recommendation B lists `recover-from-crash = lock file detection` for local and only vaguely gestures at CI crash recovery.

**The other tools' position**: APM and spec-kit agree that disk state at `.specify/orchestrator/` is truth. They frame CI persistence as "the adapter handles checkpoint/restore" without specifying the mechanism. spec-kit's adapter description treats CI crash recovery as a solved problem ("concurrency groups") without acknowledging that concurrency groups handle mutual exclusion, not state recovery.

**My counter-argument**: I conceded that repo-memory cannot be the primary state location -- and that concession stands. But the iteration 1 revisions from APM and spec-kit underspecify CI state persistence to the point where the adapter interface becomes unimplementable for crash recovery scenarios. Consider: a CI orchestrator run crashes mid-phase after completing 3 of 5 tasks. The working tree state in `.specify/orchestrator/` reflects those 3 completions. But the working tree is ephemeral -- it dies with the runner. The next workflow run starts with a fresh checkout. Where does it find the state from the crashed run?

The answer is: the adapter must persist `.specify/orchestrator/` to a durable location between workflow steps and recover it at workflow start. Repo-memory is purpose-built for exactly this. The spec should explicitly name this as a CI adapter responsibility and acknowledge that repo-memory (or an equivalent durable branch-backed store) is *required* for CI crash recovery, not merely "optional supplementary caching."

**Proposed resolution**: The runtime adapter interface should include an explicit `persist-state` / `restore-state` contract for cross-session state durability. Locally, this is a no-op (files already persist). In CI, the adapter must implement durable persistence -- repo-memory is the reference implementation. The spec should state that any CI adapter MUST provide durable state persistence across workflow runs, and that the orchestrator's crash recovery protocol depends on this guarantee.

---

### Dispute 4: The Dual-Entry-Point Directory Layout Adds Unnecessary Structural Complexity

**Claim I am disputing**: APM's New Recommendation A proposes a dual-entry-point directory layout where each skill has both a `SKILL.md` (APM reads) and a command `.md` (spec-kit reads), with a `skills/` directory paralleling the `commands/` directory. spec-kit's Revised Recommendation 7 accepts this coexistence model.

**The other tools' position**: APM argues that `SKILL.md` is the APM entry point and the command markdown is the spec-kit entry point, and both must coexist in the same directory tree. spec-kit concedes that the skill folder serves real functions (APM deployment unit, dispatch payload boundary) and accepts dual registration.

**My counter-argument**: The dual-entry-point model creates a maintenance burden where every skill change requires updating two files that describe the same logical unit in two different formats. The `SKILL.md` contains `name`, `description`, and frontmatter that duplicates information already present in the command markdown's frontmatter and the `extension.yml` manifest. In CI, the gh-aw adapter does not read `SKILL.md` files -- it reads workflow definitions that reference command payloads. APM's skill integrator is the only consumer of `SKILL.md`, and it should be able to generate or derive skill metadata from the command markdown and `extension.yml` rather than requiring a separate hand-maintained file.

The dispatch payload concern (what does a worker need?) is real, but the answer is not "a skill folder with a `SKILL.md`" -- it is "a payload specification in the dispatch interface." The dispatch payload is constructed by the orchestrator at dispatch time from command definitions, relevant templates, and accumulated context. It is not a static folder structure that exists on disk. In CI, the payload is assembled into workflow inputs; locally, it is assembled into a context injection. The skill folder conflates the packaging unit with the dispatch unit, and these are different things with different lifecycles.

**Proposed resolution**: The spec should define a single authoritative source for each command's metadata: the command markdown file with spec-kit frontmatter. APM should derive skill metadata from command frontmatter and `extension.yml` rather than requiring a parallel `SKILL.md`. If APM's skill integrator cannot parse spec-kit command frontmatter, the correct fix is an APM adapter that bridges the formats at install time, not a permanent dual-file structure in the source tree. The dispatch payload contract should be defined in the adapter interface, independent of the directory layout.

---

## Points of Convergence

All three tools now agree on the following positions after iteration 1 revisions.

### Convergence 1: The orchestrator is a spec-kit extension first, with APM and gh-aw as distribution and runtime layers

All three iteration 1 documents converge on this hierarchy. gh-aw's revised overall stance: "The orchestrator's core architecture must be runtime-agnostic as both APM and spec-kit argue." APM's revised overall stance: "The orchestrator is a spec-kit extension that APM distributes. Not an APM package that happens to run in spec-kit." spec-kit's position summary: "Spec-kit's extension system remains the canonical organizational model." This was genuinely contested in iteration 0 and is now settled.

### Convergence 2: A runtime adapter interface is necessary

All three tools independently proposed or endorsed a runtime adapter pattern in their iteration 1 revisions. gh-aw proposed it as New Recommendation A. APM proposed it as New Recommendation C. spec-kit proposed it as New Recommendation B. The specific contract details differ (see Dispute 1), but the architectural pattern -- core orchestrator logic programming against an abstract interface, with platform-specific adapters -- is unanimously accepted.

### Convergence 3: Static configuration and dynamic runtime state must be explicitly separated

gh-aw's New Recommendation C, APM's Revised Recommendation 3, and spec-kit's New Recommendation A all converge on the same boundary: static config (human-authored, changes rarely) through spec-kit's multi-layer config system; dynamic state (machine-authored, changes per-run) in `.specify/orchestrator/`. This was a three-way confusion in iteration 0 and is now resolved.

### Convergence 4: The orchestrator must not override or replace core spec-kit commands

APM proposed this as an explicit constraint in their cross-review. spec-kit adopted it in Recommendation 8 (revised): "The orchestrator MUST NOT override or replace core spec-kit commands via presets." gh-aw's concern about command composition vs. dispatch boundaries is addressed by this constraint -- new `speckit.orchestrator.*` commands that delegate to standard commands, never preset-based overrides. All three tools endorse option (a) from spec-kit's original Recommendation 8.

### Convergence 5: Verification must be mechanical, runtime-agnostic, and defined as a protocol

All three tools agree that verification is non-negotiable and must be mechanical (not self-assessed). gh-aw's Revised Recommendation 4, APM's Revised Recommendation 5, and spec-kit's Surviving Recommendation 6 all converge on: the verification *protocol* (what checks run, what constitutes passing, how results are recorded) is defined once in the spec; the verification *execution mechanism* varies by runtime (hooks locally, workflow steps in CI). The verification ladder (static, command, behavioral, human) from the spec is accepted by all three tools as the correct abstraction.

---

## Final Position Statement

### Non-Negotiable Positions

1. **The adapter interface must support capability tiers, not lowest-common-denominator operations.** If the interface only models what local subprocess execution can do, the CI adapter becomes a workaround machine. Batch dispatch and concurrency control must be expressible through the interface, even if local adapters implement them trivially.

2. **CI state persistence is a required adapter capability, not an optional enhancement.** Any CI adapter must guarantee durable state persistence across workflow runs. Without this guarantee, crash recovery -- one of the spec's core safety mechanisms -- does not function in CI. The spec must name this requirement explicitly in the adapter contract.

3. **Specification propagation must be addressed as a functional requirement.** The spec currently has no mechanism for handling upstream changes that invalidate downstream plans. This is a gap that affects all runtimes and all tiers. The specific mechanism is negotiable; the requirement is not.

### Where I Am Flexible

1. **Directory layout**: I have a preference against dual-entry-point structures (Dispute 4), but if APM's skill integrator genuinely cannot derive metadata from command frontmatter, I can accept `SKILL.md` files as a pragmatic concession -- provided there is a single source of truth for command descriptions that both files reference rather than duplicate.

2. **SpecOps as the propagation mechanism**: I proposed SpecOps because it is a proven gh-aw pattern, but I am flexible on the implementation. A spec-kit-native invalidation mechanism, a manual re-planning command, or even a simple "stale plan" detection check would all satisfy the underlying requirement. The mechanism is negotiable; the requirement is not.

3. **Repo-memory as the specific CI persistence technology**: I proposed repo-memory because it is purpose-built for this use case, but the adapter contract should be technology-agnostic. If a future CI platform provides a better persistence mechanism, the adapter should be free to use it. What matters is the contract (persist state durably across sessions), not the implementation (repo-memory branches specifically).

4. **Concurrency control semantics in the adapter interface**: I proposed specific operations (batch dispatch, concurrency hints), but I am open to alternative interface designs that achieve the same goal of enabling platform-native parallelism. The principle is that the interface should not *prevent* efficient CI execution; the specific API shape is negotiable.
