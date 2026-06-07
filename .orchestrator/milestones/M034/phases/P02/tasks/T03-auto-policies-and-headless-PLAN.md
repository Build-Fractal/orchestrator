---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M034"
name: "Auto-mode policies + continue-file write + headless QUESTIONS.md fallback (SC-4 write-side, SC-5)"
depends_on: ["T02"]
---

## Prerequisites

- T02 complete: `scripts/lifecycle/interactive-review.sh` exists with the `_run_headless_policy` stub (marker `# >>> T03 fills this`), the `_append_review_block` / `_populate_signoff` / `_ensure_review_block` helpers, the `_packet_field` extractor, and arg vars `MILESTONE`/`PHASE`/`GATE_ID`/`PACKET`/`POLICY`/`REVIEW_OUT`/`SIGNOFF_OUT`.
- T01: `decisions-constants.sh` carries `DECISIONS_POLICY_VALUES` + `decisions_is_valid_policy`.
- `commands/auto.md` exists.

## Description

Fill the headless branch of `interactive-review.sh` with the three FR-8 auto-mode
policies and the FR-9 headless `QUESTIONS.md` hand-off. This governs every
autonomous/headless run that reaches a gate — it must never deadlock, and it must
preserve the always-write invariant (CON-5/SC-5: the `*-DECISIONS.md` is already
on disk and stays; the policy only gates operator-touch). Wire `commands/auto.md`
to export `ORCH_HEADLESS=1` before a gated phase and read the gate policy.

## Steps

1. **Replace the `_run_headless_policy` stub** in `interactive-review.sh`. The
   function reads `$POLICY` (validated against `decisions_is_valid_policy`;
   invalid → error+exit 1) and branches:

   - **`defer`** (default):
     1. `idx=$(_review_block_count "$REVIEW_OUT")` — blocks already written (0 fresh).
     2. Write the continue-file atomically (tmpfile + `mv`) at
        `CONTINUE_FILE="$(dirname "$PACKET")/${GATE_ID}-CONTINUE.md"` with the
        PC-5 schema (M034-P01-ADDENDUM.md §PC-5) — frontmatter exactly:
        ```yaml
        ---
        schema_version: "1.0"
        type: pending-review-continue
        milestone_id: "<MILESTONE>"
        phase_id: "<PHASE>"
        gate_id: "<GATE_ID>"
        last_review_md_block_index: <idx>
        declared_policy: "defer"
        created_at: "<iso>"
        packet_path: "<PACKET>"
        review_md_path: "<REVIEW_OUT>"
        status: "pending-review"
        ---
        ```
        (a short body line is fine; the frontmatter is the contract.)
     3. Append a `pending_review` JSONL event to the milestone execution-log
        (`_emit_event` helper, step 2):
        `{"record_type":"pending_review","milestone":"<M>","phase":"<P>","gate_id":"<g>","last_review_md_block_index":<idx>,"declared_policy":"defer","timestamp":"<iso>"}`.
     4. Print `INTERACTIVE-REVIEW: deferred gate <GATE_ID> -> <CONTINUE_FILE>` and
        `exit 0` (clean exit — resumable; no deadlock).

   - **`accept-with-audit`**:
     1. `_ensure_review_header "$REVIEW_OUT"`; `base=$(_review_block_count "$REVIEW_OUT")`.
     2. For each `id` in `$(bash "$READER" active-ids "$PACKET")` (in order):
        - append a REVIEW.md block with `action=accept`,
          `rationale="auto-accepted (accept-with-audit policy)"` via
          `_append_review_block` (so `reviewed: <id>` is written → the id counts
          reviewed);
        - append one `auto_accepted` JSONL event per decision:
          `{"record_type":"auto_accepted","milestone":"<M>","phase":"<P>","gate_id":"<g>","decision_id":"<id>","timestamp":"<iso>"}`.
     3. `_populate_signoff "$SIGNOFF_OUT" <final_block_count> "auto-accept"`.
     4. Print `INTERACTIVE-REVIEW: accept-with-audit gate <GATE_ID> (<N> decisions)` and `exit 0`.

   - **`refuse-entry`**:
     1. Append a `refused_entry` JSONL event:
        `{"record_type":"refused_entry","milestone":"<M>","phase":"<P>","gate_id":"<g>","timestamp":"<iso>"}`.
     2. Print `INTERACTIVE-REVIEW: refuse-entry gate <GATE_ID> — phase entry refused (declared policy)` to stderr.
     3. `exit 30` (a distinct non-zero — refuse-entry is the declared strict
        behavior per Edge Case, NOT a bug; the caller halts the autonomous run at
        the phase boundary). The `*-DECISIONS.md` is untouched (always-write holds).

   - **FR-9 `QUESTIONS.md` hand-off**: the headless path ALSO writes a
     `QUESTIONS.md` hand-off (so a human can complete the gate out-of-band) for
     the `defer` policy specifically (the policy that expects later human
     completion). Write `QUESTIONS_FILE="$(dirname "$PACKET")/${GATE_ID}-QUESTIONS.md"`
     listing each active decision id + its `summary` + `concrete_impact` (via
     `_packet_field`) as a checklist, mirroring the M033 P04 `>N-conflicts`
     hand-off shape (a markdown list the operator answers). This is additive to
     the `defer` branch (write QUESTIONS.md, then the continue-file + JSONL +
     exit 0). For `accept-with-audit`/`refuse-entry` no QUESTIONS.md is written
     (no pending human question). The watchdog never fires because every branch
     terminates with an explicit `exit` — there is no blocking read.

2. **Add an `_emit_event` helper** to `interactive-review.sh` (near the other
   helpers): resolve the milestone execution-log path and append a JSONL line:

   ```bash
   _emit_event() {
     # $1 = full JSON object string (already formed by the caller).
     ev_log="$REPO_ROOT/.orchestrator/milestones/$MILESTONE/execution-log.jsonl"
     # Fixture override: ORCH_EVENT_LOG forces the log path (verifier hermeticity).
     if [ -n "${ORCH_EVENT_LOG:-}" ]; then ev_log="$ORCH_EVENT_LOG"; fi
     mkdir -p "$(dirname "$ev_log")" 2>/dev/null || return 0
     printf '%s\n' "$1" >> "$ev_log" 2>/dev/null || true
   }
   ```

   (The `ORCH_EVENT_LOG` override lets the verifier point the log at a scratch
   path so the real milestone log is never touched — keep commits scoped.)

3. **Wire `commands/auto.md`** — add a short subsection (instruction prose, not
   code that auto-loop runs) stating: before entering a phase that declares
   `review_gates: [...]`, `orchestrator:auto` exports `ORCH_HEADLESS=1` (no human
   in an autonomous loop) and invokes `interactive-review.sh` with the gate's
   declared `--policy` read from the phase-plan frontmatter; a `defer` result
   (clean exit 0 + continue-file) pauses the autonomous run for later
   `orchestrator:resume`; a `refuse-entry` non-zero halts at the phase boundary.
   The literal token `ORCH_HEADLESS` MUST appear in the file.

4. **Co-author** `tools/verify/m034-p02-auto-policies.sh` (see Verification).

## Must-Haves

- Under `ORCH_HEADLESS=1`, `defer` writes `<gate_id>-CONTINUE.md` (PC-5 schema with all required keys) + a `pending_review` JSONL event + a `<gate_id>-QUESTIONS.md` hand-off, and exits 0.
- `accept-with-audit` writes one `auto_accepted` JSONL per active decision + one REVIEW.md block per decision (each carrying `reviewed: <id>`) + populates SIGNOFF; exits 0.
- `refuse-entry` writes a `refused_entry` JSONL event and exits non-zero (refuses entry); writes no REVIEW.md/SIGNOFF.
- All three paths leave the `*-DECISIONS.md` intact (always-write CON-5/SC-5).
- The headless path never blocks on input (no hang); a `QUESTIONS.md` hand-off is written on the `defer` path (FR-9).
- `commands/auto.md` contains `ORCH_HEADLESS`.

## Verification

```bash
bash tools/verify/m034-p02-auto-policies.sh
```

## Inputs

### From Previous Tasks
- `scripts/lifecycle/interactive-review.sh` (from T02)
  - Key API: `_run_headless_policy` stub to replace; `_append_review_block <file> <idx> <id> <action> <rationale> <value>`; `_ensure_review_header <file>`; `_review_block_count <file>`; `_populate_signoff <file> <count> <approved_by>`; `_packet_field <packet> <id> <field>`; vars `MILESTONE`/`PHASE`/`GATE_ID`/`PACKET`/`POLICY`/`REVIEW_OUT`/`SIGNOFF_OUT`/`REPO_ROOT`/`READER`.
- `scripts/knowledge/lib/decisions-constants.sh` (from T01)
  - Key API: `DECISIONS_POLICY_VALUES`, `decisions_is_valid_policy <v>` → `ok`/empty.
- `scripts/knowledge/read-decisions.sh` (from T02) — `active-ids <packet>` → ordered active ids; `unreviewed-count <packet>`.

### From Disk (Pre-existing)
- `commands/auto.md` — the autonomous-loop command doc to wire (add the ORCH_HEADLESS + gate-policy subsection).
- `templates/continue-file.md` — the generic continue-file convention; the PC-5 `<gate_id>-CONTINUE.md` is a distinct review-specific shape (do not reuse the generic `continue.md` path).
- `M034-P01-ADDENDUM.md` §PC-5 — the binding continue-file schema (5 required keys + audit context).

## Constraints

- CON-1: bash 3.2 single-file; continue-file write is atomic (tmpfile + `mv`).
- CON-5/SC-5: never delete or rewrite the `*-DECISIONS.md`; only operator-touch is gated.
- CON-8: the policy enum value is `refuse-entry` everywhere — never `block`.
- JSONL events are append-only (`>>`); never rewrite the execution-log.
- No blocking reads on any headless path (the watchdog-never-fires guarantee is structural: every branch ends in an explicit `exit`).

## Expected Output

See `## Notes`.

## Notes

`bash tools/verify/m034-p02-auto-policies.sh` builds a fixture packet (≥2 active
decisions) and, with `ORCH_HEADLESS=1` and `ORCH_EVENT_LOG=<scratch>`, drives
`interactive-review.sh` three times (one per policy) against fresh scratch dirs.
It asserts: `defer` → continue-file present with all five PC-5 keys + a
`pending_review` line in the scratch log + a `*-QUESTIONS.md` + exit 0;
`accept-with-audit` → N `auto_accepted` lines + N REVIEW.md blocks + SIGNOFF
populated + exit 0; `refuse-entry` → a `refused_entry` line + non-zero exit + no
REVIEW.md; the `*-DECISIONS.md` unchanged (byte-identical) after every run. Each
invocation returns within the verifier's own bounded wait (no hang). Prints
`PASS: m034-p02 auto-policies` + exit 0, else `FAIL: m034-p02 auto-policies —
<reason>` + exit 1.
