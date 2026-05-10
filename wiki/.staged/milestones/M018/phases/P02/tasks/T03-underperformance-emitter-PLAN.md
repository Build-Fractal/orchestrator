---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M018"
name: "Aggregate-savings underperformance self-check + compression_underperformance emitter"
depends_on: ["T02"]
---

## Prerequisites

- T01 has landed `scripts/lib/preservation-check.sh` (sourceable by `build-context.sh`).
- T02 has wired the knowledge filter into `build-context.sh`, extended `_bc_emit_payload_breakdown` with the `filter_dropped_tokens` field, and added the `compression:` block to `.orchestrator/config.yml`.
- `references/compression-grammar.md` `## Aggregate Plausibility (SC-9)` (lines 245–290) names the calibrated 34.7% mean payload-token reduction floor (P00 80% CI lower bound across n=169 historical `payload_breakdown` records).
- P01-SUMMARY MIT-09 (THREAT-08) is the spec for this task: P02 ships an aggregate-savings self-check that emits a `compression_underperformance` JSONL record when the running mean falls below the 34.7% floor — operational signal, not a hard gate. The check never blocks dispatch.

## Description

Add an aggregate-savings self-check to `scripts/dispatch/build-context.sh` that, after each `payload_breakdown` emission, computes the running mean payload-token reduction across the last N dispatches in `execution-log.jsonl` and emits a `compression_underperformance` JSONL record when that running mean falls below the SC-9 calibrated 34.7% floor.

The self-check is operational-signal only. It NEVER blocks dispatch. Its purpose is to surface a regression early — if M018 is shipping but the aggregate savings are below the floor, the operator sees a JSONL record they can grep for, before relying on the [M027](../../../../../milestones/M027/index.md) efficiency footer's per-milestone rollup at consolidation time.

The check is config-driven so the threshold and window can evolve without code edits:

```yaml
compression:
  underperformance:
    enabled: true            # default; set false to disable the self-check.
    window_size: 30          # last N payload_breakdown records considered.
    floor_pct: 34.7          # SC-9 calibrated floor (P00 80% CI lower bound).
    min_sample_size: 10      # skip the check when fewer than N records exist.
```

Reduction calculation: for each `payload_breakdown` record in the window, the savings are `(filter_dropped_tokens + tier1_savings_tokens + tier2_savings_tokens + tier3_compression_savings_tokens) / (payload_tokens_estimate + filter_dropped_tokens + tier1_savings_tokens + tier2_savings_tokens + tier3_compression_savings_tokens)` — the denominator is the *pre-compression* payload size (the post-compression `payload_tokens_estimate` plus everything the tiers stripped). At P02, only `filter_dropped_tokens` is non-null; tier1/tier2/tier3 fields are absent (treated as 0) until P03/P04/P06 ship. The math holds.

When the running mean reduction is below `floor_pct` AND the sample size is at least `min_sample_size`, emit:

```json
{
  "record_type": "compression_underperformance",
  "milestone": "M018",
  "phase": "P02",
  "task": "T02",
  "running_mean_pct": 12.4,
  "floor_pct": 34.7,
  "window_size": 30,
  "sample_size": 30,
  "shortfall_pct": 22.3,
  "timestamp": "2026-04-27T14:23:01Z"
}
```

The record is additive (CON-5). Pre-M018 records remain valid JSON. Existing rollups that key by `record_type` ignore the new type cleanly.

## Steps

1. **Add the `compression.underperformance:` block to `.orchestrator/config.yml`** and `templates/config-defaults.yml`. Insert under the existing `compression:` block from T02:

   ```yaml
   compression:
     enabled: true
     knowledge_filter:
       enabled: true
       drop_list:
         - superseded
         - experimental
     underperformance:
       enabled: true
       window_size: 30
       floor_pct: 34.7
       min_sample_size: 10
   ```

2. **Author `_bc_emit_compression_underperformance`** in `scripts/dispatch/build-context.sh`. Place near `_bc_emit_payload_breakdown` (line 1042 region). The function is invoked from the same top-level site, AFTER `_bc_emit_payload_breakdown` and AFTER `_bc_emit_payload_filter`:

   ```bash
   _bc_emit_compression_underperformance() {
     [ "${ORCH_M019_EMIT:-1}" = "0" ] && return 0

     local enabled window_size floor_pct min_sample_size
     enabled="$(config_read 'compression.underperformance.enabled' true)"
     [ "$enabled" != "true" ] && return 0
     window_size="$(config_read 'compression.underperformance.window_size' 30)"
     floor_pct="$(config_read 'compression.underperformance.floor_pct' 34.7)"
     min_sample_size="$(config_read 'compression.underperformance.min_sample_size' 10)"

     local log_dir log_file
     log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
     [ ! -d "$log_dir" ] && [ -d "$ORCH_ROOT/phases" ] && log_dir="$ORCH_ROOT"
     log_file="$log_dir/execution-log.jsonl"
     [ ! -f "$log_file" ] && return 0

     # Compute running mean reduction over the last $window_size payload_breakdown
     # records. Use awk: it has the floating-point math we need and runs in one
     # process (AP-009 safe — single command).
     local stats
     stats="$(awk -v win="$window_size" -v floor="$floor_pct" -v min="$min_sample_size" '
       BEGIN { count=0; sum_pct=0 }
       /"record_type":"payload_breakdown"/ {
         # Extract payload_tokens_estimate.
         pte = 0; fdt = 0; t1 = 0; t2 = 0; t3 = 0
         if (match($0, /"payload_tokens_estimate":[0-9]+/)) {
           v = substr($0, RSTART+25, RLENGTH-25)
           pte = v + 0
         }
         if (match($0, /"filter_dropped_tokens":[0-9]+/)) {
           v = substr($0, RSTART+24, RLENGTH-24)
           fdt = v + 0
         }
         if (match($0, /"tier1_savings_tokens":[0-9]+/)) {
           v = substr($0, RSTART+23, RLENGTH-23)
           t1 = v + 0
         }
         if (match($0, /"tier2_savings_tokens":[0-9]+/)) {
           v = substr($0, RSTART+23, RLENGTH-23)
           t2 = v + 0
         }
         if (match($0, /"tier3_compression_savings_tokens":[0-9]+/)) {
           v = substr($0, RSTART+34, RLENGTH-34)
           t3 = v + 0
         }
         saved = fdt + t1 + t2 + t3
         pre = pte + saved
         if (pre > 0) {
           pct = (saved * 100.0) / pre
           rec_count++
           rec_pct[rec_count] = pct
         }
       }
       END {
         if (rec_count < min) {
           printf "INSUFFICIENT %d %d\n", rec_count, min
           exit 0
         }
         start = rec_count - win + 1
         if (start < 1) start = 1
         actual_window = rec_count - start + 1
         total = 0
         for (i = start; i <= rec_count; i++) total += rec_pct[i]
         mean = total / actual_window
         printf "MEAN %.2f %d %.2f\n", mean, actual_window, floor
       }
     ' "$log_file")"

     # Parse stats line.
     local marker mean_pct sample_size floor_seen
     marker="$(printf '%s\n' "$stats" | awk '{print $1}')"
     [ "$marker" != "MEAN" ] && return 0
     mean_pct="$(printf '%s\n' "$stats" | awk '{print $2}')"
     sample_size="$(printf '%s\n' "$stats" | awk '{print $3}')"
     floor_seen="$(printf '%s\n' "$stats" | awk '{print $4}')"

     # Compare mean_pct < floor_pct using awk (bash 3.2 has no float comparison).
     local under
     under="$(awk -v m="$mean_pct" -v f="$floor_seen" 'BEGIN { print (m < f) ? "1" : "0" }')"
     [ "$under" != "1" ] && return 0

     # Compute shortfall.
     local shortfall
     shortfall="$(awk -v m="$mean_pct" -v f="$floor_seen" 'BEGIN { printf "%.2f", f - m }')"

     local ts
     ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
     printf '{"record_type":"compression_underperformance","milestone":"%s","phase":"%s","task":"%s","running_mean_pct":%s,"floor_pct":%s,"window_size":%d,"sample_size":%d,"shortfall_pct":%s,"timestamp":"%s"}\n' \
       "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
       "$mean_pct" "$floor_seen" "$window_size" "$sample_size" \
       "$shortfall" "$ts" \
       >> "$log_file" 2>/dev/null || true
     return 0
   }
   ```

3. **Wire the call site**. Near line 1208 in `build-context.sh`, after the existing `_bc_emit_payload_breakdown "$PAYLOAD_CAPTURE" || true` and the T02-added `_bc_emit_payload_filter || true`, add:

   ```bash
   _bc_emit_compression_underperformance || true
   ```

4. **Smoke-test against a synthetic execution log**. Create a tiny test under `/tmp/`:

   ```bash
   tmp=$(mktemp -d)
   for i in $(seq 1 30); do
     printf '{"record_type":"payload_breakdown","milestone":"TEST","phase":"P01","task":"T01","payload_chars":1000,"payload_tokens_estimate":100,"filter_dropped_tokens":5,"timestamp":"2026-04-27T00:00:00Z"}\n' >> "$tmp/execution-log.jsonl"
   done
   # 30 records each with savings 5/(100+5) ≈ 4.76% — well below the 34.7% floor.
   # Running the underperformance check should produce a compression_underperformance record.
   ```

   Hand-invoke the awk block from step 2 against the synthetic log; assert the printed `MEAN` value is ~4.76 and the function would emit a `compression_underperformance` record.

5. **Document the new fields** in a comment at the top of the underperformance function:

   ```bash
   # M018/P02/T03: compression_underperformance self-check.
   # MIT-09 (P01 carryover): operational signal — never blocks dispatch.
   # Emits compression_underperformance JSONL when running mean reduction over
   # the last $window_size payload_breakdown records falls below
   # $floor_pct (default 34.7, SC-9 calibrated floor per P00 80% CI lower bound).
   # Sample-size guard: skips emission when count < $min_sample_size (default 10)
   # so the check doesn't fire spuriously on a fresh log.
   # Reduction math: (sum of tier savings) / (payload_tokens + sum of tier savings).
   ```

## Must-Haves

This task addresses the phase truth:

- The aggregate-savings self-check emits `compression_underperformance` JSONL records when the running mean falls below the 34.7% floor; the check is operational signal only, never blocks dispatch; threshold and window are config-driven. (Verified by `bash scripts/verify/m018-p02-underperformance-emit.sh` from T04.)

## Verification

```
bash scripts/dispatch/build-context.sh --fixture tests/fixtures/m018-p02-knowledge-status
```

Expected: when the fixture's execution log accumulates ≥ 10 `payload_breakdown` records with savings well below 34.7%, exactly one `compression_underperformance` line appears per dispatch on top of the existing records.

T04's verifier `bash scripts/verify/m018-p02-underperformance-emit.sh` constructs a synthetic execution log with 30 underperforming records, runs `build-context.sh` (or invokes the function directly via a sourced harness), and asserts a `compression_underperformance` record was appended.

## Inputs

### From Previous Tasks

- `scripts/dispatch/build-context.sh` (modified by T02)
  - Key API extended in T02: `_bc_emit_payload_breakdown` now writes `filter_dropped_tokens`. T03's underperformance check reads that field from `execution-log.jsonl`.
  - Key types: same `payload_breakdown` JSONL schema; T03 ADDS a sibling `compression_underperformance` record type.
  - Behavioral contract: T03's call site is AFTER `_bc_emit_payload_breakdown` so the running mean includes the just-emitted record.

- `.orchestrator/config.yml` (modified by T02 — adds `compression:` block)
  - T03 extends with `compression.underperformance.*` keys.

### From Disk (Pre-existing)

- `references/compression-grammar.md` `## Aggregate Plausibility (SC-9)` (lines 245–290) — names the 34.7% floor and the per-tier 80% CIs the floor was derived from. The default `floor_pct: 34.7` traces to this section.
- `.orchestrator/scratch/m018-section-distribution-output.json` `aggregate.low_pct` — the source of truth for the 34.7342% bootstrap-derived lower bound. The probe output lives on disk and is the audit trail for any future floor adjustment.
- `execution-log.jsonl` (per-milestone, e.g. `.orchestrator/milestones/M018/execution-log.jsonl`) — the input the awk block parses. Records are append-only JSONL; pre-M018 records lack the new fields and are correctly handled by the awk (default to 0).

## Constraints

- **Bash 3.2 + AP-009 / AD-19 shape**. Float math is awk-only (bash 3.2 has no `bc` dependency assumption). Each function uses sequential statements; no compound chains > 2; no `$(...|...)` containing pipes.
- **Operational signal only**. The check NEVER blocks dispatch. Failure to emit (mkdir failure, log-file unwritable, awk error) returns 0 silently. Constitution Principle XI compliance.
- **Additive emitter (CON-5)**. `compression_underperformance` is a new `record_type`; pre-M018 rollups ignore it cleanly.
- **Sample-size guard**. The check skips emission when `sample_size < min_sample_size` (default 10) so a fresh log doesn't trigger spurious underperformance reports. P02-stage logs may legitimately be below the floor because tier1/tier2/tier3 haven't shipped yet — that's expected and the operator reads the record as a baseline, not an alarm. M018 close ships P03+ which closes the gap.
- **Multi-runtime parity (FR-13)**. Awk + bash, no LLM call; output is byte-identical across CC / Codex CLI / Cursor.
- **AGENTS.md dual-write convention**. T03 does NOT edit CLAUDE.md or AGENTS.md. T04 handles the dual-write recent-changes refresh.

## Expected Output

- `scripts/dispatch/build-context.sh` modified — adds `_bc_emit_compression_underperformance` (~70–100 lines including the awk block) and one new call-site line.
- `.orchestrator/config.yml` modified — adds `compression.underperformance.*` keys under the existing `compression:` block (T02-created).
- `templates/config-defaults.yml` modified — same block mirrored.
- Smoke test passes: synthetic execution log with 30 underperforming records produces a `compression_underperformance` record on the next `build-context.sh` invocation.
