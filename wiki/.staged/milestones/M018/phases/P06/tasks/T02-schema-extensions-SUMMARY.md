---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P06"
milestone: "M018"
provides:
  - "additive `tier3_compression_savings_tokens` + `tier3_invocations` integer fields on payload_breakdown / dispatch_usage / unit_close JSONL records (CON-5); TIER3_SAVINGS + TIER3_INVOCS columns appended at indices 17-18 of the metrics-rollup.sh data row (back-compat preserved on cols 1-12 + 13-16); efficiency-footer.sh compression-line numerator widened to filter+tier1+tier2+tier3; check-anomalies.sh per-row sav_total widened with tier3_compression_savings_tokens; pinned column-index contract retrofit on m018-p05-cost-rollup-savings-columns.sh (absolute indices replacing fragile NF-relative reads)"
requires:
  - "from:M018/P06/T01 what:_bc_apply_tier3 helper writes savings_tokens=<N> invocations=<M> to TMPDIR_BUILD/_tier3_stats.txt as first action; from:M018/P05/T01 what:_di_rollup_savings_fields/_ws_rollup_savings_fields rollup-helper shape (extended to six integers); from:M018/P05/T02 what:metrics-rollup.sh column-projection awk pass + efficiency-footer.sh + check-anomalies.sh shape (extended additively)"
affects:
  - "P06/T03 (compression-eval.sh --tier 3 reads tier3_compression_savings_tokens from the new payload_breakdown field this task writes); P06/T04 (canonical truth verifier m018-p06-tier3-additivity.sh asserts the additive fields end-to-end against fixture logs); M027 future surfaces (consume the additive savings fields with no further changes — rollup column-index contract pinned at 1-12 + 13-16 + 17-18); M019 cost+token transparency surfaces (dispatch_usage / unit_close additive fields are the contract M019 surfaces read)"
key_files:
  - "scripts/dispatch/build-context.sh;scripts/dispatch/dispatch-interface.sh;scripts/knowledge/write-summary.sh;scripts/diagnostics/metrics-rollup.sh;scripts/diagnostics/efficiency-footer.sh;scripts/diagnostics/check-anomalies.sh;scripts/verify/m018-p05-cost-rollup-savings-columns.sh"
key_decisions:
  - "Field placement: tier3_compression_savings_tokens + tier3_invocations placed AFTER tier2_savings_tokens / tier1_invocations and BEFORE the model/source/timestamp triplet on payload_breakdown / dispatch_usage / unit_close — preserves every prior field position so existing JSONL consumers see no shift (CON-5 byte-identity carry-forward); rollup column-index contract: TIER3_SAVINGS + TIER3_INVOCS appended at absolute indices 17-18 (cols 1-12 + 13-16 byte-identical); MEM004 emitter-internal carve-out extends to the six widened helpers; co-located dispatch_usage emitter (_bc_emit_dispatch_usage_colocated) NOT widened — never carried the four P05 fields either; staying consistent with P05 posture; m018-p05-cost-rollup-savings-columns.sh retrofit from $(NF-3)..$NF to absolute $13..$16 because the pinned column-index contract IS the back-compat invariant, and NF-relative reads were a fragile choice not the contract"
patterns_established:
  - "Schema-extension carve-out reuse pattern: when an additive emitter has an in-flight rollup helper (T01-style _di_rollup_savings_fields / _ws_rollup_savings_fields), extending it with N more fields is a 4-step recipe (1: extend awk BEGIN initializer + per-record match() + END printf with N more accumulators; 2: extend the calling sed -n line-extraction with N more positional reads; 3: extend the emitter printf format string + value list; 4: leave defensive [-n] || var=0 fallback unchanged); rollup-source restriction carry-forward: metrics-rollup.sh / efficiency-footer.sh / check-anomalies.sh consume payload_breakdown rows ONLY for savings sums to avoid double-counting the rolled-up copies on dispatch_usage / unit_close; absolute column-index contract over NF-relative indexing in shape verifiers — when a column-set will grow over time, anchor verifier reads to absolute positions, not offset-from-end"
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P06/tasks/T02-schema-extensions-PAYLOAD.md;.orchestrator/milestones/M018/phases/P06/tasks/T02-schema-extensions-PLAN.md;.orchestrator/milestones/M018/phases/P06/tasks/T01-tier3-helper-SUMMARY.md;.orchestrator/milestones/M018/phases/P05/tasks/T01-schema-extensions-SUMMARY.md"
duration: "~1h"
verification_result: "pass"
completed_at: "2026-04-28T14:19:11Z"
---

T02 ships the additive schema-extension production code for Tier 3 auto-compact observability — wires `_tier3_stats.txt` (T01) through every JSONL emitter and rollup-helper surface that consumes the payload_breakdown ground truth. Verifiers / fixtures / dual-write land in T04.

Verification (Tier 1 must-haves per task plan + smoke harness against the merged build-context.sh):

- `bash -n scripts/dispatch/build-context.sh` — clean exit 0.
- `bash -n scripts/dispatch/dispatch-interface.sh` — clean exit 0.
- `bash -n scripts/knowledge/write-summary.sh` — clean exit 0.
- `bash -n scripts/diagnostics/metrics-rollup.sh` — clean exit 0.
- `bash -n scripts/diagnostics/efficiency-footer.sh` — clean exit 0.
- `bash -n scripts/diagnostics/check-anomalies.sh` — clean exit 0.
- E2E smoke (write-summary phase against fixture with two payload_breakdown rows carrying tier3_compression_savings_tokens=200,75 and tier3_invocations=1,1): unit_close record carries tier3_compression_savings_tokens=275 and tier3_invocations=2 rolled up granularity-aware (phase scope), and ALL four P05 fields preserved at expected sums.
- E2E rollup smoke (metrics-rollup.sh --milestone M999 against the same fixture): TIER3_SAVINGS=275 and TIER3_INVOCS=2 columns appended after the four P05 columns; columns 1-12 + 13-16 byte-identical for back-compat consumers.
- efficiency-footer awk smoke (synthetic 18-column data row): compression-line numerator includes tier3_savings; label updated to `filter+tier1+tier2+tier3 / payload_tokens`. Both normal and `(N missing)` shifted layouts compute correctly.
- check-anomalies awk smoke (synthetic data row): sav_total folds tier3 (200/1000=0.200 < 0.347 floor flags compression-regression; 400/1000=0.400 above floor does NOT flag). Suppression matrix preserved.
- Pre-existing P05 verifiers (m018-p05-dispatch-usage-additivity.sh, m018-p05-unit-close-additivity.sh, m018-p05-cost-rollup-savings-columns.sh, m018-p05-efficiency-footer-compression.sh, m018-p05-doctor-compression-regression.sh, m018-p05-compression-eval.sh) all PASS — no regression.

Truths addressed (subset per task plan): #3 (`payload_breakdown` / `dispatch_usage` / `unit_close` carry additive `tier3_compression_savings_tokens` + `tier3_invocations` fields; pre-P06 records remain valid JSON; CON-5). Truths #1, #2, #4, #5 are T01/T03/T04 scope.

Gotchas worth surfacing for downstream tasks:

1. The `_bc_emit_dispatch_usage_colocated` co-located emitter in build-context.sh was NOT widened — it never carried the four P05 fields either. The plan called for parity but P05 did not add them; staying consistent here. The canonical dispatch_usage emitter (`_di_emit_dispatch_usage` in dispatch-interface.sh) IS the carrier of the rolled-up savings fields. T04 verifier should target the dispatch-interface emit, not the colocated emit.

2. metrics-rollup.sh now emits 18 columns. The previous P05 verifier `m018-p05-cost-rollup-savings-columns.sh` was indexing from the END (`$(NF-3)..$NF`) — fragile under T02's append. Updated it in-place to use absolute column indices `$13..$16` per the pinned column-index contract (P05-SUMMARY: "1-12 stable; 13-16 are the M018 savings columns"). T04 should similarly use absolute indices `$17..$18` for tier3.

3. efficiency-footer.sh and check-anomalies.sh both detect the `(N missing)` cost-cell shift via `$5 ~ /^\(/` and switch column reads accordingly. Tier3 is at col 17 (normal) / col 19 (shifted). The label was widened to `filter+tier1+tier2+tier3 / payload_tokens` to surface that tier3 contributes to the numerator.

4. CON-5 additivity audit: payload_breakdown printf widened with two new fields placed AFTER `tier2_savings_tokens` and BEFORE `model`/`source`/`timestamp`. Same placement on dispatch_usage and unit_close. All prior column positions byte-identical for pre-M018 consumers; absent fields default to 0 in awk-based downstream rollups.

5. MEM004 emitter-internal carve-out: pipes / awk / `$()` permitted inside emitter / rollup-helper bodies. Only the Check: lines need single-script-file shape (AD-19 / AP-009). All six modifications stay within MEM004 carve-out.

6. Bash 3.2 (MEM001): no `declare -A`; parallel scalars / indexed accumulators only. All six modified scripts pass bash -n.

7. Pre-existing environmental issue (NOT a T02 regression): `find-active-milestone.sh` hangs when invoked outside an explicit milestone context against the live `.orchestrator/`. This causes `m018-p05-compression-eval-shape.sh` to hang on assertions 6+ when MILESTONE auto-resolution fails to short-circuit. Reproduces against the pristine pre-T02 codebase. Out of scope for T02 — flag for downstream investigation.
