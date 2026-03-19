# Cross-Review: gh-aw's UTILIZATION.md

**Reviewer**: spec-kit (the SDD framework the orchestrator extends)
**Reviewed**: gh-aw's UTILIZATION.md for the speckit-orchestrator spec
**Date**: 2026-03-18

---

## 1. Dangerous Contradictions

### 1.1 "Design for CI as the primary runtime" inverts the spec's architectural authority

**gh-aw position** (Section 4, "Off-Base Assumptions", paragraph 1): gh-aw recommends reversing the spec's priority -- designing for CI dispatch as the primary autonomous runtime, with local execution as the "development/debugging mode." It calls the spec's local-first approach an assumption that should be reversed and claims the lock-file crash recovery machinery "is unnecessary in CI."

**spec-kit position** (UTILIZATION.md Section 2, "Disk-only state" alignment; spec FR-019 line 230, FR-020 line 231, Constraint line 477): The spec's "state on disk is truth" principle is not a local-execution convenience -- it is a core SDD principle inherited from spec-kit's own architecture. Spec-kit derives status from file existence (`check-prerequisites.sh` checks for `tasks.md`, `plan.md`). The orchestrator's file-presence-based state machine (FR-020) is architecturally consistent with this. Making CI the primary runtime would subordinate the orchestrator's state model to GitHub Actions' run lifecycle, replacing a portable, inspectable, version-controlled state tree with platform-locked workflow run metadata.

**Why this is dangerous**: If CI becomes the primary runtime, the orchestrator's state model must serve two masters: gh-aw's repo-memory branches for CI and `.specify/orchestrator/` for local. This bifurcation means the extension no longer has a single source of truth. Spec-kit extensions are designed to be agent-agnostic and runtime-agnostic (FR-032, spec line 264). Privileging one CI platform's runtime model as "primary" directly violates this. The orchestrator must work identically on Claude Code, Cursor, Copilot, Gemini CLI, and 13+ other agents -- most of which will never run in GitHub Actions. The spec correctly treats CI as additive (US-7, P7) because the orchestrator is a spec-kit extension first and a GitHub workflow second.

### 1.2 Replacing file-based state with repo-memory eliminates inspectability

**gh-aw position** (Section 3, "Repo-memory for durable orchestrator state"; Section 5, Recommendation 3): gh-aw recommends storing the decisions register, knowledge file, execution log, and phase summaries in repo-memory branches at `/tmp/gh-aw/repo-memory-{id}/`. It claims this "eliminates the need for manual git operations and crash-recovery lock files in CI."

**spec-kit position** (UTILIZATION.md Section 2, "Separate state tree" alignment; Section 2, "Disk-only state" alignment): Spec-kit's entire philosophy rests on artifacts being inspectable, version-controlled, and locally accessible. The spec's `.specify/orchestrator/` tree is designed so a developer can `ls` the directory, read any file, and understand the orchestrator's complete state. This is not a convenience -- it is the mechanism by which the state machine operates (FR-020: state derived deterministically from file presence/absence). Repo-memory branches are invisible to the working tree. A developer running `git status` or browsing the project directory sees nothing. The state machine cannot derive state from files that do not exist in the working tree.

**Why this is dangerous**: Repo-memory is a persistence mechanism for CI workflows, not a state machine substrate. The spec's state machine reads specific files at specific paths to determine what state it is in. If those files live on a separate git branch accessible only through gh-aw's tooling, the state machine breaks for every non-CI execution context. This recommendation would fork the orchestrator into two incompatible implementations: one for CI (repo-memory) and one for everything else (disk). Spec-kit's extension system has no concept of repo-memory branches -- extensions store state in the working tree under `.specify/`.

### 1.3 Mapping the work hierarchy to GitHub sub-issues creates platform coupling

**gh-aw position** (Section 3, "Sub-issue hierarchies for work decomposition"; Section 5, Recommendation 1): gh-aw recommends mapping the milestone/phase/task hierarchy to GitHub's sub-issue feature via `create-issue` with `parent` fields and `link-sub-issue` safe outputs. It presents this as the "native GitHub representation" of the orchestrator's work hierarchy.

**spec-kit position** (UTILIZATION.md Section 2, "Multi-agent compatibility" alignment; spec FR-032 line 264, FR-033 line 265, Constraint line 473): The spec explicitly requires working across all 17+ spec-kit-supported agents without agent-specific code paths and explicitly prohibits runtime dependencies on external platforms. The work hierarchy is defined by files on disk (roadmap, phase plans, task plans) that any agent can read. GitHub issues are a GitHub-specific representation that does not exist in Cursor, Windsurf, Cline, Aider, or any non-GitHub-connected agent runtime.

**Why this is dangerous**: If the orchestrator's work hierarchy is represented as GitHub sub-issues, the orchestrator becomes functionally dependent on the GitHub API for work decomposition -- a core P2 capability. Agents without GitHub access cannot enumerate phases, cannot check task status, and cannot advance the state machine. The spec's file-based hierarchy is deliberately platform-neutral. gh-aw's recommendation would make the orchestrator a GitHub-specific tool disguised as a spec-kit extension. The correct approach (which the spec takes) is: files on disk are the source of truth; GitHub representation is an optional projection for teams that use GitHub, not a replacement.

### 1.4 `dispatch-workflow` and `call-workflow` as dispatch primitives eliminate runtime portability

**gh-aw position** (Section 3, "dispatch-workflow safe output for task dispatch" and "call-workflow for synchronous phase execution"; Section 5, Recommendations 2 and 4): gh-aw recommends using `dispatch-workflow` as the CI dispatch primitive for task execution and `call-workflow` for synchronous phase reviews. It frames the spec's custom dispatch mechanism as "forcing implementers to build dispatch plumbing from scratch."

**spec-kit position** (UTILIZATION.md Section 4, "Command composition via wrapping"; spec FR-013 line 215, FR-034 line 269): The spec designs dispatch as an abstraction -- construct a minimal context payload, spawn a fresh agent context -- precisely because different runtimes implement "fresh context" differently. Claude Code uses subagent dispatch. Cursor uses new composer sessions. Copilot uses different mechanisms entirely. The spec's FR-013 requires supporting dispatch "where the agent runtime supports it" with fallback to "sequential in-session execution where it does not." This is a runtime-portable abstraction, not "custom plumbing."

**Why this is dangerous**: Hardwiring dispatch to `dispatch-workflow` and `call-workflow` makes the orchestrator's core execution loop (dispatch task, verify, advance) dependent on GitHub Actions workflow triggers. When running locally on Claude Code, there is no `dispatch-workflow`. When running on Cursor, there is no `call-workflow`. The spec's dispatch abstraction is correct: define what dispatch means semantically (fresh context, minimal payload, verification after completion), and let each runtime implement it with its available primitives. gh-aw's `dispatch-workflow` is one such implementation -- a valuable one for CI -- but it cannot be the dispatch primitive itself.

---

## 2. Tensions

### 2.1 Crash recovery: lock files vs. CI workflow run isolation

**gh-aw position** (Section 4, paragraph 1; Section 5, Recommendation 7): gh-aw argues that the lock-file crash recovery mechanism (FR-021) is "unnecessary in CI where each workflow run is a discrete, auditable unit" and recommends replacing lock files with CI-mode concurrency groups.

**spec-kit position** (UTILIZATION.md Section 2, "Disk-only state" alignment; spec FR-021 line 244, FR-049 line 312): Lock files are the mechanism by which the state machine distinguishes between crashes and graceful pauses. This is a local-execution concern that the spec correctly addresses.

**Tension**: gh-aw is right that lock files are redundant in CI -- workflow runs are inherently isolated. But the spec is right that they are necessary for local execution. The tension is about whether crash recovery should be runtime-aware (different mechanisms for CI vs. local) or runtime-agnostic (one mechanism everywhere).

**Resolution path**: The spec should define crash recovery as a capability with a pluggable detection mechanism. Lock files are the default (local) detector. In CI, the detector could use workflow run status instead. The orchestrator checks for the detector appropriate to its runtime context. This preserves the spec's portable state model while acknowledging that CI runtimes have better isolation primitives.

### 2.2 Progress tracking: disk-only vs. GitHub Projects

**gh-aw position** (Section 3, "GitHub Projects for progress tracking"; Section 5, Recommendation 6): gh-aw recommends using `update-project` safe outputs to maintain a GitHub Projects board as the orchestrator's progress dashboard, with custom fields for phase status, risk level, and blocker count.

**spec-kit position** (spec FR-038 line 275, FR-039 line 276): The spec requires that the progress overview be "derivable entirely from disk state, requiring no additional tracking beyond existing state files."

**Tension**: The spec's disk-only requirement ensures progress is always available without external dependencies. gh-aw's Projects recommendation adds a valuable collaboration layer but introduces a dependency on the GitHub API. The tension is between portability and team visibility.

**Resolution path**: Treat GitHub Projects as a projection layer, not a data source. The orchestrator derives progress from disk state (as the spec requires) and optionally syncs that progress to a GitHub Projects board when running in a gh-aw context. The sync is one-directional: disk to Projects. The status command always reads from disk. This satisfies FR-039 while giving teams the collaborative dashboard gh-aw envisions.

### 2.3 Priority of CI execution (P7 vs. P2-P3)

**gh-aw position** (Section 5, Recommendation 8): gh-aw recommends elevating US-7 (GitHub Agentic Workflows runtime) from P7 to P2 or P3, arguing that Tier C autonomous execution is the "primary value proposition" and gh-aw provides the most robust runtime for it.

**spec-kit position** (UTILIZATION.md, overall framing): spec-kit's review focuses on how the orchestrator integrates with the extension system, template resolution stack, and configuration infrastructure -- all of which are local-execution concerns. The extension system itself has no CI awareness.

**Tension**: gh-aw makes a legitimate point that the spec's core architecture should be CI-compatible from the start, not retrofitted. But spec-kit's concern is that elevating CI to P2-P3 would pressure the architecture toward CI-specific primitives (as evidenced by gh-aw's own recommendations to use dispatch-workflow, repo-memory, and concurrency groups as core primitives).

**Resolution path**: Keep CI execution at P7 as a delivery milestone but elevate "CI compatibility" as a design constraint from the start. The spec should add a constraint: "All state management, dispatch, and verification abstractions MUST be implementable in both local and CI execution contexts without forking the core logic." This gives gh-aw the design-time consideration it wants without promoting a specific CI platform to first-class status.

### 2.4 TaskOps pattern alignment vs. spec-kit SDD flow ownership

**gh-aw position** (Section 3, "TaskOps strategy alignment"): gh-aw notes that its TaskOps pattern (Research -> Plan -> Assign) maps "almost directly" to the spec's Tier C flow and suggests the spec should ground its design in TaskOps rather than "reinventing" the pipeline.

**spec-kit position** (UTILIZATION.md Section 4, "Skill folder architecture is orthogonal to the extension system"): spec-kit's review flags that the skill folder concept is already an import from a non-spec-kit pattern (APM/GSD-2). Adding TaskOps as another external pattern further dilutes the spec-kit-native architecture.

**Tension**: The spec's Tier C flow (discuss -> plan -> execute) is clearly influenced by patterns from GSD-2 and gh-aw's TaskOps. gh-aw wants explicit acknowledgment and alignment. spec-kit wants the orchestrator to map onto its own extension primitives, not import external pattern names.

**Resolution path**: The spec should document the intellectual lineage (TaskOps, GSD-2 phases) in a "Design Influences" section without creating runtime dependencies on those patterns. The orchestrator implements the concepts using spec-kit's native mechanisms (commands, hooks, templates, config). gh-aw gets the conceptual alignment it wants; spec-kit gets the architectural purity it needs.

### 2.5 Staged mode as dry-run vs. spec-kit's verification ladder

**gh-aw position** (Section 3, "Staged mode for dry-run verification"): gh-aw recommends using its staged mode as a pre-flight check for the two-stage review -- run the review workflow in staged mode, inspect outputs, then re-run with staging disabled.

**spec-kit position** (spec FR-016 through FR-018 lines 223-226): The spec defines its own verification ladder (static -> command -> behavioral -> human) which is runtime-agnostic and operates on disk artifacts.

**Tension**: gh-aw's staged mode is a powerful dry-run capability, but it is GitHub Actions-specific. The spec's verification ladder is designed to work on any runtime. Integrating staged mode as a verification step creates a CI-only code path in what should be a universal verification system.

**Resolution path**: The verification ladder should remain runtime-agnostic as specified. Staged mode could be exposed as an optional "CI-enhanced verification" step that runs in addition to the standard ladder when gh-aw is available. The spec's FR-018 already accommodates this -- its ladder is extensible, and staged mode would fit as an additional check at the "command checks" level for CI environments.

---

## 3. Safe Agreements

### 3.1 Tiered execution with zero overhead for simple work

**gh-aw position** (Section 2, first bullet): Agrees that the spec's Tier A/B/C classification correctly avoids requiring CI or heavy orchestration for simple tasks.

**spec-kit position** (UTILIZATION.md Section 2, "Zero overhead for Tier A"): Agrees this respects spec-kit's principle that the framework should not degrade the experience for work that does not need orchestration.

**Alignment**: Both reviews endorse the tiered model without modification. The spec's classification gates ensure the orchestrator adds value only when warranted. This is architecturally sound and requires no reconciliation.

### 3.2 Mechanical verification over self-assessment

**gh-aw position** (Section 2, fourth bullet): Agrees that the spec's insistence on mechanical verification at task and phase boundaries aligns with gh-aw's deterministic-agentic pattern.

**spec-kit position** (spec FR-016 line 223, FR-016a line 224): spec-kit's SDD philosophy requires evidence-based verification. The orchestrator's mechanical verification (file existence, content checks, connection verification) directly implements the "Evidence Before Claims" constitution principle.

**Alignment**: Both reviews endorse the spec's verification model as architecturally sound. gh-aw's deterministic-agentic pattern and spec-kit's evidence-based SDD converge on the same requirement: verification must be observable and reproducible, not dependent on agent self-report. The implementation will use different primitives per runtime (shell commands locally, workflow steps in CI), but the verification semantics are identical.

### 3.3 Idempotency as a first-class requirement

**gh-aw position** (Section 2, sixth bullet): Agrees that the spec's idempotency requirement (FR-066) is a direct match for how workflows should be designed, especially for scheduled workflows and retry scenarios.

**spec-kit position** (spec FR-066 line 360, SC-018 line 443): Idempotency is essential for an extension that may be invoked by different agents, in different sessions, with different retry behaviors. The spec's requirement that running any command twice produces identical disk state is the strongest form of this guarantee.

**Alignment**: Both reviews endorse idempotency without reservation. This is one of the spec's most important reliability properties and it serves both local and CI execution equally well. No reconciliation needed.

### 3.4 Fresh context per dispatch unit

**gh-aw position** (Section 2, second bullet): Agrees that the spec's requirement for fresh agent contexts per task dispatch aligns with gh-aw's `dispatch-workflow` model of independent runs.

**spec-kit position** (spec FR-012 line 214, FR-013 line 215; constitution Principle V "Fresh Context Per Unit"): Fresh context is a constitutional principle, not just an implementation detail. Each task gets only what it needs, preventing context pollution from prior tasks.

**Alignment**: Both reviews agree on the principle. The disagreement (addressed in Dangerous Contradictions 1.4) is about *how* dispatch is implemented, not *whether* it should produce fresh contexts. The semantic requirement is shared; the implementation mechanism must remain runtime-agnostic per spec-kit's position.

---

## 4. Summary Position

gh-aw's review is thorough and technically detailed. It correctly identifies that the spec underspecifies CI execution (US-7) and that gh-aw provides mature solutions to dispatch, state persistence, and concurrency problems that the spec addresses from scratch. These are valid observations.

However, gh-aw's recommendations consistently push the orchestrator toward GitHub Actions as a privileged runtime -- replacing portable abstractions (file-based state, generic dispatch, lock-file recovery) with GitHub-specific primitives (repo-memory, dispatch-workflow, concurrency groups). This conflicts with spec-kit's core architectural constraint: extensions must work across all supported agents and runtimes without platform-specific code paths.

The resolution is clear: the orchestrator's core architecture must remain runtime-agnostic as the spec intends. CI execution via gh-aw should be implemented as a **runtime adapter** -- a thin layer that maps the orchestrator's portable abstractions onto gh-aw's primitives when running in a GitHub Actions context. This gives gh-aw everything it wants (dispatch-workflow for tasks, repo-memory for state, concurrency groups for isolation) without compromising the orchestrator's portability for the 16+ other agent runtimes that spec-kit supports.

The spec should add a "Runtime Adapter" concept to its architecture: a pluggable layer where each runtime (local, gh-aw CI, future runtimes) implements the dispatch, persistence, and crash recovery interfaces using its own primitives. The orchestrator's core logic operates on the abstractions; adapters handle the platform specifics.
