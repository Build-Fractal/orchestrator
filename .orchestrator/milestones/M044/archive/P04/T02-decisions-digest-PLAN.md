---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M044"
---

# T02 — FR-6 bounded budget-bounded Decisions digest at Quick

## Zero-context summary

`build-context.sh` direct-mode (Quick) payload assembly omits the Decisions section
entirely: `:344 if [ "$PROFILE" != "quick" ]` guards the `## Decisions` block, and
even at non-quick it emits only a marker. So a Quick project's inject has no
decisions (G-2) — an empty-forever Decisions slot. Add a bounded, budget-bounded
digest at Quick.

## Steps

1. Add a `_bc_decisions_digest <decisions_file> <budget_tokens> <max_rows>` helper
   (near the other `_bc_*` helpers). It:
   - returns nothing if the file is absent or has no `^\| D###` data rows;
   - takes the last `max_rows` data rows, ranks newest-first;
   - builds a governor chunk-list (`D###|<ceil(chars/4)>|<tmp-row-file>` per row);
   - routes through `reference_apply_budget` (CON-2) — defensively sourcing
     `scripts/dispatch/lib/reference-budget.sh` if the function isn't loaded;
   - emits the surviving rows (path column) in governor order. Deterministic: file
     order is the rank, no wall-clock (CON-3).
2. In the direct-mode payload block (`:344`), replace the `!= quick` omission with an
   always-emitted `## Decisions` section whose body is the digest of
   `$_M031_PROJECT_ROOT/.orchestrator/DECISIONS.md` (budget
   `${KP_FALLBACK_BUDGET_TOKENS:-2000}`, `max_rows ${QUICK_DECISIONS_DIGEST_MAX:-10}`).
   When the digest is empty, emit a `(no decisions on record)` sentinel so the
   section header still parses (parity with the knowledge `(no qualifying…)` shape).

## Verifier

`tools/verify/m044-p04-t02-decisions-digest.sh`:
- a Quick `build-context.sh --profile=quick` inject over a fixture project with a
  consumer-order `.orchestrator/DECISIONS.md` → asserts a `## Decisions` section is
  present and contains a captured decision row.
- determinism: two identical runs → byte-identical `## Decisions` body.
- budget: a fixture with many oversized rows → the digest token total stays within
  budget (governor applied); the `reference-budget.sh` source line is present in
  build-context.sh (CON-2 wiring).

## Done when

- `bash tools/verify/m044-p04-t02-decisions-digest.sh` → `PASS:`
- The Quick inject carries a `## Decisions` digest; existing M031/M018 build-context
  regressions stay green.
