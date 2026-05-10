---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M027"
name: "run-doctor.sh integration (--config-check flag + advisory invocations of T01 + T02)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 has shipped `scripts/diagnostics/check-anomalies.sh` (≥ 120 lines, executable). CLI accepts `--milestone`, `--project`, `--no-anomaly`, `--yes`, `--threshold`, `--sample-floor`, `--config-defaults`, `--help`. The helper exits 0 in all paths (FR-8 advisory contract). Output prefix: `Anomaly Detection (Tier 1 baseline)`.
- T02 has shipped `scripts/diagnostics/check-config-drift.sh` (≥ 80 lines, executable). CLI accepts `--keys`, `--key`, `--no-config-check`, `--config-defaults`, `--help`. Output prefix: `Config Drift (M027 knobs)`.
- T02 has updated `commands/doctor.md` to document the `## Anomaly Detection` and `## Config Drift` sections + the suppression matrix + the baseline disclaimer.
- `scripts/diagnostics/run-doctor.sh` exists in pre-T03 form (~145 lines today). Has a `run_check <name> <script> <args> <advisory>` function (line 31) that invokes a check script, parses its output for `DOCTOR:` status lines, and tracks pass/fail / advisory-warning counts. Has an `--root` and `--format` arg-parse loop (lines 15–21). Has a sequence of `run_check` invocations (lines 98–112) for the existing standard checks, ending with `Documentation Completeness` and `Runtime Instruction Drift`. Then graph-health is conditionally added, then summary + history append.
- bash 3.2 / POSIX sh discipline (CON-7).
- AD-19 single-script-file `Check:` shape: this task ships its own scoped precheck `scripts/verify/m027-p03-t03-shape-precheck.sh`.

## Description

Edit `scripts/diagnostics/run-doctor.sh` to:

1. **Add `--config-check` to the arg-parse loop** as a flag (default off). When set, the script additionally invokes the `check-config-drift.sh` helper as an advisory check.
2. **Add `--no-anomaly` to the arg-parse loop** as a flag (default off). When set, the anomaly check is skipped entirely (suppressed-mode parity with the helper's `--no-anomaly` flag).
3. **Add a `run_check "Anomaly Detection"` invocation** below the existing `Runtime Instruction Drift` invocation (after line 112) and above the conditional `Graph Health` block. Mark it as advisory (`"1"` final arg). Pass the `--no-anomaly` flag through if set on `run-doctor.sh`'s own invocation.
4. **Conditionally add a `run_check "Config Drift"` invocation** when `--config-check` is set. Mark it as advisory.

These two new advisory checks do NOT count toward the `checks_passed / checks_total` ratio; they only contribute to the `advisory_warnings` count when their helper exits non-zero (which they don't — both helpers are exit-0-always per FR-8 advisory contract). The `HEALTHY` / `NEEDS_ATTENTION` overall status is unaffected by either new check (FR-8: anomaly findings are advisory and never block autonomous mode).

Both new `run_check` invocations follow the existing pattern verbatim — same calling convention, same `advisory=1` marker, same output handling. No re-shape of the existing scoring logic. The only structural changes are the two arg-parse cases and the two `run_check` calls.

## Steps

1. **Edit `scripts/diagnostics/run-doctor.sh` arg-parse loop** (current lines 15–21):

   ```bash
   while [ $# -gt 0 ]; do
     case "$1" in
       --root) PROJECT_ROOT="$2"; shift 2 ;;
       --format) FORMAT="$2"; shift 2 ;;
       *) echo "run-doctor.sh: unknown option: $1" >&2; exit 1 ;;
     esac
   done
   ```

   Modify to (preserve `--root` and `--format`; add `--config-check` and `--no-anomaly`):

   ```bash
   CONFIG_CHECK=0
   NO_ANOMALY=0
   while [ $# -gt 0 ]; do
     case "$1" in
       --root) PROJECT_ROOT="$2"; shift 2 ;;
       --format) FORMAT="$2"; shift 2 ;;
       --config-check) CONFIG_CHECK=1; shift ;;
       --no-anomaly) NO_ANOMALY=1; shift ;;
       *) echo "run-doctor.sh: unknown option: $1" >&2; exit 1 ;;
     esac
   done
   ```

   The `CONFIG_CHECK=0` and `NO_ANOMALY=0` initializations must precede the `while` loop.

2. **Add the anomaly `run_check` invocation** between the existing `Runtime Instruction Drift` line (line 112) and the conditional `Graph Health` block (line 114). Insert the following lines:

   ```bash
   # M027/P03/T03 — Anomaly Detection (advisory; FR-8: never blocks autonomous mode).
   if [ "$NO_ANOMALY" -eq 1 ]; then
     run_check "Anomaly Detection" "$SCRIPT_DIR/check-anomalies.sh" "--no-anomaly" "1"
   else
     run_check "Anomaly Detection" "$SCRIPT_DIR/check-anomalies.sh" "" "1"
   fi
   ```

   Then, immediately after, add the conditional config-drift `run_check`:

   ```bash
   # M027/P03/T03 — Config Drift (advisory; opt-in via --config-check; FR-16).
   if [ "$CONFIG_CHECK" -eq 1 ]; then
     run_check "Config Drift" "$SCRIPT_DIR/check-config-drift.sh" "" "1"
   fi
   ```

3. **Confirm the existing `run_check` function** (line 31) handles the empty-`args` case correctly — current implementation does (`bash "$script" $args 2>&1` with deliberate word-splitting on `$args`; empty `$args` is a no-op).

4. **Make no other changes** to the script. No re-ordering of existing checks. No re-shape of the scoring logic. The two new checks are advisory and surfaced below the existing checks.

5. **Create the T03-scoped precheck** `scripts/verify/m027-p03-t03-shape-precheck.sh` (~70 lines):

   ```bash
   #!/usr/bin/env bash
   set -u
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"
   fail() { echo "FAIL: m027-p03-t03-shape-precheck $1" >&2; exit 1; }
   [ -f scripts/diagnostics/run-doctor.sh ] || fail "missing run-doctor.sh"
   # Arg-parse additions.
   grep -q -- "--config-check" scripts/diagnostics/run-doctor.sh || fail "missing --config-check arg"
   grep -q -- "--no-anomaly" scripts/diagnostics/run-doctor.sh || fail "missing --no-anomaly arg"
   grep -q "CONFIG_CHECK=" scripts/diagnostics/run-doctor.sh || fail "missing CONFIG_CHECK init"
   grep -q "NO_ANOMALY=" scripts/diagnostics/run-doctor.sh || fail "missing NO_ANOMALY init"
   # run_check invocations.
   grep -q 'run_check "Anomaly Detection"' scripts/diagnostics/run-doctor.sh || fail "missing Anomaly Detection run_check"
   grep -q 'run_check "Config Drift"' scripts/diagnostics/run-doctor.sh || fail "missing Config Drift run_check"
   grep -q "check-anomalies.sh" scripts/diagnostics/run-doctor.sh || fail "missing check-anomalies.sh ref"
   grep -q "check-config-drift.sh" scripts/diagnostics/run-doctor.sh || fail "missing check-config-drift.sh ref"
   # Advisory marker (the trailing "1" arg in run_check invocations for both new checks).
   grep -E 'run_check "Anomaly Detection".*"1"' scripts/diagnostics/run-doctor.sh >/dev/null || fail "Anomaly Detection not advisory"
   grep -E 'run_check "Config Drift".*"1"' scripts/diagnostics/run-doctor.sh >/dev/null || fail "Config Drift not advisory"
   # Behavioral: run-doctor.sh smoke-test runs without crashing.
   out=$(bash scripts/diagnostics/run-doctor.sh --no-anomaly 2>&1 | head -3)
   echo "$out" | grep -q "Orchestrator Diagnostics" || fail "run-doctor.sh failed smoke test"
   echo "PASS: m027-p03-t03-shape-precheck"
   exit 0
   ```

   `chmod +x scripts/verify/m027-p03-t03-shape-precheck.sh`.

## Must-Haves

- `scripts/diagnostics/run-doctor.sh` exists, ≥ 140 lines, contains `--config-check` arg-parse case and `--no-anomaly` arg-parse case.
- File contains the literal `run_check "Anomaly Detection"` invocation referencing `check-anomalies.sh`.
- File contains the literal `run_check "Config Drift"` invocation referencing `check-config-drift.sh`.
- Both new `run_check` invocations carry the trailing `"1"` advisory marker.
- File contains the literal `Anomaly Detection` (asserted by P03 phase-plan artifact requirement).
- Running `bash scripts/diagnostics/run-doctor.sh --no-anomaly` exits without crashing and produces output prefixed `=== Orchestrator Diagnostics ===`.
- `scripts/verify/m027-p03-t03-shape-precheck.sh` exists, executable, exits 0 against the post-T03 codebase.

## Verification

```bash
bash scripts/verify/m027-p03-t03-shape-precheck.sh
```

This T03-scoped precheck verifier (ships with T03) asserts T03's must-haves. T04 ships the canonical phase-level verifier `m027-p03-run-doctor-integration.sh` which subsumes this precheck.

## Inputs

### From Previous Tasks

- T01: `scripts/diagnostics/check-anomalies.sh` — invoked by the new `Anomaly Detection` `run_check`. Exits 0 in all paths (FR-8 advisory). The `--no-anomaly` flag is passed through when `run-doctor.sh` is invoked with `--no-anomaly`.
- T02: `scripts/diagnostics/check-config-drift.sh` — invoked by the new `Config Drift` `run_check` only when `--config-check` is set on `run-doctor.sh`. Exits 0 in all paths.

### From Disk (Pre-existing)

- `scripts/diagnostics/run-doctor.sh` — pre-T03 form (~145 lines). Has the `run_check` function (line 31). Existing `run_check` invocations end at line 112 (`Runtime Instruction Drift`). The conditional `Graph Health` block follows on lines 114–121. Summary + history append on lines 123–144. T03 inserts two `run_check` invocations between line 112 and line 114 (no re-ordering of existing invocations).

## Constraints

- **CON-7 (bash 3.2)**: No `declare -A`, no `<<<`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`. The existing `run-doctor.sh` is bash 3.2 compatible; T03 preserves that property.
- **FR-8 (advisory; never blocks)**: Both new checks are marked advisory (`"1"` final arg). They contribute to `advisory_warnings` if their helpers exit non-zero (which they don't), but never to `checks_total` or `checks_passed`. Overall HEALTHY status is unaffected.
- **FR-16 (config-check opt-in)**: The `Config Drift` check is only invoked when `--config-check` is set. Without the flag, `run-doctor.sh` output is unchanged (modulo the new `Anomaly Detection` block, which is always present unless `--no-anomaly` is set).
- **CON-3-equivalent (suppressed-mode parity with T01)**: When `run-doctor.sh --no-anomaly` is invoked, the anomaly helper is invoked WITH `--no-anomaly` and emits zero anomaly content. The `--- Anomaly Detection ---` section header from `run_check` still appears (since `run_check` always emits the header before invoking the script), but the body is empty. This is the documented behavior in `commands/doctor.md` (T02).
- **FR-12 / CON-1 (read-only)**: No new writes to disk by `run-doctor.sh` itself; the two new helpers are read-only per FR-12 / CON-1.
- **FR-21 / CON-6 / SC-16 (zero-LLM-token)**: No `claude_chat`, no `anthropic`, no `dispatch-interface.sh`, no `dispatch_task`, no `subagent` introduced.
- **AD-19 (single-script-file Check shape)**: This task's `Check:` invokes a single helper script (the T03-scoped precheck). T04 ships the canonical phase-level Truth `Check:` invocations.
- **MEM012 (no re-shape of existing canonical structure)**: The arg-parse and `run_check` sequences in `run-doctor.sh` are pre-existing canonical structures. T03 appends to the arg-parse case-statement and inserts between two pre-existing `run_check` invocations; no pre-existing line is re-ordered or re-worded.

## Expected Output

After this task:

1. `scripts/diagnostics/run-doctor.sh` modified to include the `--config-check` and `--no-anomaly` arg-parse cases plus two new `run_check` invocations (`Anomaly Detection`, conditional `Config Drift`).
2. The `--- Anomaly Detection ---` block appears in `run-doctor.sh` output by default (advisory, exit-0 always).
3. The `--- Config Drift ---` block appears in `run-doctor.sh` output ONLY when `--config-check` is set.
4. `bash scripts/diagnostics/run-doctor.sh --no-anomaly` exits without crashing; the anomaly block body is empty (suppressed-mode contract).
5. `scripts/verify/m027-p03-t03-shape-precheck.sh` exists, executable, exits 0 against the post-T03 codebase.
6. `git diff --quiet` is non-zero (this task modifies files); however, no `execution-log.jsonl` file is touched.
