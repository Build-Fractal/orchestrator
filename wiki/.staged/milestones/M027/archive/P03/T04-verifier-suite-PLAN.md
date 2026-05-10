---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M027"
name: "P03 verifier suite (m027-p03-suite.sh + per-contract m027-p03-*.sh)"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has shipped `scripts/diagnostics/check-anomalies.sh` (≥ 120 lines, executable, sourceable). CLI accepts `--milestone`, `--project`, `--no-anomaly`, `--yes`, `--threshold`, `--sample-floor`, `--config-defaults`, `--help`. Title: `Anomaly Detection (Tier 1 baseline)`. Suppressed mode emits zero stdout. Below-floor mode emits the literal `insufficient sample` line.
- T01 has added four anomaly keys to `VALID_KEYS` in `scripts/state/read-config.sh` (`anomaly_cost_multiplier`, `anomaly_retry_threshold`, `anomaly_pass_rate_threshold`, `anomaly_check_enabled`).
- T02 has shipped `scripts/diagnostics/check-config-drift.sh` (≥ 80 lines, executable, sourceable). CLI accepts `--keys`, `--key`, `--no-config-check`, `--config-defaults`, `--help`. Title: `Config Drift (M027 knobs)`.
- T02 has updated `commands/doctor.md` with the `## Anomaly Detection` and `## Config Drift` sections + the suppression matrix + the baseline disclaimer + two new `## Referenced Scripts` bullets. Created `tests/fixtures/m027-p03/doctor-suppressed-baseline.txt`, `tests/fixtures/m027-p03/anomaly-fixture.jsonl`, and `tests/fixtures/m027-p03/README.md`.
- T03 has updated `scripts/diagnostics/run-doctor.sh` with `--config-check` and `--no-anomaly` arg-parse cases plus two new `run_check` invocations (`Anomaly Detection` always; `Config Drift` conditional).
- M027/P00 has shipped `scripts/verify/m027-rollup-schema.sh` (phase-suite orchestrator); M027/P01 has shipped `scripts/verify/m027-p01-suite.sh`; M027/P02 has shipped `scripts/verify/m027-p02-suite.sh`. All three follow the canonical shape: parallel-string `GATES` list, per-gate exit-code capture, PASS/FAIL emission, RELAX-CANDIDATE forwarding, cheapest-first ordering. T04's `m027-p03-suite.sh` mirrors this verbatim.
- Project verifier conventions: scripts under `scripts/verify/` emit `PASS:` / `FAIL:` / `WARN:` to stdout (`FAIL:` may also go to stderr); exit 0 on green, 1 on red, 2 on usage error. Bash 3.2 compatible.
- AD-19 (single-script-file `Check:` shape): T04's deliverables ARE the canonical phase-level `Check:` targets. T04's own `Verification` block invokes the suite orchestrator that T04 itself ships (single-script-file shape).
- T01/T02/T03 each shipped a scoped `m027-p03-t##-shape-precheck.sh`. T04 may delete those prechecks once the canonical verifiers ship and the phase-level `check-must-haves.sh` is green — mirroring the M027/P01/T03 + T04 and M027/P02/T01–T04 patterns.

## Description

Ship 11 per-contract verifier scripts and one phase-suite orchestrator that together gate every Truth in the P03 phase plan. The suite is invoked at the phase boundary by `scripts/verify/check-must-haves.sh` (which auto-discovers `Check:` commands from `P03-PLAN.md`); the suite is also runnable standalone via `bash scripts/verify/m027-p03-suite.sh`.

The 11 per-contract verifiers correspond 1:1 to the 11 phase-level Truths defined in `P03-PLAN.md`:

1. `m027-p03-anomaly-shape.sh` — gates Truth #1 (anomaly helper shape + behavior).
2. `m027-p03-config-drift-shape.sh` — gates Truth #2 (config-drift helper shape + behavior).
3. `m027-p03-doctor-md-shape.sh` — gates Truth #3 (`commands/doctor.md` integration shape).
4. `m027-p03-doctor-byte-identity.sh` — gates Truth #4 (doctor.md `## Referenced Scripts` tail byte-identity vs. fixture).
5. `m027-p03-suppression-matrix.sh` — gates Truth #5 (5-path suppression matrix on the anomaly helper).
6. `m027-p03-run-doctor-integration.sh` — gates Truth #6 (`run-doctor.sh` integration shape).
7. `m027-p03-anomaly-latency.sh` — gates Truth #7 (latency budget; inner-vs-outer split against [M013](../../../../milestones/M013/index.md)).
8. `m027-p03-anomaly-goodhart-pairing.sh` — gates Truth #8 (Goodhart pairing on the anomaly alerting surface).
9. `m027-p03-zero-llm-token.sh` — gates Truth #9 (no LLM-invocation tokens in script set).
10. `m027-p03-read-only.sh` — gates Truth #10 (`git diff --quiet` after invocation).
11. `m027-p03-bash32-compat.sh` — gates Truth #11 (bash 3.2 forbidden constructs absent).

The phase-suite orchestrator `m027-p03-suite.sh` runs all 11 in stable order (cheapest static checks first; latency / live-invocation last) and aggregates results.

## Steps

1. **Create the phase-suite orchestrator** `scripts/verify/m027-p03-suite.sh` (mirrors `scripts/verify/m027-p02-suite.sh` shape verbatim):

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m027-p03-suite.sh — M027/P03 phase-suite orchestrator.
   # Mirrors the shape of m027-p02-suite.sh / m027-p01-suite.sh / m027-rollup-schema.sh.
   set -u
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   GATES="m027-p03-bash32-compat m027-p03-zero-llm-token m027-p03-doctor-md-shape m027-p03-anomaly-shape m027-p03-config-drift-shape m027-p03-run-doctor-integration m027-p03-suppression-matrix m027-p03-anomaly-goodhart-pairing m027-p03-doctor-byte-identity m027-p03-read-only m027-p03-anomaly-latency"
   pass=0; fail=0; failures=""; relax=""
   for gate in $GATES; do
     out="$(bash "$SCRIPT_DIR/${gate}.sh" 2>&1)"; rc=$?
     relax_line="$(printf '%s\n' "$out" | grep -E '^WARN: RELAX-CANDIDATE|^RELAX-CANDIDATE' || true)"
     if [ -n "$relax_line" ]; then relax="${relax}
   ${relax_line}"; fi
     if [ $rc -eq 0 ]; then
       pass=$((pass+1)); echo "PASS: ${gate}"
     else
       fail=$((fail+1)); failures="${failures} ${gate}"
       echo "FAIL: ${gate}"; printf '%s\n' "$out" >&2
     fi
   done
   if [ -n "$relax" ]; then printf '%s\n' "$relax"; fi
   if [ $fail -eq 0 ]; then
     echo "PASS: m027-p03-suite.sh ${pass} gates"; exit 0
   else
     echo "FAIL: m027-p03-suite.sh ${fail} gates failed:${failures}" >&2; exit 1
   fi
   ```

   Gate ordering rationale: bash32-compat (regex-only, < 50 ms) and zero-llm-token (regex-only) run first. Markdown-shape check (doctor-md) runs early — pure file grep. Helper-shape checks run mid-suite. Run-doctor-integration runs after the shape checks (greps run-doctor.sh). Suppression matrix runs after (forks the helper 5×). Goodhart pairing runs after suppression (forks the helper against the M999 fixture). Doctor byte-identity runs near the end (awk-extract + diff). Read-only runs late (captures pre/post `git diff`). Latency runs LAST because it is the most environment-sensitive.

2. **Per-contract verifier scripts** — create each under `scripts/verify/`. Each follows this skeleton:

   ```bash
   #!/usr/bin/env bash
   set -u
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"
   # ... contract-specific assertions ...
   if [ <fail-condition> ]; then echo "FAIL: <gate-name> <reason>" >&2; exit 1; fi
   echo "PASS: <gate-name>"
   exit 0
   ```

3. **`m027-p03-anomaly-shape.sh`** (~70 lines) — gates Truth #1:
   - Assert `scripts/diagnostics/check-anomalies.sh` exists, ≥ 120 lines, executable.
   - Assert `grep -q "Anomaly Detection (Tier 1 baseline)" scripts/diagnostics/check-anomalies.sh`.
   - Assert `grep -q "check_anomalies_render" scripts/diagnostics/check-anomalies.sh`.
   - Assert `grep -q "BASH_SOURCE" scripts/diagnostics/check-anomalies.sh`.
   - Assert `grep -q -- "--no-anomaly" scripts/diagnostics/check-anomalies.sh`.
   - Assert `grep -q "metrics-rollup.sh" scripts/diagnostics/check-anomalies.sh`.
   - Assert `grep -q "anomaly_cost_multiplier" scripts/state/read-config.sh`.
   - Assert `grep -q "anomaly_retry_threshold" scripts/state/read-config.sh`.
   - Assert `grep -q "anomaly_pass_rate_threshold" scripts/state/read-config.sh`.
   - Assert `grep -q "anomaly_check_enabled" scripts/state/read-config.sh`.
   - Run `bash scripts/diagnostics/check-anomalies.sh --no-anomaly --milestone M013` and capture stdout + exit code; assert exit 0 and stdout is empty.
   - Run `bash scripts/diagnostics/check-anomalies.sh --milestone M013` and capture exit code; assert exit 0 and stdout starts with `Anomaly Detection (Tier 1 baseline)`.
   - Run `bash scripts/diagnostics/check-anomalies.sh --milestone [M021](../../../../milestones/M021/index.md) --sample-floor 5` and assert stdout contains `insufficient sample`.
   - PASS.

4. **`m027-p03-config-drift-shape.sh`** (~60 lines) — gates Truth #2:
   - Assert `scripts/diagnostics/check-config-drift.sh` exists, ≥ 80 lines, executable.
   - Assert `grep -q "Config Drift (M027 knobs)" scripts/diagnostics/check-config-drift.sh`.
   - Assert `grep -q "check_config_drift_render" scripts/diagnostics/check-config-drift.sh`.
   - Assert `grep -q "BASH_SOURCE" scripts/diagnostics/check-config-drift.sh`.
   - Assert `grep -q "read-config.sh" scripts/diagnostics/check-config-drift.sh`.
   - Run `bash scripts/diagnostics/check-config-drift.sh --keys efficiency_footer` and assert stdout contains `Config Drift (M027 knobs)` and `key=efficiency_footer` and `effective=`.
   - Run `bash scripts/diagnostics/check-config-drift.sh --no-config-check` and assert empty stdout / exit 0.
   - Run with default keys (no `--keys` flag) and assert all six default M027 knobs appear in the output (`efficiency_footer`, `predictive_cost_surface`, `anomaly_cost_multiplier`, `anomaly_retry_threshold`, `anomaly_pass_rate_threshold`, `anomaly_check_enabled`).
   - PASS.

5. **`m027-p03-doctor-md-shape.sh`** (~80 lines) — gates Truth #3:
   - Assert `commands/doctor.md` exists, ≥ 60 lines.
   - Assert `grep -q "## Anomaly Detection" commands/doctor.md`.
   - Assert `grep -q "## Config Drift" commands/doctor.md`.
   - Assert `grep -q "scripts/diagnostics/check-anomalies.sh" commands/doctor.md`.
   - Assert `grep -q "scripts/diagnostics/check-config-drift.sh" commands/doctor.md`.
   - Assert all 5 suppression-matrix tokens are documented: `--no-anomaly`, `ORCHESTRATOR_AUTO`, `anomaly_check_enabled`, `--yes`, `insufficient sample`.
   - Assert the #Q-10 disclaimer text is present (verbatim substring): `grep -q "fallback=duration" commands/doctor.md` AND `grep -q "Corruption-recovery" commands/doctor.md`.
   - Assert pre-edit canonical section order is preserved. Capture line numbers of each canonical section header via `grep -n | head -1 | cut -d: -f1`; assert: `## What It Checks` < `## Runtime Instruction Drift` < `## Anomaly Detection` < `## Config Drift` < `## Usage` < `## Output` < `## When to Run` < `## Referenced Scripts`. Use a small bash function (sequence of `grep -n` + `[ "$a" -lt "$b" ]` checks) to extract each line number; assert each is strictly less than the next.
   - PASS.

6. **`m027-p03-doctor-byte-identity.sh`** (~70 lines) — gates Truth #4:
   - Assert fixture `tests/fixtures/m027-p03/doctor-suppressed-baseline.txt` exists, ≥ 1 line.
   - Extract the post-`## Referenced Scripts` tail of the live `commands/doctor.md` via `awk '/^## Referenced Scripts/,EOF' commands/doctor.md > /tmp/m027-p03-live-tail.txt`.
   - Diff the live tail against the fixture: `diff /tmp/m027-p03-live-tail.txt tests/fixtures/m027-p03/doctor-suppressed-baseline.txt`. Failure if diff exits non-zero.
   - Cleanup the temp file.
   - PASS.

7. **`m027-p03-suppression-matrix.sh`** (~80 lines) — gates Truth #5:
   - For each of the 5 suppression conditions (4 actively-suppressing + 1 structural), run the helper and assert the contract per condition:
     - `bash scripts/diagnostics/check-anomalies.sh --no-anomaly --milestone M013` → empty stdout, exit 0.
     - `bash scripts/diagnostics/check-anomalies.sh --yes --milestone M013` → empty stdout, exit 0.
     - `ORCHESTRATOR_AUTO=1 bash scripts/diagnostics/check-anomalies.sh --milestone M013` → empty stdout, exit 0.
     - `ORCH_ANOMALY_CHECK_ENABLED=false bash scripts/diagnostics/check-anomalies.sh --milestone M013` → empty stdout, exit 0.
     - `bash scripts/diagnostics/check-anomalies.sh --milestone M021 --sample-floor 5` → non-empty stdout containing `insufficient sample`, exit 0 (structural carve-out: in default mode emits the line).
     - `bash scripts/diagnostics/check-anomalies.sh --milestone M021 --sample-floor 5 --no-anomaly` → empty stdout, exit 0 (the four flags override the structural carve-out).
   - Failure if any path violates its contract.
   - PASS.

8. **`m027-p03-run-doctor-integration.sh`** (~70 lines) — gates Truth #6:
   - Assert `scripts/diagnostics/run-doctor.sh` exists, ≥ 140 lines.
   - Assert `grep -q -- "--config-check" scripts/diagnostics/run-doctor.sh`.
   - Assert `grep -q -- "--no-anomaly" scripts/diagnostics/run-doctor.sh`.
   - Assert `grep -q 'run_check "Anomaly Detection"' scripts/diagnostics/run-doctor.sh`.
   - Assert `grep -q 'run_check "Config Drift"' scripts/diagnostics/run-doctor.sh`.
   - Assert `grep -q "check-anomalies.sh" scripts/diagnostics/run-doctor.sh`.
   - Assert `grep -q "check-config-drift.sh" scripts/diagnostics/run-doctor.sh`.
   - Assert both new `run_check` invocations carry the trailing `"1"` advisory marker (`grep -E 'run_check "Anomaly Detection".*"1"' scripts/diagnostics/run-doctor.sh`; same for Config Drift).
   - Behavioral: run `bash scripts/diagnostics/run-doctor.sh --no-anomaly 2>&1 | head -3` and assert stdout starts with `=== Orchestrator Diagnostics ===`.
   - PASS.

9. **`m027-p03-anomaly-latency.sh`** (~80 lines) — gates Truth #7:
   - Inner measurement: `time bash scripts/diagnostics/check-anomalies.sh --milestone M013 >/dev/null 2>&1` — repeat 3×, take min wall-clock. Use `perl -MTime::HiRes` for sub-second timing on macOS (perl is standard on macOS); fall back to `date +%s` (1-second precision; only fails on > 1000 ms).
   - Outer measurement: same invocation against the largest existing milestone log (M013); reports informationally.
   - Inner threshold: hard fail at 250 ms (the per-the-P02-pattern budget; mirrors the predictive-surface verifier's inner threshold). PASS below 250 ms.
   - Outer threshold: report informational; if > 500 ms, emit `WARN: RELAX-CANDIDATE: outer-wall-clock measured=<N>ms target=250ms (~150ms macOS bash startup + rollup-fork overhead)`. Outer threshold does NOT fail the gate (mirrors P01/P02/T04 latency verifier).
   - Both numbers reported in stdout regardless of pass/fail.
   - PASS on inner threshold.

10. **`m027-p03-anomaly-goodhart-pairing.sh`** (~70 lines) — gates Truth #8:
    - Set up an isolated test environment: `tmp_root=$(mktemp -d); mkdir -p "$tmp_root/.orchestrator/milestones/M999"; cp tests/fixtures/m027-p03/anomaly-fixture.jsonl "$tmp_root/.orchestrator/milestones/M999/execution-log.jsonl"`.
    - Invoke the helper against the M999 fixture: `cd "$tmp_root"; out=$(bash "$PROJECT_ROOT/scripts/diagnostics/check-anomalies.sh" --milestone M999 --sample-floor 5 2>/dev/null); cd "$PROJECT_ROOT"`.
    - Assert `out` contains the literal `Anomaly Detection (Tier 1 baseline)` (the title is rendered).
    - Assert `out` contains a `FLAGGED` line referencing the M999/P00/T09 outlier (the line should match the regex `^FLAGGED M999/P00/T09`).
    - Assert the same flagged line contains BOTH a cost token (`cost=` — either the numeric form or the `cost=(unavailable; fallback=duration)` form) AND a quality token (`pass_rate=` AND `retry_count=`). Implementation: extract the FLAGGED line, then `echo "$line" | grep -q "cost=" && echo "$line" | grep -q "pass_rate=" && echo "$line" | grep -q "retry_count="`.
    - Cleanup: `rm -rf "$tmp_root"`.
    - PASS.

11. **`m027-p03-zero-llm-token.sh`** (~50 lines) — gates Truth #9:
    - For each file in: `scripts/diagnostics/check-anomalies.sh`, `scripts/diagnostics/check-config-drift.sh`, every `scripts/verify/m027-p03-*.sh` (explicit list).
    - `grep -nE "(claude_chat|anthropic|dispatch-interface\.sh|dispatch_task|subagent)"` against each file. Failure if any match.
    - Exclude self via explicit file list (mirrors P01/P02/T04 carve-out — the verifier file itself contains the regex string but is excluded from the scan list).
    - Implementation: `FILES="scripts/diagnostics/check-anomalies.sh scripts/diagnostics/check-config-drift.sh scripts/verify/m027-p03-anomaly-shape.sh scripts/verify/m027-p03-config-drift-shape.sh scripts/verify/m027-p03-doctor-md-shape.sh scripts/verify/m027-p03-doctor-byte-identity.sh scripts/verify/m027-p03-suppression-matrix.sh scripts/verify/m027-p03-run-doctor-integration.sh scripts/verify/m027-p03-anomaly-latency.sh scripts/verify/m027-p03-anomaly-goodhart-pairing.sh scripts/verify/m027-p03-read-only.sh scripts/verify/m027-p03-bash32-compat.sh scripts/verify/m027-p03-suite.sh"`. The verifier file itself (`m027-p03-zero-llm-token.sh`) is intentionally absent from `FILES`.
    - PASS.

12. **`m027-p03-read-only.sh`** (~50 lines) — gates Truth #10:
    - Capture `git diff --quiet`'s exit status before the run. If non-zero (the working tree is already dirty), emit `WARN: working-tree-dirty pre-run; skipping read-only assertion` and exit 0 (mirrors P01/P02/T04 pattern).
    - Else, run a sequence of read-only invocations:
      - `bash scripts/diagnostics/check-anomalies.sh --no-anomaly --milestone M013 >/dev/null`
      - `bash scripts/diagnostics/check-anomalies.sh --milestone M013 >/dev/null`
      - `bash scripts/diagnostics/check-config-drift.sh >/dev/null`
      - `bash scripts/diagnostics/check-config-drift.sh --no-config-check >/dev/null`
      - `bash scripts/diagnostics/run-doctor.sh --config-check --no-anomaly >/dev/null` (note: `run-doctor.sh` does append to `doctor-history.jsonl`; this is a pre-existing side-effect of `run-doctor.sh` and is excluded from the assertion via `git diff --quiet -- ':!.orchestrator/doctor-history.jsonl'` — the M027/P03 helpers themselves are read-only; `run-doctor.sh`'s history append is pre-T03 behavior unchanged by this phase).
    - Re-run `git diff --quiet -- ':!.orchestrator/doctor-history.jsonl'`. Failure if exit non-zero.
    - PASS.

13. **`m027-p03-bash32-compat.sh`** (~70 lines) — gates Truth #11:
    - For each file in: `scripts/diagnostics/check-anomalies.sh`, `scripts/diagnostics/check-config-drift.sh`, every `scripts/verify/m027-p03-*.sh`, plus `commands/doctor.md`.
    - For each file, `grep -nE` against the forbidden-construct regex assembled from split-literal tokens: `(declare -A|mapfile|readarray|<<<|<\(|>\(|&>|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^})`. Failure if any match (excluding the verifier file itself).
    - Exclude self via explicit file list.
    - Use the split-literal token assembly pattern from M027/P01+P02+T04 to keep the verifier from matching its own source: build the regex from concatenated string fragments (e.g., `FORBID_A='declare''_'-A'` after tr -d, etc.) so the literal `declare -A` substring does not appear in the verifier file body.
    - Run `bash -n` against each shell file (parse-check) — every helper must parse cleanly under bash 3.2 grammar.
    - PASS.

14. **`chmod +x`** all 12 new scripts (`m027-p03-suite.sh` + 11 per-contract verifiers).

15. **Delete the T01/T02/T03 scoped prechecks** (`scripts/verify/m027-p03-t01-shape-precheck.sh`, `scripts/verify/m027-p03-t02-shape-precheck.sh`, `scripts/verify/m027-p03-t03-shape-precheck.sh`) once the canonical verifiers ship and `bash scripts/verify/m027-p03-suite.sh` exits 0. This mirrors the M027/P01/T03+T04 and M027/P02/T01-T04 pattern (the prechecks are scaffolding to satisfy each per-task `Verification` block; once the canonical verifiers exist, the prechecks are redundant).

## Must-Haves

- File `scripts/verify/m027-p03-suite.sh` exists, ≥ 30 lines, contains the literal string `m027-p03`.
- Files `scripts/verify/m027-p03-*.sh` exist for each of the 11 per-contract verifiers (see Phase Plan Artifacts list).
- Running `bash scripts/verify/m027-p03-suite.sh` from the project root exits 0 against the post-P03 codebase.
- Each per-contract verifier exits 0 in isolation against the post-P03 codebase.
- Verifiers are bash 3.2 compatible (the bash32-compat verifier scans them).
- Phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P03` exits 0.
- T01/T02/T03 scoped prechecks deleted (no leftover `m027-p03-t##-shape-precheck.sh` files).

## Verification

```bash
bash scripts/verify/m027-p03-suite.sh
```

The above must exit 0 and emit `PASS: m027-p03-suite.sh 11 gates` on stdout. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P03` also runs at the phase boundary; it auto-discovers the 11 Truth `Check:` commands from the phase plan and re-runs them. Both should be green.

## Inputs

### From Previous Tasks

- T01: `scripts/diagnostics/check-anomalies.sh` — invoked by 5 verifiers (anomaly-shape, suppression-matrix, anomaly-latency, anomaly-goodhart-pairing, read-only). Library function: `check_anomalies_render`. CLI flags: `--milestone`, `--project`, `--no-anomaly`, `--yes`, `--threshold`, `--sample-floor`, `--config-defaults`, `--help`.
- T01: modified `scripts/state/read-config.sh` `VALID_KEYS` to include the four anomaly keys. Verifiers grep this file for all four.
- T02: `scripts/diagnostics/check-config-drift.sh` — invoked by 2 verifiers (config-drift-shape, read-only). Library function: `check_config_drift_render`. CLI flags: `--keys`, `--key`, `--no-config-check`, `--config-defaults`, `--help`.
- T02: modified `commands/doctor.md` (≥ 60 lines, contains both new sections + 5 suppression tokens + #Q-10 disclaimer). Created `tests/fixtures/m027-p03/doctor-suppressed-baseline.txt`, `anomaly-fixture.jsonl`, `README.md`. The doctor-suppressed baseline is the load-bearing input to the byte-identity verifier; the anomaly fixture is the load-bearing input to the Goodhart-pairing verifier.
- T03: modified `scripts/diagnostics/run-doctor.sh` (`--config-check` and `--no-anomaly` arg-parse cases + two new `run_check` invocations).

### From Disk (Pre-existing)

- `scripts/diagnostics/metrics-rollup.sh` (P00) — invoked transitively by the anomaly-shape and anomaly-latency verifiers via the helper.
- `scripts/state/read-config.sh` (M027/P02-extended + M027/P03/T01-extended) — invoked transitively by the config-drift-shape verifier via the helper.
- `scripts/verify/m027-p02-suite.sh` (P02), `scripts/verify/m027-p01-suite.sh` (P01), `scripts/verify/m027-rollup-schema.sh` (P00) — reference shapes for the phase-suite orchestrator. Mirror verbatim.
- `perl -MTime::HiRes` — standard on macOS; used by latency verifier for sub-second timing.
- `awk` (POSIX) — used by doctor-byte-identity verifier to extract the post-`## Referenced Scripts` tail.
- `.orchestrator/milestones/M013/execution-log.jsonl` (~26.6 KB) — largest existing milestone log; latency verifier target.
- `.orchestrator/milestones/M021/execution-log.jsonl` (~4 KB, 4 records) — below-floor smoke-test target.
- `tests/fixtures/m027-p03/doctor-suppressed-baseline.txt` (created by T02).
- `tests/fixtures/m027-p03/anomaly-fixture.jsonl` (created by T02).

## Constraints

- **CON-1 / FR-12 (read-only)**: Verifiers are read-only. They MAY create temp files under `${TMPDIR:-/tmp}/` but never write to the project tree. `read-only.sh` explicitly asserts `git diff --quiet` post-invocation (with `:!.orchestrator/doctor-history.jsonl` exclusion for the pre-existing `run-doctor.sh` history-append behavior).
- **CON-7 (bash 3.2)**: Every verifier passes the bash32-compat scan. No `declare -A`, no `<<<`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`.
- **AD-19 (single-script-file Check shape)**: The phase plan's 11 Truths each have a single-script-file `Check:` invoking these verifiers. Each verifier internally MAY use pipes / `$()` / `awk` / `grep` (MEM004 emitter-internal carve-out).
- **#Q-5 / latency carry-forward**: The `anomaly-latency.sh` verifier hard-fails at 250 ms on the inner measurement against the M013 log (the largest existing milestone log) and reports outer measurement as informational with `WARN: RELAX-CANDIDATE` annotation. Mirrors P01/P02/T04 latency verifier.
- **CON-3-equivalent / suppressed-mode byte-identity**: The `suppression-matrix.sh` verifier exercises 5 paths against the helper. The `doctor-byte-identity.sh` verifier diffs the live `commands/doctor.md` post-`## Referenced Scripts` tail against the T02 fixture.
- **CON-4 / FR-9 (Goodhart pairing carry-forward)**: The `anomaly-goodhart-pairing.sh` verifier asserts paired cost+quality at the alerting surface against the M999 fixture.
- **FR-21 / CON-6 / SC-16 (zero-LLM-token)**: The `zero-llm-token.sh` verifier scans the M027/P03 script set for forbidden LLM-invocation patterns.
- **#Q-1 resolution**: The defaults pinned in this plan (`anomaly_cost_multiplier=3.0`, `anomaly_retry_threshold=2`, `anomaly_pass_rate_threshold=0.5`, `anomaly_sample_floor=5`) are tested implicitly by the anomaly-shape and goodhart-pairing verifiers — the M999 fixture's 8× outlier is a clear hit at multiplier 3.0; the below-floor M021 path triggers at floor 5.

## Expected Output

After this task:

1. 12 new scripts under `scripts/verify/` (1 suite orchestrator + 11 per-contract verifiers), each ≥ 30 lines, executable.
2. T01/T02/T03 scoped prechecks deleted (`scripts/verify/m027-p03-t01-shape-precheck.sh`, `scripts/verify/m027-p03-t02-shape-precheck.sh`, `scripts/verify/m027-p03-t03-shape-precheck.sh` removed).
3. Running `bash scripts/verify/m027-p03-suite.sh` exits 0 and emits `PASS: m027-p03-suite.sh 11 gates` on stdout.
4. Running each per-contract verifier in isolation exits 0 against the post-P03 codebase.
5. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P03` exits 0 (auto-discovers and re-runs the 11 Truth `Check:` commands from `P03-PLAN.md`).
6. `git diff --quiet -- ':!.orchestrator/doctor-history.jsonl'` after running the suite is exit 0 — verifiers are read-only modulo the pre-existing `run-doctor.sh` history append.
