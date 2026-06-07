---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M034"
name: "PC-5 resume round-trip — interactive-review.sh --resume + commands/resume.md branch (SC-4)"
depends_on: ["T03"]
---

## Prerequisites

- T03 complete: the `defer` policy writes a `<gate_id>-CONTINUE.md` continue-file (PC-5 schema) + a `pending_review` JSONL event.
- T02: `interactive-review.sh` has the `_run_resume` stub (marker `# >>> T04 fills this`), the `_run_test_responses` path, and the REVIEW/SIGNOFF helpers.
- `commands/resume.md` exists (the M029 resume surface to extend).

## Description

Close the PC-5 round-trip: implement `interactive-review.sh --resume=<continue-file>`
so a deferred gate re-enters at the recorded `last_review_md_block_index` WITHOUT
re-writing the already-recorded blocks, completes the remaining decisions, and
populates SIGNOFF. Extend `commands/resume.md` with the `pending-review-continue`
state-scan branch that routes a `type: pending-review-continue` continue-file to
`interactive-review.sh --resume`. This is SC-4's "extended round-trip"
(re-entry at the recorded position, not a restart).

## Steps

1. **Replace the `_run_resume` stub** in `interactive-review.sh`. The function:
   1. `[ -f "$RESUME_FILE" ]` else error+exit 1.
   2. Parse the continue-file frontmatter (grep + sed, the same idiom
      `render-status-json.sh` uses) to read: `milestone_id`, `phase_id`,
      `gate_id`, `last_review_md_block_index`, `packet_path`, `review_md_path`.
      Overwrite the run vars from these (so `--resume` needs no other flags):
      `MILESTONE`/`PHASE`/`GATE_ID`/`PACKET`/`REVIEW_OUT`; derive `SIGNOFF_OUT`
      from `PACKET` as in T02. Validate `[ -f "$PACKET" ]` else error+exit 3.
   3. `resume_idx=<last_review_md_block_index>`.
      `current=$(_review_block_count "$REVIEW_OUT")` — blocks already on disk.
      Re-entry guarantee: only decisions whose position is `> resume_idx` are
      pending. Build the ordered active-id list
      `ids="$(bash "$READER" active-ids "$PACKET")"`; the already-recorded ids
      are those marked `reviewed: <id>` in REVIEW_OUT (use
      `read-decisions.sh unreviewed-count` semantics — or directly: an id is
      pending iff NOT already `reviewed:` in REVIEW_OUT). Iterate the active ids;
      SKIP any id already reviewed (so re-entry never double-writes a block);
      for each pending id, record a response.
   4. **Response source on resume**: if `--test-responses=<path>` is ALSO passed
      (the deterministic verifier path), read the remaining responses from that
      fixture exactly as `_run_test_responses` does (action/value/rationale, with
      default-accept for absent ids). If `--test-responses` is NOT passed, the
      resume runs under whatever renderer the probe resolves (interactive-cc →
      the agent walkthrough completes it; headless → re-defer is a no-op error).
      For P02's verifier, the `--test-responses` resume path is the asserted one.
      Append one REVIEW.md block per pending id (continuing the block index from
      `current`), each ending `reviewed: <id>`.
   5. `_populate_signoff "$SIGNOFF_OUT" <final_block_count> "${ORCH_REVIEWER:-operator}"`.
   6. Append a `review_resumed` JSONL event via `_emit_event`:
      `{"record_type":"review_resumed","milestone":"<M>","phase":"<P>","gate_id":"<g>","resumed_from_block":<resume_idx>,"timestamp":"<iso>"}`.
   7. Remove the consumed continue-file (`rm -f "$RESUME_FILE"`) — the continue-
      file is consumed on resume (mirrors resume.md Path A A3).
   8. Print `INTERACTIVE-REVIEW: resumed gate <GATE_ID> from block <resume_idx> -> SIGNOFF` and `exit 0`.

2. **Extend `commands/resume.md`** — add a new top-level recovery branch, placed
   AFTER "Recovery Type Detection" and BEFORE "Path A", titled
   `## Pending-Review Continue (M034 PC-5)`. Prose contract:
   - During recovery-artifact location, ALSO scan
     `<milestone-dir>/phases/*/` for files matching `*-CONTINUE.md` whose
     frontmatter carries `type: pending-review-continue`.
   - When one is found, this is a deferred interactive review gate (not a crash,
     not a generic pause). Route recovery to:
     ```bash
     bash scripts/lifecycle/interactive-review.sh --resume=<path-to-CONTINUE.md>
     ```
     which re-enters the walkthrough at `last_review_md_block_index` and completes
     the remaining decisions. This branch is additive to the existing pause
     (Path A) / crash (Path B) branches — neither is changed. The literal token
     `pending-review-continue` MUST appear in the file.
   - Note idempotency: `interactive-review.sh --resume` deletes the continue-file
     on success, so a second resume finds none and falls through.

3. **Co-author** `tools/verify/m034-p02-resume-roundtrip.sh` (see Verification).

## Must-Haves

- `interactive-review.sh --resume=<continue-file>` reads `last_review_md_block_index` from the continue-file and re-enters at that position, appending blocks ONLY for decisions not already recorded (no double-write).
- After resume completes the remaining decisions, SIGNOFF.md is populated and `read-decisions.sh unreviewed-count <packet>` returns 0.
- The consumed continue-file is removed on successful resume.
- `commands/resume.md` contains a `pending-review-continue` branch routing to `interactive-review.sh --resume`.

## Verification

```bash
bash tools/verify/m034-p02-resume-roundtrip.sh
```

## Inputs

### From Previous Tasks
- `scripts/lifecycle/interactive-review.sh` (from T02/T03)
  - Key API: `_run_resume` stub to replace; `_review_block_count`, `_append_review_block`, `_populate_signoff`, `_ensure_review_header`, `_emit_event`; vars `RESUME_FILE`, `TEST_RESPONSES`, `READER`, `REPO_ROOT`.
- T03's `defer` path — writes the `<gate_id>-CONTINUE.md` this task consumes (the PC-5 schema with `last_review_md_block_index`).

### From Disk (Pre-existing)
- `commands/resume.md` — the M029 resume surface; the new branch is additive to Path A / Path B.
- `M034-P01-ADDENDUM.md` §PC-5 — the binding continue-file schema + the resume state-scan extension contract.
- `scripts/knowledge/read-decisions.sh` — `active-ids` / `unreviewed-count` for the pending-id determination.

## Constraints

- CON-1: bash 3.2 single file; frontmatter parse via grep+sed (no yaml lib).
- Re-entry MUST NOT re-write already-recorded REVIEW.md blocks (the "operator answers, then crash before SIGNOFF" edge case — partial answers survive, resume continues from them).
- REVIEW.md stays append-only across the defer→resume boundary.
- The `commands/resume.md` edit is additive: do not alter Path A or Path B.

## Expected Output

See `## Notes`.

## Notes

`bash tools/verify/m034-p02-resume-roundtrip.sh` builds a fixture packet (≥3
active decisions) and a fixture response file covering all of them. STEP 1: run
`interactive-review.sh --policy=defer` under `ORCH_HEADLESS=1` +
`ORCH_EVENT_LOG=<scratch>` — assert exit 0, a `<gate>-CONTINUE.md` with
`last_review_md_block_index: 0`, and SIGNOFF NOT yet populated. (Optionally
pre-seed one REVIEW.md block to assert mid-stream re-entry at index 1.) STEP 2:
run `interactive-review.sh --resume=<continue-file> --test-responses=<fixture>` —
assert it appends blocks for the remaining decisions (no duplicate ids), removes
the continue-file, populates SIGNOFF, and drives `read-decisions.sh
unreviewed-count` to 0. Assert a `review_resumed` line in the scratch log. Prints
`PASS: m034-p02 resume-roundtrip` + exit 0, else `FAIL: m034-p02
resume-roundtrip — <reason>` + exit 1.
