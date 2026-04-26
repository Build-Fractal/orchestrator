---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P06"
milestone: "M024"
provides:
  - "scripts/intake/axis-rederive.sh (pure decision emitter for dependent-axis recomputation); scripts/verify/m024-p06-axis-rederive.sh"
requires:
  - "P01 (templates/intake-proposal.md, scripts/intake/proposal-emit.sh, scripts/intake/shape-detect.sh, scripts/intake/intake-id-allocate.sh); P03 (closed-enum axis names from paragraph-classify.sh / approval-gate.sh)"
affects:
  - "P06/T02 (revise.sh consumes axis-rederive.sh once per operator override to build the --axes-from payload); P06/T03 (proposal-emit --axes-from flag relies on the dependent-axis lines this script emits); P07 (design_gate manual/skip branch already stubbed here)"
key_files:
  - "scripts/intake/axis-rederive.sh, scripts/verify/m024-p06-axis-rederive.sh"
key_decisions:
  - "Re-encode rule table from paragraph-classify.sh + spec-shape-classify.sh rather than refactor a shared lib (third call site can drive future extraction); independent axes (conversus_gate, intensity) emit nothing on stdout but write a stderr advisory `note=axis is independent — no dependents`; input_shape override is structural — exit 0 with stderr WARN instead of attempting re-derivation; proposal path is read-only, used only to source input_shape for forward-binding (P07 may diverge paragraph vs spec rules)"
patterns_established:
  - "Pure decision-emitter shape (no file writes — no `>` redirect, `cp`, `mv`, `mkdir`, `touch`, `sed -i`) reused from P03 route-* scripts; closed-enum first-failing-condition-wins validation with actionable error messages naming the supported set; `note=axis is independent — no dependents` stderr advisory pattern for no-op success; AD-19 single-script-file verify shape (every external invocation top-level, no `$(... | ...)` containing pipes)"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P06/tasks/T01-PAYLOAD.md, .orchestrator/milestones/M024/phases/P06/tasks/T01-PLAN.md"
duration: "5m"
verification_result: "pass"
completed_at: "2026-04-25T00:00:00Z"
---

## Summary

T01 ships the leaf decision emitter for the P06 revision flow: `scripts/intake/axis-rederive.sh`. Given a single primary-axis override and the parent proposal path, it emits the recomputed dependent-axis values to stdout as `key=value` lines. T02's `revise.sh` will invoke it once per operator override to build the `--axes-from <file>` payload it hands to `proposal-emit.sh`.

## What was built

- **`scripts/intake/axis-rederive.sh`** — pure decision emitter (no file writes, no side effects beyond stdout/stderr). Accepts `--axis <name> --value <value> --proposal <path>`. Implements the rule table re-encoded from `paragraph-classify.sh` and `spec-shape-classify.sh`:
  - `scope_tier=A` → `decomposition=single-task` + `recommended_command=orchestrator:dispatch`
  - `scope_tier=B` → `decomposition=single-phase` + `recommended_command=orchestrator:specify`
  - `scope_tier=C` → `decomposition=milestone-with-phases` + `recommended_command=orchestrator:specify`
  - `decomposition=single-task` → `recommended_command=orchestrator:dispatch`
  - `decomposition=single-phase` → `recommended_command=orchestrator:specify`
  - `decomposition=milestone-with-phases` → `recommended_command=orchestrator:specify`
  - `decomposition=multi-milestone` → `recommended_command=orchestrator:roadmap`
  - `design_gate=*` → no rederives (P07 owns the manual/skip branch)
  - `conversus_gate=*` / `intensity=*` → independent; stderr `note=axis is independent — no dependents`
  - `input_shape=*` → structural; stderr WARN advising re-run from scratch
- **`scripts/verify/m024-p06-axis-rederive.sh`** — single-script-file verify (AD-19) that generates a fresh paragraph proposal via `proposal-emit.sh`, exercises every rule-table branch, and asserts closed-enum validation rejects unknown axis names and invalid values with non-zero exit.

## Key decisions

- **Re-encode over shared library**: rule tables in `paragraph-classify.sh` and `spec-shape-classify.sh` are small enough that re-encoding is cheaper than refactoring three scripts to share a lib in P06. A future cleanup phase can extract the shared mapping once a third call site appears.
- **Proposal-aware shape lookup is forward-binding**: T01 reads `input_shape` from the proposal frontmatter even though P06 paragraph and spec rules happen to coincide. P07 may diverge them; T01 reserves the dispatch hook now so callers don't need to change.
- **Independent axes emit nothing on stdout**: `conversus_gate` and `intensity` re-derive nothing. The stderr advisory `note=axis is independent — no dependents` is pure observability — callers parse stdout, so a no-op stays clean.
- **`input_shape` override is structural**: rather than attempt to recompute everything downstream of a shape change, the script exits 0 with a stderr WARN advising the operator to re-run `orchestrator:evaluate` from scratch. Defends against subtle drift.

## Files changed

- Created: `scripts/intake/axis-rederive.sh` (executable)
- Created: `scripts/verify/m024-p06-axis-rederive.sh` (executable)

## Verification

`bash scripts/verify/m024-p06-axis-rederive.sh` exits 0 with:

```
note=axis is independent — no dependents
note=axis is independent — no dependents
PASS: axis-rederive — rule table covers scope_tier+decomposition; independent axes emit no lines; usage validation works
```

The two `note=` lines are stderr advisories from the conversus_gate and intensity test cases — confirming the independent-axis no-op path emits the right observability without polluting stdout.

## Concerns

None. T01 is the leaf task and the task plan's "Files To Touch" enumerates the full P06 write-set spanning T01–Tn — this task delivered exactly the two files named in the Steps section (axis-rederive.sh + its verify), and the rest are owned by T02–T04 (already planned per the task directory listing). No scope widening, no surprises.
