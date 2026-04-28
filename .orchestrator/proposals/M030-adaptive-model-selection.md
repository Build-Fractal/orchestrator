# Proposal: M030 — Adaptive Model Selection

**Captured**: 2026-04-28
**Shape**: Milestone (4 phases) — collapsible to 2-3 if classifier heuristics prove simple
**Source**: User direction — "we should use lesser models where additional firepower is unnecessary, to be more sensitive to users' tokens"

## Goal

Route each dispatch to the cheapest model that can do the job correctly. Default toward Haiku/Sonnet for tasks whose plan is surgical or mechanical; reserve Opus for tasks whose character is novel, exploratory, or architecturally consequential. Surface the resulting savings via the M027 cost surfaces already shipped.

## Why now

Two enabling milestones have shipped that make this both *possible* and *responsible*:

1. **M027 (Cost+Quality Observability)** — every dispatch already records cost+quality data Goodhart-paired (CON-4). We can validate that "lesser model X performs equivalently on task class Y" with empirical rollup data, not by gut feel. M027's anomaly detection (`scripts/diagnostics/check-anomalies.sh`) will catch model-routing-induced regressions automatically (verifier failures, retry rates, pass-rate drops).

2. **M019 Tier 2/3 (cost rollup, per-task granularity)** — per-task LLM-source records aren't yet on disk (M027 noted this as `#Q-11` deferred). M030 P00 may need to extend the JSONL schema with a `model_used` field if not already present.

Today the orchestrator has *intensity* tiers (Quick/Standard/Full — controlling *process intensity*, e.g. how many gates fire) but no equivalent dial for *model selection*. Every dispatch effectively uses whatever the runtime defaults to (currently Opus 4.7 in CC). That's correct for novel architectural work and excessive for "edit this file to add a config knob per the plan."

## Strict scope

This is **model routing at dispatch time**, not:
- Process-intensity selection (already covered by `intensity-recommend.sh`)
- Conversus deliberation model selection (conversus owns that — see `~/Sites/conversus-oss/conversus.example.yml`)
- Multi-model deliberation within a single task (conversus's role)
- Codex Cloud model selection (deferred to M010 demand-driven fast-follow)

M030 asks: "given this task plan, what's the cheapest single model that should execute it?"

## Findings / design pillars

### F1. Task-character classifier

A new layer that classifies each task before dispatch into one of N character classes. Bash + heuristics over PLAN.md fields (no LLM call — that would defeat the savings). Inputs:

- **Plan structure** — does PLAN.md have explicit `## Steps` with file paths and exact edits? → mechanical
- **Verification block** — does the plan have unambiguous verifiers (`bash X.sh: PASS`)? → bounded
- **Task type field** — frontmatter `type:` (already present in some PLAN.md files)
- **File-touch breadth** — does the plan declare ≤3 files? → narrow → likely mechanical
- **Dispatch payload size** — proxy for context complexity (M018 telemetry)
- **Phase position** — P01 (foundation) tasks tend to be more novel; later P0N tasks tend to be more mechanical
- **Recent retry rate** — anomaly signal from M027; if this task class has been retrying, escalate

Output: one of `{surgical, bounded, exploratory, novel}` plus a confidence score.

### F2. Model routing table

`templates/model-routing.yml` — declarative mapping `(character × runtime) → model`. Examples:

```yaml
# Defaults aggressive; users can override via .orchestrator/config.yml
routing:
  surgical:
    claude-code: claude-haiku-4-5-20251001
    codex-cli: gpt-5-nano  # placeholder
    cursor: inherit
  bounded:
    claude-code: claude-sonnet-4-6
    codex-cli: gpt-5-mini
    cursor: inherit
  exploratory:
    claude-code: claude-sonnet-4-6
    codex-cli: gpt-5
    cursor: inherit
  novel:
    claude-code: claude-opus-4-7
    codex-cli: gpt-5
    cursor: inherit

escalation:
  on_verifier_fail: bump_one_tier  # surgical → bounded → exploratory → novel
  on_anomaly: bump_one_tier        # M027 anomaly detection
  max_escalations_per_task: 2      # hard cap
```

The table is the single source of truth — modifiable per-project via `.orchestrator/config.yml` overlay.

### F3. Dispatch-layer integration

`scripts/dispatch/dispatch-interface.sh` reads classifier output + routing table and selects model. Backend adapters (`scripts/dispatch/adapters/backend/*.sh`) translate to the runtime's model-selection mechanism:
- CC backend: `--model <id>` flag
- Codex CLI backend: equivalent
- Cursor: `inherit` (no programmatic override)

Per-dispatch JSONL records gain a `model_routed: <id>` field next to the existing `model_used` field. Discrepancies (routed ≠ used) get flagged in M027's anomaly detection.

### F4. Escalation + override

- **Verifier failure** auto-escalates: a `surgical` task whose verifiers fail re-dispatches at `bounded`. Hard cap at 2 escalations per task (prevents infinite cost spirals).
- **Operator override** per-task: PLAN.md frontmatter `model_override: <id>` short-circuits classification. Useful for tasks the user *knows* need Opus.
- **Operator override per-milestone**: `.orchestrator/config.yml` knob `model_routing_enabled: false` disables M030 entirely (always use runtime default).
- **Hard floor**: certain task types (e.g., constitutional changes, design milestones) have a `min_tier: novel` annotation that prevents downgrade regardless of classifier.

### F5. Surface via M027

No new cost surfaces. M030 hooks into existing M027 paths:
- `orchestrator:cost` rollup gets a per-model breakdown (`metrics-rollup.sh --by-model`)
- Efficiency footer shows model mix ("23 dispatches: 14 Haiku / 7 Sonnet / 2 Opus, $0.42 vs $1.89 if all-Opus")
- Anomaly detection catches routing-induced quality regression
- `orchestrator:doctor` `--config-check` validates routing table syntax

This piggybacks the M027 surfaces from M029 (which embeds them in the tree). Net result: the user sees model mix and savings naturally.

## Phase shape

| Phase | Goal | Key artifact | Verifies |
|---|---|---|---|
| P01 | Classifier + routing table | `scripts/dispatch/classify-task.sh` (heuristics over PLAN.md fields). `templates/model-routing.yml` defaults. Unit tests against fixture plans. | Classifier output reproducible; routing table parses; no LLM calls. |
| P02 | Dispatch integration | `dispatch-interface.sh` consults classifier + routing. Backend adapters honor `--model`. JSONL gains `model_routed` field. M027 schema updated. | End-to-end: dispatch a fixture plan, observe selected model in JSONL. |
| P03 | Escalation + override | Verifier-failure auto-escalation. Per-task and per-milestone override knobs. Hard cap. | Force a verifier fail on a `surgical` task; confirm re-dispatch at `bounded`. Confirm cap holds. |
| P04 | M027 surface integration + verifiers + summary | Per-model breakdown in `metrics-rollup.sh`. Efficiency-footer model-mix line. Doctor config-check rule. Replay corpus: 30 fixture tasks classify with ≥85% agreement vs human-labeled ground truth. | All P01-P03 verifiers green. Replay corpus baseline established. |

## Collapse condition

If P01 shows the classifier is essentially "look at PLAN.md frontmatter `type:` field" (i.e., humans already declared task character cleanly), M030 collapses to:
- **PR-1**: Routing table + dispatch integration
- **PR-2**: Escalation + M027 surface

Total ~2-3 days.

## Empirical validation strategy

Before shipping P02 to production dispatching, run a *shadow* mode:
1. Classifier runs and selects a model
2. Dispatch ignores the selection and uses runtime default (Opus)
3. JSONL records both `model_routed` (what classifier picked) and `model_used` (Opus)
4. After 50+ dispatches, compare verifier pass rates and quality metrics M027 already records
5. If shadow shows routing would have downgraded N tasks with no quality regression, *then* flip to live routing

This makes the milestone non-disruptive — early shadow data validates before any actual cost change. The shadow phase can be P02.5 if needed.

## Dependencies & sequencing

**Requires (all shipped)**: M019 Tier 1+2+3, M027 (cost surfaces — empirical validation needs them), M025 (installer coexistence — config knob plumbing).

**Plays nicely with**: M010 (Managed Agents) — when M010 lands its model abstraction, M030's routing table provides the policy layer M010 needs.

**Slot recommendation** (per `.orchestrator/proposals/README.md`): after M018 (active) and before M023, *or* between M023 and M029. Either works. Earlier is better for maximum savings accumulation pre-launch. Recommended: **immediately after M028** (auto hardening v3) — M028 stabilizes autonomous runs, M030 makes them cheap.

**Complementary milestones** (not blocking):
- M029 (roadmap viz) — surfaces the model mix in the headline / tree, but M030 ships without M029 and just shows in `orchestrator:cost` as today.
- M023 (design layer) — design tasks should annotate `min_tier: novel` to prevent inappropriate downgrades.

## Out of scope

- Multi-model deliberation within a task (conversus's role).
- Dynamic per-step model selection inside a single dispatch (would require runtime cooperation that doesn't exist).
- Cost optimization across providers (e.g., "would Codex be cheaper than CC for this task?") — runtime is fixed per-project; routing is within-runtime only.
- Auto-tuning the routing table from JSONL feedback. Tempting but premature; ship static-table v1 first and gather data.

## Open questions for `orchestrator:specify`

1. **Classifier output cardinality**: 4 classes (surgical/bounded/exploratory/novel) or 3 (mechanical/standard/novel)? More classes = finer routing but harder to label and validate. Recommendation: start with 3, add 4th if data shows clean split.
2. **Default aggressiveness**: how aggressive should defaults be? Conservative (only "surgical" downgrades) keeps quality risk minimal; aggressive (most non-novel tasks downgrade) maximizes savings. Recommendation: ship conservative; document the aggressive overlay.
3. **Shadow-mode duration**: 50 dispatches? 100? Time-bounded (1 week)? Recommendation: dispatch-count-bounded (50) — time-bounded is unfair to slow projects.
4. **Per-runtime model name handling**: hardcode model IDs in the routing table or symbolic names (`fast`/`balanced`/`smart`) that resolve per-runtime? Recommendation: symbolic names with per-runtime resolution table — avoids breaking when models are renamed/deprecated.
5. **Constitution interaction**: should "use lesser models where sufficient" become a constitutional principle? Adopting a principle would gate future feature additions on cost-impact. Probably overkill — leave it as a milestone-driven default.

## Source evidence (file paths)

- `scripts/engine/intensity-recommend.sh` (where to slot — already has cost-annotation hook from M027)
- `scripts/dispatch/dispatch-interface.sh` (dispatch entry point — gains routing call)
- `scripts/dispatch/adapters/backend/` (per-runtime model-flag translation)
- `scripts/diagnostics/metrics-rollup.sh` (M027 — extend with `--by-model`)
- `scripts/diagnostics/efficiency-footer.sh` (M027 — extend with model-mix line)
- `scripts/diagnostics/check-anomalies.sh` (M027 — already catches retry-rate spikes; routing regressions surface here for free)
- `templates/model-routing.yml` (NEW — routing policy)
- `scripts/dispatch/classify-task.sh` (NEW — task character classifier)
