# gh-aw Cross-Review of spec-kit's Review

**Cross-reviewer**: gh-aw
**Reviewing**: spec-kit's review of the speckit-orchestrator implementation plan
**Date**: 2026-03-19

---

## Dangerous Contradictions

These are points where spec-kit's recommendations and gh-aw's recommendations, if both followed naively, produce mutually exclusive designs or introduce breakage.

### DC-1: Config file location creates an unsolvable placement conflict

spec-kit recommends (P1, Rec #3) moving `orchestrator-config.yml` to `.specify/extensions/orchestrator/orchestrator-config.yml` to follow spec-kit's config convention. gh-aw's review does not contest the plan's root placement, but gh-aw's `repo-memory` persistence strategy (Rec #3) maps `.specify/orchestrator/` files to a `memory/orchestrator` branch for CI state survival. If the config file lives inside `.specify/extensions/orchestrator/`, it is outside the repo-memory persistence scope -- meaning CI runners would lose access to config between runs unless repo-memory's `file-glob` is expanded to also cover `.specify/extensions/`. But `.specify/extensions/` is managed by spec-kit's install process, not by the orchestrator's runtime -- committing into it from CI would conflict with spec-kit's `ExtensionManager.install_from_directory()` ownership. **Both recommendations are internally sound but cannot coexist without an explicit boundary agreement on which tool owns which paths under `.specify/`.**

### DC-2: Hook condition gating vs. CI re-entry model

spec-kit's Off-Base #4 warns that the `condition` field in hooks is not evaluated by LLMs -- hooks with conditions are skipped entirely, and the orchestrator must use prompt-based gating (`optional: true` with descriptive text) to conditionally execute hooks. gh-aw's Rec #7 designs the CI `auto` command as a scheduled re-entry loop that derives state in a deterministic precomputation step and gates the agent invocation with `if: needs.pre_activation.outputs.state_result != 'complete'`. These two gating mechanisms operate at different layers (spec-kit hook layer vs. gh-aw workflow layer) and will silently conflict: a hook might fire in CI even when the gh-aw precomputation step determined the phase is complete, because the hook's prompt-based gating runs inside the agent session after the workflow has already started. **The plan needs a single authoritative gating layer -- either the CI workflow gates before the agent session starts (gh-aw's model) or the agent gates internally via hook prompts (spec-kit's model), but not both independently, as they can disagree on state.**

### DC-3: Command composition via `handoffs` frontmatter vs. async dispatch workflows

spec-kit recommends (P2, Rec #5) using the `handoffs` frontmatter mechanism for command chaining -- the `auto` command would declare transitions to `plan-phase`, `dispatch`, `verify` as structured handoffs with `agent`, `prompt`, and `send` keys. gh-aw's Rec #1 and Off-Base #3 establish that in CI, synchronous command chaining is infeasible: a single workflow run cannot drive a full milestone due to timeout caps, so dispatch must use `dispatch-workflow` (async, independent runs). These are architecturally incompatible execution models. spec-kit's `handoffs` assume sequential, same-session transitions where one agent hands context to the next command. gh-aw's `dispatch-workflow` creates a new, context-free workflow run. **If `auto` declares `handoffs` per spec-kit's recommendation, the gh-aw adapter would need to translate each handoff into an async dispatch, discarding the `prompt` and `send` context that handoffs are designed to carry. The handoff mechanism becomes a lie in CI -- it promises context transfer but delivers context-free dispatch.**

---

## Tensions

Points where the two reviews pull the design in different directions without outright contradiction. Both positions have merit; resolution requires an explicit design decision.

### T-1: Scripts in frontmatter vs. deterministic precomputation steps

spec-kit's Rec #2 (P1) insists that orchestrator commands declare helper scripts in frontmatter (`scripts: { sh: ../../scripts/state/derive-phase.sh }`) so spec-kit's path rewriting and `{SCRIPT}` placeholder substitution work correctly. gh-aw's Rec #5 (P2) recommends running `derive-phase.sh` as an `on.steps:` deterministic precomputation step outside the agent session entirely, avoiding an AI engine invocation for pure computation. These pull in opposite directions: spec-kit wants the script invoked through its own resolution mechanism inside the command template; gh-aw wants it invoked before the command template even runs. Both are valid optimizations for their respective runtimes. The resolution likely requires the adapter to intercept script declarations and hoist deterministic ones into precomputation, but this requires a classification of which scripts are deterministic -- a concept neither review introduces.

### T-2: Checklist-based verification vs. CI verification with staged mode

spec-kit's Rec #7 (P2) wants phase must-haves expressed as spec-kit checklists so `/speckit.implement` can gate on checklist completion through its built-in mechanism. gh-aw's Rec #9 (P3) proposes a `verify --staged` mode that previews safe-output side effects (issues, PRs, status updates) without execution. These are complementary in theory but create a tension in practice: which verification is authoritative? If a checklist item passes but staged verification reveals the PR it would create conflicts with protected files, what wins? The verification ladder (R-006) needs to define which verification layer is the final gate, and the two reviews assign that authority to different systems.

### T-3: Template overridability vs. CI workflow compilation

spec-kit's Missed Opportunity #7 argues that the orchestrator's 15 templates should participate in spec-kit's template resolution stack (project-local overrides > presets > extensions > core), making them user-customizable. gh-aw's Missed Opportunity #3 notes that any frontmatter change in gh-aw workflows requires `gh aw compile` to regenerate `.lock.yml` files. If orchestrator templates are overridable and those overrides change frontmatter (permissions, tools, safe-outputs), every template override in a CI context triggers a recompilation requirement that the user may not know about. The tension is between spec-kit's desire for runtime flexibility and gh-aw's requirement for ahead-of-time compilation. The resolution needs a clear boundary: which parts of a template are safe to override without recompilation (markdown body) vs. which require it (frontmatter fields that map to workflow config).

### T-4: Extension install hygiene (.extensionignore) vs. CI artifact needs

spec-kit's Rec #6 (P2) recommends an `.extensionignore` excluding `tests/`, `fixtures/`, `specs/`, `docs/` from the installed extension to avoid bloat. gh-aw's perspective on CI state persistence (Rec #3) and deterministic precomputation (Rec #5) may need access to test fixtures or scripts that live in those excluded directories -- for example, verification scripts in `tests/` or reference data in `fixtures/` used by precomputation steps. The tension is minor but real: aggressive exclusion for local install cleanliness can starve CI workflows of artifacts they need. The `.extensionignore` should be designed with awareness of what the CI adapter actually references.

### T-5: `inject-context` declared not_supported vs. spec-kit's agent_scripts mechanism

gh-aw's Rec #6 (P2) declares `inject-context` should be marked `not_supported` in the gh-aw adapter because you cannot inject context into a running workflow mid-execution. spec-kit's Missed Opportunity #3 highlights `agent_scripts` (`agent_scripts: { sh: scripts/bash/update-agent-context.sh __AGENT__ }`) as a mechanism for updating agent context files (CLAUDE.md) when phase state changes. These are adjacent capabilities: `agent_scripts` modifies persistent files that the agent reads on next invocation, while `inject-context` attempts to modify a running session. If the orchestrator leans on `agent_scripts` for context propagation (spec-kit's suggestion), it partially works around gh-aw's `inject-context` limitation -- but only across runs, not within a single run. The design needs to be explicit about whether context updates take effect immediately (impossible in CI) or on next invocation (achievable via both mechanisms).

---

## Safe Agreements

Points where both reviews converge on the same conclusion or complementary conclusions with no conflict.

### SA-1: Config precedence model is correct as designed

Both reviews independently validate the plan's 4-level config precedence (env vars > local override > project config > extension defaults). spec-kit confirms it matches EXTENSION-API-REFERENCE.md lines 517-521. gh-aw confirms it mirrors gh-aw's most-specific-wins env var model (environment-variables.md lines 126-142). No changes needed to the precedence hierarchy itself.

### SA-2: Append-only JSONL execution log is the right format

spec-kit does not contest the `execution-log.jsonl` format. gh-aw explicitly validates it as matching the MemoryOps JSONL best practice for time-series data (memoryops.md). Both reviews implicitly agree this format serves both local state tracking and CI persistence (via repo-memory). The format is sound.

### SA-3: AD-2 (Disk State is Truth) is fundamentally correct and bridgeable to both systems

spec-kit's alignment section validates the `.specify/orchestrator/` state tree as correctly separated from `.specify/extensions/` (AD-7). gh-aw's alignment section validates that this state tree maps naturally to repo-memory branches for CI persistence. Both reviews agree the disk-state-is-truth principle is architecturally sound -- their disagreements are about where specific files live within the state tree, not whether the principle is correct.

### SA-4: The `requires.commands` manifest declaration is needed

spec-kit's Rec #1 (P1) calls for declaring `requires: commands: ["speckit.plan", "speckit.tasks", ...]` in the extension manifest. gh-aw's review does not address this but also does not conflict with it -- `requires.commands` is a spec-kit installation concern with no CI implications. Both perspectives would agree that install-time validation of core command dependencies is strictly beneficial.
