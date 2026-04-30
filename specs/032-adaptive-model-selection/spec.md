---
schema_version: "1.0"
type: feature-spec
feature_slug: "032-adaptive-model-selection"
created_at: "2026-04-30"
status: "Draft"
milestone: "M030"
---

# Feature Specification: 032-adaptive-model-selection

**Feature Branch**: `032-adaptive-model-selection`
**Created**: 2026-04-30
**Status**: Draft
**Milestone**: M030
**Input**: User description: "Adaptive model selection: task-character classifier routes each dispatch to the cheapest single model that can do the job correctly. Default Haiku/Sonnet for surgical/mechanical tasks; reserve Opus for novel/architectural work. Verifier-fail auto-escalates one tier (cap 2). Per-task and per-milestone overrides plus min_tier floor for constitutional/design work. Empirical shadow-mode (50 dispatches) validates classifier against M027 quality data before flipping live. Symbolic model names (fast/balanced/smart) resolve per-runtime. Surface savings via M027 cost rollup, efficiency-footer model-mix line, doctor config-check, anomaly detection."

## Problem Statement

The orchestrator has process-intensity tiers (Quick / Standard / Full, controlling *how many gates fire*) but no equivalent dial for *which model executes the dispatch*. Every dispatch effectively uses whatever the runtime defaults to (currently Opus 4.7 in Claude Code). That is the right call for novel architectural work and is excessive for "edit this file to add a config knob per the plan."

Three concrete pain points follow from the gap. First, mechanical tasks — well-specified PLAN.md edits with explicit file paths, line targets, and unambiguous verifiers — burn premium model tokens for work a faster model would do correctly and ~10× cheaper. Second, the user has no visibility into the model mix, so token-spend trends look like a black box even after M027 shipped per-dispatch cost data. Third, today's all-Opus dispatch posture is a soft launch blocker: the orchestrator is asking early users to absorb premium-model cost on every dispatch with no levers to dial it back.

The minimum surface that fixes all three is a task-character classifier (heuristics over PLAN.md fields, no LLM call), a declarative routing table (`(character × runtime) → model`), dispatch-layer integration that selects the model before invoking the backend adapter, escalation on verifier failure (capped), and a shadow-mode validation phase that produces empirical evidence before any live cost change. M027's cost+quality observability is a hard prerequisite — without paired metrics, "model X works on task class Y" is gut feel rather than measurement.

This spec deliberately does not attempt cross-provider cost optimization, multi-model deliberation within a single dispatch, dynamic per-step model selection, or auto-tuning the routing table from JSONL feedback. Those each have their own scope (conversus owns multi-model deliberation; cross-provider routing requires runtime cooperation that does not exist; auto-tuning is premature without static-table baseline data).

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

US-1 (classifier + routing table) plus US-2 (dispatch integration with shadow mode) close the dogfood loop: every dispatch in this repo's own milestones gets classified and the predicted model is recorded next to the actually-used model in JSONL, producing the empirical record that gates US-3 (live routing flip) and US-4 (escalation + override). US-5 (M027 surface integration) and US-6 (operator overrides) layer on after the empirical foundation holds.

### User Story 1 — Classify task character before dispatch (Priority: P1)

As an orchestrator operator running a dispatch, I want each task classified into one of three character classes (mechanical / standard / novel) before the model is selected, so the routing table has a deterministic input and the classification is reproducible across runs without an LLM call.

**Why this priority**: Every other story consumes classifier output. Without a stable classifier, the routing table has no input, the shadow-mode comparison has no signal, and escalation has no baseline to escalate from. This is the load-bearing primitive.

**Independent Test**: Feed `scripts/dispatch/classify-task.sh <plan-path>` a fixture corpus of 20+ PLAN.md files (some mechanical, some novel, some ambiguous). Run the classifier twice; both runs return identical `character=` + `confidence=` lines. No network calls, no LLM round-trips, runs under 100ms per plan.

**Acceptance Scenarios**:

1. **Given** a PLAN.md with explicit `## Steps` listing file paths and exact edits across ≤3 files plus unambiguous bash verifiers, **When** the classifier runs, **Then** stdout contains `character=mechanical` and `confidence=high`.
2. **Given** a PLAN.md whose Goal section uses words like "explore", "design", or "evaluate alternatives" with no concrete file targets, **When** the classifier runs, **Then** stdout contains `character=novel` and `confidence=high`.
3. **Given** a PLAN.md that is partially specified (file paths declared but verifiers ambiguous), **When** the classifier runs, **Then** stdout contains `character=standard` and `confidence=medium`.
4. **Given** the same PLAN.md run through the classifier twice, **When** both runs complete, **Then** both runs emit byte-identical stdout (deterministic).

### User Story 2 — Shadow-mode dispatch with paired prediction (Priority: P1)

As an orchestrator operator running real milestone dispatches, I want the classifier to record the routing-table choice in JSONL alongside the actually-used model and produce evidence of classifier-confidence stability per class, so I have empirical paired data validating that the classifier is well-calibrated before any live cost change. Cross-model regression detection is performed post-flip via escalation, anomaly detection, and the kill switch — not pre-flip via empirical model-equivalence.

**Why this priority**: Constitution Principle II (Evidence Before Claims) requires that the live-routing flip rest on stated, mechanically-verifiable evidence. The shadow corpus is the evidence layer for classifier calibration; FR-10 escalation, FR-18 anomaly detection, and CON-4 kill switch are the evidence layer for post-flip cross-model regression. Without ≥50 paired dispatches per class showing stable classifier confidence, US-3 has nothing to defend its flip on, and the post-flip regression mesh has no class baseline.

**Independent Test**: Run 50 real dispatches across at least two phases of any milestone with `M030_SHADOW_MODE=1`. Each `dispatch_usage` JSONL record contains both `model_routed` and `model_used` fields; `model_used` continues to match the runtime default; `bash scripts/diagnostics/shadow-compare.sh` reports per-class evidence count + classifier-confidence stability + a `flip_recommendation=ready|partially_ready|block|evidence_insufficient` verdict.

**Acceptance Scenarios**:

1. **Given** shadow mode is enabled and a task is classified as `mechanical`, **When** dispatch executes, **Then** the JSONL `dispatch_usage` record contains `model_routed=fast` (symbolic) and `model_used=<runtime-default-id>` and verifier outcome.
2. **Given** 50+ shadow dispatches per class on disk with stable classifier confidence, **When** `shadow-compare.sh` runs, **Then** stdout reports per-class evidence count + classifier-confidence stability + `flip_recommendation=ready`.
3. **Given** ≥2 of 3 classes meet the per-class threshold AND the under-threshold class's routing-table default is `smart`, **When** `shadow-compare.sh` runs, **Then** stdout reports `flip_recommendation=partially_ready` and enumerates the flippable classes; the under-threshold class is named in `withheld_classes`.

### User Story 3 — Live model routing with escalation (Priority: P2)

As an orchestrator operator who has validated the shadow data, I want dispatch to actually use the routed model and to auto-escalate one tier on verifier failure (capped at 2 escalations per task), so cheap-model failures self-correct without an infinite cost spiral.

**Why this priority**: This is the actual cost-savings event. P2 because it depends on US-1 + US-2 evidence; the safety mechanism (escalation cap) is what makes it operationally responsible.

**Independent Test**: With routing live, dispatch a `mechanical`-classified task whose plan deliberately mis-specifies a verifier so the cheap-model output fails. Observe re-dispatch at the next tier (`fast` → `balanced`). Force a second failure; observe re-dispatch at `smart`. Force a third failure; observe `escalation_cap_hit` JSONL record and the task surfaces as a normal verifier failure (not a fourth re-dispatch).

**Acceptance Scenarios**:

1. **Given** routing is live and a task classified `mechanical`, **When** dispatch runs and verifiers pass, **Then** the task closes with `model_used=<fast-tier-id>` and one dispatch in the JSONL trail.
2. **Given** routing is live and a `mechanical` task fails verification, **When** auto-escalation fires, **Then** a second `dispatch_usage` record appears with `model_used=<balanced-tier-id>` and `escalation_reason=verifier_fail`.
3. **Given** a task has already escalated twice, **When** verifier fails a third time, **Then** no further re-dispatch fires, an `escalation_cap_hit` JSONL record is written, and the task fails normally through the existing verifier-failure path.

### User Story 4 — Operator overrides and floors (Priority: P2)

As an orchestrator operator working on architecturally consequential tasks, I want to declare `model_override:` in PLAN.md frontmatter or `min_tier: smart` for entire milestones, plus a global kill switch, so I can short-circuit classification when I know the task character better than the heuristics do.

**Why this priority**: P2 because US-3 ships safe defaults; overrides are the escape hatch that makes adoption non-disruptive for milestones the user already knows need premium models (constitutional changes, design milestones, novel architecture).

**Independent Test**: Create three plan fixtures — one with `model_override: smart` in frontmatter (classified `mechanical`), one in a milestone with `.orchestrator/config.yml` declaring `model_routing.min_tier: smart`, one with `.orchestrator/config.yml` declaring `model_routing_enabled: false`. Dispatch all three; observe the override propagates in each case.

**Acceptance Scenarios**:

1. **Given** a PLAN.md with `model_override: smart`, **When** dispatch runs, **Then** the JSONL record contains `model_routed=smart` regardless of classifier output, and `override_source=plan_frontmatter`.
2. **Given** `.orchestrator/config.yml` sets `model_routing.min_tier: smart` for the active milestone, **When** dispatch runs on any task in that milestone, **Then** `model_used` is at least `smart` even for `mechanical`-classified tasks, with `override_source=milestone_floor`.
3. **Given** `.orchestrator/config.yml` sets `model_routing_enabled: false`, **When** dispatch runs, **Then** the routing layer is a pass-through and `model_used` matches the runtime default with `override_source=disabled`.

### User Story 5 — Cost-savings visibility via M027 surfaces (Priority: P3)

As an orchestrator operator monitoring cost trends, I want the model mix and counterfactual savings shown in `orchestrator:cost`, the efficiency footer, and `orchestrator:doctor` config-check, so I can see "23 dispatches: 14 fast / 7 balanced / 2 smart, $0.42 vs $1.89 if all-smart" without reading raw JSONL.

**Why this priority**: P3 because the JSONL data is the truth; the surfaces are convenience. Useful for the launch story but not load-bearing for the routing decision itself.

**Independent Test**: After running 10+ live dispatches across the three classes, run `bash scripts/diagnostics/metrics-rollup.sh --by-model`, `bash scripts/diagnostics/efficiency-footer.sh`, and `bash scripts/diagnostics/doctor.sh --config-check`. Each surface prints model-mix + savings data; doctor validates routing-table syntax.

**Acceptance Scenarios**:

1. **Given** 10+ live dispatches on disk, **When** `metrics-rollup.sh --by-model` runs, **Then** stdout includes per-tier dispatch counts and aggregated cost vs. the all-`smart` counterfactual.
2. **Given** the same data, **When** the efficiency footer renders at the close of an `orchestrator:auto` run, **Then** the footer includes a `model_mix:` line summarizing the run's tier distribution and savings versus default.
3. **Given** a malformed `templates/model-routing.yml` (e.g., undefined symbolic name), **When** `doctor.sh --config-check` runs, **Then** stdout reports the malformation with the offending file path and line number.

### User Story 6 — Anomaly-driven escalation (Priority: P3)

As an orchestrator operator, I want a sustained spike in verifier-fail rate or retry rate on a class to auto-escalate that class's default tier (or surface as a `block_flip` if shadow), so model-routing-induced quality regressions are caught by M027's anomaly detection before they cost a milestone.

**Why this priority**: P3 because manual reversal via the kill switch already covers the catastrophic case; this is the early-warning improvement on top.

**Independent Test**: Synthesize 20 fixture dispatches per class with engineered verifier-fail rates; run `scripts/diagnostics/check-anomalies.sh`. Confirm the script emits a `model_routing_regression` record when a class crosses the configured threshold.

**Acceptance Scenarios**:

1. **Given** `mechanical`-class verifier-fail rate exceeds the configured threshold over the rolling window, **When** `check-anomalies.sh` runs, **Then** an anomaly record with `kind=model_routing_regression` and `class=mechanical` is emitted to JSONL and surfaced by `orchestrator:doctor`.

---

## Edge Cases

- **Plan with no clear character signals** — PLAN.md missing both explicit step structure and explicit "explore/design" framing. Classifier returns `character=standard` with `confidence=low`; routing table maps low-confidence-standard to the safer (`balanced`) tier rather than the cheapest.
- **Runtime that does not support model selection** — Cursor today has no programmatic model-override hook. The Cursor backend adapter resolves any symbolic tier to `inherit` (no flag emitted to the runtime); JSONL still records `model_routed=<symbolic>` and `model_used=inherit` so the shadow corpus remains useful for any future runtime that does support selection.
- **Shadow-mode JSONL gaps** — operator runs partial dispatches and the shadow corpus has fewer than 50 entries when flip-readiness check runs. The check refuses the flip with a `evidence_insufficient` exit code rather than guessing.
- **Override conflict** — PLAN.md declares `model_override: fast` while milestone config declares `min_tier: smart`. Floor wins; override-source recorded as `milestone_floor` (not `plan_frontmatter`); a one-line warning emitted so the operator notices the conflict.
- **Symbolic name resolution failure** — routing table refers to a symbolic tier (`fast`) but the per-runtime resolution table has no mapping for the active runtime. Dispatch refuses with a clear error pointing at `templates/model-routing.yml`; the kill switch (`model_routing_enabled: false`) is named in the diagnostic as the immediate workaround.
- **Verifier-fail escalation collides with budget cap** — escalation would push a task above the milestone's M027 budget. Escalation still proceeds (budget is a soft surface, not a hard gate per existing M027 semantics) but the cost-cap-warning JSONL record fires.
- **Classifier disagrees with itself across plan revisions** — a PLAN.md is amended mid-milestone and re-classifies into a different class. New classification applies to subsequent dispatches; prior shadow data is preserved with the original classification timestamp so the shadow corpus is not retroactively corrupted.

---

## Functional Requirements

- **FR-1 (classifier-script)**: `scripts/dispatch/classify-task.sh <plan-path>` reads PLAN.md frontmatter + body and emits `character=<mechanical|standard|novel>` plus `confidence=<high|medium|low>` to stdout. Pure bash + heuristics — no LLM call, no network, no jq dependency on the hot path. Satisfies US-1 AS-1/AS-2/AS-3/AS-4.
- **FR-2 (classifier-inputs)**: Heuristic inputs are limited to: explicit `## Steps` block presence + structure, file-touch breadth declared in plan, verification-block specificity, frontmatter `type:` field if present, phase position within milestone (P01 vs late P0N), and recent-retry signal from M027 anomaly JSONL. No other inputs; the heuristic table is the SSOT. Classifier output for the same PLAN.md is consistent within a single `orchestrator:auto` run because anomaly JSONL state is snapshotted at the start of each run (or, equivalently, the classifier reads anomaly JSONL once at session startup rather than per-dispatch). Cross-run consistency is NOT guaranteed when the anomaly JSONL changes between runs; shadow-corpus records that share a PLAN.md path but differ in `model_routed` across runs are expected behavior, not corpus corruption — the timestamped append-only nature of the corpus (CON-6) preserves both observations. Satisfies US-1 deterministic-output requirement and resolves Q-A9 (RISK-07).
- **FR-3 (routing-table)**: `templates/model-routing.yml` declares the `(character × runtime) → symbolic-tier` mapping plus the `(symbolic-tier × runtime) → model-id` resolution table. Conservative defaults: only `mechanical` downgrades to `fast`; `standard` maps to `balanced`; `novel` stays at `smart`. The template also declares a `cost_rates:` section with per-symbolic-tier input/output token costs (per million tokens) — this is the SSOT for the cost counterfactual computed by `metrics-rollup.sh --by-model` (FR-15) and rendered by the `model_mix:` line (FR-16). When the per-tier `cost_rates:` entry is absent, `metrics-rollup.sh --by-model` MUST emit a "cost rates not configured" warning and produce a zero-savings line. `references/model-routing.md` documents the operator obligation to update `cost_rates:` when provider pricing changes. Aggressive overlay documented in `references/model-routing.md` for opt-in operators. Satisfies the brief's open-question resolutions #1, #2, and #4 and resolves Q-A6.
- **FR-4 (per-project-overlay)**: `.orchestrator/config.yml` accepts a `model_routing:` block that overlays the template defaults — supported keys are `enabled`, `min_tier`, and per-class `tier` overrides. The overlay is read at dispatch time; no orchestrator restart required. Satisfies US-4 AS-2/AS-3.
- **FR-5 (dispatch-integration)**: `scripts/dispatch/dispatch-interface.sh` invokes the classifier for each task before adapter dispatch, resolves the routing-table choice to a concrete model ID via the per-runtime resolution table, and passes the model ID to the backend adapter. The selected model ID and the symbolic tier are recorded in the dispatch JSONL record. Satisfies US-2 AS-1.
- **FR-6 (backend-adapter-translation)**: Backend adapters (`scripts/dispatch/adapters/backend/*.sh`) translate the resolved model ID to the runtime's model-selection mechanism — Claude Code passes `--model <id>`; Codex CLI passes its equivalent flag; Cursor falls back to `inherit` (no flag, runtime default applies). The adapter contract is one stdin/stdout shape; the per-runtime translation is internal to each adapter. Satisfies US-2 AS-1, edge case "Runtime that does not support model selection".
- **FR-7 (shadow-mode-as-classifier-calibration)**: When `M030_SHADOW_MODE=1` (env var) or `model_routing.shadow: true` (config), `dispatch-interface.sh` runs the classifier and records the routing decision but passes the runtime default to the adapter. JSONL `dispatch_usage` records gain both `model_routed` (symbolic + ID, the classifier's choice) and `model_used` (actual ID, the runtime default). Shadow mode is a **classifier-calibration gate**, not a model-equivalence gate: it produces evidence that classification is stable and class coverage is adequate, not evidence that cheaper models perform equivalently to the runtime default. Cross-model regression detection is performed post-flip via FR-10 (escalation), FR-18 (anomaly), and CON-4 (kill switch) — see Constitution Check below. Shadow mode is the default state until US-3 flip-readiness is signed off. Satisfies US-2 AS-1, US-2 AS-2.
- **FR-8 (shadow-comparison-classifier-confidence)**: `scripts/diagnostics/shadow-compare.sh` aggregates the shadow corpus and reports (a) per-class evidence count, (b) per-class classifier-confidence stability (rolling variance of `confidence=` values within class, plus minimum class-coverage threshold), and (c) a `flip_recommendation=ready|partially_ready|block|evidence_insufficient` verdict. Threshold for `ready`: ≥50 dispatches per class with classifier-confidence stability above the configured floor. Threshold for `partially_ready`: ≥2 of 3 classes meet the per-class evidence + stability thresholds AND the under-threshold class's routing-table default is `smart` (no model downgrade would occur for that class under live routing); `shadow-compare.sh` enumerates the flippable classes. Threshold for `evidence_insufficient`: corpus has 0 dispatches OR all classes are below threshold. The classifier-confidence stability metric is defined concretely in plan-phase (#Q-3 deferred). Satisfies US-2 AS-2/AS-3 and resolves Q-A1 + Q-A3.
- **FR-9 (live-routing-flip-programmatically-enforced)**: When `model_routing.live: true` (config), `dispatch-interface.sh` MUST invoke `bash scripts/diagnostics/shadow-compare.sh` before the first live-routed dispatch in any session. If `shadow-compare.sh` returns `flip_recommendation=evidence_insufficient` (or `block`), `dispatch-interface.sh` MUST refuse to proceed with live routing, MUST NOT call the backend adapter, and MUST write a JSONL record with `override_source=shadow_gate_blocked` plus the failing verdict. If `shadow-compare.sh` returns `ready`, all classes flip live; if it returns `partially_ready`, only the enumerated classes flip — the under-threshold class continues to dispatch at its conservative default, and JSONL records `partial_flip_active=true` with `withheld_classes=<list>` for dispatches in the withheld classes. The flip is per-project and reversible (revert the config knob); orchestrator state and prior shadow data are preserved across the flip. Satisfies US-3 and resolves Q-A2 + Q-A3.
- **FR-10 (verifier-fail-escalation)**: On verifier failure of a routed dispatch, `dispatch-interface.sh` re-dispatches the task at the next-higher symbolic tier (`fast` → `balanced` → `smart`). Each escalation increments a per-task counter in JSONL; at counter ≥2, no further escalation fires and the task surfaces as a normal verifier failure. The escalation reason and source are recorded. Satisfies US-3 AS-2/AS-3.
- **FR-11 (per-task-override)**: PLAN.md frontmatter `model_override: <symbolic-tier|model-id>` short-circuits classification — the override resolves through the same per-runtime resolution table as routed selections. JSONL records `override_source=plan_frontmatter`. Satisfies US-4 AS-1.
- **FR-12 (per-milestone-floor)**: `.orchestrator/config.yml` `model_routing.min_tier: <symbolic-tier>` raises the effective floor for every dispatch in the active milestone — even `mechanical`-classified tasks dispatch at the floor or higher. JSONL records `override_source=milestone_floor`. Satisfies US-4 AS-2. **Note**: `min_tier` is not a substitute for an unvalidated class in a partial flip — it routes unconditionally at the floor without engaging the shadow corpus or the flip-readiness check (FR-9). When `partially_ready` authorizes a partial live flip, the under-threshold class continues to dispatch at its routing-table default; do not interpret `min_tier: smart` on the under-threshold class as a partial-flip mechanism. (Resolves Q-A8.)
- **FR-13 (kill-switch)**: `.orchestrator/config.yml` `model_routing_enabled: false` makes the routing layer a pass-through — classifier still runs and records `model_routed`, but the adapter receives no `--model` flag and `model_used` is the runtime default. JSONL records `override_source=disabled`. Satisfies US-4 AS-3.
- **FR-14 (override-conflict-resolution)**: When per-task override and per-milestone floor disagree, the floor wins. A one-line warning is emitted to stderr; JSONL records `override_source=milestone_floor` (not `plan_frontmatter`). Satisfies the override-conflict edge case.
- **FR-15 (M027-rollup-extension)**: `scripts/diagnostics/metrics-rollup.sh` accepts `--by-model` flag that outputs per-symbolic-tier dispatch counts, aggregated cost, and the all-`smart` counterfactual. Existing rollup output shape is unchanged when the flag is absent (additive only — CON-5 holds). Satisfies US-5 AS-1.
- **FR-16 (efficiency-footer-extension)**: `scripts/diagnostics/efficiency-footer.sh` emits a `model_mix:` line summarizing the run's tier distribution and savings versus the all-`smart` baseline. The line is additive — existing footer fields are byte-identical when no model-routing data is present (CON-5). Satisfies US-5 AS-2.
- **FR-17 (doctor-config-check)**: `scripts/diagnostics/doctor.sh --config-check` validates `templates/model-routing.yml` syntax — checks symbolic-tier closure (no undefined names), per-runtime resolution-table coverage, and `.orchestrator/config.yml` overlay compatibility. Reports specific malformations with file path and line number. Satisfies US-5 AS-3.
- **FR-18 (anomaly-detection-extension)**: `scripts/diagnostics/check-anomalies.sh` adds a rolling-window check on per-class verifier-fail rate. When a class crosses the configured threshold, a `model_routing_regression` anomaly record is emitted. Existing anomaly checks are unchanged. Satisfies US-6.
- **FR-19 (jsonl-schema-additive)**: All new JSONL fields (`model_routed`, `model_used`, `override_source`, `escalation_count`, `escalation_reason`) are additive — existing consumers that ignore the fields continue to work. The schema extension is documented in `references/observability.md`. Satisfies CON-5.

## Success Criteria

- **SC-1**: `bash scripts/dispatch/classify-task.sh <fixture-plan>` exits 0 with deterministic stdout across two consecutive runs (`diff` produces empty output) on every plan in the fixture corpus. No network calls (verified via `strace`/`dtruss` in the test harness, or by absence of any curl/dispatch invocations in the script body).
- **SC-2**: After 50+ shadow dispatches across at least two phases, `bash scripts/diagnostics/shadow-compare.sh` exits 0 and stdout contains per-class evidence counts plus per-class classifier-confidence stability metric plus a `flip_recommendation=` line with one of `ready`, `partially_ready`, `block`, or `evidence_insufficient`.
- **SC-2a (programmatic flip-gate)**: With `model_routing.live: true` and a shadow corpus of 0 dispatches, `bash scripts/dispatch/dispatch-interface.sh` refuses to call any backend adapter, exits nonzero, and writes a JSONL record where `jq -r '.override_source'` returns `shadow_gate_blocked`. With `model_routing.live: true` and a corpus where `shadow-compare.sh` returns `ready` (or `partially_ready` for the dispatched task's class), `dispatch-interface.sh` proceeds normally.
- **SC-3**: With routing live on a fixture plan classified `mechanical`, `bash scripts/dispatch/dispatch-interface.sh` exits 0 and the resulting JSONL `dispatch_usage` record contains `model_used=<fast-tier-id>` (verified via `jq -r '.model_used'`).
- **SC-3a (shadow-record write-path correctness)**: For each record in the shadow-mode fixture corpus, `jq -r '.model_routed'` matches the stdout `character=` → `symbolic-tier` mapping produced by `bash scripts/dispatch/classify-task.sh <plan-path>` run independently on the same plan, where `<plan-path>` is the plan referenced in the JSONL record. This verifies the initial-write correctness of the shadow corpus that CON-6's append-only invariant alone does not.
- **SC-4**: With routing live on a fixture plan engineered to fail verifier twice then pass, the JSONL trail contains exactly three `dispatch_usage` records for the task with `model_used` values forming the sequence `<fast> <balanced> <smart>` and the third record carrying `escalation_count=2`.
- **SC-5**: With routing live on a fixture plan engineered to fail verifier three times, the JSONL trail contains exactly three `dispatch_usage` records (no fourth) and one `escalation_cap_hit` record with `task_id=<id>` and `final_count=2`.
- **SC-6**: A PLAN.md with `model_override: smart` in frontmatter, classified by the classifier as `mechanical`, dispatches at the `smart` tier — `jq -r '.model_routed'` returns `smart` and `jq -r '.override_source'` returns `plan_frontmatter`.
- **SC-7**: With `.orchestrator/config.yml` setting `model_routing_enabled: false`, dispatching any plan results in `jq -r '.override_source'` returning `disabled` and `jq -r '.model_used'` matching the documented runtime default.
- **SC-7a (compound kill-switch + floor)**: With `.orchestrator/config.yml` setting both `model_routing_enabled: false` and `model_routing.min_tier: smart`, dispatching any `mechanical`-classified plan results in `jq -r '.override_source'` returning `disabled` (NOT `milestone_floor`), `jq -r '.model_used'` matching the runtime default, and stderr containing the one-line bypass warning naming `min_tier: smart` as inactive.
- **SC-8**: `bash scripts/diagnostics/metrics-rollup.sh --by-model` exits 0 and stdout contains a line matching the regex `^[0-9]+ dispatches: [0-9]+ fast / [0-9]+ balanced / [0-9]+ smart`. When `templates/model-routing.yml` defines a `cost_rates:` section, stdout additionally contains an aggregated cost line and an all-`smart` counterfactual line. When `cost_rates:` is absent, stdout additionally contains a "cost rates not configured" warning and a zero-savings line — both cases exit 0.
- **SC-9**: `bash scripts/diagnostics/doctor.sh --config-check` exits 1 on a `templates/model-routing.yml` with an undefined symbolic-tier reference, and stdout names both the offending file and the offending line number.
- **SC-10**: A fixture corpus of ≥30 hand-labeled tasks classifies with ≥85% agreement against ground truth — measured by `bash scripts/dispatch/classify-task.sh` output matching the human label for ≥26 of 30 plans. The fixture corpus MUST be drawn from pre-existing PLAN.md files in `specs/0NN-*/` with hand-applied labels recorded in a version-controlled fixture file at `tests/fixtures/m030-classifier-corpus/labels.yml`. The fixture file commit timestamp MUST precede the first commit of `classify-task.sh`. The labeling party MUST NOT have access to the classifier implementation at time of labeling; if the corpus is drawn from pre-M030 milestone history and labeled before implementation begins, this constraint is satisfied by construction.
- **SC-11**: Existing M027 JSONL consumers (`metrics-rollup.sh` without `--by-model`, `efficiency-footer.sh` reading pre-M030 data) emit byte-identical output when run against pre-M030 JSONL fixtures (CON-5 additive-schema verification).

## Non-Goals

- **NG-1**: Multi-model deliberation within a single dispatch. Conversus owns this surface; M030's routing layer selects exactly one model per dispatch.
- **NG-2**: Dynamic per-step model selection inside a single dispatch. Would require runtime cooperation that does not exist.
- **NG-3**: Cross-provider cost optimization (e.g., "would Codex be cheaper than CC for this task?"). Runtime is fixed per-project; routing is within-runtime only.
- **NG-4**: Auto-tuning the routing table from JSONL feedback. Tempting but premature — ship static-table v1 and gather data first; promote to a follow-up milestone if signal warrants.
- **NG-5**: Codex Cloud model selection. Deferred to M010 (Managed Agents + Codex Cloud) demand-driven fast-follow.
- **NG-6**: Process-intensity selection. `intensity-recommend.sh` already covers this; M030 is orthogonal.
- **NG-7**: Conversus deliberation model selection. Conversus owns its own model-selection surface (`conversus.example.yml`); M030 does not reach into deliberation internals.
- **NG-8**: A new constitutional principle for cost-sensitivity. The brief's open-question resolution #5: milestone-driven default is sufficient; promoting to a constitutional principle would gate every future feature on cost impact, which is overkill.

## Constraints

- **CON-1 (no-LLM-on-classifier-hot-path)**: The classifier MUST NOT invoke an LLM. Doing so would defeat the entire token-savings premise. Enforced by code review and by the dispatch-time JSONL record showing classifier latency well under any plausible LLM round-trip.
- **CON-2 (additive-jsonl-schema)**: All new JSONL fields are additive; existing consumers must continue to work byte-identically when run against pre-M030 fixtures. Cross-references the existing M027 invariant (CON-5 in spec-029).
- **CON-3 (per-runtime-symbolic-resolution)**: Symbolic names (`fast`, `balanced`, `smart`) are the routing-table interface; concrete model IDs live only in the per-runtime resolution table. Hardcoding model IDs in the routing table is forbidden — it would break when models are renamed or deprecated.
- **CON-4 (kill-switch-always-available-supersedes-min_tier)**: The kill switch (`model_routing_enabled: false`) MUST disable the entire routing layer regardless of any other config. No code path may bypass it. This is the operator's panic button if routing introduces an unexpected regression. **The kill switch supersedes `min_tier`.** When `model_routing_enabled: false` is active alongside an active `min_tier` setting, `override_source=disabled` is recorded in JSONL and a one-line stderr warning names the bypassed `min_tier` value, e.g., `model_routing_enabled=false: min_tier: smart is inactive`. Two conforming implementations reading only the spec text MUST produce identical behavior on this interaction.
- **CON-5 (escalation-hard-cap)**: The verifier-fail escalation hard-cap is 2 escalations per task. Removing or raising the cap requires a new D-row decision; this is the cost-spiral safety guarantee.
- **CON-6 (shadow-corpus-immutability)**: Once a shadow JSONL record is written with a `model_routed` value, the value MUST NOT be retroactively rewritten by re-classification. Plan amendments produce new records with new timestamps; the corpus is append-only.

### Knowledge-Layer Boundary (M030 vs. M020 / M027)

M030 owns: `templates/model-routing.yml` (the routing-table SSOT), `scripts/dispatch/classify-task.sh` (classifier heuristics), and the new JSONL fields enumerated in FR-19.

M020 (knowledge-layer maturation) continues to own the knowledge-graph schema and the `knowledge/**` write-sites. M030 reads M027-emitted JSONL (anomaly stream, dispatch usage) but does not write into `knowledge/**` — model-routing decisions are dispatch-layer state, not knowledge-graph state.

M027 continues to own `metrics-rollup.sh`, `efficiency-footer.sh`, `check-anomalies.sh`, and `doctor.sh`. M030 extends each with additive flags / fields per FR-15 / FR-16 / FR-17 / FR-18 — no rewrites of existing M027 surfaces.

## Assumptions

- **A-1**: M019 Tier 1+2+3 cost-rollup JSONL stream (`dispatch_usage`, `unit_close`) is the canonical source of paired cost+quality data. M030 reads but does not modify the existing fields.
- **A-2**: M027 anomaly detection (`check-anomalies.sh`) is shipped and emits anomaly records in the schema documented in `references/observability.md`.
- **A-3**: M025 installer coexistence is shipped — M030's config-knob plumbing through `.orchestrator/config.yml` follows the M025 overlay convention.
- **A-4**: Claude Code, Codex CLI, and Cursor backend adapters in `scripts/dispatch/adapters/backend/` exist and accept a uniform stdin/stdout shape from `dispatch-interface.sh`.
- **A-5**: M028 (autonomous hardening v3) ships before M030 — M028 stabilizes autonomous runs that M030's shadow corpus depends on for clean signal.
- **A-6**: Operators have access to fixture PLAN.md files for the classifier ground-truth corpus. The corpus may be drawn from this repo's own milestone history (`specs/0NN-*`).

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle I (Context Minimization)**: M030 reduces token spend per task by routing surgical work to faster, cheaper models. Per the standalone-amendment refinement of Principle I ("minimize *total task tokens via efficient context delivery*, not payload bytes"), M030 minimizes total task cost without changing context delivery — orthogonal but reinforcing.
- **Principle II (Evidence Before Claims)**: M030's evidence story is two-layered. Pre-flip, shadow mode (FR-7 / FR-8 / SC-2) produces empirical evidence of **classifier-confidence stability and class coverage** — not cross-model verifier-pass equivalence — because the cheaper model is never invoked during shadow. Per-class evidence ≥50 dispatches with stable classifier confidence is the mechanically-verifiable gate that authorizes the flip. Post-flip, cross-model regression is detected by three independent mechanisms: FR-10 verifier-fail escalation (≤2 tier-jumps per task per CON-5, the cost-spiral safety guarantee), FR-18 per-class anomaly detection (`model_routing_regression` records when verifier-fail rate crosses the configured threshold over the rolling window), and CON-4 kill switch (operator-pulled disable of the routing layer entirely). Each post-flip mechanism is mechanically verifiable in JSONL. The deliberate choice to recharacterize shadow mode away from cheaper-model equivalence (rejected: 5% canary as Option B during discuss) traded pre-flip empirical model-equivalence — which the spec's original FR-7 mechanism could not produce — for an honest two-layer story whose evidence is what each mechanism actually generates.
- **Principle III (Design Before Code)**: The routing table (FR-3) and the symbolic-tier-with-per-runtime-resolution decision (CON-3) are the design layer for the implementation. The classifier heuristic table (FR-2) is itself a design artifact authored before the implementation script.
- **Principle XIV (No Speculative Complexity)**: NG-4 (no auto-tuning), NG-3 (no cross-provider routing), NG-2 (no per-step selection) all reflect this principle. Ship the static-table baseline; let data justify any future complexity.
- **Principle XV (Surgical Precision)**: The routing layer is a single decision point in `dispatch-interface.sh` with three additive surfaces (rollup `--by-model`, footer `model_mix:`, doctor `--config-check`) — none of which rewrite existing M027 code paths. The kill switch (CON-4) gives operators a single revert knob.

## Open Questions (defer to planning)

- **#Q-1 (RESOLVED — promoted to spec constraint per Q-A4 arbiter ruling)**: The fixture corpus SHALL be drawn from real milestone history (pre-M030 `specs/0NN-*/` PLAN.md files), labeled against the FR-2 character definitions before `classify-task.sh` is authored, and committed as a version-controlled fixture file before M030 implementation begins. The plan-phase document MUST confirm timeline compliance as a SC-10 verification prerequisite. Synthetic-fixture corpora are out of scope for SC-10 verification.
- **#Q-2 (shadow-corpus-storage)**: Does the shadow corpus live in the existing `dispatch_usage` JSONL stream (additive fields per FR-19) or a separate `.orchestrator/shadow-corpus.jsonl` file? Recommendation is the additive route — keeps the stream unified and lets `check-anomalies.sh` consume it without a second source.
- **#Q-3 (escalation-from-floor)**: When a task has `min_tier: balanced` (milestone floor) and verifier fails, does escalation step from `balanced → smart` (one tier) or skip directly to `smart`? Plan-phase decides; recommendation is to step one tier at a time from whatever the actual dispatch tier was.
- **#Q-4 (anomaly-threshold-default)**: What is the configured threshold for the `model_routing_regression` anomaly (FR-18) — fixed pass-rate delta (e.g., 15%) or relative-to-runtime-default-baseline? Plan-phase decides with M027-team input.
- **#Q-5 (rollback-grace)**: When the kill switch flips from `false → true`, do in-flight dispatches honor the new state immediately or complete under the prior state? Recommendation is "complete under prior state" to avoid mid-task config flips, with the new state taking effect on the next dispatch.

### Conversus Gate Findings (RESOLVED 2026-04-29 — see `M030-CONTEXT.md`)

**Resolution status**: All 8 findings (#Q-A1 through #Q-A8) and the accepted-with-monitoring item (RISK-07) were resolved during `orchestrator:discuss` on 2026-04-29. Binding decisions D-A1 through D-A9 are recorded in `specs/032-adaptive-model-selection/M030-CONTEXT.md`. The corresponding spec amendments have been applied to FR-2, FR-3, FR-7, FR-8, FR-9, FR-12, CON-4, US-2, SC-2, SC-3a (new), SC-7a (new), SC-8, SC-10, the Constitution Check, and Q-1 (promoted to spec constraint). The text below is preserved as the historical record of the findings being amended; do not re-relitigate without superseding `M030-CONTEXT.md`.

The Standard-intensity adversarial gate (`conversus.sh gate spec-pressure-test`) returned **verdict=BLOCK, surviving_disputes=7** with one arbiter ruling. Full deliberation at `specs/032-adaptive-model-selection/conversus/`. At Standard intensity the BLOCK is advisory — these findings carried into `orchestrator:discuss` for resolution before plan-phase. Two were CRITICAL (architecturally load-bearing); the rest were targeted prose/logic amendments.

- **#Q-A1 — RISK-01/02 (CRITICAL): Shadow mode cannot produce cheaper-model observations.** FR-7 passes the runtime default to the adapter, so every shadow `dispatch_usage` record has `model_used=<premium>`. The flip-readiness gate (FR-8) compares the premium model's pass rate against itself, stratified by class. The Constitution Check claim that shadow mode "is the embodiment of Principle II (Evidence Before Claims)" is structurally false as written. **Two mitigation options** (discuss must pick one): (A) recharacterize shadow mode as a **classifier-calibration** gate (not a model-equivalence gate) and rewrite FR-8 + the Constitution Check accordingly; (B) add a **5% canary** where mechanical-classified tasks are actually dispatched to the cheap model during shadow, producing real cheaper-model observations. (Source: red-advocate/disputes.md RISK-01, RISK-02; Blue conceded both.)

- **#Q-A2 — RISK-03 (HIGH): Flip-activation path is unspecified and programmatically unenforced.** FR-9 reads in passive voice ("when shadow corpus passes the flip-readiness check") with no specified code path that re-validates the corpus before honoring `model_routing.live: true`. An operator can edit config directly and bypass any check. **Required amendment** (FR-9): "`dispatch-interface.sh` MUST invoke `shadow-compare.sh` before the first live-routed dispatch in any session where `model_routing.live: true`. If `shadow-compare.sh` returns `evidence_insufficient`, dispatch-interface.sh MUST refuse to proceed with live routing and write `override_source=shadow_gate_blocked` to JSONL." Add corresponding negative SC. (Source: RISK-03; Blue conceded.)

- **#Q-A3 — RISK-04 (HIGH): 50-per-class threshold likely unsatisfiable before launch.** Remaining roadmap is 7 milestones × 4-6 phases ≈ 28-42 total dispatches; the `novel` class is structurally rare. The binary all-classes-or-nothing flip gate may permanently lock M030's value in shadow. **Required amendment** (FR-8): add a `partially_ready` verdict — "If ≥2 of 3 classes meet the 50-dispatch threshold and the under-threshold class's routing-table default is `smart`, return `flip_recommendation=partially_ready` with an enumerated list of flippable classes." JSONL records `partial_flip_active=true` and `withheld_classes=<list>`. (Source: RISK-04; Blue conceded.)

- **#Q-A4 — RISK-05 (HIGH, ARBITER-RULED): SC-10 ground-truth corpus independence must be in spec text, not deferred.** The arbiter accepted Red's position and rejected Blue's "delegate to plan-phase" defense. Promoting Q-1 from open question to spec constraint. **Required amendment** (SC-10 + Q-1 promoted): "The fixture corpus MUST be drawn from pre-existing PLAN.md files in `specs/0NN-*/` with hand-applied labels recorded in a version-controlled fixture file. The fixture file commit timestamp MUST precede the first commit of `classify-task.sh`." Grounding: Principle II mechanical-gate requirement, Principle III uncertainty-surfacing. (Source: arbiter/resolution.md.)

- **#Q-A5 — RISK-06 (MEDIUM): Kill switch + `min_tier` floor interaction is contradictory.** CON-4 says kill switch "MUST disable the entire routing layer regardless of any other config"; US-4 AS-2 says `min_tier: smart` ensures `model_used` is at least `smart`. These cannot both hold. CC-only launch makes this latent (runtime default IS `smart`), but two conforming implementations will diverge. **Required amendment** (CON-4): "The kill switch supersedes `min_tier`. When `model_routing_enabled: false` is active alongside an active `min_tier`, `override_source=disabled` is recorded and a one-line stderr warning names the bypassed `min_tier` value." Add compound test case to SC-7. (Source: RISK-06; Blue partially conceded.)

- **#Q-A6 — RISK-08 (MEDIUM): Cost counterfactual has no specified rate source.** US-5 promises "$0.42 vs $1.89 if all-smart" but no FR specifies where per-tier token costs live. **Required amendment** (FR-3): add `cost_rates:` section to `templates/model-routing.yml` with per-symbolic-tier input/output costs per million tokens. Document update obligation in `references/model-routing.md`. Extend SC-8 to verify the savings line appears when `cost_rates` is defined. (Source: RISK-08; Blue conceded.)

- **#Q-A7 — RISK-09 (MEDIUM): Shadow corpus write-path correctness is unverified.** CON-6 ensures append-only/immutability but not that the initial write is correct. A bug writing `model_routed=smart` for all tasks would produce a circular shadow corpus that satisfies the flip gate trivially. **Required amendment** (add SC-3a): "For each record in the shadow-mode fixture corpus, `jq -r '.model_routed'` matches the stdout of `bash scripts/dispatch/classify-task.sh <plan-path>` run independently on the same plan." (Source: RISK-09; Blue partially conceded.)

- **#Q-A8 — RISK-10 (MEDIUM, NEW IN CROSS-REVIEW): `min_tier` is not a substitute for partial-class flip authorization.** Future planners reading old reviews may misinterpret `min_tier: smart` as a partial-flip mechanism for the under-threshold class. It isn't — it bypasses the routing layer entirely. **Required amendment** (FR-12 documentation note): "`min_tier` is not a substitute for an unvalidated class in a partial flip — it routes unconditionally at the floor without engaging the shadow corpus or flip-readiness check." (Source: red-advocate cross-review NEW-01.)

**Accepted-with-monitoring** (no spec amendment required, but plan-phase should document the convention):
- **RISK-07** — anomaly JSONL state mutation between classifier invocations creates cross-dispatch inconsistency. Document the snapshot convention (e.g., classifier reads anomaly JSONL once at session start) in FR-2 prose, or explicitly disclaim per-run consistency.

**Threats withdrawn during deliberation**: THREAT-07 (SC-4 fixture model-capability dependence — Blue defended successfully), THREAT-10 (Cursor `inherit` records — withdrawn under CC-only launch posture), THREAT-11 (kill switch leaves classifier running — intentional design).

## Dependencies

- **D-1**: M019 Tier 1+2+3 — cost-rollup JSONL stream is the empirical foundation.
- **D-2**: M027 — cost+quality observability surfaces (`metrics-rollup.sh`, `efficiency-footer.sh`, `check-anomalies.sh`, `doctor.sh`) are extended (additive only) by M030.
- **D-3**: M025 — installer coexistence + `.orchestrator/config.yml` overlay convention.
- **D-4**: M028 — autonomous hardening v3 stabilizes runs whose JSONL feeds the shadow corpus.

## Downstream Consumers (informational, not binding)

- **DC-1 (M010 Managed Agents)**: When M010 lands its model abstraction, M030's routing table provides the policy layer M010 needs.
- **DC-2 (M023 design layer)**: Design tasks in M023 should annotate `min_tier: smart` (or `model_override: smart`) to prevent inappropriate downgrade.
- **DC-3 (M031 right-sized entry)**: M031's middle-flow restoration may want to default Quick-intensity tasks to `mechanical` classification when the orchestrator detects low-stakes dispatches; cross-link at plan-phase time.
- **DC-4 (M033 onboarding)**: First-run defaults should favor conservative routing (kill switch on, or shadow-only) until the user has built up enough shadow data; M033 plans the onboarding-flow integration.
