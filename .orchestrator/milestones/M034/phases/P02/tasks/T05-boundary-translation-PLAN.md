---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M034"
name: "boundary_translation packet type — producer + confirm-the-bridge surfacing + na action (FR-13, SC-8)"
depends_on: ["T02"]
---

## Prerequisites

- T02 complete: `interactive-review.sh` writes REVIEW.md blocks and handles the action enum (`accept`/`override`/`pushback`/`na`); `_packet_field` extractor exists.
- P01: `write-decisions.sh` accepts `{"decisions":[...]}` on stdin and emits typed entries; the schema already includes `type: boundary_translation` (`DECISIONS_TYPE_VALUES` in `decisions-constants.sh`).

## Description

Ship the FR-13 `boundary_translation` packet type — the lakeledger M066/P04-class
post-deploy-drift guard. A task declaring `touches_persistence: true` auto-emits
a `type: boundary_translation` entry recording the four bridge fields; the
walkthrough surfaces it as an explicit confirm-the-bridge decision; the `na`
action records acknowledged-not-applicable for a heuristic false-positive. v1 is
explicit-only (#Q-6 / D-P02-5) — the planner heuristic is advisory, documented in
T06's references doc, and does NOT auto-fire.

## Steps

1. **Author `scripts/knowledge/emit-boundary-translation.sh`** — bash 3.2
   single-file. It takes the four FR-13 fields as flags and emits/appends a
   `boundary_translation` entry by piping a `{"decisions":[...]}` document to
   `write-decisions.sh`:

   - Args: `--milestone=`, `--artifact=`, `--out=` (the packet path),
     `--id=` (default `BT-1`), `--source-vocab=`, `--target-vocab=`,
     `--transform-site=` (a `file:line` string), `--verify-mechanism=`,
     `--severity=` (default `block`).
   - Guard: all four bridge fields (`--source-vocab`, `--target-vocab`,
     `--transform-site`, `--verify-mechanism`) are REQUIRED; a missing one →
     error+exit 1 (the entry is worthless without the bridge it records).
   - Build the entry JSON with `jq -n` (so field bodies are losslessly encoded —
     RISK-1):
     ```bash
     doc="$(jq -n \
       --arg id "$ID" \
       --arg sv "$SOURCE_VOCAB" --arg tv "$TARGET_VOCAB" \
       --arg ts "$TRANSFORM_SITE" --arg vm "$VERIFY_MECHANISM" \
       --arg sev "$SEVERITY" '
       {decisions: [ {
         id: $id,
         summary: ("Boundary translation: " + $sv + " -> " + $tv),
         picked_value: ($sv + " -> " + $tv + " @ " + $ts),
         rationale: ("Persistence/protocol/format boundary: plan vocabulary \"" + $sv + "\" maps to target vocabulary \"" + $tv + "\". Verification: " + $vm + "."),
         alternatives_considered: "n/a (boundary translation is a recorded bridge, not a chosen option)",
         concrete_impact: ("If the bridge is wrong, the first real run throws at " + $ts + " (e.g. no-such-column). Verify via: " + $vm + "."),
         severity: $sev,
         type: "boundary_translation",
         source_vocab: $sv,
         target_vocab: $tv,
         transform_site: $ts,
         verify_mechanism: $vm
       } ] }')"
     printf '%s' "$doc" | bash "$WRITER" --milestone="$MILESTONE" --artifact="$ARTIFACT" --out="$OUT"
     ```
     NOTE: `write-decisions.sh` only emits the eight FR-1 fields per block (it
     ignores extra JSON keys). To make the four bridge fields readable in the
     packet, ALSO ensure they land in the block: write-decisions emits a fixed
     field set, so encode the four fields inside `picked_value` + `concrete_impact`
     + `rationale` (done above) so they survive the writer. The four-fields
     assertion (SC-8) reads them from those bodies. (Do NOT modify
     write-decisions.sh — keep the boundary_translation extra-field handling in
     this producer's text encoding.)

   Re-check SC-8's exact requirement before finalizing: the entry must carry all
   four fields recoverably. The encoding above puts `source_vocab`,
   `target_vocab`, `transform_site`, and `verify_mechanism` verbatim into the
   `summary`/`picked_value`/`concrete_impact` bodies, so a grep for each of the
   four input strings in the emitted packet succeeds.

2. **Add confirm-the-bridge surfacing** to `interactive-review.sh`. In the
   REVIEW.md block writer path (the `_run_test_responses` loop and, by extension,
   the headless/interactive paths), when a decision's `type` is
   `boundary_translation` (read via `_packet_field "$PACKET" "$id" type`), the
   block records an extra `- **gate_kind**: confirm-the-bridge` line so the audit
   trail distinguishes a bridge-confirmation from an ordinary decision. The `na`
   action on such an entry records `- **rationale**: <fixture rationale>` plus
   `- **acknowledged_not_applicable**: true` (the FR-13 "operator can mark N/A"
   edge case — recorded in REVIEW.md, still counts reviewed via `reviewed: <id>`).

   Implement minimally: in `_append_review_block`, accept an optional 7th arg
   `gate_kind`; when the caller passes `confirm-the-bridge`, emit the
   `- **gate_kind**:` line; when `action==na`, emit
   `- **acknowledged_not_applicable**: true`. The `_run_test_responses` loop
   computes `gate_kind` from `_packet_field ... type` per id.

3. **Co-author** `tools/verify/m034-p02-boundary-translation.sh` (see Verification).

## Must-Haves

- `emit-boundary-translation.sh` with the four bridge fields produces a `type: boundary_translation` packet entry from which all four field values are recoverable (grep-able) in the emitted `*-DECISIONS.md`.
- Missing any of the four bridge fields → the producer errors (exit non-zero).
- A `boundary_translation` entry surfaced through `interactive-review.sh --test-responses` records `gate_kind: confirm-the-bridge` in its REVIEW.md block.
- The `na` action on a `boundary_translation` entry records acknowledged-not-applicable AND `reviewed: <id>` (counts reviewed).

## Verification

```bash
bash tools/verify/m034-p02-boundary-translation.sh
```

## Inputs

### From Previous Tasks
- `scripts/lifecycle/interactive-review.sh` (from T02) — `_append_review_block` (extend with the optional `gate_kind` arg), `_packet_field`, `_run_test_responses` loop.
- `scripts/knowledge/lib/decisions-constants.sh` (from T01) — `DECISIONS_ACTION_VALUES` includes `na`.

### From Disk (Pre-existing)
- `scripts/knowledge/write-decisions.sh` — the stdin-JSON writer this producer pipes into; emits the eight FR-1 fields per block (ignores extra JSON keys), so the four bridge fields are encoded into the FR-1 body fields.
- `scripts/knowledge/lib/decisions-constants.sh` — `DECISIONS_TYPE_VALUES` already includes `boundary_translation` (P01).
- spec FR-13 + Edge Case "Boundary-translation heuristic false-positive" — the na/acknowledged-not-applicable contract.

## Constraints

- CON-1: bash 3.2 single-file; jq for entry construction (already a write-decisions dependency).
- D-P02-5 / #Q-6: explicit `touches_persistence` path only; the producer is invoked deliberately, NOT auto-fired by a heuristic. Do not add heuristic auto-detection in v1.
- RISK-1: all field bodies pass through `jq -n --arg` (lossless) → `write-decisions.sh` (quoted) — never `eval`.
- Do NOT modify `write-decisions.sh` (a closed P01 deliverable) — keep all boundary_translation specifics in this producer + interactive-review.sh.

## Expected Output

See `## Notes`.

## Notes

`bash tools/verify/m034-p02-boundary-translation.sh` runs
`emit-boundary-translation.sh` with source-vocab `surface_acres`, target-vocab
`surface_area_acres`, transform-site `models/lake.py:42`, verify-mechanism
`real-DB column-existence check`, and asserts all four strings appear in the
emitted `*-DECISIONS.md` and the entry's `type` is `boundary_translation`. It
then drives `interactive-review.sh --test-responses` with an `na` action for the
BT entry and asserts the REVIEW.md block carries `gate_kind: confirm-the-bridge`,
`acknowledged_not_applicable: true`, and `reviewed: BT-1`. It also asserts the
producer errors when `--verify-mechanism` is omitted. Prints `PASS: m034-p02
boundary-translation` + exit 0, else `FAIL: ... — <reason>` + exit 1.
