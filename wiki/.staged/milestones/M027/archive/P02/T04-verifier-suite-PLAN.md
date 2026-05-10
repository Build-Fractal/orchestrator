---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M027"
name: "P02 verifier suite (m027-p02-suite.sh + per-contract m027-p02-*.sh)"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has shipped `scripts/diagnostics/efficiency-footer.sh` (≥ 80 lines, executable, sourceable). CLI accepts `--milestone`, `--project`, `--quiet`, `--config-defaults`, `--help`. Title: `Efficiency (Tier 1 rollup)`. `--quiet` emits zero stdout.
- T01 has added `efficiency_footer` and `predictive_cost_surface` to `VALID_KEYS` in `scripts/state/read-config.sh`.
- T02 has updated `commands/status.md` with the `## Efficiency Footer` section + the `efficiency-footer.sh` reference. Created `tests/fixtures/m027-p02/status-quiet-baseline.txt` and `tests/fixtures/m027-p02/README.md`.
- T03 has shipped `scripts/dispatch/predictive-surface.sh` (≥ 80 lines, executable, sourceable). CLI accepts `--description`, `--intensity quick|standard|full`, `--no-predict`, `--yes`, `--config-defaults`, `--help`. T03 has updated `commands/dispatch.md` with the `## Predictive Surface (M027/P02)` section + the 5-condition suppression matrix + the `predictive-surface.sh` reference.
- M027/P00 has shipped `scripts/verify/m027-rollup-schema.sh` (phase-suite orchestrator) and M027/P01 has shipped `scripts/verify/m027-p01-suite.sh` (mirror-shape phase-suite orchestrator). Both follow the canonical shape: parallel-string `GATES` list, per-gate exit-code capture, PASS/FAIL emission, RELAX-CANDIDATE forwarding, cheapest-first ordering. T04's `m027-p02-suite.sh` mirrors this verbatim.
- Project verifier conventions: scripts under `scripts/verify/` emit `PASS:` / `FAIL:` / `WARN:` to stdout (`FAIL:` may also go to stderr); exit 0 on green, 1 on red, 2 on usage error. Bash 3.2 compatible. No `declare -A`, no `<<<` herestrings, no `mapfile`.
- AD-19 (single-script-file `Check:` shape): T04's deliverables ARE the canonical phase-level `Check:` targets. T04's own `Verification` block invokes the suite orchestrator that T04 itself ships (single-script-file shape).
- T01/T02/T03 each shipped a scoped `m027-p02-t##-shape-precheck.sh`. T04 may delete those prechecks once the canonical verifiers ship and the phase-level `check-must-haves.sh` is green — mirroring the M027/P01/T03 + T04 pattern.

## Description

Ship 11 per-contract verifier scripts and one phase-suite orchestrator that together gate every Truth in the P02 phase plan. The suite is invoked at the phase boundary by `scripts/verify/check-must-haves.sh` (which auto-discovers `Check:` commands from `P02-PLAN.md`); the suite is also runnable standalone via `bash scripts/verify/m027-p02-suite.sh`.

The 11 per-contract verifiers correspond 1:1 to the 11 phase-level Truths defined in `P02-PLAN.md`:

1. `m027-p02-efficiency-footer-shape.sh` — gates Truth #1 (efficiency-footer helper shape + behavior).
2. `m027-p02-status-md-shape.sh` — gates Truth #2 (`commands/status.md` integration shape).
3. `m027-p02-status-quiet-byte-identity.sh` — gates Truth #3 (status `--quiet` byte-identity vs. fixture).
4. `m027-p02-predictive-surface-shape.sh` — gates Truth #4 (predictive-surface helper shape + behavior).
5. `m027-p02-suppression-matrix.sh` — gates Truth #5 (5-path suppression matrix).
6. `m027-p02-dispatch-md-shape.sh` — gates Truth #6 (`commands/dispatch.md` integration shape).
7. `m027-p02-predictive-surface-latency.sh` — gates Truth #7 (latency budget; inner-vs-outer split).
8. `m027-p02-predictive-goodhart-pairing.sh` — gates Truth #8 (Goodhart pairing on dispatch-time surface).
9. `m027-p02-zero-llm-token.sh` — gates Truth #9 (no LLM-invocation tokens in script set).
10. `m027-p02-read-only.sh` — gates Truth #10 (`git diff --quiet` after invocation).
11. `m027-p02-bash32-compat.sh` — gates Truth #11 (bash 3.2 forbidden constructs absent).

The phase-suite orchestrator `m027-p02-suite.sh` runs all 11 in stable order (cheapest static checks first; latency / live-invocation last) and aggregates results.

## Steps

1. **Create the phase-suite orchestrator** `scripts/verify/m027-p02-suite.sh` (mirrors the shape of `scripts/verify/m027-p01-suite.sh` and `scripts/verify/m027-rollup-schema.sh`). Skeleton:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m027-p02-suite.sh — M027/P02 phase-suite orchestrator.
   # Mirrors the shape of m027-p01-suite.sh / m027-rollup-schema.sh.
   set -u
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   GATES="m027-p02-bash32-compat m027-p02-zero-llm-token m027-p02-status-md-shape m027-p02-dispatch-md-shape m027-p02-efficiency-footer-shape m027-p02-predictive-surface-shape m027-p02-suppression-matrix m027-p02-predictive-goodhart-pairing m027-p02-status-quiet-byte-identity m027-p02-read-only m027-p02-predictive-surface-latency"
   pass=0; fail=0; failures=""; relax=""
   for gate in $GATES; do
     out="$(bash "$SCRIPT_DIR/${gate}.sh" 2>&1)"; rc=$?
     relax_line="$(printf '%s\n' "$out" | grep -E '^RELAX-CANDIDATE' || true)"
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
     echo "PASS: m027-p02-suite.sh ${pass} gates"; exit 0
   else
     echo "FAIL: m027-p02-suite.sh ${fail} gates failed:${failures}" >&2; exit 1
   fi
   ```

   Gate ordering rationale: bash32-compat (regex-only, < 50 ms) and zero-llm-token (regex-only) run first. Markdown-shape checks (status-md, dispatch-md) run early — pure file greps. Helper-shape checks run mid-suite. Suppression matrix runs after the shape checks (forks the helper 5x). Goodhart pairing runs after suppression. Byte-identity runs near the end (forks status-rendering proxy + diff). Read-only runs late (captures pre/post `git diff`). Latency runs LAST because it is the most environment-sensitive.

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

3. **`m027-p02-efficiency-footer-shape.sh`** (~60 lines) — gates Truth #1:
   - Assert `scripts/diagnostics/efficiency-footer.sh` exists, ≥ 80 lines, executable.
   - Assert `grep -q "Efficiency (Tier 1 rollup)" scripts/diagnostics/efficiency-footer.sh`.
   - Assert `grep -q "efficiency_footer_render" scripts/diagnostics/efficiency-footer.sh`.
   - Assert `grep -q "BASH_SOURCE" scripts/diagnostics/efficiency-footer.sh`.
   - Assert `grep -q -- "--quiet" scripts/diagnostics/efficiency-footer.sh`.
   - Assert `grep -q "metrics-rollup.sh" scripts/diagnostics/efficiency-footer.sh`.
   - Assert `grep -q "efficiency_footer" scripts/state/read-config.sh` (config knob registered).
   - Run `bash scripts/diagnostics/efficiency-footer.sh --quiet` and capture stdout + exit code; assert exit 0 and stdout is empty.
   - Run `bash scripts/diagnostics/efficiency-footer.sh --milestone [M019](../../../../milestones/M019/index.md)` and capture exit code; assert exit 0 (smoke-test that helper does not crash on a real milestone).
   - PASS.

4. **`m027-p02-status-md-shape.sh`** (~60 lines) — gates Truth #2:
   - Assert `commands/status.md` exists, ≥ 170 lines.
   - Assert `grep -q "## Efficiency Footer" commands/status.md`.
   - Assert `grep -q "efficiency-footer" commands/status.md`.
   - Assert `grep -q "scripts/diagnostics/efficiency-footer.sh" commands/status.md`.
   - Assert `grep -q -- "--quiet" commands/status.md` (suppression flag documented).
   - Assert `grep -q "efficiency_footer" commands/status.md` (config knob documented).
   - Assert pre-edit canonical section order is preserved. Implementation: capture line numbers of each canonical section header via `grep -n`, assert the sequence: `## State Derivation` < `## Progress Overview` < `## Blockers` < `## Execution History` < `## Telemetry Metrics` < `## Efficiency Footer` < `## Next Action` < `## Concurrent Safety` < `## Idempotency` < `## Error Handling` < `## Gotchas` < `## Reference Files`. Use a small bash function (or a sequence of `grep -n | head -1`) to extract each line number; assert each is strictly less than the next.
   - PASS.

5. **`m027-p02-status-quiet-byte-identity.sh`** (~70 lines) — gates Truth #3:
   - Assert fixture `tests/fixtures/m027-p02/status-quiet-baseline.txt` exists, ≥ 1 line.
   - Extract the post-`## Next Action` tail of the live `commands/status.md` via `awk '/^## Next Action/,EOF' commands/status.md > /tmp/m027-p02-live-tail.txt`.
   - Diff the live tail against the fixture: `diff /tmp/m027-p02-live-tail.txt tests/fixtures/m027-p02/status-quiet-baseline.txt`. Failure if diff exits non-zero.
   - Cleanup the temp file.
   - PASS.

6. **`m027-p02-predictive-surface-shape.sh`** (~70 lines) — gates Truth #4:
   - Assert `scripts/dispatch/predictive-surface.sh` exists, ≥ 80 lines, executable.
   - Assert `grep -q "predictive_cost_surface" scripts/dispatch/predictive-surface.sh`.
   - Assert `grep -q "predictive_surface_render" scripts/dispatch/predictive-surface.sh`.
   - Assert `grep -q "BASH_SOURCE" scripts/dispatch/predictive-surface.sh`.
   - Assert `grep -q "intensity-recommend.sh" scripts/dispatch/predictive-surface.sh`.
   - Assert `grep -q "INTENSITY_RECOMMEND_FAST_PATH" scripts/dispatch/predictive-surface.sh`.
   - Assert `grep -q "_CE_RECOMMENDED" scripts/dispatch/predictive-surface.sh`.
   - Assert `grep -q "predictive_cost_surface" scripts/state/read-config.sh` (config knob registered).
   - Run `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard` and capture stdout + exit code; assert exit 0 and stdout contains `predictive_cost_surface` (interactive surface rendered).
   - Assert the rendered output contains the literal `override:` (override prompt present per CON-10).
   - PASS.

7. **`m027-p02-suppression-matrix.sh`** (~80 lines) — gates Truth #5:
   - For each of the 5 suppression conditions, run the helper and assert empty stdout + exit 0:
     - `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard --yes`
     - `ORCHESTRATOR_AUTO=1 bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard`
     - `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard --no-predict`
     - `ORCH_PREDICTIVE_COST_SURFACE=false bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard`
     - `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity quick`
   - Each must produce empty stdout AND exit 0.
   - Failure if any path produces non-empty stdout OR non-zero exit.
   - PASS.

8. **`m027-p02-dispatch-md-shape.sh`** (~60 lines) — gates Truth #6:
   - Assert `commands/dispatch.md` exists, ≥ 160 lines.
   - Assert `grep -q "## Predictive Surface" commands/dispatch.md`.
   - Assert `grep -q "predictive-surface" commands/dispatch.md`.
   - Assert `grep -q "scripts/dispatch/predictive-surface.sh" commands/dispatch.md`.
   - Assert all 5 suppression-matrix tokens are documented: `grep -q -- "--yes" commands/dispatch.md`, `grep -q "ORCHESTRATOR_AUTO" commands/dispatch.md`, `grep -q -- "--no-predict" commands/dispatch.md`, `grep -q "predictive_cost_surface" commands/dispatch.md`, `grep -qE "intensity.*quick|quick.*intensity" commands/dispatch.md`.
   - Assert pre-edit canonical section order is preserved. Capture line numbers of each canonical section header; assert: `## Intensity Behavior` < `## Prerequisites` < `## Context Construction` < `## Dispatch Strategy` < `## Predictive Surface` < `## Execution Recording` < `## Post-Dispatch` < `## Idempotency` < `## Error Handling` < `## Claude Code Appendix` < `## Gotchas` < `## Referenced Scripts` < `## Referenced Templates`.
   - Run `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard --yes` and assert empty stdout / exit 0 (suppressed-mode contract).
   - PASS.

9. **`m027-p02-predictive-surface-latency.sh`** (~80 lines) — gates Truth #7:
   - Inner measurement: `INTENSITY_RECOMMEND_FAST_PATH=1 _CE_RECOMMENDED=standard time bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard >/dev/null 2>&1` — repeat 3x, take min wall-clock. Use `perl -MTime::HiRes` for sub-second timing on macOS (perl is standard on macOS); fall back to `date +%s` (1-second precision; only fails on >1000 ms).
   - Outer measurement: same invocation WITHOUT `INTENSITY_RECOMMEND_FAST_PATH=1` / `_CE_RECOMMENDED` pre-set — repeat 3x, take min wall-clock.
   - Inner threshold: hard fail at 100 ms (CON-9 carry-forward). PASS below 100 ms.
   - Outer threshold: report informational; if > 250 ms, emit `RELAX-CANDIDATE: outer-wall-clock measured=<N>ms target=100ms (~200ms macOS bash startup overhead)`. Outer threshold does NOT fail the gate (mirrors P01/T04 latency verifier).
   - Both numbers reported in stdout regardless of pass/fail.
   - PASS on inner threshold.

10. **`m027-p02-predictive-goodhart-pairing.sh`** (~50 lines) — gates Truth #8:
    - Run `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard` and capture stdout.
    - For each line that contains a cost token (matches `cost_quick_usd|cost_standard_usd|cost_full_usd|cost_pricing_warning`), assert that the same render block also contains a quality token (matches `cost_quick_quality|cost_standard_quality|cost_full_quality`).
    - Implementation: simpler structural check — assert that the rendered block contains AT LEAST ONE `cost_*_usd` line AND AT LEAST ONE `cost_*_quality` line. The P01 hook contract (carried into the dispatch-time surface) guarantees both classes of lines on every render; the test asserts the contract holds at THIS attach point.
    - Failure if any cost class is present without its quality counterpart.
    - PASS.

11. **`m027-p02-zero-llm-token.sh`** (~40 lines) — gates Truth #9:
    - For each file in: `scripts/diagnostics/efficiency-footer.sh`, `scripts/dispatch/predictive-surface.sh`, every `scripts/verify/m027-p02-*.sh`.
    - `grep -nE "(claude_chat|anthropic|dispatch-interface\.sh|dispatch_task|subagent)"` against each file. Failure if any match.
    - Exclude self via explicit file list (mirrors P01/T04 carve-out — the verifier file itself contains the regex string but is excluded from the scan list).
    - Implementation: `FILES="scripts/diagnostics/efficiency-footer.sh scripts/dispatch/predictive-surface.sh scripts/verify/m027-p02-efficiency-footer-shape.sh scripts/verify/m027-p02-status-md-shape.sh scripts/verify/m027-p02-status-quiet-byte-identity.sh scripts/verify/m027-p02-predictive-surface-shape.sh scripts/verify/m027-p02-suppression-matrix.sh scripts/verify/m027-p02-dispatch-md-shape.sh scripts/verify/m027-p02-predictive-surface-latency.sh scripts/verify/m027-p02-predictive-goodhart-pairing.sh scripts/verify/m027-p02-read-only.sh scripts/verify/m027-p02-bash32-compat.sh scripts/verify/m027-p02-suite.sh"`. The verifier file itself (`m027-p02-zero-llm-token.sh`) is intentionally absent from `FILES`.
    - PASS.

12. **`m027-p02-read-only.sh`** (~50 lines) — gates Truth #10:
    - Capture `git diff --quiet`'s exit status before the run. If non-zero (the working tree is already dirty), emit `WARN: working-tree-dirty pre-run; skipping read-only assertion` and exit 0 (mirrors P01/T04 pattern).
    - Else, run a sequence of read-only invocations:
      - `bash scripts/diagnostics/efficiency-footer.sh --quiet >/dev/null`
      - `bash scripts/diagnostics/efficiency-footer.sh --milestone M019 >/dev/null`
      - `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard >/dev/null`
      - `bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard --yes >/dev/null`
    - Re-run `git diff --quiet`. Failure if exit non-zero.
    - PASS.

13. **`m027-p02-bash32-compat.sh`** (~60 lines) — gates Truth #11:
    - For each file in: `scripts/diagnostics/efficiency-footer.sh`, `scripts/dispatch/predictive-surface.sh`, every `scripts/verify/m027-p02-*.sh`, `commands/status.md`, `commands/dispatch.md`.
    - For each file, `grep -nE` against the forbidden-construct regex: `(declare -A|mapfile|readarray|<<<|<\(|>\(|&>|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^})`. Failure if any match (excluding the verifier file itself).
    - Exclude self via explicit file list (the verifier contains the regex literal).
    - Markdown files MAY contain forbidden tokens inside fenced code blocks documenting examples; implementation discipline says they should NOT — if a code block legitimately needs to show a forbidden construct, use the literal escaped form. Simpler discipline: do not include forbidden constructs in the markdown body.
    - PASS.

14. **`chmod +x`** all 12 new scripts (`m027-p02-suite.sh` + 11 per-contract verifiers).

15. **Delete the T01/T02/T03 scoped prechecks** (`scripts/verify/m027-p02-t01-shape-precheck.sh`, `scripts/verify/m027-p02-t02-shape-precheck.sh`, `scripts/verify/m027-p02-t03-shape-precheck.sh`) once the canonical verifiers ship and `bash scripts/verify/m027-p02-suite.sh` exits 0. This mirrors the M027/P01/T03 + T04 pattern (the prechecks are scaffolding to satisfy the per-task `Verification` block; once the canonical verifiers exist, the prechecks are redundant).

## Must-Haves

- File `scripts/verify/m027-p02-suite.sh` exists, ≥ 30 lines, contains the literal string `m027-p02`.
- Files `scripts/verify/m027-p02-*.sh` exist for each of the 11 per-contract verifiers (see Phase Plan Artifacts list).
- Running `bash scripts/verify/m027-p02-suite.sh` from the project root exits 0 against the post-P02 codebase.
- Each per-contract verifier exits 0 in isolation against the post-P02 codebase.
- Verifiers are bash 3.2 compatible (the bash32-compat verifier scans them).
- Phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P02` exits 0.
- T01/T02/T03 scoped prechecks deleted (no leftover `m027-p02-t##-shape-precheck.sh` files).

## Verification

```bash
bash scripts/verify/m027-p02-suite.sh
```

The above must exit 0 and emit `PASS: m027-p02-suite.sh 11 gates` on stdout. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P02` also runs at the phase boundary; it auto-discovers the 11 Truth `Check:` commands from the phase plan and re-runs them. Both should be green.

## Inputs

### From Previous Tasks

- T01: `scripts/diagnostics/efficiency-footer.sh` — invoked by 4 verifiers (efficiency-footer-shape, status-quiet-byte-identity, read-only, bash32-compat). Library function: `efficiency_footer_render`. CLI flags: `--milestone`, `--project`, `--quiet`, `--config-defaults`, `--help`. `--quiet` emits zero stdout / exit 0.
- T01: modified `scripts/state/read-config.sh` `VALID_KEYS` to include `efficiency_footer` and `predictive_cost_surface`. Verifiers grep this file for both keys.
- T02: modified `commands/status.md` (≥ 170 lines, contains `## Efficiency Footer` section, references `scripts/diagnostics/efficiency-footer.sh`). Created `tests/fixtures/m027-p02/status-quiet-baseline.txt` and `tests/fixtures/m027-p02/README.md`. The fixture is the load-bearing input to the byte-identity verifier.
- T03: `scripts/dispatch/predictive-surface.sh` — invoked by 5 verifiers (predictive-surface-shape, suppression-matrix, dispatch-md-shape, predictive-surface-latency, predictive-goodhart-pairing). Library function: `predictive_surface_render`. CLI flags: `--description`, `--intensity`, `--no-predict`, `--yes`, `--config-defaults`, `--help`.
- T03: modified `commands/dispatch.md` (≥ 160 lines, contains `## Predictive Surface` section + 5-condition suppression matrix + `predictive-surface.sh` reference).

### From Disk (Pre-existing)

- `scripts/diagnostics/metrics-rollup.sh` (P00) — invoked transitively by the efficiency-footer-shape smoke test (`--milestone M019`).
- `scripts/engine/intensity-recommend.sh` (P01) — invoked transitively by the predictive-surface-shape and predictive-goodhart-pairing tests via the helper.
- `scripts/verify/m027-p01-suite.sh` (P01) and `scripts/verify/m027-rollup-schema.sh` (P00) — reference shapes for the phase-suite orchestrator. Mirror verbatim: parallel-string `GATES` list, per-gate exit-code capture, `RELAX-CANDIDATE` forwarding, cheapest-first ordering.
- `perl -MTime::HiRes` — standard on macOS; used by latency verifier for sub-second timing.
- `awk` (POSIX) — used by status-quiet-byte-identity verifier to extract the post-`## Next Action` tail of `commands/status.md`.
- `tests/fixtures/m027-p02/status-quiet-baseline.txt` (created by T02) — baseline fixture for byte-identity verifier.

## Constraints

- **CON-1 / FR-12 (read-only)**: Verifiers are read-only. They MAY create temp files under `${TMPDIR:-/tmp}/` but never write to the project tree. `read-only.sh` explicitly asserts `git diff --quiet` post-invocation.
- **CON-7 (bash 3.2)**: Every verifier passes the bash32-compat scan. No `declare -A`, no `<<<`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`.
- **AD-19 (single-script-file Check shape)**: The phase plan's 11 Truths each have a single-script-file `Check:` invoking these verifiers. Each verifier internally MAY use pipes / `$()` / `awk` (MEM004 emitter-internal carve-out).
- **CON-9 / FR-22 / SC-15 (latency carry-forward)**: The `predictive-surface-latency.sh` verifier hard-fails at 100 ms on the inner measurement and reports outer measurement as informational with `RELAX-CANDIDATE` annotation. Mirrors P01/T04 latency verifier.
- **CON-3 / SC-3 / SC-17 (back-compat byte-identity)**: The `status-quiet-byte-identity.sh` verifier diffs the live `commands/status.md` post-`## Next Action` tail against the T02 fixture. The `suppression-matrix.sh` verifier exercises all 5 suppression paths against the predictive-surface helper.
- **CON-4 / SC-18 (Goodhart pairing carry-forward)**: The `predictive-goodhart-pairing.sh` verifier asserts paired cost+quality at the dispatch-time surface attach point.
- **FR-21 / CON-6 / SC-16 (zero-LLM-token)**: The `zero-llm-token.sh` verifier scans the M027/P02 script set for forbidden LLM-invocation patterns.
- **#Q-16 resolution**: The `suppression-matrix.sh` verifier exercises the `--no-predict` flag as one of the 5 suppression paths, asserting the always-on-with-override contract.

## Expected Output

After this task:

1. 12 new scripts under `scripts/verify/` (1 suite orchestrator + 11 per-contract verifiers), each ≥ 30 lines, executable.
2. T01/T02/T03 scoped prechecks deleted (`scripts/verify/m027-p02-t01-shape-precheck.sh`, `scripts/verify/m027-p02-t02-shape-precheck.sh`, `scripts/verify/m027-p02-t03-shape-precheck.sh` removed).
3. Running `bash scripts/verify/m027-p02-suite.sh` exits 0 and emits `PASS: m027-p02-suite.sh 11 gates` on stdout.
4. Running each per-contract verifier in isolation exits 0 against the post-P02 codebase.
5. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P02` exits 0 (auto-discovers and re-runs the 11 Truth `Check:` commands from `P02-PLAN.md`).
6. `git diff --quiet` after running the suite is exit 0 — verifiers are read-only.
