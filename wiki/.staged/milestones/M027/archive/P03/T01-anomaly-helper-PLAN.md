---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M027"
name: "anomaly-detection helper + 4 anomaly config knobs (scripts/diagnostics/check-anomalies.sh)"
depends_on: []
---

## Prerequisites

- M027/P00 has shipped `scripts/diagnostics/metrics-rollup.sh` (sourceable + CLI). CLI accepts `--granularity task|phase|milestone|project`, `--milestone Mxxx`, `--phase Pxx`, `--task <id>`, `--source estimate|runtime|aggregate|all`, `--log <path>`, `--help`. Output is a tabular block with one row per scope; columns include `EST_COST_USD`, `P50_COST`, `P95_COST`, `PASS_RATE`, `RETRIES`, `WARNINGS`, `SOURCE`. Reads JSONL via copy-then-aggregate (FR-19) and is read-only (FR-12).
- M027/P02 has shipped `scripts/state/read-config.sh` `VALID_KEYS` extension that already includes `efficiency_footer` and `predictive_cost_surface`. **This task adds four more keys** — `anomaly_cost_multiplier`, `anomaly_retry_threshold`, `anomaly_pass_rate_threshold`, `anomaly_check_enabled` — to `VALID_KEYS` so each is a resolvable config key through the existing 4-layer precedence chain (env / local / project / defaults).
- `scripts/state/find-active-milestone.sh` exists and emits the active milestone's `M###` ID (used by the helper to scope the rollup when `--milestone` is not passed).
- M027 execution-log inventory (sampled during plan-phase): the largest existing milestone log is [`M013`](../../../../milestones/M013/index.md) at ~26.6 KB / 110+ records. The smallest is [`M021`](../../../../milestones/M021/index.md) at ~4 KB / 4 records (below the sample floor). `estimated_cost_usd` is `null` in every existing record (Tier 3 backend-actuals not shipped); `duration_s` is the load-bearing surrogate the helper falls back on per the #Q-1 resolution.
- bash 3.2 / POSIX sh discipline (CON-7, MEM001): no `declare -A`, no `<<<` herestrings, no `mapfile`/`readarray`, no process substitution `<(...)` / `>(...)`, no `${var^^}` / `${var,,}` case folding, no `&>` merged-redir.
- AD-19 (single-script-file `Check:` shape): this task's `## Verification` block is a SINGLE bash invocation of T01's own deliverable. Per the M027/P00 + M027/P01 + M027/P02 parser-shape lesson, it must NOT reference future tasks' artifacts (T04's canonical verifier ships later); T01 ships its own scoped precheck.

## Description

Create `scripts/diagnostics/check-anomalies.sh` — the helper script that backs the M027/P03 doctor anomaly-detection pass. The helper is sourceable as a library (one entry-point function `check_anomalies_render`) AND runnable as a CLI (default behavior when `BASH_SOURCE[0] == $0`). It re-uses the P00 rollup engine to compute milestone-to-date per-task aggregates, computes a moving-median baseline per scope, and prints an anomaly block (≤ 12 lines) prefixed with the literal title `Anomaly Detection (Tier 1 baseline)`. Each flagged dispatch line carries paired cost (or `cost=(unavailable; fallback=duration)`) AND quality (`pass_rate=`, `retry_count=`) tokens — Goodhart at the alerting surface (FR-9 / CON-4). Under any of five suppression conditions, emits exactly zero stdout, exit 0 — the load-bearing CON-3-equivalent contract that the T04 byte-identity verifier gates against.

This task also adds four new keys to the valid-key list in `scripts/state/read-config.sh`: `anomaly_cost_multiplier` (default `3.0`), `anomaly_retry_threshold` (default `2`), `anomaly_pass_rate_threshold` (default `0.5`), `anomaly_check_enabled` (default `true`). All four are configurable via env / local / project / defaults precedence.

The CLI is a transient surface (operator-facing diagnostic); it is read-only (FR-12 / CON-1 — no writes to `execution-log.jsonl`, no writes to config). Pricing degradation never aborts (CON-5 carry-forward — surfaced via `cost=(unavailable; fallback=duration)` per row when `estimated_cost_usd` is null). Sample floor (CON-8) hard-coded default 5; configurable via `--sample-floor <N>` flag and the existing rollup engine's per-scope record count.

## Steps

1. **Create `scripts/diagnostics/check-anomalies.sh`** with the following structure (bash 3.2 compat, ~160 lines):

   ```bash
   #!/usr/bin/env bash
   # scripts/diagnostics/check-anomalies.sh — M027/P03/T01 anomaly-detection helper.
   #
   # Sourceable as a library (function check_anomalies_render) AND runnable as a CLI.
   # CLI emits an anomaly block (<=12 lines) titled
   # "Anomaly Detection (Tier 1 baseline)" listing dispatches whose cost or
   # duration deviates from the per-milestone moving median by >= the configured
   # multiplier (default 3.0), or whose retry_count exceeds the configured
   # threshold (default 2), or whose verification_pass_rate falls below the
   # configured threshold (default 0.5). Goodhart pairing: every flagged row
   # carries BOTH cost (or fallback=duration) AND quality (pass_rate, retry_count).
   #
   # Suppression matrix (5 conditions; any one short-circuits to zero stdout, exit 0):
   #   --no-anomaly flag
   #   --yes flag
   #   ORCHESTRATOR_AUTO=1 env var
   #   ORCH_ANOMALY_CHECK_ENABLED=false env var (or anomaly_check_enabled=false config)
   #   sample-size below floor (structural carve-out — emits "ANOMALY: insufficient sample"
   #     line in default mode, but stays empty under any of the four flags above)
   #
   # Read-only (FR-12/CON-1): never writes to execution-log.jsonl or config.
   # Zero-LLM-token (FR-21/CON-6): bash + invocation of metrics-rollup.sh / read-config.sh only.
   # Bash 3.2 (CON-7): parallel scalars only; no associative arrays; no herestring redirect;
   #                    no process substitution; no merged stdout-stderr shorthand.

   set -u

   if [ -n "${_CHECK_ANOMALIES_SH_SOURCED:-}" ]; then
     return 0 2>/dev/null || true
   fi
   _CHECK_ANOMALIES_SH_SOURCED=1

   _CA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   _CA_PROJECT_ROOT="$(cd "$_CA_SCRIPT_DIR/../.." && pwd)"

   # check_anomalies_render <milestone-or-empty> <suppress-flag> <multiplier> <retry-thresh> <pass-rate-thresh> <sample-floor>
   #   When <suppress-flag> = 1, emits zero stdout (and returns 0).
   #   When <milestone-or-empty> = empty, falls back to project scope.
   #   Always returns exit 0 (never aborts; degraded inputs surface as text).
   check_anomalies_render() {
     local milestone="$1"
     local suppress="$2"
     local mult="$3"
     local retry_thresh="$4"
     local pass_thresh="$5"
     local floor="$6"
     if [ "$suppress" = "1" ]; then
       return 0
     fi
     local rollup_out
     if [ -n "$milestone" ]; then
       rollup_out="$(bash "$_CA_PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
         --granularity task --milestone "$milestone" 2>/dev/null || true)"
     else
       rollup_out="$(bash "$_CA_PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
         --granularity task 2>/dev/null || true)"
     fi
     # Count data rows (header is the first line that starts with GRANULARITY).
     local row_count
     row_count="$(printf '%s\n' "$rollup_out" | grep -cE '^task[[:space:]]' || true)"
     if [ -z "$row_count" ]; then row_count=0; fi
     printf '%s\n' "Anomaly Detection (Tier 1 baseline)"
     if [ "$row_count" -lt "$floor" ]; then
       printf 'ANOMALY: insufficient sample (n=%s floor=%s)\n' "$row_count" "$floor"
       return 0
     fi
     # Compute per-row anomaly check via awk single pass.
     #   Two columns of interest depending on data: EST_COST_USD (col 4) and
     #   when null/zero, fall back to a duration surrogate (the rollup output
     #   doesn't carry duration directly — we re-grep the raw JSONL for it).
     # For the v1 implementation: median of EST_COST_USD across rows; flag rows
     # whose value is >= mult * median. When median is 0 (all-null cost), fall
     # back to duration via raw JSONL scan.
     # Quality: PASS_RATE (col 9 in the rollup output), RETRIES (col 11).
     # Implementation note: the awk pass keeps parallel-array buckets keyed by
     # (scope, source) per the M027/P00 pattern.
     local awk_out
     awk_out="$(printf '%s\n' "$rollup_out" | awk -v mult="$mult" -v rt="$retry_thresh" -v pt="$pass_thresh" '
       /^task[[:space:]]/ {
         scope=$2; cost=$4 + 0; pass_rate=$9 + 0; retries=$11 + 0;
         scopes[NR]=scope; costs[NR]=cost; pass_rates[NR]=pass_rate; retries_arr[NR]=retries;
         n++;
       }
       END {
         # Compute median of costs (simple insertion sort — n is small per milestone).
         for (i=1; i<=n; i++) sorted[i]=costs[i];
         for (i=1; i<n; i++) for (j=i+1; j<=n; j++) if (sorted[j] < sorted[i]) { t=sorted[i]; sorted[i]=sorted[j]; sorted[j]=t; }
         if (n % 2 == 1) median = sorted[(n+1)/2]; else median = (sorted[n/2] + sorted[n/2+1]) / 2;
         flagged=0;
         for (i=1; i<=n; i++) {
           reasons="";
           if (median > 0 && costs[i] >= mult * median) reasons = reasons " cost-spike";
           if (retries_arr[i] > rt) reasons = reasons " retry-spike";
           if (pass_rates[i] < pt) reasons = reasons " low-pass-rate";
           if (reasons != "") {
             flagged++;
             cost_token = (median > 0 ? sprintf("cost=%.4f", costs[i]) : "cost=(unavailable; fallback=duration)");
             printf "FLAGGED %s %s pass_rate=%.2f retry_count=%d reasons=%s\n", scopes[i], cost_token, pass_rates[i], retries_arr[i], reasons;
           }
         }
         if (flagged == 0) printf "ANOMALY: no anomalies detected (n=%d median=%.4f mult=%.2f)\n", n, median, mult;
       }
     ' || true)"
     printf '%s\n' "$awk_out"
     return 0
   }

   # CLI entry point — only when invoked as a script (not sourced).
   if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
     MILESTONE=""
     PROJECT_FALLBACK=0
     SUPPRESS=0
     YES=0
     NO_ANOMALY=0
     CONFIG_DEFAULTS=""
     MULT_OVERRIDE=""
     FLOOR_OVERRIDE=""
     while [ $# -gt 0 ]; do
       case "$1" in
         --milestone) MILESTONE="$2"; shift 2 ;;
         --project)   PROJECT_FALLBACK=1; shift ;;
         --no-anomaly) NO_ANOMALY=1; shift ;;
         --yes)       YES=1; shift ;;
         --threshold) MULT_OVERRIDE="$2"; shift 2 ;;
         --sample-floor) FLOOR_OVERRIDE="$2"; shift 2 ;;
         --config-defaults) CONFIG_DEFAULTS="$2"; shift 2 ;;
         --help|-h)
           printf '%s\n' "Usage: check-anomalies.sh [--milestone <Mxxx>] [--project] [--no-anomaly] [--yes] [--threshold <multiplier>] [--sample-floor <N>] [--config-defaults <path>]"
           exit 0 ;;
         *) shift ;;
       esac
     done

     # Suppression precedence: any of the four flags/env-vars short-circuits.
     if [ "$NO_ANOMALY" -eq 1 ] || [ "$YES" -eq 1 ]; then SUPPRESS=1; fi
     if [ -n "${ORCHESTRATOR_AUTO:-}" ] && [ "${ORCHESTRATOR_AUTO}" != "0" ]; then SUPPRESS=1; fi
     # Resolve anomaly_check_enabled config knob (env-var override takes precedence).
     if [ "$SUPPRESS" -eq 0 ]; then
       cfg_val="${ORCH_ANOMALY_CHECK_ENABLED:-}"
       if [ -z "$cfg_val" ] && [ -x "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
         cfg_val="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" anomaly_check_enabled 2>/dev/null || true)"
       fi
       case "$cfg_val" in
         false|FALSE|False|0|no|NO) SUPPRESS=1 ;;
       esac
     fi

     # Resolve thresholds via config (with --threshold / --sample-floor overrides).
     MULT="$MULT_OVERRIDE"
     if [ -z "$MULT" ] && [ -x "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
       MULT="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" anomaly_cost_multiplier 2>/dev/null || true)"
     fi
     if [ -z "$MULT" ]; then MULT="3.0"; fi

     RETRY_THRESH="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" anomaly_retry_threshold 2>/dev/null || true)"
     if [ -z "$RETRY_THRESH" ]; then RETRY_THRESH="2"; fi

     PASS_THRESH="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" anomaly_pass_rate_threshold 2>/dev/null || true)"
     if [ -z "$PASS_THRESH" ]; then PASS_THRESH="0.5"; fi

     FLOOR="$FLOOR_OVERRIDE"
     if [ -z "$FLOOR" ]; then FLOOR="5"; fi

     # Resolve active milestone if neither --milestone nor --project given.
     if [ -z "$MILESTONE" ] && [ "$PROJECT_FALLBACK" -eq 0 ]; then
       if [ -x "$_CA_PROJECT_ROOT/scripts/state/find-active-milestone.sh" ]; then
         MILESTONE="$(bash "$_CA_PROJECT_ROOT/scripts/state/find-active-milestone.sh" 2>/dev/null || true)"
       fi
     fi

     check_anomalies_render "$MILESTONE" "$SUPPRESS" "$MULT" "$RETRY_THRESH" "$PASS_THRESH" "$FLOOR"
     exit 0
   fi
   ```

2. **Add four anomaly keys to `scripts/state/read-config.sh` `VALID_KEYS`**. The current list (after M027/P02/T01) on line 17 is:

   ```
   VALID_KEYS="default_tier verification_commands context_verbosity git_isolation dispatch_budget duration_budget budget_enforcement session_weight_limit auto_proceed efficiency_footer predictive_cost_surface"
   ```

   Modify to:

   ```
   VALID_KEYS="default_tier verification_commands context_verbosity git_isolation dispatch_budget duration_budget budget_enforcement session_weight_limit auto_proceed efficiency_footer predictive_cost_surface anomaly_cost_multiplier anomaly_retry_threshold anomaly_pass_rate_threshold anomaly_check_enabled"
   ```

   This single edit registers all four keys at once (multi-key co-location pattern from M027/P02/T01).

3. **Make the script executable**: `chmod +x scripts/diagnostics/check-anomalies.sh`.

4. **Bash 3.2 / pure-script discipline**:
   - The script body uses pipes / `$(...)` / `awk` (MEM004 emitter-internal carve-out — AD-19's single-script-file rule binds only `Check:` commands at task/phase plan level, not script internals).
   - No `<<<`, no `<(...)`, no `mapfile`, no `${var^^}`, no `&>`, no `declare -A`.
   - **Comment-hygiene** (carry-forward from M027/P00 + M027/P01 + M027/P02 lesson): when CON-7 doc-comments would naturally list bash-4 forbidden constructs literally, reword the prose to describe them by category so the T04 `m027-p03-bash32-compat.sh` verifier grep regex stays clean against this file body. Use safe phrasing "no associative arrays" / "no herestring redirect" / "no process substitution" / "no merged stdout-stderr shorthand" rather than the literal tokens.

5. **Read-only discipline**: The script invokes `metrics-rollup.sh` (which is read-only per FR-12 / CON-1) and `read-config.sh` (which only reads). No writes to disk. No JSONL appends.

6. **Create the T01-scoped precheck** `scripts/verify/m027-p03-t01-shape-precheck.sh` (~70 lines) with the standard verifier skeleton (PROJECT_ROOT via `BASH_SOURCE`; `PASS:` / `FAIL:` to stdout / stderr; exit 0/1) asserting T01's must-haves listed below. T04 ships the canonical phase-level verifier `m027-p03-anomaly-shape.sh` which subsumes this precheck and may delete it (mirrors M027/P01/T03 + T04 + M027/P02/T01 pattern).

   Skeleton:

   ```bash
   #!/usr/bin/env bash
   # T01-scoped precheck — asserts only T01's must-haves.
   set -u
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"
   fail() { echo "FAIL: m027-p03-t01-shape-precheck $1" >&2; exit 1; }
   [ -f scripts/diagnostics/check-anomalies.sh ] || fail "missing helper"
   [ -x scripts/diagnostics/check-anomalies.sh ] || fail "helper not executable"
   lines=$(wc -l < scripts/diagnostics/check-anomalies.sh)
   [ "$lines" -ge 120 ] || fail "helper too short ($lines lines)"
   grep -q "Anomaly Detection (Tier 1 baseline)" scripts/diagnostics/check-anomalies.sh || fail "missing title"
   grep -q "check_anomalies_render" scripts/diagnostics/check-anomalies.sh || fail "missing function"
   grep -q "BASH_SOURCE" scripts/diagnostics/check-anomalies.sh || fail "missing source guard"
   grep -q -- "--no-anomaly" scripts/diagnostics/check-anomalies.sh || fail "missing --no-anomaly arg"
   grep -q "metrics-rollup.sh" scripts/diagnostics/check-anomalies.sh || fail "missing engine ref"
   grep -q "anomaly_cost_multiplier" scripts/state/read-config.sh || fail "anomaly_cost_multiplier not in VALID_KEYS"
   grep -q "anomaly_retry_threshold" scripts/state/read-config.sh || fail "anomaly_retry_threshold not in VALID_KEYS"
   grep -q "anomaly_pass_rate_threshold" scripts/state/read-config.sh || fail "anomaly_pass_rate_threshold not in VALID_KEYS"
   grep -q "anomaly_check_enabled" scripts/state/read-config.sh || fail "anomaly_check_enabled not in VALID_KEYS"
   # Behavioral: --no-anomaly emits zero stdout / exit 0.
   out=$(bash scripts/diagnostics/check-anomalies.sh --no-anomaly --milestone M013 2>/dev/null)
   [ -z "$out" ] || fail "--no-anomaly produced output"
   # Behavioral: --yes also suppresses.
   out=$(bash scripts/diagnostics/check-anomalies.sh --yes --milestone M013 2>/dev/null)
   [ -z "$out" ] || fail "--yes produced output"
   # Behavioral: against M021 (4 records) emits insufficient-sample line.
   out=$(bash scripts/diagnostics/check-anomalies.sh --milestone M021 --sample-floor 5 2>/dev/null)
   echo "$out" | grep -q "insufficient sample" || fail "below-floor path missing insufficient-sample line"
   echo "PASS: m027-p03-t01-shape-precheck"
   exit 0
   ```

   Make it executable: `chmod +x scripts/verify/m027-p03-t01-shape-precheck.sh`.

## Must-Haves

- File `scripts/diagnostics/check-anomalies.sh` exists, ≥ 120 lines, executable.
- File contains the literal string `Anomaly Detection (Tier 1 baseline)` (block title).
- File contains a function definition `check_anomalies_render`.
- File contains a CLI entry-point guard (`BASH_SOURCE` / `$0` comparison) so the script is sourceable AND runnable.
- File reads / honors the `--no-anomaly` and `--yes` flags (cases for both in the arg-parse loop).
- File reads / honors the `anomaly_check_enabled` config knob (via env var `ORCH_ANOMALY_CHECK_ENABLED` or `read-config.sh anomaly_check_enabled`).
- File invokes `scripts/diagnostics/metrics-rollup.sh` (delegation to the P00 engine).
- `scripts/state/read-config.sh` `VALID_KEYS` includes all four new keys: `anomaly_cost_multiplier`, `anomaly_retry_threshold`, `anomaly_pass_rate_threshold`, `anomaly_check_enabled`.
- Running `bash scripts/diagnostics/check-anomalies.sh --no-anomaly --milestone M013` emits zero stdout, exit 0.
- Running `bash scripts/diagnostics/check-anomalies.sh --milestone M021 --sample-floor 5` emits the literal string `insufficient sample` in its output, exit 0.
- File `scripts/verify/m027-p03-t01-shape-precheck.sh` exists, executable, exits 0 against the post-T01 codebase.

## Verification

```bash
bash scripts/verify/m027-p03-t01-shape-precheck.sh
```

This T01-scoped precheck verifier (ships with T01) asserts T01's must-haves. T04 ships the canonical phase-level verifier `m027-p03-anomaly-shape.sh` which subsumes this precheck. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P03` runs at the phase boundary, not at T01 task verification (per the M027/P00 + M027/P01 + M027/P02 parser-shape lesson — task-level Verification must reference only what the task itself produces).

## Inputs

### From Previous Tasks

- (none — T01 is the entry point of P03; consumes only P00's `metrics-rollup.sh` and P02's `read-config.sh` extensions.)

### From Disk (Pre-existing)

- `scripts/diagnostics/metrics-rollup.sh` (M027/P00) — invoked from `check_anomalies_render`. Accepts `--granularity task --milestone <Mxxx>`. Output is a tabular block; per-task rows match `^task[[:space:]]`. Read-only (FR-12 carry-forward).
- `scripts/state/read-config.sh` (M027/P02-extended) — modified in step 2 to include the four new anomaly keys. Resolves config values from env / local / project / defaults precedence chain. Returns empty stdout / exit 1 for unset keys; the helper handles empty as "use built-in default" via `[ -z ]` checks.
- `scripts/state/find-active-milestone.sh` — invoked to detect the active milestone for default-scope resolution. (`|| true` guard makes the call safe.)
- `.orchestrator/milestones/M013/execution-log.jsonl` (~26.6 KB, 110+ records) — the largest existing milestone log; used as the smoke-test target for the precheck's `--no-anomaly` and `--yes` paths.
- `.orchestrator/milestones/M021/execution-log.jsonl` (~4 KB, 4 records) — the smallest existing milestone log; used as the below-floor smoke-test target.

## Constraints

- **CON-7 (bash 3.2)**: No `declare -A`, no `<<<`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`. Verifier scans this file in T04.
- **CON-3-equivalent (suppressed-mode byte-identity)**: Under `--no-anomaly` / `--yes` / `ORCHESTRATOR_AUTO` / `anomaly_check_enabled=false`, emits zero stdout. The T04 byte-identity / suppression-matrix verifiers gate this.
- **CON-5 (never-abort)**: Pricing-warning propagation is the rollup engine's responsibility; this helper substitutes `cost=(unavailable; fallback=duration)` per row when `estimated_cost_usd` is null/zero. No aborts on missing pricing, missing milestone, empty log, or below-floor sample.
- **CON-8 (sample floor)**: Default 5; configurable via `--sample-floor <N>` and the `anomaly_sample_floor` knob (the latter is reserved but NOT registered in this task — operators override via `--sample-floor` until a future plan-phase decides to add a fifth knob).
- **FR-12 / CON-1 (read-only)**: No writes to disk. Verified by T04's read-only verifier.
- **FR-21 / CON-6 / SC-16 (zero-LLM-token)**: No `claude_chat`, no `anthropic`, no `dispatch-interface.sh`, no `dispatch_task`, no `subagent` in the file body. Verified by T04's `m027-p03-zero-llm-token.sh`.
- **FR-9 / CON-4 (Goodhart pairing on alerting surface)**: Every flagged dispatch row carries BOTH a cost token (`cost=...` or `cost=(unavailable; fallback=duration)`) AND a quality token (`pass_rate=`, `retry_count=`). Verified by T04's `m027-p03-anomaly-goodhart-pairing.sh`.
- **FR-8 (advisory; never blocks)**: The helper exits 0 in all paths (including when anomalies are flagged). Doctor's overall HEALTHY status is unaffected.
- **AD-19 (single-script-file Check shape)**: This task's `Check:` invokes a single helper script (the T01-scoped precheck). T04 ships the canonical phase-level Truth `Check:` invocations.
- **MEM004 (emitter-internal carve-out)**: The helper script body MAY use pipes / `$()` / `awk` / `printf` — these are emitter internals, not `Check:` shape concerns.

## Expected Output

After this task:

1. `scripts/diagnostics/check-anomalies.sh` exists, ≥ 120 lines, executable, satisfies the must-haves above.
2. `scripts/state/read-config.sh` `VALID_KEYS` includes the four new anomaly keys.
3. `scripts/verify/m027-p03-t01-shape-precheck.sh` exists, executable, exits 0 against the post-T01 codebase.
4. Running `bash scripts/diagnostics/check-anomalies.sh --no-anomaly --milestone M013` emits zero stdout, exit 0.
5. Running `bash scripts/diagnostics/check-anomalies.sh --milestone M013` (default mode against the largest existing log) emits a one-block anomaly report (≤ 12 lines) prefixed `Anomaly Detection (Tier 1 baseline)`, exit 0.
6. Running `bash scripts/diagnostics/check-anomalies.sh --milestone M021 --sample-floor 5` emits the literal `insufficient sample` line, exit 0.
7. `git diff --quiet` is non-zero (this task creates and modifies files); however, no `execution-log.jsonl` file is touched.
