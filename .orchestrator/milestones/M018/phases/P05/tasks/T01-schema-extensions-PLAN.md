---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M018"
name: "Schema extensions on dispatch_usage + unit_close — additive filter_dropped_tokens / tier1_savings_tokens / tier2_savings_tokens / tier1_invocations integer fields rolled up from payload_breakdown at emit-time"
depends_on: []
---

## Prerequisites

- P02, P03, and P04 have shipped the upstream additive fields on `payload_breakdown` JSONL records emitted by `_bc_emit_payload_breakdown` in `scripts/dispatch/build-context.sh`. The four fields T01 rolls up are:
  - `filter_dropped_tokens` (integer; from P02 — knowledge filter)
  - `tier1_savings_tokens` (integer; from P03 — Tier 1 paging)
  - `tier1_invocations` (integer; from P03 — Tier 1 paging)
  - `tier2_savings_tokens` (integer; from P04 — Tier 2 head-drop)
  Each field is already present on every post-P04 `payload_breakdown` record. Pre-P02 records have none of these fields. Missing fields default to 0 in rollups (CON-5).
- `scripts/dispatch/dispatch-interface.sh` carries the existing `_di_emit_dispatch_usage` function at lines ~141–245. The function emits exactly one `dispatch_usage` JSONL record per dispatch invocation. Two emit branches: happy-path (line ~220) and pricing-degradation (line ~232). The record is appended to `<log_dir>/execution-log.jsonl` where `<log_dir>` is `$ORCH_ROOT` (when it contains a `phases/` subdir) or `$ORCH_ROOT/milestones/$MILESTONE_ID` otherwise.
- `scripts/knowledge/write-summary.sh` carries the existing `_ws_emit_unit_close` function at lines ~263–444. The function emits exactly one `unit_close` JSONL record per task / phase / milestone summary write. The record is appended to `<log_dir>/execution-log.jsonl`. The function already aggregates `payload_breakdown` records to compute `verification_pass_rate` (via the awk pass at lines ~395–414) — T01 mirrors that pattern for the savings rollup.
- The `payload_breakdown` JSONL record carries `unitId`, `milestone`, `phase`, `task` fields (same shape as `dispatch_usage`). For dispatch_usage, the rollup matches on `unitId`. For unit_close, the rollup matches on the granularity-appropriate scope (task → milestone+phase+task; phase → milestone+phase; milestone → milestone).
- AP-009 (`scripts/hooks/pre-bash-shape-guard.sh`) bans: compound chains > 2; plain subshells; `$(...|...)` shell forms; process substitution. Bash 3.2 — no `declare -A`. T01 follows MEM004's emitter-internal carve-out: pipes, awk, and command substitution are permitted INSIDE the rollup helper functions because they are dispatch-internal emitters, not agent-facing payload bytes and not Check: commands. The carve-out is already documented at the top of `dispatch-interface.sh` and `write-summary.sh`.
- T01 does NOT modify `payload_breakdown` (already P02/P03/P04 work). T01 does NOT ship verifiers or fixtures (those are T04). T01 ships ONLY the production code that T04's verifiers exercise.

## Description

Land four additive integer fields on the `dispatch_usage` and `unit_close` JSONL records. The fields are:

- `filter_dropped_tokens` (sum of P02 knowledge-filter drops on the same unit / scope)
- `tier1_savings_tokens` (sum of P03 Tier 1 paging savings on the same unit / scope)
- `tier2_savings_tokens` (sum of P04 Tier 2 head-drop savings on the same unit / scope)
- `tier1_invocations` (sum of P03 Tier 1 invocation counts on the same unit / scope)

Both emitters compute the four integers by scanning the in-flight `execution-log.jsonl` for matching `payload_breakdown` records and summing the field values. For `dispatch_usage`, the match is on `unitId` (one or more `payload_breakdown` records may exist for the same unitId — typically one). For `unit_close`, the match is granularity-scoped: task → milestone+phase+task; phase → milestone+phase; milestone → milestone. Records lacking a field contribute 0.

The fields are additive per CON-5: pre-P05 records remain valid JSON; missing fields are treated as 0 by downstream consumers (`metrics-rollup.sh`, `efficiency-footer.sh`, `check-anomalies.sh`, `compression-eval.sh` — extended in T02 and T03 to read these fields with the absent-defaults-to-zero rule).

After T01:

1. Every `dispatch_usage` JSONL line emitted by `_di_emit_dispatch_usage` carries `"filter_dropped_tokens":<int>,"tier1_savings_tokens":<int>,"tier2_savings_tokens":<int>,"tier1_invocations":<int>` between the existing `pricing_version` and `model` (or `pricing_warning`) fields. Both emit branches (happy-path and pricing-degradation) carry the new fields.
2. Every `unit_close` JSONL line emitted by `_ws_emit_unit_close` carries the same four fields between the existing `retry_count` and `source` fields.
3. The pre-P05 fixture at `tests/fixtures/m018-p02-baseline-payload.golden.txt` (P02 disable-flag golden) is byte-identical against the post-T01 build-context.sh under `compression.enabled: false` — T01 does NOT touch build-context.sh. The golden contract is preserved through the principle that T01's emit-time rollup is a no-op when no in-scope `payload_breakdown` records exist (zero matches → all four fields = 0).
4. When `ORCH_M019_EMIT=0` (the existing test seam), the rollup helpers are not invoked — no log read, no field computation. The full emit-skip semantics already documented at `dispatch-interface.sh:148` carry forward unchanged.

T01 ships ONLY:

- The two rollup helper functions (`_di_rollup_savings_fields` in dispatch-interface.sh; `_ws_rollup_savings_fields` in write-summary.sh).
- The four additive fields on the printf format strings of both emit branches in each emitter.
- The two new field bindings (`filter_dropped`, `tier1_savings`, `tier2_savings`, `tier1_invocs`) in each emitter scope.

T01 does NOT ship:

- Verifiers, fixtures, fixture-staging helper, P05-SUMMARY, dual-write (those are T04).
- `metrics-rollup.sh` / `efficiency-footer.sh` / `check-anomalies.sh` extensions (those are T02).
- `compression-eval.sh` (T03).

## Inputs

- `scripts/dispatch/dispatch-interface.sh` — read existing `_di_emit_dispatch_usage` (lines ~141–245). The two printf format strings to extend are at lines ~220 (happy-path) and ~232 (degradation). The log_file resolution is at lines ~198–205 — T01's rollup helper reuses the same `$log_file` value. The ORCH_M019_EMIT=0 short-circuit at line 148 fences the helper.
- `scripts/knowledge/write-summary.sh` — read existing `_ws_emit_unit_close` (lines ~263–444). The printf format is at line ~434. The existing `verification_pass_rate` aggregation awk pass at lines ~395–414 is the canonical shape T01 mirrors for the savings rollup. The log_file resolution is at lines ~430–432.
- `scripts/dispatch/build-context.sh:_bc_emit_payload_breakdown` — read for the existing `payload_breakdown` JSONL field shape so T01's rollup helpers extract the right field names. The four field names T01 reads are exactly: `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier1_invocations`. They appear unquoted (integer values) on each `payload_breakdown` line.
- `scripts/util/json-field.sh` (optional) — exposes `json_field()` for JSON field extraction, but T01 prefers a direct `sed -n -E` extractor co-located with the rollup helper to avoid sourcing dependencies. The `sed` extractor pattern matching `metrics_rollup.sh`'s `_metrics_rollup_field_num` (lines ~109–113 of `scripts/diagnostics/metrics-rollup.sh`) is the reference shape.

## Steps

### Step 1 — Add `_di_rollup_savings_fields` to `scripts/dispatch/dispatch-interface.sh`

Insert the helper function immediately above `_di_emit_dispatch_usage` (around line 140). The helper signature, contract, and body:

```bash
# --- M018/P05/T01: dispatch_usage savings-field rollup ---
# Reads the same-unitId payload_breakdown record(s) from the in-flight log
# file and emits four integers on stdout (one per line, in order):
#   filter_dropped_tokens, tier1_savings_tokens, tier2_savings_tokens, tier1_invocations
# Records lacking a field contribute 0. Multiple matching records sum.
# Bail-safe: missing log file or zero matches emits "0\n0\n0\n0\n".
# MEM004 emitter-internal carve-out — pipes/awk/$() permitted in body.
_di_rollup_savings_fields() {
  local log_file="$1"
  local unit_id="$2"
  if [ -z "$log_file" ] || [ ! -f "$log_file" ] || [ -z "$unit_id" ]; then
    printf '0\n0\n0\n0\n'
    return 0
  fi
  # Match payload_breakdown records on unitId; sum each savings field.
  # Tolerates absent fields (treated as 0) per CON-5.
  awk -v uid="$unit_id" '
    BEGIN { fdrop = 0; t1s = 0; t2s = 0; t1i = 0 }
    /"record_type":"payload_breakdown"/ {
      if (index($0, "\"unitId\":\"" uid "\"") == 0) next
      if (match($0, /"filter_dropped_tokens":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); fdrop += v + 0
      }
      if (match($0, /"tier1_savings_tokens":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t1s += v + 0
      }
      if (match($0, /"tier2_savings_tokens":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t2s += v + 0
      }
      if (match($0, /"tier1_invocations":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t1i += v + 0
      }
    }
    END { printf "%d\n%d\n%d\n%d\n", fdrop, t1s, t2s, t1i }
  ' "$log_file" 2>/dev/null || printf '0\n0\n0\n0\n'
}
```

The helper is purely read-only against the log file; it never appends or rewrites. Multiple `payload_breakdown` records for the same `unitId` (an edge case but documented in P02/P03/P04) sum.

### Step 2 — Wire the rollup into `_di_emit_dispatch_usage`

Inside `_di_emit_dispatch_usage`, after `log_file="$log_dir/execution-log.jsonl"` (line ~205) and before the existing `mkdir -p` (line ~207), capture the four integers:

```bash
  # M018/P05/T01: roll up the same-unitId payload_breakdown savings fields.
  # Reads from the in-flight log; missing log / zero matches → all zeros.
  local _di_savings _di_filter_dropped _di_tier1_savings _di_tier2_savings _di_tier1_invocs
  _di_savings="$(_di_rollup_savings_fields "$log_file" "$UNIT_ID")"
  _di_filter_dropped="$(printf '%s\n' "$_di_savings" | sed -n '1p')"
  _di_tier1_savings="$(printf '%s\n' "$_di_savings" | sed -n '2p')"
  _di_tier2_savings="$(printf '%s\n' "$_di_savings" | sed -n '3p')"
  _di_tier1_invocs="$(printf '%s\n' "$_di_savings" | sed -n '4p')"
  # Defensive defaulting — never trust a malformed helper return.
  [ -n "$_di_filter_dropped" ] || _di_filter_dropped=0
  [ -n "$_di_tier1_savings" ] || _di_tier1_savings=0
  [ -n "$_di_tier2_savings" ] || _di_tier2_savings=0
  [ -n "$_di_tier1_invocs" ] || _di_tier1_invocs=0
```

### Step 3 — Extend the two printf format strings in `_di_emit_dispatch_usage`

Modify the happy-path printf (line ~220) by adding the four fields between `"pricing_version":"%s"` and `"model":"%s"`:

```bash
    printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"%s","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":%s,"pricing_version":"%s","filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier2_savings_tokens":%d,"tier1_invocations":%d,"model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s"}\n' \
      "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$BACKEND" \
      "$input_tokens" "$output_tokens" "$cost_usd" \
      "$pricing_version" \
      "$_di_filter_dropped" "$_di_tier1_savings" "$_di_tier2_savings" "$_di_tier1_invocs" \
      "$model" "$ts" \
      >> "$log_file" 2>/dev/null || {
      printf 'dispatch-interface.sh: dispatch_usage append failed on %s\n' "$log_file" >&2
      return 0
    }
```

Same shape for the degradation printf (line ~232) — insert the four `%d` slots in the same position (between `"pricing_version":"%s"` and `"pricing_warning":"%s"`):

```bash
    printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"%s","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":null,"pricing_version":"%s","filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier2_savings_tokens":%d,"tier1_invocations":%d,"pricing_warning":"%s","model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s"}\n' \
      "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$BACKEND" \
      "$input_tokens" "$output_tokens" \
      "$pricing_version" \
      "$_di_filter_dropped" "$_di_tier1_savings" "$_di_tier2_savings" "$_di_tier1_invocs" \
      "$escaped_warning" "$model" "$ts" \
      >> "$log_file" 2>/dev/null || {
      printf 'dispatch-interface.sh: dispatch_usage append failed on %s\n' "$log_file" >&2
      return 0
    }
```

### Step 4 — Add `_ws_rollup_savings_fields` to `scripts/knowledge/write-summary.sh`

Insert the helper function above `_ws_emit_unit_close` (around line 260). Same algorithmic shape as `_di_rollup_savings_fields`, but the scope match is granularity-aware. Signature:

```bash
# --- M018/P05/T01: unit_close savings-field rollup ---
# Reads the in-scope payload_breakdown record(s) from the log file and
# emits four integers on stdout (one per line, in order):
#   filter_dropped_tokens, tier1_savings_tokens, tier2_savings_tokens, tier1_invocations
# Scope match by granularity:
#   task: milestone == M && phase == P && task == T
#   phase: milestone == M && phase == P
#   milestone: milestone == M
# Records lacking a field contribute 0. Bail-safe: missing log → all zeros.
# MEM004 emitter-internal carve-out — pipes/awk/$() permitted in body.
_ws_rollup_savings_fields() {
  local log_file="$1"
  local granularity="$2"
  local milestone="$3"
  local phase="$4"
  local task="$5"
  if [ -z "$log_file" ] || [ ! -f "$log_file" ]; then
    printf '0\n0\n0\n0\n'
    return 0
  fi
  awk -v g="$granularity" -v m="$milestone" -v p="$phase" -v t="$task" '
    BEGIN { fdrop = 0; t1s = 0; t2s = 0; t1i = 0 }
    /"record_type":"payload_breakdown"/ {
      if (m != "" && index($0, "\"milestone\":\"" m "\"") == 0) next
      if (g == "phase" || g == "task") {
        if (p != "" && index($0, "\"phase\":\"" p "\"") == 0) next
      }
      if (g == "task") {
        if (t != "" && index($0, "\"task\":\"" t "\"") == 0) next
      }
      if (match($0, /"filter_dropped_tokens":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); fdrop += v + 0
      }
      if (match($0, /"tier1_savings_tokens":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t1s += v + 0
      }
      if (match($0, /"tier2_savings_tokens":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t2s += v + 0
      }
      if (match($0, /"tier1_invocations":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t1i += v + 0
      }
    }
    END { printf "%d\n%d\n%d\n%d\n", fdrop, t1s, t2s, t1i }
  ' "$log_file" 2>/dev/null || printf '0\n0\n0\n0\n'
}
```

### Step 5 — Wire the rollup into `_ws_emit_unit_close`

Inside `_ws_emit_unit_close`, after `mkdir -p "$log_dir" 2>/dev/null || return 0` (line ~432) and before the printf (line ~434), capture the four integers:

```bash
  # M018/P05/T01: roll up the in-scope payload_breakdown savings fields.
  local _ws_savings _ws_filter_dropped _ws_tier1_savings _ws_tier2_savings _ws_tier1_invocs
  _ws_savings="$(_ws_rollup_savings_fields "$log_file" "$granularity" "$milestone_arg" "$phase_arg" "$task_arg")"
  _ws_filter_dropped="$(printf '%s\n' "$_ws_savings" | sed -n '1p')"
  _ws_tier1_savings="$(printf '%s\n' "$_ws_savings" | sed -n '2p')"
  _ws_tier2_savings="$(printf '%s\n' "$_ws_savings" | sed -n '3p')"
  _ws_tier1_invocs="$(printf '%s\n' "$_ws_savings" | sed -n '4p')"
  [ -n "$_ws_filter_dropped" ] || _ws_filter_dropped=0
  [ -n "$_ws_tier1_savings" ] || _ws_tier1_savings=0
  [ -n "$_ws_tier2_savings" ] || _ws_tier2_savings=0
  [ -n "$_ws_tier1_invocs" ] || _ws_tier1_invocs=0
```

### Step 6 — Extend the printf in `_ws_emit_unit_close`

Modify the printf format (line ~434) by inserting the four `%d` slots between `"retry_count":%d` and `"source":"%s"`:

```bash
  printf '{"record_type":"unit_close","granularity":"%s","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","duration_s":%d,"outcome":"%s","completed_at":"%s","estimated_cost_usd":%s,"pricing_version":"%s","verification_pass_rate":%s,"deviation_count":%d,"retry_count":%d,"filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier2_savings_tokens":%d,"tier1_invocations":%d,"source":"%s","timestamp":"%s"}\n' \
    "$granularity" "$unit_id" \
    "$milestone_arg" "$phase_arg" "$task_arg" \
    "$duration_s" "$outcome" "$completed_at_arg" \
    "$cost_field" "$pricing_version" \
    "$pass_rate" "$deviation_count" "$retry_count" \
    "$_ws_filter_dropped" "$_ws_tier1_savings" "$_ws_tier2_savings" "$_ws_tier1_invocs" \
    "$src" "$ts" \
    >> "$log_file" 2>/dev/null || true
```

### Step 7 — Confirm short-circuit semantics still work

- `ORCH_M019_EMIT=0` short-circuit in dispatch-interface.sh (line 148) is BEFORE the rollup helper invocation — so a test seam set to 0 still emits zero `dispatch_usage` records and zero log reads.
- write-summary.sh has no `ORCH_M019_EMIT` check today; T01 adds none. The existing `mkdir -p ... || return 0` guard at line 432 carries through; if that fails, no rollup, no emit.
- Empty / missing `execution-log.jsonl` → rollup returns `0\n0\n0\n0\n` → all four fields emit as integer `0` → record remains valid JSON.
- The P02 disable-flag golden (`tests/fixtures/m018-p02-baseline-payload.golden.txt`) is unchanged because T01 does not modify build-context.sh; the golden compares dispatch-payload bytes, not JSONL records.

## Verification

T01 produces no verifier scripts (those are T04). The Must-Have truths that T01's production code feeds are exercised by T04's verifiers `m018-p05-dispatch-usage-additivity.sh` and `m018-p05-unit-close-additivity.sh`.

T01 itself is verified by the post-implementation truths block at the phase level (`bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P05/`), which T04 wires up.

For T01's own self-check during development, the implementing agent SHOULD craft a synthetic in-flight log fixture and exercise the rollup helpers + emitters directly (smoke test — agent's call). T01 ships no verifier script; T04 wires the public verifiers `m018-p05-dispatch-usage-additivity.sh` and `m018-p05-unit-close-additivity.sh`.

Mechanical self-checks (syntax-only — production-code lint):

- Check: `bash -n scripts/dispatch/dispatch-interface.sh`
- Check: `bash -n scripts/knowledge/write-summary.sh`

## Must-Haves (subset addressed by this task)

This task addresses the following Must-Have truths from `P05-PLAN.md`:

- **Truth #1**: dispatch_usage additive fields. Wholly addressed by Steps 1–3.
- **Truth #2**: unit_close additive fields. Wholly addressed by Steps 4–6.

T01 does not address:

- Truth #3 (cost rollup savings columns) — T02.
- Truth #4 (efficiency footer compression line) — T02.
- Truth #5 (doctor compression-regression flag) — T02.
- Truth #6 (compression-eval cohort segmentation) — T03.
- Truth #7 (compression-eval shape) — T03.
- Truth #8 (dual-write recent-changes) — T04.

## Notes

- The four field names are exactly `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier1_invocations`. Capitalization and underscore placement match P02/P03/P04 verbatim. Downstream consumers (T02, T03, M027 surfaces) match these names exactly.
- The field order in the printf format strings follows the existing dispatch_usage/unit_close convention: pricing/quality fields together, then the new savings fields, then the closing identity fields (`source`, `timestamp`, etc.). This keeps the JSONL records visually grouped when read raw.
- The rollup helpers read the IN-FLIGHT log — i.e., the log file the emitter is about to append to. For dispatch_usage, this means the helper sees the most recent `payload_breakdown` record(s) the same dispatch already emitted (build-context.sh writes payload_breakdown BEFORE dispatch-interface.sh writes dispatch_usage in the dispatch path). For unit_close, the helper sees every payload_breakdown record on the in-scope milestone/phase/task at the time the summary is written.
- Token cost: zero. The two rollup helpers are bash + awk + sed; no LLM invocation.
- Bash 3.2 compliance: parallel scalars (`_di_filter_dropped`, `_di_tier1_savings`, etc. — no `declare -A`); awk/sed only inside the helper bodies (MEM004 carve-out). The shape guard (AP-009) accepts these helpers because they are not Check: commands.
