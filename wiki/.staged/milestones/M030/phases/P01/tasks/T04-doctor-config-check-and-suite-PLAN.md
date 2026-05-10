---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M030"
name: "doctor.sh --config-check routing-table validation + P01 phase-suite gate"
depends_on: ["T03"]
---

## Prerequisites

- `templates/model-routing.yml` exists with `routing:`, `resolution:`, `cost_rates:` sections (T03 close).
- `tools/verify/p01-routing-table-shape.sh` exists and exits 0 against the shipped `templates/model-routing.yml` (T03 close).
- `references/model-routing.md` exists with all five required sections and concrete numeric stability-metric values (T03 close).
- `scripts/diagnostics/run-doctor.sh` exists with an existing `--config-check` flag (verified at plan-authoring: the file is present and the flag-parsing branch already accepts `--config-check`; T04 extends the flag's body).
- All P01 verifiers from T01-T03 are on disk: `tools/verify/p01-d-a4-timeline.sh`, `tools/verify/p01-classifier-determinism.sh`, `tools/verify/p01-classifier-perf-and-network.sh`, `tools/verify/p01-classifier-ground-truth.sh`, `tools/verify/p01-routing-table-shape.sh`, `tools/verify/p01-model-routing-doc-shape.sh`.

Plan-time prerequisite-existence verification: every path above resolves under `[ -f <path> ]` at plan-authoring time. Confirmed: `scripts/diagnostics/run-doctor.sh` accepts `--config-check` per existing flag-parsing branch (head of file shows `--config-check) CONFIG_CHECK=1; shift ;;`).

## Description

T04 closes the phase. It does two things:

1. **Extend `scripts/diagnostics/run-doctor.sh --config-check` to validate `templates/model-routing.yml`** (FR-17 + SC-9). When `--config-check` is set, run the routing-table-shape closure check; on a malformed table (deliberately introduced fixture), exit 1 with stdout naming both the offending file path AND the offending line number. On a well-formed table, exit 0.

2. **Author the P01 phase-suite aggregator `tools/verify/p01-phase-suite.sh`** (the phase-close gate). The script invokes all seven P01 sub-gates in literal sequence — no loops, no eval, straight-line bash per the P00 phase-suite pattern — and emits `SUMMARY: p01-phase-suite.sh pass=N fail=M` before exit. Exits 0 iff every sub-gate passes.

T04 also authors `tools/verify/p01-doctor-config-check.sh` — the verifier that exercises both the well-formed-pass and malformed-fail paths of `run-doctor.sh --config-check`. The malformed-fail fixture lives at `/tmp/p01-malformed-routing.yml` (created by the verifier at runtime, in the run-probe-allowed `/tmp/` dir) so we don't pollute the repo with a permanently-malformed sample.

### Doctor extension contract (FR-17 + SC-9)

The existing `run-doctor.sh --config-check` branch is currently a stub (the flag is parsed but does not run routing-table validation today). T04 extends it as follows:

- When `--config-check` is set, additionally run `bash tools/verify/p01-routing-table-shape.sh "$ROUTING_TABLE_PATH"` where `ROUTING_TABLE_PATH` defaults to `templates/model-routing.yml` and can be overridden via env var or a `--routing-table` flag.
- Capture the verifier's stdout + exit code. On verifier exit 1, propagate exit 1 from `run-doctor.sh` and pipe the verifier's diagnostic stdout (which contains the file + line of the malformation) to the doctor's existing structured-output stream.
- On verifier exit 0, pass through to the existing doctor-check pipeline (no behavior change for non-routing checks).

The `p01-routing-table-shape.sh` verifier T03 authored MUST already emit file + line on closure violations (e.g., `FAIL: templates/model-routing.yml:42 — symbolic tier 'turbo' referenced in routing.standard.claude-code but not defined in resolution:`). T04's job is to wire the verifier into doctor's flag, not re-implement the shape check. If T03's verifier doesn't emit line numbers, T04 first amends T03's verifier to do so (the verifier and doctor extension are co-scheduled).

### P01 phase-suite contract

`tools/verify/p01-phase-suite.sh` invokes seven sub-gates in this order:

1. `bash tools/verify/p01-d-a4-timeline.sh`
2. `bash tools/verify/p01-classifier-determinism.sh`
3. `bash tools/verify/p01-classifier-perf-and-network.sh`
4. `bash tools/verify/p01-classifier-ground-truth.sh`
5. `bash tools/verify/p01-routing-table-shape.sh`
6. `bash tools/verify/p01-doctor-config-check.sh`
7. `bash tools/verify/p01-model-routing-doc-shape.sh`

Each invocation is a literal statement; `pass`/`fail` accumulators update via `pass=$((pass+1))` / `fail=$((fail+1))` per `$?`. No `for` loop over a script-name array (which would force compound shapes). Final line: `SUMMARY: p01-phase-suite.sh pass=N fail=M`. Exit 0 iff all seven exit 0.

## Steps

1. **Confirm all T01-T03 deliverables are on disk.** Run:

   ```bash
   bash tools/verify/p01-d-a4-timeline.sh
   bash tools/verify/p01-classifier-determinism.sh
   bash tools/verify/p01-classifier-perf-and-network.sh
   bash tools/verify/p01-classifier-ground-truth.sh
   bash tools/verify/p01-routing-table-shape.sh
   bash tools/verify/p01-model-routing-doc-shape.sh
   ```

   Expected: all six exit 0. If any fails, T04 cannot close — the failing upstream task must be re-opened.

2. **Verify `scripts/diagnostics/run-doctor.sh --config-check` accepts the flag.** Run:

   ```bash
   bash scripts/diagnostics/run-doctor.sh --config-check
   ```

   Expected: exits some code (likely 0 with the existing stub behavior). The flag is parsed by the existing case statement; T04's job is to extend the *body* of the `--config-check` branch.

3. **Inspect T03's `tools/verify/p01-routing-table-shape.sh` and confirm it emits `<file>:<line>` on malformation.** If the verifier's diagnostic shape is `FAIL: <message>` without a file:line prefix, amend the verifier to include the offending line number — extract the line number via `grep -n` during the closure walk, and emit `FAIL: templates/model-routing.yml:<lineno> — <message>`. The line-number extraction is a small targeted edit; the AD-19 single-script-file shape is preserved.

4. **Extend `scripts/diagnostics/run-doctor.sh`'s `--config-check` body.** Locate the existing `CONFIG_CHECK=1` flag-handling code (around the early flag-parsing case statement). Add the routing-table validation step:

   - When `CONFIG_CHECK=1`, after the existing checks (or in their place — executor decides based on the existing structure), run:

     ```bash
     ROUTING_TABLE="${ROUTING_TABLE_PATH:-templates/model-routing.yml}"
     bash "$PROJECT_ROOT/tools/verify/p01-routing-table-shape.sh" "$ROUTING_TABLE"
     routing_rc=$?
     if [ "$routing_rc" -ne 0 ]; then
       checks_failed=$((checks_failed+1))
       # Diagnostic was already emitted to stdout by the verifier with file:line.
     else
       checks_passed=$((checks_passed+1))
     fi
     ```

   - Use the existing `checks_passed` / `checks_failed` accumulators that `run-doctor.sh` already tracks (visible in the file head: `checks_passed=0`).
   - Preserve all existing flag semantics (`--root`, `--format`, `--no-anomaly`). The routing-table check is additive when `--config-check` is set; it is not invoked when `--config-check` is absent.

5. **Author `tools/verify/p01-doctor-config-check.sh`.** Bash 3.2-compatible. AD-19 single-script-file shape. Two scenarios:

   - **Scenario A — well-formed**: invoke `bash scripts/diagnostics/run-doctor.sh --config-check`. Capture exit code. Assert exit 0.
   - **Scenario B — malformed fixture**: stage a malformed copy of `templates/model-routing.yml` at `/tmp/p01-malformed-routing.yml` (e.g., introduce an undefined symbolic-tier reference like `claude-code: turbo` under `routing.standard`). Invoke `ROUTING_TABLE_PATH=/tmp/p01-malformed-routing.yml bash scripts/diagnostics/run-doctor.sh --config-check`. Assert exit 1. Assert stdout contains `/tmp/p01-malformed-routing.yml` AND a line-number pattern (`:[0-9]+`).
   - Cleanup: `rm -f /tmp/p01-malformed-routing.yml`.
   - On all checks pass: emit `SUMMARY: p01-doctor-config-check.sh pass=N fail=0` and exit 0.

   Note on `/tmp/` usage: per Plan-Time Discipline rule 4 (`run-probe.sh` scope discipline), `/tmp/` is one of the allowed dirs for staged-throwaway probes — but the verifier here writes to `/tmp/` directly via `cat > /tmp/...` rather than wrapping the doctor invocation in `run-probe.sh`. The verifier itself is a repo-resident verifier under `tools/verify/`; it is invoked directly via `bash tools/verify/p01-doctor-config-check.sh`, not through `run-probe.sh`. The fixture-staging-in-/tmp/ pattern is independent of the run-probe discipline.

6. **Author `tools/verify/p01-phase-suite.sh`** per the seven-gate contract above. Verbatim straight-line bash:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p01-phase-suite.sh — M030 P01 phase-close gate.
   # Invokes all seven P01 sub-gates in order; exits 0 iff all pass.
   # Bash 3.2 compatible. Straight-line — no loops, no eval, no compound chains.

   set -uo pipefail

   pass=0
   fail=0

   bash tools/verify/p01-d-a4-timeline.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p01-classifier-determinism.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p01-classifier-perf-and-network.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p01-classifier-ground-truth.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p01-routing-table-shape.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p01-doctor-config-check.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p01-model-routing-doc-shape.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   echo "SUMMARY: p01-phase-suite.sh pass=$pass fail=$fail"

   if [ "$fail" -eq 0 ]; then
     exit 0
   else
     exit 1
   fi
   ```

   Note: `set -uo pipefail` (NOT `-e`) so `$?` is captured even on sub-gate fail. Each sub-gate's own diagnostic is emitted to stdout/stderr by the sub-gate; the suite just accumulates and reports.

7. **Run the new T04 verifiers as a self-check:**

   ```bash
   bash tools/verify/p01-doctor-config-check.sh
   bash tools/verify/p01-phase-suite.sh
   ```

   Expected:
   - `bash tools/verify/p01-doctor-config-check.sh` → `SUMMARY: p01-doctor-config-check.sh pass=N fail=0`, exit 0.
   - `bash tools/verify/p01-phase-suite.sh` → `SUMMARY: p01-phase-suite.sh pass=7 fail=0`, exit 0.

8. **Recent-changes dual-write** (CON-6 dual-write invariant; see CLAUDE.md `# >>> orchestrator:recent-changes >>>` region). Append a one-line P01 close fragment to `CLAUDE.md` (and `AGENTS.md` if present) via `scripts/util/dual-write-runtime-md.sh`. Fragment shape: `M030 P01 close: classifier (<NN>/40 ground-truth agreement) + routing table (cost_rates SSOT) + classifier-confidence stability metric (variance≤0.10 N=20 cov≥50) + doctor --config-check; phase-suite green pass=7 fail=0`. Substitute `<NN>` with the actual T02 ground-truth pass count.

9. **Stage and commit.** Add `scripts/diagnostics/run-doctor.sh` (modify), `tools/verify/p01-doctor-config-check.sh` (create), `tools/verify/p01-phase-suite.sh` (create), and the recent-changes-region update to `CLAUDE.md` (and `AGENTS.md` if present) and commit with `git commit -F <message-file>`. Recommended message: `M030/P01/T04: doctor --config-check routing-table validation + phase-suite gate`.

## Must-Haves

This task satisfies the phase truths:

- "`bash scripts/diagnostics/run-doctor.sh --config-check` exits 0 on a well-formed `templates/model-routing.yml` and exits 1 on a deliberately malformed fixture with stdout naming both the offending file path and the offending line number." — gated by `tools/verify/p01-doctor-config-check.sh` (FR-17 + SC-9).
- "`bash tools/verify/p01-phase-suite.sh` invokes all six P01 sub-gates in literal sequence, exits 0 iff every sub-gate passes, and emits `SUMMARY: p01-phase-suite.sh pass=N fail=M` on a single line before exit." — `tools/verify/p01-phase-suite.sh` is itself the gate; its own self-check is `bash tools/verify/p01-phase-suite.sh`.

## Verification

```bash
bash tools/verify/p01-doctor-config-check.sh
bash tools/verify/p01-phase-suite.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P01
```

Each verifier uses single-script-file shape per AD-19. The phase-suite is the canonical phase-close gate; if it exits 0 with `pass=7 fail=0`, P01 is ready for `orchestrator:verify`. `check-must-haves.sh` is the framework-owned final gate that runs all phase Truth `Check:` commands + Artifact existence + Key Link presence.

## Inputs

### From Previous Tasks

- `tools/verify/p01-d-a4-timeline.sh` (from T01)
  - Key API: `bash tools/verify/p01-d-a4-timeline.sh` exits 0 with `SUMMARY: p01-d-a4-timeline.sh pass=1 fail=0` in Mode B (post-T02 git-log ordering).

- `scripts/dispatch/classify-task.sh` (from T02)
  - Key API: emits `character=<...>` + `confidence=<...>` to stdout. T04 does not invoke directly; the four classifier verifiers (also from T02) gate it.

- `tools/verify/p01-classifier-determinism.sh`, `tools/verify/p01-classifier-perf-and-network.sh`, `tools/verify/p01-classifier-ground-truth.sh` (from T02)
  - Key API: each is `bash <path>` → exit 0 with `SUMMARY: <name> pass=N fail=0`.

- `templates/model-routing.yml` (from T03)
  - Key API: YAML file with `routing:`, `resolution:`, `cost_rates:` top-level sections. T04 reads via doctor's `--config-check` flag invocation; does not parse directly.

- `tools/verify/p01-routing-table-shape.sh` (from T03)
  - Key API: `bash tools/verify/p01-routing-table-shape.sh [path]` exits 0 on well-formed, exits 1 with stdout `FAIL: <path>:<lineno> — <message>` on malformation. T04 wires this into doctor's `--config-check` body and may amend it in Step 3 if line-number emission is missing.

- `references/model-routing.md` (from T03)
  - Key API: Markdown file with five required sections + concrete numeric stability-metric values. T04 does not modify.

- `tools/verify/p01-model-routing-doc-shape.sh` (from T03)
  - Key API: `bash tools/verify/p01-model-routing-doc-shape.sh` exits 0 with `SUMMARY: p01-model-routing-doc-shape.sh pass=8 fail=0` on the well-formed README.

### From Disk (Pre-existing)

- `scripts/diagnostics/run-doctor.sh` — existing diagnostic orchestrator with `--config-check` flag stub. T04 extends the flag body to invoke routing-table validation.
- `scripts/util/dual-write-runtime-md.sh` (if present) — recent-changes dual-write helper.
- `CLAUDE.md` — recent-changes region target for the P01-close fragment.
- `tools/verify/p00-phase-suite.sh` — reference pattern for the straight-line phase-suite shape.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. No `for` loops over script-name arrays in `p01-phase-suite.sh` (forbidden by the heuristic; the literal-statement form is required).
- **FR-17 file:line emission**: doctor `--config-check` malformation diagnostic MUST include both file path and line number per SC-9. If T03's `p01-routing-table-shape.sh` emits only `FAIL: <message>` without line numbers, T04 amends that verifier in Step 3.
- **Additive doctor extension**: the existing `--config-check` flag's other behaviors (if any) are preserved. The new routing-table check is additive when the flag is set.
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`, no `pipefail` reliance for capturing exit codes (use `$?` directly after each invocation, the same pattern as `p00-phase-suite.sh`).
- **No /tmp/ pollution**: the malformed fixture in Scenario B is cleaned up via `rm -f /tmp/p01-malformed-routing.yml` at end-of-verifier, success or fail.
- **`run-probe.sh` scope discipline (Plan-Time rule 4)**: `tools/verify/p01-doctor-config-check.sh` is a repo-resident verifier under `tools/verify/`; it is invoked directly via `bash tools/verify/p01-doctor-config-check.sh`, NOT wrapped in `run-probe.sh`. `run-probe.sh` is reserved for genuinely staged probes.
- **Plan-Time Discipline rule 5 (real-DB verification for SQL-bound code)**: T04 does NOT introduce SQL or schema migrations — this rule does not apply. The doctor extension is YAML-shape validation, not DB integration.

## Expected Output

- `scripts/diagnostics/run-doctor.sh` — extended `--config-check` body invokes `tools/verify/p01-routing-table-shape.sh` and propagates exit 1 with file:line on malformation.
- `tools/verify/p01-doctor-config-check.sh` — exercises both well-formed-pass and malformed-fail paths.
- `tools/verify/p01-phase-suite.sh` — straight-line aggregator over the seven P01 sub-gates.
- `bash tools/verify/p01-phase-suite.sh` exits 0 with `SUMMARY: p01-phase-suite.sh pass=7 fail=0`.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P01` exits 0 with all phase truths + artifacts + key-links passing.
- `CLAUDE.md` recent-changes region updated with P01-close fragment.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p01-doctor-config-check.sh` → `OK: well-formed routing.yml passes --config-check`, `OK: malformed fixture fails --config-check with file:line diagnostic`, `SUMMARY: p01-doctor-config-check.sh pass=N fail=0`, exit 0.
- `bash tools/verify/p01-phase-suite.sh` → seven sub-gate SUMMARY lines (one per gate), then `SUMMARY: p01-phase-suite.sh pass=7 fail=0`, exit 0.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P01` → all eight Truth checks pass, all eleven Artifact checks pass, all eight Key Link checks pass, `PASS: <count> truths, <count> artifacts, <count> key-links`, exit 0.

When P01's phase-suite green and the framework `check-must-haves.sh` green, P01 is ready for `orchestrator:verify` to write `P01-SUMMARY.md` and advance the milestone. Downstream P02 (Dispatch integration + shadow-mode JSONL + shadow-compare) consumes:

- `scripts/dispatch/classify-task.sh` — for hooking classifier invocation into `dispatch-interface.sh`.
- `templates/model-routing.yml` — for tier resolution at the adapter boundary.
- `references/model-routing.md` ## Classifier-Confidence Stability Metric section — for the concrete numeric thresholds `shadow-compare.sh` enforces.

The cross-cutting concern "Classifier-confidence stability metric definition" (M030-ROADMAP.md) is satisfied at P01 close: T03 nailed the numeric values, T04 confirmed them via the doc-shape verifier. P02 plan-phase consumes them verbatim.

If T03's `p01-routing-table-shape.sh` did not emit line numbers and T04's Step 3 amendment was needed, the amendment is a small surgical edit (changing `echo "FAIL: $msg"` to `echo "FAIL: $path:$lineno — $msg"` after extracting `$lineno` via `grep -n '<pattern>' "$path" | head -1 | cut -d: -f1`). This is a minimal change preserving the AD-19 single-script-file shape.
