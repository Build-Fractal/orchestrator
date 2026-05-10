---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M019"
name: "dispatch_usage emitter + pricing degradation in dispatch-interface.sh"
depends_on: ["T02"]
---

## Prerequisites

- T01 complete: `scripts/lib/pricing.sh` ships `pricing_estimate_cost_usd`, `pricing_warning_reason`, `pricing_file_path`, `pricing_last_updated`, `pricing_is_stale`. `scripts/verify/m019-schema.sh` validates `dispatch_usage` records.
- T02 complete: `scripts/dispatch/build-context.sh` emits `payload_breakdown` records carrying `unitId: "<Mxxx>/<Pxx>/<Txx>"`. Those records provide the cost-block inputs that T04's `unit_close` emitter sums per task.

## Description

Append one `dispatch_usage` JSONL record to `.orchestrator/milestones/<Mxxx>/execution-log.jsonl` **after** the backend adapter subprocess returns, inside `scripts/dispatch/dispatch-interface.sh`. The record pairs each `payload_breakdown` with its runtime dispatch outcome:

- `record_type: "dispatch_usage"`
- `unitId: "<Mxxx>/<Pxx>/<Txx>"` — derived from the dispatched task plan path (parse `.orchestrator/milestones/<M>/phases/<P>/tasks/<T>-PLAN.md`)
- `backend` — the resolved backend name (`$BACKEND` in dispatch-interface.sh)
- `input_tokens_estimate` — `chars_to_tokens_quartile` of the payload chars (read back from the most-recent `payload_breakdown` record for the same `unitId`, or recomputed from `$PAYLOAD` file size)
- `output_tokens_estimate` — Tier 1 placeholder `0` (backend does not currently expose completion size; Tier 3 will land real values with `source: "runtime"`)
- `estimated_cost_usd` — `pricing_estimate_cost_usd $in $out $model`. On pricing miss / stale: `null`.
- `pricing_version` — value of `last_updated` from the pricing file (empty on missing-file)
- `pricing_warning` — ONLY present when `_PRICING_WARNING_REASON` is non-empty. Examples: `"missing"`, `"stale:124d"`, `"no-rate:claude-opus-4-7"`.
- `source: "estimate"`
- `timestamp` — ISO-8601 UTC

**Pricing-degradation path (SC-5 / C4)**: if the pricing file is absent OR stale (>90 days) OR the model is unknown, the record still lands. `estimated_cost_usd` is the JSON literal `null` (not the string `"null"`). `pricing_warning` carries the reason. Dispatch exits 0 normally.

## Steps

1. **Source the pricing library** at the top of `scripts/dispatch/dispatch-interface.sh`, after `ADAPTERS_DIR` is set:

   ```bash
   . "$(cd "$SCRIPT_DIR/../.." && pwd)/scripts/lib/pricing.sh"
   ```

2. **Derive `unitId` + `milestone` from the task plan path** near the top of the script (after `TASK_PLAN` is validated). Regex-extract the `M###/P##/T##` components from the path:

   ```bash
   MILESTONE_ID="$(printf '%s' "$TASK_PLAN" | grep -oE 'M[0-9]{3}' | head -n 1)"
   PHASE_ID="$(printf '%s' "$TASK_PLAN" | grep -oE 'P[0-9]{2}' | head -n 1)"
   TASK_ID="$(printf '%s' "$TASK_PLAN" | grep -oE 'T[0-9]{2}' | head -n 1)"
   UNIT_ID="${MILESTONE_ID}/${PHASE_ID}/${TASK_ID}"
   ORCH_ROOT="${ORCHESTRATOR_ROOT:-.orchestrator}"
   LOG_FILE="$ORCH_ROOT/milestones/$MILESTONE_ID/execution-log.jsonl"
   ```

   Fall back: if any ID is empty, set the UNIT_ID to the full basename-without-extension of the task plan. The emitter still runs — schema validator accepts any UNIT_ID string.

3. **Compute input_tokens_estimate** — size of `$PAYLOAD` file divided by 4 via the pricing-lib helper:

   ```bash
   payload_bytes="$(wc -c < "$PAYLOAD" 2>/dev/null || echo 0)"
   input_tokens="$(chars_to_tokens_quartile "$payload_bytes")"
   output_tokens=0
   ```

4. **Resolve model** — check env `$ORCH_MODEL`, else look up from `$INTENSITY_METADATA` file if it contains a `model:` YAML key. Empty string if neither is set:

   ```bash
   model="${ORCH_MODEL:-}"
   if [ -z "$model" ] && [ -n "${INTENSITY_METADATA:-}" ] && [ -f "$INTENSITY_METADATA" ]; then
     model="$(grep -E '^model:' "$INTENSITY_METADATA" | head -n 1 | sed -E 's/^model:[[:space:]]*"?([^"]*)"?.*/\1/')"
   fi
   ```

5. **Compute cost + warning** via the pricing lib:

   ```bash
   cost_usd="$(pricing_estimate_cost_usd "$input_tokens" "$output_tokens" "$model")"
   warning="$(pricing_warning_reason)"
   pricing_version="$(pricing_last_updated)"
   ```

6. **Emit the record** immediately AFTER the adapter subprocess returns a valid result (after the conformance checks at lines 177–190, before the `echo "$adapter_output"` at line 193):

   ```bash
   ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   mkdir -p "$(dirname "$LOG_FILE")"
   if [ -n "$cost_usd" ]; then
     # Happy path — cost is numeric
     printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"%s","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":%s,"pricing_version":"%s","model":"%s","source":"estimate","timestamp":"%s"}\n' \
       "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$BACKEND" \
       "$input_tokens" "$output_tokens" "$cost_usd" \
       "$pricing_version" "$model" "$ts" \
       >> "$LOG_FILE" || true
   else
     # Degradation path — cost=null, pricing_warning present
     printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"%s","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":null,"pricing_version":"%s","pricing_warning":"%s","model":"%s","source":"estimate","timestamp":"%s"}\n' \
       "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$BACKEND" \
       "$input_tokens" "$output_tokens" \
       "$pricing_version" "$warning" "$model" "$ts" \
       >> "$LOG_FILE" || true
   fi
   ```

7. **Also emit on the error paths** — when the adapter subprocess fails or emits malformed output, a `dispatch_usage` record should still appear with `backend` set and `estimated_cost_usd: null` + `pricing_warning: "adapter-failed"`. This preserves the invariant "every dispatch produces one dispatch_usage record" from SC-1. Place the emit snippet inside each of the three `emit_error ... exit N` branches (lines 167–173, 178–183, 184–190), immediately before `exit`.

   Alternative: factor the emit logic into a helper function `_di_emit_dispatch_usage` defined early in the script, called from the happy-path end AND each error branch.

## Must-Haves

- One new `dispatch_usage` record appended per `dispatch-interface.sh` invocation, happy path or error path.
- Every record carries `source: "estimate"` and `record_type: "dispatch_usage"`.
- Missing / stale pricing file -> record written with `estimated_cost_usd: null` + `pricing_warning` field present; dispatch exits 0 normally.
- `pricing_version` echoes the `last_updated` value from pricing.yml (empty string on missing-file is acceptable).
- Zero-token instrumentation preserved — dispatch-interface.sh stdout is byte-identical to pre-instrumentation output (the adapter's dispatch-result.md content, unchanged).

## Verification

- `bash scripts/verify/m019-p01-pricing-degradation.sh` (ships in T05) — renames `.orchestrator/config/pricing.yml` aside, runs a fixture dispatch, asserts a record with `estimated_cost_usd: null` and `pricing_warning` present, dispatch exit 0.
- `bash scripts/verify/m019-p01-emitter-presence.sh` (ships in T05) — counts `dispatch_usage` records on a fixture dispatch, asserts exactly one per call.
- `bash scripts/verify/m019-schema.sh <log>` — validates record shape + source enum.
- `bash scripts/verify/m019-p01-bash32-compat.sh` (ships in T06) — scans modified dispatch-interface.sh.

## Inputs

### From Previous Tasks

- `scripts/lib/pricing.sh` (from T01)
  - Key API: `pricing_estimate_cost_usd INPUT_TOKENS OUTPUT_TOKENS MODEL` -> prints USD estimate or empty on degradation. Exit 0 regardless.
  - Key API: `pricing_warning_reason` -> prints `missing | stale:<N>d | no-rate:<MODEL>` after a degraded estimate, else empty.
  - Key API: `pricing_last_updated` -> prints the YAML `last_updated:` value (the `pricing_version`).
  - Key API: `chars_to_tokens_quartile CHARS` -> integer token estimate (AD-1).
- `scripts/dispatch/build-context.sh` (from T02, modified)
  - Key contract: writes `payload_breakdown` records with the same `unitId` shape T03 uses. The two emitters are independently keyed; no shared file handle is required.

### From Disk (Pre-existing)

- `scripts/dispatch/dispatch-interface.sh` — target for modification. 194 lines. Backend resolution + adapter invocation is at lines 125–165; the emit hook sits after the adapter subprocess completes.
- `.orchestrator/config/pricing.yml` (from M019/P00/T04) — source of rates + staleness.
- [`.orchestrator/milestones/M019/M019-CONTEXT.md`](../../../../../milestones/M019/M019-CONTEXT.md) — AD-4 (three record types), AD-2 (pricing path), C4 (never-abort).

## Constraints

- **C4 / SC-5 — Never abort on pricing degradation.** Missing file, stale rates (>90 days), or unknown model all emit a record with `estimated_cost_usd: null` + `pricing_warning`, and dispatch returns its normal exit code (0 on happy path; whatever the adapter set on errors).
- **SC-1 — Exactly one `dispatch_usage` per dispatch.** Every code path that reaches an `exit` statement after `BACKEND` is resolved must emit exactly one record. Zero records = FAIL. Two records = FAIL.
- **C1 / SC-6 — Zero tokens.** Adapter stdout passes through unchanged; no emission surfaces on stdout. Log writes go to the execution-log file only.
- **C3 / SC-10 — Additive.** Existing `execution-log.jsonl` fields untouched; only new `record_type` values appended.
- **C5 — Bash 3.2.** Standard restrictions.
- **No agent-facing content.** Infrastructure script only.
- **MEM004 carve-out applies** — pipes / `$()` / awk permitted inside this script.

## Expected Output

- `scripts/dispatch/dispatch-interface.sh` grows by ~60–80 lines (helper function + 3-branch emit call).
- One `dispatch_usage` record appended per invocation; `bash scripts/verify/m019-schema.sh` validates it.
- Pricing-degradation fixture test passes: missing pricing.yml -> `estimated_cost_usd: null`, `pricing_warning: "missing"`, dispatch exit 0.
- Adapter-failure fixture test: adapter returns non-zero -> `dispatch_usage` still written with `pricing_warning: "adapter-failed"`, dispatch-interface exit 5 (preserves existing contract).
