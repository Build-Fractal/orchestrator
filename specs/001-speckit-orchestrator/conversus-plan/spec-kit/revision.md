# Spec-Kit Position Revision

**Author**: spec-kit (extension system, commands, hooks, templates, configuration)
**Date**: 2026-03-19
**Input**: APM cross-review of spec-kit, gh-aw cross-review of spec-kit, spec-kit cross-reviews of APM and gh-aw

---

## Disposition of Original Recommendations

### Rec 1 (P1): Declare `requires.commands` in extension.yml -- **Surviving**

No cross-reviewer challenged this. APM's cross-review lists it under Safe Agreements (SA-4). gh-aw's cross-review explicitly agrees (SA-4: "install-time validation of core command dependencies is strictly beneficial"). This is uncontested and should be implemented as originally stated.

### Rec 2 (P1): Use the `scripts` frontmatter field in command markdown -- **Modified**

gh-aw's cross-review (T-1) raises a legitimate tension: in CI, deterministic scripts like `derive-phase.sh` should run as precomputation steps *before* the agent session, not inside it. Declaring scripts in frontmatter and running them as precomputation steps are not mutually exclusive -- frontmatter declaration is about registration and path resolution; the execution context depends on the adapter.

**Revised position**: Orchestrator commands MUST still declare scripts in frontmatter for spec-kit's path rewriting to work in local execution. The gh-aw adapter MAY hoist deterministic scripts into precomputation steps, using the frontmatter declaration as its manifest of available scripts. The plan should classify each script as `deterministic` (pure computation, no agent interaction needed -- candidates for hoisting) or `interactive` (requires agent context -- must run inside the session). This classification does not exist today; it is new work the plan must add.

### Rec 3 (P1): Move `orchestrator-config.yml` to `.specify/extensions/orchestrator/` -- **Withdrawn**

APM's cross-review (Dangerous Contradiction #1) delivers the decisive counterargument: APM's `apm install` uses always-overwrite semantics for `.specify/extensions/orchestrator/`. The plan's AD-7 explicitly states this directory is "overwritten on install." My original recommendation was based on spec-kit's `ExtensionManager.install_from_directory()` preserving config files, but APM's install path does not offer this guarantee, and the quickstart advertises both install paths. Moving config into the APM deployment radius would destroy user configuration on `apm install --update`. gh-aw's cross-review (DC-1) adds a second concern: repo-memory file-globs would not capture config inside `.specify/extensions/`.

**Revised position**: Config stays at the project root as the plan currently specifies. I accept this as a documented deviation from spec-kit's config convention. The extension's `provides.config` manifest section should document the non-standard path and the rationale (APM overwrite safety). Spec-kit's `ExtensionManager.get_config()` should be pointed at the project-root path via the manifest.

### Rec 4 (P1): Add `$ARGUMENTS` handling to all command definitions -- **Surviving**

No cross-reviewer challenged this. The `$ARGUMENTS` mechanism is fundamental to how spec-kit commands receive user input and is used by every core command template. APM's cross-review focuses on different concerns (SKILL.md, instructions); gh-aw's cross-review focuses on CI execution. Neither negates the need for `$ARGUMENTS` handling in local execution. Commands that accept inline user input (evaluate, discuss, dispatch, auto) must include the `## User Input` section with `$ARGUMENTS`.

### Rec 5 (P2): Leverage `handoffs` frontmatter for command chaining -- **Modified**

gh-aw's cross-review (DC-3) makes a sharp point: handoffs assume sequential, same-session transitions with context transfer. In CI, dispatch uses `dispatch-workflow` (async, context-free). If `auto` declares handoffs, the gh-aw adapter would need to translate each handoff into an async dispatch, discarding the `prompt` and `send` context that handoffs carry. The handoff mechanism "becomes a lie in CI."

**Revised position**: `handoffs` should be declared in command frontmatter for local execution, where they genuinely improve the agent's ability to present structured next-step options. However, the plan must explicitly document that handoffs are a *presentation-layer* mechanism, not an *execution-layer* mechanism. The adapter interface (AD-3) must define how adapters translate handoffs: the local adapter uses them directly for sequential chaining; the CI adapter extracts the target command name and ignores the prompt/send context, constructing its own dispatch payload. Commands must not depend on handoff context being received -- the receiving command must be self-sufficient, reading state from disk (AD-2) rather than relying on the handoff's `send` payload.

### Rec 6 (P2): Create `.extensionignore` to exclude development artifacts -- **Modified**

gh-aw's cross-review (T-4) raises a real edge case: CI precomputation steps or verification scripts might reference files in `tests/` or `fixtures/`. Aggressive exclusion for local install cleanliness could starve CI workflows.

**Revised position**: The `.extensionignore` should still exist but should be designed with awareness of CI needs. Exclude `specs/`, `docs/` source, `.planning/`, and CI-only fixtures. Do NOT exclude `scripts/` (needed by both local and CI). `tests/` exclusion should be scoped to unit test files only (`tests/unit/`), not integration test fixtures that scripts depend on. The gh-aw adapter's precomputation steps should reference scripts from the source checkout, not the installed extension directory, so `.extensionignore` exclusions only affect the spec-kit install path.

### Rec 7 (P2): Connect phase must-haves to spec-kit's checklist system -- **Modified**

This recommendation drew the most cross-review fire. APM's cross-review (Dangerous Contradiction #4) flags that APM's `PostToolUse` hooks, spec-kit's checklists, and the orchestrator's own R-006 verification ladder create three overlapping verification systems. gh-aw's cross-review (T-2) adds staged mode and precomputation steps as fourth and fifth mechanisms. My own cross-review of gh-aw (DC-2) proposed a tier-to-mechanism mapping. APM's cross-review correctly identifies spec-kit checklists as "the strongest candidate" for primary verification.

**Revised position**: Spec-kit's checklist system should be the *primary* verification mechanism, but with a clearer scope than my original recommendation. The revised verification architecture:

- **Tier 1 (static checks)**: Deterministic scripts (precomputation steps in CI, `{SCRIPT}` invocations locally). Checks file existence, schema validity, state consistency. No agent involvement.
- **Tier 2 (command checks)**: Spec-kit checklists. Phase must-haves are expressed as checklist items. `/speckit.implement` gates on checklist completion. This is the authoritative gate for "is this phase ready to ship?"
- **Tier 3 (behavioral preview)**: gh-aw's staged mode (`verify --staged`). Previews side effects without execution. Informational, not blocking.
- **Tier 4 (human review)**: Manual review, unchanged from R-006.

APM's `PostToolUse` hooks are explicitly *not* part of the verification ladder. If adopted at all, they serve as early-warning signals during editing, not enforcement gates.

### Rec 8 (P2): Add `config_schema` to extension.yml for config validation -- **Surviving**

No cross-reviewer challenged this. JSON Schema validation of the 6 config fields is strictly beneficial and has no interaction with APM's or gh-aw's concerns. The schema validates config regardless of where the file lives (project root or otherwise).

### Rec 9 (P3): Consider `before_commit` and `after_commit` hooks -- **Modified**

APM's cross-review (Dangerous Contradiction #4) correctly identifies that choosing between spec-kit's `before_commit` hook and APM's `PostToolUse` hooks for commit-time verification requires an explicit decision. APM recommends spec-kit's `before_commit` as "the natural fit since the orchestrator is a spec-kit extension first (AD-1)." I agree with APM's resolution.

**Revised position**: `before_commit` should be adopted as the commit-time verification gate, bringing the hook count from 4 to 5. Its purpose is narrowly scoped: validate that the current phase's tier-1 static checks pass before allowing a commit of orchestrator state files. `after_commit` remains P3 -- useful for execution-log updates but not critical for initial implementation. The total hook integration is now 5 points: `before_tasks`, `after_tasks`, `before_implement`, `after_implement`, `before_commit`.

### Rec 10 (P3): Make templates overridable through spec-kit's template resolution stack -- **Modified**

APM's cross-review (Productive Tension #5) raises the question: which artifacts are templates (customizable) and which are context (linkable)? gh-aw's cross-review (T-3) adds that frontmatter changes in overridable templates trigger `gh aw compile` recompilation in CI, creating a hidden coupling.

**Revised position**: Split the orchestrator's 15 templates into two categories:
- **Overridable** (participate in spec-kit's template resolution stack): output format templates (phase-summary, milestone-summary, dispatch-brief). These affect presentation only and can be safely customized. Frontmatter changes in overrides should be limited to non-CI-affecting fields.
- **Internal** (not overridable): state machine templates (roadmap, phase-plan, task-plan), dispatch payload templates, verification templates. These affect correctness and their frontmatter maps to CI workflow configuration. Overriding them could break the gh-aw adapter's compiled workflows.

Document which templates are in each category and why.

---

## Disposition of Original Off-Base Assumptions

### Off-Base 1: Hook count (4 vs 6) -- **Modified to 5**

As discussed in Rec 9 above, adopting `before_commit` brings the count to 5. `after_commit` remains deferred. The original claim that there are "potentially 6 hook points" was factually correct but the recommendation should have been more selective about which additional hooks provide value.

### Off-Base 2: Config file placement -- **Withdrawn**

See Rec 3 above. APM's always-overwrite semantics are the deciding factor. Project root placement is the correct choice given the dual install path.

### Off-Base 3: Quickstart install command assumes catalog availability -- **Surviving**

APM's cross-review (Productive Tension #4) independently reaches the same conclusion: the quickstart advertises install paths that do not work today. Both reviews agree the quickstart should lead with `--dev` local install and mark catalog/APM install as future distribution options. No cross-reviewer defended the current quickstart's assumption.

### Off-Base 4: Hook `condition` expressions not evaluated by LLMs -- **Surviving**

gh-aw's cross-review (DC-2) adds a new dimension: CI re-entry gating (via workflow `if:` conditions) and spec-kit hook gating (via `optional: true` prompt text) operate at different layers and can disagree on state. This reinforces the original finding that `condition` fields cannot be relied upon. The resolution is:
- CI gating happens at the workflow layer (gh-aw's `if: needs.pre_activation.outputs.state_result != 'complete'`), *before* any spec-kit hook fires.
- Local gating happens at the hook layer (spec-kit's `optional: true` with descriptive text), inside the agent session.
- These are layered, not competing. The CI gate is a superset -- if the workflow does not start, hooks never fire.

---

## New Recommendations

These address gaps revealed by the cross-review process that my original review did not cover.

### New-1 (P1): Define a two-channel context injection strategy

APM's cross-review (Dangerous Contradiction #3) identifies that APM `.instructions.md` and spec-kit frontmatter/templates are two non-overlapping context injection channels operating at different lifecycle points. My original review ignored `.instructions.md` entirely, which was a gap.

**Recommendation**: The plan must explicitly document a two-channel strategy:
- **Ambient context** (APM `.instructions.md`): Static, always-applicable rules that agents load at session start. Example: "Files in `.specify/orchestrator/` use YAML frontmatter. Do not modify `execution-log.jsonl` manually."
- **Command context** (spec-kit frontmatter/templates): Dynamic, command-specific guidance injected when a slash command executes. Example: "This dispatch targets phase P02, which has these must-haves..."

Neither channel is "primary." They serve different moments. The orchestrator should author both, and the plan should document which guidance belongs in which channel.

### New-2 (P1): Resolve the SKILL.md derivation gap

APM's cross-review (Dangerous Contradiction #2) reveals that the "unanimous convergence" on AD-6 (command frontmatter as single source for skill metadata) rests on a capability APM does not have: frontmatter-to-SKILL.md derivation at install time. My original review accepted AD-6 implicitly without verifying APM's capabilities.

**Recommendation**: For the initial release, author a single root-level `SKILL.md` as a summary document listing all 10 commands with one-line descriptions. This is the pragmatic short-term solution that APM can distribute today. Mark it as "generated from command frontmatter" with a comment indicating it should be replaced by automated derivation when APM adds that capability. This avoids the "parallel hierarchy" problem (one summary file, not 10 individual SKILL files) while providing APM skill discoverability.

### New-3 (P2): Classify scripts as deterministic vs interactive

This emerged from gh-aw's cross-review (T-1) of my Rec 2 and was not in my original review at all.

**Recommendation**: Each script in `scripts/` should be classified in the plan:
- **Deterministic**: Pure computation, no agent interaction, idempotent. Candidates for CI precomputation hoisting. Examples: `derive-phase.sh`, `scope-filter.sh`, `validate-state.sh`.
- **Interactive**: Requires agent context, may prompt for input, depends on session state. Must run inside the agent session. Examples: `build-context.sh` (assembles context from agent's current working set), `dispatch-payload.sh` (may incorporate agent observations).

This classification should be documented in the plan and reflected in command frontmatter (deterministic scripts get a `deterministic: true` annotation or are listed separately from interactive scripts).

### New-4 (P2): Add `runtime` field to lock file schema

This emerged from my cross-review of gh-aw (T-3). The plan's lock file schema uses PID-based liveness, which is meaningless on ephemeral CI runners.

**Recommendation**: Add a `runtime` field to `orchestrator.lock` (`"local"` or `"ci"`) and a `run_id` field for CI contexts. The liveness check inspects `runtime` to determine whether to check PID existence or query the GitHub Actions run status. This is a data model change (data-model.md) that must be specified before implementation.

### New-5 (P2): Define state persistence direction for CI adapter

This emerged from my cross-review of gh-aw (DC-1). The working tree vs repo-memory source-of-truth question is unresolved.

**Recommendation**: The working tree is always canonical. The gh-aw adapter syncs state FROM the working tree TO repo-memory after each run, and hydrates the working tree FROM repo-memory at the start of each run. The direction is: repo-memory -> working tree (start) -> working tree is canonical during execution -> working tree -> repo-memory (end). This preserves spec-kit's filesystem assumptions while giving CI durability.

---

## Position Summary

Of my original 10 recommendations: 4 survive unchanged (Recs 1, 4, 8; Off-Base 3), 5 are modified based on legitimate cross-review feedback (Recs 2, 5, 6, 7, 9, 10), and 1 is withdrawn (Rec 3 / Off-Base 2, config file placement). I add 5 new recommendations addressing gaps my original review missed.

**The three most significant shifts in my position are:**

1. **Config file placement (Withdrawn)**: APM's always-overwrite deployment semantics are the deciding factor. I was wrong to prioritize convention conformance over install-path safety. The project-root placement is correct, and spec-kit should document this as an accepted deviation.

2. **Verification architecture (Modified)**: My original recommendation to connect must-haves to checklists was too narrow. The cross-reviews revealed 5 potential verification mechanisms. The revised position assigns each verification tier to exactly one mechanism, with spec-kit checklists as the authoritative gate (tier 2) and everything else explicitly scoped to avoid overlap.

3. **Two-channel context injection (New)**: My original review was blind to the APM instructions channel because I was focused exclusively on spec-kit's own mechanisms. APM's cross-review correctly identified that agents have two context injection moments (session start and command invocation) and the orchestrator needs to serve both. This is the most important new insight from the cross-review process.

**What did not change**: The extension-first principle (AD-1), deployment boundary separation (AD-7), command naming conventions, `$ARGUMENTS` handling, `requires.commands` declaration, and `config_schema` validation are all uncontested across all three reviews. These are safe to implement as specified.
