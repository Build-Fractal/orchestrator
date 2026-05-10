---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M030"
name: "P06 fixtures + golden baseline + SC-11 gate (preflight)"
depends_on: []
---

## Prerequisites

- `scripts/diagnostics/check-anomalies.sh` exists in its post-M027/[M018](../../../../../milestones/M018/index.md) form (~290 lines; sourceable + CLI; `set -u` only; reads `metrics-rollup.sh` task-grain rollup; emits a "Anomaly Detection (Tier 1 baseline)" text block to stdout; suppression matrix = 5 conditions; bash 3.2 compatible). Verified at plan-time by direct `find` + Read.
- `scripts/diagnostics/run-doctor.sh` exists with the existing "Anomaly Detection" advisory invocation at lines 154-159 (`run_check "Anomaly Detection" "$SCRIPT_DIR/check-anomalies.sh" ...`). Verified at plan-time.
- `scripts/dispatch/dispatch-interface.sh` exists in its post-P04 form with the shadow-on emit branch carrying the 9-field schema: `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`, `classifier_confidence`, `override_source`, `escalation_count`, `escalation_reason`, plus the [M019](../../../../../milestones/M019/index.md) baseline fields. T01 does NOT amend `dispatch-interface.sh` — the amendment is T02's deliverable; T01 only ships fixtures and the SC-11 gate.
- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` exists (P02/T01 deliverable; 5 records; pre-M030 schema; no `model_routed` / `model_used` / `character` field). The SC-11 byte-equality contract uses this corpus as the regression-test input.
- `tests/fixtures/m030-p02/round-trip-stage/` exists with the deterministic 4096B payload + intensity-metadata fixture P02 used for byte-equality round-trip. T01 does NOT consume this directly; it is referenced by P06's `tools/verify/p06-shadow-off-byte-equality.sh` (T02 deliverable).
- `tools/verify/p02-additive-schema.sh` exists (P02 SC-11 byte-equality gate; round-trips the P02 round-trip-stage record through `dispatch-interface.sh` under `M030_SHADOW_MODE=0` and asserts byte-identity). P06's `p06-shadow-off-byte-equality.sh` (T02 deliverable) wraps this gate.
- `templates/model-routing.yml` exists with three top-level sections: `routing:` (3 chars × 3 runtimes), `resolution:` (3 tiers × 3 runtimes), `cost_rates:` (3 tiers).

Plan-time prerequisite-existence verification: every path above is asserted by direct read at plan-authoring time. Any missing path FAILs T01 authorship.

## Description

T01 ships before any work on `scripts/diagnostics/check-anomalies.sh` or `scripts/dispatch/dispatch-interface.sh` so the SC-11 byte-equality contract has a mechanical gate at the moment T02's diff lands. Mirrors the P02/T01 + P03/T01 + P04/T01 + P05/T01 graduation pattern (verifier-before-deliverable).

Three deliverable groups that ship as a single coherent commit at T01 close:

1. **Fixture corpora** at `tests/fixtures/m030-p06/` — 6 JSONL fixtures plus the `synthesize-corpus.sh` synthesizer.
2. **Pre-amendment golden baseline** at `tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt`.
3. **SC-11 byte-equality gate** at `tools/verify/p06-sc11-byte-equality.sh`.

### Fixture corpus shape

P06 needs five distinct corpora to cover the truth matrix:

- **regression-mechanical.jsonl** — 20 shadow-on `dispatch_usage` records with `character=mechanical`. 12 records carry `escalation_count=1` + `escalation_reason=verifier_fail` (failures); 8 carry `escalation_count=0` + `escalation_reason=""` (passes). Class pass-rate = 8/20 = 0.40 — below the default 0.50 threshold. Sample size 20 ≥ 10 floor. Triggers the model_routing_regression flag.
- **regression-standard.jsonl** — 20 shadow-on records `character=standard`. Same 12-fail / 8-pass split. Class pass-rate = 0.40. Triggers model_routing_regression for standard.
- **regression-novel.jsonl** — 20 shadow-on records `character=novel`. Same 12-fail / 8-pass split. Class pass-rate = 0.40. Triggers model_routing_regression for novel.
- **no-regression.jsonl** — 60 shadow-on records (20 mechanical + 20 standard + 20 novel). Each class has 4 fails / 16 passes — pass-rate 0.80, well above 0.50 threshold. Sample size 20 per class ≥ 10 floor. NO regression fired for any class.
- **below-min-sample.jsonl** — 5 shadow-on records `character=mechanical` with 3 fails / 2 passes — pass-rate 0.40 (would trigger if sample met floor) but sample 5 < 10 min_class_sample floor, so silently skipped.

All corpora share these per-record fields (additive over the post-P04 schema with the new T02-introduced `character` field):

- `record_type=dispatch_usage`
- `unitId=M999/P01/T<NN>`
- `milestone=M999`
- `phase=P01`
- `task=T<NN>`
- `backend=stub`
- `input_tokens_estimate=1024`
- `output_tokens_estimate=512`
- `estimated_cost_usd=0.01536000`
- `pricing_version=2026-04-17`
- `filter_dropped_tokens=0`
- `tier1_savings_tokens=0`
- `tier2_savings_tokens=0`
- `tier1_invocations=0`
- `tier3_compression_savings_tokens=0`
- `tier3_invocations=0`
- `model=<resolved-id>`
- `source=estimate`
- `emission_point=dispatch-interface`
- `timestamp=<ISO8601>`
- `classifier_confidence=high`
- `model_routed=<tier>`
- `model_used=<resolved-id>`
- `partial_flip_active=false`
- `withheld_classes=""`
- `override_source=none`
- `escalation_count=<0|1>`
- `escalation_reason="<verifier_fail|>"`
- `character=<mechanical|standard|novel>` ← T01 fixtures already carry this even though `dispatch-interface.sh` doesn't yet emit it; T02 closes the loop.

T01's fixtures are forward-compatible by design — the JSONL shape with `character=` is what T02's amendment will produce. P02/T01 set this precedent (its stub adapter already accepted `--model` flag in T01 even though dispatch-interface.sh started passing it in T02).

The synthesizer at `tests/fixtures/m030-p06/synthesize-corpus.sh` is idempotent (re-running produces byte-identical corpora) and emits all five corpora in one invocation:

```bash
#!/usr/bin/env bash
# tests/fixtures/m030-p06/synthesize-corpus.sh
# Emits five fixture corpora to siblings of this script. Idempotent.
# 20 records per class for the regression-* files (12 fail / 8 pass each),
# 60 records (20 per class, 4 fail / 16 pass each) for no-regression,
# 5 records mechanical (3 fail / 2 pass) for below-min-sample.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Tier resolution mirrors templates/model-routing.yml default routing.
tier_for_class() {
  case "$1" in
    mechanical) echo "fast" ;;
    standard) echo "balanced" ;;
    novel) echo "smart" ;;
  esac
}

model_for_tier() {
  case "$1" in
    fast) echo "claude-haiku-4-5" ;;
    balanced) echo "claude-sonnet-4-7" ;;
    smart) echo "claude-opus-4-7" ;;
  esac
}

emit_record() {
  # $1 task-suffix (e.g., "T01"); $2 character; $3 escalation_count;
  # $4 escalation_reason; $5 ts.
  local task_n="$1"
  local character="$2"
  local esc_count="$3"
  local esc_reason="$4"
  local ts="$5"
  local tier
  tier="$(tier_for_class "$character")"
  local model
  model="$(model_for_tier "$tier")"
  printf '{"record_type":"dispatch_usage","unitId":"M999/P01/%s","milestone":"M999","phase":"P01","task":"%s","backend":"stub","input_tokens_estimate":1024,"output_tokens_estimate":512,"estimated_cost_usd":0.01536000,"pricing_version":"2026-04-17","filter_dropped_tokens":0,"tier1_savings_tokens":0,"tier2_savings_tokens":0,"tier1_invocations":0,"tier3_compression_savings_tokens":0,"tier3_invocations":0,"model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s","classifier_confidence":"high","model_routed":"%s","model_used":"%s","partial_flip_active":false,"withheld_classes":"","override_source":"none","escalation_count":%s,"escalation_reason":"%s","character":"%s"}\n' \
    "$task_n" "$task_n" "$model" "$ts" "$tier" "$model" "$esc_count" "$esc_reason" "$character"
}

# regression-<class>.jsonl: 20 records per class; first 12 fail, last 8 pass.
synthesize_regression_corpus() {
  local character="$1"
  local out="$SCRIPT_DIR/regression-$character.jsonl"
  : > "$out"
  local n=1
  local task_n
  while [ "$n" -le 12 ]; do
    task_n="$(printf 'T%02d' "$n")"
    emit_record "$task_n" "$character" 1 "verifier_fail" "2026-04-30T11:$(printf '%02d' "$n"):00Z" >> "$out"
    n=$((n + 1))
  done
  while [ "$n" -le 20 ]; do
    task_n="$(printf 'T%02d' "$n")"
    emit_record "$task_n" "$character" 0 "" "2026-04-30T11:$(printf '%02d' "$n"):00Z" >> "$out"
    n=$((n + 1))
  done
}

synthesize_regression_corpus mechanical
synthesize_regression_corpus standard
synthesize_regression_corpus novel

# no-regression.jsonl: 60 records; per class 4 fail / 16 pass (pass_rate=0.80).
out="$SCRIPT_DIR/no-regression.jsonl"
: > "$out"
class_idx=0
for character in mechanical standard novel; do
  base=$((class_idx * 20))
  i=1
  while [ "$i" -le 4 ]; do
    n=$((base + i))
    task_n="$(printf 'T%02d' "$n")"
    emit_record "$task_n" "$character" 1 "verifier_fail" "2026-04-30T12:$(printf '%02d' "$n"):00Z" >> "$out"
    i=$((i + 1))
  done
  while [ "$i" -le 20 ]; do
    n=$((base + i))
    task_n="$(printf 'T%02d' "$n")"
    emit_record "$task_n" "$character" 0 "" "2026-04-30T12:$(printf '%02d' "$n"):00Z" >> "$out"
    i=$((i + 1))
  done
  class_idx=$((class_idx + 1))
done

# below-min-sample.jsonl: 5 mechanical records (3 fail / 2 pass).
out="$SCRIPT_DIR/below-min-sample.jsonl"
: > "$out"
n=1
while [ "$n" -le 3 ]; do
  task_n="$(printf 'T%02d' "$n")"
  emit_record "$task_n" "mechanical" 1 "verifier_fail" "2026-04-30T13:$(printf '%02d' "$n"):00Z" >> "$out"
  n=$((n + 1))
done
while [ "$n" -le 5 ]; do
  task_n="$(printf 'T%02d' "$n")"
  emit_record "$task_n" "mechanical" 0 "" "2026-04-30T13:$(printf '%02d' "$n"):00Z" >> "$out"
  n=$((n + 1))
done
```

The synthesizer is committed alongside the corpora for reproducibility.

### Pre-amendment golden baseline

T01 captures stdout snapshot of `check-anomalies.sh` against the pre-M030 fixture BEFORE T02 amends it. The captured snapshot is the SC-11 contract.

The capture must run against an `ORCHESTRATOR_ROOT` carve-out so `find-active-milestone.sh` resolves to a fixture milestone instead of the real `.orchestrator/`. Stage:

```bash
tmp_root="$(mktemp -d -t p06-t01-baseline.XXXXXX)"
mkdir -p "$tmp_root/milestones/M001/phases/P00"
cp tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl "$tmp_root/milestones/M001/execution-log.jsonl"
# A minimal milestone marker so find-active-milestone.sh is happy.
cat > "$tmp_root/milestones/M001/M001-CONTEXT.md" <<'EOF'
---
type: milestone-context
milestone: "M001"
status: open
---
EOF

ORCHESTRATOR_ROOT="$tmp_root" PROJECT_ROOT="$(pwd)" \
  bash scripts/diagnostics/check-anomalies.sh --milestone M001 \
  > tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt 2>/dev/null

rm -rf "$tmp_root"
```

The baseline is byte-identical regardless of capture-time machine state because `check-anomalies.sh` is a deterministic function of its `metrics-rollup.sh` input (which is itself deterministic over the JSONL fixture). The only non-deterministic input is the timestamp on emitted JSONL anomaly records — but T01's capture runs against PRE-amendment HEAD, where no JSONL emit exists. The text-only stdout block is fully deterministic.

If `check-anomalies.sh`'s stdout against a 5-record-no-shadow-on fixture is dominated by the "ANOMALY: insufficient sample" line (sample size 5 < default floor 5 — actually equal, so the floor check passes; for n<floor it short-circuits), expect output along the lines of:

```
Anomaly Detection (Tier 1 baseline)
ANOMALY: no anomalies detected (n=5 median=0.5000 mult=3.00)
```

The exact bytes depend on the rollup's median-cost computation over the fixture. T01 captures whatever HEAD emits and that becomes the contract.

### SC-11 byte-equality gate

`tools/verify/p06-sc11-byte-equality.sh` mirrors P05's `p05-sc11-rollup-byte-equality.sh` shape — stages the carve-out + invokes check-anomalies + diffs against the committed golden:

```bash
#!/usr/bin/env bash
# tools/verify/p06-sc11-byte-equality.sh — SC-11 byte-equality gate.
# Asserts check-anomalies.sh stdout against the pre-M030 fixture is
# byte-identical to the committed golden baseline. Pre-amendment-tolerant
# at T01 close (post-amendment goldens reflect HEAD); becomes byte-strict
# the moment T02 amendment lands.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BASELINE="$PROJECT_ROOT/tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl"

pass=0
fail=0

if [ ! -f "$BASELINE" ]; then
  echo "FAIL: baseline missing at $BASELINE"
  echo "SUMMARY: p06-sc11-byte-equality.sh pass=0 fail=1"
  exit 1
fi

if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: fixture missing at $FIXTURE"
  echo "SUMMARY: p06-sc11-byte-equality.sh pass=0 fail=1"
  exit 1
fi

tmp_root="$(mktemp -d -t p06-sc11.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT
mkdir -p "$tmp_root/milestones/M001"
cp "$FIXTURE" "$tmp_root/milestones/M001/execution-log.jsonl"
cat > "$tmp_root/milestones/M001/M001-CONTEXT.md" <<'EOF_CTX'
---
type: milestone-context
milestone: "M001"
status: open
---
EOF_CTX

ACTUAL="$(mktemp -t p06-sc11-actual.XXXXXX)"
trap 'rm -rf "$tmp_root"; rm -f "$ACTUAL"' EXIT

ORCHESTRATOR_ROOT="$tmp_root" PROJECT_ROOT="$PROJECT_ROOT" \
  bash "$PROJECT_ROOT/scripts/diagnostics/check-anomalies.sh" \
  --milestone M001 \
  > "$ACTUAL" 2>/dev/null

if diff -u "$BASELINE" "$ACTUAL"; then
  pass=1
  echo "OK: check-anomalies stdout byte-identical to baseline"
else
  fail=1
  echo "FAIL: check-anomalies stdout differs from baseline (see diff above)"
fi

echo "SUMMARY: p06-sc11-byte-equality.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

Note: the `trap` line is rewritten when the second tmp file is created so the first cleanup remains in scope. Standard Bash 3.2-compatible single-trap-replacement-with-superset pattern.

T01 ships this verifier byte-strict from the start (mirrors P05's pattern: the goldens themselves carry the contract). At T01 close, the verifier passes because the golden was captured from HEAD. The moment T02's amendment lands, IF T02's amendment accidentally changes the unflagged stdout (e.g., a `printf` left in outside the new-class-regression branch), the verifier fails — surfacing the regression mechanically.

## Steps

1. **Create the fixture directory**:

   ```bash
   mkdir -p tests/fixtures/m030-p06
   ```

2. **Author the corpus synthesizer** at `tests/fixtures/m030-p06/synthesize-corpus.sh` per the shape in the Description. Bash 3.2-compatible. Make executable: `chmod +x tests/fixtures/m030-p06/synthesize-corpus.sh`.

3. **Run the synthesizer to produce all five corpora**:

   ```bash
   bash tests/fixtures/m030-p06/synthesize-corpus.sh
   ```

   Expected: five files exist with deterministic line counts:
   - `regression-mechanical.jsonl` — 20 lines
   - `regression-standard.jsonl` — 20 lines
   - `regression-novel.jsonl` — 20 lines
   - `no-regression.jsonl` — 60 lines
   - `below-min-sample.jsonl` — 5 lines

   Verify by running:
   ```bash
   bash tools/verify/p06-fixture-shape.sh  # IF authored at T01; otherwise the artifact-grep gates in step 5 cover this.
   ```

   (Optional: T01 may author a thin `p06-fixture-shape.sh` that asserts each file's line count + `character=` present. Recommended NOT — the artifact grep predicates in P06-PLAN.md's Artifacts section already cover shape via `check-must-haves.sh`.)

4. **Capture the pre-amendment golden baseline** for `check-anomalies.sh` against the pre-M030 fixture:

   ```bash
   tmp_root="$(mktemp -d -t p06-t01-baseline.XXXXXX)"
   mkdir -p "$tmp_root/milestones/M001"
   cp tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl "$tmp_root/milestones/M001/execution-log.jsonl"
   ```

   Then write the M001-CONTEXT.md milestone marker as a separate Bash invocation (heredoc inside a `cat >` is OK as a standalone line; pre-bash-shape-guard rejects compound shapes, not heredocs themselves):

   ```bash
   bash -c "cat > $tmp_root/milestones/M001/M001-CONTEXT.md << 'EOF_M001'
---
type: milestone-context
milestone: \"M001\"
status: open
---
EOF_M001"
   ```

   Then capture the baseline:

   ```bash
   ORCHESTRATOR_ROOT="$tmp_root" PROJECT_ROOT="$(pwd)" bash scripts/diagnostics/check-anomalies.sh --milestone M001 > tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt 2>/dev/null
   ```

   Then clean up:

   ```bash
   rm -rf "$tmp_root"
   ```

   Expected: `tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt` exists with the deterministic check-anomalies stdout block (≥1 line; typically the "Anomaly Detection (Tier 1 baseline)" header + one summary line).

5. **Author `tools/verify/p06-sc11-byte-equality.sh`** per the shape in the Description. Make executable: `chmod +x tools/verify/p06-sc11-byte-equality.sh`.

6. **Self-check the SC-11 gate against pre-amendment HEAD**:

   ```bash
   bash tools/verify/p06-sc11-byte-equality.sh
   ```

   Expected: exit 0 with `SUMMARY: p06-sc11-byte-equality.sh pass=1 fail=0`. The gate passes because the golden was captured from HEAD just now; this is the load-bearing T01 self-check that confirms the golden-capture mechanics work.

7. **Verify file shapes are correct** (artifact-grep predicates from the phase plan's Artifacts section):

   ```bash
   wc -l tests/fixtures/m030-p06/regression-mechanical.jsonl
   wc -l tests/fixtures/m030-p06/regression-standard.jsonl
   wc -l tests/fixtures/m030-p06/regression-novel.jsonl
   wc -l tests/fixtures/m030-p06/no-regression.jsonl
   wc -l tests/fixtures/m030-p06/below-min-sample.jsonl
   grep -c '"character":"mechanical"' tests/fixtures/m030-p06/regression-mechanical.jsonl
   grep -c '"escalation_count":1' tests/fixtures/m030-p06/regression-mechanical.jsonl
   ```

   Expected: 20/20/20/60/5 line counts respectively; `character=mechanical` count = 20 in regression-mechanical; `escalation_count=1` count = 12 (the failure records).

## Must-Haves

T01 satisfies the following phase truths:

- "SC-11 byte-equality through `check-anomalies.sh`" — gated by `bash tools/verify/p06-sc11-byte-equality.sh` (T01 deliverable; passes pre-T02 because golden was captured from HEAD; load-bearing for T02 to maintain).

The remaining seven phase truths (mechanical-regression, standard-regression, novel-regression, no-regression, below-min-sample, doctor-surfaces-anomaly, shadow-off-byte-equality) are gated by T02-authored verifiers. T01 only ships the corpora + golden these verifiers will consume.

## Verification

```bash
bash tools/verify/p06-sc11-byte-equality.sh
```

Single-script-file shape per AD-19. Must exit 0 before T01 closes. Emits `SUMMARY: p06-sc11-byte-equality.sh pass=1 fail=0` on success.

## Inputs

### From Disk (Pre-existing)

- `scripts/diagnostics/check-anomalies.sh` — Key API: `bash <path> [--milestone <M>] [--project] [--no-anomaly] [--yes] [--threshold <mult>] [--sample-floor <N>]`. Sourceable + CLI. Reads `metrics-rollup.sh` task-grain rollup. Emits "Anomaly Detection (Tier 1 baseline)" text block. Suppression matrix = 5 conditions. Bash 3.2 compatible. Always exits 0 (CON-5 never-abort).
- `scripts/diagnostics/run-doctor.sh` — Key API: `bash <path> [--root <P>] [--format text|json] [--config-check] [--routing-table <T>] [--no-anomaly]`. Invokes `check-anomalies.sh` at lines 154-159 as the "Anomaly Detection" advisory check. Pre-amendment doctor surface T02's check-anomalies stdout will flow through unchanged.
- `scripts/dispatch/dispatch-interface.sh` — Key API: emits `dispatch_usage` JSONL records to execution-log via `_di_emit_dispatch_usage`. Shadow-on emit branch (gated by `M030_SHADOW_MODE=1 && CLAUDECODE=1`) currently emits 9 additive fields beyond M019 baseline. T02 will append `character` as a 10th additive field.
- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` — Key API: 5-record JSONL fixture; pre-M030 schema (no `model_routed` / `model_used` / `character` field); M001/P01-P05 records. SC-11 baseline input.
- `templates/model-routing.yml` — Key API: shipped routing-table; default mapping `mechanical→fast / standard→balanced / novel→smart` for claude-code runtime.

### From Previous Tasks

T01 has no upstream tasks (depends_on: [] — preflight task). All inputs are pre-existing on disk.

## Constraints

- **AD-19 single-script-file shape**: every verifier under `tools/verify/p06-*` is invoked as a single `bash <path>` Check command. No compound `&&`/`||` chains, no `bash -c '...'` inline (with the narrow exception of the T01 baseline-capture step's heredoc redirect, which is a shell-builtin pattern that the shape-guard accepts), no `$(...)` containing pipes inside the verifier bodies' Check-command-equivalent invocations.
- **AP-008 heredoc-with-expansion**: NOT introduced — T01 ships only fixture data + verifier; no commit message authoring (T03 handles the close commit and uses `git commit -F <file>` per the CLAUDE.md guidance).
- **AP-009 compound-chain-gt2**: synthesizer and verifier use straight-line shape (one command per line; per-command `bash <path>` then `$?` capture). No 3-or-more-step `&&` chains.
- **Bash 3.2 compatibility**: synthesizer and verifier use parallel scalars, `while [ ... ]; do` loops, plain `case` statements, `[ ... ]` (not `[[ ... ]]`). No `declare -A`, no `mapfile`, no `readarray`, no process substitution `<(...)`, no `[[ ... =~ ... ]]`.
- **MEM004 emitter-internal carve-out**: does NOT apply to T01 (no emitter amendment in T01).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T01 introduces no SQL — N/A.
- **Plan-Time Discipline rule 4 (run-probe.sh scope)**: T01 invokes verifiers under `tools/verify/` and `scripts/diagnostics/` directly via `bash <path>`. No `run-probe.sh` invocations.
- **Project-owned-verifier-paths discipline ([M032](../../../../../milestones/M032/index.md) Finding A)**: every new verifier lives under `tools/verify/` with a slug-bearing filename `p06-*`. None under `scripts/verify/`.
- **Idempotency**: re-running `synthesize-corpus.sh` produces byte-identical output to the previously-committed corpora. Verified by running the synthesizer twice and `diff`-ing the second emission against the first.
- **Pre-amendment-tolerant graduation pattern (P02/T01 + P03/T01 + P04/T01 + P05/T01 lineage)**: T01's corpora carry the future-T02 `character` field forward-compatibly. The corpora are valid input to both the pre-T02 dispatch-interface (which would ignore `character`) and the post-T02 dispatch-interface (which emits it). The SC-11 gate ships byte-strict from the start (P05/T01 inverts P04/T01 — the goldens themselves carry the contract).

## Expected Output

- `tests/fixtures/m030-p06/synthesize-corpus.sh` — corpus synthesizer (executable; idempotent).
- `tests/fixtures/m030-p06/regression-mechanical.jsonl` — 20 records, `character=mechanical`, 12 fail / 8 pass.
- `tests/fixtures/m030-p06/regression-standard.jsonl` — 20 records, `character=standard`, 12 fail / 8 pass.
- `tests/fixtures/m030-p06/regression-novel.jsonl` — 20 records, `character=novel`, 12 fail / 8 pass.
- `tests/fixtures/m030-p06/no-regression.jsonl` — 60 records (20 per class), each class 4 fail / 16 pass.
- `tests/fixtures/m030-p06/below-min-sample.jsonl` — 5 mechanical records, 3 fail / 2 pass.
- `tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt` — pre-amendment check-anomalies stdout snapshot (≥1 line).
- `tools/verify/p06-sc11-byte-equality.sh` — SC-11 byte-equality gate; exits 0 against HEAD.

## Notes

Expected output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p06-sc11-byte-equality.sh` → `SUMMARY: p06-sc11-byte-equality.sh pass=1 fail=0`, exit 0.
- The pre-M030 baseline file's content (rough sample, depends on metrics-rollup over a 5-record fixture):
  ```
  Anomaly Detection (Tier 1 baseline)
  ANOMALY: no anomalies detected (n=5 median=<computed> mult=3.00)
  ```
  Or possibly an "ANOMALY: insufficient sample (n=N floor=5)" line if the rollup-task-row count drops below the default floor of 5. T01 captures whatever HEAD emits; the gate is byte-strict over THAT exact output.

The SC-11 gate is NOT pre-amendment-tolerant — it is byte-strict from the start. The golden is captured pre-amendment so the gate must pass at T01 close, and any T02 amendment that breaks unflagged byte-equality immediately surfaces as a fail at T02's self-check. This is the correct shape for an additive-schema regression contract: the test is the contract.

The forward-compatible `character=` field in the T01 fixtures means T02's check-anomalies amendment can be authored and tested against these fixtures BEFORE the dispatch-interface amendment lands — because the fixtures already carry the field shape T02's check-anomalies expects to read. Once the dispatch-interface amendment lands (T02 step 4-5), real shadow-on dispatches will start producing the same shape, validating the contract end-to-end.

If `M001-CONTEXT.md` heredoc creation in step 4 trips the pre-bash-shape-guard (e.g., the `bash -c "cat > $f << 'EOF'..."` pattern is rejected as compound), the alternative is to use the Write tool from the executor's harness directly — author the file on disk via the harness, not via shell heredoc. The synthesizer script itself does NOT need a heredoc; it only writes JSONL via `printf` + redirect, which is single-builtin shape.

If `find-active-milestone.sh` fails to find M001 in the carve-out (because the lone `M001-CONTEXT.md` doesn't satisfy its discovery heuristic), pass `--project` to `check-anomalies.sh` instead of `--milestone M001` — that falls back to project-granularity rollup which works against any execution-log. The golden capture and the verifier MUST use the same flag form so the byte-equality holds. T01 chooses one and documents the choice in the verifier's header comment.

If the M001-CONTEXT.md heredoc shape is harness-rejected even via the `bash -c "..."` form, the simplest workaround is to write a tiny one-line marker file using `printf '%s\n' '---' '...'` redirects — no heredoc needed. The shape `printf '%s\n' '---' 'type: milestone-context' 'milestone: "M001"' 'status: open' '---' > "$tmp_root/milestones/M001/M001-CONTEXT.md"` is a single command with one redirect.
