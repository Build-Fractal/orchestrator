---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P00"
milestone: "M030"
name: "README methodology + D-A4 independence verifier + phase-suite gate"
depends_on: ["T01", "T02"]
---

## Prerequisites

- `tests/fixtures/m030-classifier-corpus/labels.yml` exists at the T02-close state — every entry has concrete `character` + `confidence` + `rationale`, ≥30 entries, ≥5 per class, no `TBD` survives.
- `tests/fixtures/m030-classifier-corpus/SELECTION-NOTES.md` exists (T01 working notes — graduates into the README's methodology section in this task).
- `tools/verify/p00-corpus-shape.sh`, `tools/verify/p00-plans-exist.sh`, `tools/verify/p00-class-coverage.sh` all exist and exit 0 against the T02-close state.
- `scripts/dispatch/classify-task.sh` STILL must not exist on disk — D-A4 independence remains in force throughout P00 close.

## Description

Author the corpus README at `tests/fixtures/m030-classifier-corpus/README.md` with four required sections (`## Source Pool`, `## Sampling Methodology`, `## Labeling Rubric`, `## D-A4 Independence Compliance`). Author the D-A4 independence-by-construction verifier at `tools/verify/p00-d-a4-independence.sh`. Author the README-shape verifier at `tools/verify/p00-readme-shape.sh`. Author the phase-suite gate at `tools/verify/p00-phase-suite.sh` that invokes all five P00 gates in order.

T03 is the phase-close task: when its verifiers all pass, P00's must-haves are fully met and the corpus is ready to commit. The commit happens at phase-close (the orchestrator-default git-commit shape — `git add` the produced paths, `git commit -F <message-file>` per the `## Commit Message Authoring` rule in `CLAUDE.md`).

## Steps

1. **Author `tests/fixtures/m030-classifier-corpus/README.md`.** Required structure:

   ```markdown
   # M030 Classifier Ground-Truth Corpus

   This directory holds the version-controlled fixture corpus that gates
   `scripts/dispatch/classify-task.sh` against ground truth (SC-10:
   ≥85% agreement on ≥30 hand-labeled task plans).

   The corpus's value depends on a single load-bearing property:
   **the labels were applied before the classifier was authored**.
   See `## D-A4 Independence Compliance` below.

   ## Source Pool

   The candidate pool is `find .orchestrator/milestones -name "T*-PLAN.md"
   -type f` filtered to closed milestones — paths under
   `.orchestrator/milestones/M*/archive/` plus
   `.orchestrator/milestones/M*/phases/` for milestones whose
   `M*-SUMMARY.md` exists at the milestone root. As of P00 plan time
   the pool contains <N> closed-milestone task plans across milestones
   M001 through [M027](../../../../../milestones/M027/index.md). In-flight milestones ([M028](../../../../../milestones/M028/index.md), M030 itself) are
   excluded so the labeler is not biased by current development context.

   ## Sampling Methodology

   ≥30 plans were sampled from the candidate pool with class-diversity
   intent. The labeler read the first ~40-60 lines of each candidate's
   body (Description + Steps sections) and formed a working hypothesis
   about the plan's character class before applying a formal label.
   Selection aimed for ≥10 plans per provisional class (so the final
   per-class floor of 5 has slack against label revision). Plans whose
   character was genuinely ambiguous were tagged `confidence: low`
   rather than excluded — `low`-confidence labels are useful signal for
   classifier calibration (FR-8's stability metric).

   The selection working notes are preserved at
   `SELECTION-NOTES.md` in this directory.

   ## Labeling Rubric

   Per FR-1 (`specs/032-adaptive-model-selection/spec.md` lines 36-47):

   - **mechanical** — explicit `## Steps` block listing file paths and
     exact edits across ≤3 files; bash verifiers named explicitly. Plan
     reads as "do these N things in this order" with no judgment calls.
   - **standard** — partially specified: file paths declared but
     verifier shape ambiguous, OR step list present but spans 4+ files /
     multiple subsystems. Some judgment required by the executor.
   - **novel** — Goal/Description uses words like "explore", "design",
     "evaluate alternatives", "spike", "research"; no concrete file
     targets; reads as open-ended.

   Confidence levels:

   - **high** — the rubric matches the plan unambiguously.
   - **medium** — the rubric matches with one or two minor caveats.
   - **low** — the plan plausibly fits two of the three classes; the
     label captures the closest fit but the call is not robust.

   The labeler captured each call's reasoning in the `rationale` field
   of `labels.yml`. This is the audit trail for D-A4: future readers
   (including SC-10's ≥85% agreement check post-P01) can replay the
   labeling reasoning without access to the (now-shipped) classifier.

   ## D-A4 Independence Compliance

   Per [`.orchestrator/milestones/M030/M030-CONTEXT.md`](../../../../../milestones/M030/M030-CONTEXT.md) D-A4 (and
   per the SC-10 amendment promoting Q-1 to spec constraint), the
   ground-truth corpus has three load-bearing properties:

   1. **Drawn from pre-M030 milestone history** — every `plan_path` in
      `labels.yml` resolves to a `T*-PLAN.md` file authored before
      M030 began.

   2. **Labeled before the classifier was authored** — at the moment
      this README and `labels.yml` were committed, the file
      `scripts/dispatch/classify-task.sh` did not exist anywhere in
      the working tree. The mechanical proxy is
      `bash tools/verify/p00-d-a4-independence.sh` which asserts
      either (a) `classify-task.sh` does not yet exist on disk, OR
      (b) the labels.yml first-commit timestamp precedes the
      classify-task.sh first-commit timestamp via `git log`.

   3. **No labeler had access to a draft classifier** — the labeling
      was a manual rubric application, not an automated
      classifier-assist task. No LLM was invoked with a
      "classify these for me" prompt; no draft of `classify-task.sh`
      existed to consult.

   These three properties together satisfy D-A4 / SC-10's
   independence-by-construction. P01's `classify-task.sh`
   plan-phase verifier MUST confirm property (2) via `git log`
   ordering before ratifying SC-10.

   ## Cross-References

   - `specs/032-adaptive-model-selection/spec.md` FR-1, FR-2, SC-10
   - [`.orchestrator/milestones/M030/M030-CONTEXT.md`](../../../../../milestones/M030/M030-CONTEXT.md) D-A4
   - `tools/verify/p00-d-a4-independence.sh` — independence verifier
   - `tools/verify/p00-phase-suite.sh` — full P00 gate suite
   ```

   Substitute `<N>` with the actual candidate-pool count (run `find` and count). The README is ≥60 lines per the phase plan's artifact spec.

2. **Delete (or archive) `tests/fixtures/m030-classifier-corpus/SELECTION-NOTES.md`** — its content is now subsumed by README.md's `## Sampling Methodology` section. T01 wrote it as a working artifact; T03 graduates it into README. (Implementation choice: either `git rm SELECTION-NOTES.md` or move to a path outside the corpus dir. Prefer `git rm` for cleanliness; the phase-suite gate doesn't reference SELECTION-NOTES.md.)

3. **Author `tools/verify/p00-d-a4-independence.sh`.** Bash 3.2-compatible. Behavior:
   - Working tree assumed at `$(pwd)`. No path argument.
   - Phase 1 (during P00 execution, pre-P01 commit of classifier): if `scripts/dispatch/classify-task.sh` does NOT exist on disk, emit `OK: classify-task.sh absent — D-A4 independence by construction` and exit 0.
   - Phase 2 (post-P01 commit of classifier): if `scripts/dispatch/classify-task.sh` DOES exist, fall through to the `git log` ordering check:
     - Resolve labels.yml first-commit timestamp:

       ```
       labels_ts=$(git log --diff-filter=A --pretty=format:%at -- tests/fixtures/m030-classifier-corpus/labels.yml | tail -1)
       ```

       (Single-pipeline invocation. The `tail -1` selects the oldest entry from `git log`'s newest-first default order.)

     - Resolve classify-task.sh first-commit timestamp:

       ```
       classifier_ts=$(git log --diff-filter=A --pretty=format:%at -- scripts/dispatch/classify-task.sh | tail -1)
       ```

     - Assert `labels_ts < classifier_ts` (numeric integer comparison via `[ "$labels_ts" -lt "$classifier_ts" ]`).
     - On pass: emit `OK: labels.yml committed at <ts1> precedes classify-task.sh at <ts2>` and exit 0.
     - On fail: emit `FAIL: D-A4 timeline violated — labels.yml=<ts1> classify-task.sh=<ts2>` and exit 1.
   - Either phase: append a `SUMMARY: p00-d-a4-independence.sh pass=N fail=M` line before exit.

4. **Author `tools/verify/p00-readme-shape.sh`.** Bash 3.2-compatible. Behavior:
   - Path argument default: `tests/fixtures/m030-classifier-corpus/README.md`. Override via `$1`.
   - Check 1: file exists.
   - Check 2: `grep -q '^## Source Pool$' "$file"` succeeds.
   - Check 3: `grep -q '^## Sampling Methodology$' "$file"` succeeds.
   - Check 4: `grep -q '^## Labeling Rubric$' "$file"` succeeds.
   - Check 5: `grep -q '^## D-A4 Independence Compliance$' "$file"` succeeds.
   - Check 6: README contains literal strings `mechanical`, `standard`, `novel` (rubric vocabulary present).
   - Check 7: README contains literal `classify-task.sh` (D-A4 compliance section names the load-bearing future file).
   - On all pass, emit `SUMMARY: p00-readme-shape.sh pass=7 fail=0` and exit 0.
   - On any fail, emit `SUMMARY: p00-readme-shape.sh pass=K fail=M` plus diagnostics, exit 1.

5. **Author `tools/verify/p00-phase-suite.sh`.** Bash 3.2-compatible. Behavior:
   - Working tree assumed at `$(pwd)`.
   - Define a list of five gate scripts in dependency order: corpus-shape, plans-exist, class-coverage, readme-shape, d-a4-independence.
   - For each, run `bash tools/verify/<name>.sh` directly (no compound chains, no `xargs`, no `for`-loop subshells). Capture exit code per gate. Track pass/fail counts in two integer accumulators.
   - After all five run, emit `SUMMARY: p00-phase-suite.sh pass=N fail=M` on a single line.
   - Exit 0 iff all five gates passed; exit 1 otherwise.
   - The script body is a literal sequence of five `bash tools/verify/p00-<name>.sh` invocations followed by `pass=$((pass+1))` / `fail=$((fail+1))` updates per `$?`. Plain straight-line bash, no loops over arrays, no `eval`.

6. **Run the phase-suite as a self-check.** From repo root:

   ```bash
   bash tools/verify/p00-phase-suite.sh
   ```

   The suite must exit 0 and emit `SUMMARY: p00-phase-suite.sh pass=5 fail=0`.

7. **Recent-changes dual-write** (CON-6 dual-write invariant if applicable to M030 — see CLAUDE.md `# >>> orchestrator:recent-changes >>>` region). Append a one-line P00 close fragment to `CLAUDE.md` and `AGENTS.md` (if `AGENTS.md` exists in this repo) via `scripts/util/dual-write-runtime-md.sh`. Fragment shape: `M030 P00 close: classifier-ground-truth corpus authored at tests/fixtures/m030-classifier-corpus/ (≥30 hand-labeled pre-M030 task plans, D-A4 independence by construction, phase-suite green)`. If the dual-write helper is unavailable on this branch, append manually to `CLAUDE.md`'s recent-changes region only and note it in T03 close.

## Must-Haves

This task satisfies the phase truths:
- "README.md exists with the four required sections + rubric vocabulary + D-A4 mention" (readme-shape truth).
- "D-A4 independence-by-construction holds at corpus-commit time" (d-a4-independence truth).
- "phase-suite invokes all five P00 gates and emits SUMMARY line" (phase-suite truth).

## Verification

```bash
bash tools/verify/p00-readme-shape.sh
bash tools/verify/p00-d-a4-independence.sh
bash tools/verify/p00-phase-suite.sh
```

Each verifier uses single-script-file shape per AD-19. The phase-suite invocation is the canonical phase-close gate; if it exits 0, P00 is ready for `orchestrator:verify`.

## Inputs

### From Previous Tasks

- `tests/fixtures/m030-classifier-corpus/labels.yml` (from T02)
  - Key API: YAML file with frontmatter + `entries:` list of ≥30 entries; every entry has concrete `character` ∈ {mechanical, standard, novel}, `confidence` ∈ {high, medium, low}, non-empty `rationale`. T03 reads but does not mutate this file.

- `tests/fixtures/m030-classifier-corpus/SELECTION-NOTES.md` (from T01)
  - Key API: prose record of T01's selection methodology. T03 graduates its content into README.md's `## Sampling Methodology` section, then deletes the working file.

- `tools/verify/p00-corpus-shape.sh` (from T01), `tools/verify/p00-plans-exist.sh` (from T01), `tools/verify/p00-class-coverage.sh` (from T02)
  - Key API: each is a `bash <script>.sh` invocation; each exits 0 with `SUMMARY: <script> pass=N fail=0` when its respective gate holds. T03 invokes them transitively via the phase-suite.

### From Disk (Pre-existing)

- `specs/032-adaptive-model-selection/spec.md` lines 36-47 (FR-1 character definitions; verbatim source for the README's `## Labeling Rubric` section).
- [`.orchestrator/milestones/M030/M030-CONTEXT.md`](../../../../../milestones/M030/M030-CONTEXT.md) lines 38-42 (D-A4; verbatim source for the README's `## D-A4 Independence Compliance` section).
- `scripts/util/dual-write-runtime-md.sh` (if present; recent-changes dual-write helper).
- `CLAUDE.md` (recent-changes region, target for the P00-close fragment).

## Constraints

- **D-A4 independence preserved**: `scripts/dispatch/classify-task.sh` STILL must not exist on disk during T03. Confirm before starting work.
- **README is the authoritative methodology record**: SELECTION-NOTES.md graduates into README and is then deleted from the corpus directory. Do not leave duplicate methodology records — the README is the SSOT post-T03.
- **No labels.yml mutations**: T03 does not touch `labels.yml`. T02 closed the labeling work; T03 only ships the methodology + verifier surfaces.
- **Bash 3.2 compatibility + AD-19 single-script-file shape**: verifier scripts MUST NOT use compound chains, plain subshells, `$(...)` containing pipes, process substitution, or heredocs feeding pipes. Each verifier is a straight-line bash script invokable as `bash tools/verify/<name>.sh`.
- **Phase-suite is straight-line**: `p00-phase-suite.sh` does NOT loop over a script-name array (which would force compound shapes). It invokes each gate by literal name, in five sequential statements.

## Expected Output

- `tests/fixtures/m030-classifier-corpus/README.md` — ≥60 lines, all four required sections present.
- `tools/verify/p00-d-a4-independence.sh` — independence-by-construction OR git-log-ordering verifier.
- `tools/verify/p00-readme-shape.sh` — README structural gate.
- `tools/verify/p00-phase-suite.sh` — full P00 gate suite, exits 0 with `SUMMARY: p00-phase-suite.sh pass=5 fail=0`.
- `CLAUDE.md` recent-changes region updated with P00-close fragment (and `AGENTS.md` if present).
- `tests/fixtures/m030-classifier-corpus/SELECTION-NOTES.md` removed (content graduated into README).

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p00-d-a4-independence.sh` → during P00 execution (classify-task.sh absent): `OK: classify-task.sh absent — D-A4 independence by construction`, `SUMMARY: p00-d-a4-independence.sh pass=1 fail=0`, exit 0.
- `bash tools/verify/p00-readme-shape.sh` → `SUMMARY: p00-readme-shape.sh pass=7 fail=0`, exit 0.
- `bash tools/verify/p00-phase-suite.sh` → `SUMMARY: p00-phase-suite.sh pass=5 fail=0`, exit 0.

If the phase-suite reports any sub-gate failure, the diagnostic per failing sub-gate is emitted by that sub-gate's own SUMMARY line — the suite itself just aggregates pass/fail counts.

Post-P01 (when `scripts/dispatch/classify-task.sh` ships), `p00-d-a4-independence.sh` automatically transitions from the absence-check phase to the git-log-ordering phase. P01's plan-phase MUST re-run `bash tools/verify/p00-phase-suite.sh` as a SC-10 prerequisite — the suite green is the mechanical gate that the timeline ordering held.
