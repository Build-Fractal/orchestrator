# APM Cross-Review of gh-aw's UTILIZATION.md

**Reviewer**: APM (Agent Package Manager)
**Subject**: gh-aw's UTILIZATION.md for speckit-orchestrator spec
**Date**: 2026-03-18

---

## 1. Dangerous Contradictions

### 1.1 "Design for CI dispatch as the primary autonomous runtime" vs. APM's runtime-agnostic packaging model

**gh-aw position** (Section 4, Off-Base Assumptions, bullet 1): "The assumption should be reversed: design for CI dispatch as the primary autonomous runtime, with local execution as the development/debugging mode."

**APM position** (Section 2, Alignment, bullet 1): "APM appears [correctly] as the distribution mechanism... the spec correctly identifies APM as the distribution mechanism and gh-aw integration layer, and it explicitly avoids making APM a runtime dependency (FR-033, FR-036). This is a sound architectural decision."

**Why this is dangerous**: gh-aw recommends inverting the spec's execution model so that CI is primary and local is secondary. APM packages must work identically regardless of runtime context -- the same `apm install` deploys skills, hooks, and instructions whether the consumer is a developer's laptop, a Copilot agent session, a Cursor workspace, or a gh-aw CI runner. If the orchestrator's core architecture is designed CI-first, its state management (repo-memory branches), dispatch model (workflow_dispatch), and persistence (ephemeral working directories) will be gh-aw-native primitives that do not exist outside CI. APM's skill integration pipeline copies skill folders to `.github/skills/`, `.claude/skills/`, `.cursor/skills/` -- these are filesystem paths that assume local persistence. An orchestrator designed for repo-memory branches as its primary state store cannot be meaningfully packaged by APM for local consumption without a translation layer the spec does not describe. The spec's current local-first design with CI as an adaptation layer (US-7) is the correct orientation for an APM-distributable package. gh-aw is one runtime among many; it should not dictate the core architecture.

### 1.2 "Replace lock files with CI concurrency groups" vs. APM's file-based state tracking

**gh-aw position** (Section 5, Recommendation 7): "Replace the lock file requirement with a CI-mode concurrency configuration" using gh-aw's per-workflow concurrency groups and `job-discriminator`.

**APM position** (Section 3, Missed Opportunities, bullet 6): APM tracks all deployed files via `apm.lock.yaml` and requires file-based state for collision detection, sync operations, and uninstall cleanup. (Section 5, Recommendation 9): APM explicitly recommends adding version pinning acceptance scenarios where `apm.lock.yaml` records exact commit SHAs and all deployed files.

**Why this is dangerous**: gh-aw proposes replacing file-based lock mechanisms with GitHub Actions concurrency primitives. APM's entire lifecycle management -- install, sync, uninstall, collision detection -- depends on file-based state tracking via `apm.lock.yaml` and the orchestrator's own state files under `.specify/orchestrator/`. If the orchestrator drops lock files in CI mode, APM cannot track what was deployed, detect collisions with other packages, or perform clean uninstalls. The orchestrator's lock file (FR-021) serves a different purpose than gh-aw's concurrency groups: it records execution state for crash recovery, not just mutual exclusion. These are complementary mechanisms, not substitutes. The spec should retain file-based locks as the universal mechanism and layer gh-aw concurrency groups on top in CI mode, not replace one with the other.

### 1.3 "Use repo-memory for durable orchestrator state" vs. APM's `.specify/orchestrator/` filesystem contract

**gh-aw position** (Section 5, Recommendation 3): "Create a repo-memory configuration that maps to the spec's state directories: `memory/orchestrator-decisions` for DECISIONS.md, `memory/orchestrator-knowledge` for KNOWLEDGE.md... Each workflow run reads state from the memory branch, makes changes, and auto-commits on completion. This eliminates the need for manual git operations and crash-recovery lock files in CI."

**APM position** (Section 3, Missed Opportunities, bullet 5): APM recommends packaging KNOWLEDGE.md, DECISIONS.md, and phase summaries as `.context.md` files that participate in APM's context linking and compilation pipeline. (Section 5, Recommendation 6): "Package knowledge artifacts as APM context primitives."

**Why this is dangerous**: gh-aw wants orchestrator state to live on repo-memory git branches (`/tmp/gh-aw/repo-memory-{id}/`). APM wants the same artifacts to be `.context.md` files that it discovers, links, and compiles into agent instruction sets. These two models are mutually exclusive at a filesystem level: repo-memory branches are invisible to APM's install-time file discovery, which scans the working tree and package source directories. If DECISIONS.md lives on a repo-memory branch, APM cannot discover it for context linking. If it lives in `.specify/orchestrator/`, gh-aw must explicitly sync it to/from the working tree on every workflow run. The spec's current design (state on disk at `.specify/orchestrator/`) is the only model that serves both consumers. gh-aw's recommendation should be constrained to caching/mirroring, not primary storage.

### 1.4 "Use `create-agent-session` / `assign-to-agent` for task execution" vs. APM's agent-agnostic skill deployment

**gh-aw position** (Section 5, Recommendation 5): "Instead of custom dispatch to 'fresh agent contexts,' leverage gh-aw's ability to create Copilot coding agent sessions or assign Copilot to task issues."

**APM position** (Section 2, Alignment, bullet 5): The spec's multi-agent compatibility requirement (FR-032) aligns with APM's multi-target deployment model covering `.github/` (Copilot), `.claude/` (Claude), `.cursor/` (Cursor), `.opencode/` (OpenCode). (Section 5, Recommendation 8): The orchestrator's compilation target should be `all`.

**Why this is dangerous**: gh-aw's recommendation hardcodes Copilot as the task execution agent. The spec explicitly requires multi-agent compatibility (FR-032, SC-007). APM deploys the orchestrator's skills to all detected agent targets -- Copilot, Claude Code, Cursor, Gemini CLI, OpenCode. If the orchestrator's dispatch model is built around `create-agent-session` (a Copilot-specific primitive), it cannot dispatch tasks to Claude Code sessions, Cursor agents, or any other runtime. The spec's generic "fresh agent context" model is deliberately agent-agnostic; gh-aw's recommendation narrows it to a single vendor. This directly contradicts both the spec's FR-032 and APM's multi-target deployment model.

---

## 2. Tensions

### 2.1 Elevating US-7 priority vs. spec's deliberate sequencing

**gh-aw position** (Section 5, Recommendation 8): "Elevate US-7 (CI execution) to P2 or P3... CI execution should be a design consideration from the start -- not an afterthought."

**APM position** (Section 1, Executive Summary): APM notes US-8 (APM Packaging) is P8 and thin, but does not argue for reprioritization -- instead recommends deepening the existing user stories with concrete deliverables (apm.yml manifest, compilation targets, version pinning).

**Tension**: gh-aw wants CI execution elevated to near the top of the priority stack. APM wants packaging depth added to the existing priority. Both are valid -- the spec underspecifies both CI and packaging. However, elevating US-7 to P2/P3 while US-8 remains at P8 creates a sequencing problem: CI execution via gh-aw depends on APM packaging (gh-aw workflows declare APM frontmatter dependencies, `apm pack` produces CI bundles). You cannot meaningfully implement CI dispatch without first having a packaged artifact to dispatch.

**Resolution path**: Elevate both US-7 and US-8 together, or define US-8 as a dependency of US-7. The spec should not implement CI dispatch before the packaging contract is defined.

### 2.2 TaskOps as the orchestration pattern vs. spec-kit SDD as the orchestration pattern

**gh-aw position** (Section 3, Missed Opportunities, bullet 8): "gh-aw's TaskOps pattern (Research -> Plan -> Assign) maps almost directly to the spec's Tier C flow (discuss -> plan -> execute). The spec does not reference TaskOps at all, missing an opportunity to ground its design in a proven gh-aw pattern."

**APM position** (Section 1, Executive Summary): The orchestrator's value is in the "orchestration intelligence (what to dispatch, how to verify, when to escalate)" and APM treats spec-kit's own SDD flow as the canonical process the orchestrator manages.

**Tension**: gh-aw sees TaskOps as a proven pattern the spec should adopt. APM sees the spec-kit SDD workflow as the canonical pattern. These are not the same: TaskOps is Research -> Plan -> Assign (three steps, CI-native); spec-kit SDD is specify -> clarify -> plan -> tasks -> implement -> verify (six steps, agent-native). The orchestrator's job is to manage multiple SDD flows, not to replace SDD with TaskOps.

**Resolution path**: TaskOps can serve as the CI-level dispatch pattern (how gh-aw triggers and monitors orchestrator runs), while spec-kit SDD remains the domain-level execution pattern (what the orchestrator actually orchestrates). These are different layers -- gh-aw manages workflow dispatch, the orchestrator manages SDD steps. Frame TaskOps as the CI adapter pattern, not the orchestration model.

### 2.3 GitHub sub-issues as work hierarchy vs. filesystem-based hierarchy

**gh-aw position** (Section 3, Missed Opportunities, bullet 6; Section 5, Recommendation 1): "Map the work hierarchy to GitHub sub-issues... milestones as parent issues, phases as sub-issues, tasks as sub-sub-issues."

**APM position** (Section 2, Alignment, bullet 1): APM endorses the spec's principle that "State On Disk Is Truth" (Constitution Principle 6) and that `.specify/orchestrator/` is the source of truth for orchestrator state.

**Tension**: gh-aw wants GitHub Issues to be the canonical representation of the work hierarchy. The spec (and APM's endorsement) says disk state is truth. If issues are created as a mirror of disk state, they drift unless kept in sync -- and sync is expensive. If issues become the primary representation, disk state becomes a cache, violating the constitution.

**Resolution path**: GitHub sub-issues as a read-only projection of disk state, created and updated by a CI workflow that reads `.specify/orchestrator/` and syncs to GitHub Issues. Never the reverse. The spec's disk state remains authoritative; issues are a visibility layer.

### 2.4 `dispatch-workflow` as the dispatch primitive vs. generic context spawning

**gh-aw position** (Section 3, Missed Opportunities, bullet 1; Section 5, Recommendation 2): "Use `dispatch-workflow` as the CI dispatch primitive... define a `task-worker.md` agentic workflow that accepts the task payload via `workflow_dispatch.inputs`."

**APM position** (implicit): APM's packaging model delivers skills and instructions to multiple agent runtimes. The dispatch mechanism must be runtime-pluggable, not hardcoded to any single dispatch primitive.

**Tension**: `dispatch-workflow` is a sound CI dispatch mechanism, but making it the dispatch primitive couples the orchestrator to gh-aw's workflow model. The spec currently describes dispatch abstractly (FR-012, FR-013) -- "construct a context payload and spawn a fresh agent context" -- which is runtime-agnostic. Adopting `dispatch-workflow` as the primitive means the orchestrator's dispatch layer must be an abstraction with gh-aw as one implementation.

**Resolution path**: Define a dispatch interface in the spec (payload format, completion signaling, result collection) and specify `dispatch-workflow` as the gh-aw implementation of that interface. APM can then package multiple dispatch adapters (gh-aw, local subprocess, Claude Code task, Cursor agent) as skill variants.

### 2.5 Slash command triggers vs. spec-kit command composition

**gh-aw position** (Section 5, Recommendation 9): "Adopt the `slash_command` trigger for interactive orchestration. A `/orchestrate discuss` or `/orchestrate inject` command in a GitHub issue would trigger the orchestrator workflow."

**APM position**: The spec's commands are spec-kit extension commands (`speckit.orchestrator.*`) invoked via spec-kit's slash command system in agent contexts, not GitHub issue comments.

**Tension**: Two different slash command systems with the same syntax but different execution models. gh-aw's `slash_command` triggers GitHub Actions workflows from issue/PR comments. Spec-kit's slash commands trigger agent-context skill execution. If both exist, `/orchestrate discuss` means different things depending on whether you type it in a GitHub issue or a Claude Code session.

**Resolution path**: Namespace them explicitly. Spec-kit commands remain `speckit.orchestrator.*` (agent-context). gh-aw slash commands use a different prefix like `/ci orchestrate` or are triggered by issue labels rather than comment commands, avoiding collision with the spec-kit command namespace.

---

## 3. Safe Agreements

### 3.1 Tiered execution with graceful degradation

**gh-aw position** (Section 2, Alignment, bullet 1): "The spec's Tier A/B/C classification mirrors gh-aw's own design philosophy where simple workflows coexist with complex multi-job orchestration patterns."

**APM position** (Section 2, Alignment, bullet 1): APM endorses FR-033/FR-036 and the principle that the orchestrator should not require heavy infrastructure for simple tasks.

**Agreement**: Both reviews endorse the three-tier model and agree that the orchestrator should avoid imposing unnecessary overhead on simple tasks. APM packages this by deploying different skill subsets per tier; gh-aw supports it by not requiring CI dispatch for Tier A/B. No conflict.

### 3.2 Mechanical verification at phase boundaries

**gh-aw position** (Section 2, Alignment, bullet 4): "The spec's insistence on mechanical (not self-assessed) verification at both task and phase boundaries aligns with gh-aw's deterministic-agentic pattern."

**APM position** (Section 5, Recommendation 7): APM recommends shipping `.instructions.md` files with `applyTo` patterns for orchestrator state files, which would include verification result formats and expectations.

**Agreement**: Both reviews support the spec's mechanical verification requirement (FR-016, FR-016a). gh-aw provides CI-native verification via deterministic pre/post steps. APM provides agent-native verification guidance via compiled instructions. These are complementary implementations of the same principle at different runtime layers. No conflict.

### 3.3 Idempotency requirement

**gh-aw position** (Section 2, Alignment, bullet 6): "The spec's requirement that all orchestrator commands are idempotent is a direct match for how gh-aw workflows should be designed."

**APM position** (implicit in Section 5, Recommendation 9): APM's version pinning and lockfile tracking depend on idempotent install/uninstall operations. An orchestrator that is not idempotent cannot be reliably managed by APM.

**Agreement**: Both reviews consider idempotency (FR-066) essential. gh-aw needs it for retry safety; APM needs it for lifecycle management reliability. The spec's requirement serves both consumers without modification.

### 3.4 Fresh context per dispatch unit

**gh-aw position** (Section 2, Alignment, bullet 2): "The spec's requirement that each task dispatches to a fresh agent context with a minimal payload aligns with gh-aw's `dispatch-workflow` model."

**APM position** (Section 2, Alignment, bullet 1): APM endorses the spec's context minimization principle (Constitution Principle 1) and the design that avoids runtime coupling.

**Agreement**: Both reviews endorse fresh-context dispatch (FR-012, FR-013) as architecturally sound. The disagreement is only about the dispatch mechanism (gh-aw's `dispatch-workflow` vs. generic spawning), not the principle itself. The principle is safe common ground.

---

## Summary

gh-aw's review is thorough and technically precise about CI capabilities, but it consistently recommends making gh-aw primitives the primary implementation rather than one adapter among many. Three of the four dangerous contradictions stem from the same root: gh-aw treats itself as the orchestrator's primary runtime, while the spec (and APM's review) treats it as one of several runtimes the orchestrator must support. The resolution is consistent: design the orchestrator's core around runtime-agnostic abstractions (filesystem state, generic dispatch interfaces, agent-neutral skill deployment) and implement gh-aw integration as an adapter layer that maps these abstractions to `dispatch-workflow`, `repo-memory`, concurrency groups, and sub-issues. APM packages the core and the adapter separately; consumers who use gh-aw get both, consumers who don't get only the core.
