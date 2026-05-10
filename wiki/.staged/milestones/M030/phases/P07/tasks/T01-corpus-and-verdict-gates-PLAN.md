---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P07"
milestone: "M030"
name: "Acceptance-corpus synthesizer + 4 corpus fixtures + per-verdict gates"
depends_on: []
---

## Prerequisites

- `scripts/diagnostics/shadow-compare.sh` exists and emits a `flip_recommendation=<ready|partially_ready|block|evidence_insufficient>` line per the closed-enum verdict table documented at the top of the script (lines 11-17). Verified at plan-authoring time: `[ -f scripts/diagnostics/shadow-compare.sh ]` passes.
- `scripts/dispatch/classify-task.sh` exists and emits deterministic `character=<mechanical|standard|novel>` + `confidence=<high|medium|low>` lines. Verified.
- `templates/model-routing.yml` exists and declares the routing table where `mechanical → fast`, `standard → balanced`, `novel → smart`, plus the `cost_rates:` section. Verified.
- `tests/fixtures/m030-classifier-corpus/labels.yml` exists (P00 fixture corpus); P07 corpus synthesis can sample `unitId` paths from this set if needed for stable fixture generation.
- Existing P02 shadow-corpus fixtures at `tests/fixtures/m030-p02/` — read-only reference for corpus shape:
  - `shadow-corpus-ready.jsonl` (150 records / 50 per class) — P07's `corpus-50-per-class.jsonl` shape mirrors this.
  - `shadow-corpus-partially-ready.jsonl` (100 records) — P07's `corpus-2-class-only.jsonl` shape mirrors this with one class omitted.
  - `shadow-corpus-block.jsonl` (30 records) — P07's `corpus-block.jsonl` shape mirrors this with at-scale volume.
  - `shadow-corpus-evidence-insufficient.jsonl` (0 records) — P07's `corpus-zero.jsonl` is the same shape (empty).

Plan-time prerequisite-existence verification (P07 paper-cut sweep rule 1): all five paths above are present at plan-authoring time.

## Description

T01 ships the acceptance-corpus foundation: an idempotent synthesizer at `tests/m030-acceptance/shadow-corpus-fixtures.sh` that produces four corpora exercising all four `shadow-compare.sh` verdicts at acceptance scale, plus five per-verdict verifier gates under `tools/verify/p07-*`.

T01 deliberately separates the corpus + per-verdict gates from the acceptance-battery runner (T02). Reason: the per-verdict gates can run independently against just the synthesized corpora, without depending on the full SC battery runner shape. This lets T02's runner delegate to T01 gates rather than re-implement the verdict-extraction logic.

### Corpus design

Four corpora under `tests/m030-acceptance/`:

1. **`corpus-50-per-class.jsonl`** — 150 dispatch_usage records, 50 per class (mechanical / standard / novel). Records carry `model_routed` matching the routing-table mapping (mechanical→fast, standard→balanced, novel→smart) and `classifier_confidence=high` for >=80% of records (driving the rolling-variance stability metric below floor; corpus is "ready"). Synthesized timestamps deterministic via loop-index. Drives `flip_recommendation=ready`.

2. **`corpus-zero.jsonl`** — 0 records (empty file). Drives `flip_recommendation=evidence_insufficient`.

3. **`corpus-2-class-only.jsonl`** — 100 records, 50 mechanical + 50 standard, 0 novel. Mechanical and standard meet the per-class evidence + stability thresholds; novel is below threshold. Novel's routing-table default is `smart` (no model downgrade would occur), so the D-A3 conservative-by-construction gate fires and `shadow-compare.sh` returns `partially_ready` enumerating mechanical+standard as the flippable classes.

4. **`corpus-block.jsonl`** — 60 records distributed across all 3 classes (e.g., 20-20-20) but with low classifier_confidence values driving rolling-variance ABOVE the stability floor for at least one class whose routing-table default is NOT `smart` (mechanical → fast or standard → balanced). The per-class evidence count alone may be at-or-just-below the threshold, but the stability metric pushes the verdict below the partially_ready conservative-construction gate. Drives `flip_recommendation=block`.

Synthesizer responsibilities:
- Idempotent: re-running produces byte-identical output (deterministic timestamps via loop-index; deterministic record IDs; no `date`-derived fields outside the timestamp formatter).
- Each record is a complete `dispatch_usage` JSON line matching the field set emitted by `scripts/dispatch/dispatch-interface.sh` (lines 630 and 666 of that script — see prerequisites). Critical fields for P07: `unitId`, `milestone`, `phase`, `task`, `classifier_confidence`, `model_routed` (symbolic tier), `model_used`, `partial_flip_active=false`, `withheld_classes=""`, `character`.
- `mkdir -p tests/m030-acceptance/` before write.

### Per-verdict gates

Five verifiers under `tools/verify/`:

- `p07-corpus-synthesizer-idempotent.sh` — runs the synthesizer twice, captures sha256 of each corpus before+after the second run, asserts equality.
- `p07-corpus-50-per-class-ready.sh` — invokes `shadow-compare.sh` against `corpus-50-per-class.jsonl`, greps `^flip_recommendation=ready$` from stdout.
- `p07-corpus-zero-evidence-insufficient.sh` — invokes `shadow-compare.sh` against `corpus-zero.jsonl`, greps `^flip_recommendation=evidence_insufficient$` from stdout.
- `p07-corpus-2-class-partially-ready.sh` — invokes `shadow-compare.sh` against `corpus-2-class-only.jsonl`, greps `^flip_recommendation=partially_ready$` AND asserts the enumeration line names `mechanical` and `standard` (the flippable classes; the exact enumeration line shape is determined by reading `scripts/diagnostics/shadow-compare.sh` body — likely `flippable_classes=mechanical,standard` per FR-8 prose).
- `p07-corpus-block.sh` — invokes `shadow-compare.sh` against `corpus-block.jsonl`, greps `^flip_recommendation=block$` from stdout.

All five gates emit `SUMMARY: <verifier-name> pass=N fail=M` and exit 0 iff every assertion holds. AD-19 single-script-file shape; no `(...)` subshells, no `$()` containing pipes, no compound chains > 2 commands.

## Steps

1. **Read `scripts/diagnostics/shadow-compare.sh` body** to confirm the enumeration-line shape for `partially_ready` (line 277 region per the grep snapshot — exact field name `flippable_classes=` vs. some other token). Record the exact shape; the T01 `p07-corpus-2-class-partially-ready.sh` verifier asserts against this exact shape.

2. **Read one record from `tests/fixtures/m030-p02/shadow-corpus-ready.jsonl`** to confirm the JSON field set + ordering. The synthesizer emits records matching this shape. Notable fields used by P07: `record_type`, `unitId`, `milestone`, `phase`, `task`, `backend`, `classifier_confidence`, `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`. Optional fields: `character`, `override_source`, `escalation_count`, `escalation_reason`. Earlier-phase fixtures may not carry the latter; P07 corpora carry the full superset for cross-surface gates.

3. **Author `tests/m030-acceptance/shadow-corpus-fixtures.sh`** as a bash 3.2-compatible idempotent synthesizer. Shape:

   ```bash
   #!/usr/bin/env bash
   # tests/m030-acceptance/shadow-corpus-fixtures.sh
   # Idempotent acceptance-corpus synthesizer for M030/P07.
   # Generates four corpora exercising the four shadow-compare.sh verdicts.
   set -euo pipefail
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   OUT_DIR="$SCRIPT_DIR"
   mkdir -p "$OUT_DIR"

   # Helper: emit one dispatch_usage record. Args:
   #   $1 unit_id  $2 milestone  $3 phase  $4 task  $5 character (mechanical|standard|novel)
   #   $6 model_routed (fast|balanced|smart)  $7 model_used  $8 confidence (high|medium|low)
   #   $9 timestamp_iso8601
   emit_record() {
     printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"stub","input_tokens_estimate":1024,"output_tokens_estimate":0,"estimated_cost_usd":0.01536000,"pricing_version":"2026-04-17","filter_dropped_tokens":0,"tier1_savings_tokens":0,"tier2_savings_tokens":0,"tier1_invocations":0,"tier3_compression_savings_tokens":0,"tier3_invocations":0,"model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s","classifier_confidence":"%s","model_routed":"%s","model_used":"%s","partial_flip_active":false,"withheld_classes":"","character":"%s"}\n' \
       "$1" "$2" "$3" "$4" "$7" "$9" "$8" "$6" "$7" "$5"
   }

   # Helper: emit N records of a given class with deterministic timestamps.
   # Args: $1 class  $2 count  $3 model_routed  $4 confidence  $5 base_minute
   emit_class_records() {
     local class="$1" count="$2" routed="$3" conf="$4" base_minute="$5"
     local i=0
     while [ "$i" -lt "$count" ]; do
       local minute=$((base_minute + i))
       local ts="$(printf '2026-04-30T%02d:%02d:00Z' $((minute / 60)) $((minute % 60)))"
       emit_record "M999/P01/T$(printf '%03d' "$i")" "M999" "P01" "T$(printf '%03d' "$i")" \
         "$class" "$routed" "$routed" "$conf" "$ts"
       i=$((i + 1))
     done
   }

   # ---------- corpus-50-per-class.jsonl (drives ready) ----------
   {
     emit_class_records "mechanical" 50 "fast"     "high" 0
     emit_class_records "standard"   50 "balanced" "high" 50
     emit_class_records "novel"      50 "smart"    "high" 100
   } > "$OUT_DIR/corpus-50-per-class.jsonl"

   # ---------- corpus-zero.jsonl (drives evidence_insufficient) ----------
   : > "$OUT_DIR/corpus-zero.jsonl"

   # ---------- corpus-2-class-only.jsonl (drives partially_ready) ----------
   {
     emit_class_records "mechanical" 50 "fast"     "high" 0
     emit_class_records "standard"   50 "balanced" "high" 50
   } > "$OUT_DIR/corpus-2-class-only.jsonl"

   # ---------- corpus-block.jsonl (drives block) ----------
   # 20 records per class, low confidence to push stability variance ABOVE
   # the floor for at least one class whose default is NOT `smart`. The
   # alternation between high/low confidence values within the mechanical
   # class produces high rolling variance.
   {
     # mechanical: alternating confidence to break stability
     local i=0
     while [ "$i" -lt 20 ]; do
       local conf="high"
       [ $((i % 2)) -eq 0 ] && conf="low"
       local ts="$(printf '2026-04-30T%02d:%02d:00Z' $((i / 60)) $((i % 60)))"
       emit_record "M999/P02/T$(printf '%03d' "$i")" "M999" "P02" "T$(printf '%03d' "$i")" \
         "mechanical" "fast" "fast" "$conf" "$ts"
       i=$((i + 1))
     done
     emit_class_records "standard" 20 "balanced" "low" 20
     emit_class_records "novel"    20 "smart"    "low" 40
   } > "$OUT_DIR/corpus-block.jsonl"

   echo "SYNTHESIZED: corpus-50-per-class.jsonl corpus-zero.jsonl corpus-2-class-only.jsonl corpus-block.jsonl"
   ```

   Notes:
   - The exact confidence-distribution that drives `block` vs `partially_ready` depends on `shadow-compare.sh`'s rolling-variance threshold. Read the script body during T01 authoring to confirm the threshold; tune the alternation window in the `corpus-block.jsonl` synthesis to land above it. If the threshold is configurable via env, set it explicitly in the verifier so the corpus + threshold ship as a coupled pair.
   - The `local` keyword inside the `corpus-block.jsonl` block requires a function context — refactor to a helper function if `set -e`'s POSIX-strict pickup rejects it. Acceptable rewrite: lift the inline mechanical loop to a helper named `emit_block_mechanical_records` declared above the corpus generator block.

4. **Make synthesizer executable**:

   ```bash
   chmod +x tests/m030-acceptance/shadow-corpus-fixtures.sh
   ```

5. **Run synthesizer to populate corpora**:

   ```bash
   bash tests/m030-acceptance/shadow-corpus-fixtures.sh
   ```

   Confirm via `wc -l tests/m030-acceptance/corpus-*.jsonl` that the four files report 150/0/100/60 lines respectively.

6. **Validate the corpora exercise the expected verdicts** by running `shadow-compare.sh` against each:

   ```bash
   M030_SHADOW_COMPARE_CORPUS=tests/m030-acceptance/corpus-50-per-class.jsonl bash scripts/diagnostics/shadow-compare.sh
   M030_SHADOW_COMPARE_CORPUS=tests/m030-acceptance/corpus-zero.jsonl bash scripts/diagnostics/shadow-compare.sh
   M030_SHADOW_COMPARE_CORPUS=tests/m030-acceptance/corpus-2-class-only.jsonl bash scripts/diagnostics/shadow-compare.sh
   M030_SHADOW_COMPARE_CORPUS=tests/m030-acceptance/corpus-block.jsonl bash scripts/diagnostics/shadow-compare.sh
   ```

   Confirm the four verdicts come out as expected. If `corpus-block.jsonl` lands as `partially_ready` instead of `block`, tune the confidence-distribution in step 3 (more alternation, or push more classes below stability) until `block` fires.

   Note: the env-var name above (`M030_SHADOW_COMPARE_CORPUS`) is one of the documented seam-points per `scripts/diagnostics/shadow-compare.sh` body. If the script also accepts a positional argument or `--corpus` flag, prefer whichever shape the existing P02 verifiers use (`tools/verify/p02-shadow-compare-verdicts.sh` is the reference).

7. **Author `tools/verify/p07-corpus-synthesizer-idempotent.sh`**:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p07-corpus-synthesizer-idempotent.sh
   # Asserts shadow-corpus-fixtures.sh is idempotent (re-running produces
   # byte-identical corpora).
   set -uo pipefail
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

   pass=0
   fail=0

   bash "$PROJECT_ROOT/tests/m030-acceptance/shadow-corpus-fixtures.sh" >/dev/null
   sha_before_50="$(sha256sum "$PROJECT_ROOT/tests/m030-acceptance/corpus-50-per-class.jsonl" | awk '{print $1}')"
   sha_before_zero="$(sha256sum "$PROJECT_ROOT/tests/m030-acceptance/corpus-zero.jsonl" | awk '{print $1}')"
   sha_before_2cls="$(sha256sum "$PROJECT_ROOT/tests/m030-acceptance/corpus-2-class-only.jsonl" | awk '{print $1}')"
   sha_before_block="$(sha256sum "$PROJECT_ROOT/tests/m030-acceptance/corpus-block.jsonl" | awk '{print $1}')"

   bash "$PROJECT_ROOT/tests/m030-acceptance/shadow-corpus-fixtures.sh" >/dev/null
   sha_after_50="$(sha256sum "$PROJECT_ROOT/tests/m030-acceptance/corpus-50-per-class.jsonl" | awk '{print $1}')"
   sha_after_zero="$(sha256sum "$PROJECT_ROOT/tests/m030-acceptance/corpus-zero.jsonl" | awk '{print $1}')"
   sha_after_2cls="$(sha256sum "$PROJECT_ROOT/tests/m030-acceptance/corpus-2-class-only.jsonl" | awk '{print $1}')"
   sha_after_block="$(sha256sum "$PROJECT_ROOT/tests/m030-acceptance/corpus-block.jsonl" | awk '{print $1}')"

   if [ "$sha_before_50" = "$sha_after_50" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: corpus-50-per-class.jsonl drifted"; fi
   if [ "$sha_before_zero" = "$sha_after_zero" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: corpus-zero.jsonl drifted"; fi
   if [ "$sha_before_2cls" = "$sha_after_2cls" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: corpus-2-class-only.jsonl drifted"; fi
   if [ "$sha_before_block" = "$sha_after_block" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: corpus-block.jsonl drifted"; fi

   printf 'SUMMARY: p07-corpus-synthesizer-idempotent.sh pass=%s fail=%s\n' "$pass" "$fail"
   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

   Note: macOS may name `sha256sum` as `shasum -a 256`. Detect at runtime and fall back. Helper-function-carve-out per AD-19 helper-function discipline.

8. **Author the four per-verdict gates** (`p07-corpus-50-per-class-ready.sh`, `p07-corpus-zero-evidence-insufficient.sh`, `p07-corpus-2-class-partially-ready.sh`, `p07-corpus-block.sh`). Each follows the same shape:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p07-corpus-<verdict>.sh
   set -uo pipefail
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   CORPUS="$PROJECT_ROOT/tests/m030-acceptance/<corpus-file>.jsonl"

   pass=0
   fail=0

   stdout_capture="$(M030_SHADOW_COMPARE_CORPUS="$CORPUS" bash "$PROJECT_ROOT/scripts/diagnostics/shadow-compare.sh")"
   rc=$?
   if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: shadow-compare.sh exited $rc"; fi

   if echo "$stdout_capture" | grep -qE '^flip_recommendation=<verdict>$'; then
     pass=$((pass + 1))
   else
     fail=$((fail + 1))
     echo "FAIL: expected flip_recommendation=<verdict>; got:"
     echo "$stdout_capture"
   fi

   printf 'SUMMARY: p07-corpus-<verdict>.sh pass=%s fail=%s\n' "$pass" "$fail"
   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

   For `p07-corpus-2-class-partially-ready.sh`: ALSO assert the enumeration line names `mechanical` and `standard`. Read `shadow-compare.sh` body during T01 authoring to confirm the exact enumeration shape (likely `flippable_classes=mechanical,standard` based on the grep snapshot at line 277 region of shadow-compare.sh). If the shape is different (e.g., space-delimited, or per-class lines), the verifier asserts whichever shape the script actually emits — verify in step 6's stdout output.

   Plan-Time Discipline rule 3 (classifier-shape pre-validation): the `M030_SHADOW_COMPARE_CORPUS=... bash ...` invocation is a single-leading-env-var-then-command shape, NOT a compound chain — verified by inspection against the [M021](../../../../../milestones/M021/index.md) shape classifier conventions (env-var prefix is part of the same word-list as the command).

9. **Make all five new verifiers executable**:

   ```bash
   chmod +x tools/verify/p07-corpus-synthesizer-idempotent.sh tools/verify/p07-corpus-50-per-class-ready.sh tools/verify/p07-corpus-zero-evidence-insufficient.sh tools/verify/p07-corpus-2-class-partially-ready.sh tools/verify/p07-corpus-block.sh
   ```

10. **Self-check each verifier**:

    ```bash
    bash tools/verify/p07-corpus-synthesizer-idempotent.sh
    bash tools/verify/p07-corpus-50-per-class-ready.sh
    bash tools/verify/p07-corpus-zero-evidence-insufficient.sh
    bash tools/verify/p07-corpus-2-class-partially-ready.sh
    bash tools/verify/p07-corpus-block.sh
    ```

    Expected: each emits `SUMMARY: <name> pass=N fail=0` and exits 0.

11. **Confirm artifact predicates against `P07-PLAN.md` declarations** by running the must-haves checker (only the T01 deliverables will be present at this point — most artifact rows are owned by T02/T03/T04):

    ```bash
    bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P07
    ```

    Expect MIXED output — T01 artifacts PASS; T02/T03/T04 artifacts FAIL because they don't exist yet. Capture the output for sanity-check; do NOT fix the FAILs in T01 (they belong to downstream tasks).

## Must-Haves

T01 satisfies the following P07 phase truths:

- `bash tests/m030-acceptance/shadow-corpus-fixtures.sh` is idempotent — gated by `bash tools/verify/p07-corpus-synthesizer-idempotent.sh`.
- `bash scripts/diagnostics/shadow-compare.sh` against `corpus-50-per-class.jsonl` emits `flip_recommendation=ready` — gated by `bash tools/verify/p07-corpus-50-per-class-ready.sh`.
- `bash scripts/diagnostics/shadow-compare.sh` against `corpus-zero.jsonl` emits `flip_recommendation=evidence_insufficient` — gated by `bash tools/verify/p07-corpus-zero-evidence-insufficient.sh`.
- `bash scripts/diagnostics/shadow-compare.sh` against `corpus-2-class-only.jsonl` emits `flip_recommendation=partially_ready` + flippable-classes enumeration — gated by `bash tools/verify/p07-corpus-2-class-partially-ready.sh`.
- `bash scripts/diagnostics/shadow-compare.sh` against `corpus-block.jsonl` emits `flip_recommendation=block` — gated by `bash tools/verify/p07-corpus-block.sh`.

## Verification

```bash
bash tools/verify/p07-corpus-synthesizer-idempotent.sh
bash tools/verify/p07-corpus-50-per-class-ready.sh
bash tools/verify/p07-corpus-zero-evidence-insufficient.sh
bash tools/verify/p07-corpus-2-class-partially-ready.sh
bash tools/verify/p07-corpus-block.sh
```

All five must exit 0 with `SUMMARY: <name> pass=N fail=0` before T01 closes.

## Inputs

### From Previous Tasks

None — T01 is the first P07 task.

### From Disk (Pre-existing)

- `scripts/diagnostics/shadow-compare.sh` — Key API: reads corpus from `M030_SHADOW_COMPARE_CORPUS` env (or positional arg / `--corpus` flag — check script body); emits `flip_recommendation=<ready|partially_ready|block|evidence_insufficient>` line + per-class evidence lines + (for partially_ready) a flippable-classes enumeration line. Exit 0 on all valid input. Used by every P07 per-verdict gate.
- `scripts/dispatch/dispatch-interface.sh` — reference for the `dispatch_usage` JSON record shape. T01 synthesizer emits records matching this shape (see lines 630 and 666 of dispatch-interface.sh for the canonical printf format). Critical fields: `unitId`, `milestone`, `phase`, `task`, `backend`, `classifier_confidence`, `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`, `character`.
- `tests/fixtures/m030-p02/shadow-corpus-{ready,partially-ready,block,evidence-insufficient}.jsonl` — read-only reference for record shape + per-class distribution. T01's corpora at `tests/m030-acceptance/` are STRUCTURALLY similar but at full acceptance scale (50/class for ready/partially-ready, 60 records for block).
- `templates/model-routing.yml` — declares `mechanical → fast`, `standard → balanced`, `novel → smart` (the routing-table mapping that constrains the synthesizer's `model_routed` field per class).

## Constraints

- **AD-19 single-script-file shape**: all five new verifiers + the synthesizer use single-builtin shape. No `(...)` subshells, no `$()` containing pipes, no compound chains > 2 commands. Helper-function-carve-out per M028/P02/T05 — function bodies are exempt from inline-shape scans.
- **Bash 3.2 compatibility**: synthesizer + verifiers use parallel scalars + `if`-statements. No `declare -A`, no `mapfile`, no `[[:alpha:]]` regex inside body classifiers. `local` only inside function contexts.
- **CON-2 / FR-19 / SC-11**: T01 emits a NEW corpus at `tests/m030-acceptance/`; it does NOT modify pre-M030 fixtures. The existing `tests/fixtures/m030-p02/*` corpora remain byte-untouched.
- **Project-owned-verifier-paths discipline ([M032](../../../../../milestones/M032/index.md) Finding A)**: the five new verifiers live under `tools/verify/` with slug-bearing filename `p07-*.sh`. The synthesizer + corpora live under `tests/m030-acceptance/` (NOT `tests/fixtures/`) per the roadmap line 68 boundary-map produce declarations.
- **Plan-Time Discipline rule 4 (run-probe.sh scope)**: T01 invokes verifiers and the synthesizer directly via `bash <path>`. No `run-probe.sh` wrapping (these paths are repo-resident).
- **CON-6 (shadow-corpus-immutability)**: T01's corpora are write-once-then-read-only. The synthesizer overwrites in idempotent fashion (byte-identical output), but does NOT retroactively rewrite individual records.

## Expected Output

- `tests/m030-acceptance/shadow-corpus-fixtures.sh` — idempotent synthesizer; bash 3.2 compatible.
- `tests/m030-acceptance/corpus-50-per-class.jsonl` (150 lines), `corpus-zero.jsonl` (0 lines), `corpus-2-class-only.jsonl` (100 lines), `corpus-block.jsonl` (60 lines).
- `tools/verify/p07-corpus-synthesizer-idempotent.sh` — sha256-equality gate over the four corpora across two synthesizer invocations.
- `tools/verify/p07-corpus-50-per-class-ready.sh`, `p07-corpus-zero-evidence-insufficient.sh`, `p07-corpus-2-class-partially-ready.sh`, `p07-corpus-block.sh` — each invokes `shadow-compare.sh` against its corpus and asserts the expected `flip_recommendation=` verdict.

All five verifiers exit 0 with `SUMMARY: <name> pass=N fail=0`.

## Notes

Expected output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tests/m030-acceptance/shadow-corpus-fixtures.sh` → `SYNTHESIZED: corpus-50-per-class.jsonl corpus-zero.jsonl corpus-2-class-only.jsonl corpus-block.jsonl`, exit 0.
- `wc -l tests/m030-acceptance/corpus-*.jsonl` → `100 corpus-2-class-only.jsonl / 150 corpus-50-per-class.jsonl / 60 corpus-block.jsonl / 0 corpus-zero.jsonl / 310 total` (alphabetical order).
- `bash tools/verify/p07-corpus-synthesizer-idempotent.sh` → `SUMMARY: p07-corpus-synthesizer-idempotent.sh pass=4 fail=0`, exit 0.
- `M030_SHADOW_COMPARE_CORPUS=tests/m030-acceptance/corpus-50-per-class.jsonl bash scripts/diagnostics/shadow-compare.sh` → stdout begins with per-class evidence lines + a `flip_recommendation=ready` final line, exit 0.

If the `corpus-block.jsonl` confidence-distribution doesn't reliably drive `block` instead of `partially_ready` (e.g., the rolling-variance threshold is more permissive than expected), the plan-amendment-not-task-reopen pattern from P02-P06 applies — tune the alternation window in the synthesizer (more frequent low/high alternation, or stretch one class's confidence values to span the full range), retest step 6, and AMEND the synthesizer steps in this plan to record the chosen distribution. Do NOT change `shadow-compare.sh`'s threshold to make the corpus pass; the corpus must drive the existing threshold.

If `shadow-compare.sh`'s `partially_ready` enumeration line uses a shape other than `flippable_classes=mechanical,standard` (e.g., `flippable_classes=[mechanical, standard]` or per-class indented lines), AMEND the `p07-corpus-2-class-partially-ready.sh` grep regex to match the actual shape AND amend the corresponding artifact `contains` predicate in `P07-PLAN.md` so `check-must-haves.sh` keeps passing. The verifier asserts the existing script's behavior; the script is the contract.

If macOS lacks `sha256sum`, the synthesizer-idempotent verifier should fall back to `shasum -a 256` (BSD-portable). Detect via `command -v sha256sum >/dev/null 2>&1` and define a `_sha256()` helper at the top of the script, then call `_sha256 <path>` in place of `sha256sum <path> | awk '{print $1}'`. Helper-function-carve-out applies — the helper body is exempt from AD-19 inline-shape scans.

The synthesizer's `corpus-zero.jsonl` is intentionally a 0-line file (empty). The `:` builtin redirected to the path creates an empty file on first run and truncates it on re-run; sha256 of an empty file is the well-known constant `e3b0c4...` and is byte-identical across runs. The verifier doesn't need a special-case for the empty corpus.
