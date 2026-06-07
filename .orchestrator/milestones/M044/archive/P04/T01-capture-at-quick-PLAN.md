---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M044"
---

# T01 — FR-8/G-1 explicit-decision capture at Quick

## Zero-context summary

`intensity-knowledge.sh` is the intensity-gated knowledge-pipeline runner. At Quick
(`:92-95`) it runs only `write-summary.sh` — it never captures decisions (G-1). So a
Quick project that makes an explicit decision can't record it through the gate. The
fix: an explicit-decision path that runs the legacy `append-decision.sh` primitive at
ANY intensity (DQ-7 — no net-new verb), independent of the intensity-gated auto steps.

## Steps

1. Add a repeatable `--decision-arg <value>` flag. Accumulate values into a bash-3.2
   indexed array `decision_argv` (each value is one positional arg for
   `append-decision.sh`: `<decisions-file> <when> <scope> <decision> <choice>
   <rationale> [revisable]`).
2. Track `has_explicit_decision` = (count of `decision_argv` > 0).
3. After the intensity-gated step loop, if `has_explicit_decision`: run
   `append-decision.sh "${decision_argv[@]}"` (NOT via `$FORWARD_ARGS` — its own
   argv). In `--dry-run`, emit `WOULD_RUN: $SCRIPT_DIR/append-decision.sh <args>`.
   This runs at every intensity, including Quick.
4. Leave the auto-pipeline step membership untouched: with NO `--decision-arg`, Quick
   still plans exactly `write-summary.sh` (the m008 step-count tests stay green).
5. Update the header docstring to document the explicit-decision path.

## Verifier

`tools/verify/m044-p04-t01-capture-at-quick.sh`:
- dry-run `--intensity Quick` with NO decision args → exactly one `WOULD_RUN:`
  (`write-summary.sh`), no `append-decision.sh` (regression guard for m008).
- dry-run `--intensity Quick --decision-arg <f> --decision-arg <when> …` → plans
  `append-decision.sh` (the explicit path fires at Quick).
- live `--intensity Quick --decision-arg <file> --decision-arg M044/P01 --decision-arg arch …`
  on an ephemeral DECISIONS.md → asserts the row is appended (consumer-order, awk
  `$5`=Scope/`$6`=When holds — composes P02).

## Done when

- `bash tools/verify/m044-p04-t01-capture-at-quick.sh` → `PASS:`
- `bash scripts/verify/m008-p03-knowledge-pipeline.sh` and
  `bash scripts/verify/m008-p03-integration-e2e.sh` stay green.
