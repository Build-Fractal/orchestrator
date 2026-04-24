---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M026"
name: "Synthesis-crux spike + GO/NO-GO gate file"
depends_on: []
---

## Prerequisites

- `~/Sites/conversus-oss/linter/output_contract.py` readable on disk (confirmed 2026-04-23: file exists per `ls ~/Sites/conversus-oss/linter/`).
- `~/Sites/conversus-oss/engine/pipeline.py` readable on disk.
- `scripts/dispatch/adapters/tool/conversus.sh` in this repo, specifically the python-invocation at approximately line 298 that calls `python -m linter.output_contract <synthesis> --mode <mode>` and parses JSON containing `quality_indicators.genuine_disagreements_surviving`, `headline`, `summary`.
- `~/Sites/conversus-oss/presets/` directory for a red-blue preset to examine the synthesis-phase shape end-to-end on OSS (preferred) or `~/Sites/conversus-oss/conversus.example.yml` as fallback.

## Description

Run the DC-6 synthesis-crux spike: determine whether OSS's red-blue pipeline produces (or can be made to produce) content the orchestrator's adapter can parse into its four expected fields (`verdict`, `disputes`, `rationale`, `source_hash`). The spike is fs-inspection plus at most a single `conversus validate` invocation (mock provider; no network). No writes to the OSS tree. Output: a single `Verdict: GO` or `Verdict: NO-GO` line in `SPIKE-SYNTHESIS-CRUX.md` and a matching `P01-SPIKE-GATE.md` file P02 plan-phase reads.

**What GO means.** OSS ships `linter/output_contract.py` with a callable interface importable as `python -m linter.output_contract` that accepts a synthesis-phase output file + a `--mode` flag and emits JSON containing AT LEAST the three adapter-consumed keys (`quality_indicators.genuine_disagreements_surviving`, `headline`, `summary`) OR an equivalent shape the adapter can be updated to consume WITHIN the FR-1/FR-2 resolver-flip scope without breaking the `gate-result.md` frontmatter contract (FR-7/CON-1).

**What NO-GO means.** OSS either lacks `linter/output_contract.py`, or ships it under a non-importable path, or its red-blue pipeline terminal-phase output cannot be parsed into the adapter-expected key set, AND no lightweight adapter-side change inside M026's scope can bridge the gap. In this case P02 halts and the operator decides: (a) narrow scope per OQ-2 (ship resolver-flip + env var only, defer JSONL + preset-frontmatter + dual-edition-test to a follow-up); (b) escalate with a new D-row capturing the rehomed `linter.output_contract`-equivalent decision; (c) hand off to an OSS-upstream PR per the spec 025 `CONVERSUS-PR-HANDOFF.md` pattern.

## Steps

1. **Confirm the OSS linter/output_contract.py surface.** Read `~/Sites/conversus-oss/linter/output_contract.py` in full. Capture:
   - The module's public entry point (e.g., `if __name__ == '__main__':` block or `main()` function).
   - The CLI shape: does it accept a positional synthesis-file arg + `--mode` flag? Or a different shape?
   - The output JSON key set. Specifically whether the keys `quality_indicators.genuine_disagreements_surviving`, `headline`, `summary` are present, and under what nesting.
   - Any mode-specific branching (e.g., red-blue vs cooperative).

2. **Locate OSS's red-blue synthesis-phase output.** Read `~/Sites/conversus-oss/engine/pipeline.py` and trace the red-blue phase ordering. Specifically: does the pipeline end at `synthesis` (as oss-early-review.md observed in the mock invocation) or at `arbitration`? What file does the synthesis phase write (e.g., `summary/final.md`, `synthesis/final.md`, or a different path)? Record the exact phase-terminal file path convention OSS uses.

3. **Cross-check against the orchestrator's adapter expectation.** Read `scripts/dispatch/adapters/tool/conversus.sh` around line 285-300 (the block that reads back `<output>/summary/final.md` and invokes `python -m linter.output_contract`). Note: the adapter currently expects `summary/final.md` and consumes three keys from the module's JSON output. Record the adapter's exact expectations.

4. **Determine a minimal-viable parseability path.** Using only the OSS-tree file inspections from steps 1-3, answer the three questions:

   **Q1: Does `python -m linter.output_contract` run on the OSS tree?** Run (no network, mock-only): `cd ~/Sites/conversus-oss && python -m linter.output_contract --help 2>&1` or equivalent. Capture exit code + first 20 lines of output. If the module is importable, answer Q1=YES.

   **Q2: Does the OSS red-blue terminal phase write a file at `summary/final.md` or an equivalent path the adapter can point at?** Trace `pipeline.py`. Answer Q2=YES/NO with the exact output-path convention.

   **Q3: Does `linter.output_contract`'s JSON output contain the three adapter-consumed keys, or a documented superset/rename that the adapter can trivially adapt to within P02's ~30-line adapter-patch budget?** Inspect the module's emit/print paths. Answer Q3=YES/NO with the observed key set.

5. **Decide the verdict per DC-6.**
   - **Q1=YES AND Q2=YES AND Q3=YES** → `Verdict: GO`. Adapter's current logic works on OSS unchanged modulo the resolver flip P02 handles.
   - **Q1=YES AND Q2=YES AND Q3=NO (key rename only)** → `Verdict: GO` with a P02 addendum: the adapter's key-parsing lines adapt within the P02 scope budget. Record the rename map in the Rationale.
   - **Any Q=NO in a way that requires upstream work** → `Verdict: NO-GO`. Record the blocker and cite the halt-options.

6. **Author `SPIKE-SYNTHESIS-CRUX.md`** at `.orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md`:

   ```markdown
   ---
   schema_version: "1.0"
   type: spike-report
   phase: "P01"
   task: "T02"
   milestone: "M026"
   status: final
   created_at: "2026-04-23"
   ---

   # DC-6 Synthesis-Crux Spike — OSS linter.output_contract parseability

   ## Method

   - Inspected `~/Sites/conversus-oss/linter/output_contract.py` lines <N-M>.
   - Inspected `~/Sites/conversus-oss/engine/pipeline.py` lines <N-M> (red-blue phase chain).
   - Cross-referenced `scripts/dispatch/adapters/tool/conversus.sh:285-300` (adapter's read-back + linter invocation).
   - (optional) Invoked `python -m linter.output_contract --help` against the OSS venv for importability confirmation.

   ## Findings

   ### Q1: `python -m linter.output_contract` runs on OSS
   <YES/NO + evidence>

   ### Q2: OSS red-blue terminal phase writes `summary/final.md` (or equivalent)
   <YES/NO + exact path + evidence>

   ### Q3: linter.output_contract JSON contains the three adapter-consumed keys
   <YES/NO + observed key set + evidence>

   ## Verdict

   Verdict: <GO|NO-GO>

   ## Rationale

   <One or more paragraphs grounding the verdict in Q1/Q2/Q3. On GO: name any
   minor adapter-side adaptation P02 absorbs. On NO-GO: name the specific blocker
   and cite the halt options (OQ-2 narrow-scope, new D-row, upstream handoff).>
   ```

7. **Author `P01-SPIKE-GATE.md`** at `.orchestrator/milestones/M026/phases/P01/P01-SPIKE-GATE.md` — the machine-readable gate file P02 reads:

   On GO:
   ```markdown
   ---
   schema_version: "1.0"
   type: spike-gate
   phase: "P01"
   milestone: "M026"
   ---
   gate=GO
   spike_report=.orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md
   ```

   On NO-GO:
   ```markdown
   ---
   schema_version: "1.0"
   type: spike-gate
   phase: "P01"
   milestone: "M026"
   ---
   gate=NO-GO
   spike_report=.orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md

   ## Halt

   P02 is blocked. Operator decision required between:
   1. Narrow scope per OQ-2 (ship FR-1 + FR-2 + FR-3 minimally; defer FR-4/FR-8/FR-10/FR-11 to a follow-up milestone).
   2. Escalate with a new D-row in `.orchestrator/DECISIONS.md` capturing the rehomed `linter.output_contract`-equivalent decision.
   3. Hand off to an OSS-upstream PR per the `specs/025-knowledge-layer-maturation/conversus/CONVERSUS-PR-HANDOFF.md` pattern.

   Cite: `.orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md` Verdict section.
   ```

## Must-Haves

This task satisfies the phase truths:
- "SPIKE-SYNTHESIS-CRUX.md exists with required frontmatter + body structure" (spike-note-shape truth).
- "P01-SPIKE-GATE.md contains a single `gate=GO|NO-GO` line" (spike-gate-file truth).

## Verification

```
bash scripts/verify/m026-p01-spike-note-shape.sh
bash scripts/verify/m026-p01-spike-gate-file.sh
bash scripts/verify/m026-p01-upstream-readonly.sh
```

Each verifier uses single-script-file shape per AD-19.

Expected: `SUMMARY: pass=N fail=0` per script, exit 0.

## Inputs

### From Previous Tasks
- None (T02 runs in parallel with T01 + T03).

### From Disk (Pre-existing)
- `~/Sites/conversus-oss/linter/output_contract.py` — the module under test (read-only).
- `~/Sites/conversus-oss/engine/pipeline.py` — pipeline phase ordering (read-only).
- `scripts/dispatch/adapters/tool/conversus.sh:285-300` — adapter's synthesis-read-back + linter invocation (read-only).
- `.orchestrator/milestones/M026/M026-CONTEXT.md` — DC-6 constraint (read-only).
- `specs/027-conversus-oss-migration/conversus/oss-early-review.md` — smoke-test evidence that OSS red-blue terminates at `synthesis` (read-only).

## Constraints

- **CON-5 read-only on conversus trees**: no writes or commits under `~/Sites/conversus-oss`.
- **No network**: the spike does not hit Anthropic/ollama/any provider. If `python -m linter.output_contract --help` is invoked for importability confirmation, it runs with mock data only.
- **Output-path budget**: the spike writes exactly two files: `SPIKE-SYNTHESIS-CRUX.md` + `P01-SPIKE-GATE.md`. Both under `.orchestrator/milestones/M026/phases/P01/`. No other writes.
- **Verdict vocabulary is fixed**: `Verdict: GO` or `Verdict: NO-GO` — no `MAYBE`, `INCONCLUSIVE`, `PARTIAL`. The DC-6 gate is binary by design. Ambiguous findings default to `NO-GO` + halt (operator decides on narrow-scope or upstream-handoff from there).

## Expected Output

- `.orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md` — 50+ lines, four-section body (Method / Findings / Verdict / Rationale).
- `.orchestrator/milestones/M026/phases/P01/P01-SPIKE-GATE.md` — `gate=GO` or `gate=NO-GO` single-line value plus frontmatter; on NO-GO, a Halt section.
- No writes under `~/Sites/conversus*` or anywhere outside `.orchestrator/milestones/M026/phases/P01/`.
