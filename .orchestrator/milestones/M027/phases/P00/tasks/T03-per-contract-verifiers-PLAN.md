---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P00"
milestone: "M027"
name: "per-contract verifier scripts (m027-p00-*.sh)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 has shipped `scripts/diagnostics/metrics-rollup.sh` with the documented CLI surface and library functions.
- T02 has shipped the fixture suite under `tests/fixtures/m027-p00/`.
- The repository convention for verifier scripts is established by `scripts/verify/m019-p01-*.sh`. Each verifier:
  - Has `#!/usr/bin/env bash` and `set -u`.
  - Prints `PASS: <verifier-name> <details>` to stdout on green.
  - Prints `FAIL: <verifier-name> <reason>` to stderr on red.
  - Exits 0 on green, 1 on red, 2 on misuse / missing inputs.

## Description

Write fourteen per-contract verifier scripts under `scripts/verify/m027-p00-*.sh`. Each verifier exercises one specific contract from the P00 must-haves against the fixtures (T02) using the engine (T01). Each verifier is a single-script-file invocation (so it can be referenced as a `Check:` command from the phase plan, AD-19 compliant). Internally each verifier may use pipes / `$()` / `awk` (MEM004 carve-out for emitter-internal code).

## Steps

For each verifier, follow the same skeleton: locate `PROJECT_ROOT` via `BASH_SOURCE`, set `ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"` and `FIX="$PROJECT_ROOT/tests/fixtures/m027-p00"`, run a fixture-driven invocation, assert the contract, emit `PASS:` / `FAIL:`.

1. **`scripts/verify/m027-p00-rollup-cli-contract.sh`** (FR-1, FR-2, FR-3): Run `bash $ROLLUP --help`; assert exit 0 and stdout contains all of: `--granularity`, `--milestone`, `--phase`, `--task`, `--source`, `--log`. Run `bash $ROLLUP --bogus-flag`; assert exit code 2.

2. **`scripts/verify/m027-p00-live-m019-row.sh`** (FR-1, FR-4, SC-1): Run `bash $ROLLUP --granularity milestone --milestone M019` against the live `.orchestrator/milestones/M019/execution-log.jsonl`. Assert exit 0. Assert stdout contains exactly one milestone-row line (greppable header detection or column-count). Assert that line carries both a cost token (numeric `EST_COST_USD` value or `(N missing)`) AND a quality token (numeric `PASS_RATE` value). If the live log is missing or empty, this verifier emits `SKIP: live M019 log not present` to stdout and exits 0 (graceful for fresh clones; the fixture-based verifiers cover the contract).

3. **`scripts/verify/m027-p00-goodhart-pairing.sh`** (FR-4, SC-12): For each granularity in `{task, phase, milestone}`, run the rollup against `mixed-source-aggregate.jsonl`. For each output row, assert that if the row contains a cost column it also contains a quality column. Implementation: run rollup, capture stdout, awk over each row asserting both column-positions are non-empty. If any cost-only row found, FAIL.

4. **`scripts/verify/m027-p00-source-filter.sh`** (FR-3, SC-6): Run rollup with `--source runtime` against `estimate-only.jsonl`; assert stdout contains "no records match filter" and exit 0. Run with `--source estimate`; assert non-empty paired row, exit 0. Run with `--source all`; assert same count as `--source estimate`. Run with `--source bogus`; assert exit 2.

5. **`scripts/verify/m027-p00-aggregation-precedence.sh`** (FR-18, AD-1, SC-14): Run rollup `--granularity phase --milestone M999` against `mixed-source-aggregate.jsonl`; assert the cost cell equals the aggregate-row value (0.50), NOT the aggregate+children sum (0.80). Run `--granularity task --milestone M999`; assert the cost cells sum to 0.30 (children visible at their own granularity, aggregate row not double-applied).

6. **`scripts/verify/m027-p00-read-only.sh`** (FR-12, SC-9): Capture `git status --porcelain` BEFORE running the rollup against every fixture. Run rollup `--granularity milestone --milestone M999 --log <each-fixture>` for each fixture in turn. Capture `git status --porcelain` AFTER. Assert byte-identical (no new modifications). Also assert no new files appeared under `.orchestrator/milestones/`.

7. **`scripts/verify/m027-p00-zero-llm-token.sh`** (FR-21, CON-6, SC-16 carry-forward): grep the M027 P00 script set (`scripts/diagnostics/metrics-rollup.sh` + `scripts/verify/m027-*.sh`) for forbidden patterns: `claude_chat`, `anthropic`, `dispatch-interface\.sh`, `dispatch_task`, `subagent`. Any match → FAIL with the matching file and line.

8. **`scripts/verify/m027-p00-corrupt-line.sh`** (FR-14, SC-5): Run rollup `--granularity task --milestone M999 --log $FIX/corrupt-line.jsonl`. Assert exit 0. Assert stderr contains exactly one WARN line referencing line number 4 (the planted corrupt line). Assert the rollup aggregated 9 records (verifiable via dispatch-count or similar column).

9. **`scripts/verify/m027-p00-input-schema.sh`** (FR-17): Run rollup against `missing-fields.jsonl`. Assert exit 0. Assert stderr contains exactly 2 `WARN: input-schema` lines. Assert the rollup aggregated only the 6 valid records (not 8).

10. **`scripts/verify/m027-p00-pricing-warning.sh`** (FR-11): Run rollup against `pricing-warning.jsonl`. Assert stdout contains the substring `(2 missing)` somewhere on the cost cell of the relevant scope row.

11. **`scripts/verify/m027-p00-fs-race.sh`** (FR-13, FR-19, AD-3, SC-19): Build a temp working JSONL in `$(mktemp -d)`. Copy `corrupt-line.jsonl` content into it. Background a small bash one-liner (single-script-file shape — extract into the verifier itself, not as a Check) that sleeps 0.05 s, then truncates the source JSONL to zero bytes. Run rollup `--log <temp-jsonl>` synchronously in the foreground. Assert rollup exits 0 (the snapshot semantic protected it from the truncation). Cleanup the background pid, the temp dir.

12. **`scripts/verify/m027-p00-perf-bound.sh`** (CON-12, AD-2, SC-13): Invoke `bash $FIX/perf-10mb.jsonl.gen.sh /tmp/m027-perf.jsonl`. Assert the resulting file is ≥ 10 MB. Run rollup `--granularity milestone --log /tmp/m027-perf.jsonl` under a wall-clock timer. Assert wall-clock elapsed < 5 s. Cleanup `/tmp/m027-perf.jsonl`. **Bound-relaxation clause**: if the wall-clock time exceeds 5 s, the verifier prints a `FAIL` with the observed time AND a follow-up advisory `RELAX-CANDIDATE: <time>s observed against 10MB; consider relaxing CON-12 if architectural rework is required` so the operator has the data needed to decide whether to relax the bound (per the planning brief's "perf bound" note).

13. **`scripts/verify/m027-p00-pre-m019-additivity.sh`** (SC-10 carry-forward): Run rollup against `pre-m019-mixed.jsonl`. Assert exit 0. Assert no stderr WARN diagnostics for the 3 pre-M019 lines (those are silently ignored). Assert the rollup counted 3 records (the M019 ones), not 6.

14. **`scripts/verify/m027-p00-bash32-compat.sh`** (CON-7, SC-11): grep the P00 script set (`scripts/diagnostics/metrics-rollup.sh`, every `scripts/verify/m027-*.sh`, `tests/fixtures/m027-p00/perf-10mb.jsonl.gen.sh`) for forbidden constructs: `declare -A`, `mapfile`, `readarray`, `<<<`, `<\(`, `>\(`, `&>`, `\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^}`. Any match → FAIL with the matching file and line.

For each verifier: `chmod +x scripts/verify/m027-p00-*.sh`.

## Must-Haves

- Each of the 14 named verifier scripts exists, is executable, ≥ 30 lines.
- Each verifier emits a `PASS: <name>` line to stdout on green and exits 0.
- Each verifier emits a `FAIL: <name> <reason>` line to stderr on red and exits 1.
- Each verifier is bash 3.2 compatible (no associative arrays, no `<<<`, etc.).
- No verifier writes to `.orchestrator/milestones/`. T04's phase-suite verifier will run `git diff --quiet` post-suite as a final invariant.

## Verification

```bash
bash scripts/verify/m027-p00-rollup-cli-contract.sh
bash scripts/verify/m027-p00-live-m019-row.sh
bash scripts/verify/m027-p00-goodhart-pairing.sh
bash scripts/verify/m027-p00-source-filter.sh
bash scripts/verify/m027-p00-aggregation-precedence.sh
bash scripts/verify/m027-p00-read-only.sh
bash scripts/verify/m027-p00-zero-llm-token.sh
bash scripts/verify/m027-p00-corrupt-line.sh
bash scripts/verify/m027-p00-input-schema.sh
bash scripts/verify/m027-p00-pricing-warning.sh
bash scripts/verify/m027-p00-fs-race.sh
bash scripts/verify/m027-p00-perf-bound.sh
bash scripts/verify/m027-p00-pre-m019-additivity.sh
bash scripts/verify/m027-p00-bash32-compat.sh
```

Note: the phase-level `scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P00` runs at the phase boundary (T04 / phase-transition), not at task-V time — only this task's own deliverables run here.

## Inputs

### From Previous Tasks

- `scripts/diagnostics/metrics-rollup.sh` (from T01)
  - Key API: CLI flags `--granularity`, `--milestone`, `--phase`, `--task`, `--source`, `--log <path>`, `--help`. Library functions `metrics_rollup_snapshot`, `metrics_rollup_normalize`, `metrics_rollup_aggregate`, `metrics_rollup_render`.
  - Behavioral contract: read-only, exit 0 on degraded inputs, mktemp+cp snapshot, AD-1 precedence, FR-3 source-filter, FR-4 Goodhart pairing, FR-11 pricing-warning suffix, FR-14 corrupt-line tolerance, FR-17 input-schema validation.
- `tests/fixtures/m027-p00/*.jsonl` and `perf-10mb.jsonl.gen.sh` (from T02)
  - Each fixture maps to a single FR/SC contract; T03 verifiers consume them.

### From Disk (Pre-existing)

- `scripts/verify/m019-p01-*.sh` — convention reference for verifier shape (PASS/FAIL, exit codes, structured-output protocol).
- `.orchestrator/milestones/M019/execution-log.jsonl` — live demo target consumed by `m027-p00-live-m019-row.sh`.

## Constraints

- **AD-19 (script-file shape) applies at the phase plan `Check:` level only**. Each of these verifier files is a single-script-file invocation when referenced from the phase plan; internally, MEM004 emitter-internal carve-out permits pipes / `$()` / `awk`.
- **CON-7 (bash 3.2)**: every verifier in this task must itself pass the `m027-p00-bash32-compat.sh` gate. Self-application: `m027-p00-bash32-compat.sh` greps its own grep targets, including itself.
- **CON-1 / FR-12 (read-only)**: no verifier writes to `.orchestrator/milestones/`. All scratch state lives under `$(mktemp -d)`.
- **Hermeticity**: each verifier must be runnable from any cwd (use `BASH_SOURCE`-relative path resolution). Each verifier cleans up its own scratch state on exit (`trap 'rm -rf "$tmp"' EXIT`).
- **Deterministic**: each verifier produces byte-identical PASS output across invocations on the same codebase + fixtures.
- **Perf-bound relaxation channel**: `m027-p00-perf-bound.sh` supports relaxation per the planning brief — if the engine cannot meet 5 s without rework, it prints a structured `RELAX-CANDIDATE` advisory so plan-phase can revisit CON-12 with evidence.

## Expected Output

After this task:

1. Fourteen verifier scripts under `scripts/verify/m027-p00-*.sh`, each executable, ≥ 30 lines, bash 3.2 compatible, AD-19 single-script-file shape compatible (each is itself the script-file the phase plan's `Check:` lines invoke).
2. Each verifier exits 0 against the T01 engine + T02 fixtures.
3. `git diff --quiet` after running every verifier returns exit 0.
4. The full per-contract suite is ready to be orchestrated by T04's `scripts/verify/m027-rollup-schema.sh`.
