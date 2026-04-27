---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M027"
name: "P01 verifier suite (m027-p01-suite.sh + per-contract m027-p01-*.sh)"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has shipped `scripts/engine/cost-estimate.sh` (≥200 lines, executable, sourceable).
- T02 has modified `scripts/engine/intensity-recommend.sh` to accept `--format text|json` and append per-tier cost annotations in text mode.
- T03 has created `commands/cost.md` (with the D027 verbatim disclaimer under `## Accuracy`), `packaging/bundle/skills/orchestrator-cost.md`, and updated `packaging/bundle/manifest.yml`.
- M027/P00 has shipped `scripts/diagnostics/metrics-rollup.sh` and a phase-suite orchestrator `scripts/verify/m027-rollup-schema.sh`. The phase-suite shape (parallel-string `GATES` list, per-gate exit-code capture, PASS/FAIL emission, cheapest-first ordering) is the canonical reference for T04's own suite orchestrator.
- Project verifier conventions: scripts under `scripts/verify/` emit `PASS:` / `FAIL:` / `WARN:` to stdout (`FAIL:` may also go to stderr); exit 0 on green, 1 on red, 2 on usage error. Bash 3.2 compatible. No `declare -A`, no `<<<` herestrings, no `mapfile`.

## Description

Ship 12 per-contract verifier scripts and one phase-suite orchestrator that together gate every Truth in the P01 phase plan. The suite is invoked at the phase boundary by `scripts/verify/check-must-haves.sh` (which auto-discovers `Check:` commands from `P01-PLAN.md`); the suite is also runnable standalone via `bash scripts/verify/m027-p01-suite.sh`.

The 12 per-contract verifiers correspond 1:1 to the 12 phase-level Truths defined in `P01-PLAN.md`:

1. `m027-p01-cost-command-shape.sh` — gates Truth #1 (`commands/cost.md` exists, follows MEM012, contains D027 disclaimer).
2. `m027-p01-cost-retro-default.sh` — gates Truth #2 (orchestrator:cost retrospective default behavior).
3. `m027-p01-cost-estimate-table.sh` — gates Truth #3 (`--estimate` produces 3-row paired table + accuracy trailer).
4. `m027-p01-predictive-goodhart-pairing.sh` — gates Truth #4 (every cost row carries a quality cell).
5. `m027-p01-zero-llm-token.sh` — gates Truth #5 (script set has no LLM-invocation tokens).
6. `m027-p01-predictive-latency.sh` — gates Truth #6 (`cost-estimate.sh` < 100 ms wall-clock).
7. `m027-p01-pricing-degradation.sh` — gates Truth #7 (missing pricing.yml degrades gracefully).
8. `m027-p01-intensity-text-back-compat.sh` — gates Truth #8 (intensity-recommend.sh text byte-stability).
9. `m027-p01-intensity-json-cost-estimates.sh` — gates Truth #9 (intensity-recommend.sh JSON cost_estimates per D026).
10. `m027-p01-read-only.sh` — gates Truth #10 (git diff --quiet after invocation).
11. `m027-p01-runtime-adapter-registration.sh` — gates Truth #11 (Claude Code / Codex / Cursor adapter dry-run lists orchestrator-cost.md).
12. `m027-p01-bash32-compat.sh` — gates Truth #12 (bash 3.2 forbidden constructs absent).

The phase-suite orchestrator `m027-p01-suite.sh` runs all 12 in stable order (cheapest static checks first; latency / live-invocation last) and aggregates results.

## Steps

1. **Create the phase-suite orchestrator** `scripts/verify/m027-p01-suite.sh` (mirror the shape of `scripts/verify/m027-rollup-schema.sh` from P00). Skeleton:

   ```
   #!/usr/bin/env bash
   set -u
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   GATES="m027-p01-cost-command-shape m027-p01-bash32-compat m027-p01-zero-llm-token m027-p01-cost-retro-default m027-p01-cost-estimate-table m027-p01-predictive-goodhart-pairing m027-p01-pricing-degradation m027-p01-intensity-text-back-compat m027-p01-intensity-json-cost-estimates m027-p01-runtime-adapter-registration m027-p01-read-only m027-p01-predictive-latency"
   pass=0; fail=0; failures=""
   for gate in $GATES; do
     out="$(bash "$SCRIPT_DIR/${gate}.sh" 2>&1)"; rc=$?
     if [ $rc -eq 0 ]; then pass=$((pass+1)); echo "PASS: ${gate}"
     else fail=$((fail+1)); failures="${failures} ${gate}"; echo "FAIL: ${gate}"; printf '%s\n' "$out" >&2
     fi
   done
   if [ $fail -eq 0 ]; then echo "PASS: m027-p01-suite.sh ${pass} gates"; exit 0
   else echo "FAIL: m027-p01-suite.sh ${fail} gates failed:${failures}" >&2; exit 1
   fi
   ```

   Gate ordering rationale: bash32-compat (regex-only, < 50 ms) and cost-command-shape (file-grep, < 50 ms) run first. The latency verifier runs last because it is the most environment-sensitive. The runtime-adapter registration verifier runs near the end because it forks the adapter scripts.

2. **Per-contract verifier scripts** — create each under `scripts/verify/`. Each follows this skeleton:

   ```
   #!/usr/bin/env bash
   set -u
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"
   # ... contract-specific assertions ...
   if [ <fail-condition> ]; then echo "FAIL: <gate-name> <reason>" >&2; exit 1; fi
   echo "PASS: <gate-name>"
   exit 0
   ```

3. **`m027-p01-cost-command-shape.sh`** (~50 lines):
   - Assert `commands/cost.md` exists and is non-empty.
   - Assert `grep -q "^description:" commands/cost.md` (frontmatter present).
   - Assert `grep -q "orchestrator:cost" commands/cost.md`.
   - Assert `grep -qF "Estimates use M019 char-quartile token approximation and pricing.yml rates; actual cost typically lands within +/-20%. Runtime-actuals calibration is Tier 3 (deferred)." commands/cost.md` (D027 verbatim).
   - Assert `grep -q "## Accuracy" commands/cost.md`.
   - Assert `grep -q "scripts/diagnostics/metrics-rollup.sh" commands/cost.md`.
   - Assert `grep -q "scripts/engine/cost-estimate.sh" commands/cost.md`.
   - Assert `grep -q "scripts/engine/intensity-recommend.sh" commands/cost.md`.
   - Assert line count ≥ 80.
   - Pass.

4. **`m027-p01-cost-retro-default.sh`** (~60 lines):
   - Run a dry-run / mock equivalent. Since `orchestrator:cost` is a markdown command (not a shell entry point), this verifier asserts the *delegation contract* documented in `commands/cost.md`: under `## Core Workflow ### 2.` the document references `metrics-rollup.sh` and the `--milestone` / `--phase` / `--task` / `--granularity` / `--source` flags pass through.
   - Assert `grep -q "metrics-rollup.sh" commands/cost.md`.
   - Assert `grep -qE -- "--granularity|--milestone|--phase|--task" commands/cost.md`.
   - Run `bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019` and capture exit code; assert exit 0 (smoke-test that the delegated engine still works post-T01/T02/T03).
   - Pass.

5. **`m027-p01-cost-estimate-table.sh`** (~80 lines):
   - Run `bash scripts/engine/cost-estimate.sh --description "add a TypeScript rewrite of the parser"` and capture stdout + exit code.
   - Assert exit 0.
   - Assert stdout contains lines matching the labels `Quick`, `Standard`, `Full` (one each).
   - Assert exactly one line is marked recommended (asterisk `*` or some unambiguous marker; T01 spec says `*` in RECOMMENDED column).
   - Assert stdout contains the verbatim D027 trailer `estimates +/-~20%; see commands/cost.md#accuracy`.
   - Assert each tier row contains a numeric (or `(unavailable)`) cost cell.
   - Assert each tier row contains a quality semantics token (`best-effort` | `self-review` | `adversarial-gate`).
   - Pass.

6. **`m027-p01-predictive-goodhart-pairing.sh`** (~60 lines):
   - Run `bash scripts/engine/cost-estimate.sh --description "test prompt"` and capture stdout.
   - For each line that looks like a tier row (matching `^(Quick|Standard|Full)\b`), assert it contains BOTH a cost token AND a quality token. Failure if any tier row has cost without quality.
   - Run with `--format json` and parse the output: assert each tier object in `tiers.{quick,standard,full}` carries both `cost_usd` (number-or-null) AND `quality` (string).
   - Pass.

7. **`m027-p01-zero-llm-token.sh`** (~40 lines):
   - For each file in: `scripts/engine/cost-estimate.sh`, `scripts/engine/intensity-recommend.sh`, every `scripts/verify/m027-p01-*.sh`.
   - `grep -nE "(claude_chat|anthropic|dispatch-interface\.sh|dispatch_task|subagent)"` against each file. Failure if any match.
   - Note: the verifier file itself contains the regex string, so the script must match itself but its own occurrences are inside a single-quoted regex literal; the verifier excludes itself from the scan via `[ "$f" != "$0" ]` or by listing files explicitly without globbing. Implementation: list files explicitly.
   - Pass.

8. **`m027-p01-predictive-latency.sh`** (~60 lines):
   - Run `time bash scripts/engine/cost-estimate.sh --description "test" >/dev/null 2>&1` (or use `date +%s%3N` deltas for portability — bash 3.2 macOS lacks `%N`; use `python3 -c 'import time;print(int(time.time()*1000))'` or `perl -MTime::HiRes -e 'printf "%d\n", Time::HiRes::time*1000'`). Implementation: prefer `perl -MTime::HiRes` (perl is standard on macOS); fall back to `date +%s` (1-second precision; only fails the test on >1000 ms which is way over budget, so still useful).
   - Repeat 3 invocations; take the minimum wall-clock as the measured latency (warm-cache discipline).
   - Hard fail at 250 ms (CON-9 100 ms budget + 150 ms slack for CI noise); soft warn (`WARN: RELAX-CANDIDATE measured=<N>ms target=100ms`) between 100 ms and 250 ms; PASS below 100 ms.
   - In all cases, also run with `_CE_RECOMMENDED=standard` pre-set to skip the inner intensity-recommend re-fork; this measures the inner library overhead in isolation. Report both numbers in stdout.
   - Pass on hard threshold.

9. **`m027-p01-pricing-degradation.sh`** (~70 lines):
   - Set `ORCH_PRICING_FILE=/tmp/m027-p01-pricing-nonexistent.yml` (a path guaranteed not to exist).
   - Run `ORCH_PRICING_FILE=... bash scripts/engine/cost-estimate.sh --description "test"` and capture stdout + exit code.
   - Assert exit 0.
   - Assert stdout contains 3 tier rows (Quick, Standard, Full).
   - Assert at least one cost cell shows `(unavailable)` (or all three).
   - Assert the recommendation marker is still present.
   - Run `ORCH_PRICING_FILE=... bash scripts/engine/cost-estimate.sh --description "test" --format json` and assert the JSON parses and `tiers.quick.cost_usd == null` (use `python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["tiers"]["quick"]["cost_usd"] is None'` — python3 is standard on macOS) OR a regex check `grep -qE '"quick":\{[^}]*"cost_usd":null'`.
   - Same for `intensity-recommend.sh --format json` — assert `cost_estimates.quick.cost_usd == null`.
   - Pass.

10. **`m027-p01-intensity-text-back-compat.sh`** (~80 lines):
    - Capture pre-T02 baseline output: read the fixture `tests/fixtures/m027-p01/intensity-recommend-baseline-text.txt` (created in this verifier as a one-time setup, OR shipped as part of the verifier — implementation choice: ship the fixture as a side-by-side `.txt` file under `tests/fixtures/m027-p01/`). The fixture contains the exact 8 key=value lines that pre-T02 `intensity-recommend.sh --description "<canonical sample>"` would have emitted.
    - Run `bash scripts/engine/intensity-recommend.sh --description "<canonical sample>" --no-cost-annotation` (or just `bash scripts/engine/intensity-recommend.sh --description "<canonical sample>"` and take only the first 8 lines). Capture stdout.
    - Extract the first 8 lines of stdout. Diff against the fixture. Failure if `diff` is non-zero.
    - Verifier setup creates `tests/fixtures/m027-p01/` directory if missing, then writes the canonical baseline. Subsequent runs read the file. Implementation discipline: the canonical baseline is hand-crafted with stable values (a description that produces deterministic analyze + profile output OR a description that goes through pre-computed `--analyze-output` and `--profile-output` strings to remove environmental variance from `detect-capabilities.sh`).
    - The most reliable approach: the verifier passes `--analyze-output "<inline-fixture>"` and `--profile-output "<inline-fixture>"` so that `intensity-recommend.sh`'s outputs are deterministic given fixed inputs (no fork to detect-capabilities).
    - Pass.

11. **`m027-p01-intensity-json-cost-estimates.sh`** (~60 lines):
    - Run `bash scripts/engine/intensity-recommend.sh --description "test" --format json` and capture stdout.
    - Assert exit 0.
    - Assert stdout is one line.
    - Use `python3 -c 'import json,sys;d=json.loads(sys.stdin.read());...` to validate the JSON parses and contains keys: `intensity`, `confidence`, `reasoning`, `scope`, `risk_level`, `complexity`, `risk_signals`, `cap_score`, `cost_estimates`. Inside `cost_estimates`, validate keys `quick`, `standard`, `full`. For each tier, validate inner keys `cost_usd`, `input_tokens`, `output_tokens`, `pricing_warning`. Validate `input_tokens` and `output_tokens` are integers; validate `cost_usd` is number-or-null; validate `pricing_warning` is string.
    - Pass.

12. **`m027-p01-read-only.sh`** (~50 lines):
    - Capture `git diff --quiet`'s exit status before the run. If non-zero (the working tree is already dirty — e.g., the developer is mid-edit), the verifier emits `WARN: working-tree-dirty pre-run; skipping read-only assertion` and exits 0. (This avoids false-positive failures during interactive development; CI runs against a clean tree.)
    - Else, run a sequence of read-only invocations:
      - `bash scripts/engine/cost-estimate.sh --description "test" >/dev/null`
      - `bash scripts/engine/intensity-recommend.sh --description "test" >/dev/null`
      - `bash scripts/engine/intensity-recommend.sh --description "test" --format json >/dev/null`
      - `bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019 >/dev/null`
    - Re-run `git diff --quiet`. Failure if exit non-zero.
    - Pass.

13. **`m027-p01-runtime-adapter-registration.sh`** (~70 lines):
    - For each adapter script `scripts/dispatch/adapters/runtime/{claude-code,codex,cursor}.sh`:
      - Run `bash <adapter> --register --dry-run` (under HOME redirect to a mktemp directory if the adapter writes to HOME — but `--dry-run` is meant to write nothing).
      - Implementation: set `HOME` to a mktemp dir to be safe: `tmphome=$(mktemp -d); HOME="$tmphome" bash <adapter> --register --dry-run`.
      - Capture stdout. Assert it contains `would_write=` followed by a path ending in `orchestrator-cost.md`.
    - Failure if any of the three adapters does not list `orchestrator-cost.md`.
    - Pass.

14. **`m027-p01-bash32-compat.sh`** (~60 lines):
    - For each file in: `scripts/engine/cost-estimate.sh`, `scripts/engine/intensity-recommend.sh`, every `scripts/verify/m027-p01-*.sh`, `commands/cost.md`, `packaging/bundle/skills/orchestrator-cost.md`.
    - For each file, `grep -nE` against the forbidden-construct regex: `(declare -A|mapfile|readarray|<<<|<\(|>\(|&>|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^}|\$\{[a-zA-Z_][a-zA-Z0-9_]*,,})`. Failure if any match (excluding the verifier file itself, which contains the regex literal — exclude self via explicit file list, not glob).
    - The markdown files `commands/cost.md` and `packaging/bundle/skills/orchestrator-cost.md` MAY contain forbidden tokens inside fenced code blocks documenting examples; implementation discipline says they should NOT, since the documentation is consumed by both human readers and grep-based lints. If a code block legitimately needs to show a forbidden construct (e.g., warning against use of `<<<`), use the literal escaped form `\<\<\<` — but the simpler discipline is "do not include forbidden constructs in the markdown body."
    - Pass.

15. **`chmod +x`** all 13 new scripts (`m027-p01-suite.sh` + 12 per-contract verifiers).

## Must-Haves

- File `scripts/verify/m027-p01-suite.sh` exists, ≥ 30 lines, contains the literal string `m027-p01`.
- Files `scripts/verify/m027-p01-*.sh` exist for each of the 12 per-contract verifiers (see Phase Plan Artifacts list).
- Running `bash scripts/verify/m027-p01-suite.sh` from the project root exits 0 against the post-P01 codebase.
- Each per-contract verifier exits 0 in isolation against the post-P01 codebase.
- Verifiers are bash 3.2 compatible (the bash32-compat verifier scans them).

## Verification

```bash
bash scripts/verify/m027-p01-suite.sh
```

The above must exit 0 and emit `PASS: m027-p01-suite.sh 12 gates` on stdout. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P01` also runs at the phase boundary; it auto-discovers the 12 Truth `Check:` commands from the phase plan and re-runs them. Both should be green.

## Inputs

### From Previous Tasks

- T01: `scripts/engine/cost-estimate.sh` — invoked by 5 verifiers (cost-estimate-table, predictive-goodhart-pairing, predictive-latency, pricing-degradation, read-only). Library functions exposed: `cost_estimate_per_tier`, `cost_estimate_recommend`, `cost_estimate_resolve_model`. Module variable `_CE_RECOMMENDED` for skipping inner re-fork.
- T02: modified `scripts/engine/intensity-recommend.sh` — invoked by 3 verifiers (intensity-text-back-compat, intensity-json-cost-estimates, pricing-degradation). New flags: `--format text|json`, `--no-cost-annotation`. JSON output shape per D026.
- T03: `commands/cost.md` (≥80 lines, MEM012 shape, D027 disclaimer), `packaging/bundle/skills/orchestrator-cost.md`, `packaging/bundle/manifest.yml` (with `orchestrator-cost.md` in skills list).

### From Disk (Pre-existing)

- `scripts/diagnostics/metrics-rollup.sh` (P00) — invoked by `cost-retro-default.sh` and `read-only.sh` smoke-tests.
- `scripts/dispatch/adapters/runtime/{claude-code,codex,cursor}.sh` — invoked by `runtime-adapter-registration.sh` with `--register --dry-run` under a redirected HOME.
- `scripts/verify/m027-rollup-schema.sh` (P00) — reference for the phase-suite orchestrator shape.
- `python3` — standard on macOS; used by JSON-shape verifiers. Fallback to grep-regex if python3 is unavailable.
- `perl -MTime::HiRes` — standard on macOS; used by latency verifier for sub-second timing.
- `tests/fixtures/m027-p01/` — directory created by `intensity-text-back-compat.sh` setup (or hand-shipped). Contains the canonical baseline text fixture.

## Constraints

- **CON-1 / FR-12 (read-only)**: Verifiers themselves are read-only. They MAY create temp files under `${TMPDIR:-/tmp}/` but never write to the project tree. The `read-only.sh` verifier explicitly asserts `git diff --quiet` post-invocation.
- **CON-7 (bash 3.2)**: Every verifier passes the bash32-compat scan. No `declare -A`, no `<<<`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`.
- **AD-19 (single-script-file Check shape)**: The phase plan's 12 Truths each have a single-script-file `Check:` invoking these verifiers. Each verifier internally MAY use pipes / `$()` / `awk` (MEM004 emitter-internal carve-out).
- **CON-9 / FR-22 / SC-15 (latency)**: The `predictive-latency.sh` verifier hard-fails at 250 ms (100 ms target + 150 ms CI slack) and soft-warns above 100 ms. RELAX-CANDIDATE annotation pattern mirrors P00 perf verifier.
- **D026 (JSON shape)**: The `intensity-json-cost-estimates.sh` verifier asserts the verbatim D026 contract — `cost_estimates` keyed by `quick`/`standard`/`full`; per-tier `cost_usd` (number-or-null), `input_tokens` (int), `output_tokens` (int), `pricing_warning` (string).
- **D027 (disclaimer copy)**: The `cost-command-shape.sh` verifier asserts the verbatim disclaimer string. The `cost-estimate-table.sh` verifier asserts the verbatim trailer string.

## Expected Output

After this task:

1. 13 new scripts under `scripts/verify/` (1 suite orchestrator + 12 per-contract verifiers), each ≥ 30 lines, executable.
2. Running `bash scripts/verify/m027-p01-suite.sh` exits 0 and emits `PASS: m027-p01-suite.sh 12 gates` on stdout.
3. Running each per-contract verifier in isolation exits 0 against the post-P01 codebase.
4. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P01` exits 0 (auto-discovers and re-runs the 12 Truth `Check:` commands from `P01-PLAN.md`).
5. `git diff --quiet` after running the suite is exit 0 — verifiers are read-only.
