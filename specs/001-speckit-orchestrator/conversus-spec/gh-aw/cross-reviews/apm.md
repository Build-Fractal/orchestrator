# gh-aw Cross-Review of APM's UTILIZATION.md

**Reviewer**: GitHub Agentic Workflows (gh-aw)
**Document reviewed**: `conversus/apm/UTILIZATION.md`
**Date**: 2026-03-18

---

## 1. Dangerous Contradictions

### 1.1 APM Hook Integration Bypasses gh-aw's Deterministic-Agentic Pattern

**APM position** (Section 3, bullet 2; Recommendation 5): APM recommends packaging the orchestrator's hooks as APM hook JSON files under `.apm/hooks/` so that `apm install` deploys them to `.github/hooks/`, `.claude/settings.json`, and `.cursor/hooks.json` automatically. APM frames this as "cross-agent hook deployment" and treats hook distribution as a solved problem within APM's install pipeline.

**gh-aw position** (UTILIZATION.md Section 2, bullet 4; Recommendation 4): gh-aw's deterministic-agentic pattern requires that verification and gate-keeping logic runs as deterministic pre/post steps within the workflow itself -- not as agent-side hooks that fire in the IDE. In CI, hooks deployed to `.github/hooks/` are irrelevant: the execution environment is a GitHub Actions runner, not an IDE. The orchestrator's phase-boundary verification (FR-016, FR-016a) must be implemented as `call-workflow` invocations of review workflows that produce typed, auditable outputs.

**Why this is dangerous**: If the spec follows APM's recommendation and implements verification gates exclusively as IDE-deployed hooks, those gates will be entirely absent in CI execution. A Tier C autonomous run dispatched via gh-aw would advance through phases with no verification whatsoever, because no IDE is present to fire the hooks. The spec's most critical safety mechanism -- mechanical verification before advancing (FR-016) -- would silently disappear in the runtime where autonomous execution matters most. Hooks are an IDE convenience; verification gates must be workflow-native to survive CI dispatch.

### 1.2 `apm compile` Constitution Injection vs. Repo-Memory State Management

**APM position** (Section 3, bullet 3; Recommendation 6-7): APM recommends using `apm compile` for constitution injection into `AGENTS.md` and shipping `.instructions.md` files with `applyTo` patterns for orchestrator state files. This assumes the orchestrator's governing principles and state-editing guidance are compile-time artifacts baked into instruction files before execution begins.

**gh-aw position** (UTILIZATION.md Section 3, bullet 4; Recommendation 3): gh-aw recommends storing orchestrator state (including decisions, knowledge, and governing documents) in repo-memory branches that are read and written during workflow execution. In CI, the constitution and accumulated knowledge must be fetched from the repo-memory branch at the start of each workflow run, not pre-compiled into a static instruction file that may be stale.

**Why this is dangerous**: Constitution injection via `apm compile` produces a point-in-time snapshot. The orchestrator's Principle 7 (Knowledge Compounds) requires that knowledge accumulates across phases -- meaning the constitution's practical interpretation evolves as DECISIONS.md grows. A compiled-in constitution cannot reflect decisions made in phase N when phase N+1's workflow starts. If the spec follows APM's compile-time injection, CI workflows will operate on stale context, violating the spec's own principle that "State On Disk Is Truth" (Principle 6). The constitution must be a runtime-read artifact, not a compile-time-embedded one.

### 1.3 APM's `apm pack` Bundle Model Conflicts with gh-aw's Native Dependency Resolution

**APM position** (Section 3, bullet 4; Recommendation 4): APM recommends `apm pack --archive` as the mechanism for CI artifact distribution, producing self-contained bundles that work "without APM, Python, or network access." APM frames this as necessary because "sandboxed gh-aw runners need" offline bundles.

**gh-aw position** (UTILIZATION.md Section 3, bullet 1; Recommendation 2): gh-aw workflows declare their dependencies in frontmatter, and the gh-aw activation job handles dependency installation before the agent job starts. gh-aw already supports APM frontmatter dependencies (the spec's own US-7 acceptance scenario 2 acknowledges this). The activation job runs `apm install` with network access -- it is only the agent job that is sandboxed. There is no need for pre-packed archives because the activation job resolves dependencies natively.

**Why this is dangerous**: If the spec adopts `apm pack` as the required CI distribution mechanism, it introduces a build step (pack the archive), a storage step (upload the artifact), and an extraction step (unpack in the runner) that are redundant with gh-aw's existing frontmatter-based dependency resolution. Worse, a packed bundle is a frozen snapshot -- it cannot pick up hotfixes to skill definitions or instruction updates without re-packing and re-uploading. This creates a stale-artifact risk in CI and adds operational overhead that gh-aw's native activation flow already eliminates. APM's recommendation is based on an incorrect assumption about gh-aw's sandboxing model.

### 1.4 Skill Folder `config.json` Overwrite Policy Breaks CI State Continuity

**APM position** (Section 4, bullet 2): APM identifies that `apm install` uses an "always-overwrite" policy for package-owned files, meaning skill folder `config.json` files are replaced on every install. APM recommends separating user configuration from skill-folder configuration, placing active config at `.specify/orchestrator/config.json`.

**gh-aw position** (UTILIZATION.md Section 4, bullet 3; Recommendation 3): gh-aw's repo-memory provides persistent, version-controlled state that survives across workflow runs. Configuration that evolves during orchestration (e.g., risk thresholds adjusted after a phase failure, verification strictness escalated after a crash recovery) must persist in repo-memory, not in the working tree where `apm install` can overwrite it and not in `.specify/orchestrator/` which is ephemeral in CI.

**Why this is dangerous**: APM's recommendation to move config to `.specify/orchestrator/config.json` solves the overwrite problem for local execution but creates a new problem in CI: that path is in the ephemeral working directory and is not automatically persisted between workflow runs. If the activation job runs `apm install` (which APM recommends), and the orchestrator's config has been modified by a previous run's decisions, those modifications are lost. APM's recommendation is correct for local-only usage but incomplete for the CI runtime that the spec's Tier C autonomous mode demands.

---

## 2. Tensions

### 2.1 Packaging Completeness vs. Runtime Adaptability

**APM position** (Recommendations 1, 2, 8): APM wants the orchestrator to be a fully specified APM package with a manifest, compilation targets, skill contracts, and version pinning. This is a "ship everything at install time" model.

**gh-aw position** (Recommendations 2, 3, 5): gh-aw wants the orchestrator to declare lightweight workflow definitions that dynamically read state and dispatch work at runtime. This is a "resolve at runtime" model.

**Tension**: These are not incompatible -- APM can package the workflow definitions and skill content, while gh-aw resolves the runtime state. But the spec needs to explicitly delineate which artifacts are install-time (skill definitions, SKILL.md files, instruction templates, workflow YAML) and which are runtime (orchestrator state, accumulated knowledge, active configuration, dispatch decisions). APM's review pushes everything toward install-time packaging; gh-aw pushes orchestrator intelligence toward runtime resolution. The spec must draw the line.

**Resolution path**: Adopt APM's packaging for static artifacts (skills, instructions, workflow templates) and gh-aw's repo-memory for dynamic state. The `apm.yml` manifest declares the package contents; the gh-aw workflow reads runtime state from repo-memory. Neither system owns both.

### 2.2 Multi-Agent Target Compilation vs. gh-aw's GitHub-Native Execution

**APM position** (Recommendation 8): APM recommends `target: all` for compilation, producing output for `.github/`, `.claude/`, `.cursor/`, and `.opencode/`. This reflects APM's multi-agent deployment philosophy.

**gh-aw position** (UTILIZATION.md Section 4, bullet 1; Recommendation 8): gh-aw operates exclusively within GitHub Actions. Its workflows, safe outputs, repo-memory, and concurrency controls are GitHub-native. There is no `.cursor/` or `.opencode/` equivalent in CI.

**Tension**: APM's `target: all` would deploy orchestrator artifacts to directories that gh-aw cannot use, wasting disk space in CI runners and potentially confusing agent runtimes that discover stale artifacts in directories they don't own. Conversely, compiling only for `.github/` would break local execution with non-GitHub agents.

**Resolution path**: Use conditional compilation targets. When running in CI (`GITHUB_ACTIONS=true`), compile for `.github/` only. When running locally, compile for detected agents. APM's manifest could specify `target: detect` or gh-aw's activation job could pass a compilation flag.

### 2.3 Knowledge Artifacts as APM Context Primitives vs. gh-aw Repo-Memory Documents

**APM position** (Section 3, bullet 5; Recommendation 6): APM recommends packaging KNOWLEDGE.md, DECISIONS.md, and phase summaries as `.context.md` files that participate in APM's context linking and compilation graph.

**gh-aw position** (UTILIZATION.md Section 2, bullet 3; Recommendation 3): gh-aw recommends these same artifacts live in repo-memory branches, read at workflow start and committed at workflow end.

**Tension**: If knowledge artifacts are APM context primitives, they are static files deployed at install time. If they are repo-memory documents, they are dynamic files that grow during execution. They cannot be both simultaneously. An APM-compiled KNOWLEDGE.md would be empty at install time (no knowledge has been generated yet), making context linking pointless. A repo-memory KNOWLEDGE.md would accumulate content but would not participate in APM's compilation graph.

**Resolution path**: Knowledge artifact templates (schema, headers, empty structure) are APM context primitives deployed at install time. Knowledge artifact content is repo-memory state populated at runtime. APM's context links point to the template for format guidance; the runtime reads/writes the repo-memory copy for actual content. The template and the runtime instance are separate files.

### 2.4 APM's Hook JSON Deployment vs. spec-kit's Extension Hook System

**APM position** (Recommendation 5): APM recommends packaging orchestrator hooks as APM hook JSON files for cross-agent deployment via `apm install`.

**Spec's design** (extension.yml lines 57-81): The spec defines hooks through spec-kit's own extension system -- `before_tasks`, `after_tasks`, `before_implement`, `after_implement` -- which are spec-kit lifecycle events, not IDE hooks.

**Tension**: APM's hook system and spec-kit's hook system serve different purposes. APM hooks fire in the IDE when certain file patterns are matched or certain actions are taken. Spec-kit hooks fire within the SDD workflow when spec-kit commands execute. APM's recommendation to repackage spec-kit hooks as APM hooks would change their semantics: they would fire at IDE events rather than SDD lifecycle events, potentially triggering at wrong times or missing the right times.

**Resolution path**: Keep spec-kit extension hooks as the primary hook mechanism for SDD lifecycle events. Use APM hooks only for IDE-level concerns that are genuinely outside spec-kit's lifecycle (e.g., warning when a user manually edits `.specify/orchestrator/` state files without going through the orchestrator commands).

### 2.5 Version Pinning Rigidity vs. Autonomous Evolution

**APM position** (Recommendation 9): APM recommends strict version pinning with `apm install speckit-orchestrator#v0.1.0`, lockfile SHA tracking, and clean uninstall verification.

**gh-aw position** (UTILIZATION.md Section 5, Recommendation 8): gh-aw recommends elevating CI execution to P2/P3, implying rapid iteration on the orchestrator's CI integration. Strict version pinning during active development creates friction: every workflow update requires a version bump, a new tag, and consumers must update their pinned version.

**Tension**: APM's version pinning is correct for stable releases but premature for a spec that is still in draft status. During the orchestrator's development phase, gh-aw workflows will change frequently as the dispatch model is refined. Pinning to a specific version means CI workflows lag behind the orchestrator's current capabilities.

**Resolution path**: Use APM's branch-based dependency syntax (`apm install speckit-orchestrator@main`) during development, switching to tag-based pinning (`#v1.0.0`) only at stable release. APM supports both; the spec should recommend the branch-based approach for pre-1.0 development.

---

## 3. Safe Agreements

### 3.1 APM Is Not a Runtime Dependency

**APM position** (Section 2, bullet 1): APM agrees with the spec that it should not be a runtime dependency (FR-033, FR-036). APM is an install-time tool.

**gh-aw position** (UTILIZATION.md Section 2, bullet 1): gh-aw agrees. The orchestrator's runtime behavior must not depend on APM being present. In CI, the activation job runs `apm install` before the agent job starts; the agent job itself never calls APM.

**Why this is safe**: Both reviews converge on the same architectural boundary. APM handles packaging and deployment; the orchestrator handles execution. Neither system needs the other at runtime. This is a clean separation that the spec already mandates.

### 3.2 Skill Folder Structure Is Architecturally Sound

**APM position** (Section 2, bullet 2): The spec's skill folder design (SKILL.md + scripts/ + templates/ + references/) is structurally compatible with APM's skill integration pipeline.

**gh-aw position** (UTILIZATION.md Section 2, bullet 1): gh-aw's tiered execution model does not conflict with the skill folder structure. Skills are content that gets deployed; gh-aw workflows are execution infrastructure that consumes that content.

**Why this is safe**: The skill folder structure is a content concern (what gets deployed), not a runtime concern (how it executes). APM deploys the folders; gh-aw workflows reference the deployed content. Both systems agree the structure works.

### 3.3 Mechanical Verification Is Non-Negotiable

**APM position** (Section 2, implicitly via alignment with FR-016/FR-016a): APM does not challenge the mechanical verification requirement.

**gh-aw position** (UTILIZATION.md Section 2, bullet 4): gh-aw explicitly endorses mechanical verification and maps it to the deterministic-agentic pattern.

**Why this is safe**: Both reviews agree that verification must be mechanical, not self-assessed. The disagreement (see Contradiction 1.1) is about where verification runs (IDE hooks vs. workflow steps), not whether it should exist. The principle is shared; only the implementation mechanism is contested.

### 3.4 The Spec Underspecifies Both APM and gh-aw Integration

**APM position** (Section 1, Executive Summary): "The spec's treatment of APM is thin relative to what APM actually offers."

**gh-aw position** (UTILIZATION.md Section 1, Executive Summary): "The spec treats [CI-based execution] as a 'nice-to-have' enhancement rather than a first-class execution runtime."

**Why this is safe**: Both reviews independently conclude that the spec acknowledges their respective systems but does not integrate deeply enough with either. This shared diagnosis means the spec needs more integration work with both systems -- and that work should be coordinated to avoid the contradictions identified above.

---

## 4. Summary

APM's review is thorough on packaging concerns but systematically underestimates CI execution requirements. Its recommendations are correct for the local development workflow but create gaps or conflicts when the orchestrator runs autonomously in CI via gh-aw. The most dangerous pattern is APM's tendency to solve runtime problems with install-time mechanisms (compiled constitutions, pre-packed bundles, IDE-deployed hooks) -- all of which break down in an ephemeral CI environment where state must be managed dynamically.

The resolution strategy across all contradictions follows a single principle: **static content is APM's domain; dynamic state and execution are gh-aw's domain.** Skills, instructions, workflow templates, and constitution schemas are install-time artifacts managed by APM. Orchestrator state, accumulated knowledge, runtime configuration, verification gates, and dispatch decisions are runtime concerns managed by gh-aw's repo-memory, safe outputs, and workflow infrastructure. Neither system should reach into the other's domain.
