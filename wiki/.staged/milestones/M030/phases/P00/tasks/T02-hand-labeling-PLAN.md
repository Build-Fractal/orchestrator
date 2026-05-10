---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P00"
milestone: "M030"
name: "Hand-labeling + class-coverage verifier"
depends_on: ["T01"]
---

## Prerequisites

- `tests/fixtures/m030-classifier-corpus/labels.yml` exists at the T01-close skeleton state — frontmatter populated, ≥30 entries each carrying `plan_path` (real, resolves on disk) plus `character: TBD` + `confidence: TBD` + `rationale: TBD`.
- `tests/fixtures/m030-classifier-corpus/SELECTION-NOTES.md` exists with T01's selection rationale.
- `tools/verify/p00-corpus-shape.sh` and `tools/verify/p00-plans-exist.sh` exist and exit 0 against the skeleton.
- `scripts/dispatch/classify-task.sh` STILL must not exist on disk — D-A4 independence remains in force throughout labeling.

## Description

Read every selected plan body in `labels.yml` and apply a `character` (one of `mechanical|standard|novel`), a `confidence` (one of `high|medium|low`), and a `rationale` (one or more sentences justifying the call) to each entry. Replace every `TBD` placeholder with a concrete value. Then author `tools/verify/p00-class-coverage.sh` to gate the per-class floor.

The labeling rubric is the FR-1 + US-1 acceptance scenarios from `specs/032-adaptive-model-selection/spec.md`:

- **mechanical** + **high**: explicit `## Steps` listing file paths and exact edits across ≤3 files; bash verifiers named explicitly. Plan reads as "do these 5 things in this order" with no judgment calls.
- **mechanical** + **medium**: similar shape, but one or two steps require judgment (e.g., "select an appropriate threshold").
- **novel** + **high**: Goal/Description uses words like "explore", "design", "evaluate alternatives", "spike", "research"; no concrete file targets; reads as open-ended.
- **novel** + **medium**: framed as design/research but with one or two concrete deliverables.
- **standard** + **high/medium/low**: partially specified — file paths declared but verifier shape ambiguous, OR step list present but spans 4+ files / multiple subsystems. `confidence: low` is reserved for genuinely ambiguous cases that could plausibly be classified into any of the three classes.

The labeler MUST capture each call's reasoning in the `rationale` field. This is the audit trail D-A4 demands: future readers (including post-P01 verifiers running SC-10's ≥85% agreement check) can replay the labeler's reasoning without access to the (eventually-shipped) classifier.

## Steps

1. **Read `labels.yml` end-to-end.** Confirm ≥30 entries are present with `TBD` placeholders. Note the entry count — N — for use in coverage targets.

2. **Walk each entry, in `labels.yml` order.** For each entry:
   - Read the body of `<plan_path>` end-to-end (typically 80-200 lines for a task plan).
   - Apply the rubric (above) to form a `character` + `confidence` decision.
   - Compose a 1-3 sentence `rationale` naming the specific signal that drove the call (e.g., "Eight discrete `## Steps` each editing one file with grep-based verifiers — fully mechanical, no judgment calls", or "Goal section frames work as 'explore design alternatives' with no file targets — novel by FR-1 definition").
   - Update the entry in `labels.yml`. Replace `character: TBD` with `character: <call>`, `confidence: TBD` with `confidence: <call>`, `rationale: TBD` with `rationale: "<sentence>"` (quoted YAML string for safety against punctuation).

3. **Apply class-coverage backfill if needed.** After labeling all ≥30 entries, count per-class distribution:

   - If any of `mechanical|standard|novel` has fewer than 5 entries, the corpus fails the per-class floor. Choose additional plans from the candidate pool (re-run T01's `find` command, exclude already-listed plans), label them, and append to `labels.yml`. Repeat until each class has ≥5 entries.
   - Aim for a roughly balanced distribution but do NOT artificially balance — if the natural distribution of pre-M030 plans is skewed (e.g., 18 mechanical / 9 standard / 6 novel for 33 total), accept the skew as the corpus's empirical character. SC-10's ≥85% agreement target is per-corpus, not per-class.

4. **Author `tools/verify/p00-class-coverage.sh`.** Bash 3.2-compatible. Behavior:
   - Path argument default: `tests/fixtures/m030-classifier-corpus/labels.yml`. Override via `$1`.
   - Strict vocabulary check: every `character:` value MUST be exactly one of `mechanical|standard|novel` — `TBD` is rejected. Every `confidence:` value MUST be exactly one of `high|medium|low` — `TBD` is rejected. (This is the gate that flips from T01's lenient acceptance to T02-and-after's strict acceptance.)
   - Per-class count: extract `character:` values, count occurrences of each canonical value via three independent `grep -c` invocations:

     ```
     mechanical_count=$(grep -c '^      character: mechanical$' "$file" || true)
     standard_count=$(grep -c '^      character: standard$' "$file" || true)
     novel_count=$(grep -c '^      character: novel$' "$file" || true)
     ```

     (Three separate single-line invocations — no `$()` containing a pipe, no compound chains.)

   - Floor check: each count ≥5. Print `FAIL: class=<name> count=<N> below floor=5` per failing class.
   - Total check: total entry count ≥30 (`grep -c '^  - plan_path:' "$file"`).
   - Rationale check: every `rationale:` line MUST be non-empty and MUST NOT equal the literal `TBD`. Use `grep -c '^      rationale: TBD$' "$file"` and assert the count is 0.
   - On all checks pass, emit `SUMMARY: p00-class-coverage.sh pass=K fail=0` (K = number of checks passed; expect 5: vocab-character, vocab-confidence, per-class-floor, total-floor, no-TBD-rationale) and exit 0.
   - On any fail, emit `SUMMARY: p00-class-coverage.sh pass=K fail=M` plus per-failure diagnostics, exit 1.

5. **Run all three verifiers as a self-check.** From repo root:

   ```bash
   bash tools/verify/p00-corpus-shape.sh
   bash tools/verify/p00-plans-exist.sh
   bash tools/verify/p00-class-coverage.sh
   ```

   All three must exit 0. The shape verifier still passes (the underlying YAML structure didn't change); the plans-exist verifier still passes (paths weren't touched); the new class-coverage verifier passes because every `TBD` has been replaced and per-class floors hold.

## Must-Haves

This task satisfies the phase truths:
- "every entry's `character` is exactly one of mechanical/standard/novel" (class-coverage truth).
- "every entry's `confidence` is exactly one of high/medium/low" (class-coverage truth — vocab check).
- "every entry's `rationale` is non-empty" (class-coverage truth — no-TBD check).
- "≥5 entries per class" (class-coverage truth — per-class floor).

## Verification

```bash
bash tools/verify/p00-corpus-shape.sh
bash tools/verify/p00-plans-exist.sh
bash tools/verify/p00-class-coverage.sh
```

Each verifier uses single-script-file shape per AD-19. Each emits `SUMMARY: <script> pass=N fail=0` on success and exits 0.

## Inputs

### From Previous Tasks

- `tests/fixtures/m030-classifier-corpus/labels.yml` (from T01)
  - Key API: a YAML file with frontmatter + `entries:` list. Each entry is a YAML mapping with keys `plan_path` (string, relative path), `character`, `confidence`, `rationale` (all `TBD` at T01-close).
  - Key types: string-valued YAML scalars; T02 mutates the latter three keys per entry.

- `tests/fixtures/m030-classifier-corpus/SELECTION-NOTES.md` (from T01)
  - Key API: prose record of T01's selection methodology. Reading it is optional for T02 (the labeler can re-derive class hypotheses from each plan's body) but useful as a sanity check on the candidate-pool sweep.

- `tools/verify/p00-corpus-shape.sh` + `tools/verify/p00-plans-exist.sh` (from T01)
  - Key API: each is a `bash <script>.sh` invocation taking optional `<labels-yml-path>` argument. Both exit 0 with `SUMMARY: <script> pass=N fail=0` stdout when their respective gates hold.

### From Disk (Pre-existing)

- The 30+ task plan files referenced in `labels.yml`'s `plan_path` entries. Each plan body is the labeling input.
- `specs/032-adaptive-model-selection/spec.md` lines 36-47 (US-1 acceptance scenarios) — the authoritative rubric for the three-class taxonomy.
- `specs/032-adaptive-model-selection/spec.md` line 134 (FR-2) — the heuristic-input list (`## Steps` block presence, file-touch breadth, verification specificity, frontmatter `type:` field, phase position, recent-retry signal). Useful as a lens for forming the labeling call.

## Constraints

- **D-A4 independence preserved**: `scripts/dispatch/classify-task.sh` STILL must not exist on disk during T02. The labeling work itself is the independence guarantee; do not consult any draft or stub of the classifier.
- **No automation of labeling**: the labeling MUST be done by reading each plan and forming a manual call. Do not invoke an LLM with a "classify these for me" prompt — that would defeat D-A4 and SC-10's mechanical-independence purpose.
- **Strict vocabulary at T02-close**: `character:` ∈ {mechanical, standard, novel}, `confidence:` ∈ {high, medium, low}. No `TBD` survives.
- **Per-class floor 5**: every class has ≥5 entries. Backfill the corpus if the initial 30 didn't hit the floor.
- **Bash 3.2 compatibility + AD-19 single-script-file shape**: same constraints as T01's verifiers.

## Expected Output

- `tests/fixtures/m030-classifier-corpus/labels.yml` — every entry has concrete `character` + `confidence` + `rationale` values; no `TBD` survives; per-class count ≥5 for each of `mechanical|standard|novel`; total entry count ≥30.
- `tools/verify/p00-class-coverage.sh` — strict-vocabulary + per-class-floor + total-floor + no-TBD gate.
- All three verifiers (corpus-shape, plans-exist, class-coverage) exit 0.

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p00-class-coverage.sh` → stdout ends with `SUMMARY: p00-class-coverage.sh pass=5 fail=0`, exit 0.
- `bash tools/verify/p00-corpus-shape.sh` continues to pass — the underlying YAML structure is unchanged from T01-close; only field values mutated.

If `p00-class-coverage.sh` reports a per-class floor failure, the remediation is to label additional plans from the candidate pool (not to game the verifier or weaken the floor).
