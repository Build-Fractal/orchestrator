---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P06"
milestone: "M018"
name: "scripts/diagnostics/compression-eval.sh `--tier 3` real cohort logic replaces the P05 reservation stub; reads `tier3_compression_savings_tokens` from payload_breakdown rows; reports per-cohort + delta means for verification_pass_rate / retry_count / deviation_count with 95% CIs; below-floor `insufficient sample` and exit 0; sourceable + CLI shape preserved (FR-12 / CON-5 / AD-19)"
depends_on: ["T02"]
---

## Prerequisites

- T02 has shipped the additive `tier3_compression_savings_tokens` field on `payload_breakdown` records. T03 cohort-classifies units on this field.
- The P05/T03 implementation of `compression-eval.sh` is the canonical shape T03 mirrors. Re-read it in full before authoring (full plan at `.orchestrator/milestones/M018/phases/P05/tasks/T03-compression-eval-PLAN.md`). Specifically the cohort-build awk pass at lines ~174-306 of the existing script.
- The P05 stub at lines ~145-155 of the existing script:

  ```bash
  case "$tier" in
    1|2) ;;
    3)
      printf 'tier 3 reserved for P06; not yet supported\n'
      return 0
      ;;
    *)
      printf 'unsupported tier=%s (must be 1, 2, or 3)\n' "$tier"
      return 0
      ;;
  esac
  ```

  T03 replaces the `3)` arm with a fall-through into the existing tier-1/tier-2 cohort-build logic, but with the cohort field switched on `tier3_compression_savings_tokens` instead of `tier1_savings_tokens` / `tier2_savings_tokens`.
- The cohort field switch is the only behavioral change inside the awk pass:

  ```awk
  /"record_type":"payload_breakdown"/ {
    # ... existing milestone / phase / task extraction ...
    if (tier == "1") {
      v = field_num($0, "tier1_savings_tokens")
    } else if (tier == "2") {
      v = field_num($0, "tier2_savings_tokens")
    } else if (tier == "3") {
      v = field_num($0, "tier3_compression_savings_tokens")
    }
    if (v > 0) tier_fired[key] = 1
    else if (!(key in tier_fired)) tier_fired[key] = 0
  }
  ```

  The unit_close-side cohort metrics (verification_pass_rate, retry_count, deviation_count) and the END block (Wilson 95% CI for proportions, pooled SEM for counts, regression_flag advisory) are unchanged — the diagnostic computes the same outcome-rate deltas regardless of which tier defines the cohort split.
- The CLI surface stays unchanged: `--milestone <Mxxx>`, `--tier <N>`, `--sample-floor <N>`. T03 only changes the case-arm body for `--tier 3` from "advisory stub" to "fall-through to cohort logic."
- AD-19 / AP-009: T03's task-local extractable Check is `bash -n scripts/diagnostics/compression-eval.sh`. The canonical truth verifier `m018-p06-compression-eval-tier3.sh` ships in T04.
- MEM004 emitter-internal carve-out applies inside the `compression-eval.sh` body — pipes / awk / `$()` permitted (the existing P05 implementation already uses them; T03 just extends).
- FR-12 (read-only diagnostic): never appends to or rewrites JSONL; always exits 0. T03 preserves this — the only mutation is in-process awk state.
- Bash 3.2 (MEM001).

## Description

T03 ships a single-file modification to `scripts/diagnostics/compression-eval.sh`:

1. The case-arm at the top of `compression_eval_render` for `tier=3` no longer emits "tier 3 reserved for P06" — it falls through into the cohort-build logic.
2. The cohort-build awk pass is widened with a third tier-arm that reads `tier3_compression_savings_tokens` (instead of `tier1_savings_tokens` / `tier2_savings_tokens`) for the cohort split.
3. The header line and the regression_flag wording stay byte-identical; the diagnostic continues to emit `# compression-eval — milestone=<id> tier=3` followed by the same COHORT / delta block.

T03 does NOT ship:

- `_bc_apply_tier3` helper or prompt template (T01).
- Schema extensions (T02 — that ships the field T03 reads).
- Verifiers, fixtures, fixture-staging helper, P06-SUMMARY, dual-write (T04).
- A new tier3-specific quality regression metric (the diagnostic continues to report verification_pass_rate / retry_count / deviation_count — the same three outcome-rate metrics tier 1 / tier 2 use).

## Inputs

Surface contracts T03 reads from upstream files:

- `scripts/diagnostics/compression-eval.sh` (P05/T03 implementation, full file ~279 lines) — the canonical shape T03 modifies in two places:
  - The case-arm at lines ~145-155 (the `3)` arm currently returns the stub).
  - The cohort-build awk pass at lines ~197-208 (the tier-1/tier-2 if/else; T03 widens to tier-1/tier-2/tier-3).

- `scripts/dispatch/build-context.sh:_bc_emit_payload_breakdown` (T02-widened) — confirms the JSONL field name is `tier3_compression_savings_tokens` (full key, no abbreviation; matches the spec FR-10 + the T02 printf line).

- `scripts/diagnostics/efficiency-footer.sh` and `check-anomalies.sh` (T02-widened) — read for the awk extraction pattern T03 mirrors:

  ```awk
  if (match($0, /"tier3_compression_savings_tokens":[0-9]+/)) {
    v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); ...
  }
  ```

  The same `match() / substr() / sub(/.*:/)` extraction works inside compression-eval's `field_num()` helper (which already implements this pattern generically — see lines ~175-181 of the existing script).

## Steps

### Step 1 — Replace the `tier=3` case-arm

In `scripts/diagnostics/compression-eval.sh`, locate the case statement around lines ~145-155:

```bash
  case "$tier" in
    1|2) ;;
    3)
      printf 'tier 3 reserved for P06; not yet supported\n'
      return 0
      ;;
    *)
      printf 'unsupported tier=%s (must be 1, 2, or 3)\n' "$tier"
      return 0
      ;;
  esac
```

Replace with:

```bash
  case "$tier" in
    1|2|3) ;;
    *)
      printf 'unsupported tier=%s (must be 1, 2, or 3)\n' "$tier"
      return 0
      ;;
  esac
```

The `3` arm now falls through to the cohort-build logic identically to `1` and `2`.

### Step 2 — Widen the cohort-build awk pass

Locate the existing if/else inside the awk pass (around lines ~202-208 of the existing script):

```awk
/"record_type":"payload_breakdown"/ {
  m = field_str($0, "milestone")
  p = field_str($0, "phase")
  t = field_str($0, "task")
  key = m "/" p "/" t
  if (tier == "1") {
    v = field_num($0, "tier1_savings_tokens")
  } else {
    v = field_num($0, "tier2_savings_tokens")
  }
  if (v > 0) tier_fired[key] = 1
  else if (!(key in tier_fired)) tier_fired[key] = 0
}
```

Replace with:

```awk
/"record_type":"payload_breakdown"/ {
  m = field_str($0, "milestone")
  p = field_str($0, "phase")
  t = field_str($0, "task")
  key = m "/" p "/" t
  if (tier == "1") {
    v = field_num($0, "tier1_savings_tokens")
  } else if (tier == "2") {
    v = field_num($0, "tier2_savings_tokens")
  } else if (tier == "3") {
    v = field_num($0, "tier3_compression_savings_tokens")
  } else {
    v = 0
  }
  if (v > 0) tier_fired[key] = 1
  else if (!(key in tier_fired)) tier_fired[key] = 0
}
```

The `else` arm is defensive — should never fire because the case statement at the bash level rejects unknown tiers — but it preserves zero-fill safety on accidental call paths.

### Step 3 — Verify no other code path treats tier=3 as a stub

Grep the rest of the file for any other `tier 3` / `"3"` references that may carry the stub intent forward:

```
grep -n 'tier.*3\|"3"' scripts/diagnostics/compression-eval.sh
```

Expected: only the case-arm at the top and the new awk arm. No other behavior changes.

### Step 4 — Self-check during development

```bash
bash -n scripts/diagnostics/compression-eval.sh
bash scripts/diagnostics/compression-eval.sh --help
bash scripts/diagnostics/compression-eval.sh --milestone M018 --tier 3 --sample-floor 1
```

Expected:

- `bash -n` exits 0.
- `--help` emits the usage block and exits 0.
- `--tier 3 --sample-floor 1` against the live M018 log either reports a cohort (if any tier3 records exist post-T01/T02 dispatches) OR `insufficient sample` (most likely outcome — T1/T2/T3 haven't fired enough times in P06's planning pass to populate cohorts). Exit 0 in both cases.

The diagnostic MUST NOT emit the literal string "tier 3 reserved for P06" any longer.

## Verification

T03 ships only production code modification. The canonical truth verifier `m018-p06-compression-eval-tier3.sh` ships in T04 and asserts:

- `--tier 3` against a fixture log carrying tier3 records produces the same COHORT / delta block shape that `--tier 1` produces.
- `--tier 3 --sample-floor 1000` against the same fixture emits `insufficient sample`.
- The diagnostic no longer emits "tier 3 reserved for P06" against any fixture.
- `bash -n` self-check passes.

T03's task-local extractable Check is the syntax-only self-check:

- Check: `bash -n scripts/diagnostics/compression-eval.sh`

## Must-Haves (subset addressed by this task)

- **Truth #4**: `compression-eval.sh --tier 3` real cohort logic replaces the P05 stub. Wholly addressed by Steps 1, 2, 3.

T03 does not address Truths #1 (T01), #2 (T01), #3 (T02), or #5 (T04).

## Notes

- **Single-file change**: T03 is a surgical modification to one script. The narrow surface is intentional — the cohort-segmentation awk pass, the Wilson 95% CI / pooled-SE arithmetic, and the regression_flag advisory threshold are all already correct (P05/T03 implemented them). Tier 3's only difference from tier 1 / tier 2 is the JSONL field name that drives the cohort split.
- **No new metrics**: the diagnostic continues to report verification_pass_rate / retry_count / deviation_count for the cohort split. Tier 3-specific quality regression (e.g., "summary lost a load-bearing MEM ID") is the preservation-self-check's job (T01) and the manual RISK-3 review's job (phase-close), not compression-eval's.
- **`else { v = 0 }` defensive arm**: the case statement at the bash level prevents tier=4 / tier=5 / etc. from reaching the awk pass. The defensive arm in awk is for paranoia — it ensures `v` is always defined, which guards against awk's `uninitialized variable` warnings under stricter awk implementations.
- **Always-exit-0 contract preserved**: the diagnostic continues to emit text on stdout for every degraded input case (missing log, unsupported tier, insufficient sample, malformed args). Tier 3 fall-through doesn't change this.
- **No JSONL writes**: T03 doesn't add any JSONL emit path; the diagnostic remains read-only per FR-12.
- **MEM004 carve-out** applies — the awk pass is dispatch-internal; pipes / `$()` / awk permitted.
- **AD-19 / AP-009**: every Check at task-plan level is a single-script-file invocation. T03's `bash -n` self-check satisfies this; T04's verifier asserts the same Check shape on its own canonical verifier.
- **Bash 3.2** (MEM001): no `declare -A`. The awk pass uses awk indexed maps (`tier_fired[key]`, `pr_sum[cohort]`, etc.) which awk supports natively under all POSIX awks.
