# Feature Specification: Conversus Deliberation Gate

**Feature Branch**: `017-conversus-deliberation-gate`
**Created**: 2026-04-15
**Status**: Draft
**Input**: User description: "Integrate Conversus multi-agent deliberation as an opt-in quality gate in the orchestrator's hook lifecycle. The intensity engine should auto-detect when the generation-evaluation gap is wide enough that multi-agent review adds value over single-agent audit. Uses the autoreason paper's four conditions (external verification, constrained scope, structured reasoning, sufficient decision space) as the trigger classifier. User-friendly adoption: disabled by default, recommended by the engine, zero config for first use."

## Problem Statement

The orchestrator's autonomous mode (`orchestrator:auto`) dispatches tasks to fresh agent contexts, verifies results mechanically, and advances. This works for tasks with clear right/wrong answers (file exists, pattern matches, script passes). But some decisions during autonomous execution are genuinely ambiguous:

- A task plan proposes approach A when approach B is equally valid — a single agent picks one without surfacing the tradeoff.
- Verification returns `DONE_WITH_CONCERNS` — is the concern correctness-blocking or observational? A single agent applies its own bias.
- Phase transition reveals the boundary map has drifted — do downstream phases need replanning? A single agent assesses from one perspective.

The autoreason paper (Nous Research, 2026) quantifies this problem as the **generation-evaluation gap**: models can generate good alternatives but cannot reliably choose between them. Self-refinement without external evaluation produces progressive degradation — the critique-and-revise loop actively harms output quality on weaker models (Haiku 3.5 baselines scored below unrefined single-pass in every experiment). The gap is widest at mid-tier models, which is precisely where cost-conscious orchestrator deployments operate.

The orchestrator's hook system (`PRE_DISPATCH`, `POST_DISPATCH`, `POST_VERIFY`, `PRE_ADVANCE`) already supports structured verdicts (`PASS`, `BLOCK`, `WARN`, `NEEDS_REVIEW`), and the `NEEDS_REVIEW` verdict was explicitly designed as the Conversus integration seam (M005 AD-3). The seam exists. What's missing is the hook script that invokes Conversus, the trigger classifier that determines when to invoke it, and the user-facing configuration that makes it opt-in and adoption-friendly.

## Background: Autoreason's Four Conditions

The autoreason paper identifies four conditions under which multi-agent external evaluation adds value. These become the trigger classifier for the Conversus gate:

1. **External verification needed**: The generating model cannot reliably evaluate its own output. Signal: mid-tier model in use (from `routing.yaml`), or task complexity exceeds model capability band.

2. **Constrained scope**: The improvement space is bounded, preventing drift. Signal: task has must-haves, verify scripts, a bounded file list, and explicit acceptance criteria. The orchestrator's task decomposition naturally provides this.

3. **Structured reasoning**: The task requires explicit failure analysis, not reactive find-and-fix. Signal: task plan has genuine design tradeoffs (multiple valid approaches documented), not template-filling.

4. **Sufficient decision space**: The task admits genuinely different valid approaches. Signal: phase has >1 unresolved architectural question, or the task plan's "Steps" section includes conditional branches. Conversely, tasks with one correct structure (data model migration, template fill-in) have no decision space.

When all four conditions are met, Conversus adds value. When any condition is absent, single-agent audit is sufficient.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Zero-Config First Use (Priority: P1)

A developer enables Conversus in their orchestrator config with a single flag. The next `orchestrator:auto` run automatically identifies which tasks would benefit from multi-agent review and invokes Conversus at the right hook points. The developer does not need to write a `conversus.yml`, choose agents, or understand the deliberation pipeline — the orchestrator generates the configuration dynamically from the task context.

**Why this priority**: Adoption-friendliness is the primary design goal. If the developer needs to author agent perspectives, pick modes, or configure iterations, adoption drops to near-zero. The orchestrator already has the context (spec, constitution, task plan, phase boundaries) to generate a high-quality Conversus config automatically.

**Independent Test**: Enable `conversus.enabled: true` in `.orchestrator/config.yml`. Run `orchestrator:auto` on a phase with mixed task types (some with genuine tradeoffs, some template-filling). Verify that Conversus fires only on the tradeoff tasks, not the template-filling ones.

**Acceptance Scenarios**:

1. **Given** `conversus.enabled: true` in config with no other Conversus settings, **When** `orchestrator:auto` dispatches a high-risk task with multiple valid approaches, **Then** the intensity engine recommends Conversus and the `PRE_DISPATCH` hook generates a `conversus.yml`, runs `conversus run`, and maps the result to a verdict.
2. **Given** `conversus.enabled: true`, **When** the task is template-filling with one correct structure, **Then** the intensity engine skips Conversus and the task dispatches without deliberation.
3. **Given** Conversus is not installed (`conversus` not on PATH), **When** `orchestrator:auto` starts, **Then** the pre-flight check reports "Conversus not available — deliberation gates will be skipped" and continues without error.
4. **Given** Conversus is enabled but the provider has no credentials, **When** `conversus validate` fails, **Then** the hook reports the validation failure as `VERDICT:WARN` (not `BLOCK`) and the task dispatches normally.

---

### User Story 2 - Post-Verification Recovery (Priority: P1)

A task fails mechanical verification on its first attempt. Before building the retry payload, the orchestrator invokes Conversus to evaluate: is the failure a genuine regression, an evaluation artifact, or an approach mismatch? The Conversus verdict determines whether to retry with the same approach (genuine bug), retry with a different approach (mismatch), or skip the retry and surface to the user (evaluation artifact that can't be mechanically resolved).

**Why this priority**: Autoreason's central finding is that the value of structured evaluation is in *recovery after failure*, not first-attempt improvement. The `POST_VERIFY` hook on failure is the highest-value insertion point.

**Independent Test**: Seed a task plan that will fail verification on first attempt (e.g., a must-have check for a pattern the subagent is likely to miss). After the first failure, verify that Conversus fires with the failure context, produces a structured assessment, and the retry payload incorporates the assessment.

**Acceptance Scenarios**:

1. **Given** a task fails verification with specific check failures, **When** Conversus is enabled and the intensity engine recommends it, **Then** the `POST_VERIFY` hook invokes Conversus with the task plan, verification report, and subagent output as review targets.
2. **Given** Conversus assesses the failure as "approach mismatch" (disagreements_surviving > 0 on the approach), **When** the retry payload is built, **Then** it includes the Conversus synthesis recommending an alternative approach, not just the raw verification failures.
3. **Given** Conversus assesses the failure as "genuine bug" (no disagreement on approach, only on implementation), **When** the retry payload is built, **Then** it includes the specific bug diagnosis from the Conversus critic, identical to standard retry behavior.

---

### User Story 3 - Intensity-Driven Recommendations (Priority: P1)

The orchestrator's intensity engine extends its recommendation output to include a Conversus recommendation alongside the Quick/Standard/Full intensity level. The recommendation is based on the four autoreason conditions, computed from the task's metadata (risk level, decision space, model tier, prior verification failures).

**Why this priority**: The intensity engine is the user-friendly adoption mechanism. Developers don't need to understand when Conversus adds value — the engine computes it from signals already available in the orchestrator's state.

**Independent Test**: Call `intensity-recommend.sh` with task descriptions of varying complexity. Verify that the `conversus:` field in the output is `skip` for simple tasks, `recommended` for tasks with genuine tradeoffs at mid-tier models, and `skip` for frontier models on the same task.

**Acceptance Scenarios**:

1. **Given** a task with risk=high, multiple valid approaches, and a mid-tier model in use, **When** `intensity-recommend.sh` evaluates it, **Then** the output includes `conversus=recommended`.
2. **Given** a task with risk=low and one correct implementation, **When** `intensity-recommend.sh` evaluates it, **Then** the output includes `conversus=skip`.
3. **Given** a task with risk=high but a frontier model in use, **When** `intensity-recommend.sh` evaluates it, **Then** the output includes `conversus=skip` (the generation-evaluation gap is narrow enough that single-agent audit suffices).
4. **Given** a task that has already failed verification once, **When** `intensity-recommend.sh` re-evaluates for the retry, **Then** `conversus=recommended` regardless of the original recommendation (recovery is where value peaks).

---

### User Story 4 - Constitution-Grounded Arbitration (Priority: P2)

When the Conversus deliberation produces surviving disputes, the orchestrator's constitution (`.orchestrator/memory/constitution.md`) serves as the grounding document for Phase 6 arbitration. The arbiter resolves disputes by citing specific constitution principles, ensuring all decisions align with the project's governing framework.

**Why this priority**: The constitution is the orchestrator's decision-making anchor. Conversus arbitration without grounding produces opinions; with constitution grounding, it produces principled rulings that compound into the knowledge base.

**Acceptance Scenarios**:

1. **Given** a Conversus deliberation produces 2 surviving disputes, **When** Phase 6 arbitration runs, **Then** the arbiter's resolution references specific constitution principles by number (e.g., "Principle VI: State On Disk Is Truth").
2. **Given** the arbitration output, **When** the hook processes the result, **Then** each resolved dispute is appended to `DECISIONS.md` via `append-decision.sh` with `source: conversus-arbitration`.

---

## Success Criteria

- **SC-1**: A developer enables Conversus with `conversus.enabled: true` and zero additional config. The next `orchestrator:auto` run invokes Conversus at the right hook points without manual `conversus.yml` authoring.
- **SC-2**: The intensity engine's recommendation includes `conversus=skip|recommended` based on the four autoreason conditions, computed from task metadata.
- **SC-3**: Conversus fires at `POST_VERIFY` on first verification failure when the intensity engine recommends it, and the retry payload incorporates the Conversus assessment.
- **SC-4**: Conversus is opt-in, gracefully absent (no error when not installed), and never blocks execution when provider credentials are missing.
- **SC-5**: The constitution serves as the grounding document for all Conversus arbitration.
- **SC-6**: Tasks with no decision space (template-filling, data migration) never trigger Conversus, regardless of risk level.

## Non-Goals

- Replacing the mechanical verification pipeline (must-haves, check scripts). Conversus supplements judgment; it does not replace mechanical checks.
- Running Conversus on every task. The trigger classifier ensures it fires only when the generation-evaluation gap is wide enough.
- Supporting Conversus modes beyond `cooperative`. The orchestrator integration uses cooperative mode with optional arbitration. Other modes (red-blue, prisoner's dilemma) are available via manual `conversus.yml` override but are not auto-configured.
- Building a custom multi-agent framework. The integration consumes Conversus CLI as-is (`conversus run` + `--format json`). No forks, no embedded engine.
- Making Conversus a runtime dependency. The orchestrator runs identically with or without Conversus installed. Deliberation gates are skipped when absent.

## Constraints

- Conversus is an external CLI dependency (`pip install conversus`). The orchestrator must gracefully degrade when it's not installed.
- Bash 3.2 compatible hook scripts. The hook invokes `conversus` via subprocess, not Python import.
- Cost awareness: 3 agents + 1 iteration + optional arbiter = ~16 LLM calls per gate. The intensity engine must factor this into budget calculations.
- The `--format json` output is the integration contract. If Conversus changes its JSON schema, the hook must handle gracefully.
- Constitution grounding requires the constitution file to exist at `.orchestrator/memory/constitution.md`. Projects without a constitution skip arbitration.
