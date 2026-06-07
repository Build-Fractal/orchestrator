---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P02"
milestone: "M034"
name: "CC AskUserQuestion renderer surface (FR-6) + phase-suite aggregator"
depends_on: ["T01", "T02", "T03", "T04", "T05"]
---

## Prerequisites

- T01–T05 complete: the five slice verifiers `tools/verify/m034-p02-{renderer-probe,test-responses,auto-policies,resume-roundtrip,boundary-translation}.sh` all exist and pass; `interactive-review.sh` has the `_emit_interactive_descriptor` stub (marker `# >>> T06 fills this`).

## Description

Complete the CC `AskUserQuestion` renderer surface (FR-6) — the interactive-cc
path per Case A (`M034-P00-ADDENDUM.md`): the orchestrating agent issues
`AskUserQuestion` per decision and writes `REVIEW.md` directly. This task fills
the `_emit_interactive_descriptor` stub so `interactive-review.sh` emits a
render-descriptor (a coordination boundary mirroring `local-agent.sh`), authors
the agent-facing walkthrough instructions in `references/interactive-review-renderer.md`,
and authors the phase-suite aggregator that gates the whole phase.

## Steps

1. **Author `references/interactive-review-renderer.md`** (min 30 lines). The
   agent-facing instruction surface for the interactive-cc walkthrough. Sections:
   - **When this runs** — `interactive-review.sh` resolved `renderer=interactive-cc`
     and emitted a render-descriptor; the orchestrating agent (top-level CC
     session, Case A) performs the walkthrough in-process.
   - **How to walk through the packet** — for each active decision in
     `*-DECISIONS.md` (use `read-decisions.sh active-ids`), surface it via
     `AskUserQuestion` with concrete-impact framing drawn from the entry's
     `summary` / `picked_value` / `concrete_impact` / `alternatives_considered`.
     Offer accept / override / push-back (and, for `type: boundary_translation`
     entries, confirm-the-bridge / mark N/A).
   - **How to record** — append one REVIEW.md block per response in the
     `templates/review.md` shape (ending `reviewed: <id>`), then populate
     SIGNOFF.md from the terminal entry. The agent writes REVIEW.md DIRECTLY
     (Case A); `interactive-review.sh` does NOT write it on this path.
   - **boundary_translation heuristic (advisory, #Q-6)** — note that v1 emits
     boundary_translation entries ONLY for explicit `touches_persistence: true`;
     the planner heuristic (SQL reads / migrations / ORM / format readers /
     protocol parsers) is advisory and does NOT auto-fire. The literal token
     `AskUserQuestion` MUST appear in the file.

2. **Replace the `_emit_interactive_descriptor` stub** in `interactive-review.sh`.
   It emits a render-descriptor on stdout (Case A coordination boundary,
   mirroring `local-agent.sh`'s descriptor) and exits 0. Shape:
   ```
   ---
   schema_version: "1.0"
   type: "interactive-review-descriptor"
   renderer: "<interactive-cc|interactive-cursor>"
   gate_id: "<GATE_ID>"
   packet: "<PACKET>"
   review_out: "<REVIEW_OUT>"
   signoff_out: "<SIGNOFF_OUT>"
   ---

   # Interactive Review — orchestrating-agent action required

   Render the decision packet at <PACKET> interactively per
   references/interactive-review-renderer.md: surface each active decision via
   the runtime question primitive (AskUserQuestion for interactive-cc; Cursor MCP
   elicitation for interactive-cursor, P03), append one REVIEW.md block per
   response to <REVIEW_OUT>, and populate <SIGNOFF_OUT> from the terminal entry.

   Renderer: <renderer> (Case A — agent issues the question primitive in-process)
   Reference: references/interactive-review-renderer.md
   ```
   The descriptor's Notes point the agent at the references doc — the agent, not
   bash, issues the question primitive (CON-7 / AD-3 / Case A).

3. **Author the phase-suite aggregator `tools/verify/m034-p02-phase-suite.sh`**
   (min 15 lines; the single entry point `orchestrator:verify P02` resolves to).
   It runs the five slice verifiers in order (plain `bash <path>`, never
   run-probe — Plan-Time Discipline rule 4), prints each one's output, and
   additionally asserts the FR-6 surface: `references/interactive-review-renderer.md`
   exists and contains `AskUserQuestion`, AND `interactive-review.sh` contains
   `interactive-review-descriptor` (the render-descriptor type). Mirror the
   structure of `tools/verify/m034-p01-phase-suite.sh` (read it):
   - iterate `for slice in renderer-probe test-responses auto-policies resume-roundtrip boundary-translation`,
     `bash "$REPO_ROOT/tools/verify/m034-p02-$slice.sh"`, accumulate failures;
   - then the FR-6 assertion block;
   - print `PASS: m034-p02 phase-suite (5/5 slices + FR-6 surface)` + exit 0 iff
     all green, else `FAIL: m034-p02 phase-suite — <which>` + exit 1.

## Must-Haves

- `references/interactive-review-renderer.md` exists, documents the interactive-cc walkthrough, and contains `AskUserQuestion`.
- `interactive-review.sh`'s interactive-cc path emits a render-descriptor (`type: interactive-review-descriptor`) pointing the agent at the references doc.
- `tools/verify/m034-p02-phase-suite.sh` runs all five slice verifiers + asserts the FR-6 surface; green only when every slice passes.

## Verification

```bash
bash tools/verify/m034-p02-phase-suite.sh
```

## Inputs

### From Previous Tasks
- `tools/verify/m034-p02-{renderer-probe,test-responses,auto-policies,resume-roundtrip,boundary-translation}.sh` (T01–T05) — the five slice verifiers the aggregator runs.
- `scripts/lifecycle/interactive-review.sh` (T02–T05) — the `_emit_interactive_descriptor` stub to replace; vars `GATE_ID`/`PACKET`/`REVIEW_OUT`/`SIGNOFF_OUT`.

### From Disk (Pre-existing)
- `tools/verify/m034-p01-phase-suite.sh` — the structural model for the aggregator (slice loop + addendum assertion + PASS/FAIL contract).
- `scripts/dispatch/adapters/backend/local-agent.sh` — the coordination-boundary descriptor pattern the interactive-cc descriptor mirrors.
- `M034-P00-ADDENDUM.md` §PC-2 — the Case A determination (agent writes REVIEW.md directly on the interactive path).

## Constraints

- CON-1: bash 3.2 single-file for the aggregator + the descriptor emission.
- Plan-Time Discipline rule 4: the aggregator invokes verifiers via `bash <path>` directly, never `run-probe.sh` (these are repo-tree verifiers).
- AD-19 / naming: the aggregator is milestone-prefixed (`m034-p02-phase-suite.sh`) under `tools/verify/` (project-owned).
- The interactive-cc path emits a descriptor and exits 0; it does NOT itself call any question primitive (CON-7 — the agent does, in-process).

## Expected Output

See `## Notes`.

## Notes

`bash tools/verify/m034-p02-phase-suite.sh` prints each slice verifier's output
followed by `PASS: m034-p02 phase-suite (5/5 slices + FR-6 surface)` + exit 0
when all five slices pass AND the FR-6 surface is present. On any slice failure
or a missing FR-6 surface it prints `FAIL: m034-p02 phase-suite — <which failed>`
+ exit 1. This is the command `orchestrator:verify P02` and the phase Must-Have
`Check:` commands resolve to.
