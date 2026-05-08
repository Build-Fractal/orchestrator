---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P00"
milestone: "M030"
name: "Source-pool sweep + corpus skeleton + shape verifier"
depends_on: []
---

## Prerequisites

- Working tree at `~/Sites/orchestrator/` with `.orchestrator/milestones/M*/` populated by closed milestones (M001–M027 all have `phases/` or `archive/` subtrees containing `T*-PLAN.md` files — 455 candidates available as of P00 plan time).
- `scripts/dispatch/classify-task.sh` MUST NOT exist on disk — D-A4 independence-by-construction. Confirm via `ls scripts/dispatch/classify-task.sh` returning exit 1 before starting work; if the file exists, halt and escalate.
- `tools/verify/` directory may not exist yet; create it via `mkdir -p tools/verify` if absent (this is the project-owned verifier home per AD-19 path discipline).
- `tests/fixtures/` exists; create `tests/fixtures/m030-classifier-corpus/` via `mkdir -p`.

## Description

Sweep `.orchestrator/milestones/M*/` for `T*-PLAN.md` files, select ≥30 candidates with class-diversity intent (reading-by-eye for mechanical / standard / novel character signals before labels are formally applied), write the `labels.yml` skeleton with one entry per selected plan carrying `plan_path` + placeholder `character: TBD` + `confidence: TBD` + `rationale: TBD`, and author the two structural verifiers (`p00-corpus-shape.sh` + `p00-plans-exist.sh`) that gate the skeleton.

T01 ships ONLY the structural foundation — labels remain `TBD` after T01 completes; T02 fills them. The skeleton's purpose is to lock in the path manifest so T02 has a definite scope of plans to read.

## Steps

1. **Enumerate candidate task plans.** Run `find .orchestrator/milestones -name "T*-PLAN.md" -type f` to get the full pool (≈455 entries). Filter to plans whose milestone directory has a closed status — i.e., paths under `.orchestrator/milestones/M*/archive/` (143 closed-task plans) plus `.orchestrator/milestones/M*/phases/` for milestones whose `M*-SUMMARY.md` exists at the milestone root. Avoid plans from in-flight milestones (M028, M030 itself) so the labeler isn't biased by current context.

2. **Sample ≥30 plans with class-diversity intent.** Read the first ~40-60 lines of each candidate's body (`Description` + `Steps` sections are sufficient for a quick eyeball read). For each plan, form a working hypothesis about its character class:
   - **mechanical** — explicit `## Steps` block listing file paths and exact edits across ≤3 files; bash verifiers named explicitly; plan reads as "do these 5 things in this order."
   - **novel** — Goal/Description uses words like "explore", "design", "evaluate alternatives", "spike", "research"; no concrete file targets; reads as open-ended.
   - **standard** — partially specified; file paths declared but verifier shape ambiguous, OR step list present but spans 4+ files / multiple subsystems.
   Aim for ≥10 plans per provisional class (so the final per-class floor of 5 has slack against label-revision in T02). 30 is the floor; selecting 36-40 is reasonable.

3. **Capture the selection rationale in a working notes file** at `tests/fixtures/m030-classifier-corpus/SELECTION-NOTES.md` (this is a T01 working artifact; T03's README will graduate the methodology summary into `README.md`'s `## Sampling Methodology` section). Notes file content: total candidate-pool count, filter applied (closed milestones), provisional class distribution targets, and any plans rejected for ambiguity-too-high (out of scope for the first ≥30; can be added later if SC-10 measurement reveals coverage gaps).

4. **Write the skeleton `labels.yml`** at `tests/fixtures/m030-classifier-corpus/labels.yml`. Required structure:

   ```yaml
   ---
   schema_version: "1.0"
   type: classifier-fixture-corpus
   milestone: "M030"
   phase: "P00"
   created_at: "2026-04-30"
   labeler_constraint: "labels applied before scripts/dispatch/classify-task.sh authored — D-A4 independence by construction. See README.md ## D-A4 Independence Compliance."
   ---

   # M030 Classifier Ground-Truth Corpus

   # Labels are applied per the FR-1 three-class taxonomy:
   #   mechanical|standard|novel  (plus confidence: high|medium|low)
   # See README.md ## Labeling Rubric for the full vocabulary definitions.
   # Independence: this file's first commit MUST predate the first commit
   # of scripts/dispatch/classify-task.sh per D-A4 / SC-10.

   entries:
     - plan_path: ".orchestrator/milestones/M026/archive/P01/T01-PLAN.md"
       character: TBD
       confidence: TBD
       rationale: TBD
     - plan_path: ".orchestrator/milestones/M026/archive/P02/T03-PLAN.md"
       character: TBD
       confidence: TBD
       rationale: TBD
     # ... one entry per selected plan, ≥30 total
   ```

   Every entry's `plan_path` is the relative path from repo root. T01 leaves all label fields as the literal string `TBD` — T02 fills them.

5. **Author `tools/verify/p00-corpus-shape.sh`.** Bash 3.2-compatible. Behavior:
   - Path argument default: `tests/fixtures/m030-classifier-corpus/labels.yml`. Override via `$1`.
   - Check 1: file exists; print `FAIL: labels.yml missing` and exit 1 if not.
   - Check 2: frontmatter contains all six required keys (`schema_version`, `type: classifier-fixture-corpus`, `milestone: "M030"`, `phase: "P00"`, `created_at`, `labeler_constraint`). Use `grep -q` per key against the file.
   - Check 3: an `entries:` list-key line exists in the body.
   - Check 4: count of `  - plan_path:` lines is ≥30. Use `grep -c '^  - plan_path:' "$file"` (single-script-file shape, no `$()` with pipe).
   - Check 5: every entry has the four required keys present in the immediately-following block. Use a small awk pass that walks the file looking for the `  - plan_path:` anchor and asserting the next three lines start with `    character:`, `    confidence:`, `    rationale:`. Reject any entry missing one.
   - Check 6: every `character:` value is one of `mechanical|standard|novel` OR the literal `TBD` (T01 acceptance — labels still placeholder; T02 will tighten). Every `confidence:` value is one of `high|medium|low` OR `TBD`. Every `rationale:` value is non-empty (allow `TBD` at T01).
   - On success, emit `SUMMARY: p00-corpus-shape.sh pass=6 fail=0` and exit 0.
   - On any check failure, emit `SUMMARY: p00-corpus-shape.sh pass=N fail=M` plus a diagnostic line per failure and exit 1.
   - Note: at T01-close, all entries have `character: TBD` etc., so the shape verifier accepts `TBD` as a valid value for the placeholder phase. T02 amends the verifier (or T02's class-coverage verifier rejects `TBD`) so the eventual phase-close gate cannot pass with placeholders remaining.

6. **Author `tools/verify/p00-plans-exist.sh`.** Bash 3.2-compatible. Behavior:
   - Path argument default: `tests/fixtures/m030-classifier-corpus/labels.yml`. Override via `$1`.
   - Extract every `plan_path:` value from the file. Use `awk -F'"' '/^  - plan_path:/{print $2}'` (no quoting tricks, no `$()` chains).
   - For each path, run `[ -f "$path" ]`; record pass/fail count. Print `MISSING: $path` for each fail.
   - On all-present, emit `SUMMARY: p00-plans-exist.sh pass=N fail=0` (where N is the entry count) and exit 0.
   - On any miss, emit `SUMMARY: p00-plans-exist.sh pass=K fail=M` and exit 1.

7. **Run both verifiers as a self-check.** From repo root:

   ```bash
   bash tools/verify/p00-corpus-shape.sh
   bash tools/verify/p00-plans-exist.sh
   ```

   Both must exit 0. The shape verifier accepts `TBD` placeholders; the plans-exist verifier confirms every selected `plan_path` resolves to a real file on disk.

## Must-Haves

This task satisfies the phase truths:
- "labels.yml exists with required frontmatter + ≥30 entries with required keys" (corpus-shape truth — TBD acceptance only at this task; T02/T03 tighten).
- "every plan_path resolves to an existing file" (plans-exist truth).
- The shape and confidence vocabulary truths are also gated by T01's `p00-corpus-shape.sh` (vocabulary check accepts `TBD` only at T01-close; T02/T03 enforce the strict vocabulary via the class-coverage verifier).

## Verification

```bash
bash tools/verify/p00-corpus-shape.sh
bash tools/verify/p00-plans-exist.sh
```

Each verifier uses single-script-file shape per AD-19. Each emits `SUMMARY: <script> pass=N fail=0` on success and exits 0.

## Inputs

### From Previous Tasks

- None (T01 is the head of P00).

### From Disk (Pre-existing)

- `.orchestrator/milestones/M*/{archive,phases}/P*/T*-PLAN.md` — the 455-entry candidate pool. Read the first ~40-60 lines of each selected plan to form a class hypothesis.
- `specs/032-adaptive-model-selection/spec.md` — FR-1 character definitions (lines 36-47 of US-1 acceptance scenarios) and FR-2 heuristic-input list. Authoritative labeling rubric source.
- `.orchestrator/milestones/M030/M030-CONTEXT.md` — D-A4 (CONTEXT.md lines 38-42) names the independence constraint and mandates the version-controlled fixture file.

## Constraints

- **D-A4 independence**: `scripts/dispatch/classify-task.sh` MUST NOT exist on disk during T01 execution. Confirm before starting work.
- **Closed-milestone-only sourcing**: candidate plans come from `.orchestrator/milestones/M*/archive/` or from `.orchestrator/milestones/M*/phases/` where the milestone has a `M*-SUMMARY.md` at root. In-flight milestones (M028, M030) are excluded so the labeler isn't biased by current development context.
- **Skeleton-only at T01-close**: every entry's `character`, `confidence`, `rationale` is the literal `TBD`. T01 does NOT apply labels — that's T02's job. The skeleton locks the scope; the labels apply against the locked scope.
- **Bash 3.2 compatibility**: verifier scripts MUST NOT use `mapfile`/`readarray`, `declare -A`, process substitution `<(...)`, `&>`, or `${var^^}`. Use plain pipes via single-line invocations and POSIX-portable awk where possible.
- **Single-script-file Truth Check shape (AD-19)**: each verifier is a standalone script invoked as `bash tools/verify/<name>.sh`. No inline compound bash, no plain subshells, no `$(...)` containing a pipe.

## Expected Output

- `tests/fixtures/m030-classifier-corpus/labels.yml` — skeleton with ≥30 entries, all label fields set to `TBD`.
- `tests/fixtures/m030-classifier-corpus/SELECTION-NOTES.md` — T01 working notes (graduates into README's methodology section in T03).
- `tools/verify/p00-corpus-shape.sh` — shape gate, accepts `TBD` placeholders.
- `tools/verify/p00-plans-exist.sh` — every `plan_path` resolves on disk.
- Both verifiers exit 0 against the T01-close skeleton.

## Notes

Expected verifier output examples (for human readers, not for `auto-loop --step=V` evaluation):

- `bash tools/verify/p00-corpus-shape.sh` → stdout ends with `SUMMARY: p00-corpus-shape.sh pass=6 fail=0`, exit 0.
- `bash tools/verify/p00-plans-exist.sh` → stdout ends with `SUMMARY: p00-plans-exist.sh pass=N fail=0` (N = entry count), exit 0.

Per the planner-template Section-Discipline rule, expected output stays under `## Notes` because everything in `## Verification` is eval'd as a command by `auto-loop.sh --step=V`.
