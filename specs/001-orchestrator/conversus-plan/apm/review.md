# APM Review: Speckit-Orchestrator Extension — Implementation Planning Artifacts

**Reviewer**: APM (Agent Package Manager)
**Date**: 2026-03-19
**Artifacts reviewed**: `data-model.md`, `plan.md`, `quickstart.md`, `research.md`

---

## Executive Summary

The speckit-orchestrator artifacts describe a spec-kit extension that adds autonomous multi-phase orchestration (milestone/phase/task hierarchy, file-based state machine, runtime adapters, mechanical verification, continuous knowledge generation) to spec-kit's SDD workflow. The extension is implemented as markdown command templates plus bash scripts, distributed as an APM package via `apm.yml`, and deployed into the spec-kit extension directory. The conversus process has already resolved the most contentious APM-related disputes — command-centric layout over parallel `skills/` tree (AD-6, R-001), config outside APM's deployment radius (R-004), and deployment directory boundary separation (AD-7) — in ways that are architecturally sound from APM's perspective, even where they deviated from APM's initial position.

The plan demonstrates a solid understanding of APM's deployment model, particularly the always-overwrite semantics that necessitate the strict separation between `.specify/extensions/orchestrator/` (APM-managed, overwritable) and `.specify/orchestrator/` (runtime state, never touched by install). The `apm.yml` manifest is mentioned as a deliverable (plan.md line 62), and the extension is explicitly designed to be installable via both `specify extension add` and `apm install` (quickstart.md lines 17-20). However, the artifacts treat APM almost exclusively as a distribution pipe and miss several opportunities to use APM primitives — compilation, context files, instructions, hooks — to solve problems the orchestrator is re-implementing from scratch.

**Most important recommendation**: Define a real `apm.yml` manifest with typed dependencies, compilation settings, and scripts, rather than treating it as a metadata-only placeholder. The orchestrator's dispatch payload construction (R-005) is essentially re-inventing context compilation; APM's compilation system could handle constitution injection, instruction scoping by file pattern, and context linking, reducing the surface area of custom bash scripts.

---

## Alignment

- **[Deployment Boundary]** (plan.md line 151, AD-7): The strict separation between `.specify/extensions/orchestrator/` (APM-managed deployment target, overwritten on install) and `.specify/orchestrator/` (runtime state, never touched by install) correctly accounts for APM's always-overwrite deployment semantics. This is the single most important APM concern and the plan gets it right.

- **[Config Outside APM Radius]** (research.md lines 104-126, R-004): User-mutable config (`orchestrator-config.yml`, `orchestrator-config.local.yml`) is explicitly placed outside APM-managed directories, with the constraint "User-mutable config MUST NOT reside in APM-managed directories (FR-070)" at line 126. This directly addresses the APM-overwrite problem documented in the research.

- **[Dual Installation Path]** (quickstart.md lines 12-20): Supporting both `specify extension add` and `apm install` correctly positions APM as the distribution mechanism while spec-kit remains the runtime host. This matches AD-1 (plan.md line 133) — "spec-kit extension that APM distributes."

- **[Command Frontmatter as Single Source]** (plan.md lines 147-148, AD-6): The decision that skill metadata lives in command markdown frontmatter and APM derives `SKILL.md` at install time is a pragmatic resolution. It avoids the maintenance burden of parallel hierarchies while preserving APM discoverability. This aligns with APM's skill detection model (skills.md lines 277-287) where APM auto-detects package type from content.

- **[apm.yml as Deliverable]** (plan.md line 62): Including `apm.yml` in the project structure acknowledges APM's manifest as the distribution contract. The manifest schema (manifest-schema.md sections 2-3) requires `name` and `version` at minimum, and the plan implicitly commits to providing these.

- **[Extension-First, APM-Distributes Model]** (plan.md lines 162-166, Dispute D4): The resolution — committed extension is default, APM-managed is supported but not canonical — correctly positions APM's value as upgrade management and dependency resolution rather than runtime control. This preserves APM's `apm install --update` flow (manifest-schema.md lines 386-388) without forcing APM as a runtime dependency.

---

## Missed Opportunities

- **[APM Compilation for Constitution Injection]** The orchestrator's dispatch payload (research.md lines 130-167, R-005) always includes "Constitution Principles" as a section. APM's compilation system already has a constitution injection feature (compilation.md lines 363-370, key-concepts.md lines 515-531) that automatically injects `memory/constitution.md` at the top of compiled output with hash-based drift detection and idempotent regeneration. The orchestrator could leverage `apm compile` to handle constitution injection into dispatch templates rather than implementing custom `build-context.sh` logic. **Impact: Medium** — reduces custom script surface area by ~1 script and ensures constitution drift is detected automatically.

- **[APM Instructions for Scope-Filtered Context]** The knowledge scoping strategy (research.md lines 236-251, R-008) and dispatch payload construction use custom `scope-filter.sh` to filter KNOWLEDGE.md and DECISIONS.md by scope tags. APM's `.instructions.md` primitive (key-concepts.md lines 132-145) already supports `applyTo` glob patterns that target specific file types and directories. The orchestrator's scope tags (`project`, `milestone:{M###}`, `phase:{M###/P##}`) could map to APM instruction files with `applyTo` patterns matching the orchestrator's directory structure, letting APM's compilation engine handle the filtering. **Impact: Medium-High** — scope filtering is one of the orchestrator's most complex subsystems and APM's pattern-matching is already battle-tested.

- **[APM Context Files for Knowledge Artifacts]** The orchestrator produces structured knowledge artifacts (DECISIONS.md, KNOWLEDGE.md, phase/milestone summaries) that are essentially `.context.md` files by another name. APM's context linking system (key-concepts.md lines 399-452) supports automatic link resolution and composable knowledge graphs. If summaries were formatted as `.context.md` files, other APM primitives could reference them via markdown links and APM would resolve paths automatically. **Impact: Low-Medium** — the orchestrator's knowledge artifacts serve a different lifecycle (runtime-generated vs. authored), but adopting the format would enable cross-tool discoverability.

- **[APM Scripts for Verification Commands]** The `apm.yml` manifest supports a `scripts` field (manifest-schema.md lines 139-148) with named commands executed via `apm run <name>`. The orchestrator's verification commands (currently configured in `orchestrator-config.yml` as plain shell strings) could be registered as APM scripts, enabling `apm run verify-phase`, `apm run check-must-haves`, etc. This would give the orchestrator's verification pipeline visibility in the APM ecosystem and allow other packages to depend on or extend these scripts. **Impact: Low** — primarily a discoverability and interoperability improvement.

- **[APM Hooks for Lifecycle Events]** APM supports hooks (key-concepts.md lines 352-382) with `PreToolUse`, `PostToolUse`, `Stop`, `Notification`, and `SubagentStop` events. The orchestrator's spec-kit hook integration (research.md lines 280-298, R-010) covers 4 spec-kit lifecycle points but does not consider APM hooks as a complementary mechanism. For tools that support APM hooks natively (Claude, Copilot), the orchestrator could register `PostToolUse` hooks to trigger verification after file writes, supplementing the spec-kit hook system. **Impact: Low** — spec-kit hooks are the correct primary mechanism, but APM hooks could provide defense-in-depth for verification.

- **[APM Lockfile for Reproducible Extension State]** The plan mentions `apm.yml` as a deliverable but does not discuss `apm.lock.yaml` (manifest-schema.md lines 358-399). For teams installing the orchestrator via APM, the lockfile pins the exact commit SHA and deployed files, enabling reproducible installations and rollback. The plan should explicitly state that `apm.lock.yaml` is committed alongside `apm.yml` so that orchestrator version pinning is deterministic. **Impact: Medium** — without lockfile awareness, teams using `apm install` may get non-reproducible orchestrator versions.

- **[APM Package Type Declaration]** The `apm.yml` manifest supports a `type` field (manifest-schema.md lines 121-138) with values `instructions`, `skill`, `hybrid`, `prompts`. The orchestrator is a hybrid package (it has commands/prompts and would benefit from SKILL.md generation), but the plan does not specify which `type` to declare. Setting `type: hybrid` would ensure APM processes both the skill metadata derivation and any instruction files the extension bundles. **Impact: Low** — APM auto-detects type from content, but explicit declaration is clearer.

- **[APM Target Configuration for Multi-Agent Support]** The orchestrator aims to support all spec-kit-supported agents (Claude Code, Copilot, Cursor, Gemini CLI). APM's `target` field (manifest-schema.md lines 103-119) and compilation targets (compilation.md lines 16-48) control which output formats are generated. The plan should specify `target: all` in `apm.yml` to ensure the orchestrator's context primitives compile correctly for all supported agents. **Impact: Low** — this is primarily a configuration detail but ensures multi-agent parity from day one.

---

## Off-Base Assumptions

- **[SKILL.md Derivation at Install Time]** (plan.md lines 147-148, AD-6; research.md lines 10-25, R-001): The plan states "APM derives skill metadata from command frontmatter at install time." This is not how APM currently works. APM's skill integration (skills.md lines 39-57) copies existing `SKILL.md` files to target directories (`.github/skills/`, `.claude/skills/`, etc.) and detects package type based on file presence (skills.md lines 277-287). APM does **not** have a facility to synthesize `SKILL.md` from non-SKILL frontmatter at install time. If the orchestrator wants skill discoverability, it must either (a) include a `SKILL.md` in the package root, or (b) include skill definitions in `.apm/skills/*/SKILL.md` for sub-skill promotion (skills.md lines 237-275). The "derive at install time" model would require APM feature work that does not exist today.

- **[`.instructions.md` as Supplementary]** (plan.md lines 162-163, Dispute D2): The plan positions `.instructions.md` as "supplementary, not primary" to "avoid soft APM runtime dependency." This mischaracterizes the relationship. APM instructions are deployed by `apm install` into `.github/instructions/` or equivalent target directories (compilation.md lines 70-81), where they are consumed by the AI agent directly — no APM runtime is required after installation. The `.instructions.md` files are static assets, not a runtime dependency. The plan's concern about "soft APM runtime dependency" conflates install-time integration with runtime dependency. Instructions could serve as the orchestrator's primary mechanism for injecting file-pattern-scoped guidance without any runtime coupling to APM.

- **[No APM Runtime Dependencies Constraint is Moot]** (plan.md line 19): The constraint "no GSD-2 or APM runtime dependencies" is stated as if APM imposes runtime requirements. APM is a package manager — it runs at install time and compile time, never at runtime. After `apm install`, all primitives are static files on disk. The orchestrator's runtime is entirely bash scripts and spec-kit commands; APM never enters the execution path. The constraint is satisfied by default and does not need to be stated as a design constraint. Stating it suggests a misunderstanding of APM's execution model.

---

## Actionable Recommendations

1. **P1 — Create a concrete `apm.yml` manifest for the extension package.**
   - **Current**: `apm.yml` listed as a deliverable (plan.md line 62) but no schema or content specified.
   - **Proposed**: Define `name: speckit-orchestrator`, `version: 0.1.0`, `type: hybrid`, `target: all`, with `scripts` entries for key operations (`verify`, `status`, `scaffold`) and `compilation` settings excluding `.specify/orchestrator/` from compilation scope.
   - **Rationale**: The manifest schema (manifest-schema.md sections 2-5) defines `name` and `version` as REQUIRED fields. Without a concrete manifest, APM cannot resolve, install, or lock the package. The `scripts` field (manifest-schema.md lines 139-148) provides discoverability for orchestrator operations.
   - **Risk if ignored**: The extension is not installable via `apm install` despite the quickstart claiming it is (quickstart.md line 19).

2. **P1 — Include a root-level `SKILL.md` instead of relying on "derive at install time."**
   - **Current**: Plan assumes APM will derive skill metadata from command frontmatter (AD-6, plan.md line 148).
   - **Proposed**: Author a `SKILL.md` at package root with `name: speckit-orchestrator` and `description: Autonomous multi-phase orchestration for spec-kit` frontmatter, body summarizing the 10 commands and their relationships.
   - **Rationale**: APM detects skill packages by `SKILL.md` presence (skills.md lines 277-287). The derive-at-install-time capability does not exist. Without a `SKILL.md`, the package will not be discovered as a skill by any agent tool.
   - **Risk if ignored**: Zero skill discoverability in `.github/skills/`, `.claude/skills/`, `.cursor/skills/` — agents cannot discover the orchestrator's capabilities through the standard skill interface.

3. **P1 — Commit `apm.lock.yaml` for reproducible installations.**
   - **Current**: Lockfile not mentioned in plan or project structure.
   - **Proposed**: Add `apm.lock.yaml` to the project structure section (plan.md lines 56-124) and document that consuming projects should commit the lockfile.
   - **Rationale**: The lockfile specification (manifest-schema.md lines 358-399) mandates that resolvers write `apm.lock.yaml` after successful resolution. It pins exact commit SHAs and deployed files. Without lockfile documentation, teams installing the orchestrator via APM get non-reproducible installs.
   - **Risk if ignored**: Version drift across team members; inability to rollback to a known-good orchestrator version.

4. **P2 — Use APM `.instructions.md` for file-pattern-scoped orchestrator guidance.**
   - **Current**: The orchestrator plans custom `scope-filter.sh` for knowledge injection (research.md lines 236-251).
   - **Proposed**: Author `.apm/instructions/orchestrator-state.instructions.md` with `applyTo: ".specify/orchestrator/**"` containing state machine rules and file format specs. Author `.apm/instructions/orchestrator-commands.instructions.md` with `applyTo: "commands/**/*.md"` containing command authoring standards.
   - **Rationale**: APM instructions (key-concepts.md lines 132-145) are deployed as static files and apply automatically based on glob patterns — no runtime dependency. They solve the same problem as scope-filtered knowledge injection but leverage the AI agent's native instruction loading rather than custom prompt construction.
   - **Risk if ignored**: Missed opportunity to reduce dispatch payload complexity; custom scope filtering remains a maintenance burden.

5. **P2 — Leverage APM compilation's constitution injection instead of custom `build-context.sh`.**
   - **Current**: Dispatch payload includes constitution principles via custom script (research.md lines 155-157, R-005).
   - **Proposed**: Place constitution at `memory/constitution.md` (or `.specify/memory/constitution.md`) and configure `apm compile` to inject it. The compilation system (compilation.md lines 363-370) handles injection with hash-based drift detection and idempotency.
   - **Rationale**: Constitution injection is already implemented in APM (key-concepts.md lines 515-531). Using it reduces custom code and adds automatic drift detection (the hash changes when constitution content changes, signaling recompilation).
   - **Risk if ignored**: Low — the custom approach works, but constitution drift goes undetected.

6. **P2 — Declare `compilation.exclude` to prevent APM from scanning runtime state.**
   - **Current**: No compilation configuration specified for the extension.
   - **Proposed**: In `apm.yml`, set `compilation.exclude: [".specify/orchestrator/**"]` to prevent APM from scanning runtime-generated artifacts during compilation.
   - **Rationale**: The compilation system (compilation.md lines 285-311) scans directories for primitives. Without exclusion, APM would attempt to parse KNOWLEDGE.md, DECISIONS.md, and summary files as potential context files, producing noise or errors.
   - **Risk if ignored**: Compilation failures or spurious warnings when running `apm compile` in a project with active orchestrator state.

7. **P2 — Register key orchestrator operations as APM scripts.**
   - **Current**: Orchestrator operations are invoked exclusively through spec-kit slash commands.
   - **Proposed**: Register scripts in `apm.yml`: `scripts: { status: "bash scripts/state/derive-phase.sh", verify: "bash scripts/verify/check-must-haves.sh", scaffold: "bash scripts/lifecycle/scaffold.sh" }`.
   - **Rationale**: The `scripts` field (manifest-schema.md lines 139-148) enables `apm run <name>` invocation, providing a CI-friendly entry point for orchestrator operations that does not require an interactive AI agent session. This is especially relevant for the gh-aw CI adapter (research.md line 95) which needs non-interactive invocation.
   - **Risk if ignored**: CI/automation must invoke scripts by path rather than by name; no `--param` substitution support.

8. **P3 — Correct the "no APM runtime dependency" framing in plan constraints.**
   - **Current**: plan.md line 19 states "no GSD-2 or APM runtime dependencies" as a design constraint.
   - **Proposed**: Reframe as "no GSD-2 runtime dependency; APM is install-time only and imposes no runtime requirements."
   - **Rationale**: APM is a package manager, not a runtime. After `apm install`, all primitives are static files. Framing APM as a potential runtime dependency suggests a misunderstanding that could lead to under-utilization of APM's install-time capabilities.
   - **Risk if ignored**: Low — the constraint is technically satisfied by default, but the framing may discourage adoption of APM features that would reduce implementation complexity.

9. **P3 — Consider APM hooks as a supplementary verification mechanism.**
   - **Current**: Verification relies on spec-kit hooks at 4 lifecycle points (research.md lines 280-298) plus custom command composition.
   - **Proposed**: For agents that support APM hooks natively (Claude, Copilot), register `PostToolUse` hooks on `write_file` events to trigger lightweight verification checks (e.g., "does the written file match an expected artifact from must-haves?").
   - **Rationale**: APM hooks (key-concepts.md lines 352-382) fire on tool events (`PreToolUse`, `PostToolUse`, etc.) and can run arbitrary scripts. This provides verification at a different granularity than spec-kit hooks — per file write rather than per lifecycle phase.
   - **Risk if ignored**: Low — spec-kit hooks are sufficient, but APM hooks could catch issues earlier in the write cycle.

10. **P3 — Use APM context linking for cross-artifact references in summaries.**
    - **Current**: Task/phase/milestone summaries use `drill_down_paths` (data-model.md line 182) and `key_files` fields with raw file paths.
    - **Proposed**: Format summary artifacts as `.context.md` files with markdown links to related artifacts. APM's context linking (key-concepts.md lines 399-452) resolves relative paths automatically, enabling AI agents to traverse the knowledge graph natively.
    - **Rationale**: Context linking is a core APM capability that makes knowledge artifacts discoverable and traversable without custom path resolution. It works in both IDE and GitHub contexts.
    - **Risk if ignored**: Low — raw paths work, but agents must manually resolve references rather than following linked context.

---

## Referenced Documentation

- `<redacted-monorepo>/apm/docs/src/content/docs/introduction/key-concepts.md` — APM primitives (agents, instructions, skills, context, hooks), context linking, constitution injection
- `<redacted-monorepo>/apm/docs/src/content/docs/reference/manifest-schema.md` — `apm.yml` schema (name, version, type, target, scripts, dependencies, compilation), lockfile specification
- `<redacted-monorepo>/apm/docs/src/content/docs/guides/skills.md` — SKILL.md format, skill integration flow, package type detection, sub-skill promotion
- `<redacted-monorepo>/apm/docs/src/content/docs/guides/compilation.md` — Context optimization engine, compilation targets, constitution injection, directory exclusion, multi-agent output
- `<redacted-monorepo>/spec-kit-orc/specs/001-orchestrator/plan.md` — Implementation plan (project structure, architecture decisions, disputes)
- `<redacted-monorepo>/spec-kit-orc/specs/001-orchestrator/data-model.md` — Entity model, state machine, file format specifications
- `<redacted-monorepo>/spec-kit-orc/specs/001-orchestrator/quickstart.md` — Developer getting-started guide, installation paths
- `<redacted-monorepo>/spec-kit-orc/specs/001-orchestrator/research.md` — Research decisions R-001 through R-010
