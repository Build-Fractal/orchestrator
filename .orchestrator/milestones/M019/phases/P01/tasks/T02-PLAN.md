---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M019"
name: "payload_breakdown emitter in build-context.sh"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `scripts/lib/pricing.sh` ships `chars_to_tokens_quartile`, `pricing_warning_reason`, and is sourceable.
- T01 complete: `scripts/verify/m019-schema.sh` validates `record_type: payload_breakdown` records.
- P00 complete: `scripts/dispatch/build-context.sh` has a clearly demarcated post-payload-assembly hook point — the L1/L2/L4 additions land at approximately line 945–1001 (per P00/T01 summary). `BC_STABLE_IDXS` + `BC_VOLATILE_ALL_IDXS` are exported before `_bc_assemble_manifest_and_emit`. This task's emission hooks **after** `_bc_assemble_manifest_and_emit` returns, so it sits outside the payload.

## Description

Append one `payload_breakdown` JSONL record to `.orchestrator/milestones/<Mxxx>/execution-log.jsonl` **after** payload assembly completes, so the payload itself is byte-identical before and after instrumentation (SC-6). The record captures payload composition:

- `record_type: "payload_breakdown"`
- `unitId: "<Mxxx>/<Pxx>/<Txx>"` (or `<Mxxx>/<Pxx>/PHASE_PLAN` for planning payloads)
- `milestone`, `phase`, `task` — flat string fields
- `payload_chars` — integer, length of the assembled payload string in bytes
- `payload_tokens_estimate` — `chars_to_tokens_quartile(payload_chars)` (AD-1)
- `token_estimate_method: "char-quartile"`
- `section_tokens` — object `{ "<section-name>": <int> }` per emitted section (from `SECTION_NAMES_PIPE` + per-section file sizes in `$TMPDIR_BUILD/s<i>.txt`)
- `model` — from the intensity metadata when available, else `""`
- `source: "estimate"`
- `timestamp` — ISO-8601 UTC (`date -u +%Y-%m-%dT%H:%M:%SZ`)

The emitter writes to the milestone's `execution-log.jsonl`; if the milestone lives under a fixture root (tests call build-context.sh with a fixture `orch_root`), the log path is derived from `ORCH_ROOT/milestones/<Mxxx>/execution-log.jsonl`.

## Steps

1. **Add a helper function `_bc_emit_payload_breakdown`** near the bottom of `scripts/dispatch/build-context.sh`, below `_bc_assemble_manifest_and_emit` and **before** the `exit 0` line. The function:
   - Sources `scripts/lib/pricing.sh` once (guard: `if ! type chars_to_tokens_quartile >/dev/null 2>&1; then . "$PROJECT_ROOT/scripts/lib/pricing.sh"; fi`).
   - Computes `payload_chars` from the concatenated section files: iterate `i=1..SECTION_COUNT`, sum byte sizes of `$TMPDIR_BUILD/s${i}.txt` plus manifest+title+frontmatter overhead. Alternative: capture the stdout of `_bc_assemble_manifest_and_emit` into a temp file and `wc -c` it — but that would double-emit the payload. Use the summation approach.
   - Actually: the simplest correct route — `_bc_assemble_manifest_and_emit` writes to stdout, which is also what the caller captures. This task replaces that sole `_bc_assemble_manifest_and_emit` call with:

     ```bash
     # Capture the assembled payload into a temp file so we can measure its
     # byte size AND still emit it to stdout. Zero-token: no new content is
     # added to the payload; only a post-emit observation is made.
     PAYLOAD_CAPTURE="$TMPDIR_BUILD/_payload_capture.txt"
     _bc_assemble_manifest_and_emit "$SECTION_COUNT" "$SECTION_NAMES_PIPE" \
       "$SECTION_PRIORITIES_PIPE" "$FRONTMATTER" "$TITLE" > "$PAYLOAD_CAPTURE"
     cat "$PAYLOAD_CAPTURE"
     _bc_emit_payload_breakdown "$PAYLOAD_CAPTURE"
     exit 0
     ```

     `cat "$PAYLOAD_CAPTURE"` preserves the exact bytes that the caller would have received from direct `_bc_assemble_manifest_and_emit` — verified byte-identical by `scripts/verify/m019-p01-zero-token-growth.sh`.

2. **Compute per-section token counts** inside `_bc_emit_payload_breakdown`:
   - Loop `i=1..SECTION_COUNT`. For each `s<i>.txt`, compute `bytes=$(wc -c < "$TMPDIR_BUILD/s${i}.txt")` (MEM004 carve-out permits this). Extract the i-th display name from `SECTION_NAMES_PIPE` via `cut -d'|' -fN`.
   - Build a JSON object literal by concatenating `"<name>": <tokens>,` pairs. Drop the trailing comma via sed on the accumulator.
   - The object goes in `"section_tokens": { ... }` in the final record.

3. **Build the JSON record** with plain `printf`:

   ```bash
   log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
   log_file="$log_dir/execution-log.jsonl"
   mkdir -p "$log_dir"
   ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   model="${ORCH_MODEL:-}"
   printf '{"record_type":"payload_breakdown","unitId":"%s/%s/%s","milestone":"%s","phase":"%s","task":"%s","payload_chars":%d,"payload_tokens_estimate":%d,"token_estimate_method":"char-quartile","section_tokens":{%s},"model":"%s","source":"estimate","timestamp":"%s"}\n' \
     "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
     "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
     "$payload_chars" "$payload_tokens" \
     "$section_tokens_json" "$model" "$ts" \
     >> "$log_file"
   ```

4. **PLANNING-branch guard**: when `$TASK_ID == "PHASE_PLAN"`, the `unitId` becomes `<Mxxx>/<Pxx>/PHASE_PLAN` and `task` field is the literal string `"PHASE_PLAN"`. The record_type stays `payload_breakdown` — this is still a dispatch payload composition, just for planning.

5. **Bail-safe on I/O failure**: if `mkdir -p "$log_dir"` fails (read-only fixture root in a negative test) emit a stderr note and continue — never abort the dispatch. Wrap the `>>` append in `|| true` so the caller sees exit 0 even under a write failure.

## Must-Haves

- One new `payload_breakdown` record appended to `execution-log.jsonl` per `build-context.sh` invocation.
- Payload stdout is byte-identical to the pre-instrumentation output for the same inputs (SC-6).
- Record contains all ten fields listed in the Description.
- Instrumentation never adds content to the payload on stdout (no additional sections, no additional lines).
- Emitter never aborts the dispatch on log-write failure.

## Verification

- `bash scripts/verify/m019-p01-zero-token-growth.sh` (ships in T05) — diffs the payload bytes before/after instrumentation; byte-identical or FAIL.
- `bash scripts/verify/m019-p01-emitter-presence.sh` (ships in T05) — asserts exactly one `payload_breakdown` record emitted per `build-context.sh` call.
- `bash scripts/verify/m019-schema.sh <log>` (from T01) — validates the emitted record against the record_type + source enums.
- `bash scripts/verify/m019-p01-bash32-compat.sh` (ships in T06) — scans modified build-context.sh for bash 3.2 violations.

## Inputs

### From Previous Tasks

- `scripts/lib/pricing.sh` (from T01)
  - Key API: `chars_to_tokens_quartile <chars>` prints integer token estimate.
  - Key API: (no rate lookup needed in this task — `payload_breakdown` records have no `estimated_cost_usd`; that lands on `dispatch_usage` in T03).

- `scripts/verify/m019-schema.sh` (from T01)
  - Key API: `bash scripts/verify/m019-schema.sh <log.jsonl>` exits 0 on valid, 1 on violations; validates `record_type`, `source`, and (for unit_close) cost+quality pairing.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — target for modification. Hook point: immediately before `exit 0` (line 1001). `TMPDIR_BUILD`, `SECTION_COUNT`, `SECTION_NAMES_PIPE`, `MILESTONE_ID`, `PHASE_ID`, `TASK_ID`, `ORCH_ROOT`, `PROJECT_ROOT` are all in scope at that point.
- `scripts/lib/manifest-builder.sh` — provides `_bc_assemble_manifest_and_emit`. Inspect its signature to confirm stdout is the sole emission surface (it is, per P00/T01 summary).
- `.orchestrator/milestones/M019/M019-CONTEXT.md` — AD-1 (char-quartile), AD-5 (`<dispatch-volatile>` marker awareness — section_tokens accounting respects volatile boundaries because it operates on the same `s<i>.txt` files the emit loop consumes).

## Constraints

- **C1 / SC-6 — Zero-token instrumentation.** The payload emitted to stdout must be byte-identical before and after this change for the same inputs. The `PAYLOAD_CAPTURE` intermediate file is internal only; its sole purpose is measurement.
- **C3 / SC-10 — Additive only.** Existing `execution-log.jsonl` fields on pre-M019 records stay untouched; this task only appends new records with new `record_type` values.
- **C5 — Bash 3.2.** No `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`.
- **MEM004 carve-out applies** — emitter code is verification/dispatch-internal; pipes + `$()` + awk are fine inside the scripts.
- **No agent-facing content changes.** This task modifies dispatch *infrastructure*, not any template, prompt, or payload section. Anti-pattern linter should remain green unchanged.
- **Never abort dispatch.** All failure modes degrade silently (stderr note at most) rather than changing exit code.
- **No Tier 2/3 surface** — no rollup, no new command, no user-facing output change.

## Expected Output

- `scripts/dispatch/build-context.sh` line count rises by ~60 lines; file still ends with `exit 0`.
- One new `payload_breakdown` line appended to `execution-log.jsonl` per dispatch invocation.
- `bash scripts/verify/m019-schema.sh <modified_log>` -> `PASS: m019-schema.sh 1 records validated`, exit 0.
- `diff <expected-payload> <new-payload>` (invoked through the zero-token-growth script in T05) reports no differences.
