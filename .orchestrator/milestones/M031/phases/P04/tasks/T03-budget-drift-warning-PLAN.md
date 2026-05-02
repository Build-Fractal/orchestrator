---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M031"
name: "efficiency-footer.sh QUICK_BUDGET_DRIFT warning (AD-19) + AD-19 acceptance test"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: `templates/orchestrator-config-default.yml` carries the `quick_knowledge_token_budget` knob (default 800); the SC-9 + SC-10 verifiers exist and pass.
- T02 complete: `scripts/diagnostics/run-doctor.sh` carries the AD-9 compound-change message; the AD-9 acceptance test exists and passes.
- `scripts/diagnostics/efficiency-footer.sh` exists at the project root (currently 259 lines per the planner's plan-time inspection).
- The M027 efficiency-footer JSONL stream convention is in place — the script reads `payload_breakdown` records and emits efficiency-footer JSONL records with structured fields.
- P01's `payload_breakdown` JSONL records are emitted by `scripts/dispatch/build-context.sh` and contain a `knowledge_section_tokens` field per the AD-11 sidecar schema.
- `tests/m031-acceptance/` directory exists.
- `tools/verify/` directory exists.

## Description

T03 amends `scripts/diagnostics/efficiency-footer.sh` to emit a `QUICK_BUDGET_DRIFT` informational JSONL record when the rolling median of `knowledge_section_tokens` across the most recent 7 Quick-profile dispatches exceeds `quick_knowledge_token_budget × 1.1`.

**Design contract (AD-19)**:

- **Window**: the most recent 7 consecutive Quick-profile dispatches (read from the `payload_breakdown` JSONL stream, filtered by `profile == "quick"`).
- **Threshold**: `quick_knowledge_token_budget × 1.1` where the budget is read from the active `.orchestrator/config.yml` if the knob is set, else from `templates/orchestrator-config-default.yml` (default 800), else from a hardcoded fallback (800).
- **Statistic**: rolling median of `knowledge_section_tokens` across the 7-record window.
- **Trigger**: `median > threshold` fires the warning. `median <= threshold` does NOT fire.
- **Output**: a JSONL record carrying the literal substring `QUICK_BUDGET_DRIFT` (e.g. `{"warning":"QUICK_BUDGET_DRIFT","window":7,"median":880,"budget":800,"threshold":880}` — exact field set is implementation-defined; the literal `QUICK_BUDGET_DRIFT` is the load-bearing contract). Emitted to the same stream as the existing efficiency-footer records.
- **Non-blocking**: the warning is **informational only**. The script's exit code is unaffected; existing call sites continue to function unchanged.

**Test-only seam**: T03 stages an `ORCH_EFFICIENCY_FOOTER_INPUT` env override (or equivalent — `--records-from <path>` flag is also acceptable; pick the option that fits the script's existing input-resolution pattern best). When set, the script reads `payload_breakdown` records from the named path instead of from the production JSONL stream. The SC test pipes a fixture 7-record stream via this seam.

## Steps

1. **Read `scripts/diagnostics/efficiency-footer.sh`** with the `Read` tool. Identify:
   - The current input-resolution path (where it reads `payload_breakdown` records from). Common shapes: a hardcoded path under `.orchestrator/observability/`, an argument-driven path, or a stdin pipe.
   - The current output-emission shape (where it writes efficiency-footer records). Match this shape for the new `QUICK_BUDGET_DRIFT` record.
   - Whether the script already reads config values (likely yes — it probably reads cost-related knobs already).
   - Whether the script already uses any windowed-stat helpers (e.g. a median or rolling-window function) — if yes, reuse; if no, implement inline.

2. **Add the input-resolution env override** at the top of the script (after `set -u` / `set -e`). Pseudo-shape:

   ```bash
   # M031/P04/T03: test-only env override for fixture-driven AD-19 testing.
   if [ -n "${ORCH_EFFICIENCY_FOOTER_INPUT:-}" ]; then
     INPUT_PATH="$ORCH_EFFICIENCY_FOOTER_INPUT"
   else
     INPUT_PATH="$(<existing resolution logic>)"
   fi
   ```

   Place the override BEFORE existing resolution. Preserve all fallbacks.

3. **Add the budget-resolution helper**. Direct YAML grep against the active `.orchestrator/config.yml`, falling back to the template default, falling back to 800:

   ```bash
   # M031/P04/T03: AD-19 budget threshold resolution.
   m031_quick_budget() {
     local cfg_path="${ORCH_CONFIG_PATH:-.orchestrator/config.yml}"
     local val
     if [ -f "$cfg_path" ]; then
       val=$(grep -E '^quick_knowledge_token_budget:' "$cfg_path" | head -n 1 | awk '{print $2}')
       if [ -n "$val" ]; then
         printf '%s\n' "$val"
         return 0
       fi
     fi
     local tpl_path="$PROJECT_ROOT/templates/orchestrator-config-default.yml"
     if [ -f "$tpl_path" ]; then
       val=$(grep -E '^quick_knowledge_token_budget:' "$tpl_path" | head -n 1 | awk '{print $2}')
       if [ -n "$val" ]; then
         printf '%s\n' "$val"
         return 0
       fi
     fi
     printf '800\n'
   }
   ```

   Bash 3.2 compatible; mirrors the P02/P03 4-layer config-knob resolution pattern.

4. **Add the windowed-median helper** if the script doesn't already have one. Bash 3.2 compatible (no `declare -A`, no process substitution):

   ```bash
   # M031/P04/T03: AD-19 windowed-median helper.
   # $1 path to JSONL stream (payload_breakdown records, one per line)
   # Reads up to the most recent 7 records with profile="quick" and emits
   # the median of knowledge_section_tokens to stdout. Emits empty string
   # if fewer than 7 quick records are available.
   m031_quick_window_median() {
     local input="$1"
     local tmp_quick
     tmp_quick=$(mktemp)
     # Filter for quick-profile records; keep last 7.
     grep -F '"profile":"quick"' "$input" 2>/dev/null | tail -n 7 >"$tmp_quick" || true
     local count
     count=$(wc -l <"$tmp_quick" | awk '{print $1}')
     if [ "$count" -lt 7 ]; then
       rm -f "$tmp_quick"
       return 0
     fi
     # Extract knowledge_section_tokens, sort numerically, pick row 4 (median of 7).
     local median
     median=$(grep -oE '"knowledge_section_tokens":[0-9]+' "$tmp_quick" | awk -F: '{print $2}' | sort -n | sed -n '4p')
     rm -f "$tmp_quick"
     printf '%s\n' "$median"
   }
   ```

   Note: the AD-19 contract uses the median of the 7-record window. Sort-and-pick-row-4 is the simplest median for an odd-sized window. The helper returns silently (empty stdout) when the window has < 7 quick records — the AD-19 trigger does not fire on a half-full window.

5. **Add the AD-19 drift-check** at the appropriate point in the script's main flow (after the input-resolution step, after existing efficiency-footer emission). Pseudo-shape:

   ```bash
   # M031/P04/T03: AD-19 QUICK_BUDGET_DRIFT informational warning.
   m031_quick_budget_drift_check() {
     # $1 input path (resolved JSONL stream)
     local input="$1"
     local budget
     budget=$(m031_quick_budget)
     local median
     median=$(m031_quick_window_median "$input")
     if [ -z "$median" ]; then
       return 0
     fi
     local threshold
     threshold=$(awk -v b="$budget" 'BEGIN{printf "%d\n", b * 11 / 10}')
     if [ "$median" -gt "$threshold" ]; then
       printf '{"warning":"QUICK_BUDGET_DRIFT","window":7,"median":%s,"budget":%s,"threshold":%s}\n' "$median" "$budget" "$threshold"
     fi
     return 0
   }
   ```

   Then call the function in the script's main flow:

   ```bash
   m031_quick_budget_drift_check "$INPUT_PATH"
   ```

   Place the call AFTER the existing efficiency-footer emission so the new record appears at the tail of the stream.

6. **Confirm the script post-edit shape**:
   - The literal substring `QUICK_BUDGET_DRIFT` appears at least 2 times (the function comment + the JSONL record body).
   - The literal substring `quick_knowledge_token_budget` appears at least 2 times (the helper grep + a comment).
   - The literal substring `knowledge_section_tokens` appears at least 1 time (the windowed-median helper).
   - The literal substring `ORCH_EFFICIENCY_FOOTER_INPUT` appears at least 1 time.
   - The script remains bash 3.2 compatible.
   - The script's existing exit-code contract is preserved.

7. **Author `tests/m031-acceptance/test-budget-drift-warning.sh`** (≥ 50 lines, executable). Body shape:

   ```bash
   #!/usr/bin/env bash
   # tests/m031-acceptance/test-budget-drift-warning.sh
   # M031/P04/T03 — AD-19 budget-drift warning acceptance test.
   #
   # Constructs two 7-record fixture JSONL streams: one whose rolling
   # median knowledge_section_tokens > budget * 1.1 (must trigger
   # QUICK_BUDGET_DRIFT); one whose rolling median is below the
   # threshold (must NOT trigger). Pipes each through
   # scripts/diagnostics/efficiency-footer.sh via the
   # ORCH_EFFICIENCY_FOOTER_INPUT env override.
   #
   # Emits RESULT: AD-19 pass (exit 0) or RESULT: AD-19 fail (exit 1).

   set -u
   PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   FOOTER="$PROJECT_ROOT/scripts/diagnostics/efficiency-footer.sh"

   work=$(mktemp -d)
   trap 'rm -rf "$work"' EXIT

   trip_stream="$work/trip.jsonl"
   safe_stream="$work/safe.jsonl"

   # Fixture: 7 quick records with knowledge_section_tokens uniformly 1000.
   # Default budget 800 -> threshold 880 -> median 1000 > 880 -> trigger fires.
   i=1
   while [ "$i" -le 7 ]; do
     printf '{"profile":"quick","knowledge_section_tokens":1000}\n' >>"$trip_stream"
     i=$((i + 1))
   done

   # Fixture: 7 quick records with knowledge_section_tokens uniformly 700.
   # Threshold 880 -> median 700 < 880 -> trigger does NOT fire.
   i=1
   while [ "$i" -le 7 ]; do
     printf '{"profile":"quick","knowledge_section_tokens":700}\n' >>"$safe_stream"
     i=$((i + 1))
   done

   pass=0
   fail=0

   trip_out=$(ORCH_EFFICIENCY_FOOTER_INPUT="$trip_stream" bash "$FOOTER" 2>&1 || true)
   if printf '%s\n' "$trip_out" | grep -qF -- "QUICK_BUDGET_DRIFT"; then
     printf 'PASS: trip fixture emits QUICK_BUDGET_DRIFT\n'
     pass=$((pass + 1))
   else
     printf 'FAIL: trip fixture missing QUICK_BUDGET_DRIFT\n'
     fail=$((fail + 1))
   fi

   safe_out=$(ORCH_EFFICIENCY_FOOTER_INPUT="$safe_stream" bash "$FOOTER" 2>&1 || true)
   if printf '%s\n' "$safe_out" | grep -qF -- "QUICK_BUDGET_DRIFT"; then
     printf 'FAIL: safe fixture unexpectedly emits QUICK_BUDGET_DRIFT\n'
     fail=$((fail + 1))
   else
     printf 'PASS: safe fixture suppresses QUICK_BUDGET_DRIFT\n'
     pass=$((pass + 1))
   fi

   printf 'AD-19 totals: pass=%d fail=%d\n' "$pass" "$fail"
   if [ "$fail" -eq 0 ]; then
     printf 'RESULT: AD-19 pass\n'
     exit 0
   fi
   printf 'RESULT: AD-19 fail\n'
   exit 1
   ```

   Note: the `while [ "$i" -le 7 ]` loops are at SCRIPT body level (not inline in a `Check:` command); they do NOT trigger the AD-19 / AP-009 shape-guard. The shape-guard governs `Check:` commands and the harness-level invocations the harness sees, not the contents of authored test scripts.

   `chmod +x tests/m031-acceptance/test-budget-drift-warning.sh`.

8. **Author `tools/verify/m031-p04-budget-drift-shape.sh`** (≥ 25 lines, executable). Asserts the efficiency-footer post-edit:
   - `check_present scripts/diagnostics/efficiency-footer.sh "QUICK_BUDGET_DRIFT"`
   - `check_present scripts/diagnostics/efficiency-footer.sh "quick_knowledge_token_budget"`
   - `check_present scripts/diagnostics/efficiency-footer.sh "knowledge_section_tokens"`
   - `check_present scripts/diagnostics/efficiency-footer.sh "ORCH_EFFICIENCY_FOOTER_INPUT"`
   - `check_present scripts/diagnostics/efficiency-footer.sh "m031_quick_budget_drift_check"`

   AD-19 single-script-file shape; emits `SUMMARY: m031-p04-budget-drift-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`.

9. **Author `tools/verify/m031-p04-test-budget-drift-shape.sh`** (≥ 20 lines, executable). Asserts:
   - `check_present tests/m031-acceptance/test-budget-drift-warning.sh "AD-19"`
   - `check_present tests/m031-acceptance/test-budget-drift-warning.sh "QUICK_BUDGET_DRIFT"`
   - `check_present tests/m031-acceptance/test-budget-drift-warning.sh "efficiency-footer.sh"`
   - `check_present tests/m031-acceptance/test-budget-drift-warning.sh "ORCH_EFFICIENCY_FOOTER_INPUT"`

10. **Run each verifier locally to confirm exit 0**:

    ```bash
    bash tests/m031-acceptance/test-budget-drift-warning.sh
    ```

    ```bash
    bash tools/verify/m031-p04-budget-drift-shape.sh
    ```

    ```bash
    bash tools/verify/m031-p04-test-budget-drift-shape.sh
    ```

11. **Commit T03 deliverables** via `git commit -F <message-file>`. Suggested commit subject: `M031/P04/T03: efficiency-footer.sh AD-19 QUICK_BUDGET_DRIFT warning + acceptance test`.

## Must-Haves

This task addresses the following Must-Haves from `P04-PLAN.md`:
- "`scripts/diagnostics/efficiency-footer.sh` post-amend emits a `QUICK_BUDGET_DRIFT` informational JSONL record when the rolling median of `knowledge_section_tokens` across the most recent 7 Quick dispatches exceeds `quick_knowledge_token_budget × 1.1`" (Truth #6; Check via `m031-p04-budget-drift-shape.sh`)
- "`tests/m031-acceptance/test-budget-drift-warning.sh` (AD-19) exists, is executable, and exits 0" (Truth #10; Check via `m031-p04-test-budget-drift-shape.sh`)

## Verification

```bash
bash tests/m031-acceptance/test-budget-drift-warning.sh
```

```bash
bash tools/verify/m031-p04-budget-drift-shape.sh
```

```bash
bash tools/verify/m031-p04-test-budget-drift-shape.sh
```

## Notes

- The 7-record window is the minimum useful sample size for a stable median. Smaller windows would produce false positives on a single anomalous task; larger windows would lag the operator-visible signal too long.
- The threshold multiplier `× 1.1` is a 10% over-budget tolerance — the AD-19 design treats `quick_knowledge_token_budget` as an advisory ceiling, not a hard cap (per FR-5 / AD-13). The drift warning fires only when the median sits ≥ 10% above the budget for 7 consecutive runs, not when a single run overshoots.
- The fixture streams use uniform values (1000 across 7 records, 700 across 7 records) for deterministic median computation. A real production stream would carry varying values; the median statistic absorbs that variance gracefully.
- The test uses `2>&1` to capture both streams because the efficiency-footer's stream choice for the new record is implementation-defined.
- The `awk -v b="$budget" 'BEGIN{printf "%d\n", b * 11 / 10}'` arithmetic is integer-truncated — for budget 800, threshold = 880 (exact). For non-multiple-of-10 budgets, the truncation is acceptable for an advisory threshold.
- The script's existing exit-code contract is preserved. The new function ALWAYS returns 0; the JSONL emission is a side-effect, not a gate.
- **Real-app smoke test pending** (plan-time discipline rule 5): the test exercises the function via env-override fixture streams. Production confirmation that an operator running 7 consecutive Quick dispatches with high knowledge-injection sees the warning in their efficiency-footer JSONL stream is the M033 onboarding milestone's job; T03's gates confirm the contract surface.

## Inputs

### From Previous Tasks

- **T01: `templates/orchestrator-config-default.yml`** carries `quick_knowledge_token_budget: 800`. T03's budget-resolution helper grep-reads this knob.
- **T02: `scripts/diagnostics/run-doctor.sh`** carries the AD-9 compound-change message. T03 makes no edits to T02 deliverables; the AD-19 surface is independent of the AD-9 surface (one is a one-time message at doctor invocation, the other is per-dispatch JSONL emission at footer invocation).

### From Previous Phases

- **P01 (`scripts/dispatch/build-context.sh` + `payload_breakdown` JSONL records)** — P01 emits `knowledge_section_tokens` in the AD-11 sidecar and the `payload_breakdown` JSONL stream. T03 reads `knowledge_section_tokens` from the JSONL stream.
- **P01 (FR-5 `quick_knowledge_token_budget` knob)** — T03 reads the knob value from the active config + template default with the standard 4-layer fallback pattern.

### From Disk (Pre-existing)

- `scripts/diagnostics/efficiency-footer.sh` — read for the existing input-resolution path + output-emission shape + existing config-reading pattern.
- `tools/verify/m031-p03-do-md-shape.sh` — read as the canonical shape-verifier template.

## Constraints

- **Bash 3.2 compatibility** (MEM001) for the efficiency-footer amendment, the test, and both shape verifiers.
- **AD-19 single-script-file shape** for Truth `Check:` invocations and verifier internals.
- **No edits to T01 / T02 deliverables** in T03.
- **No edits to `scripts/cost/`** in T03 (SC-12 block-list — `scripts/diagnostics/efficiency-footer.sh` is M027-adjacent but the file lives under `scripts/diagnostics/`, NOT `scripts/cost/`; T03's edit is allowed).
- **CON-7 / D020**: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- **SC-12 scope-guard**: T03 must NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`.
- **CON-1 invariant** (knowledge-unconditional): T03's footer amendment is observational — it does NOT change dispatch behavior. CON-1 is unaffected.
- **NG-2 (no cost-surface redesign)**: T03 ADDS one informational signal to the efficiency-footer. It does NOT redesign the M027 cost surface; existing cost-rollup, predictive-surface, and check-anomalies surfaces are untouched.
- **Commit shape**: multi-line messages MUST use `git commit -F <message-file>`.

## Expected Output

After T03 completes:

1. `scripts/diagnostics/efficiency-footer.sh` modified — contains `QUICK_BUDGET_DRIFT` + `quick_knowledge_token_budget` + `knowledge_section_tokens` + `ORCH_EFFICIENCY_FOOTER_INPUT` + `m031_quick_budget_drift_check` literal substrings.
2. `tests/m031-acceptance/test-budget-drift-warning.sh` (≥ 50 lines, executable) — exits 0 with `RESULT: AD-19 pass`.
3. `tools/verify/m031-p04-budget-drift-shape.sh` (≥ 25 lines, executable) — exits 0 with `SUMMARY: m031-p04-budget-drift-shape.sh pass=N fail=0`.
4. `tools/verify/m031-p04-test-budget-drift-shape.sh` (≥ 20 lines, executable) — exits 0 with `SUMMARY: m031-p04-test-budget-drift-shape.sh pass=N fail=0`.

T03 leaves the post-merge runtime safety net for Quick-injection efficiency drift in place. T04 picks up with the milestone-grain SC-12 scope-guard + the SC-14 acceptance battery aggregator.
