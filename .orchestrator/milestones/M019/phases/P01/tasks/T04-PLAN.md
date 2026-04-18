---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M019"
name: "unit_close emitter with Goodhart pairing in write-summary.sh"
depends_on: ["T03"]
---

## Prerequisites

- T01 complete: `scripts/lib/pricing.sh` + `scripts/verify/m019-schema.sh` (validator rejects unit_close records missing cost OR quality blocks).
- T02 complete: `payload_breakdown` records keyed by `<Mxxx>/<Pxx>/<Txx>` are in `execution-log.jsonl`.
- T03 complete: `dispatch_usage` records keyed by the same unitId are in `execution-log.jsonl`.
- `scripts/knowledge/write-summary.sh` exists (211 lines), accepts `task | phase | milestone` as its first arg, produces YAML-frontmatter-plus-markdown summary files.

## Description

Append one `unit_close` JSONL record to `.orchestrator/milestones/<Mxxx>/execution-log.jsonl` after each successful `write-summary.sh task | phase | milestone` invocation. Every `unit_close` record carries BOTH a cost block AND a quality block — the Goodhart guard (C2). Schema validator from T01 rejects records missing either block.

Record shape:

- `record_type: "unit_close"`
- `granularity: "task" | "phase" | "milestone"` (SC-4 enum)
- `unitId: "<Mxxx>/<Pxx>/<Txx>"` for tasks, `<Mxxx>/<Pxx>` for phases, `<Mxxx>` for milestones
- `milestone`, `phase` (empty on milestone-granularity), `task` (empty on phase/milestone)
- `duration_s` — from the `--duration` field of write-summary (parse `25m` -> 1500)
- `outcome` — from `--verification_result` (pass | fail | pending)
- `completed_at` — the summary's `completed_at` timestamp (echoed)
- Cost block:
  - `estimated_cost_usd` — sum of `estimated_cost_usd` values across all records for this unitId (task: own records; phase: all child-task records; milestone: all child-phase records). `null` if any contributing record has `null` OR if no contributing records exist.
  - `pricing_version` — the `pricing_version` from the most recent contributing `dispatch_usage` record; empty if none.
- Quality block (per AD-3 — derived from existing fields, no new event emission):
  - `verification_pass_rate` — 1.0 for a single task where `verification_result=pass`, 0.0 for `fail`. For phase: count(pass tasks) / count(total tasks). For milestone: count(pass phases) / count(total phases).
  - `deviation_count` — count of existing log records for this unitId where `attempt > 1` OR `outcome != "success"`. AD-3 heuristic.
  - `retry_count` — count of existing log records for this unitId where `attempt > 1`.
- `source: "aggregate"` for phase/milestone granularity, `"estimate"` for task granularity (the task-level rollup is over that one task's own records, which are all source=estimate in Tier 1)
- `timestamp` — ISO-8601 UTC

## Steps

1. **Add a helper function `_ws_emit_unit_close`** at the bottom of `scripts/knowledge/write-summary.sh`, before the final `echo "SUMMARY: ..."` line.

   ```bash
   _ws_emit_unit_close() {
     # args: granularity milestone phase task duration_s outcome completed_at
     local granularity="$1"
     local milestone="$2"
     local phase="$3"
     local task="$4"
     local duration_s="$5"
     local outcome="$6"
     local completed_at="$7"
     # ... (see steps 2-5)
   }
   ```

2. **Parse duration to seconds.** `write-summary.sh` accepts formats like `25m`, `2h`, `130m`. Implement `_ws_parse_duration_seconds`:
   - `${dur}` ends in `m` -> multiply by 60
   - ends in `h` -> multiply by 3600
   - ends in `s` -> as-is
   - fallback: numeric as-is

3. **Compute unitId + log file path.**

   ```bash
   ORCH_ROOT="${ORCHESTRATOR_ROOT:-.orchestrator}"
   log_file="$ORCH_ROOT/milestones/$milestone/execution-log.jsonl"
   case "$granularity" in
     task)      unit_id="$milestone/$phase/$task" ;;
     phase)     unit_id="$milestone/$phase" ;;
     milestone) unit_id="$milestone" ;;
   esac
   ```

4. **Compute the cost block** by scanning `$log_file`:
   - Task granularity: sum `estimated_cost_usd` values from records where `unitId == "<M>/<P>/<T>"`. Most recent `pricing_version` wins.
   - Phase granularity: sum across all `unitId` values that START with `<M>/<P>/`. The grep prefix `"unitId":"<M>/<P>/` is the filter.
   - Milestone granularity: sum across all records in the file (file is already milestone-scoped).
   - If any contributing record has `estimated_cost_usd: null`, the summed field is also `null` (preserves the Tier 1 degradation signal up the aggregation chain). If no records match, also `null`.
   - Implementation: one awk pass over the log file filtering by unitId prefix, summing, tracking any-null:

     ```bash
     cost_summary="$(
       awk -v prefix="\"unitId\":\"$unit_id" '
         $0 ~ prefix {
           if (match($0, /"estimated_cost_usd":null/)) { any_null=1 }
           else if (match($0, /"estimated_cost_usd":[0-9.]+/)) {
             v=substr($0,RSTART+24,RLENGTH-24); sum+=v+0; n++
           }
           if (match($0, /"pricing_version":"[^"]*"/)) {
             pv=substr($0,RSTART+19,RLENGTH-20)
           }
         }
         END {
           if (any_null || n==0) print "null|" pv
           else printf "%.8f|%s\n", sum, pv
         }
       ' "$log_file" 2>/dev/null
     )"
     cost_total="${cost_summary%%|*}"
     pricing_version="${cost_summary##*|}"
     ```

     For task-granularity, the prefix is the full unitId with a closing quote; adjust to `"unitId":"<M>/<P>/<T>\""`. Use a second awk variant for the phase / milestone prefix-match shape. MEM004 carve-out permits awk.

5. **Compute the quality block** (AD-3 — derive from existing log fields):
   - `retry_count`: count of log lines matching the unitId prefix AND `"attempt":[2-9]`.
   - `deviation_count`: retry_count + count of lines with `"outcome":"fail"` (or `"outcome":"error"`) for the same unitId.
   - `verification_pass_rate`:
     - Task: `outcome == "pass" ? 1.0 : 0.0`.
     - Phase/milestone: ratio of child-units whose most recent verification record is `pass`. Compute by counting child unitIds where a `pass` unit_close record already exists.
   - Bash-3.2-safe arithmetic; use awk for the ratio:

     ```bash
     pass_rate="$(
       awk -v prefix="\"unitId\":\"$unit_id/" '
         $0 ~ prefix && /"record_type":"unit_close"/ {
           total++
           if (match($0, /"outcome":"pass"/)) pass++
         }
         END { if (total>0) printf "%.2f", pass/total; else printf "1.0" }
       ' "$log_file" 2>/dev/null
     )"
     ```

     For task granularity, skip the child-aggregation and echo `1.0` on outcome=pass, `0.0` otherwise.

6. **Emit the record** to `$log_file`:

   ```bash
   ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   mkdir -p "$(dirname "$log_file")"
   # cost_total is either "null" or a decimal
   if [ "$cost_total" = "null" ]; then cost_field="null"; else cost_field="$cost_total"; fi
   src="estimate"
   if [ "$granularity" != "task" ]; then src="aggregate"; fi
   printf '{"record_type":"unit_close","granularity":"%s","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","duration_s":%d,"outcome":"%s","completed_at":"%s","estimated_cost_usd":%s,"pricing_version":"%s","verification_pass_rate":%s,"deviation_count":%d,"retry_count":%d,"source":"%s","timestamp":"%s"}\n' \
     "$granularity" "$unit_id" \
     "$milestone" "$phase" "$task" \
     "$duration_s" "$outcome" "$completed_at" \
     "$cost_field" "$pricing_version" \
     "$pass_rate" "$deviation_count" "$retry_count" \
     "$src" "$ts" \
     >> "$log_file" || true
   ```

   Note: `source: "aggregate"` for phase + milestone is valid per the spec (US2/AS-2 reserves `aggregate` as the rollup tag). If the schema validator in T01 only whitelists `estimate | runtime`, extend it to also accept `aggregate` — update `m019-schema.sh` in this task to whitelist `estimate | runtime | aggregate` for the `source` field.

   **Schema validator update**: modify `scripts/verify/m019-schema.sh` source-enum to `estimate | runtime | aggregate`. Leave `scripts/verify/m019-p01-source-enum.sh` (T05) asserting that `estimate` and `runtime` are accepted and other values rejected — with `aggregate` now also accepted, the source-enum gate's rejection case uses a value like `"fabricated"` or `"gpt-guess"`. SC-4 text says "estimate | runtime"; extend gently: `aggregate` is the rollup slot reserved by AS-2. Document in the validator comment.

7. **Call `_ws_emit_unit_close`** at the end of `scripts/knowledge/write-summary.sh`, just BEFORE the final `echo "SUMMARY: ..."` line. Pass `SUMMARY_TYPE` as `granularity`, the parsed fields, and the computed `f_completed`. The duration-to-seconds parse happens inside the helper.

## Must-Haves

- One `unit_close` record appended per `write-summary.sh task | phase | milestone` call.
- Every emitted record contains ALL of: `estimated_cost_usd` key, `pricing_version` key, `verification_pass_rate` key, `deviation_count` key, `retry_count` key. Missing any = schema-validator FAIL.
- `granularity` field is exactly `task`, `phase`, or `milestone`.
- Task granularity: verification_pass_rate is 1.0 or 0.0.
- Phase granularity: verification_pass_rate is `child_pass_tasks / total_child_tasks` (handling 0/0 -> 1.0).
- Milestone granularity: ratio over child phases.
- Summary file write is unchanged — the emitter only appends to the JSONL log, never modifies the summary output.
- `write-summary.sh` exit code unchanged (0 on success).

## Verification

- `bash scripts/verify/m019-p01-emitter-presence.sh` (ships in T05) — asserts one unit_close per write-summary at each of the three granularities, and asserts cost+quality fields all present.
- `bash scripts/verify/m019-schema.sh <log>` — rejects test fixtures where cost or quality block is deliberately removed.
- `bash scripts/verify/m019-p01-source-enum.sh` (ships in T05) — still accepts estimate + runtime, now also aggregate; rejects arbitrary other values.
- `bash scripts/verify/m019-p01-bash32-compat.sh` (ships in T06).

## Inputs

### From Previous Tasks

- `scripts/lib/pricing.sh` (from T01) — not sourced directly by this task; all lookups are over already-emitted log records.
- `scripts/verify/m019-schema.sh` (from T01) — validator needs its source-enum whitelist extended to `estimate | runtime | aggregate`. This task performs that one-line extension.
- `scripts/dispatch/build-context.sh` (from T02) — produces `payload_breakdown` records that T04's task-level rollup may reference via the same log file (though T04's primary sum is over `dispatch_usage` records, since those carry the estimated_cost_usd field; `payload_breakdown` records do not).
- `scripts/dispatch/dispatch-interface.sh` (from T03) — produces `dispatch_usage` records carrying `estimated_cost_usd`, `pricing_version`, `unitId`. These are the cost-block inputs for task-granularity rollup.

### From Disk (Pre-existing)

- `scripts/knowledge/write-summary.sh` — target. 211 lines. Existing flow: parse `--field=value` args, validate required fields, build YAML + body, write summary file, echo `SUMMARY: <type> <id> written`. The emit call goes between the summary write and the final echo.
- `.orchestrator/milestones/M019/M019-CONTEXT.md` — AD-3 (deviation_count derived from existing fields), AD-4 (granularity enum + cost+quality pairing), C2 (Goodhart guard).
- Pre-existing `execution-log.jsonl` in any milestone — for fixture testing, T05 ships a fixture that preserves the pre-M019 record shape so additivity can be asserted.

## Constraints

- **C2 / SC-3 — Goodhart pairing mandatory.** Every emitted `unit_close` record contains both blocks. Schema validator fails any record missing either.
- **SC-2 — Exactly one `unit_close` per write-summary invocation.** No emission from any other entry point.
- **C3 / SC-10 — Additive.** Existing summary file output unchanged byte-for-byte.
- **C5 — Bash 3.2.** No `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`. `local` is safe (already used throughout write-summary.sh).
- **MEM004 carve-out applies** — awk + `$()` + pipes permitted inside write-summary.sh emit helper.
- **Never abort** — log-write failures degrade silently via `|| true`. Summary file write failures keep their existing behavior.
- **AD-3 derivation only** — do NOT emit new event records to compute quality. Read what's already in the log.
- **No Tier 2/3 surface** — no new CLI, no new user output.

## Expected Output

- `scripts/knowledge/write-summary.sh` grows by ~80–100 lines; final `echo "SUMMARY: ..."` unchanged.
- `scripts/verify/m019-schema.sh` source-enum whitelist extended by one token (`aggregate`).
- Running `write-summary.sh task` on a fixture task produces: unchanged summary file + one new `unit_close` record in the milestone's execution-log.jsonl with granularity=task, cost + quality blocks populated.
- Running `write-summary.sh phase` / `milestone` produces records with `granularity` set accordingly and `source: "aggregate"`.
- `bash scripts/verify/m019-p01-emitter-presence.sh` and `bash scripts/verify/m019-schema.sh <log>` both PASS.
