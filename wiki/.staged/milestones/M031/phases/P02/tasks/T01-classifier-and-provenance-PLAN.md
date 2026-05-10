---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M031"
name: "Tier A+ classifier verdict (FR-6) + AD-16 fixture provenance + SC-5 acceptance test"
depends_on: []
---

## Prerequisites

- P01 complete: `scripts/dispatch/build-context.sh` carries `--profile=quick|standard|full` and `--meta-out` flags (verified by `bash tools/verify/m031-p01-build-context-profile-shape.sh`).
- P01 complete: `commands/dispatch.md` Quick row has been amended to remove "Skip payload assembly" (verified by `bash tools/verify/m031-p01-dispatch-md-reconciliation.sh`).
- P01 complete: `templates/orchestrator-config-default.yml` declares the three M031 knobs at the P00 pinned defaults, including `tier_a_plus_prompt_summary_lines: 8` (verified by `bash tools/verify/m031-p01-config-knobs-stable.sh`).
- The existing [M024](../../../../../milestones/M024/index.md) verdict enum on disk is `idea | paragraph | fragment | spec | empty` (per `scripts/intake/shape-detect.sh` body). Verify by inspection before editing — T01's job is to add `tier_a_plus` as a SIXTH verdict value, additive only.
- `.orchestrator/execution-log.jsonl` (or any sibling JSONL stream under `.orchestrator/`) exists and contains at least one historical `unit_close` record. T01 must cite at least one such record by `<milestone>/<phase>/<task>` provenance in `FIXTURE-PROVENANCE.md`.

## Description

T01 extends the M024 input-shape classifier additively with a `tier_a_plus` verdict and grounds the heuristic in a normative fixture-provenance document per AD-16. T01 ships:

1. The classifier extension itself (`scripts/intake/shape-detect.sh` + `scripts/intake/paragraph-classify.sh`) — additive only; existing four verdicts MUST stay byte-equal on M024 regression fixtures.
2. The AD-16 normative provenance file `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` — at least one historical `.orchestrator/` JSONL `unit_close` record cited with `<milestone>/<phase>/<task>` provenance plus the annotator's classification rationale.
3. The fixture input `tests/m031-acceptance/fixtures/tier-a-plus-input.txt` — a 30–80 word feature-request body matching the Tier A+ heuristic (paraphrased from the cited historical record).
4. SC-5 acceptance test `tests/m031-acceptance/test-tier-a-plus-classifier.sh` asserting the classifier emits `tier_a_plus` against the fixture.
5. Four shape verifiers under `tools/verify/m031-p02-*.sh` co-authored alongside the deliverables.

The Tier A+ heuristic boundary (recommended starting point — confirm against historical record body length during authoring): word count ≥ 30 AND word count ≤ 80 AND zero of the existing structural markers (`^##` heading, full Given/When/Then triple, `^- FR-`). Tasks above 80 words OR with structural markers continue to classify as `fragment` (today's behavior). Tasks below 30 words classify as `idea` or `paragraph` (today's behavior). Tier A+ is the **uninstantiated middle band** — paragraphs of feature-request prose without spec-shape markers, sized for medium tasks.

The classifier output line shape stays `input_shape=<value>` + `shape_classification=<high|low>` (today's contract). The verdict surface grows from `idea | paragraph | fragment | spec | empty` to `idea | paragraph | tier_a_plus | fragment | spec | empty`. Confidence emission stays the existing `high` / `low` enum.

## Steps

1. **Read the existing classifier scripts.** Open `scripts/intake/shape-detect.sh` (115 lines) and `scripts/intake/paragraph-classify.sh`. Identify (a) the word-count and structural-marker computation block, (b) the verdict-emission switch.

2. **Determine the Tier A+ heuristic boundary.** Walk `.orchestrator/execution-log.jsonl` (or any sibling under `.orchestrator/`) for `unit_close` records. Identify at least one record whose original task description (where present in the record body) matches the candidate heuristic (30–80 words, no spec-shape markers). Note the `<milestone>/<phase>/<task>` provenance — this is the AD-16 grounding. If multiple candidate records are visible, prefer the one whose task description is most paraphrasable into a 30–80 word fixture.

3. **Author `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md`.** Bash 3.2-compatible (no shell required; this is markdown). Required body sections:
   - `## Cited Historical Records` — at least one bullet citing `<milestone>/<phase>/<task>` provenance from `.orchestrator/execution-log.jsonl` (or sibling JSONL stream).
   - `## Annotator Rationale` — a paragraph explaining why the cited record qualifies as a Tier A+ candidate (word-count band, structural-marker absence, what the task was trying to do).
   - `## Boundary Heuristic Confirmation` — bullets naming the chosen word-count boundary (e.g., 30–80) and any structural-marker exclusion rules, with a one-sentence justification grounded in the cited record(s).
   - File MUST contain the literal substrings `tier_a_plus`, `unit_close`, `rationale`, and at least one `<milestone>/<phase>/<task>` provenance string.

4. **Author `tests/m031-acceptance/fixtures/tier-a-plus-input.txt`.** Plain UTF-8 text. 30–80 words, no `^##` heading line, no Given/When/Then triple, no `^- FR-` bullet. Body is a paraphrase of the cited historical record from step 2 — feature-request shape ("add a new flag X to script Y with three tests and a doc update" / "wire knob Z into config + add doctor-time validation + emit one new JSONL record" etc.). Validate manually that `wc -w` returns a value in [30, 80].

5. **Extend `scripts/intake/shape-detect.sh` with a `tier_a_plus` verdict branch.** Place the new branch BEFORE the existing `fragment` and `idea` branches so it can claim the 30–80-word + zero-structural-marker band. Concrete patch shape (insertion only, no replacement of existing logic):

   ```bash
   # Tier A+: 30-80 words, zero structural markers (FR-6, AD-16 grounded).
   # Empirical boundary documented in tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md.
   if [ "$structural" -eq 0 ] && [ "$words" -ge 30 ] && [ "$words" -le 80 ]; then
     conf="high"
     # Low-confidence sub-case: word-count near the boundary edges.
     if [ "$words" -le 32 ] || [ "$words" -ge 78 ]; then
       conf="low"
     fi
     echo "input_shape=tier_a_plus"
     echo "shape_classification=$conf"
     exit 0
   fi
   ```

   Insertion point: AFTER the structural-marker-fragment branch (line ~76 today) and BEFORE the `idea` branch. The existing fragment branch fires when `structural > 0 || words >= 81`; the new tier_a_plus branch fires only when `structural == 0 && 30 <= words <= 80`; the existing idea branch fires when `words <= 10`; the existing paragraph default fires for everything else (mostly the 11-29 word band). Verify mentally that the existing verdicts remain byte-equal on inputs that don't fall into the new band.

6. **Extend `scripts/intake/paragraph-classify.sh` parallel to step 5** — add a `tier_a_plus` recognition branch consistent with shape-detect.sh's heuristic. (Inspect the file first; if its surface differs from shape-detect.sh — e.g., it operates on already-paragraph-classified inputs — the extension may be a single-line literal-token recognition rather than a heuristic re-implementation.)

7. **Author `tests/m031-acceptance/test-tier-a-plus-classifier.sh`** (executable, bash 3.2). SC-5 contract:
   - Read `tests/m031-acceptance/fixtures/tier-a-plus-input.txt`.
   - Invoke `bash scripts/intake/shape-detect.sh --input "$(cat <fixture>)"`. Capture stdout.
   - Assert stdout contains the literal token `tier_a_plus` (the `input_shape=tier_a_plus` line).
   - Assert `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` exists and contains at least one `<milestone>/<phase>/<task>` provenance string.
   - Output: emit `RESULT: SC-5 pass` on success or `RESULT: SC-5 fail` + a diagnostic on failure. Exit 0 iff pass.

8. **Author `tools/verify/m031-p02-classifier-extension-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `scripts/intake/shape-detect.sh` contains the literal substring `tier_a_plus` AND the literal substring `input_shape=tier_a_plus` (the verdict surface).
   - Assert `scripts/intake/paragraph-classify.sh` contains the literal substring `tier_a_plus`.
   - Assert the four pre-existing verdict tokens (`idea`, `paragraph`, `fragment`, `spec`, `empty`) all still appear in `scripts/intake/shape-detect.sh` (no regression on the existing enum).
   - Output: a single final stdout line `SUMMARY: m031-p02-classifier-extension-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

9. **Author `tools/verify/m031-p02-fixture-provenance-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` exists and is non-empty (≥ 25 lines).
   - Assert the file contains the literal substrings `tier_a_plus`, `unit_close`, `rationale`, and `AD-16`.
   - Assert the file contains at least one `M[0-9][0-9][0-9]/P[0-9][0-9]/T[0-9][0-9]` provenance pattern (basic regex via `grep -E`).
   - Output: a single final stdout line `SUMMARY: m031-p02-fixture-provenance-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

10. **Author `tools/verify/m031-p02-tier-a-plus-input-shape.sh`** (executable, bash 3.2). Contract:
    - Assert `tests/m031-acceptance/fixtures/tier-a-plus-input.txt` exists and is non-empty.
    - Assert `wc -w` of the file returns a value in [30, 80].
    - Assert the file does NOT contain a `^##` heading line, a Given/When/Then triple, or a `^- FR-` bullet (so the fixture truly classifies as `tier_a_plus` rather than `fragment` or `paragraph`).
    - Output: a single final stdout line `SUMMARY: m031-p02-tier-a-plus-input-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

11. **Author `tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh`** (executable, bash 3.2). Contract:
    - Assert `tests/m031-acceptance/test-tier-a-plus-classifier.sh` exists, is executable.
    - Assert the test contains the literal substrings `SC-5`, `tier_a_plus`, and `FIXTURE-PROVENANCE`.
    - Output: a single final stdout line `SUMMARY: m031-p02-test-tier-a-plus-classifier-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

12. **Run all four new verifiers locally + the SC-5 acceptance test** to confirm exit 0:

    ```bash
    bash tools/verify/m031-p02-classifier-extension-shape.sh
    bash tools/verify/m031-p02-fixture-provenance-shape.sh
    bash tools/verify/m031-p02-tier-a-plus-input-shape.sh
    bash tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh
    bash tests/m031-acceptance/test-tier-a-plus-classifier.sh
    ```

13. **Confirm no regression on existing M024 verdicts.** Sanity-check by invoking shape-detect.sh against a one-word input (expect `idea`), a five-word input (expect `idea`), a 25-word input (expect `paragraph`), and a 100-word input with no structural markers (expect `fragment` — word-count >= 81 dominates).

## Must-Haves

This task addresses the following Must-Haves from `P02-PLAN.md`:
- "scripts/intake/shape-detect.sh and scripts/intake/paragraph-classify.sh emit a fourth verdict value tier_a_plus" (Truth #1; Check via `m031-p02-classifier-extension-shape.sh`)
- "tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md exists with at least one historical unit_close record cited" (Truth #2; Check via `m031-p02-fixture-provenance-shape.sh`)
- "tests/m031-acceptance/fixtures/tier-a-plus-input.txt exists with a 30-80 word feature-request fixture" (Truth #3; Check via `m031-p02-tier-a-plus-input-shape.sh`)
- "tests/m031-acceptance/test-tier-a-plus-classifier.sh (SC-5) exists, executable, exits 0" (Truth #8; Check via `m031-p02-test-tier-a-plus-classifier-shape.sh`)

## Verification

```bash
bash tools/verify/m031-p02-classifier-extension-shape.sh
```

```bash
bash tools/verify/m031-p02-fixture-provenance-shape.sh
```

```bash
bash tools/verify/m031-p02-tier-a-plus-input-shape.sh
```

```bash
bash tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh
```

```bash
bash tests/m031-acceptance/test-tier-a-plus-classifier.sh
```

## Notes

- Each shape verifier MUST emit `SUMMARY: <script-name> pass=N fail=M` as its final stdout line and exit 0 iff `fail=0` — the M031 P01 convention reused.
- The SC-5 acceptance script uses the alternate envelope `RESULT: SC-5 pass` / `RESULT: SC-5 fail` per the M031 P01 convention for SC-* scripts (see P01/T03 plan, "two distinct envelope conventions").
- Confidence-band tuning at the boundary edges (32 / 78) is heuristic — adjust during T01 based on the cited historical record's actual word count to keep its classification at `high` confidence rather than the boundary `low` band.
- D020 token hygiene (CON-7): comments and prose in the new files MUST NOT embed the literal scaffold-placeholder open-bracket-TODO-colon byte pattern inside backticked inline code; paraphrase or escape.
- Bash 3.2 compatibility (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.

## Inputs

### From Previous Tasks

(No upstream tasks within P02; T01 is the entry point.)

### From Disk (Pre-existing)

- `scripts/intake/shape-detect.sh` (115 lines) — existing M024 classifier. Read the word-count + structural-marker block (lines ~55–73) and the verdict-emission switch (lines ~75–115) before editing. Key API: invoked as `bash scripts/intake/shape-detect.sh --input <string>` or `--spec-path <path>`; emits two stdout lines `input_shape=<value>` + `shape_classification=<high|low>`.
- `scripts/intake/paragraph-classify.sh` — existing M024 paragraph-shape sub-classifier. Read its surface before editing; the extension may be smaller than shape-detect.sh's depending on its current responsibility.
- `.orchestrator/execution-log.jsonl` (or any sibling JSONL stream under `.orchestrator/`) — read for at least one historical `unit_close` record with task-description body in the 30–80 word range. The cited record's `<milestone>/<phase>/<task>` provenance lands in `FIXTURE-PROVENANCE.md`.
- `templates/orchestrator-config-default.yml` — declares `tier_a_plus_prompt_summary_lines: 8` (P00 pinned default). T01 reads this value name only as part of the FIXTURE-PROVENANCE.md cross-reference; does not modify the file.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **Strictly additive** to the M024 classifier surface: existing four verdicts (`idea | paragraph | fragment | spec | empty`) MUST emit byte-equal pre/post on regression fixtures.
- **No edits to `scripts/intake/route-to-dispatch.sh`** in T01 (T04's job).
- **No edits to `templates/dispatch-role-*.md`** in T01 (T02's job — files do not yet exist).
- **No edits to `scripts/intake/lib/`** in T01 (T02 + T03 ship lib helpers; T01 has no lib dependency).
- **SC-12 scope-guard**: T01 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`.
- **No new state machines / lock files** (CON-4 / DC-4): T01 makes additive classifier edits only — no state-derivation rule, no lock file, no milestone scaffolding write.
- **Verifier path discipline** (AD-19 + [M032](../../../../../milestones/M032/index.md) Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`. The M031-namespaced prefix `m031-p02-` avoids collision with [M030](../../../../../milestones/M030/index.md)'s `p02-*` verifiers in the shared tree.

## Expected Output

After T01 completes:

1. `scripts/intake/shape-detect.sh` emits `input_shape=tier_a_plus` for inputs in the 30–80 word band with zero structural markers; emits the original four verdicts byte-equal on every other input.
2. `scripts/intake/paragraph-classify.sh` recognizes `tier_a_plus` consistent with shape-detect.sh.
3. `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` exists, ≥ 25 lines, cites at least one `<milestone>/<phase>/<task>` historical `unit_close` record, contains the literal `tier_a_plus`, `unit_close`, `rationale`, `AD-16` tokens.
4. `tests/m031-acceptance/fixtures/tier-a-plus-input.txt` exists, 30–80 words, no spec-shape structural markers.
5. `tests/m031-acceptance/test-tier-a-plus-classifier.sh` exists, executable, exits 0 (`RESULT: SC-5 pass`).
6. Four shape verifiers under `tools/verify/m031-p02-*.sh` exist, executable, exit 0.
7. `scripts/intake/route-to-dispatch.sh` byte-identical to its pre-T01 state (no edits in T01).

T01 leaves the M024 classifier surface extended with `tier_a_plus` and the AD-16 grounding on disk. T02 builds on this by shipping the slug library + role templates that the eventual T04 router will invoke.
