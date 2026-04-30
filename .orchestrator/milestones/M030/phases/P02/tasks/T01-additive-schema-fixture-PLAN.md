---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M030"
name: "SC-11 byte-equality fixture + additive-schema gate (preflight)"
depends_on: []
---

## Prerequisites

- `scripts/dispatch/dispatch-interface.sh` exists in its pre-P02 form (the M019/P01/T03 + M018/P05/T01 + M018/P06/T02 emitter shape — `_di_emit_dispatch_usage` writes records with the field set documented at `dispatch-interface.sh:283-308`).
- `scripts/dispatch/classify-task.sh` exists (P01/T02 close — present at the file path; T01 does not invoke it but T02 will).
- `templates/model-routing.yml` exists (P01/T03 close).
- `references/model-routing.md` exists with the `## Classifier-Confidence Stability Metric` section (P01/T03 close).
- Existing pre-M030 JSONL reference fixtures are on disk for shape comparison: `tests/fixtures/m027-p00/pre-m019-mixed.jsonl`, `tests/fixtures/m019-p01/pre-m019-execution-log.jsonl`, `tests/fixtures/m019-p01/post-m019-rollup-demo.jsonl`. T01 does NOT modify these — they are read-only references for the canonical pre-M030 `dispatch_usage` field set.

Plan-time prerequisite-existence verification: every path above resolves under `[ -f <path> ]` at plan-authoring time. Confirmed via P01-SUMMARY.md `key_files:` block (`scripts/dispatch/classify-task.sh`, `templates/model-routing.yml`, `references/model-routing.md` are all P01 deliverables). The pre-M030 reference fixtures were inventoried during plan-authoring (`find tests/fixtures -name '*.jsonl'` returned the M019/M027 fixtures cited above).

## Description

T01 ships the SC-11 byte-equality contract BEFORE T02 amends `dispatch-interface.sh`. This mirrors P01's D-A4 timeline-graduation discipline: the additive-only invariant gets a mechanical gate that exists at the moment the dispatch-interface diff lands.

Two deliverables:

1. **`tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl`** — the byte-equality golden file. Five canonical `dispatch_usage` records spanning the three pre-M030 emit shapes:
   - **Happy-path** (3 records): `estimated_cost_usd: <float>`, no `pricing_warning` field.
   - **Pricing-warning** (1 record): `estimated_cost_usd: null`, `pricing_warning: "<reason>"` field present.
   - **Cost-null degradation** (1 record): `estimated_cost_usd: null`, `pricing_warning: "adapter-failed"` (the override-branch shape from `dispatch-interface.sh:294-309`).

   Each record contains the canonical pre-M030 field set in canonical order — exact field order matters for byte-equality. The fixture is captured by inspecting the `printf` format strings in `dispatch-interface.sh:283-309` (the live emitter); the field order in the fixture MUST mirror those `printf` templates byte-for-byte. The five records exercise:
   - distinct `unitId` values (M001/P01/T01, M005/P03/T02, M019/P01/T03, M027/P00/T01, M020/P02/T03)
   - distinct `backend` values (`local-agent`, `local-codex`, `stub`)
   - both `model: "claude-opus-4-7"` and `model: ""` (empty model — the pre-INTENSITY_METADATA case)
   - non-zero `filter_dropped_tokens`/`tier1_savings_tokens`/etc. on at least one record (M018/P05 carry-forward path)
   - non-zero `tier3_compression_savings_tokens`/`tier3_invocations` on at least one record (M018/P06 carry-forward path)

2. **`tools/verify/p02-fixture-shape.sh`** — asserts the fixture is well-formed. Checks per record: starts with `{"record_type":"dispatch_usage"`; ends with a closing `}` (one record per line); contains the load-bearing pre-M030 field tokens (`unitId`, `backend`, `input_tokens_estimate`, `output_tokens_estimate`, `estimated_cost_usd`, `pricing_version`, `filter_dropped_tokens`, `tier1_savings_tokens`, `tier1_invocations`, `tier3_compression_savings_tokens`, `tier3_invocations`, `model`, `source`, `emission_point`, `timestamp`); does NOT contain any of the new P02 fields (`model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`).

3. **`tools/verify/p02-additive-schema.sh`** — the SC-11 gate. Stages a controlled invocation of `dispatch-interface.sh` against a fixture task plan + payload + intensity-metadata under `M030_SHADOW_MODE=0` (or unset) and `unset CLAUDECODE` to force the non-shadow path. Captures the appended `dispatch_usage` line from a freshly-staged log file. `diff`s the captured line against the corresponding fixture record. Passes iff `diff` exits 0 (byte-identical). Repeats for at least 3 of the 5 fixture-record shapes (happy-path with `model="claude-opus-4-7"`; happy-path with `model=""`; pricing-warning record). The malformed-or-cost-null records are out of scope for round-trip (those depend on adapter-failed branches that need a crashing adapter fixture); T01 verifies their presence via `grep -F` only.

   Key discipline: the verifier MUST establish the fixture-equivalence environment so the emitter produces byte-identical output to the fixture. That means staging a payload with the recorded `payload_bytes` (which yields the recorded `input_tokens_estimate` via `chars_to_tokens_quartile`), an intensity-metadata file with the recorded `model:` line, the recorded `ORCH_ROOT` (an empty fixture milestone dir), the recorded `MILESTONE_ID`/`PHASE_ID`/`TASK_ID` (extractable from the `unitId`), and the recorded `BACKEND`. The verifier's per-record harness is a small bash function that takes (unitId, backend, model, payload_bytes, expected_record_line) and exits non-zero on diff mismatch.

T01 does NOT modify `scripts/dispatch/dispatch-interface.sh`. The verifier passes against the pre-amendment emitter today (round-trip preserves the existing field set). After T02 lands its amendment, this same verifier MUST continue to pass — that is the additive-only contract.

### Why this discipline

Plan-Time Discipline rule 2 (verifier-availability cross-check) requires every Verification command to resolve to an existing-on-disk script at plan-authoring time. By co-authoring `p02-additive-schema.sh` in T01 BEFORE T02's emitter amendment, the additive-only invariant cannot be silently broken: T02's first `bash tools/verify/p02-additive-schema.sh` run after the amendment is the contract. If T02 inserts a new field in the wrong position (e.g., between existing fields rather than at the end), or under the wrong gate (e.g., emitted unconditionally rather than only under `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`), the additive-schema verifier fails immediately.

This is the same shape P01/T01 used for D-A4: ship the gate before the deliverable; the deliverable's first run becomes the contract proof.

## Steps

1. **Inventory the pre-M030 `dispatch_usage` field set.** Read `scripts/dispatch/dispatch-interface.sh` lines 283-309 (the two `printf` templates inside `_di_emit_dispatch_usage`). Record the field order verbatim:

   Happy path (line 283):
   `record_type, unitId, milestone, phase, task, backend, input_tokens_estimate, output_tokens_estimate, estimated_cost_usd, pricing_version, filter_dropped_tokens, tier1_savings_tokens, tier2_savings_tokens, tier1_invocations, tier3_compression_savings_tokens, tier3_invocations, model, source, emission_point, timestamp`

   Degradation path (line 298): same field set with `estimated_cost_usd: null` literal + `pricing_warning` field inserted between `tier3_invocations` and `model`.

2. **Author `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl`.** Create the directory: `mkdir -p tests/fixtures/m030-p02`. Hand-author 5 records using the field order from Step 1. Use realistic values (e.g., `input_tokens_estimate: 8704`, `pricing_version: "2026-04-25"`, `timestamp: "2026-04-29T10:30:00Z"`). All five MUST be byte-correct JSONL — no trailing comma, no extra whitespace, single-line per record, terminating newline at file end. Reference the M019/M027 fixtures (`tests/fixtures/m019-p01/post-m019-rollup-demo.jsonl`) for canonical shape but DO NOT copy them verbatim — author records that exercise the carry-forward fields M018/P06 added (which the M019 fixtures predate).

3. **Author `tools/verify/p02-fixture-shape.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape (no compound chains, no inline `for` loops, no `$(...)` containing pipes). The verifier:

   - Asserts the fixture file exists at `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl`.
   - Asserts line count >= 5 via `wc -l` written through a tmp file (to avoid AP-009 compound shapes): `wc -l < tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl > /tmp/p02-fixture-linecount.txt`; read `/tmp/p02-fixture-linecount.txt`; assert >=5.
   - For each required pre-M030 token (15 tokens listed in the Description), `grep -q -F '<token>' tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl`; on miss, `fail=$((fail+1))` + diagnostic.
   - For each forbidden P02 token (`model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`), assert absence via `grep -q -F '<token>' tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` returning 1; on present, `fail=$((fail+1))` + diagnostic.
   - Emits `SUMMARY: p02-fixture-shape.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

4. **Stage a fixture milestone directory + plan + payload for the round-trip harness.** Create `tests/fixtures/m030-p02/round-trip-stage/` with:

   - `phases/P01/tasks/T01-stage-PLAN.md` — minimal task plan; the file's path encodes `M001/P01/T01` for `unitId` extraction.
   - `phases/P01/tasks/T01-stage-PAYLOAD.md` — payload of a known byte length (e.g., exactly 4096 bytes for `input_tokens_estimate=1024` after quartile rounding — verified after creation via `wc -c`).
   - `intensity-metadata.txt` — single line: `model: "claude-opus-4-7"`.

   These files are committed to the repo as fixture inputs for `p02-additive-schema.sh`. Path discipline: under `tests/fixtures/m030-p02/round-trip-stage/` only — does NOT touch real `.orchestrator/milestones/`.

5. **Author `tools/verify/p02-additive-schema.sh`.** Bash 3.2-compatible. Shape rules:

   - Stages an empty log file at `<round-trip-stage>/execution-log.jsonl` (rm + touch).
   - Sets env: `unset CLAUDECODE; unset M030_SHADOW_MODE; export ORCHESTRATOR_ROOT=<round-trip-stage>`. (Force the non-shadow path; the `ORCH_ROOT` carve-out at `dispatch-interface.sh:242` then logs to `<round-trip-stage>/execution-log.jsonl`.)
   - Invokes `bash scripts/dispatch/dispatch-interface.sh --task-plan <stage>/phases/P01/tasks/T01-stage-PLAN.md --payload <stage>/phases/P01/tasks/T01-stage-PAYLOAD.md --intensity-metadata <stage>/intensity-metadata.txt --backend stub` and discards stdout (the adapter result is irrelevant).
   - Reads the appended JSONL line from `<round-trip-stage>/execution-log.jsonl`.
   - Constructs an "expected" line by formatting the same fields with the same values used in the fixture (modulo `timestamp`, which is dynamic — strip the `timestamp:` field from both sides before diff, OR overwrite both sides' timestamps to a fixed value before diff). Actual diff approach: extract every field EXCEPT `timestamp` from both lines via `sed 's/"timestamp":"[^"]*"/"timestamp":"<NORMALIZED>"/'` to both sides, then `diff` the two normalized strings.
   - Fixture-record correspondence: the round-trip stage uses the same `unitId`/`backend`/`payload_bytes`/`model` tuple as the first happy-path fixture record. The expected line is that fixture record (with timestamp normalized).
   - On `diff` exit 0: `pass=$((pass+1))`. On non-zero: `fail=$((fail+1))`, print the actual + expected lines for diagnostic visibility.
   - Repeat the round-trip for at least 2 additional fixture-record shapes (happy-path with `model=""`; pricing-warning record — staged by passing an `intensity-metadata.txt` that triggers the pricing-warning path or by setting `ORCH_PRICING_NO_RATE=1` if such a knob exists; if it does not, the verifier covers the pricing-warning shape via `grep -F` only and emits a `WARN:` line documenting the gap).
   - Cleanup: `rm -f <round-trip-stage>/execution-log.jsonl` at end (idempotent for re-run).
   - Emits `SUMMARY: p02-additive-schema.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

6. **Run the new verifiers as a self-check.** Execute:

   ```bash
   bash tools/verify/p02-fixture-shape.sh
   bash tools/verify/p02-additive-schema.sh
   ```

   Expected: both exit 0 with `SUMMARY: <name> pass=N fail=0`. If `p02-additive-schema.sh` fails, the failure mode is one of: (a) the fixture's field order does not match `dispatch-interface.sh:283`'s `printf` template (re-author the fixture); (b) the round-trip stage's payload byte count doesn't yield the expected `input_tokens_estimate` (adjust payload size); (c) a non-additive field has appeared in the unmodified emitter (extremely unlikely — would indicate an upstream regression to investigate before touching P02).

7. **Stage and commit.** Stage `tests/fixtures/m030-p02/` (entire dir tree), `tools/verify/p02-fixture-shape.sh`, `tools/verify/p02-additive-schema.sh`. Commit with `git commit -F <message-file>` (multi-line message file authored via Write tool). Recommended message: `M030/P02/T01: SC-11 byte-equality fixture + additive-schema gate (preflight)`.

   Do NOT use the inline-HEREDOC `git commit -m "$(cat <<'EOF' ... EOF)"` form — AP-008 (`heredoc-with-expansion`) blocks it. Author a message file via Write to e.g. `/tmp/p02-t01-commit-msg.txt`, then `git commit -F /tmp/p02-t01-commit-msg.txt`.

## Must-Haves

This task satisfies the phase truths:

- "A pre-M030 `dispatch_usage` JSONL fixture (`tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl`) exists at version-control..." — gated by `tools/verify/p02-fixture-shape.sh`.
- "SC-11 byte-equality holds: when `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` is round-tripped through `scripts/dispatch/dispatch-interface.sh`'s emit path under `M030_SHADOW_MODE=0`..." — gated by `tools/verify/p02-additive-schema.sh`.

## Verification

```bash
bash tools/verify/p02-fixture-shape.sh
bash tools/verify/p02-additive-schema.sh
```

Each verifier uses single-script-file shape per AD-19. Both must exit 0 before T01 closes.

## Inputs

### From Previous Tasks

- None. T01 is the P02 preflight; depends only on P01 closure.

### From Disk (Pre-existing)

- `scripts/dispatch/dispatch-interface.sh` — pre-P02 `_di_emit_dispatch_usage` body at lines 185-311; the two `printf` templates at lines 283-309 are the canonical pre-M030 field-order specification.
  - Key API: invoked via `bash scripts/dispatch/dispatch-interface.sh --task-plan <p> --payload <p> --intensity-metadata <p> --backend <b>`. Appends one `dispatch_usage` record per invocation to `<ORCH_ROOT>/execution-log.jsonl` (or `<ORCH_ROOT>/milestones/<MILESTONE>/execution-log.jsonl` per the routing logic at lines 242-248).
- `scripts/dispatch/adapters/backend/stub.sh` — minimal adapter that emits a conformant `dispatch-result.md` document. Used as the `--backend stub` argument so the round-trip harness doesn't require Claude Code or Codex CLI to be installed.
- `tests/fixtures/m027-p00/pre-m019-mixed.jsonl`, `tests/fixtures/m019-p01/post-m019-rollup-demo.jsonl` — read-only references for canonical pre-M030 record shape. T01 does NOT modify these.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. No `for` loops, no compound `&&`/`;` chains beyond the two-link cap, no `$(...)` containing pipes.
- **AP-009 compound-chain-gt2**: command-substitution that itself contains pipes triggers the shape-guard; the round-trip harness writes intermediate output to tmp files and reads back via separate commands rather than `result=$(cmd | grep | head)`.
- **CON-2/FR-19/SC-11 (additive-only schema)**: the fixture is the byte-equality golden file. T01 ships it BEFORE T02 amends the emitter so the additive-only invariant gets a mechanical gate at the moment the diff lands. This task itself does NOT modify `dispatch-interface.sh`.
- **Plan-Time Discipline rule 4 (`run-probe.sh` scope)**: `tools/verify/p02-*.sh` are repo-resident verifiers under `tools/verify/`; they are invoked directly via `bash tools/verify/<path>`, NOT wrapped in `run-probe.sh`. The fixture-staging in `tests/fixtures/m030-p02/round-trip-stage/` is a committed fixture, not a staged throwaway probe.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T01 does NOT introduce SQL or schema migrations — this rule does not apply. JSONL is line-oriented text; SC-11 is a byte-equality verifier, not a database integration test.
- **No /tmp/ pollution beyond the verifier's own scratch**: the round-trip harness writes only to `<round-trip-stage>/execution-log.jsonl` (committed fixture path) and `/tmp/p02-fixture-linecount.txt` (scratch — `rm -f` at verifier end).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. Parallel indexed arrays per MEM001 if multiple records need iteration.

## Expected Output

- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` — 5+ canonical pre-M030 `dispatch_usage` records.
- `tests/fixtures/m030-p02/round-trip-stage/` — staged plan + payload + intensity-metadata for the additive-schema verifier's round-trip harness.
- `tools/verify/p02-fixture-shape.sh` — fixture-shape verifier, green.
- `tools/verify/p02-additive-schema.sh` — SC-11 byte-equality verifier, green against pre-amendment `dispatch-interface.sh`.
- `bash tools/verify/p02-fixture-shape.sh` exits 0 with `SUMMARY: p02-fixture-shape.sh pass=N fail=0`.
- `bash tools/verify/p02-additive-schema.sh` exits 0 with `SUMMARY: p02-additive-schema.sh pass=N fail=0`.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p02-fixture-shape.sh` → 5 record shape checks pass + 4 forbidden-token-absence checks pass + line-count check pass; `SUMMARY: p02-fixture-shape.sh pass=10 fail=0`, exit 0.
- `bash tools/verify/p02-additive-schema.sh` → at least 2 round-trip diffs come back empty; `SUMMARY: p02-additive-schema.sh pass=N fail=0`, exit 0.

The fixture's load-bearing property is the field ORDER — JSONL byte-equality requires every field to appear in the same position relative to the others. The `printf` templates in `dispatch-interface.sh:283` and `:298` are the SSOT; the fixture mirrors them exactly. If T02 later inserts new fields BETWEEN existing fields rather than appending, this verifier catches it on the first run.

The pricing-warning round-trip is documented as `WARN:` rather than hard-FAIL because reproducing the pricing-warning state from a clean fixture environment requires either a stale-pricing-rate setup (M019 territory) or an adapter-failed branch (which yields the cost-null shape rather than the pricing-warning shape). Both are exercised in T01 via fixture grep-presence rather than full round-trip; T02's `p02-shadow-emit.sh` will exercise the shadow-on path under similar grep-only discipline where round-trip is impractical.

T01 establishes the pattern that T02's `p02-shadow-emit.sh` and `p02-append-only.sh` will inherit: fixture-staged invocations under controlled env vars, log-file capture, normalized-diff comparison.
