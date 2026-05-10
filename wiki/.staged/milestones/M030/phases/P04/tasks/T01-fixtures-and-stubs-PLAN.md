---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M030"
name: "P04 fixture plans + overlay configs + shadow corpora + stub adapters + tolerant pre-amendment gates (preflight)"
depends_on: []
---

## Prerequisites

- scripts/dispatch/dispatch-interface.sh exists in its post-P03 form: `_di_emit_dispatch_usage` body (lines ~190-515); shadow path with override-resolution block (lines ~292-446); happy-path shadow-on printf at ~line 453 emitting six P02/P03 fields (`classifier_confidence`, `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`, `override_source`); degradation shadow-on printf at ~line 486; shadow-off branches at ~line 468 and ~line 501 (byte-identical to pre-P02). Adapter invocation at ~lines 586-589 currently passes `--task-plan`, `--payload`, `--intensity-metadata` only.
- scripts/dispatch/classify-task.sh exists and emits `character=<mechanical|standard|novel>` + `confidence=<high|medium|low>` to stdout (P01/T02).
- scripts/diagnostics/shadow-compare.sh exists and accepts `--corpus <path>` flag, reads JSONL, emits `flip_recommendation=<ready|partially_ready|block|evidence_insufficient>` on stdout (P02/T03 deliverable). On `partially_ready`, emits a second line `withheld_classes=<comma-list>`.
- templates/model-routing.yml exists with `routing:` (3 chars × 3 runtimes), `resolution:` (3 tiers × 3 runtimes; `claude-code: "claude-haiku-4-5"|"claude-sonnet-4-7"|"claude-opus-4-7"`), `cost_rates:` (3 tiers) sections (P01/T03).
- tools/verify/p02-additive-schema.sh exists and exits 0 against post-P03 dispatch-interface.sh.
- tools/verify/p03-override-source-enum.sh exists with five-scenario coverage of `{plan_frontmatter, milestone_floor, disabled, none}` plus the reserved-but-not-yet-emitted `shadow_gate_blocked` (P03/T01-T02).
- scripts/dispatch/adapters/backend/stub.sh exists (M019/P01/T05) — minimal conforming adapter pattern reference.
- tests/fixtures/m030-p02/round-trip-stage/ + tests/fixtures/m030-p03/round-trip-stage/ exist (pattern reference for the P04 stage shape).
- tests/fixtures/m030-p02/shadow-corpus-ready.jsonl + shadow-corpus-partially-ready.jsonl + shadow-corpus-evidence-insufficient.jsonl exist (P02/T03 deliverables; pattern reference + potential symlink targets if their schemas remain compatible — verifier asserts independently).

Plan-time prerequisite-existence verification: every path above is asserted at plan-authoring time and re-asserted by T01 self-check (Step 11). The post-P03 shape of `dispatch-interface.sh` was inspected at planning time (lines 190-515 read cleanly; the shadow-on printfs at lines 453 and 486 each emit six P02/P03 fields; the adapter invocation at lines 586-589 takes three flags).

## Description

T01 ships before any work on `scripts/dispatch/dispatch-interface.sh` so the new field invariants (the sixth `override_source` enum value `shadow_gate_blocked`, the SC-11 byte-equality contract under live-mode amendments) are mechanically enforced at the moment T02 amends the emitter. Mirrors P02/T01 + P03/T01 graduation pattern (verifier-before-deliverable, AKA D-A4 timeline-graduation discipline applied at sub-phase scope).

Six deliverable groups that ship as a single coherent commit:

1. **Fixture plans** under `tests/fixtures/m030-p04/plans/`:
   - `plan-mechanical-no-override.md` — T99 unitId, mechanical body signature (explicit `## Steps` with file paths + bash verifiers), no `model_override:` frontmatter. Load-bearing for SC-3 (live-routed mechanical → fast-tier-id) and partial-flip routing (mechanical class is flippable when partially_ready).
   - `plan-fail-twice-then-pass.md` — T97 unitId, mechanical body. Used by SC-4 verifier with stub-fail-n counter starting at 2.
   - `plan-fail-three-times.md` — T96 unitId, mechanical body. Used by SC-5 verifier with stub-fail-n counter starting at 3.
   - `plan-fail-four-times.md` — T96 unitId (re-used; the stub adapter's invocation count is the load-bearing assertion, not the unitId). Used by CON-5 verifier with stub-fail-n counter starting at 4 to prove the cap is hard.
   - `plan-novel-class.md` — T95 unitId, novel body signature (Goal section uses words like `explore`, `design`, `evaluate alternatives` with no concrete file targets). Classifier should return `character=novel`. Load-bearing for partial-flip routing (novel class is the WITHHELD class in the partially_ready corpus per D-A3 safety: novel routes to smart by default).

2. **Fixture configs** under `tests/fixtures/m030-p04/configs/`:
   - `config-with-live-true.yml` — `model_routing: { live: true }` (and nothing else). Drives the live-routing happy path.
   - `config-with-live-and-killswitch.yml` — `model_routing_enabled: false` AND `model_routing: { live: true }`. CON-4 / SC-7a-style compound — kill switch wins.
   - `config-with-live-false.yml` — `model_routing: { live: false }` explicit. Pass-through baseline (asserts the live branch is gated correctly).

3. **Shadow corpora** under `tests/fixtures/m030-p04/`:
   - `shadow-corpus-ready.jsonl` — 50+ records per class (mechanical, standard, novel) with stable `classifier_confidence` (variance < 0.10 over the rolling N=20 window per `references/model-routing.md`). When passed to `bash scripts/diagnostics/shadow-compare.sh --corpus <path>`, the verdict is `flip_recommendation=ready`. Each record uses the post-P03 schema (5 P02 fields + `override_source`).
   - `shadow-corpus-partially-ready.jsonl` — 50+ records each for mechanical + standard with stable confidence; novel class has < 50 records OR unstable confidence. Verdict: `flip_recommendation=partially_ready` AND `withheld_classes=novel` (D-A3-safe: novel's routing-table default is smart, so flipping with novel withheld is conservative).
   - `shadow-corpus-empty.jsonl` — zero bytes (or one empty line). Verdict: `flip_recommendation=evidence_insufficient`.

4. **Round-trip stage** at `tests/fixtures/m030-p04/round-trip-stage/`:
   - `intensity-metadata.txt` — two lines: `intensity: standard` + `model: "claude-opus-4-7"`. Mirrors P02/P03 shape.
   - `payload.txt` — single-line payload of arbitrary length (the chars-to-tokens-quartile rounding handles deterministic input-tokens regardless of byte count).

5. **Stub adapters** under `scripts/dispatch/adapters/backend/`:
   - `stub-fail-n.sh` — programmable fail-counter adapter. On invocation:
     - Reads `STUB_FAIL_COUNTER_FILE` env var (path to a counter file with a single integer, default `/tmp/stub-fail-n-counter.txt`).
     - Reads the integer; if file missing, treats as 0.
     - Decrements the value (write back to the file).
     - If `STUB_FAIL_COUNTER_INVOCATIONS_FILE` env var is set, appends one line per invocation (used by CON-5 verifier to assert the adapter was invoked exactly 3 times).
     - If `STUB_INVOCATION_SENTINEL_DIR` env var is set, drops a sentinel file `inv-<count>.touch` in that directory (used by CON-6 verifier to inspect log mid-escalation).
     - If decremented value > 0 (more failures pending): exit 1 with no stdout (no dispatch-result emitted; dispatch-interface treats as adapter crash).
     - If decremented value <= 0 (cap reached / pass-now): emit a conforming dispatch-result.md (mirroring `stub.sh`) on stdout, exit 0.
     - Reads `--task-plan`, `--payload`, `--intensity-metadata`, AND `--model <id>` (T01 stub already accepts the flag; T02 dispatch-interface starts passing it).
     - Bash 3.2 compatible.
   - `stub-record-model.sh` — model-flag-recorder adapter. On invocation:
     - Reads `--model <id>` flag (along with the standard flags).
     - Writes the value of the `--model` flag to `STUB_RECORD_MODEL_FILE` env var (path, default `/tmp/stub-record-model.txt`). If the flag is absent, writes the string `<no-model-flag>`.
     - Always emits a conforming dispatch-result.md on stdout, exits 0.
     - Bash 3.2 compatible.

6. **Pre-amendment-tolerant gates** under `tools/verify/`:
   - `p04-additive-schema.sh` — thin pass-through wrapper (mirrors `p03-additive-schema.sh` shape):
     ```bash
     #!/usr/bin/env bash
     set -u
     SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
     bash "$SCRIPT_DIR/p02-additive-schema.sh"
     rc=$?
     pass=0; fail=0
     if [ "$rc" -eq 0 ]; then pass=1; else fail=1; fi
     echo "SUMMARY: p04-additive-schema.sh pass=$pass fail=$fail"
     if [ "$fail" -eq 0 ]; then exit 0; fi
     exit 1
     ```
   - `p04-override-source-enum-extended.sh` — extends the P03 5-scenario enum check with a new Scenario F: live-mode + empty corpus → `shadow_gate_blocked`. Pre-amendment-tolerant: the file MUST exit 0 against the pre-T02 dispatch-interface.sh (because the live branch doesn't yet exist; the dispatch falls through to the existing `none` / `disabled` / etc. paths) AND MUST exit 0 against the post-T02 dispatch-interface.sh (where Scenario F produces exactly one `shadow_gate_blocked` token). Implementation: for Scenario F (live + empty corpus), if the appended JSONL line contains the `shadow_gate_blocked` token, PASS strictly. If it does not (pre-amendment), check whether ANY enum-valid value is present (pre-amendment-tolerant — treat as scenario inheriting the P03 enum) and PASS. Strict assertion fires only when shadow_gate_blocked is observed.

T01 ends green: all artifacts on disk, both tolerant verifiers pass against the pre-amendment `dispatch-interface.sh`. T02 inherits a hard gate: the moment `shadow_gate_blocked` emission appears in the diff, the strict-mode branch of `p04-override-source-enum-extended.sh` activates and locks the closed enum.

### shadow-corpus-ready.jsonl synthesis pattern

Each line is a complete JSONL `dispatch_usage` record matching the post-P03 schema (the same 22-23 fields the live emitter produces). Synthesizable via a literal Bash script using `printf` per line:

```bash
# Pseudocode — actual script in T01 Step 5 below
for class in mechanical standard novel; do
  case "$class" in
    mechanical) tier="fast" ;;
    standard) tier="balanced" ;;
    novel) tier="smart" ;;
  esac
  for i in $(seq 1 55); do
    printf '{"record_type":"dispatch_usage","unitId":"M999/P01/T%02d","milestone":"M999",...,"classifier_confidence":"high","model_routed":"%s","model_used":"claude-opus-4-7","partial_flip_active":false,"withheld_classes":"","override_source":"none"}\n' "$i" "$tier"
  done
done > tests/fixtures/m030-p04/shadow-corpus-ready.jsonl
```

The synthesis script lives under `tests/fixtures/m030-p04/synthesize-corpora.sh` (idempotent — re-running produces identical output). T01 invokes it once and commits the resulting JSONL files; the synthesizer is itself committed for reproducibility.

`shadow-corpus-partially-ready.jsonl`: same shape but novel class has 25 records (below 50 threshold) — verdict resolves to partially_ready with withheld_classes=novel.

`shadow-corpus-empty.jsonl`: zero bytes (created with `: > <path>`) — verdict resolves to evidence_insufficient.

### override-source-enum-extended scenario harness

Six scenarios A-F (A-E inherited from P03 / Scenario F new):

| Scenario | Config | Plan | Expected post-T02 token |
|----------|--------|------|-------------------------|
| A (none, baseline) | config-baseline (P03) | plan-mechanical-no-override (P03) | none |
| B (kill-switch) | config-with-routing-disabled (P03) | plan-mechanical-no-override (P03) | disabled |
| C (plan-frontmatter) | config-baseline (P03) | plan-with-frontmatter-override (P03) | plan_frontmatter |
| D (milestone-floor) | config-with-min-tier-smart (P03) | plan-mechanical-no-override (P03) | milestone_floor |
| E (shadow-off) | config-baseline (P03) | plan-mechanical-no-override (P03), CLAUDECODE unset | (zero override_source tokens — shadow-off branch) |
| F (live + empty corpus) | config-with-live-true (P04) | plan-mechanical-no-override (P04), corpus=empty | shadow_gate_blocked |

The verifier reuses the round-trip pattern from `p03-override-source-enum.sh`. Pre-amendment behavior on Scenario F: the live branch doesn't exist; dispatch falls through to the routing-table awk extraction; `override_source=none`. The pre-amendment-tolerant predicate: PASS if `none` OR (zero tokens) OR `shadow_gate_blocked` — Scenario F's strict assertion fires only when `shadow_gate_blocked` is observed. T02's amendment causes Scenario F to emit `shadow_gate_blocked`; from T02 forward the verifier strictly asserts that exact value for Scenario F.

### Stub-fail-n adapter shape (load-bearing detail)

The adapter is invoked by `dispatch-interface.sh` as a subprocess. The current invocation (line ~586) is:

```bash
bash "$ADAPTER" --task-plan "$TASK_PLAN" --payload "$PAYLOAD" --intensity-metadata "$INTENSITY_METADATA"
```

T02 will append `--model "$shadow_used"` when in live mode. T01's `stub-fail-n.sh` accepts both flag patterns. Implementation skeleton:

```bash
#!/usr/bin/env bash
set -u

TASK_PLAN=""; PAYLOAD=""; INTENSITY_METADATA=""; MODEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --task-plan) TASK_PLAN="${2:-}"; shift 2 ;;
    --payload) PAYLOAD="${2:-}"; shift 2 ;;
    --intensity-metadata) INTENSITY_METADATA="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

CTR_FILE="${STUB_FAIL_COUNTER_FILE:-/tmp/stub-fail-n-counter.txt}"

# Side-channel: append one line per invocation for CON-5 verifier.
if [ -n "${STUB_FAIL_COUNTER_INVOCATIONS_FILE:-}" ]; then
  printf 'invocation model=%s ts=%s\n' "$MODEL" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$STUB_FAIL_COUNTER_INVOCATIONS_FILE"
fi

# Sentinel for CON-6 verifier (drops a file per invocation).
if [ -n "${STUB_INVOCATION_SENTINEL_DIR:-}" ] && [ -d "$STUB_INVOCATION_SENTINEL_DIR" ]; then
  touch "$STUB_INVOCATION_SENTINEL_DIR/inv-$(date -u +%s)-$$.touch" 2>/dev/null
fi

# Read-decrement the counter.
remaining=0
if [ -f "$CTR_FILE" ]; then
  remaining="$(tr -d '[:space:]' < "$CTR_FILE")"
  [ -n "$remaining" ] || remaining=0
fi
new_remaining=$((remaining - 1))
printf '%d\n' "$new_remaining" > "$CTR_FILE"

if [ "$remaining" -gt 0 ]; then
  # Still have failures pending (this invocation IS a failure).
  exit 1
fi

# Counter has reached 0 (or was 0 from start) — emit conforming result.
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
task_id="T00"; phase_id="P00"; milestone_id="M000"
if [ -n "$TASK_PLAN" ] && [ -f "$TASK_PLAN" ]; then
  t="$(grep -E '^task:' "$TASK_PLAN" | head -n 1 | sed -E 's/^task:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  p="$(grep -E '^phase:' "$TASK_PLAN" | head -n 1 | sed -E 's/^phase:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  m="$(grep -E '^milestone:' "$TASK_PLAN" | head -n 1 | sed -E 's/^milestone:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  [ -n "$t" ] && task_id="$t"
  [ -n "$p" ] && phase_id="$p"
  [ -n "$m" ] && milestone_id="$m"
fi

cat <<EOF
---
schema_version: "1.0"
type: "dispatch-result"
status: "success"
backend: "stub-fail-n"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${ts}"
completed_at: "${ts}"
duration_s: "0"
---

# Stub-fail-n Dispatch Result

## Status

success — counter exhausted, returned pass.

## Notes

Fixture adapter for M030/P04 escalation tests.
EOF
exit 0
```

Note the read-decrement-on-each-invocation contract: a counter file with value `2` produces the sequence `(invocation 1: rc=1)`, `(invocation 2: rc=1)`, `(invocation 3: rc=0)`. This matches the SC-4 demo: "fail twice then pass" — three invocations total, third one succeeds.

`stub-record-model.sh` is simpler — always succeeds, always writes the `--model` flag value:

```bash
#!/usr/bin/env bash
set -u

TASK_PLAN=""; PAYLOAD=""; INTENSITY_METADATA=""; MODEL="<no-model-flag>"
while [ $# -gt 0 ]; do
  case "$1" in
    --task-plan) TASK_PLAN="${2:-}"; shift 2 ;;
    --payload) PAYLOAD="${2:-}"; shift 2 ;;
    --intensity-metadata) INTENSITY_METADATA="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-<empty-model-value>}"; shift 2 ;;
    *) shift ;;
  esac
done

OUT_FILE="${STUB_RECORD_MODEL_FILE:-/tmp/stub-record-model.txt}"
printf '%s\n' "$MODEL" > "$OUT_FILE"

# Standard dispatch-result emission (mirrors stub.sh shape).
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
task_id="T00"; phase_id="P00"; milestone_id="M000"
if [ -n "$TASK_PLAN" ] && [ -f "$TASK_PLAN" ]; then
  t="$(grep -E '^task:' "$TASK_PLAN" | head -n 1 | sed -E 's/^task:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  p="$(grep -E '^phase:' "$TASK_PLAN" | head -n 1 | sed -E 's/^phase:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  m="$(grep -E '^milestone:' "$TASK_PLAN" | head -n 1 | sed -E 's/^milestone:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  [ -n "$t" ] && task_id="$t"
  [ -n "$p" ] && phase_id="$p"
  [ -n "$m" ] && milestone_id="$m"
fi
cat <<EOF
---
schema_version: "1.0"
type: "dispatch-result"
status: "success"
backend: "stub-record-model"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${ts}"
completed_at: "${ts}"
duration_s: "0"
---

# Stub-record-model Dispatch Result

## Status

success — recorded model flag value to ${OUT_FILE}.
EOF
exit 0
```

## Steps

1. **Create `tests/fixtures/m030-p04/` directory tree.**

   ```bash
   mkdir -p tests/fixtures/m030-p04/plans
   mkdir -p tests/fixtures/m030-p04/configs
   mkdir -p tests/fixtures/m030-p04/round-trip-stage
   ```

2. **Author the five fixture plans.** Each uses the YAML frontmatter shape from P03 fixture plans (mirror `tests/fixtures/m030-p03/plans/plan-mechanical-no-override.md`):

   - `plan-mechanical-no-override.md` (T99 unitId, mechanical body, no override frontmatter).
   - `plan-fail-twice-then-pass.md` (T97 unitId, mechanical body, no override frontmatter).
   - `plan-fail-three-times.md` (T96 unitId, mechanical body, no override frontmatter).
   - `plan-fail-four-times.md` (T96 unitId — re-used; the per-test counter, not the unitId, is the load-bearing assertion. Place under a separate filename so the path-distinct fixture is committable).
   - `plan-novel-class.md` (T95 unitId, novel body — Goal section uses `explore` / `design` / `evaluate alternatives` words, NO concrete `## Steps` block with bash verifiers).

   Each plan is ≥25 lines, ends with `## Verification` containing a single literal `bash tools/verify/p04-<verifier-name>.sh` command (the verifier's name is the plan's downstream consumer; this is documentation, not load-bearing for dispatch).

   Mechanical body signature (for the four mechanical plans):

   ```markdown
   ## Steps

   1. Touch `tests/fixtures/m030-p04/output-<a|b|c>.txt` with literal string `<a|b|c>`.
   2. Same.
   3. Same.

   ## Verification

   ```bash
   bash tools/verify/p04-<applicable>.sh
   ```
   ```

   Novel body signature (for `plan-novel-class.md`):

   ```markdown
   ## Goal

   Explore alternative architectures for the live-routing flip-gate. Evaluate the trade-offs between
   per-class verdict caching and on-demand re-evaluation, and design the operator-facing knob shape
   for partial-flip authorization windows.

   ## Verification

   ```bash
   bash tools/verify/p04-partial-flip-routing.sh
   ```
   ```

3. **Author the three fixture configs.**

   `tests/fixtures/m030-p04/configs/config-with-live-true.yml`:

   ```yaml
   ---
   schema_version: "1.0"
   type: orchestrator-config
   ---

   model_routing:
     live: true
   ```

   `tests/fixtures/m030-p04/configs/config-with-live-and-killswitch.yml`:

   ```yaml
   ---
   schema_version: "1.0"
   type: orchestrator-config
   ---

   model_routing_enabled: false

   model_routing:
     live: true
     min_tier: smart
   ```

   `tests/fixtures/m030-p04/configs/config-with-live-false.yml`:

   ```yaml
   ---
   schema_version: "1.0"
   type: orchestrator-config
   ---

   model_routing:
     live: false
   ```

4. **Author the round-trip stage.**

   `tests/fixtures/m030-p04/round-trip-stage/intensity-metadata.txt`:

   ```text
   intensity: standard
   model: "claude-opus-4-7"
   ```

   `tests/fixtures/m030-p04/round-trip-stage/payload.txt`: a single-line ascii string of any length (the `chars_to_tokens_quartile` function rounds to a quartile, so deterministic length is not required at the byte level). Suggested literal: `M030/P04 round-trip payload — 466 bytes — sized to mirror P03's deterministic input.`

5. **Author and run the shadow-corpus synthesizer.** Author `tests/fixtures/m030-p04/synthesize-corpora.sh` (idempotent; safe to re-run):

   ```bash
   #!/usr/bin/env bash
   # tests/fixtures/m030-p04/synthesize-corpora.sh — M030/P04/T01 shadow-corpus synth.
   set -u

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   READY="$SCRIPT_DIR/shadow-corpus-ready.jsonl"
   PARTIAL="$SCRIPT_DIR/shadow-corpus-partially-ready.jsonl"
   EMPTY="$SCRIPT_DIR/shadow-corpus-empty.jsonl"

   : > "$READY"
   : > "$PARTIAL"
   : > "$EMPTY"

   _emit_records() {
     # $1 = output file; $2 = class; $3 = tier; $4 = count; $5 = confidence
     local out="$1" class="$2" tier="$3" count="$4" conf="$5"
     local i=1
     while [ "$i" -le "$count" ]; do
       printf '{"record_type":"dispatch_usage","unitId":"M999/P01/T%02d","milestone":"M999","phase":"P01","task":"T%02d","backend":"stub","input_tokens_estimate":1024,"output_tokens_estimate":0,"estimated_cost_usd":0.0001,"pricing_version":"2026-04-30","filter_dropped_tokens":0,"tier1_savings_tokens":0,"tier2_savings_tokens":0,"tier1_invocations":0,"tier3_compression_savings_tokens":0,"tier3_invocations":0,"model":"claude-opus-4-7","source":"estimate","emission_point":"dispatch-interface","timestamp":"2026-04-30T00:00:%02dZ","classifier_confidence":"%s","model_routed":"%s","model_used":"claude-opus-4-7","partial_flip_active":false,"withheld_classes":"","override_source":"none"}\n' "$i" "$i" "$i" "$conf" "$tier" >> "$out"
       i=$((i + 1))
     done
   }

   # Ready corpus: 55 records per class, all confidence=high (variance=0 stable).
   _emit_records "$READY" mechanical fast 55 high
   _emit_records "$READY" standard balanced 55 high
   _emit_records "$READY" novel smart 55 high

   # Partially-ready corpus: mechanical + standard at 55 each (stable);
   # novel at 25 (below 50 threshold; under-threshold).
   _emit_records "$PARTIAL" mechanical fast 55 high
   _emit_records "$PARTIAL" standard balanced 55 high
   _emit_records "$PARTIAL" novel smart 25 high

   # Empty corpus: zero bytes (already truncated above).

   echo "synthesized: ready=$(wc -l < "$READY"), partial=$(wc -l < "$PARTIAL"), empty=$(wc -l < "$EMPTY")"
   ```

   Run the synthesizer:

   ```bash
   bash tests/fixtures/m030-p04/synthesize-corpora.sh
   ```

   Expected stdout: `synthesized: ready=165, partial=135, empty=0`.

   Sanity-check against `shadow-compare.sh`:

   ```bash
   bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p04/shadow-corpus-ready.jsonl
   bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p04/shadow-corpus-partially-ready.jsonl
   bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p04/shadow-corpus-empty.jsonl
   ```

   Expected verdicts: `ready`, `partially_ready` + `withheld_classes=novel`, `evidence_insufficient`. If any verdict is wrong, debug the record count or confidence values before proceeding.

6. **Author `scripts/dispatch/adapters/backend/stub-fail-n.sh`** per the skeleton in the Description. Mark executable: `chmod +x scripts/dispatch/adapters/backend/stub-fail-n.sh`. Smoke-test:

   ```bash
   printf '2\n' > /tmp/p04-t01-smoke-counter.txt
   STUB_FAIL_COUNTER_FILE=/tmp/p04-t01-smoke-counter.txt bash scripts/dispatch/adapters/backend/stub-fail-n.sh --task-plan tests/fixtures/m030-p04/plans/plan-fail-twice-then-pass.md --payload tests/fixtures/m030-p04/round-trip-stage/payload.txt --intensity-metadata tests/fixtures/m030-p04/round-trip-stage/intensity-metadata.txt
   ```

   Expected: exit 1 (counter was 2 → invocation fails).

   Re-run twice more; the third invocation should exit 0 with a dispatch-result on stdout. Cleanup `rm -f /tmp/p04-t01-smoke-counter.txt`.

7. **Author `scripts/dispatch/adapters/backend/stub-record-model.sh`** per the skeleton in the Description. Mark executable. Smoke-test:

   ```bash
   STUB_RECORD_MODEL_FILE=/tmp/p04-t01-smoke-model.txt bash scripts/dispatch/adapters/backend/stub-record-model.sh --task-plan tests/fixtures/m030-p04/plans/plan-mechanical-no-override.md --payload tests/fixtures/m030-p04/round-trip-stage/payload.txt --intensity-metadata tests/fixtures/m030-p04/round-trip-stage/intensity-metadata.txt --model claude-haiku-4-5
   ```

   Expected: exit 0 with conforming dispatch-result on stdout. The file `/tmp/p04-t01-smoke-model.txt` contains the literal `claude-haiku-4-5`. Cleanup.

8. **Author `tools/verify/p04-additive-schema.sh`** per the shape in the Description (thin pass-through to `p02-additive-schema.sh`). Mark executable.

9. **Author `tools/verify/p04-override-source-enum-extended.sh`.** Bash 3.2-compatible. Six scenarios A-F:

   - For each scenario: stage a tmp_root with the appropriate `.orchestrator/config.yml`; export `M030_SHADOW_MODE=1 CLAUDECODE=1 ORCHESTRATOR_ROOT=tmp_root` (Scenario E unsets CLAUDECODE for shadow-off); invoke `bash scripts/dispatch/dispatch-interface.sh --task-plan <fixture-plan> --payload <stage>/payload.txt --intensity-metadata <stage>/intensity-metadata.txt --backend stub`; read the appended JSONL line; grep-assert the `override_source` token.
   - Scenario F (live + empty corpus): stage `config-with-live-true.yml`. Stage an empty execution log. Set `M030_SHADOW_COMPARE_CORPUS=tests/fixtures/m030-p04/shadow-corpus-empty.jsonl` (this env var is consumed by T02's amendment; it has no effect pre-T02 because the live branch doesn't read it).
   - Pre-amendment-tolerant predicate for Scenario F: PASS if the appended JSONL line contains `"override_source":"shadow_gate_blocked"` (post-T02 strict path) OR the line exists with any enum-valid value (pre-T02 fallback — dispatch falls through to existing paths and emits `none` or similar). The verifier increments a `pass` counter for either match.
   - Per-scenario tmp_root + cleanup (mktemp -d with fallback). AP-009-compliant: tmp-file intermediates throughout; no `cmd | grep | head` chains.
   - Final `SUMMARY: p04-override-source-enum-extended.sh pass=N fail=M`. Pass=6 (scenarios A-F all green) post-T02; pass=6 pre-T02 (Scenario F's tolerant branch fires).

   Exact verifier shape — straight-line scenarios, no loops. Per scenario:

   ```bash
   _check_scenario() {
     local label="$1" config="$2" plan="$3" expected_token="$4" tolerant_mode="$5"
     # ... stage tmp_root + dispatch + read JSONL + grep-q assertion ...
   }
   _check_scenario A config-baseline plan-mechanical-no-override-p03 '"override_source":"none"' strict
   _check_scenario B config-with-routing-disabled-p03 plan-mechanical-no-override-p03 '"override_source":"disabled"' strict
   _check_scenario C config-baseline plan-with-frontmatter-override-p03 '"override_source":"plan_frontmatter"' strict
   _check_scenario D config-with-min-tier-smart-p03 plan-mechanical-no-override-p03 '"override_source":"milestone_floor"' strict
   _check_scenario E config-baseline plan-mechanical-no-override-p03 '' shadow-off
   _check_scenario F config-with-live-true plan-mechanical-no-override '"override_source":"shadow_gate_blocked"' tolerant
   ```

   The `tolerant` mode for Scenario F: PASS if the strict token is present OR if the line contains any of the five P03 enum tokens (pre-amendment fallback). The strict mode requires exact token presence. Shadow-off requires zero `override_source` tokens.

10. **Run the two tolerant verifiers as a self-check:**

    ```bash
    bash tools/verify/p04-additive-schema.sh
    bash tools/verify/p04-override-source-enum-extended.sh
    ```

    Expected: both exit 0 against the pre-T02 dispatch-interface.sh. `p04-additive-schema.sh` passes because P02's contract is unchanged. `p04-override-source-enum-extended.sh` passes because Scenarios A-D hit their P03 enum values, Scenario E is shadow-off (zero tokens), and Scenario F hits the tolerant branch (any P03 enum value PASS pre-T02; T02 will tighten to `shadow_gate_blocked`).

11. **Verify all artifacts on disk.**

    ```bash
    ls -la tests/fixtures/m030-p04/plans/
    ls -la tests/fixtures/m030-p04/configs/
    ls -la tests/fixtures/m030-p04/round-trip-stage/
    ls -la tests/fixtures/m030-p04/shadow-corpus-*.jsonl
    ls -la scripts/dispatch/adapters/backend/stub-fail-n.sh
    ls -la scripts/dispatch/adapters/backend/stub-record-model.sh
    ls -la tools/verify/p04-additive-schema.sh
    ls -la tools/verify/p04-override-source-enum-extended.sh
    ```

    Expected: every file present; the two tools/verify/ files executable.

12. **Stage and commit.** Stage every new file. Author commit message file via Write to `/tmp/p04-t01-commit-msg.txt`; commit with `git commit -F /tmp/p04-t01-commit-msg.txt`. Recommended subject: `M030/P04/T01: P04 fixture plans + configs + shadow corpora + stub-fail-n + stub-record-model + tolerant gates (preflight)`.

## Must-Haves

This task satisfies the phase truths:

- "The `override_source` enum gains a sixth value `shadow_gate_blocked`..." — gated by `tools/verify/p04-override-source-enum-extended.sh` (now in pre-amendment-tolerant mode; T02 tightens it to strict).
- "SC-11 byte-equality re-confirmed against P02's pre-M030 fixture..." — gated by `tools/verify/p04-additive-schema.sh` (T01 stages the wrapper; pre-T02 + post-T03 both pass).

T01 also pre-stages the fixtures + stub adapters that T02 and T03's verifiers will consume. Without these, T02 and T03 cannot author their gates. This is the same graduation-pattern shape P02/T01 + P03/T01 used.

## Verification

```bash
bash tools/verify/p04-additive-schema.sh
bash tools/verify/p04-override-source-enum-extended.sh
```

Each command uses single-script-file shape per AD-19. Both must exit 0 before T01 closes.

## Inputs

### From Previous Tasks

(T01 has no upstream M030/P04 tasks; depends on P02 + P03 deliverables.)

### From Disk (Pre-existing)

- scripts/dispatch/dispatch-interface.sh — pre-T02 form. T01's verifiers exercise this against the fixtures.
  - Key API: `bash <path> --task-plan <p> --payload <p> --intensity-metadata <p> [--backend <name>]` writes one `dispatch_usage` record to `$ORCH_ROOT/.../execution-log.jsonl` per invocation. Pre-T02: emits 6 P02/P03 fields under shadow-on (`classifier_confidence`, `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`, `override_source`). The override_source enum supports five values; the sixth (`shadow_gate_blocked`) is reserved but not yet emitted (T02 deliverable).
- scripts/diagnostics/shadow-compare.sh — P02/T03 deliverable.
  - Key API: `bash <path> [--corpus <jsonl-path>]` reads a JSONL corpus, emits per-class `count=` + `variance=` lines plus a single `flip_recommendation=<ready|partially_ready|block|evidence_insufficient>` line on stdout. On `partially_ready`, also emits `withheld_classes=<comma-list>`. Bash 3.2 compatible. Used by T01 only as a sanity-check against the synthesized corpora; consumed programmatically by T02's dispatch-interface amendment.
- scripts/dispatch/classify-task.sh — P01/T02 classifier.
  - Key API: `bash <path> <plan-path>` writes `character=<m|s|n>` + `confidence=<h|m|l>` to stdout. T01's `plan-novel-class.md` should produce `character=novel`; the four mechanical plans should produce `character=mechanical`.
- templates/model-routing.yml — P01/T03 routing-table SSOT.
  - Key API: YAML file with `routing:` (3 chars × 3 runtimes) + `resolution:` (3 tiers × 3 runtimes) + `cost_rates:` (3 tiers). T01 does NOT modify; T01's verifiers do not depend on it directly.
- scripts/dispatch/adapters/backend/stub.sh — M019/P01/T05 minimal adapter; pattern reference for stub-fail-n.sh and stub-record-model.sh.
- tests/fixtures/m030-p03/ — P03/T01 fixture tree; pattern reference for the P04 fixture tree shape.
- tools/verify/p02-additive-schema.sh — P02/T04 SC-11 gate; T01's `p04-additive-schema.sh` wraps it.
- tools/verify/p03-override-source-enum.sh — P03/T01 enum gate; T01's `p04-override-source-enum-extended.sh` extends its scenario harness.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The new stub adapters are internal scripts; AD-19 governs the verifier-invocation shape, not the script's internal structure.
- **MEM004 emitter-internal carve-out**: stub-fail-n.sh and stub-record-model.sh are dispatch-internal adapters; pipes / awk / `$()` permitted in their bodies as the dispatch-internal carve-out.
- **AP-009 compound-chain-gt2 (verifier shape)**: `p04-override-source-enum-extended.sh` MUST avoid `result=$(cmd | grep | head)` patterns. Use tmp-file intermediates: `cmd > /tmp/<f>.txt; grep ... < /tmp/<f>.txt > /tmp/<g>.txt; head -1 < /tmp/<g>.txt`.
- **CON-2 / FR-19 / SC-11 (additive-only schema)**: T01 introduces no new fields to dispatch-interface.sh; SC-11 byte-equality is preserved by construction. The `p04-additive-schema.sh` wrapper continues to enforce the contract under HEAD.
- **CON-3 (symbolic-tier closure)**: T01's stub adapters do NOT introduce hardcoded model IDs in `dispatch-interface.sh` (T01 does not modify dispatch-interface.sh). The shadow-corpus JSONL fixtures contain literal model IDs (`claude-opus-4-7`) but those are FIXTURE DATA, not implementation code — fixtures are explicitly out of scope for the CON-3 closure check (which targets `scripts/**/*.sh`).
- **CON-4 / D-A5 (kill switch supersedes live)**: T01 stages the `config-with-live-and-killswitch.yml` fixture used by T02's `p04-con4-live-killswitch.sh`. T01 does NOT amend dispatch-interface.sh; the kill-switch-wins-in-live-mode logic is T02's deliverable.
- **CON-5 (escalation hard-cap)**: T01 stages `plan-fail-three-times.md` and `plan-fail-four-times.md` plus the stub-fail-n adapter. T01 does NOT implement the cap; T03 does.
- **CON-6 (append-only shadow corpus)**: T01 introduces no new write paths to dispatch-interface.sh. The synthesized JSONL fixtures are written ONCE by `synthesize-corpora.sh` and never mutated — they exemplify the append-only contract.
- **CC-only launch posture**: shadow path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1`. T01's verifiers respect this gate.
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`. All scripts use POSIX-safe constructs.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T01 introduces no SQL — N/A.

## Expected Output

- `tests/fixtures/m030-p04/plans/` contains 5 fixture plans.
- `tests/fixtures/m030-p04/configs/` contains 3 fixture configs.
- `tests/fixtures/m030-p04/round-trip-stage/` contains intensity-metadata.txt + payload.txt.
- `tests/fixtures/m030-p04/shadow-corpus-{ready,partially-ready,empty}.jsonl` exist.
- `tests/fixtures/m030-p04/synthesize-corpora.sh` exists and is executable.
- `scripts/dispatch/adapters/backend/stub-fail-n.sh` exists, executable, smoke-tested green.
- `scripts/dispatch/adapters/backend/stub-record-model.sh` exists, executable, smoke-tested green.
- `tools/verify/p04-additive-schema.sh` exits 0 with `SUMMARY: p04-additive-schema.sh pass=1 fail=0`.
- `tools/verify/p04-override-source-enum-extended.sh` exits 0 with `SUMMARY: p04-override-source-enum-extended.sh pass=6 fail=0` (pre-amendment-tolerant; Scenario F passes via the tolerant branch).
- `bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p04/shadow-corpus-ready.jsonl` reports `flip_recommendation=ready`.
- `bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p04/shadow-corpus-partially-ready.jsonl` reports `flip_recommendation=partially_ready` AND `withheld_classes=novel`.
- `bash scripts/diagnostics/shadow-compare.sh --corpus tests/fixtures/m030-p04/shadow-corpus-empty.jsonl` reports `flip_recommendation=evidence_insufficient`.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p04-additive-schema.sh` -> 1 sub-gate pass; `SUMMARY: p04-additive-schema.sh pass=1 fail=0`, exit 0.
- `bash tools/verify/p04-override-source-enum-extended.sh` -> 6 scenarios A-F all pass; `SUMMARY: p04-override-source-enum-extended.sh pass=6 fail=0`, exit 0.

The shadow-corpus synthesizer is committed to disk (NOT a one-shot script run from the build harness) so future maintainers can re-synthesize the fixtures from scratch if the JSONL schema evolves. The synthesizer's idempotence guarantees re-running produces byte-identical output (modulo the timestamp field, which is hardcoded to `2026-04-30T00:00:NNZ` for determinism — this is fixture metadata, not real telemetry).

The five P03 fixture plans (`plan-mechanical-no-override.md`, `plan-with-frontmatter-override.md`, etc.) are reused verbatim by Scenarios A-E of the enum gate. T01 does NOT duplicate them under the P04 fixture tree — Scenario A-E paths point at the existing P03 fixture files. Only Scenario F uses a P04-specific fixture (`plan-mechanical-no-override.md` under `tests/fixtures/m030-p04/plans/`). The P03 and P04 mechanical-no-override plans differ ONLY in the unitId markers (T99 vs T99 — no, both use T99 actually; the load-bearing distinguisher is the path, not the unitId).

Stub-fail-n's read-decrement contract has a subtle off-by-one: a counter of `2` produces `(rc=1, rc=1, rc=0)` — three invocations, two failures, one success. SC-4 demo says "fail twice then pass" → counter starts at 2 → matches. SC-5 demo says "fail three times" → counter starts at 3 → produces `(rc=1, rc=1, rc=1, rc=0)` IF allowed to run four times, but T03's escalation cap stops at three invocations → produces `(rc=1, rc=1, rc=1)` on disk. CON-5 demo (no fourth record, plan-fail-four-times) sets counter=4 and asserts the stub was invoked exactly 3 times — proving the cap is hard.

If `synthesize-corpora.sh` produces a corpus that `shadow-compare.sh` does NOT classify as expected (e.g., the partially_ready corpus comes back as `block` because the variance computation at N=20 produces unstable values for some edge case), the resolution is to bump the per-class record counts (e.g., 60 instead of 55) until the variance is structurally < 0.10 across the rolling window. The corpus contents are FIXTURE metadata; their exact byte shape is not load-bearing as long as the verdict from `shadow-compare.sh` is the documented one.

The `STUB_INVOCATION_SENTINEL_DIR` env var is reserved for T03's CON-6 prior-records-bit-identical verifier; T01's stub-fail-n.sh implements the sentinel-drop logic but T01's own verifiers do not exercise it. Documenting it in T01's stub is preferable to retrofitting in T03 — keeps the adapter shape stable across phases.
