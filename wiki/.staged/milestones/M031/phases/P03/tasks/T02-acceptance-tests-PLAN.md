---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M031"
name: "SC-7 trivial-path acceptance test + SC-8 low-confidence prompt acceptance test + fixtures + shape verifiers"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `scripts/intake/do-entry.sh` exists, executable, ≥ 200 lines. Verify by `bash tools/verify/m031-p03-do-entry-shape.sh` exit 0.
- T01 complete: `commands/do.md` exists. Verify by `bash tools/verify/m031-p03-do-md-shape.sh` exit 0.
- T01 complete: the entry script's `run_tier_a_degenerate` function exists and the `--dispatch-stub` test seam invokes the stub with positional arguments `(branch, task, payload-path, sidecar-path)`.
- T01 complete: the entry script's `--no-prompt-mode <A|B|C>` flag bypasses the interactive `read` and applies the supplied selection. Verify by reading the script body.
- P02 complete: `scripts/intake/shape-detect.sh` emits `tier_a_plus` for the 30–80 word + zero structural marker band; `idea` for ≤10 word inputs; `paragraph` for the 11–29 + 81+ no-structural-marker bands (verify by spot-check).
- The P02 SC-6 stub at `tests/m031-acceptance/test-tier-a-plus-flow.sh` includes the canned dispatch stub (read for shape but do not modify).

## Description

T02 ships the two M031 P03 acceptance tests that exercise `scripts/intake/do-entry.sh` end-to-end via the `--dispatch-stub` seam, plus the fixtures the tests consume, plus two shape verifiers that gate the test files' contracts.

**SC-7 (trivial-path)** asserts that invoking the entry script against a trivial Tier A degenerate input (`fix typo in foo.md` — 4 words, classifier verdict `idea`/`high`) produces:
- exactly one stderr line matching `^doing: .* — knowledge: [0-9]+ MEMs / [0-9]+ tokens$` (FR-12);
- exactly one dispatch fired (counted by stub-log line count, equal to 1);
- the dispatch payload manifest at `<payload-path>` exists and is non-empty (knowledge injection observable);
- zero approval prompts in captured stderr (no `(y) ... (n) ... (c)` substring);
- exit code 0.

**SC-8 (low-confidence prompt)** asserts that invoking the entry script against a low-confidence input (a `paragraph`-shape input the classifier emits at `low` confidence — typically a 30-word borderline `tier_a_plus` band edge that the classifier emits as `tier_a_plus`/`low`, OR a `paragraph`/`low` input) produces:
- the explicit Tier A vs Tier B prompt rendered on stderr (literal substrings `Tier A` AND `Tier B` AND a `?` token);
- under `--no-prompt-mode A`, the captured `unit_close` record contains `chosen_shape:"A"` AND the entry then fires the Tier A degenerate fast-path (the stub log shows one dispatch);
- under `--no-prompt-mode B`, the captured `unit_close` record contains `chosen_shape:"B"` AND the entry reports passthrough to `orchestrator:specify` on stderr (no dispatch fires);
- exit code 0 in both sub-cases.

**Fixture decisions**:
1. `do-entry-stub.sh` — canned dispatch stub mirroring the P02 SC-6 stub shape. Receives positional `(branch, task, payload-path, sidecar-path)`. Appends one line to `${ORCH_DO_ENTRY_STUB_LOG:-/dev/null}` per invocation. Exit 0.
2. `do-entry-trivial-input.txt` — single short line (e.g., `fix typo in foo.md`) sized so the classifier emits `idea`/`high`. ≤ 10 words.
3. `do-entry-lowconf-input.txt` — input the classifier emits at `low` confidence. The shape-detect.sh body emits `low` at: (a) `idea` 8–10 word boundary, (b) `tier_a_plus` 30–32 or 78–80 word boundary, (c) `paragraph` 81+ word with structural-marker fall-through. The simplest deterministic choice: an 8-word input that hits the `idea` low-confidence band — e.g., `update default config flag to enable feature X today`. Verify the choice empirically before committing the fixture (run `bash scripts/intake/shape-detect.sh --input "<text>"` and confirm `shape_classification=low`).

**JSONL `unit_close` capture**: T01's entry script emits the low-confidence-prompt JSONL record to `${ORCH_DO_ENTRY_LOG:-.orchestrator/observability/dispatch-log.jsonl}`. The SC-8 test sets `ORCH_DO_ENTRY_LOG` to a per-test tmp path so the assertion reads only the records emitted in this test run.

**No edits to T01 deliverables in T02** — `do-entry.sh` and `commands/do.md` are byte-frozen post-T01.

## Steps

1. **Empirically derive the low-confidence fixture content.** Run shape-detect against several candidate inputs and pick one whose output is `shape_classification=low`:

   ```bash
   bash scripts/intake/shape-detect.sh --input "update default config flag to enable feature X today"
   bash scripts/intake/shape-detect.sh --input "fix several typos in the readme and changelog"
   bash scripts/intake/shape-detect.sh --input "a brief reminder about implementing a new feature"
   ```

   Pick the first candidate whose stdout contains `shape_classification=low`. Record the exact input text for fixture authoring.

2. **Author `tests/m031-acceptance/fixtures/do-entry-stub.sh`** (executable, bash 3.2). Contract:

   ```bash
   #!/usr/bin/env bash
   # Canned dispatch stub for M031/P03 SC-7 + SC-8 acceptance tests.
   # Usage: do-entry-stub.sh <branch> <task> <payload-path> <sidecar-path>
   #
   # Mirrors the P02 SC-6 stub shape. Logs one line per invocation to
   # ${ORCH_DO_ENTRY_STUB_LOG:-/dev/null} so the test can count dispatches.
   #
   # Bash 3.2 compatible.

   branch="${1:-unknown}"
   task="${2:-unknown}"
   payload="${3:-unknown}"
   sidecar="${4:-unknown}"

   _log="${ORCH_DO_ENTRY_STUB_LOG:-/dev/null}"
   printf 'stub-invocation: branch=%s task=%s payload=%s sidecar=%s\n' "$branch" "$task" "$payload" "$sidecar" >> "$_log"
   exit 0
   ```

3. **Author `tests/m031-acceptance/fixtures/do-entry-trivial-input.txt`** — a single line, ≤ 10 words, that classifier emits as `idea`/`high`. Suggested: `fix typo in foo.md`.

4. **Author `tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt`** — the input identified in step 1 (the one shape-detect emits as `low` confidence).

5. **Author `tests/m031-acceptance/test-universal-entry-trivial.sh`** (executable, bash 3.2, ≥ 60 lines). Contract:

   - Set up a per-test tmp scratch root (`mktemp -d`) and a per-test stub log path. Export `ORCH_DO_ENTRY_STUB_LOG=<tmp>/stub.log`.
   - Capture the entry script's stderr to a tmp file:

     ```bash
     bash scripts/intake/do-entry.sh \
       --task "$(cat tests/m031-acceptance/fixtures/do-entry-trivial-input.txt)" \
       --dispatch-stub tests/m031-acceptance/fixtures/do-entry-stub.sh \
       --scratch-root "$tmp_scratch" \
       2> "$tmp_stderr"
     rc=$?
     ```

   - Assertions:
     - `rc == 0`.
     - `tmp_stderr` contains exactly one line matching `^doing: .* — knowledge: [0-9]+ MEMs / [0-9]+ tokens$` (verify with `grep -cE` returning `1`).
     - `tmp_stderr` does NOT contain `(y) ... (n) ... (c)` (zero approval prompts; verify with `grep -c '(y)'` returning `0`).
     - The stub log file contains exactly one line starting with `stub-invocation: branch=tier_a_degenerate ` (verify with `grep -c '^stub-invocation: branch=tier_a_degenerate '` returning `1`).
   - Output: `RESULT: SC-7 pass` on success or `RESULT: SC-7 fail: <diagnostic>` on failure. Exit 0 iff pass.
   - Required literal substrings in the test body for the shape verifier: `SC-7`, `doing:`, `MEMs`, `tokens`, `do-entry.sh`.

6. **Author `tests/m031-acceptance/test-universal-entry-lowconf.sh`** (executable, bash 3.2, ≥ 60 lines). Contract:

   - Set up a per-test tmp scratch root, a per-test stub log path, AND a per-test JSONL log path. Export `ORCH_DO_ENTRY_LOG=<tmp>/dispatch-log.jsonl` and `ORCH_DO_ENTRY_STUB_LOG=<tmp>/stub.log`.
   - **Sub-case A** — operator selects A in the prompt:

     ```bash
     bash scripts/intake/do-entry.sh \
       --task "$(cat tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt)" \
       --no-prompt-mode A \
       --dispatch-stub tests/m031-acceptance/fixtures/do-entry-stub.sh \
       --scratch-root "$tmp_scratch_a" \
       2> "$tmp_stderr_a"
     rc_a=$?
     ```

     Assertions:
     - `rc_a == 0`.
     - `tmp_stderr_a` contains the literal substrings `Tier A` AND `Tier B` AND `?`.
     - `<tmp>/dispatch-log.jsonl` contains the literal substring `"chosen_shape":"A"` (verify with `grep -c` returning `1`).
     - `<tmp>/stub.log` contains exactly one line starting with `stub-invocation: branch=tier_a_degenerate ` (verify with `grep -c` returning `1`) — sub-case A fires the fast-path after the prompt.

   - **Sub-case B** — operator selects B in the prompt. Reset the scratch root + JSONL log + stub log to a fresh tmp. Repeat with `--no-prompt-mode B`.

     Assertions:
     - `rc_b == 0`.
     - `tmp_stderr_b` contains `route=tier_bc` AND `passthrough=orchestrator:specify`.
     - `<tmp_b>/dispatch-log.jsonl` contains `"chosen_shape":"B"`.
     - `<tmp_b>/stub.log` is empty (zero dispatches fire on the Tier B/C passthrough branch — `wc -l` returning `0`).

   - Output: `RESULT: SC-8 pass` on success or `RESULT: SC-8 fail: <diagnostic>` on failure. Exit 0 iff both sub-cases pass.
   - Required literal substrings in the test body for the shape verifier: `SC-8`, `Tier A`, `Tier B`, `chosen_shape`, `do-entry.sh`.

7. **Author `tools/verify/m031-p03-test-universal-entry-trivial-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `tests/m031-acceptance/test-universal-entry-trivial.sh` exists, executable.
   - Assert the test contains literal substrings: `SC-7`, `doing:`, `MEMs`, `tokens`, `do-entry.sh`.
   - Assert the test does NOT invoke `orchestrator:auto`, `orchestrator:roadmap`, or `orchestrator:consolidate` (CON-4 invariant).
   - Output: a single final stdout line `SUMMARY: m031-p03-test-universal-entry-trivial-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

8. **Author `tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `tests/m031-acceptance/test-universal-entry-lowconf.sh` exists, executable.
   - Assert the test contains literal substrings: `SC-8`, `Tier A`, `Tier B`, `chosen_shape`, `do-entry.sh`, `--no-prompt-mode`.
   - Assert the test does NOT invoke `orchestrator:auto`, `orchestrator:roadmap`, or `orchestrator:consolidate` (CON-4 invariant).
   - Output: a single final stdout line `SUMMARY: m031-p03-test-universal-entry-lowconf-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

9. **Run the two acceptance tests + two shape verifiers locally** to confirm exit 0:

   ```bash
   bash tests/m031-acceptance/test-universal-entry-trivial.sh
   bash tests/m031-acceptance/test-universal-entry-lowconf.sh
   bash tools/verify/m031-p03-test-universal-entry-trivial-shape.sh
   bash tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh
   ```

10. **Verify no regression on the four T01 shape verifiers** (T02 must not edit T01 deliverables):

    ```bash
    bash tools/verify/m031-p03-do-md-shape.sh
    bash tools/verify/m031-p03-do-entry-shape.sh
    bash tools/verify/m031-p03-fastpath-shape.sh
    bash tools/verify/m031-p03-passthrough-shape.sh
    ```

## Must-Haves

This task addresses the following Must-Haves from `P03-PLAN.md`:
- "`tests/m031-acceptance/test-universal-entry-trivial.sh` (SC-7) exists, is executable, and exits 0" (Truth #5; Check via `m031-p03-test-universal-entry-trivial-shape.sh`)
- "`tests/m031-acceptance/test-universal-entry-lowconf.sh` (SC-8) exists, is executable, and exits 0" (Truth #6; Check via `m031-p03-test-universal-entry-lowconf-shape.sh`)

## Verification

```bash
bash tools/verify/m031-p03-test-universal-entry-trivial-shape.sh
```

```bash
bash tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh
```

```bash
bash tests/m031-acceptance/test-universal-entry-trivial.sh
```

```bash
bash tests/m031-acceptance/test-universal-entry-lowconf.sh
```

## Notes

- Each shape verifier MUST emit `SUMMARY: <script-name> pass=N fail=M` as its final stdout line — M031 P01/P02 convention.
- Each acceptance test MUST emit `RESULT: SC-N pass` / `RESULT: SC-N fail: <diagnostic>` — M031 P01/P02 convention for SC-* scripts.
- The fast-path's `build-context.sh --profile=quick --task-plan <inline-plan> --out <pl> --meta-out <sc>` invocation must succeed runtime against the T01-generated minimal task plan. If runtime exit is non-zero on a fresh project (no milestone tree), the SC-7 test may need to provide a slightly richer task-plan fixture inline OR the T01 entry script's inline plan generation may need a richer body. Resolve at SC-7 authoring time by adjusting the inline plan body T01 generates (e.g., adding a `## Steps` and `## Verification` section). Document the resolution inline in the SC-7 test header.
- D020 / CON-7: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- The two acceptance tests use independent tmp scratch roots + JSONL log paths (`mktemp -d`) so they do not race; cleanup via `trap 'rm -rf "$tmp_scratch_*"' EXIT`.
- **Real-app smoke test pending** (plan-time discipline rule 5): T02 verifies SC-7 / SC-8 via the `--dispatch-stub` test seam. Production behavior with the live agent runtime adapter (MEM018) is exercised only in integration with [M033](../../../../../milestones/M033/index.md) onboarding flows; SC-7 / SC-8 + their shape verifiers gate the contract surface, not the production runtime end-to-end.

## Inputs

### From Previous Tasks

- **T01: `scripts/intake/do-entry.sh`** — invoked end-to-end via the `--dispatch-stub` seam. CLI surface: `--task <description>` (required), `--yes`, `--config <path>`, `--dispatch-stub <script>`, `--scratch-root <dir>`, `--no-prompt-mode <A|B|C>`. Emits the FR-12 stderr summary line on the fast-path. Emits the JSONL `unit_close` record with `chosen_shape: <A|B|C>` to `${ORCH_DO_ENTRY_LOG:-.orchestrator/observability/dispatch-log.jsonl}` on the low-confidence-prompt branch.

### From Previous Phases

- **P02: `scripts/intake/shape-detect.sh`** — invoked by T02 step 1 to derive the low-confidence fixture body empirically.

### From Disk (Pre-existing)

- `tests/m031-acceptance/test-tier-a-plus-flow.sh` (P02/T04) — read for the canned dispatch stub shape; not modified.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **No edits to T01 deliverables** (`commands/do.md`, `scripts/intake/do-entry.sh`, the four T01 shape verifiers).
- **No edits to P01- or P02-owned files** (`build-context.sh`, `shape-detect.sh`, `route-to-dispatch.sh`, `paragraph-classify.sh`, `route-to-specify.sh`).
- **No edits to commands/dispatch.md / commands/evaluate.md / references/tier-definitions.md** (P01 / P04 owned).
- **CON-4 / DC-4**: T02 makes no orchestration-state writes; the JSONL `unit_close` record under `${ORCH_DO_ENTRY_LOG}` lands at a tmp path during the acceptance tests (cleanup via `trap`).
- **CON-7 / D020 hygiene**: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- **SC-12 scope-guard**: T02 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`.
- **Verifier path discipline** (AD-19 + [M032](../../../../../milestones/M032/index.md) Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.

## Expected Output

After T02 completes:

1. `tests/m031-acceptance/fixtures/do-entry-stub.sh` exists, executable, ≥ 15 lines.
2. `tests/m031-acceptance/fixtures/do-entry-trivial-input.txt` exists, non-empty, ≤ 10 words.
3. `tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt` exists, non-empty, classifier emits `low` confidence.
4. `tests/m031-acceptance/test-universal-entry-trivial.sh` exists, executable, ≥ 60 lines, exits 0 with `RESULT: SC-7 pass`.
5. `tests/m031-acceptance/test-universal-entry-lowconf.sh` exists, executable, ≥ 60 lines, exits 0 with `RESULT: SC-8 pass`.
6. `tools/verify/m031-p03-test-universal-entry-trivial-shape.sh` exists, executable, exits 0.
7. `tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh` exists, executable, exits 0.
8. T01's four shape verifiers still exit 0 (no regression).
9. No new files under `tools/verify/` matching `m031-p03-phase-suite` or `m031-p03-scope-guard` (T03's job).

T02 leaves the SC-7 + SC-8 acceptance tests + their fixtures + their two shape verifiers on disk. T03 builds on this by aggregating every P03 sub-gate via the phase-suite and enforcing the SC-12 scope-guard.
