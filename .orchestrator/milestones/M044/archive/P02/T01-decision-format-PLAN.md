---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M044"
---

# T01 — FR-1 decision format unification (one CI-checked change set)

## Zero-context summary

The official capture primitive `append-decision.sh` writes a decision row in
**producer-order** (`| ID | When | Scope | Decision | Choice | Rationale | Revisable |`),
but the dispatch consumer `scope-filter.sh::filter_decisions` reads it with
`awk -F'|'` at `$5`=Scope / `$6`=When (`:353-354`) — indices that only land on the
intended fields under **consumer-order** (`| ID | Decision | Choice | Scope | When | Rationale | Revisable |`).
The leading pipe makes `awk` field 1 empty, so the row resolves to the wrong
columns and the scope match silently never fires (B-3). This task flips the
producer (and the init-time header) to consumer-order. #Q-1 is RESOLVED:
consumer-order wins, producer is the loser, forward-only (no migration).

## Steps

1. `scripts/knowledge/append-decision.sh:93` — reorder the emitted row to
   `echo "| $next_id | $DECISION | $CHOICE | $SCOPE | $WHEN | $RATIONALE | $REVISABLE |"`.
   Same variables, reordered — no renames, no arg-order change (the CLI signature
   `<when> <scope> <decision> <choice> <rationale>` is unchanged; only the written
   column order changes).
2. `scripts/knowledge/append-decision.sh` docstring `# Column order:` line (`:7`)
   → update to `# Column order: #, Decision, Choice, Scope, When, Rationale, Revisable?`.
3. `scripts/lifecycle/scaffold.sh:89` — rewrite the init-time empty `DECISIONS.md`
   header to `| # | Decision | Choice | Scope | When | Rationale | Revisable? |`
   (and keep the separator row width at 7 columns).
4. `scripts/dispatch/scope-filter.sh:351` comment — correct to the awk reality:
   `# awk -F'|' fields (leading empty $1): $2=ID $3=Decision $4=Choice $5=Scope $6=When $7=Rationale`.
   **Leave the awk at `:353-354` unchanged** — it is already correct.
5. Add a one-line cross-ref comment in `append-decision.sh` noting the consumer
   contract (`scope-filter.sh filter_decisions`) so the producer↔consumer link is
   documented in-file (satisfies the P02 key-link).

## Out of scope (flag only — do NOT touch)

- `scripts/migrate/transform/decisions.sh` — a THIRD order (`ID|Scope|When|Decision|…`);
  external-tool migration, not the M044 producer/consumer contract.
- This repo's own `.orchestrator/DECISIONS.md` — a hand-maintained 7-col
  `category`-bearing variant, not `append-decision.sh` output.

## Verifier

`tools/verify/m044-p02-t01-decision-format.sh` — (a) `append-decision.sh` on an
ephemeral fixture emits a row whose `awk -F'|'` `$5` equals the SCOPE arg and `$6`
equals the WHEN arg; (b) the `scaffold.sh` init header line is consumer-order;
(c) the `scope-filter.sh` awk still reads `$5`/`$6` (unchanged). Emits `PASS:`/`FAIL:`.

## Done when

- `bash tools/verify/m044-p02-t01-decision-format.sh` → `PASS:`
- `append-decision.sh` + `scaffold.sh` + `scope-filter.sh` comment all agree on
  consumer-order; awk untouched.
