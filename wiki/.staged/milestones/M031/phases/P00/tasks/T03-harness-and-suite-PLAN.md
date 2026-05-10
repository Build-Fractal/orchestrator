---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P00"
milestone: "M031"
name: "Empirical-baseline harness + ordering verifier + pre-baseline JSONL capture + phase suite"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: spec.md carries the folded AD-1..AD-20 + renumbered SC-13 / SC-14 / SC-15 (verified by `tools/verify/p00-spec-foldin-shape.sh` exit 0).
- T02 complete: 20-task corpus + CORPUS-MANIFEST.md + pre-m031-stub.sh + RUNTIME-ASSUMPTIONS appended + three new config knobs (verified by all five T02 verifiers exit 0).
- `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh` is executable; T03 invokes it 20 times to populate the pre-M031 baseline JSONL.
- `tools/verify/` directory exists with T01 + T02 verifiers; T03 adds the remaining four (`p00-baseline-harness-shape.sh`, `p00-ordering-verifier-shape.sh`, `p00-pre-baseline-jsonl-population.sh`, `p00-phase-suite.sh`).
- Repo is a git repository with a working `git log` invocation. T03 selects between AD-12 Option A (protocol note) and Option B (git-history check) based on `git log` availability against the corpus paths.

## Description

Ship the FR-18 `empirical-baseline.sh` harness (iterates the 20-task corpus + invokes the pre-M031 stub once per task + appends to `pre-m031-baseline.jsonl`), the AD-12 / SC-13 ordering verifier `verify-baseline-ordering.sh` (Option B preferred, Option A fallback), capture the 20-record pre-M031 baseline JSONL by running the harness once, decide and record SC-13 Option A vs B in `SC13-OPTION.md`, and ship the `p00-phase-suite.sh` aggregator that invokes all eight P00 gates plus this task's own verifiers.

Critical AD-14 invariant (T03's responsibility): the JSONL capture happens at T03-close, BEFORE P01's first commit modifies `commands/dispatch.md:21` or `scripts/dispatch/build-context.sh`. The harness writes `pre-m031-baseline.jsonl` once; the file is git-committed and never regenerated. P01's first task captures the post-M031 records into a sibling `post-m031-baseline.jsonl`; the SC-11 comparison runs at P04 acceptance battery aggregation.

The harness's `--post-m031-emitter <path>` flag is a deliberate seam: at T03-close, the emitter doesn't exist (no path argument supplied), so the harness emits a "post-M031 capture pending" notice and exits 0 after the pre-M031 sweep. P01's first task supplies a real emitter path (the wrapper that invokes `build-context.sh --profile=quick` against each fixture and records the resulting `payload_breakdown` JSONL); at that point the harness emits both record sets in a single invocation, satisfying the AD-14 single-window requirement (both capture paths run while both code paths are live, then FR-4 collapses the skip branch).

## Steps

1. **Author `tests/m031-acceptance/empirical-baseline.sh`.** Bash 3.2-compatible, executable. Behavior:
   - CLI:
     - `--corpus-dir <path>` — default `tests/m031-acceptance/fixtures/empirical-baseline/`.
     - `--pre-m031-emitter <path>` — default `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh`.
     - `--post-m031-emitter <path>` — default empty (no post-M031 capture at T03-close).
     - `--out-pre <path>` — default `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl`.
     - `--out-post <path>` — default `tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl` (only written if `--post-m031-emitter` is non-empty).
     - `--compare` — when present, reads BOTH JSONL files and emits the SC-11 comparison verdict on stdout.
   - Behavior in capture mode (no `--compare`):
     - Truncate `--out-pre`. For each `task-NN.txt` in `--corpus-dir` (sorted): invoke `--pre-m031-emitter <task-path>` and append the emitted JSONL line to `--out-pre`.
     - If `--post-m031-emitter` is non-empty: truncate `--out-post`, iterate the same corpus invoking the post emitter, append to `--out-post`.
     - If `--post-m031-emitter` is empty: emit "POST-M031 CAPTURE PENDING — supply --post-m031-emitter at P01 first task" on stderr and exit 0 anyway (pre-baseline capture is the T03 deliverable; post-baseline waits for P01).
     - Final stdout line: `BASELINE: pre=20 post=<N|pending>` where `<N>` is the post-emitter record count, `pending` if the emitter was empty.
     - Exit 0 on clean capture; exit 1 if any emitter invocation fails (non-zero exit from stub) or if the pre-record count is not exactly 20.
   - Behavior in compare mode (`--compare`):
     - Read `--out-pre` and `--out-post`. Both must exist with ≥20 records each; if not, emit `COMPARE: insufficient data` on stderr, exit 1.
     - Compute median `total_task_tokens` across each set. Compute pass-rate (`verifier_pass: true` count / total) across each set.
     - Emit on stdout: `COMPARE: pre_median_tokens=<int> post_median_tokens=<int> pre_pass_rate=<float> post_pass_rate=<float> verdict=<wins|loses|inconclusive>`.
     - Verdict: `wins` if `post_median_tokens < pre_median_tokens` AND `post_pass_rate >= pre_pass_rate`. `loses` if either condition fails. `inconclusive` if pre/post record counts diverge.
     - Exit 0 on `wins`, exit 1 otherwise.
   - File header documents:
     - FR-18 ownership of the harness.
     - AD-14 single-window discipline (capture happens AT T03-close, BEFORE P01 modifications).
     - SC-11 comparison contract.

2. **Author `tests/m031-acceptance/verify-baseline-ordering.sh`.** Bash 3.2-compatible, executable. Behavior:
   - CLI:
     - `--corpus-path <path>` — default `tests/m031-acceptance/fixtures/empirical-baseline/`.
     - `--protected-paths <csv>` — default `scripts/dispatch/build-context.sh,commands/dispatch.md`. These are the files whose first-modification commit MUST POSTDATE the corpus first-commit per AD-14.
   - Option detection: try `git log -1 --format=%ct -- "$corpus_path"` and check exit + non-empty stdout. If both, Option B is available.
     - **Option B (preferred)**: For each protected path, get the first commit touching that path (`git log --diff-filter=AM --reverse --format=%ct --follow -- "$path" | head -n 1`) and the corpus first commit. Assert `corpus_first_commit_ct < protected_first_commit_ct` for each protected path. Pass on all-asserts-hold; fail with diagnostic per failure.
     - **Option A (fallback)**: If `git log` is unavailable or returns empty, the verifier exits 0 with stdout `OPTION-A: SC-13 reclassifies as P00 protocol note; ordering enforcement deferred to AD-14 manual review.` The N adjustment in SC-14 (`N ≥ 14` instead of `N ≥ 15`) takes effect; the operator records the option in `SC13-OPTION.md`.
   - Output: `ORDERING: option=<A|B> verdict=<pass|fail|protocol-note>`.
   - Exit 0 on pass or protocol-note; exit 1 on fail.

3. **Decide and record SC-13 option.** Run `verify-baseline-ordering.sh` once at T03 plan time to detect `git log` availability. Author `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md` capturing the verdict:

   ```markdown
   # SC-13 Option Selection

   AD-12 specifies two options for SC-13 (baseline-ordering enforcement):

   - **Option B (preferred)**: `verify-baseline-ordering.sh` asserts via `git log`
     that the first commit touching `tests/m031-acceptance/fixtures/empirical-baseline/`
     predates the first commit touching `scripts/dispatch/build-context.sh` and
     `commands/dispatch.md`. SC-13 stays in SC-14's count; `N ≥ 15`.

   - **Option A (fallback)**: when `git log` is unavailable (shallow clone, etc.),
     SC-13 reclassifies as a P00 protocol note. Drops from SC-14's count; `N ≥ 14`.

   ## Selected: Option <A|B>

   <reasoning — based on observed `git log` availability against the corpus path
   and protected paths during T03 execution>

   ## Effective N for SC-14: <14|15>
   ```

   The executor fills the `<A|B>` and `<14|15>` based on the actual T03 environment.

4. **Capture the pre-M031 baseline JSONL.** Run the harness once to populate `pre-m031-baseline.jsonl`:

   ```bash
   bash tests/m031-acceptance/empirical-baseline.sh
   ```

   Expected: 20 JSONL lines emitted to `pre-m031-baseline.jsonl`, stderr message "POST-M031 CAPTURE PENDING — supply --post-m031-emitter at P01 first task", final stdout `BASELINE: pre=20 post=pending`, exit 0.

   Confirm the file exists and has 20 lines. Commit the file alongside the harness — this is the AD-14 frozen capture.

5. **Author `tools/verify/p00-baseline-harness-shape.sh`.** Bash 3.2. Behavior:
   - Path default: `tests/m031-acceptance/empirical-baseline.sh`.
   - Check 1: file exists + executable.
   - Check 2: declares the FR-18 contract — header comment names FR-18.
   - Check 3: declares the AD-14 single-window discipline — header comment names AD-14.
   - Check 4: supports the `--post-m031-emitter` CLI flag — body contains the literal `--post-m031-emitter`.
   - Check 5: supports the `--compare` mode — body contains `--compare` and emits the `COMPARE:` line shape.
   - Check 6: invokable in capture mode against the corpus — `bash "$file"` exits 0 and produces a `BASELINE:` line on stdout.
   - On pass, emit `SUMMARY: p00-baseline-harness-shape.sh pass=6 fail=0`, exit 0.

6. **Author `tools/verify/p00-ordering-verifier-shape.sh`.** Bash 3.2. Behavior:
   - Path default: `tests/m031-acceptance/verify-baseline-ordering.sh`.
   - Check 1: file exists + executable.
   - Check 2: declares AD-12 in header.
   - Check 3: implements both Option A and Option B — body contains both `Option A` and `Option B` text.
   - Check 4: invokable, exits 0 (pass under Option B or protocol-note under Option A).
   - Check 5: `SC13-OPTION.md` exists and records the selected option (`A` or `B`).
   - On pass, emit `SUMMARY: p00-ordering-verifier-shape.sh pass=5 fail=0`, exit 0.

7. **Author `tools/verify/p00-pre-baseline-jsonl-population.sh`.** Bash 3.2. Behavior:
   - Path default: `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl`.
   - Check 1: file exists.
   - Check 2: line count is exactly 20. Use `wc -l` against the file (no `$()` containing pipe).
   - Check 3: every line contains `"path":"pre-m031"` (proves stub provenance — no live dispatch records leaked into the frozen baseline). Use a per-line `grep -q` loop with a `while read` against the file (single-script-file shape, no process substitution).
   - Check 4: every line contains `"knowledge_section_tokens":0` (pre-M031 by definition injects zero knowledge).
   - On pass, emit `SUMMARY: p00-pre-baseline-jsonl-population.sh pass=4 fail=0`, exit 0.

8. **Author `tools/verify/p00-phase-suite.sh`.** Bash 3.2. Behavior:
   - No CLI flags. Invoked from repo root.
   - Invokes the eight P00 sub-gates in sequence:
     1. `bash tools/verify/p00-spec-foldin-shape.sh`
     2. `bash tools/verify/p00-corpus-manifest-shape.sh`
     3. `bash tools/verify/p00-corpus-population.sh`
     4. `bash tools/verify/p00-pre-stub-shape.sh`
     5. `bash tools/verify/p00-runtime-assumptions-foldin.sh`
     6. `bash tools/verify/p00-config-defaults-pinned.sh`
     7. `bash tools/verify/p00-baseline-harness-shape.sh`
     8. `bash tools/verify/p00-ordering-verifier-shape.sh`
     9. `bash tools/verify/p00-pre-baseline-jsonl-population.sh`
   - For each: capture exit code; tally pass/fail. Emit a per-gate `OK:` or `FAIL:` line.
   - Final emission: `SUMMARY: p00-phase-suite.sh pass=N fail=M` where N is the pass count, M the fail count. Exit 0 iff every sub-gate passed.
   - File header names the M031 P00 phase and lists the nine gates.

9. **Run the phase suite as a final self-check.** From repo root:

   ```bash
   bash tools/verify/p00-phase-suite.sh
   ```

   Expected: `SUMMARY: p00-phase-suite.sh pass=9 fail=0`, exit 0. If any gate fails, address the underlying T01/T02/T03 deliverable and re-run.

## Must-Haves

This task satisfies the phase truths:
- "empirical-baseline.sh exists [...] iterates the 20 corpus tasks, runs `pre-m031-stub.sh` against each, appends one JSONL record per task to `pre-m031-baseline.jsonl`".
- "verify-baseline-ordering.sh exists per AD-12 / SC-13 [...] prefers Option B, falls back to Option A".
- "pre-m031-baseline.jsonl exists with exactly 20 JSONL records [...] AD-14 single-window capture".
- "p00-phase-suite.sh invokes all eight P00 gates [...] emits `SUMMARY: p00-phase-suite.sh pass=N fail=M`".

T03 closes P00 by emitting the `SUMMARY: pass=9 fail=0` aggregate.

## Verification

```bash
bash tools/verify/p00-baseline-harness-shape.sh
bash tools/verify/p00-ordering-verifier-shape.sh
bash tools/verify/p00-pre-baseline-jsonl-population.sh
bash tools/verify/p00-phase-suite.sh
```

Each verifier uses single-script-file shape per AD-19. Each emits `SUMMARY: <script> pass=N fail=0` and exits 0 on green. The phase suite's exit 0 closes P00.

## Inputs

### From Previous Tasks

- `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh` (from T02)
  - Key API: `bash pre-m031-stub.sh <task-NN.txt>` emits one JSONL line on stdout matching `{"task_id":"task-NN","path":"pre-m031","knowledge_section_tokens":0,"compression_applied":false,"snip_applied":false,"total_task_tokens":<int>,"verifier_pass":true}`.
  - Key types: pre-M031 JSONL record schema; the harness reads this exact shape.
- `tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md` (from T02)
  - Key API: declares the 20-entry corpus with `task_id` ↔ `task-NN.txt` mapping; the harness iterates these.
- `tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt` through `task-20.txt` (from T02)
  - Key API: each fixture parseable by `pre-m031-stub.sh`; the harness invokes the stub once per fixture.
- T01 + T02 verifiers under `tools/verify/p00-*.sh` — invoked by `p00-phase-suite.sh`.

### From Disk (Pre-existing)

- Git repository at repo root with `.git/` directory; `git log` invocations succeed under Option B.
- `commands/dispatch.md` and `scripts/dispatch/build-context.sh` — protected paths whose first-modification commit MUST postdate the corpus first-commit per AD-14. T03 verifies via `verify-baseline-ordering.sh` Option B (or records Option A fallback).

## Constraints

- **AD-14 single-window discipline**: T03 captures `pre-m031-baseline.jsonl` BEFORE P01 modifies any protected path. The capture is one-shot; subsequent runs against an already-populated file MUST be idempotent (re-capture writes the same content). The harness truncates `--out-pre` on each capture-mode invocation; idempotency holds because the stub is deterministic.
- **`pre-m031-baseline.jsonl` is git-committed**: the file ships at T03-close as a frozen artifact. P04 acceptance battery's SC-11 reads it directly; P01 first-task's post-M031 capture writes a sibling file.
- **Bash 3.2 compatibility**: harness + ordering verifier + four new verifiers all avoid `mapfile`, `declare -A`, process substitution.
- **Single-script-file Truth Check shape (AD-19)**: every `Check:` invokes `bash tools/verify/<name>.sh` with no inline pipes / subshells / heredocs.
- **No P01 / P02 / P03 / P04 surface modifications**: T03 must not touch `scripts/dispatch/build-context.sh`, `commands/dispatch.md`, `commands/evaluate.md`, `references/tier-definitions.md`, or any file outside `tests/m031-acceptance/` and `tools/verify/`. SC-12 scope-guard at P04 will assert this against the M031 cumulative diff.
- **`p00-phase-suite.sh` aggregates ALL P00 gates from T01 + T02 + T03**: future maintainers extending P00 with additional gates MUST add the new verifier to the suite's gate list and update the expected `SUMMARY: pass=N` count in this task plan's expected output.
- **D020 token hygiene (CON-7)**: in harness comments and verifier scripts, paraphrase scaffold-placeholder strings rather than embedding the literal pattern.

## Expected Output

- `tests/m031-acceptance/empirical-baseline.sh` — ≥50 lines, executable, supports capture + `--compare` modes.
- `tests/m031-acceptance/verify-baseline-ordering.sh` — ≥40 lines, executable, supports Option A + B.
- `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl` — exactly 20 lines, each a valid pre-M031 JSONL record.
- `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md` — ≥15 lines, records Option A or B selection with reasoning.
- `tools/verify/p00-baseline-harness-shape.sh` — ≥30 lines.
- `tools/verify/p00-ordering-verifier-shape.sh` — ≥30 lines.
- `tools/verify/p00-pre-baseline-jsonl-population.sh` — ≥25 lines.
- `tools/verify/p00-phase-suite.sh` — ≥35 lines, invokes nine sub-gates, emits final `SUMMARY` line.
- `bash tools/verify/p00-phase-suite.sh` exits 0 with `SUMMARY: p00-phase-suite.sh pass=9 fail=0`.

## Notes

Expected verifier output examples (for human readers):
- `bash tests/m031-acceptance/empirical-baseline.sh` → stderr `POST-M031 CAPTURE PENDING — supply --post-m031-emitter at P01 first task`; stdout `BASELINE: pre=20 post=pending`; exit 0.
- `bash tests/m031-acceptance/verify-baseline-ordering.sh` → stdout `ORDERING: option=B verdict=pass` (or `option=A verdict=protocol-note` under fallback); exit 0.
- `bash tools/verify/p00-baseline-harness-shape.sh` → `SUMMARY: p00-baseline-harness-shape.sh pass=6 fail=0`, exit 0.
- `bash tools/verify/p00-ordering-verifier-shape.sh` → `SUMMARY: p00-ordering-verifier-shape.sh pass=5 fail=0`, exit 0.
- `bash tools/verify/p00-pre-baseline-jsonl-population.sh` → `SUMMARY: p00-pre-baseline-jsonl-population.sh pass=4 fail=0`, exit 0.
- `bash tools/verify/p00-phase-suite.sh` → per-gate `OK:` lines + `SUMMARY: p00-phase-suite.sh pass=9 fail=0`, exit 0.

The `--post-m031-emitter` seam is intentional: P01 first task plugs in an emitter that runs each fixture through the soon-to-merge `build-context.sh --profile=quick` and records the resulting `payload_breakdown` JSONL. That capture happens DURING P01's first commit cycle — both code paths are live (the FR-4 skip-removal hasn't merged yet but the FR-2 `--profile` flag exists), satisfying AD-14's "simultaneously while both code paths are live" requirement. After P01 first task lands, the harness's `--compare` mode produces the SC-11 verdict; P04 acceptance battery aggregator runs `--compare` as part of its battery sweep.

The harness MUST NOT regenerate `pre-m031-baseline.jsonl` post-T03; the file is the AD-14 frozen capture. If a maintainer truncates and re-runs the harness post-FR-4, the stub-emitted records remain semantically pre-M031 (the stub never calls `build-context.sh`), but git history will show the corpus-first-commit-vs-build-context-first-commit ordering already established at T03 close — Option B's verdict remains stable.
