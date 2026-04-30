---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M030"
name: "P05 fixtures + golden baselines + SC-11 gates + doctor-config-check wrapper (preflight)"
depends_on: []
---

## Prerequisites

- `scripts/diagnostics/metrics-rollup.sh` exists in its post-M027/M018 form (~860 lines; sourceable + CLI; awk-based normalize → aggregate → render pipeline; reads M019 Tier 1 JSONL; emits a tabular cost+quality table to stdout). Verified at plan-time: `[ -f scripts/diagnostics/metrics-rollup.sh ]` returns true.
- `scripts/diagnostics/efficiency-footer.sh` exists in its post-M018/P05 form (~225 lines; sourceable function `efficiency_footer_render` + CLI; reads from `metrics-rollup.sh`; emits a multi-line footer block; carries the existing `compression:` line under a config knob). Verified at plan-time: `[ -f scripts/diagnostics/efficiency-footer.sh ]` returns true.
- `scripts/diagnostics/run-doctor.sh` exists with the `--config-check` flag wired (P01/T04 deliverable; reads `--routing-table` flag OR `ROUTING_TABLE_PATH` env OR default `templates/model-routing.yml`; invokes `tools/verify/p01-routing-table-shape.sh`; propagates `<file>:<lineno>` diagnostic; exits 1 on malformed table). Verified at plan-time: `[ -f scripts/diagnostics/run-doctor.sh ]` returns true.
- `tools/verify/p01-doctor-config-check.sh` exists and exits 0 against a clean checkout (P01/T04 deliverable; exercises both well-formed and malformed `templates/model-routing.yml` scenarios). Verified at plan-time: `[ -f tools/verify/p01-doctor-config-check.sh ]` returns true.
- `tools/verify/p01-routing-table-shape.sh` exists and validates routing-table shape (8 checks; `<file>:<lineno>` FAIL prefix). P01/T03 deliverable.
- `templates/model-routing.yml` exists with three top-level sections: `routing:` (3 chars × 3 runtimes), `resolution:` (3 tiers × 3 runtimes; `claude-code: "claude-haiku-4-5"|"claude-sonnet-4-7"|"claude-opus-4-7"`), `cost_rates:` (3 tiers; `input_per_mtok:` + `output_per_mtok:` numeric values).
- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` exists (P02/T01 deliverable; 5 records; pre-M030 schema; no `model_routed` field). The SC-11 byte-equality contract uses this corpus as the regression-test input.
- `scripts/dispatch/adapters/backend/stub.sh` exists (M019/P01/T05 reference for adapter shape — not directly used by T01 but linked in the prerequisite chain for completeness).
- `tests/fixtures/m030-p04/synthesize-corpora.sh` exists (P04/T01 deliverable; pattern reference for the `synthesize-corpus.sh` shape T01 will author for P05).

Plan-time prerequisite-existence verification: every path above is asserted at plan-authoring time. Script paths confirmed via direct read/list before T01 authorship.

## Description

T01 ships before any work on `scripts/diagnostics/metrics-rollup.sh` or `scripts/diagnostics/efficiency-footer.sh` so the SC-11 byte-equality contract has a mechanical gate at the moment T02's diff lands. Mirrors the P02/T01 + P03/T01 + P04/T01 graduation pattern (verifier-before-deliverable).

Five deliverable groups that ship as a single coherent commit at T01 close:

1. **Live-routed corpus** at `tests/fixtures/m030-p05/live-routed-corpus.jsonl`.
2. **Cost-rates-absent routing-table copy** at `tests/fixtures/m030-p05/no-cost-rates-routing.yml`.
3. **Pre-amendment golden baselines** at `tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt` + `tests/fixtures/m030-p05/footer-pre-m030-baseline.txt`.
4. **SC-11 byte-equality gates** at `tools/verify/p05-sc11-rollup-byte-equality.sh` + `tools/verify/p05-sc11-footer-byte-equality.sh`.
5. **Doctor-config-check wrapper** at `tools/verify/p05-doctor-config-check.sh`.

### Live-routed corpus shape

Each line is a complete JSONL `dispatch_usage` record matching the post-P04 schema. The corpus has exactly 23 records: 14 fast / 7 balanced / 2 smart (the demo-driven distribution from the roadmap). Each record has `record_type=dispatch_usage`, `unitId=M999/P01/T<NN>` (T01..T23), `milestone=M999`, `phase=P01`, `task=T<NN>`, `backend=stub`, `input_tokens_estimate=1024`, `output_tokens_estimate=512`, `model_routed=<tier>`, `model_used=<resolved-id>` (the same value the P04 dispatch-interface emits when live-routed; for fast use `claude-haiku-4-5`, balanced `claude-sonnet-4-7`, smart `claude-opus-4-7`), `classifier_confidence=high`, `partial_flip_active=false`, `withheld_classes=""`, `override_source=none`, `escalation_count=0`, `escalation_reason=""`, plus the standard M019/M027 fields (`source=estimate`, `pricing_version=2026-04-17`, `emission_point=dispatch-interface`, `timestamp=<ISO8601>`).

Synthesizable via a literal Bash script (`tests/fixtures/m030-p05/synthesize-corpus.sh`):

```bash
#!/usr/bin/env bash
# tests/fixtures/m030-p05/synthesize-corpus.sh
# Emits 23 deterministic shadow-on dispatch_usage records to stdout.
# 14 fast / 7 balanced / 2 smart. Idempotent — re-running produces
# byte-identical output.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPT_DIR/live-routed-corpus.jsonl"
: > "$OUT"

emit_record() {
  local n="$1"
  local tier="$2"
  local model_id="$3"
  local ts="$4"
  printf '{"record_type":"dispatch_usage","unitId":"M999/P01/T%02d","milestone":"M999","phase":"P01","task":"T%02d","backend":"stub","input_tokens_estimate":1024,"output_tokens_estimate":512,"estimated_cost_usd":0.01536000,"pricing_version":"2026-04-17","filter_dropped_tokens":0,"tier1_savings_tokens":0,"tier2_savings_tokens":0,"tier1_invocations":0,"tier3_compression_savings_tokens":0,"tier3_invocations":0,"model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s","classifier_confidence":"high","model_routed":"%s","model_used":"%s","partial_flip_active":false,"withheld_classes":"","override_source":"none","escalation_count":0,"escalation_reason":""}\n' "$n" "$n" "$model_id" "$ts" "$tier" "$model_id" >> "$OUT"
}

n=1
# 14 fast
while [ "$n" -le 14 ]; do
  emit_record "$n" "fast" "claude-haiku-4-5" "2026-04-30T10:$(printf '%02d' "$n"):00Z"
  n=$((n + 1))
done
# 7 balanced
while [ "$n" -le 21 ]; do
  emit_record "$n" "balanced" "claude-sonnet-4-7" "2026-04-30T10:$(printf '%02d' "$n"):00Z"
  n=$((n + 1))
done
# 2 smart
while [ "$n" -le 23 ]; do
  emit_record "$n" "smart" "claude-opus-4-7" "2026-04-30T10:$(printf '%02d' "$n"):00Z"
  n=$((n + 1))
done
```

The synthesizer is committed alongside the corpus for reproducibility.

### Cost-rates-absent routing-table copy

`tests/fixtures/m030-p05/no-cost-rates-routing.yml` is a verbatim copy of `templates/model-routing.yml` with the `cost_rates:` section (and its three child entries) removed. The remaining sections (frontmatter + `routing:` + `resolution:`) are byte-identical so the routing-table-shape verifier still considers the file valid (P01's check #5 only enforces cost_rates: → resolution: closure WHEN cost_rates: is present, not that it must be present; if check #5 fails on absence, T01 must additionally amend the routing-table-shape verifier to make cost_rates: optional — flagged as a contingent T01 step).

Static text shape (heredoc-able but the file is committed as plain text):

```yaml
---
schema_version: "1.0"
type: model-routing-table
milestone: "M030"
created_at: "2026-04-30"
---

routing:
  mechanical:
    claude-code: fast
    codex-cli: inherit
    cursor: inherit
  standard:
    claude-code: balanced
    codex-cli: inherit
    cursor: inherit
  novel:
    claude-code: smart
    codex-cli: inherit
    cursor: inherit

resolution:
  fast:
    claude-code: "claude-haiku-4-5"
    codex-cli: inherit
    cursor: inherit
  balanced:
    claude-code: "claude-sonnet-4-7"
    codex-cli: inherit
    cursor: inherit
  smart:
    claude-code: "claude-opus-4-7"
    codex-cli: inherit
    cursor: inherit
```

(No `cost_rates:` section. ~50 lines total.)

### Pre-amendment golden baselines

T01 captures stdout snapshots of `metrics-rollup.sh` and `efficiency-footer.sh` against the pre-M030 fixture BEFORE T02 amends them. The captured snapshots are the SC-11 contract.

Captured via:

```bash
bash scripts/diagnostics/metrics-rollup.sh \
  --log tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl \
  --granularity milestone --milestone M001 \
  > tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt 2>/dev/null

bash scripts/diagnostics/efficiency-footer.sh \
  --milestone M001 \
  > tests/fixtures/m030-p05/footer-pre-m030-baseline.txt 2>/dev/null
```

Important: the second invocation needs a way to point the footer at the pre-M030 fixture corpus. The footer's CLI takes `--milestone` and resolves the log path internally (under `.orchestrator/milestones/<M>/execution-log.jsonl`). Two strategies:

- **Strategy A (preferred): ORCHESTRATOR_ROOT carve-out**. Stage a tmp directory `tmp_root/milestones/M999/execution-log.jsonl` symlinked or copied from the pre-M030 fixture; invoke the footer with `ORCHESTRATOR_ROOT=tmp_root` `--milestone M999`. The footer's `_metrics_rollup_orch_root` resolver respects `ORCHESTRATOR_ROOT`. Same pattern P02/P03/P04 verifiers used.
- **Strategy B: leverage rollup `--log` flag**. The rollup CLI takes `--log <path>`; the footer does NOT take `--log` directly but invokes the rollup. T01 captures the baseline by running the rollup directly with `--log` and the footer via the carve-out — they're separate captures so the strategies can differ.

T01 documents the chosen strategy in the synthesizer comments. Recommended: Strategy A for both captures so the SC-11 gates exercise the full footer code-path.

The baselines are byte-identical regardless of capture-time machine state because the rollup and footer are deterministic functions of their JSONL input.

### SC-11 byte-equality gates

`tools/verify/p05-sc11-rollup-byte-equality.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/p05-sc11-rollup-byte-equality.sh — SC-11 byte-equality gate.
# Asserts the unflagged metrics-rollup.sh emission against the pre-M030
# fixture is byte-identical to the committed golden baseline.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BASELINE="$PROJECT_ROOT/tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl"

pass=0
fail=0

if [ ! -f "$BASELINE" ]; then
  echo "FAIL: baseline missing at $BASELINE"
  echo "SUMMARY: p05-sc11-rollup-byte-equality.sh pass=0 fail=1"
  exit 1
fi

if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: fixture missing at $FIXTURE"
  echo "SUMMARY: p05-sc11-rollup-byte-equality.sh pass=0 fail=1"
  exit 1
fi

ACTUAL="$(mktemp -t p05-sc11-rollup-actual.XXXXXX)"
trap 'rm -f "$ACTUAL"' EXIT

bash "$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
  --log "$FIXTURE" \
  --granularity milestone --milestone M001 \
  > "$ACTUAL" 2>/dev/null

if diff -u "$BASELINE" "$ACTUAL"; then
  pass=1
  echo "OK: rollup output byte-identical to baseline"
else
  fail=1
  echo "FAIL: rollup output differs from baseline (see diff above)"
fi

echo "SUMMARY: p05-sc11-rollup-byte-equality.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

`tools/verify/p05-sc11-footer-byte-equality.sh` follows the same shape but invokes `scripts/diagnostics/efficiency-footer.sh` against an `ORCHESTRATOR_ROOT=tmp_root` carve-out where `tmp_root/milestones/M001/execution-log.jsonl` is a copy of the pre-M030 fixture. The verifier stages the carve-out per-invocation (mktemp -d + cp + invoke + diff + cleanup).

### Doctor-config-check wrapper

`tools/verify/p05-doctor-config-check.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/p05-doctor-config-check.sh — SC-9 inheritor wrapper.
# Delegates to tools/verify/p01-doctor-config-check.sh (P01/T04 deliverable)
# which exercises both well-formed and malformed templates/model-routing.yml
# scenarios against scripts/diagnostics/run-doctor.sh --config-check.
# This wrapper exists so the P05 phase-suite carries the SC-9 contract gate
# without re-implementing the underlying scenarios.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

bash "$PROJECT_ROOT/tools/verify/p01-doctor-config-check.sh"
rc=$?

pass=0
fail=0
if [ "$rc" -eq 0 ]; then
  pass=1
  echo "OK: p01-doctor-config-check.sh exited 0 (SC-9 gate green)"
else
  fail=1
  echo "FAIL: p01-doctor-config-check.sh exited $rc"
fi

echo "SUMMARY: p05-doctor-config-check.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

## Steps

1. **Create the fixture directory**:

   ```bash
   mkdir -p tests/fixtures/m030-p05
   ```

2. **Author the corpus synthesizer** at `tests/fixtures/m030-p05/synthesize-corpus.sh` per the shape in the Description. Bash 3.2-compatible (no `declare -A`, no `mapfile`). Make executable: `chmod +x tests/fixtures/m030-p05/synthesize-corpus.sh`.

3. **Run the synthesizer to produce the corpus**:

   ```bash
   bash tests/fixtures/m030-p05/synthesize-corpus.sh
   ```

   Expected: `tests/fixtures/m030-p05/live-routed-corpus.jsonl` exists with exactly 23 lines. Verify: `wc -l tests/fixtures/m030-p05/live-routed-corpus.jsonl` returns `23`.

4. **Author the cost-rates-absent routing-table copy** at `tests/fixtures/m030-p05/no-cost-rates-routing.yml`. Use the Write tool with the static YAML text from the Description (no `cost_rates:` section).

5. **Verify the cost-rates-absent file passes routing-table-shape validation**:

   ```bash
   bash tools/verify/p01-routing-table-shape.sh tests/fixtures/m030-p05/no-cost-rates-routing.yml
   ```

   Expected: exit 0 with `SUMMARY: p01-routing-table-shape.sh pass=N fail=0`. If the shape verifier rejects on absence of `cost_rates:` (P01 check #5 may require its presence), T01 must additionally amend `tools/verify/p01-routing-table-shape.sh` to treat `cost_rates:` as optional — verify the failure message and amend if needed (this is in-scope for T01 because the cost_rates-absent fallback is the FR-15 contract, and the routing-table-shape verifier must permit it).

6. **Capture the rollup pre-amendment golden baseline**:

   ```bash
   bash scripts/diagnostics/metrics-rollup.sh \
     --log tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl \
     --granularity milestone --milestone M001 \
     > tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt 2>/dev/null
   ```

   Expected: `tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt` exists and contains the rollup's tabular output (header line + at least one data row corresponding to the pre-M030 fixture's M001 records).

7. **Capture the footer pre-amendment golden baseline**. Stage the ORCHESTRATOR_ROOT carve-out:

   ```bash
   tmp_root="$(mktemp -d -t p05-t01-footer-baseline.XXXXXX)"
   mkdir -p "$tmp_root/milestones/M001"
   cp tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl "$tmp_root/milestones/M001/execution-log.jsonl"
   ORCHESTRATOR_ROOT="$tmp_root" bash scripts/diagnostics/efficiency-footer.sh \
     --milestone M001 \
     > tests/fixtures/m030-p05/footer-pre-m030-baseline.txt 2>/dev/null
   rm -rf "$tmp_root"
   ```

   Expected: `tests/fixtures/m030-p05/footer-pre-m030-baseline.txt` exists with the footer's multi-line output.

8. **Author `tools/verify/p05-sc11-rollup-byte-equality.sh`** per the shape in the Description. Make executable.

9. **Author `tools/verify/p05-sc11-footer-byte-equality.sh`** per the same shape, but invoking `efficiency-footer.sh` via the `ORCHESTRATOR_ROOT=tmp_root` carve-out (verifier stages the carve-out per-invocation; cleans up via trap).

10. **Author `tools/verify/p05-doctor-config-check.sh`** per the shape in the Description. Make executable.

11. **Self-check the four T01 verifiers** all pass against the pre-amendment HEAD:

    ```bash
    bash tools/verify/p05-sc11-rollup-byte-equality.sh
    bash tools/verify/p05-sc11-footer-byte-equality.sh
    bash tools/verify/p05-doctor-config-check.sh
    ```

    Expected: all three exit 0. The first two pass because the goldens were captured from the pre-amendment HEAD (so post-T01 == pre-T01 == HEAD). The third passes because P01/T04's `p01-doctor-config-check.sh` is already green on a clean checkout.

12. **Verify file shapes are correct** (artifact-grep predicates from the phase plan's Artifacts section):

    ```bash
    grep -c "model_routed" tests/fixtures/m030-p05/live-routed-corpus.jsonl
    grep -c "fast" tests/fixtures/m030-p05/live-routed-corpus.jsonl
    grep -c "balanced" tests/fixtures/m030-p05/live-routed-corpus.jsonl
    grep -c "smart" tests/fixtures/m030-p05/live-routed-corpus.jsonl
    wc -l tests/fixtures/m030-p05/live-routed-corpus.jsonl
    ```

    Expected: `model_routed` count = 23 (one per record); `fast` count >= 14 (appears in `model_routed`, `model_used` model-id strings, etc.); `balanced` count >= 7; `smart` count >= 2; `wc -l` = 23.

## Must-Haves

T01 satisfies the following phase truths:

- "SC-11 byte-equality through unflagged `metrics-rollup.sh`" — gated by `bash tools/verify/p05-sc11-rollup-byte-equality.sh` (T01 deliverable; passes pre-T02 because golden was captured from HEAD; load-bearing for T02 to maintain).
- "SC-11 byte-equality through unflagged `efficiency-footer.sh`" — gated by `bash tools/verify/p05-sc11-footer-byte-equality.sh` (T01 deliverable; same logic).
- "SC-9 doctor `--config-check` continues to exit 1 with file+lineno on a malformed `templates/model-routing.yml`" — gated by `bash tools/verify/p05-doctor-config-check.sh` (T01 deliverable; delegates to P01/T04's gate).

The remaining four phase truths (by-model-dispatch-counts, by-model-cost-rates-present, by-model-cost-rates-absent, model-mix-footer-line) are gated by T02-authored verifiers. T01 only ships the corpus + cost-rates-absent fixture + goldens these verifiers will consume.

## Verification

```bash
bash tools/verify/p05-sc11-rollup-byte-equality.sh
bash tools/verify/p05-sc11-footer-byte-equality.sh
bash tools/verify/p05-doctor-config-check.sh
```

Each command uses single-script-file shape per AD-19. All three must exit 0 before T01 closes. Each emits `SUMMARY: <verifier-name> pass=N fail=0` on success.

## Inputs

### From Disk (Pre-existing)

- `scripts/diagnostics/metrics-rollup.sh` — Key API: `bash <path> --log <jsonl> --granularity milestone --milestone <id>` emits a tabular cost+quality table to stdout. Read-only on the JSONL. Exit 0 on success (including "no Tier 1 records yet"). Used by T01 step 6 to capture the golden baseline.
- `scripts/diagnostics/efficiency-footer.sh` — Key API: `bash <path> --milestone <id>` emits a multi-line footer block. Reads `metrics-rollup.sh` internally. Respects `ORCHESTRATOR_ROOT` env. Exit 0 always. Used by T01 step 7 to capture the golden baseline.
- `tools/verify/p01-doctor-config-check.sh` — Key API: `bash <path>` runs P01/T04's two-scenario doctor-config-check gate. Exit 0 on green. Delegated to by `p05-doctor-config-check.sh`.
- `tools/verify/p01-routing-table-shape.sh` — Key API: `bash <path> [<routing-table-path>]` validates routing-table shape. Exit 0 on valid. Used by T01 step 5 to verify the cost-rates-absent copy is shape-valid.
- `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` — Key API: 5-record JSONL fixture; pre-M030 schema (no `model_routed` field); M001/P01-P05 records. SC-11 baseline input.
- `tests/fixtures/m030-p04/synthesize-corpora.sh` — pattern reference for the synthesizer shape. Read-only.

### From Previous Tasks

T01 has no upstream tasks (depends_on: [] — preflight task). All inputs are pre-existing on disk.

## Constraints

- **AD-19 single-script-file shape**: every verifier under `tools/verify/p05-*` is invoked as a single `bash <path>` Check command. No compound `&&`/`||` chains, no `bash -c '...'` inline, no `$(...)` containing pipes inside the verifier bodies' Check-command-equivalent invocations.
- **AP-008 heredoc-with-expansion**: NOT introduced — T01 ships only fixture data + verifiers; no commit message authoring.
- **Bash 3.2 compatibility**: synthesizer and verifiers use parallel scalars, `while [ ... ]; do` loops, plain `case` statements. No `declare -A`, no `mapfile`, no `readarray`, no process substitution `<(...)`, no `[[ ... =~ ... ]]`.
- **MEM004 emitter-internal carve-out**: does NOT apply to T01 verifiers (they ARE the Check-command targets, not emitter-internal libraries).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T01 introduces no SQL — N/A.
- **Plan-Time Discipline rule 4 (run-probe.sh scope)**: T01 invokes verifiers under `tools/verify/` and `scripts/diagnostics/` directly via `bash <path>`. No `run-probe.sh` invocations (those are reserved for staged throwaway probes under `/tmp` / `/var/folders` / `tmp/`).
- **Project-owned-verifier-paths discipline (MEM/M032 Finding A)**: every new verifier lives under `tools/verify/` with a slug-bearing filename `p05-*`. None under `scripts/verify/` (which is bulk-staged framework dir, gitignored in consumer projects, vulnerable to clobber on next install).
- **Idempotency**: re-running `synthesize-corpus.sh` produces byte-identical output to the previously-committed `live-routed-corpus.jsonl`. Verified by `diff` against a re-synthesis post-commit.

## Expected Output

- `tests/fixtures/m030-p05/live-routed-corpus.jsonl` — 23 lines, deterministic JSONL records with the documented per-tier distribution (14 fast / 7 balanced / 2 smart).
- `tests/fixtures/m030-p05/no-cost-rates-routing.yml` — ~50 lines, valid routing-table YAML without the `cost_rates:` section.
- `tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt` — pre-amendment rollup stdout snapshot.
- `tests/fixtures/m030-p05/footer-pre-m030-baseline.txt` — pre-amendment footer stdout snapshot.
- `tests/fixtures/m030-p05/synthesize-corpus.sh` — corpus synthesizer script (executable; idempotent).
- `tools/verify/p05-sc11-rollup-byte-equality.sh` — rollup SC-11 gate; exits 0 against HEAD.
- `tools/verify/p05-sc11-footer-byte-equality.sh` — footer SC-11 gate; exits 0 against HEAD.
- `tools/verify/p05-doctor-config-check.sh` — doctor SC-9 wrapper; exits 0 against HEAD.

## Notes

Expected output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p05-sc11-rollup-byte-equality.sh` → `SUMMARY: p05-sc11-rollup-byte-equality.sh pass=1 fail=0`, exit 0.
- `bash tools/verify/p05-sc11-footer-byte-equality.sh` → `SUMMARY: p05-sc11-footer-byte-equality.sh pass=1 fail=0`, exit 0.
- `bash tools/verify/p05-doctor-config-check.sh` → `SUMMARY: p05-doctor-config-check.sh pass=1 fail=0`, exit 0.

The SC-11 gates are NOT pre-amendment-tolerant (unlike P04/T01's `p04-override-source-enum-extended.sh`). They are byte-strict from the start — the goldens are captured pre-amendment so the gate must pass at T01 close, and any T02 amendment that breaks unflagged byte-equality immediately surfaces as a fail at T02's self-check. This is the correct shape for an additive-schema regression contract: the test is the contract.

If the rollup-shape check rejects the cost-rates-absent fixture (Step 5), T01 must amend `tools/verify/p01-routing-table-shape.sh` to relax the cost_rates: presence requirement. Specifically: P01 check #5 ("every cost_rates: tier has matching resolution: tier") should hold ONLY when cost_rates: is present; absence is permitted (the FR-15 fallback path requires the rollup to handle this case at runtime). The amendment is a single-condition guard: `if cost_rates_present && !cost_rates_closure_holds: FAIL` rather than `if !cost_rates_closure_holds: FAIL`. If implementing this amendment, also verify `tools/verify/p01-doctor-config-check.sh` Scenario A (well-formed shipped routing.yml with cost_rates: present) still passes — the amendment must be backward-compatible.

If the footer's golden capture (Step 7) emits zero bytes (because the pre-M030 fixture has 5 records with no shadow-on data, which under some footer config combinations might suppress the entire body), the SC-11 footer gate is degenerate but still meaningful: it asserts that whatever the footer emitted pre-amendment continues to emit post-amendment. Empty-bytes equality is still byte-equality.
