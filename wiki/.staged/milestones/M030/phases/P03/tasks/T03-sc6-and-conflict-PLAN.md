---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M030"
name: "SC-6 frontmatter override + FR-14 override conflict + references/model-routing.md operator-overrides docs"
depends_on: ["T02"]
---

## Prerequisites

- All T02 deliverables on disk and green (per `bash tools/verify/p03-sc7-kill-switch.sh && bash tools/verify/p03-sc7a-compound.sh && bash tools/verify/p03-min-tier-floor.sh && bash tools/verify/p03-con3-closure.sh` — all four exit 0).
- scripts/dispatch/dispatch-interface.sh exists in its post-T02 form: override-resolution block + `_di_tier_rank` helper + extended shadow-on printf format strings (with `,"override_source":"%s"` field).
- tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md exists (T01).
- tests/fixtures/m030-p03/plans/plan-frontmatter-fast-vs-floor.md exists (T01).
- tests/fixtures/m030-p03/configs/{config-baseline,config-with-min-tier-smart}.yml exist (T01).
- references/model-routing.md exists in its post-P01 form (P01/T03 close — Routing Table, Per-Runtime Resolution, Cost Rates SSOT, Aggressive Overlay, Classifier-Confidence Stability Metric, See Also sections present).

Plan-time prerequisite-existence verification: every path above is asserted by T01/T02 close.

## Description

T03 closes the remaining override semantics:

1. **SC-6** — plain plan-frontmatter override raises the tier above the classifier's choice. The verifier stages `plan-with-frontmatter-override.md` (frontmatter `model_override: smart`, body mechanical) plus `config-baseline.yml` (no overlay), runs the round-trip, asserts `override_source=plan_frontmatter` AND `model_routed=smart` AND `model_used` matches `templates/model-routing.yml resolution.smart.claude-code` (i.e., `claude-opus-4-7`). Independently re-runs the classifier on the same plan and asserts `character=mechanical, confidence=high` — proves the override actually changed the routed tier.

2. **FR-14 override-conflict** — when plan-frontmatter override AND milestone min_tier disagree, floor wins. The verifier stages `plan-frontmatter-fast-vs-floor.md` (frontmatter `model_override: fast`, body mechanical) plus `config-with-min-tier-smart.yml` (min_tier: smart), runs round-trip with stderr capture, asserts `override_source=milestone_floor` (NOT `plan_frontmatter`) AND `model_routed=smart` (raised from override `fast` to floor `smart`) AND stderr contains a one-line warning naming both `model_override` and `min_tier`.

3. **Operator-overrides documentation** — amend `references/model-routing.md` to add a new `## Operator Overrides` section (after `## Classifier-Confidence Stability Metric`, before `## See Also`). The section documents the four-step precedence chain in operator-facing prose:

   - Kill switch (`model_routing_enabled: false` at config root) supersedes everything → `override_source=disabled`.
   - Plan frontmatter (`model_override: <tier>` in PLAN.md) → `override_source=plan_frontmatter`.
   - Milestone floor (`model_routing.min_tier: <tier>` in `.orchestrator/config.yml`) → `override_source=milestone_floor`.
   - Plain routed (no overrides active) → `override_source=none`.

   Plus the two compound-warning cases:

   - Kill switch + min_tier active simultaneously → kill switch wins; stderr emits `model_routing_enabled=false: min_tier: <X> is inactive`.
   - Plan-frontmatter override + min_tier active simultaneously, with floor higher than override → floor wins; stderr emits `model_override=<X> overridden by min_tier=<Y> (floor wins)`.

The references doc edit is operator-facing and surfaces in `orchestrator:doctor --config-check` output (M030/P05 deliverable, but the docs land in P03 alongside the code).

## Steps

1. **Confirm T02 deliverables are on disk and green.** Run:

   ```bash
   bash tools/verify/p03-sc7-kill-switch.sh
   bash tools/verify/p03-sc7a-compound.sh
   bash tools/verify/p03-min-tier-floor.sh
   bash tools/verify/p03-con3-closure.sh
   bash tools/verify/p03-additive-schema.sh
   bash tools/verify/p03-override-source-enum.sh
   ```

   Expected: all six exit 0. If any fail, T02 must be re-opened.

2. **Author `tools/verify/p03-sc6-frontmatter-override.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Round-trip dispatch shape:

   - Stage a tmp `ORCH_ROOT` whose `.orchestrator/config.yml` is `tests/fixtures/m030-p03/configs/config-baseline.yml`.
   - Stage a fresh log file under `$ORCH_ROOT/milestones/M999/execution-log.jsonl`.
   - Independently classify the plan: `bash scripts/dispatch/classify-task.sh tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md > /tmp/p03-sc6-classifier.txt`. Assert the file contains `character=mechanical` (classifier sanity — proves the override actually changes the tier, not just rubber-stamps the classifier).
   - `export M030_SHADOW_MODE=1; export CLAUDECODE=1; export ORCHESTRATOR_ROOT="$ORCH_ROOT"`.
   - Invoke `bash scripts/dispatch/dispatch-interface.sh --task-plan tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md --payload tests/fixtures/m030-p03/round-trip-stage/payload.txt --intensity-metadata tests/fixtures/m030-p03/round-trip-stage/intensity-metadata.txt --backend stub`.
   - `tail -n 1 "$log_file" > /tmp/p03-sc6-line.txt`.
   - Assert `grep -q '"override_source":"plan_frontmatter"' /tmp/p03-sc6-line.txt`.
   - Assert `grep -q '"model_routed":"smart"' /tmp/p03-sc6-line.txt`.
   - Assert `grep -q '"model_used":"claude-opus-4-7"' /tmp/p03-sc6-line.txt` (the routing-table-resolved smart-tier model ID under claude-code; this assertion is allowed because the verifier reads `templates/model-routing.yml resolution.smart.claude-code` to derive the expected literal — the model ID does NOT appear hardcoded in the verifier's source). Use awk extraction on `templates/model-routing.yml` to read the expected literal and compose the grep pattern dynamically.
   - Cleanup: `rm -rf "$ORCH_ROOT" /tmp/p03-sc6-*.txt`.
   - Final `SUMMARY: p03-sc6-frontmatter-override.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

3. **Author `tools/verify/p03-override-conflict.sh`.** Bash 3.2-compatible. Round-trip with stderr capture:

   - Stage a tmp `ORCH_ROOT` whose `.orchestrator/config.yml` is `tests/fixtures/m030-p03/configs/config-with-min-tier-smart.yml`.
   - Stage a fresh log file.
   - `export M030_SHADOW_MODE=1; export CLAUDECODE=1; export ORCHESTRATOR_ROOT="$ORCH_ROOT"`.
   - Invoke `bash scripts/dispatch/dispatch-interface.sh --task-plan tests/fixtures/m030-p03/plans/plan-frontmatter-fast-vs-floor.md --payload tests/fixtures/m030-p03/round-trip-stage/payload.txt --intensity-metadata tests/fixtures/m030-p03/round-trip-stage/intensity-metadata.txt --backend stub 2> /tmp/p03-conflict-stderr.txt`.
   - `tail -n 1 "$log_file" > /tmp/p03-conflict-line.txt`.
   - Assert `grep -q '"override_source":"milestone_floor"' /tmp/p03-conflict-line.txt` (NOT `plan_frontmatter`).
   - Assert `grep -q '"model_routed":"smart"' /tmp/p03-conflict-line.txt` (raised from override `fast` to floor `smart`).
   - Assert `grep -q 'model_override=fast' /tmp/p03-conflict-stderr.txt` (warning names the original override).
   - Assert `grep -q 'min_tier=smart' /tmp/p03-conflict-stderr.txt` (warning names the floor).
   - Assert `grep -q 'floor wins' /tmp/p03-conflict-stderr.txt` (warning explicitly states the resolution).
   - Cleanup.
   - Final `SUMMARY: p03-override-conflict.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

4. **Amend `references/model-routing.md`.** Insert a new `## Operator Overrides` section AFTER the `## Classifier-Confidence Stability Metric` section and BEFORE the `## See Also` section. Section content:

   ```markdown
   ## Operator Overrides

   M030/P03 ships three operator-facing override knobs plus a kill switch.
   This section documents the precedence chain mechanically: knobs evaluate
   in the order below, the first match wins, downstream knobs are bypassed.
   The chain is implemented in `scripts/dispatch/dispatch-interface.sh`'s
   `_di_emit_dispatch_usage` body and is gated by the same `M030_SHADOW_MODE=1
   AND CLAUDECODE=1` envelope as the rest of the M030 shadow path.

   ### Precedence Chain

   1. **Kill switch** (`.orchestrator/config.yml` top-level
      `model_routing_enabled: false`) — disables the entire routing layer.
      Records `override_source=disabled`. The classifier still runs and
      `model_routed`/`classifier_confidence` are still emitted (the shadow
      corpus continues to grow), but the dispatched model falls back to the
      runtime default. **Kill switch supersedes `min_tier`** (CON-4/D-A5).
      When both are active, `override_source=disabled` is recorded and a
      one-line stderr warning names the bypassed value:

      ```
      model_routing_enabled=false: min_tier: smart is inactive
      ```

   2. **Plan frontmatter** (`PLAN.md` frontmatter
      `model_override: <symbolic-tier>`) — short-circuits classification.
      Records `override_source=plan_frontmatter`. The override value MUST be
      a closed-enum symbolic tier (`fast | balanced | smart`) — concrete
      model IDs in the override field are accepted but discouraged
      (operators pinning to a dated snapshot like `claude-haiku-4-5-20260101`
      should override under `model_routing.resolution_override:` in
      `.orchestrator/config.yml`, not in the plan).

   3. **Milestone floor** (`.orchestrator/config.yml`
      `model_routing.min_tier: <symbolic-tier>`) — raises the effective
      floor for every dispatch in the active milestone. Records
      `override_source=milestone_floor`. **Floor wins over plan
      frontmatter** when the floor is higher than the plan's override
      (FR-14). When this conflict fires, a one-line stderr warning names
      both knobs:

      ```
      model_override=fast overridden by min_tier=smart (floor wins)
      ```

   4. **Plain routed** (no overrides active) — the routing table runs as
      documented in the `## Routing Table` section above. Records
      `override_source=none`.

   ### override_source closed enum

   The JSONL `override_source` field is drawn from the closed set:

   | value                | trigger                                   |
   |----------------------|-------------------------------------------|
   | `disabled`           | kill switch active                        |
   | `plan_frontmatter`   | plan frontmatter `model_override:` set    |
   | `milestone_floor`    | `min_tier:` set (or floor-wins conflict)  |
   | `none`               | plain routed (no overrides)               |
   | `shadow_gate_blocked`| reserved for FR-9 live-flip refusal (P05) |

   `shadow_gate_blocked` is the FR-9 flip-readiness gate value emitted when
   `model_routing.live: true` is set without sufficient shadow corpus —
   M030/P05 ships the live-flip path; the value is reserved here so the
   closed enum is locked at P03 close.

   ### CC-only launch posture

   Override resolution requires `CLAUDECODE=1`. On Codex CLI / Cursor the
   override path short-circuits and `override_source` is not emitted (the
   shadow path itself is bypassed; record is byte-identical to pre-M030
   shape). M009 ships per-runtime override semantics demand-driven post-
   launch.
   ```

5. **Update `references/model-routing.md` `## See Also` section.** Add two new bullets at the end of the existing list:

   ```markdown
   - `tools/verify/p03-override-source-enum.sh` (M030/P03/T01) — the closed-
     enum gate verifying every shadow-on dispatch_usage record carries
     exactly one override_source field whose value is in the closed set.
   - [`.orchestrator/milestones/M030/M030-CONTEXT.md`](../../../../../milestones/M030/M030-CONTEXT.md) D-A5 — the binding
     decision establishing the kill-switch-supersedes-min_tier compound
     resolution amended into CON-4.
   ```

6. **Run all T03 verifiers as a self-check:**

   ```bash
   bash tools/verify/p03-sc6-frontmatter-override.sh
   bash tools/verify/p03-override-conflict.sh
   ```

   Expected: both exit 0.

   If `p03-sc6-frontmatter-override.sh` fails on the model_used assertion, the awk extraction of `templates/model-routing.yml resolution.smart.claude-code` is brittle — re-check the per-tier section walker pattern.

   If `p03-override-conflict.sh` fails on the stderr assertions, the FR-14 conflict warning is not firing — investigate `dispatch-interface.sh`'s plan-frontmatter precedence branch (Step 4 of T02): the floor-wins-over-plan check must emit the `model_override=<X> overridden by min_tier=<Y> (floor wins)` warning when `_floor_rank > _plan_rank`.

7. **Re-run all P03 sub-gates as a regression check.** T03's references-doc edit does not touch `dispatch-interface.sh`; T02's verifiers must continue to pass:

   ```bash
   bash tools/verify/p03-additive-schema.sh
   bash tools/verify/p03-override-source-enum.sh
   bash tools/verify/p03-sc7-kill-switch.sh
   bash tools/verify/p03-sc7a-compound.sh
   bash tools/verify/p03-min-tier-floor.sh
   bash tools/verify/p03-con3-closure.sh
   bash tools/verify/p03-sc6-frontmatter-override.sh
   bash tools/verify/p03-override-conflict.sh
   ```

   Expected: all eight exit 0.

8. **Stage and commit.** Stage `references/model-routing.md`, `tools/verify/p03-sc6-frontmatter-override.sh`, `tools/verify/p03-override-conflict.sh`. Author commit message file via Write to /tmp/p03-t03-commit-msg.txt; commit with `git commit -F /tmp/p03-t03-commit-msg.txt`. Recommended subject: `M030/P03/T03: SC-6 frontmatter override + FR-14 conflict + operator-overrides docs`.

## Must-Haves

This task satisfies the phase truths:

- "SC-6 holds: a PLAN.md whose frontmatter declares model_override: smart..." — gated by `tools/verify/p03-sc6-frontmatter-override.sh`.
- "Override-conflict (FR-14) resolution: when a plan declares model_override: fast..." — gated by `tools/verify/p03-override-conflict.sh`.

Plus the references-doc edit operationalizes the precedence chain in operator-facing prose (no truth gate — Tier 3 / behavioral; the gate lives in `tools/verify/p03-phase-suite.sh` ensuring all eight verifiers pass).

## Verification

```bash
bash tools/verify/p03-sc6-frontmatter-override.sh
bash tools/verify/p03-override-conflict.sh
```

Each verifier uses single-script-file shape per AD-19. Both must exit 0 before T03 closes.

## Inputs

### From Previous Tasks

- tests/fixtures/m030-p03/plans/plan-with-frontmatter-override.md (from T01) — Key API: plan with `model_override: smart` frontmatter + mechanical body. Classifier returns `character=mechanical`. Plan path encodes `M999/P99/T99`.
- tests/fixtures/m030-p03/plans/plan-frontmatter-fast-vs-floor.md (from T01) — Key API: plan with `model_override: fast` frontmatter + mechanical body. Classifier returns `character=mechanical`.
- tests/fixtures/m030-p03/configs/config-baseline.yml (from T01) — Key API: minimal config with no `model_routing` block. Triggers the `none` override_source path.
- tests/fixtures/m030-p03/configs/config-with-min-tier-smart.yml (from T01) — Key API: `model_routing.min_tier: smart` overlay. Triggers the `milestone_floor` path.
- tests/fixtures/m030-p03/round-trip-stage/{intensity-metadata.txt,payload.txt} (from T01) — Key API: round-trip dispatch fixtures.
- scripts/dispatch/dispatch-interface.sh (post-T02) — Key API: `_di_emit_dispatch_usage` body with override-resolution path emitting `override_source` JSONL field. Plan-frontmatter case sets `shadow_routed=<plan-override-value>`, `override_source=plan_frontmatter`. Floor-wins-conflict case re-sets to `milestone_floor` with stderr warning.
- tools/verify/p03-additive-schema.sh, p03-override-source-enum.sh (from T01); p03-sc7-kill-switch.sh, p03-sc7a-compound.sh, p03-min-tier-floor.sh, p03-con3-closure.sh (from T02) — Key API: each `bash <path>` exits 0 with `SUMMARY:` line; pass-counts vary per sub-gate.

### From Disk (Pre-existing)

- references/model-routing.md (pre-T03) — operator reference doc with five sections (Routing Table, Per-Runtime Resolution, Cost Rates SSOT, Aggressive Overlay, Classifier-Confidence Stability Metric, See Also). T03 inserts the `## Operator Overrides` section between Stability Metric and See Also.
- templates/model-routing.yml — P01 routing-table SSOT. T03's SC-6 verifier reads `resolution.smart.claude-code` to derive the expected `model_used` literal dynamically (CON-3 — verifier doesn't hardcode the model ID).
- scripts/dispatch/classify-task.sh — P01 classifier. T03's SC-6 verifier invokes it independently to assert `character=mechanical`.
- scripts/dispatch/adapters/backend/stub.sh — minimal adapter for round-trip dispatch invocations.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`.
- **AP-009 compound-chain-gt2 (verifier shape)**: T03 verifiers MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates.
- **CON-3 (no hardcoded model IDs in verifiers)**: T03's `p03-sc6-frontmatter-override.sh` does NOT embed the literal `claude-opus-4-7` in its source — it reads the value from `templates/model-routing.yml resolution.smart.claude-code` at runtime via awk extraction. Same pattern as P02/T03's stability-metric SSOT consumption.
- **References-doc shape**: the new `## Operator Overrides` section MUST be inserted between `## Classifier-Confidence Stability Metric` and `## See Also`. Other sections are NOT modified except for the See Also bullet additions in Step 5.
- **CC-only launch posture**: T03's verifiers run shadow-on (CLAUDECODE=1, M030_SHADOW_MODE=1). The references-doc Operator-Overrides section names the CC-only constraint explicitly.
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. Verifier helper functions use `case` and parallel-indexed arrays.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T03 introduces no SQL — N/A.

## Expected Output

- `tools/verify/p03-sc6-frontmatter-override.sh` — green: SC-6 contract holds (override_source=plan_frontmatter, model_routed=smart, model_used=routing-table-resolved smart literal).
- `tools/verify/p03-override-conflict.sh` — green: FR-14 contract holds (floor wins, stderr warns naming both knobs).
- `references/model-routing.md` — amended with new `## Operator Overrides` section (between Stability Metric and See Also) + two new See Also bullets.
- `bash tools/verify/p03-sc6-frontmatter-override.sh` exits 0 with `SUMMARY: p03-sc6-frontmatter-override.sh pass=4 fail=0` (classifier sanity + override_source + model_routed + model_used).
- `bash tools/verify/p03-override-conflict.sh` exits 0 with `SUMMARY: p03-override-conflict.sh pass=5 fail=0` (override_source + model_routed + 3 stderr greps).
- All other P03 sub-gates (T01/T02 deliverables) continue to exit 0 — T03 introduces no regressions.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p03-sc6-frontmatter-override.sh` -> 4 assertions pass; `SUMMARY: p03-sc6-frontmatter-override.sh pass=4 fail=0`, exit 0.
- `bash tools/verify/p03-override-conflict.sh` -> 5 assertions pass; `SUMMARY: p03-override-conflict.sh pass=5 fail=0`, exit 0.

The references-doc `## Operator Overrides` section is the load-bearing operator-facing surface for the M030/P03 chain. Future readers ([M035](../../../../../milestones/M035/index.md) install-bundle distributors, downstream consumers running `orchestrator:doctor --config-check`) will encounter the chain semantics through this section before encountering the JSONL or the dispatch-interface code. Keeping the four-step chain explicit AND the two compound-warning cases explicit AND the closed enum table explicit means a misconfigured `.orchestrator/config.yml` is debuggable from the doc alone.

The decision to land the references-doc edit in P03 (alongside the code) rather than in M030/P05 (alongside `doctor --config-check`) is deliberate: the precedence chain is operator-visible the moment T02 ships. Deferring the doc to P05 would leave a cycle where operators see `override_source=disabled` in JSONL with no mechanical surface explaining the precedence. P03 closes the loop.

If a downstream consumer reports that the `## Operator Overrides` section's compound-warning examples drift from the actual stderr output (e.g., the warning-line shape changes in a future amendment), the references doc IS the SSOT — the dispatch-interface amendment must be re-aligned. The references-doc edit precedes the warning-line authorship in the precedence chain even though they ship in the same milestone phase.
