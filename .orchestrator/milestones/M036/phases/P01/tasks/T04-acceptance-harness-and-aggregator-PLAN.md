---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M036"
name: "SC-9 acceptance harness + phase-suite aggregator"
depends_on: ["T02", "T03"]
---

## Prerequisites

- T02 completed: `scripts/dispatch/adapters/format/markdown.sh` and `pdf.sh` exist and are executable; their registry rows are `status=live`; `tools/verify/m036-p01-markdown-adapter.sh` and `m036-p01-pdf-adapter.sh` exist and exit 0.
- T03 completed: `scripts/dispatch/adapters/format/docx.sh`, `xlsx.sh`, and `lib/xlsx-to-csv.py` exist; their registry rows are `status=live`; `tools/verify/m036-p01-docx-adapter.sh` and `m036-p01-xlsx-adapter.sh` exist and exit 0.
- All four registry rows confirmed at `status=live` (no `stub` rows remaining for the four formats).

## Description

Land the three remaining surfaces:

1. **`tests/test-tier-1-adapters.sh`** — the SC-9 acceptance harness. Invokes all four real adapters against all four real binary fixtures (per Plan-Time Discipline rule 5, real-binary smoke; per CON-3 amended, binary fixtures permitted under `tests/fixtures/m036-tier-1-adapters/`). Emits `BATTERY: pass=N fail=N` summary line.
2. **`tools/verify/m036-p01-registry-all-live.sh`** — asserts the registry contract (all four formats at `status=live`).
3. **`tools/verify/m036-p01-test-harness.sh`** — asserts the SC-9 harness exists, is executable, runs to completion, and emits `BATTERY:`.
4. **`tools/verify/m036-p01-phase-suite.sh`** — phase-suite aggregator wiring all 8 P01 sub-gates (the 4 per-adapter verifiers + the registry-contract verifier + the probe-shape verifier + the fixture-corpus-shape verifier + the test-harness verifier). Patterned after `tools/verify/m036-p00-phase-suite.sh`.

## Steps

1. Author `tests/test-tier-1-adapters.sh`. Behavioral contract:

   - `set -eu`, Bash 3.2 compatible.
   - Resolves repo root via `ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"`.
   - Creates a single temp dir under `${TMPDIR:-/tmp}` for xlsx output (`mktemp -d`).
   - Defines a `run_adapter <label> <command-and-args...>` helper that captures stdout to a per-adapter temp file, records exit code, increments pass/fail counters by inspecting expectations.
   - Test cases (each its own statement, no compound chains):
     - **markdown**: invoke `bash "$ROOT/scripts/dispatch/adapters/format/markdown.sh" "$ROOT/tests/fixtures/m036-tier-1-adapters/sample.md"`; assert exit 0 + diff-clean against the fixture.
     - **pdf**: SKIP if `command -v pdftotext` fails (`SKIP: pdf (pdftotext absent)`); else invoke `bash "$ROOT/scripts/dispatch/adapters/format/pdf.sh" "$ROOT/tests/fixtures/m036-tier-1-adapters/sample.pdf"`; assert exit 0 + non-empty + each token from `expected/sample-pdf.txt` present (loop over allowlist via plain `while read`, NOT a process-substitution `< <(...)` — use `cat allowlist | while read` is also forbidden under AP-009 since it's piped; instead use `for tok in $(cat allowlist)` only if the allowlist is short — preferred form: `while IFS= read -r tok; do ... done <"$allowlist"` (input redirect from a file, not from a substitution, is permitted).
     - **docx**: SKIP if `command -v pandoc` fails; else invoke `bash docx.sh sample.docx`; assert exit 0 + non-empty + tokens present.
     - **xlsx**: SKIP if `python3 -c "import openpyxl"` fails; else invoke `bash xlsx.sh sample.xlsx --out-dir <temp>`; assert exit 0 + per-sheet CSVs match `expected/sample-xlsx-sheet1.csv` and `sample-xlsx-sheet2.csv`.
   - Each assertion increments `pass` or `fail`; SKIPs increment a separate `skip` counter (don't fail).
   - Final stdout line: `BATTERY: pass=<P> fail=<F> skip=<S>` (note: the planning payload requires `BATTERY: pass=N fail=0` shape — emit `skip=` as an additional field; consumers grep for `BATTERY:` and parse the `pass=`/`fail=` fields explicitly).
   - Exits 0 iff `fail=0` (SKIPs are not failures).

2. Author `tools/verify/m036-p01-registry-all-live.sh`. Behavioral contract:
   - Reads `scripts/dispatch/adapters/format/registry.tsv`.
   - For each of the four formats (`markdown`, `pdf`, `docx`, `xlsx`), uses `awk -F'\t' '$1=="<format>" {print $3}' registry.tsv` (single-script-file shape; awk is one tool, not a pipe) to extract the status field.
   - Asserts the extracted status is exactly `live` for each row.
   - Emits `PASS: <format>=live` or `FAIL: <format>=<actual-status>`, final summary, exit 0 iff all four pass.

3. Author `tools/verify/m036-p01-test-harness.sh`. Behavioral contract:
   - Asserts `tests/test-tier-1-adapters.sh` exists and is executable (`-x`).
   - Invokes `bash tests/test-tier-1-adapters.sh` (single statement; capture stdout to a temp file).
   - Asserts the temp file contains a `BATTERY:` line via a single `grep -q "^BATTERY:" <temp>`.
   - Optionally asserts `pass>=4` (or `pass+skip>=4`) — but be permissive: when host tooling is absent, the harness SKIPs, so the contract is "ran to completion + emitted BATTERY: line", not "all four passed".
   - Emits `PASS:` / `FAIL:`, final summary, exit 0 iff all assertions pass.

4. Author `tools/verify/m036-p01-phase-suite.sh`. Behavioral contract: a near-clone of `tools/verify/m036-p00-phase-suite.sh` (use it as the template). Wires 8 sub-gates:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p01-phase-suite.sh -- M036 P01 phase-suite aggregator.
   # Single-script-file shape per AD-19. Filename milestone-prefixed per the
   # naming convention (commands/plan-phase.md "milestone slug REQUIRED").
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   pass=0
   fail=0
   run() {
     local gate="$1"
     if bash "$ROOT/tools/verify/$gate" >/dev/null 2>&1; then
       echo "PASS: $gate"
       pass=$((pass + 1))
     else
       echo "FAIL: $gate"
       fail=$((fail + 1))
     fi
   }
   run m036-p01-fixture-corpus-shape.sh
   run m036-p01-probe-shape.sh
   run m036-p01-markdown-adapter.sh
   run m036-p01-pdf-adapter.sh
   run m036-p01-docx-adapter.sh
   run m036-p01-xlsx-adapter.sh
   run m036-p01-registry-all-live.sh
   run m036-p01-test-harness.sh
   echo "SUMMARY: m036-p01-phase-suite.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then
     exit 1
   fi
   exit 0
   ```

   Make executable.

## Must-Haves

- SC-9 harness exists, runs all four adapters against real fixtures, emits `BATTERY:` (Truth: m036-p01-test-harness).
- Registry contract verified: all four formats at `status=live` (Truth: m036-p01-registry-all-live).
- Phase-suite aggregator wires all 8 P01 sub-gates and exits 0 iff all pass (Artifact: `m036-p01-phase-suite.sh` ≥25 lines, contains `SUMMARY: m036-p01-phase-suite.sh`).
- Key Link: `tests/test-tier-1-adapters.sh` references `scripts/dispatch/adapters/format/pdf.sh` (and the other three adapters).

## Verification

```bash
bash tools/verify/m036-p01-registry-all-live.sh
bash tools/verify/m036-p01-test-harness.sh
bash tools/verify/m036-p01-phase-suite.sh
bash tests/test-tier-1-adapters.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M036/phases/P01
```

## Inputs

### From Previous Tasks

- `scripts/dispatch/adapters/format/markdown.sh` (from T02) — Tier 1 markdown passthrough; exit 0 on valid input, emits source bytes.
- `scripts/dispatch/adapters/format/pdf.sh` (from T02) — Tier 1 pdf adapter; exit 0/1/2 contract; emits `pdftotext -layout` output.
- `scripts/dispatch/adapters/format/docx.sh` (from T03) — Tier 1 docx adapter; exit 0/1/2; emits `pandoc -t plain` output.
- `scripts/dispatch/adapters/format/xlsx.sh` (from T03) — Tier 1 xlsx adapter; argument shape `<input> --out-dir <target>`; emits `CSV:` lines + `SUMMARY: xlsx-to-csv sheets=N`.
- `scripts/dispatch/adapters/format/lib/xlsx-to-csv.py` (from T03) — openpyxl shim; invoked indirectly via xlsx.sh.
- `scripts/dispatch/adapters/format/registry.tsv` (modified by T02 + T03) — all four format rows at `status=live` after T03.
- `tools/verify/m036-p01-fixture-corpus-shape.sh`, `m036-p01-probe-shape.sh`, `m036-p01-markdown-adapter.sh`, `m036-p01-pdf-adapter.sh`, `m036-p01-docx-adapter.sh`, `m036-p01-xlsx-adapter.sh` (from T01 / T02 / T03) — wired into the phase-suite aggregator.
- `tests/fixtures/m036-tier-1-adapters/` (from T01) — fixture corpus consumed by the SC-9 harness.

### From Disk (Pre-existing)

- `tools/verify/m036-p00-phase-suite.sh` — template/shape reference for the new P01 phase-suite aggregator. Same `set -eu` + `run()` helper + `SUMMARY:` line format.
- `scripts/verify/check-must-haves.sh` (framework-owned) — the framework verifier consuming the phase-plan must-haves declared in P01-PLAN.md.

## Constraints

- CON-2: Bash 3.2 / POSIX-sh for `tests/test-tier-1-adapters.sh` and all verifiers.
- CON-3 (amended): `tests/test-tier-1-adapters.sh` invokes real adapters against real binary fixtures under `tests/fixtures/m036-tier-1-adapters/`. No mocks. This satisfies Plan-Time Discipline rule 5 (real-app smoke).
- CON-4: idempotent. Re-running the SC-9 harness on unchanged fixtures + adapters produces identical exit code and identical-shape stdout (counter values stable, paths stable up to mktemp randomness which is acceptable since the verifier greps for `BATTERY:` not exact paths).
- AD-19 / AP-009 single-script-file shape: every `Check:` and `## Verification` line is `bash <script>` form. Inside `tests/test-tier-1-adapters.sh` and the verifiers, internal logic uses sequential statements (newline-separated), not compound `;` chains >2, no `( ... )` subshells, no `<(...)`.
- The phase-suite aggregator's `run` helper uses `if bash ... >/dev/null 2>&1; then` — this is a *control-flow* construct around a single command, NOT a compound chain. The pattern is identical to `m036-p00-phase-suite.sh` which is in production. Confirmed safe under the harness shape-classifier (runs in script body, never surfaces to the outer classifier).

## Notes

Expected verifier output:
- `m036-p01-registry-all-live.sh` — `PASS: markdown=live`, `PASS: pdf=live`, `PASS: docx=live`, `PASS: xlsx=live`, `SUMMARY: m036-p01-registry-all-live pass=4 fail=0`, exit 0.
- `m036-p01-test-harness.sh` — `PASS: harness-exists`, `PASS: harness-executable`, `PASS: harness-emits-BATTERY`, final summary, exit 0.
- `m036-p01-phase-suite.sh` — 8 `PASS:` lines (one per sub-gate), `SUMMARY: m036-p01-phase-suite.sh pass=8 fail=0`, exit 0.
- `tests/test-tier-1-adapters.sh` — on fully-tooled host: `BATTERY: pass=4 fail=0 skip=0`. On dev host today (pdftotext present, pandoc/openpyxl absent): `BATTERY: pass=2 fail=0 skip=2` — still exit 0; SKIPs are not failures. Once host tooling is installed (run `bash scripts/lifecycle/probe-extraction-tools.sh` for hints) the battery converges to pass=4.

Final phase verification:
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M036/phases/P01` should emit `PASS:` for every truth, every artifact line/content check, and every key link.

## Expected Output

After T04 completes:
- `tests/test-tier-1-adapters.sh` exists and emits `BATTERY:` summary.
- 4 new project-owned verifiers under `tools/verify/`: `m036-p01-registry-all-live.sh`, `m036-p01-test-harness.sh`, `m036-p01-phase-suite.sh`, plus the per-adapter and shape verifiers from T01-T03 (8 total under the M036 P01 namespace).
- Phase suite passes: `tools/verify/m036-p01-phase-suite.sh` exits 0 with `SUMMARY: m036-p01-phase-suite.sh pass=8 fail=0` (assuming host tooling present; SKIPs in per-adapter verifiers also count as `PASS:` at the aggregator level since those verifiers exit 0 on SKIP).
- `scripts/verify/check-must-haves.sh` against the P01 phase dir emits `PASS:` for every must-have.
- Phase P01 transitions to `verified` state; downstream phases (P02 onwards) become unblocked.
