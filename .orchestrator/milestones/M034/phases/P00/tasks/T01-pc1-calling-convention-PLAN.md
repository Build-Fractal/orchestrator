---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P00"
milestone: "M034"
name: "Specify the write-decisions.sh calling convention (PC-1)"
depends_on: []
---

## Prerequisites

- `specs/044-interactive-review-gates/spec.md` exists (FR-1 decision-packet schema; PC-1 acceptance criteria in the "Pre-Planning Conditions" section). Confirmed on disk at plan-authoring time.
- `scripts/knowledge/write-summary.sh` exists (prior-art shape for a single-file bash writer). Confirmed on disk (19451 bytes).

## Description

PC-1 (P0, RISK-1) requires a concrete calling convention for passing LLM-generated multi-field decision content to the future `write-decisions.sh`. Unlike `write-summary.sh` (single summary text), the decisions packet carries an array of entries each with five text fields (`summary`, `picked_value`, `rationale`, `alternatives_considered`, `concrete_impact`) and two enum fields (`severity`, `type`). A 400-character `alternatives_considered` passage cannot be safely passed as a positional shell argument. This task produces the `## PC-1` section of the addendum specifying the wire format so a P01 implementer (and the LLM instruction template) build against one agreed convention.

This task is a SPECIFICATION task — it writes a planning addendum, not production code. `write-decisions.sh` itself is a P01 deliverable.

## Steps

1. Read `scripts/knowledge/write-summary.sh` and identify its actual calling convention: how it receives the summary text (positional arg vs stdin vs temp-file), how it receives the milestone/output-path, and how it handles multi-line content. Record the observed convention verbatim (file:line references).
2. Decide the `write-decisions.sh` wire format. Recommended (from the conversus arbiter MIT-1): a **stdin-fed JSON document** carrying the full FR-1 decision-entry array — newline- and shell-metacharacter-safe, jq-parseable. Justify the choice against the `write-summary.sh` baseline (note whether the same approach applies or a richer protocol is needed).
3. Specify the argument encoding for the non-content parameters (milestone id, primary-artifact path, output packet path) — these stay positional/flag arguments; only the structured content goes via stdin.
4. Specify the escaping/quoting contract for multi-line fields (i.e. "none required — JSON handles it; the script does not re-shell-interpret field bodies").
5. Specify the LLM-instruction-template contract: the exact JSON shape the emitting agent must produce so it matches `write-decisions.sh`'s parser exactly (key names = FR-1 field names; one object per decision; top-level array under a named key, e.g. `{"decisions": [ ... ]}`).
6. Create `.orchestrator/milestones/M034/M034-P00-ADDENDUM.md` with frontmatter (`type: pre-planning-addendum`, `milestone: M034`, `phase: P00`) and the `## PC-1 — write-decisions.sh calling convention` section. Cite `specs/044-interactive-review-gates/spec.md` FR-1/FR-2/PC-1.

## Must-Haves

- The addendum's PC-1 section is zero-context-complete: a P01 implementer can build `write-decisions.sh` AND the LLM instruction template from it without further clarification (PC-1 acceptance criterion).

## Verification

`test -f .orchestrator/milestones/M034/M034-P00-ADDENDUM.md`
`grep -q "PC-1" .orchestrator/milestones/M034/M034-P00-ADDENDUM.md`
`grep -q "stdin" .orchestrator/milestones/M034/M034-P00-ADDENDUM.md`

## Notes

The T03 verifier (`tools/verify/m034-p00-addendum.sh`) performs the consolidated check at phase close; the inline checks above are the per-task fast-fail. Expected: all three `grep`/`test` commands exit 0. The recommended wire format (stdin JSON) is a recommendation, not a mandate — if inspecting `write-summary.sh` reveals a simpler convention that scales to multi-field content, document that instead, but the decision must be explicit and final.

## Inputs

### From Disk (Pre-existing)
- `scripts/knowledge/write-summary.sh` — the prior-art single-file bash writer; inspect its content-passing convention as the baseline.
- `specs/044-interactive-review-gates/spec.md` — FR-1 (the seven-field entry schema), FR-2 (writer modeled on write-summary.sh), and the "Pre-Planning Conditions" PC-1 acceptance criteria.

## Constraints

- Specification only — do NOT author `write-decisions.sh` (P01 deliverable).
- The convention must be safe for newlines and shell metacharacters in field bodies (the failure mode RISK-1 names).
- Single addendum file; this task CREATES it (T02/T03 append).

## Expected Output

`.orchestrator/milestones/M034/M034-P00-ADDENDUM.md` created with frontmatter + a complete `## PC-1` section specifying wire format, argument encoding, escaping contract, and the LLM-instruction-template JSON shape.
