---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M024"
name: "Static qa-questions template — templates/intake-qa-questions.md"
depends_on: []
---

## Prerequisites

- P01 complete: the `templates/intake-proposal.md` shape exists; the proposal frontmatter carries `qa_short_circuited: <bool>` and `low_confidence: <bool>` keys (both default to `false`); the proposal body has a body-rendering path consumable by P05/T03 (see T03 plan for the embedding shape).
- The repo's `templates/` directory follows MEM013 conventions: YAML frontmatter with `schema_version` + `type` fields, `{{placeholder}}` syntax for dynamic values when applicable, no hardcoded milestone/phase/task IDs.

## Description

Author `templates/intake-qa-questions.md` — the **static 5-question template** that resolves spec open-question #Q-3 first cut. The template is pure data: a YAML frontmatter block plus five numbered question blocks, each with a one-line prompt and a one-line guidance hint covering one load-bearing routing axis.

The five questions are pinned in this exact order (T02's loop reads them by `### Q<N>` heading number):

1. **Q1 — Goal** (drives input_shape rationale + scope_tier evidence)
2. **Q2 — Scope** (drives decomposition axis)
3. **Q3 — Visible surface** (drives design_gate signal)
4. **Q4 — Adversarial review** (drives conversus_gate signal)
5. **Q5 — Time-boxing** (drives intensity axis)

This is a static-template-first cut per the planning-payload's #Q-3 resolution and the D019 reuse-over-rebuild posture. Conversus-loop and knowledge-driven question sources are deferred — they can land as a future M024.x extension if dogfood signals demand a richer source. The static cut earns SC-3 (≤5 turns + transcript embedded) and FR-5 (bounded loop, `enough` short-circuit, transcript embedded under `## Q&A`) without introducing new dynamic plumbing.

## Steps

1. **Author `templates/intake-qa-questions.md`** with the following content verbatim:

   ```markdown
   ---
   schema_version: "1.0"
   type: intake-qa-questions
   ---

   # Intake Q&A — Static 5-Question Template (M024/P05)

   This template is consumed by `scripts/intake/qa-loop.sh` when an operator
   invokes `orchestrator:evaluate` with neither `--input` nor `--spec-path`.
   The qa-loop reads questions in order by `### Q<N>` heading number, presents
   each prompt to the operator (or the line-mode answers file in tests), and
   captures the answer for embedding under `## Q&A` in the emitted proposal.

   The operator may answer any subset and short-circuit at any point with
   the literal token `enough`. The cap is 5 turns (FR-5).

   ### Q1 — Goal

   **Prompt**: What outcome do you want this work to produce?

   **Guidance**: One sentence. A target state ("status command caches the
   last result") rather than an action ("add caching"). This drives the
   input_shape rationale and the scope_tier evidence for the proposal.

   ### Q2 — Scope

   **Prompt**: Is this a single fix, a single feature, or a milestone-sized body of work?

   **Guidance**: One of `single-task`, `single-feature`, or
   `milestone`. Single-task is a one-script bug fix or doc edit;
   single-feature is one phase of work; milestone is multi-phase. This
   drives the decomposition axis.

   ### Q3 — Visible surface

   **Prompt**: What surface does the change touch — code, docs, config, workflow, or UI?

   **Guidance**: One or more of `code`, `docs`, `config`, `workflow`,
   `ui`. UI-touching work hints at a design-gate recommendation; the
   other surfaces typically do not. This drives the design_gate signal.

   ### Q4 — Adversarial review

   **Prompt**: Does the change touch security, correctness, or contested design?

   **Guidance**: `yes` or `no`. Yes-answers escalate the conversus_gate
   axis to `recommended`; no-answers leave it at `none`. This drives the
   conversus_gate signal.

   ### Q5 — Time-boxing

   **Prompt**: Roughly how long should this take — Quick (≤30 minutes), Standard (≤2 hours), or Full (multi-session)?

   **Guidance**: One of `Quick`, `Standard`, or `Full`. The answer
   feeds the intensity axis directly (the proposal-emit may still
   override via `intensity-recommend.sh` if the input description
   warrants).
   ```

2. **Author `scripts/verify/m024-p05-qa-questions-template.sh`** — asserts the template ships with the expected YAML schema fields and the five `### Q<N>` headings:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m024-p05-qa-questions-template.sh
   # Verifies templates/intake-qa-questions.md ships with the pinned schema
   # fields and the five ### Q<N> heading blocks per M024/P05 #Q-3 resolution.

   set -u
   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   F="$ROOT/templates/intake-qa-questions.md"

   [ -f "$F" ] || { echo "FAIL: $F missing"; exit 1; }

   grep -q '^schema_version: "1.0"' "$F" \
     || { echo "FAIL: schema_version 1.0 not present in $F"; exit 1; }
   grep -q '^type: intake-qa-questions' "$F" \
     || { echo "FAIL: type: intake-qa-questions not present in $F"; exit 1; }

   for n in 1 2 3 4 5; do
     grep -q "^### Q$n " "$F" \
       || { echo "FAIL: ### Q$n heading missing in $F"; exit 1; }
   done

   # Topic words must be grep-stable so T02 can rely on them.
   grep -q -i 'goal'             "$F" || { echo "FAIL: Q1 goal topic missing";          exit 1; }
   grep -q -i 'scope'            "$F" || { echo "FAIL: Q2 scope topic missing";         exit 1; }
   grep -q -i 'surface'          "$F" || { echo "FAIL: Q3 visible surface missing";     exit 1; }
   grep -q -i 'adversarial'      "$F" || { echo "FAIL: Q4 adversarial review missing";  exit 1; }
   grep -q -i 'time'             "$F" || { echo "FAIL: Q5 time-boxing missing";         exit 1; }

   echo "PASS: intake-qa-questions.md — schema + five ### Q<N> blocks + topic words present"
   exit 0
   ```

3. **Make the verify executable**: `chmod +x scripts/verify/m024-p05-qa-questions-template.sh` (single command — do not chain).

## Must-Haves

- `templates/intake-qa-questions.md` exists, has YAML frontmatter with `schema_version: "1.0"` and `type: intake-qa-questions`, and contains exactly five `### Q<N>` headings (Q1 through Q5).
- The five topic words (goal / scope / surface / adversarial / time) are grep-stable in the template body — T02's loop and downstream test assertions rely on them.
- `scripts/verify/m024-p05-qa-questions-template.sh` exists, is executable, and exits 0 with `PASS: ...` on a clean checkout.
- AD-19 single-script-file shape: every external command in the verify is a top-level invocation; no inline compound bash, no plain subshells, no `$(... | ...)`.
- SB-3 write-confinement: T01 writes only to `templates/intake-qa-questions.md` and `scripts/verify/m024-p05-qa-questions-template.sh`.

## Verification

```
bash scripts/verify/m024-p05-qa-questions-template.sh
```

Exits 0 with `PASS: intake-qa-questions.md — schema + five ### Q<N> blocks + topic words present`.

## Inputs

### From Previous Tasks

- None. T01 is the first task in P05 and depends only on pre-existing P01 / P04 infrastructure (which T01 does not modify).

### From Disk (Pre-existing)

- `templates/` directory — pre-existing template directory that follows MEM013 conventions (YAML frontmatter with `schema_version` + `type`).
- `scripts/verify/` directory — pre-existing verify-script home for M024 phase verifies.

## Constraints

- POSIX sh + bash 3.2 portable. No `declare -A`. No process substitution. No `[[ ]]` in the verify body.
- Writes only to `templates/intake-qa-questions.md` and `scripts/verify/m024-p05-qa-questions-template.sh` (SB-3).
- AD-19 single-script-file shape: every external invocation in the verify is a top-level command; no inline compound bash, no plain subshells, no `$(... | ...)` containing pipes.
- The template is **static and pinned** — no `{{placeholder}}` substitutions. T02's loop reads literal heading text. (Future dynamic-question-source extensions can land as a sibling file without breaking the static contract.)
- The five `### Q<N>` headings MUST be in the order Q1–Q5 per the loop's read-by-number convention.

## Expected Output

`templates/intake-qa-questions.md` is created with the five-question content above; `scripts/verify/m024-p05-qa-questions-template.sh` is created and executable; the verify exits 0 with the `PASS:` line.
