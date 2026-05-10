---
schema_version: "1.0"
type: proposal
status: rfc-capture
created_at: 2026-05-08
shape: "Post-launch demand-driven slot — sibling/overlap with M034 (interactive review gates) and M038 (living documents). Absorption decision deferred to queue-entry time."
---

# Proposal: `/orchestrator-discuss-phase` — phase-level discussion command

**Captured**: 2026-05-08 from upstream LakeLedger RFC (M075 roadmap planner referenced a non-existent `/orchestrator-discuss-phase` command — the right design instinct, but the command does not exist).
**Shape**: Single command + state-machine wiring + templates. ~1 phase of work when the arc enters the queue. Could be a sub-phase inside M034 or M038, or a standalone mini-milestone.
**Predecessors**: M013/[M014](../milestones/M014/index.md) (review-queue convention — CON-5/SC-5 human-gated apply pattern), [M020](../milestones/M020/index.md) (knowledge-graph layer — feeds the gate-finding parser if v2 ships), [M026](../milestones/M026/index.md) (conversus adapter — produces the advisory `gate-result.md` artifact this command folds), [M030](../milestones/M030/index.md) (adaptive model selection — routes the discussion agent), **M034 (interactive review gates — strong primitive overlap, see § "Relationship to M034 / M038")**, M038 (living documents — overlap on per-section structured outputs).
**Source**: 2026-05-08 LakeLedger upstream feedback — second project-on-project occurrence of "advisory conversus-gate findings folded by hand between roadmap and plan-phase." First occurrence was LakeLedger M074 (also folded hand-rolled). The pattern is stable enough to harden into framework.

## Status

**RFC capture only.** Implementation deferred post-launch, demand-driven within the post-launch fast-follow queue. [M035](../milestones/M035/index.md) is the launch event; this command does NOT block launch and does NOT enter the active milestone queue. When a second downstream consumer (or LakeLedger M076+) hits the same friction, this proposal becomes the input to either an `orchestrator:specify` pass, a phase inside M034, or a phase inside M038 — see § "Relationship to M034 / M038" for the absorption decision.

## TL;DR

The orchestrator has milestone-level discussion (`/orchestrator-discuss` → produces `M###-CONTEXT.md`, gates `pre-planning` → `discussing` → `planning`). It has no phase-level analogue. GSD ships `/gsd:discuss-phase`; orchestrator does not. Conversus advisory gates (`spec-pressure-test` and friends) run per-spec and produce **advisory** findings even at Standard intensity — verdict can be `BLOCK` while the gate exits 0, surfacing 5 P0 mitigations + 2 P1 mitigations as a typical shape. These need a structured fold step between `/orchestrator-roadmap` close and `/orchestrator-plan-phase` kickoff with three properties milestone-level discuss can't provide: per-phase scope, state-machine signal (so plan-phase doesn't kick off until the fold landed), and structured outputs (spec amendments, pre-dispatch sequencing constraints, conditional scope extensions, deferred-Open-Question resolutions).

## Problem (root-cause, two-data-point shape)

Three failure modes recur in dogfood when advisory findings arrive between roadmap and plan-phase:

1. **Spec drift.** Findings get folded into the executor's head, never into spec.md. Three phases later the spec and the running system disagree on which mitigations are in scope. LakeLedger M074 surfaced this twice in one milestone.
2. **State-machine blindness.** `derive-phase.sh` cannot distinguish "advisory findings pending fold" from "ready to plan." Plan-phase kicks off against a spec that has unfolded BLOCK-verdict mitigations, and the planner has no signal that a discussion stage was skipped. The resulting plan looks plausible but ignores load-bearing constraints.
3. **Cross-project pattern reinvention.** LakeLedger ran the fold by hand twice (M074, M075). The shape is stable: read `gate-result.md`, surface BLOCK-verdict findings, choose `apply / defer / reject` per finding, propagate to spec or to phase plan frontmatter. Each project hand-rolls this because the framework has no primitive for it.

The third failure mode is the demand signal. **Two project-on-project occurrences** (LakeLedger M074 + M075) mean the pattern is stable enough to harden, but **one downstream consumer** is still n=1 — the same threshold M034 uses. This proposal sits at the same demand-driven slot.

## Why a phase-level analogue is structurally needed (not a milestone-discuss extension)

Milestone-level discuss happens once, before roadmap. By the time individual phases are being planned, the milestone-level context draft is finalized and frozen. Re-opening it to fold per-phase advisory findings dilutes its contract — the milestone context is supposed to be the architectural framing for the *whole* milestone, not a rolling diary of per-phase mitigations.

Three structural properties the per-phase fold needs that milestone-discuss cannot provide:

- **Scope is per-phase, not per-milestone.** A spec-pressure-test finding for P03 is irrelevant to P01's plan; folding it into `M###-CONTEXT.md` pollutes the wrong scope.
- **It's a state transition, not just an edit.** `/orchestrator-plan-phase` shouldn't kick off until the gate fold has landed. That requires `derive-phase.sh` to recognize a `discussing-phase` substate, which milestone-discuss doesn't model.
- **The fold has structured outputs.** Spec amendments, pre-dispatch sequencing constraints, conditional scope extensions, decisions on deferred Open Questions — these are typed fields, not free-form prose. The milestone-context-draft template is prose-oriented (Architectural Decisions / Scope Boundaries / Design Constraints / Open Questions); it doesn't carry the typed-output shape this fold needs.

## Proposed design

### Command shape

```
/orchestrator-discuss-phase [--phase P##] [--gate-result <path>] [--non-interactive]
```

- **No args** → auto-select the next phase in `discussing-phase` substate (or first phase needing discussion if none currently in substate).
- `--phase P##` → operate on a specific phase regardless of state machine pointer.
- `--gate-result <path>` → fold findings from a specific gate-result file; defaults to `specs/<feature>/conversus/gate-result.md` if it exists.
- `--non-interactive` → write a stub `P##-CONTEXT.md` with `status: draft` and exit; intended for CI / `auto`-mode flows that route through the M034 `defer` policy.

### Prerequisites

1. **State must be `planning`.** If anything else, refuse and suggest the appropriate command (mirror `commands/discuss.md` § Prerequisites mapping).
2. **Roadmap must be finalized.** `M###-ROADMAP.md` exists and the named phase appears in it.
3. **Milestone context must be finalized.** `M###-CONTEXT.md` has `status: finalized`. The phase-level discussion *extends* the milestone-level one, never replaces it.

### Lifecycle (mirror milestone-discuss, per-phase)

1. **Create draft.** No `phases/P##/P##-CONTEXT.md` exists → copy `templates/phase-context-draft.md`, populate frontmatter (`milestone`, `phase`, `status: draft`, `created_at`, `gate_findings_source` if applicable), seed body sections from gate-result findings (if any) or general prompts. Writing the draft transitions the substate to `discussing-phase`.
2. **Update draft.** Draft exists with `status: draft` → append operator input to appropriate sections; do NOT change status.
3. **Finalize.** Operator indicates complete → flip frontmatter `status: finalized`, set `finalized_at`. Substate returns to `planning` with the phase-context now consumable by `/orchestrator-plan-phase`.

Idempotency follows `commands/discuss.md` exactly: re-running on a finalized draft is safe, re-creating on an existing draft offers update/finalize choices, malformed-frontmatter triggers repair-or-warn.

### File output schema (`templates/phase-context-draft.md`)

```yaml
---
schema_version: "1.0"
type: phase-context
milestone: "{{milestone_id}}"
phase: "{{phase_id}}"
status: draft
created_at: "{{created_at}}"
finalized_at: null
gate_findings_source: "{{path}} | null"
---
```

Body sections (typed-output discipline — mirror M034's decision-packet shape, not milestone-context's prose shape):

- `## Spec Amendments` — array of `{finding_id, source, action: apply|defer|reject, target_section, summary}` entries. Each one corresponds to a downstream edit that landed in `spec.md` (Path A) or a delta entry that the planner reconciles at plan-phase time (Path B). Default: Path A if `spec.md` is writable; Path B if frozen.
- `## Pre-Dispatch Constraints` — array of `{constraint_id, applies_to_task: "T## | all", description, source_finding}` entries. Surfaces sequencing or guardrail constraints the phase plan must honor.
- `## Conditional Scope Extensions` — array of `{extension_id, trigger, scope_delta, default_active: bool}` entries. Captures "if X, also do Y" conditions surfaced by gate findings.
- `## Deferred Question Resolutions` — array of `{question_id, source: spec.md | gate-result.md, resolution, resolved_by, resolved_at}` entries. Closes Open Questions that were deferred at milestone-discuss time and have ripened by phase-planning time.
- `## Free-Form Notes` — prose section for anything that doesn't fit the typed shapes. Operator escape hatch.

The typed-array shape lets `/orchestrator-plan-phase` consume the file mechanically (jq / yaml-parse) rather than re-parsing prose.

### State-machine integration

Two surgical edits:

1. **`scripts/state/derive-phase.sh` learns rule 3.5 (`discussing-phase`).** Inserted between rules 3 (`planning`) and 4 (`replanning`):

   > Rule 3.5: If the active phase has `phases/P##/P##-CONTEXT.md` with `status: draft`, return `discussing-phase`. The active phase is the first phase in `M###-ROADMAP.md` without a `P##-PLAN.md`.

   The substate is *additive* — projects that never invoke `/orchestrator-discuss-phase` see no change in behavior because no `P##-CONTEXT.md` ever exists. This preserves the existing 10-state shape for projects that don't opt in.

2. **`commands/plan-phase.md` learns a prerequisite check.** Plan-time discipline rule (alongside the existing rule 1 prerequisite-existence verification): if `phases/P##/P##-CONTEXT.md` exists with `status: draft`, FAIL plan authoring with "Phase context draft is unfinalized — finalize via `/orchestrator-discuss-phase` or delete the draft to skip." If the file exists with `status: finalized`, parse its typed-array sections and inject them into the planner's context payload alongside spec.md.

### Intensity behavior

Mirror `commands/discuss.md`'s intensity gate:

| Intensity | Default behavior | Override |
|---|---|---|
| **Quick** | Skip entirely. Do not create a phase-context draft. Plan-phase proceeds directly. | `--phase P## --force` to opt in. |
| **Standard** | Optional. If `gate-result.md` exists with `verdict: BLOCK` and unfolded findings, prompt: "Phase P## has N unfolded BLOCK-verdict findings from spec-pressure-test. Discuss before planning?" Otherwise skip. | Either choice respected. |
| **Full** | Required when any of: (a) `gate-result.md` has `verdict: BLOCK`, (b) milestone context lists `discuss_phases: true` in frontmatter, (c) prior phase's `P##-SUMMARY.md` declares `next_phase_discuss_recommended: true`. | None — Full is the gate. |

Default-skip at Quick preserves Quick's right-sized-entry contract ([M031](../milestones/M031/index.md)). Full-as-gate matches the milestone-discuss precedent.

### Question-generation heuristic (gate-finding-aware)

When `specs/<feature>/conversus/gate-result.md` exists with `verdict: BLOCK`, parse its `### Gate Findings` section. Surface each finding as a structured prompt with `apply | defer | reject` choices. For `apply`, prompt for target section in spec.md (Path A) or freeform delta description (Path B). Capture answers in the appropriate typed-array section of `P##-CONTEXT.md`.

When no gate-result exists, fall back to general per-phase prompts:
- "What spec sections does this phase materially depend on?"
- "What pre-dispatch sequencing constraints (if any) apply across tasks?"
- "Are there conditional scope extensions the phase should be ready for?"
- "Which Open Questions from milestone-discuss have ripened and need resolution?"

### Spec-amendment application paths

Two paths, declared per-finding (LakeLedger RFC framing, preserved):

- **Path A — inline edits to `spec.md`** (LakeLedger preference; spec stays authoritative). Apply operator-approved findings as direct edits; record the edit summary in the `Spec Amendments` array. Pro: spec is single source of truth. Con: spec evolves mid-milestone, which some workflows treat as "frozen at evaluation."
- **Path B — delta-only** (spec frozen at evaluation; reconciliation at plan-phase time). Record the delta in the `Spec Amendments` array; planner reads spec + deltas at plan-phase. Pro: spec freeze preserved. Con: reconciliation logic compounds across phases — phase 5's planner reads spec + 4 delta files.

Default: Path A if `spec.md` mtime is later than `M###-EVALUATION.md` mtime (signals a writeable-spec workflow). Path B otherwise. Operator can override per-finding.

## Relationship to M034 / M038 — paired demand-driven slot

This proposal **cannot ship in isolation** of M034 / M038 without producing a third overlapping primitive. The decision-packet schema (M034 P01) and the living-doc section binding (M038 §4) are ~80% the same shape as the typed-array `Spec Amendments` / `Pre-Dispatch Constraints` / `Conditional Scope Extensions` / `Deferred Question Resolutions` arrays this command emits. The overlap is load-bearing:

| Dimension | M034 decision-packet | M038 living-doc section | This command's `P##-CONTEXT.md` |
|---|---|---|---|
| Granularity | Per artifact-decision | Per document section | Per phase-level fold action |
| Cadence | One-shot (per phase task) | Continuously evolving | One-shot (per phase entry) |
| Trigger | Plan declares `decision_packet: true` | Detection heuristic + opt-in | Gate `verdict: BLOCK` or operator invocation |
| Sign-off surface | `SIGNOFF.md` populated from `REVIEW.md` | `sentinel: "Pass N (slug)"` + `status: shipped:<date>` | `status: finalized` flipped by operator |
| Persistence | Per-phase artifact | Append-only decision-history per section | Per-phase artifact |
| Code-anchor binding | Optional | Load-bearing | None (pre-execution stage) |

**Three resolution paths — decide at queue-entry time, not now:**

1. **(a) M034 absorbs this command.** Treat the phase-level discussion as a *pre-authoring* invocation of the same decision-packet primitive — same schema, different lifecycle position (pre-plan vs post-artifact). Argues for shipping M034 P01 first with the schema sized to cover both lifecycles, then adding `/orchestrator-discuss-phase` as a thin invocation harness.
2. **(b) M038 absorbs this command.** Treat the phase-context draft as a short-lived *living document* whose sections are the typed arrays and whose binding shape is "this phase plan depends on these findings being folded." Argues for the section-binding primitive being the right shape, with the phase-discussion case as a config preset (single-section, one-shot cadence, sentinel = `status: finalized`).
3. **(c) Sibling shipping with shared schema.** Both M034 and M038 ship the underlying packet/section primitive; this command becomes a third consumer alongside them. Lowest absorption risk; highest surface-area cost.

**Recommendation when the arc enters the queue**: **option (a) is the cleanest fit.** M034 is smaller-scope than M038, ships sooner, and the decision-packet primitive is the same shape this command needs. Sequence: M034 P01 (schema) ships → `/orchestrator-discuss-phase` lands as a phase inside M034 P02 or as an immediate fast-follow → M038 reuses both.

**For now (RFC-capture phase)**: treat M034, M038, and this command as a **paired demand-driven slot**. When LakeLedger M076+ or a second downstream consumer signals "we need this," begin the work by revisiting (a)/(b)/(c).

## MVP scope (when arc enters queue)

The smallest viable shape that retires the LakeLedger M074/M075 hand-rolled fold:

1. **The command itself** — `commands/discuss-phase.md`, copied from `commands/discuss.md` and rescoped to per-phase. Inherits the intensity gate, idempotency rules, error handling, and finalization shape; differs in scope (`P##-CONTEXT.md` not `M###-CONTEXT.md`), prerequisites (state must be `planning`, milestone context must be finalized), and section schema (typed arrays, not prose).
2. **State-machine wiring** — `scripts/state/derive-phase.sh` rule 3.5 + `commands/plan-phase.md` prerequisite check. Surgical, additive, opt-in (no draft → no behavior change).
3. **Templates** — `templates/phase-context-draft.md` (sibling to existing `templates/context-draft.md`), with the typed-array sections specified above.
4. **Skill registration** — `packaging/install/install-claude-code.sh` (and Codex CLI / Cursor when M009 broadens) registers the skill at the same precedence as `/orchestrator-discuss`.

That's ~3–4 days of work for one engineer. It would already retire the per-project hand-rolled fold ceremony in LakeLedger.

### v2 / deferred

- **Gate-findings auto-detection from `gate-result.md`.** v1 ships with manual `--gate-result <path>` and prose fallback; v2 auto-detects when a phase's spec has a corresponding gate-result file. Requires conversus-output schema stability (M026 owns).
- **Inline spec-edit automation (Path A).** v1 records the amendment in the typed array; operator hand-applies to `spec.md`. v2 applies the edit programmatically with rollback. Requires the same review-queue convention as `commands/comments.md` (CON-5/SC-5 — never auto-applied without operator gate; the auto-apply *is* the gate output).
- **Intensity-aware prompting nuance.** v1 treats Standard as flat-prompt; v2 surfaces only the highest-severity findings at Standard, full set at Full, per-finding cost projection at Standard with operator opt-in to surface the rest.
- **`auto`-mode policy parity.** Mirror M034's `defer | accept-with-audit | block` triad. v1: `defer` only (auto-mode pauses, emits `pending-phase-discuss` JSONL, exits cleanly via continue-file). v2: full triad declared in plan frontmatter.
- **Wiki review surface.** Render `P##-CONTEXT.md` as a wiki page under [M032](../milestones/M032/index.md)'s `--with-wiki` rendering when post-launch-wiki-ux ships. Comment thread per phase-discussion (giscus). Out of scope for v1.

## Risk-rank against current launch sequence

**Does NOT block M035** (the launch event). Queues post-launch, paired with M034 / M038. Three reasons:

1. **Blast radius is contained.** New command, new template, surgical state-machine rule. No publishing surface, no install-script change, no cross-runtime impact (CC-only at launch posture, parity audit deferred to M009).
2. **Demand signal is real but n=2 same-project.** LakeLedger M074 + M075 is two occurrences in one project. The M034 demand-signal threshold ("a second downstream consumer") is the right bar; this proposal sits behind it.
3. **Composes with already-shipping primitives.** Reuses `commands/discuss.md` shape, `templates/context-draft.md` schema-versioning convention, `scripts/state/derive-phase.sh` rule-priority structure, M026 conversus gate-result format. No co-development required.

Pre-launch insertion would dilute M035 without sharpening the first-impression. Post-launch insertion ships when the absorption decision (M034 / M038 / sibling) becomes informative.

## Reference implementations to mirror

Concrete file paths in this repo for the queue-entry pass to anchor against:

- **`commands/discuss.md`** — milestone-level analogue. Copy structure: Intensity Behavior → Prerequisites → Question Generation → Core Workflow (Create / Update / Finalize) → Idempotency → Error Handling → Gotchas → Referenced Scripts/Templates/Files. Rescope per-phase.
- **`templates/context-draft.md`** — milestone-context-draft template. Sibling shape, prose-oriented sections; the new `templates/phase-context-draft.md` keeps the frontmatter pattern but flips body to typed arrays.
- **`scripts/state/derive-phase.sh`** — state-machine engine, ~10 priority-ordered rules; insert rule 3.5 (`discussing-phase`) between rules 3 and 4. Header comment block at the top documents the rule list — must be kept in sync.
- **`commands/plan-phase.md` § Plan-Time Discipline** — rule-list format for plan-authoring prerequisites; add the `P##-CONTEXT.md` finalized check as a new numbered rule.
- **`commands/comments.md`** — CON-5/SC-5 review-queue convention. The Path-A spec-edit automation (v2) MUST follow this pattern: artifact written → operator gate → apply or reject → JSONL audit. Reuse the convention, not the code.
- **`templates/compression-tier3-prompt.md`** — versioned-frontmatter pattern ([M018](../milestones/M018/index.md)) for the `templates/phase-context-draft.md` `schema_version` field.
- **GSD `commands/gsd/discuss-phase.md`** (external) — sibling implementation in GSD. Useful as a UX-shape comparator at queue-entry time; do not literal-port (different state-machine, different intensity model, different review conventions). Verify the file path / latest revision when the arc enters the queue.

## Test cases a correct implementation must pass

The acceptance battery shape (mirror `tests/m029-acceptance/` / `tests/m032-acceptance/` structure):

1. **Create draft from clean state.** Milestone in `planning`, no `P##-CONTEXT.md`. Run `/orchestrator-discuss-phase --phase P##`. Assert: file created with `status: draft`, `derive-phase.sh` returns `discussing-phase`, frontmatter fields all populated.
2. **Plan-phase blocked while draft unfinalized.** With draft from #1, run `/orchestrator-plan-phase P##`. Assert: command refuses with the prerequisite-fail message; no `P##-PLAN.md` written.
3. **Finalize transitions back to `planning`.** With draft from #1, finalize. Assert: `status: finalized`, `derive-phase.sh` returns `planning`, plan-phase prerequisite passes.
4. **Plan-phase consumes typed arrays.** With finalized draft containing `Spec Amendments` and `Pre-Dispatch Constraints` entries, run plan-phase. Assert: planner payload includes the typed entries (verifiable via planner-context dump in test mode).
5. **Idempotency: re-create on existing draft.** With draft present, re-invoke. Assert: file unchanged, command offers update/finalize choices, exits cleanly.
6. **Idempotency: finalize already-finalized.** With finalized draft, re-invoke finalize. Assert: file unchanged, command reports already-finalized, exits cleanly.
7. **Quick intensity skip.** With Quick metadata, invoke. Assert: no draft created, plan-phase proceeds without the prerequisite check firing.
8. **Standard intensity gate-finding prompt.** With Standard metadata and `gate-result.md` containing `verdict: BLOCK` + 3 findings, invoke. Assert: prompt surfaces 3 findings, captures `apply/defer/reject` per finding, writes typed-array entries.
9. **Full intensity with no gate-result.** With Full metadata and no `gate-result.md`, invoke. Assert: falls back to general prompts, draft created with prose-only `Free-Form Notes` content allowed.
10. **State-machine non-regression.** Project that never invokes `/orchestrator-discuss-phase`. Run the existing M032 / [M033](../milestones/M033/index.md) / [M037](../milestones/M037/index.md) acceptance batteries. Assert: `BATTERY: pass=N fail=0` unchanged — the rule 3.5 insertion is byte-additive on projects without phase-context drafts.
11. **Malformed-frontmatter repair.** Corrupt the `status:` line in an existing draft. Invoke. Assert: command attempts repair, reports outcome, leaves draft in valid state or fails cleanly.
12. **Multi-phase isolation.** Project with P01, P02, P03. Discussion finalized for P02 only. Assert: P01 and P03 unaffected, only P02's plan-phase prerequisite check consults the draft.

## Constraints / antipattern compliance

- **AD-19 single-script-file shape** — no new scripts in this MVP; the command lands as `commands/discuss-phase.md` (instruction-only) plus the `derive-phase.sh` rule insertion. If a helper is needed for typed-array parsing, follow `scripts/state/read-roadmap.sh` shape (single bash file, POSIX-leaning, jq optional).
- **Bash 3.2 + POSIX sh** — no associative arrays, no `${var,,}`, no process substitution in hot paths. Compliance verified per `references/file-formats.md`.
- **AP-009 (compound-chain-gt2)** — any helper invokes ≤2 commands per chain.
- **CON-5 / SC-5 (never auto-applied)** — inherited verbatim from `commands/comments.md` for the v2 inline-spec-edit automation. Decision artifact always written; operator-touch gated.
- **Principle I (Context Minimization)** — typed-array sections stay tight; freeform prose lives in the operator-escape `Free-Form Notes` section, not in load-bearing payload paths.
- **Principle II (Evidence Before Claims)** — gate-finding prompts surface concrete findings (file, severity, rationale) at fold-time; operator decisions captured with timestamps + source-finding IDs for retroactive audit.
- **Principle III (Design Before Code)** — the entire premise. Plan-phase doesn't kick off until the fold is finalized.
- **Principle IV (Plans Assume Zero Context)** — finalized `P##-CONTEXT.md` carries enough typed-array structure that `/orchestrator-plan-phase` can author a plan without re-reading `gate-result.md`. Same standard as plan task-units.
- **Principle XVI (Distribution Surface Integrity)** — `templates/phase-context-draft.md` ships through the `packaging/bundle/` pipeline alongside `templates/context-draft.md`. No new install-script logic.

## Open questions (for queue-entry pass)

1. **Path A vs Path B default.** Operator preference is Path A (LakeLedger). Recommendation: Path A when `spec.md` is writable, Path B when frozen at evaluation. Detect by mtime comparison.
2. **`auto`-mode policy parity with M034.** Adopt M034's `defer | accept-with-audit | block` triad? Recommendation: yes, as v2 — v1 ships `defer` only.
3. **Wiki rendering.** When post-launch-wiki-ux ships, render `P##-CONTEXT.md` as a per-phase wiki page? Recommendation: yes, low blast radius; reuses M037 readability primitives.
4. **Schema overlap with M034 decision-packet.** If M034 P01 ships first, this command's typed arrays MUST share the underlying schema (avoid drift). Recommendation: lift M034 P01's schema to `references/decision-packet-schema.md` and have both commands cite it.
5. **GSD `discuss-phase` UX divergence.** GSD's flavor offers `--auto` to skip questions and pick recommended defaults; should this command? Recommendation: yes, mapped to the `--non-interactive` flag in v1.
6. **Per-phase substate naming.** `discussing-phase` vs `phase-discussing` vs `phase-pre-planning`. Recommendation: `discussing-phase` (mirrors `discussing` for milestone, suffix disambiguates scope).

## Cross-references

- **[`.orchestrator/proposals/M034-interactive-review-gates.md`](../proposals/M034-interactive-review-gates.md)** — primary absorption candidate. Decision-packet schema (M034 P01) is ~80% the same primitive.
- **[`.orchestrator/proposals/M038-living-documents.md`](../proposals/M038-living-documents.md)** — secondary absorption candidate. Section-binding primitive could host phase-context as a single-section special case.
- **[`.orchestrator/proposals/launch-sequencing-amendment-2026-05-03.md`](../proposals/launch-sequencing-amendment-2026-05-03.md)** — risk-rank framing this proposal mirrors. M035 is the launch event; this sits post-launch.
- **[`.orchestrator/proposals/post-launch-wiki-ux-and-adapters.md`](../proposals/post-launch-wiki-ux-and-adapters.md)** — landing zone for the wiki-rendering deferred from MVP.
- **`commands/discuss.md`** — milestone-level analogue, structural template for the new command.
- **`commands/plan-phase.md`** — prerequisite-check insertion point.
- **`scripts/state/derive-phase.sh`** — state-machine rule insertion point.
- **`templates/context-draft.md`** — sibling template, schema-versioning pattern.

## Source material

- 2026-05-08 LakeLedger upstream RFC — full body preserved in the prompt that authored this proposal; distilled here into proposal shape.
- LakeLedger M074 + M075 dogfood — two occurrences of hand-rolled gate-finding fold between roadmap and plan-phase. Reference commits TBD (LakeLedger repo); confirm at queue-entry time.
- GSD `commands/gsd/discuss-phase.md` — external sibling implementation. UX-shape comparator only; do not literal-port.
- Existing infrastructure to reuse:
  - `commands/discuss.md` (milestone-discuss, structural template)
  - `templates/context-draft.md` (schema-version + frontmatter pattern)
  - `scripts/state/derive-phase.sh` (priority-ordered rule structure)
  - `commands/plan-phase.md` § Plan-Time Discipline (prerequisite-check shape)
  - `commands/comments.md` review-queue convention (CON-5/SC-5 — for v2 inline-spec-edit automation)
- Sibling proposals:
  - `M034-interactive-review-gates.md` — paired demand-driven slot, primary absorption candidate
  - `M038-living-documents.md` — paired demand-driven slot, secondary absorption candidate
  - `launch-sequencing-amendment-2026-05-03.md` — risk-rank framing
