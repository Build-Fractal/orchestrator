---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M028"
name: "Close-out regression gate + sub-gate clean verifiers"
depends_on: ["T02"]
---

## Prerequisites

Plan-author empirically verified each path on disk at plan-authoring time:

- `scripts/verify/m028/install-roundtrip.sh` exists (P02/T05 deliverable — install-roundtrip pinned-sha gate).
- `scripts/verify/m028/run-all.sh` exists (P03/T05, P04/T05 — per-finding aggregator emitting `M028: 7/7 findings verified`).
- `tests/run-prompt-corpus-replay.sh` exists (P03/T05 — 27-entry replay harness emitting `WOULD_PROMPT=0/27`).
- `tests/run-downstream-fixture.sh` exists (T02 — autonomous-loop replay harness from this phase).
- `scripts/verify/m028/p05-downstream-fixture-clean.sh` exists (T02).

Files this task creates from scratch:
- `scripts/verify/m028/p05-corpus-replay-clean.sh`
- `scripts/verify/m028/p05-run-all-clean.sh`
- `scripts/verify/m028/p05-regression-gate.sh`

## Description

Author the M028 close-out regression gate `scripts/verify/m028/p05-regression-gate.sh` — a single CI-runnable artifact that sequences four sub-gates in dependency-stable order and emits a consolidated PASS/FAIL summary. The four sub-gates are:

1. **install-roundtrip** (`scripts/verify/m028/install-roundtrip.sh`) — pinned-sha install→install→uninstall byte-equality (SC-2).
2. **corpus replay** (`tests/run-prompt-corpus-replay.sh`) — 27-entry combined [M021](../../../../../milestones/M021/index.md) + M028 classifier replay with `WOULD_PROMPT=0/27` (SC-1, SC-8).
3. **per-finding run-all** (`scripts/verify/m028/run-all.sh`) — `M028: 7/7 findings verified (skipped: 0, failed: 0)` (SC-4).
4. **downstream fixture replay** (`tests/run-downstream-fixture.sh`) — autonomous-loop replay against the permanent fixture (SC-3, SC-5).

The regression gate runs each sub-gate sequentially, captures stdout+stderr to per-sub-gate log files under a tmp dir, and reports per-sub-gate PASS/FAIL plus a final aggregate verdict. On any sub-gate FAIL the gate exits 1; on all PASS the gate exits 0 with a `M028 close-out: 4/4 sub-gates clean` final line.

T03 also authors two thin sub-gate clean verifiers — `p05-corpus-replay-clean.sh` and `p05-run-all-clean.sh` — that wrap their respective harnesses with grep-based output-shape assertions (mirroring T02's `p05-downstream-fixture-clean.sh` shape). These two verifiers + T02's `p05-downstream-fixture-clean.sh` + the existing `install-roundtrip.sh` are the four Truth-Check leaves that the phase-level `check-must-haves.sh` runs.

The architecture is two-layer:
- The **regression gate** is the single close-out artifact — useful for CI and operator-facing close-out evidence.
- The **per-sub-gate clean verifiers** are individual Truth-Check leaves — used by `check-must-haves.sh` to surface per-Truth pass/fail in phase verification output.

Both layers consume the same underlying harnesses; the clean verifiers are NOT redundant with the regression gate — they are the granular surface for phase Truth-Checks; the regression gate is the rolled-up close-out surface.

## Steps

### Round 1 — Author `scripts/verify/m028/p05-corpus-replay-clean.sh`

1. Create `scripts/verify/m028/p05-corpus-replay-clean.sh` (~50 lines). AD-19 single-script-file flat shape; bash 3.2 + POSIX-sh-safe; no jq.

   Contract: invoke `tests/run-prompt-corpus-replay.sh`, capture output, assert:
   1. Exit 0.
   2. The summary line `WOULD_PROMPT=0/27` is present (literal substring).
   3. No `FAIL:` substring at line start.

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m028/p05-corpus-replay-clean.sh -- M028/P05/T03 sub-gate
   # clean verifier.
   #
   # Invokes tests/run-prompt-corpus-replay.sh and asserts the canonical
   # clean-pass shape: exit 0 + WOULD_PROMPT=0/27 + no FAIL: lines.
   #
   # AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

   set -u

   script_dir="$(cd "$(dirname "$0")" && pwd -P)"
   REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
   HARNESS="${REPO_ROOT}/tests/run-prompt-corpus-replay.sh"

   if [ ! -f "$HARNESS" ]; then
     echo "FAIL: harness not found at $HARNESS" >&2
     exit 1
   fi

   fail_count=0
   pass() { echo "PASS: $1"; }
   fail() { echo "FAIL: $1 ($2)" >&2; fail_count=$((fail_count + 1)); }

   tmp_out="$(mktemp)"
   trap 'rm -f "$tmp_out"' EXIT
   bash "$HARNESS" > "$tmp_out" 2>&1
   rc=$?

   if [ "$rc" -eq 0 ]; then pass "corpus-replay exit 0"; else fail "corpus-replay exit" "rc=$rc"; fi

   if grep -q '^WOULD_PROMPT=0/27$' "$tmp_out"; then
     pass "corpus-replay WOULD_PROMPT=0/27"
   else
     fail "corpus-replay summary" "missing WOULD_PROMPT=0/27 line"
   fi

   if grep -q '^FAIL:' "$tmp_out"; then
     fail "corpus-replay no FAIL lines" "FAIL lines present"
   else
     pass "corpus-replay no FAIL lines"
   fi

   if [ "$fail_count" -eq 0 ]; then
     echo "PASS: p05-corpus-replay-clean.sh"
     exit 0
   fi
   echo "FAIL: p05-corpus-replay-clean.sh ($fail_count failures)"
   exit 1
   ```

### Round 2 — Author `scripts/verify/m028/p05-run-all-clean.sh`

2. Create `scripts/verify/m028/p05-run-all-clean.sh` (~50 lines). AD-19 single-script-file flat shape; bash 3.2 + POSIX-sh-safe; no jq.

   Contract: invoke `scripts/verify/m028/run-all.sh`, capture output, assert:
   1. Exit 0.
   2. The summary line contains the literal substring `M028: 7/7 findings verified`.
   3. The summary line contains `(skipped: 0` (post-P04 the skip count is 0).
   4. No `FAIL:` substring at line start.

   Note: `scripts/verify/m028/p04-run-all-clean.sh` exists (P04/T05) and asserts the same contract. T03's `p05-run-all-clean.sh` is the P05-named sibling; both can coexist (they're not mutually exclusive — the P05 verifier is the phase-level Truth-Check leaf for THIS phase plan; the P04 verifier was the phase-level Truth-Check leaf for the P04 plan). Functional content is near-identical; the rename gives `check-must-haves.sh` a phase-scoped Truth-Check name to reference.

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m028/p05-run-all-clean.sh -- M028/P05/T03 sub-gate clean
   # verifier (P05-scoped sibling of p04-run-all-clean.sh).
   #
   # Invokes scripts/verify/m028/run-all.sh and asserts:
   #   1. exit 0.
   #   2. summary contains "M028: 7/7 findings verified".
   #   3. skipped: 0 in the summary line.
   #   4. No FAIL: lines.
   #
   # AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

   set -u

   script_dir="$(cd "$(dirname "$0")" && pwd -P)"
   RUN_ALL="${script_dir}/run-all.sh"

   if [ ! -f "$RUN_ALL" ]; then
     echo "FAIL: run-all.sh not found at $RUN_ALL" >&2
     exit 1
   fi

   fail_count=0
   pass() { echo "PASS: $1"; }
   fail() { echo "FAIL: $1 ($2)" >&2; fail_count=$((fail_count + 1)); }

   tmp_out="$(mktemp)"
   trap 'rm -f "$tmp_out"' EXIT
   bash "$RUN_ALL" > "$tmp_out" 2>&1
   rc=$?

   if [ "$rc" -eq 0 ]; then pass "run-all exit 0"; else fail "run-all exit" "rc=$rc"; fi

   if grep -q 'M028: 7/7 findings verified' "$tmp_out"; then
     pass "run-all summary 7/7 findings verified"
   else
     fail "run-all summary" "missing M028: 7/7 findings verified"
   fi

   if grep -q 'skipped: 0' "$tmp_out"; then
     pass "run-all skipped: 0"
   else
     fail "run-all skip count" "skipped: 0 absent"
   fi

   if grep -q '^FAIL:' "$tmp_out"; then
     fail "run-all no FAIL lines" "FAIL lines present"
   else
     pass "run-all no FAIL lines"
   fi

   if [ "$fail_count" -eq 0 ]; then
     echo "PASS: p05-run-all-clean.sh"
     exit 0
   fi
   echo "FAIL: p05-run-all-clean.sh ($fail_count failures)"
   exit 1
   ```

### Round 3 — Author `scripts/verify/m028/p05-regression-gate.sh`

3. Create `scripts/verify/m028/p05-regression-gate.sh` (~120 lines). AD-19 single-script-file flat shape; bash 3.2 + POSIX-sh-safe; no jq.

   Architectural contract: sequences the four sub-gates as discrete bash invocations, captures each sub-gate's output to a per-sub-gate log file under `${TMPDIR:-/tmp}/m028-p05-regression-gate-$$/`, reports per-sub-gate PASS/FAIL with the rc and a one-line tail of the captured output, emits a final aggregate verdict.

   The sub-gate ordering is stable and dependency-aligned: install-roundtrip → corpus replay → per-finding run-all → downstream fixture replay. Each sub-gate runs even if a prior sub-gate failed (full-coverage close-out evidence; the operator wants to see all four states, not stop on the first FAIL).

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m028/p05-regression-gate.sh -- M028 close-out regression
   # gate. Sequences four sub-gates and emits a consolidated PASS/FAIL
   # summary.
   #
   # Sub-gates (in stable, dependency-aligned order):
   #   1. install-roundtrip (P02/T05)        -- SC-2
   #   2. corpus replay     (P03/T05)        -- SC-1, SC-8
   #   3. per-finding run-all (P03/T05+P04)  -- SC-4
   #   4. downstream fixture (P05/T02)       -- SC-3, SC-5
   #
   # Every sub-gate runs (no short-circuit on failure) so the operator sees
   # all four states. Per-sub-gate output is captured to a log file under
   # ${TMPDIR:-/tmp}/m028-p05-regression-gate-$$/ for post-hoc inspection.
   #
   # Exits 0 on all-PASS; exits 1 on any sub-gate FAIL; emits
   #   "M028 close-out: <pass>/4 sub-gates clean"
   # as the final line.
   #
   # AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

   set -u

   script_dir="$(cd "$(dirname "$0")" && pwd -P)"
   REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"

   INSTALL_ROUNDTRIP="${script_dir}/install-roundtrip.sh"
   CORPUS_REPLAY="${REPO_ROOT}/tests/run-prompt-corpus-replay.sh"
   RUN_ALL="${script_dir}/run-all.sh"
   DOWNSTREAM_FIXTURE="${REPO_ROOT}/tests/run-downstream-fixture.sh"

   tmp_dir="${TMPDIR:-/tmp}/m028-p05-regression-gate-$$"
   mkdir -p "$tmp_dir"

   pass_count=0
   fail_count=0
   total=4

   # run_sub_gate: invoke a sub-gate script with its captured output written
   # to a named log file under tmp_dir. Reports PASS/FAIL with rc and a
   # one-line tail.
   run_sub_gate() {
     local label="$1"
     local script="$2"
     local log="${tmp_dir}/${label}.log"
     if [ ! -f "$script" ]; then
       echo "FAIL: ${label} (script missing: $script)"
       fail_count=$((fail_count + 1))
       return
     fi
     bash "$script" > "$log" 2>&1
     local rc=$?
     local tail_line
     tail_line=$(tail -n 1 "$log")
     if [ "$rc" -eq 0 ]; then
       echo "PASS: ${label} (rc=0; tail: ${tail_line})"
       pass_count=$((pass_count + 1))
     else
       echo "FAIL: ${label} (rc=${rc}; tail: ${tail_line}; log: ${log})"
       fail_count=$((fail_count + 1))
     fi
   }

   echo "M028 close-out regression gate -- 4 sub-gates"
   echo "tmp logs at: ${tmp_dir}"
   echo

   run_sub_gate "install-roundtrip" "$INSTALL_ROUNDTRIP"
   run_sub_gate "corpus-replay-27-entry" "$CORPUS_REPLAY"
   run_sub_gate "per-finding-run-all" "$RUN_ALL"
   run_sub_gate "downstream-fixture-replay" "$DOWNSTREAM_FIXTURE"

   echo
   echo "M028 close-out: ${pass_count}/${total} sub-gates clean"
   if [ "$fail_count" -eq 0 ]; then
     # Cleanup tmp logs on full pass.
     rm -rf "$tmp_dir"
     exit 0
   fi
   echo "Failed sub-gate logs preserved at ${tmp_dir} for inspection."
   exit 1
   ```

### Round 4 — Plan-time pre-validation + close

4. Plan-author confirms each `## Verification` line classifies as `allow` under the M028 classifier. All three lines are single-stage `bash <path>.sh` invocations.

5. Do NOT create a git commit; the orchestrator handles phase-boundary commits.

## Must-Haves

This task addresses the phase Truths:

- "The M028 close-out regression gate `scripts/verify/m028/p05-regression-gate.sh` exists and exits 0" — addressed by Step 3, verified by Verification line 3.
- "`bash scripts/verify/m028/run-all.sh` reports `M028: 7/7 findings verified`" — verified via the dedicated `p05-run-all-clean.sh` Truth-Check leaf authored in Step 2.
- "`bash tests/run-prompt-corpus-replay.sh` exits 0 with `WOULD_PROMPT=0/27`" — verified via the dedicated `p05-corpus-replay-clean.sh` Truth-Check leaf authored in Step 1.

## Verification

```bash
bash scripts/verify/m028/p05-corpus-replay-clean.sh
```

```bash
bash scripts/verify/m028/p05-run-all-clean.sh
```

```bash
bash scripts/verify/m028/p05-regression-gate.sh
```

## Notes

Expected output of `bash scripts/verify/m028/p05-corpus-replay-clean.sh`:

- Three `PASS:` lines (corpus-replay exit 0; WOULD_PROMPT=0/27 summary; no FAIL lines).
- Final `PASS: p05-corpus-replay-clean.sh` line.
- Exit 0.

Expected output of `bash scripts/verify/m028/p05-run-all-clean.sh`:

- Four `PASS:` lines (run-all exit 0; 7/7 summary; skipped: 0; no FAIL lines).
- Final `PASS: p05-run-all-clean.sh` line.
- Exit 0.

Expected output of `bash scripts/verify/m028/p05-regression-gate.sh`:

- Header line `M028 close-out regression gate -- 4 sub-gates`.
- `tmp logs at:` path line.
- Four `PASS:` lines (install-roundtrip, corpus-replay-27-entry, per-finding-run-all, downstream-fixture-replay).
- Final `M028 close-out: 4/4 sub-gates clean` line.
- Exit 0.

If any sub-gate FAILs, the regression gate preserves logs at `${TMPDIR:-/tmp}/m028-p05-regression-gate-$$/<label>.log` for post-hoc inspection. Inspect the failing log to find the root cause; the four sub-gates are independent (install-roundtrip drift is a P02 regression; corpus-replay drift is a P03 regression; run-all drift can be P02 / P03 / P04; downstream-fixture drift can be P02 / P03 / T01 / T02).

## Inputs

### From Previous Tasks

- `tests/run-downstream-fixture.sh` (T02) — the downstream-fixture sub-gate.
  - Key API: invoked as `bash <path>`; exits 0 on clean replay; emits `WOULD_PROMPT=0/<N>` summary line + `PASS:` lines.
- `scripts/verify/m028/p05-downstream-fixture-clean.sh` (T02) — sibling Truth-Check verifier; not directly invoked by T03 but established the wrap-the-harness pattern T03's two new clean verifiers mirror.

### From Disk (Pre-existing)

- `scripts/verify/m028/install-roundtrip.sh` (P02/T05) — install-roundtrip pinned-sha gate.
  - Key API: invoked as `bash <path>`; exits 0 on byte-identical install→install→uninstall round-trip; emits `PASS:` / `FAIL:` per-leg lines.
- `tests/run-prompt-corpus-replay.sh` (P03/T05) — 27-entry replay harness.
  - Key API: invoked as `bash <path>`; exits 0 on 27/27 expected-verdict match; emits `WOULD_PROMPT=0/27` summary line.
- `scripts/verify/m028/run-all.sh` (P03/T05, P04/T05) — per-finding aggregator.
  - Key API: invoked as `bash <path>`; emits `M028: 7/7 findings verified (skipped: 0, failed: 0)` summary line; exits 0 on all-pass.
- `scripts/verify/m028/p04-run-all-clean.sh` (P04/T05) — pre-existing P04-scoped sibling of T03's `p05-run-all-clean.sh`. Coexistence: P04 verifier is bound to the P04 phase plan's Truth-Check; P05 verifier is bound to the P05 phase plan's Truth-Check; both can run.

## Constraints

- **CON-1 (AD-19)**: All three new verifiers/gates are flat single-file shapes. Helper-function carve-out documented at top-of-file; the `run_sub_gate` helper in the regression gate has its body protected by carve-out.
- **CON-2 (bash 3.2 + POSIX sh)**: No `mapfile`, no `<<<`, no `declare -A`, no `[[` regex outside guarded contexts. The regression gate's per-sub-gate accounting uses scalar integer counters (`pass_count`, `fail_count`) — no arrays.
- **CON-6 (no new runtime deps)**: Pure bash + `grep`/`tail`/`mktemp`. No jq.
- **CON-7 (no M021 regression)**: The corpus-replay sub-gate is the canonical M021-strict-superset gate (CON-7 is its contract); if M021 entries 01..20 verdict drift, this sub-gate fails and the regression gate fails.
- **Verification-section authoring**: `## Verification` invokes project-tree verifiers directly. No `run-probe.sh` wrapping.
- **Plan-time verifier-availability**: All three `## Verification` lines resolve to scripts T03 itself authors. Co-authored with the deliverable per CLAUDE.md plan-time verifier-availability discipline.
- **Plan-time classifier-shape pre-validation**: All `## Verification` lines are single-stage `bash <path>.sh` invocations — `allow` verdict.
- **Sub-gate non-short-circuit**: Even if an early sub-gate fails, the regression gate runs all four. Operator-visibility over fail-fast — the close-out artifact's value comes from showing all four states.
- **Commit-message form (when applicable)**: `git commit -F <file>`. T03 itself does NOT commit.

## Expected Output

After all three `## Verification` lines run cleanly, T03 has shipped:

1. `scripts/verify/m028/p05-corpus-replay-clean.sh` — Truth-Check leaf for the corpus-replay phase Truth.
2. `scripts/verify/m028/p05-run-all-clean.sh` — Truth-Check leaf for the run-all phase Truth.
3. `scripts/verify/m028/p05-regression-gate.sh` — the M028 close-out regression gate, the consolidated CI-runnable artifact for the phase.

T04 will roll up all P05 Truth-Checks via `check-must-haves.sh` against the phase plan and run the full close-out sweep.
