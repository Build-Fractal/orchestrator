---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M034"
name: "interactive-review.sh stage spine + --test-responses deterministic path (SC-3)"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `decisions-constants.sh` carries `DECISIONS_ACTION_VALUES` + `decisions_is_valid_action`; `dispatch-interface.sh --probe-renderer` emits `renderer=...`; `templates/review.md` + `templates/signoff.md` exist.
- P01: `scripts/knowledge/read-decisions.sh` exists; `scripts/knowledge/write-decisions.sh` exists; packet block shape is `## <id>` heading followed by `- **field**: value` bullets.
- `jq` is on PATH (required, same posture as `write-decisions.sh`).

## Description

Author `scripts/lifecycle/interactive-review.sh` — the FR-5 `interactive_review`
lifecycle stage spine. This task delivers: argument parsing, renderer resolution
via the T01 probe seam, the append-only REVIEW.md block writer, SIGNOFF.md
population, and the fully-deterministic `--test-responses` path (PC-3/SC-3). The
headless-policy, resume, and interactive-cc branches are laid as clearly-marked
stub functions that T03/T04/T06 fill — this task's verifier drives only
`--test-responses`, so the stubs are never exercised here.

Also expose a public `active-ids <packet>` subcommand on P01's
`read-decisions.sh` (additive — surfaces the existing `_active_ids` helper) so
the stage reads active decision ids in packet order from the single canonical
packet parser rather than re-implementing the supersede filter.

## Steps

1. **Expose `active-ids` on `read-decisions.sh`** (additive). In the dispatch
   `case "$sub"` block (`read-decisions.sh:177`), add a branch and a thin wrapper
   that prints the existing `_active_ids` output:

   ```bash
   active-ids)            _active_ids "$arg" ;;
   ```

   Add `active-ids` to the usage string in the `*)` error branch. (`_active_ids`
   already emits active, non-superseded ids one per line in file order.)

2. **Author `scripts/lifecycle/interactive-review.sh`** — bash 3.2 single-file.
   Structure:

   - Header comment: purpose, the FR-5 contract, the CON-1/CON-7 notes, the
     Case A split (interactive path: agent writes REVIEW.md directly; non-
     interactive paths: this script writes it).
   - `set -u`. Resolve `SCRIPT_DIR`, `REPO_ROOT`. Source
     `"$SCRIPT_DIR/../knowledge/lib/decisions-constants.sh"`. Define paths:
     `READER="$REPO_ROOT/scripts/knowledge/read-decisions.sh"`,
     `DISPATCH_IFACE="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"`.
   - **Arg parse** (`--field=value` flags, mirroring write-decisions.sh):
     `--milestone=`, `--phase=`, `--gate-id=`, `--packet=`,
     `--policy=` (default `$DECISIONS_POLICY_DEFAULT`), `--test-responses=`,
     `--resume=`, `--review-out=`, `--signoff-out=`. Unrecognized → error+exit 1.
   - **Derive defaults**: when `--review-out`/`--signoff-out` unset, derive from
     the packet path by suffix replacement:
     `REVIEW_OUT="${PACKET%-DECISIONS.md}-REVIEW.md"`,
     `SIGNOFF_OUT="${PACKET%-DECISIONS.md}-SIGNOFF.md"`.
   - **Packet-absent guard** (Edge Case "gate reached, packet absent"): when not
     resuming and `[ ! -f "$PACKET" ]`, print
     `ERROR: interactive-review: packet not found: <path> (gate <id> fails closed)`
     to stderr and exit 3 (fail closed, do NOT silently pass).

   - **Field extractor** `_packet_field <packet> <id> <field>` — awk that scans
     the `## <id>` block and prints the `- **<field>**: ` value (used to surface
     decision context). Bash-3.2-safe awk:

     ```bash
     _packet_field() {
       awk -v want="$2" -v field="$3" '
         /^## / { inblk = 0 }
         /^- \*\*id\*\*: / { v=$0; sub(/^- \*\*id\*\*: /,"",v); inblk=(v==want)?1:0; next }
         inblk && $0 ~ ("^- \\*\\*" field "\\*\\*: ") {
           line=$0; sub("^- \\*\\*" field "\\*\\*: ","",line); print line; exit
         }
       ' "$1"
     }
     ```

   - **REVIEW.md helpers**:
     - `_review_block_count <review_file>` — prints the count of `^## ` blocks
       currently in the REVIEW file (0 if absent). `grep -c '^## ' || true`.
     - `_ensure_review_header <review_file>` — if the file does not exist, write
       the `templates/review.md` frontmatter (schema_version/type/milestone/
       phase/gate_id/packet) + `# Review Log — <gate_id>` heading. Append-only
       afterward; never rewrite the header.
     - `_append_review_block <review_file> <index> <id> <action> <rationale> <override_value>`:
       append (`>>`) one block:
       ```
       ## <id> — review block <index>
       - **id**: <id>
       - **action**: <action>
       - **reviewed_at**: <iso>
       [- **rationale**: <rationale>]      # when non-empty
       [- **override_value**: <value>]     # when action==override and non-empty
       reviewed: <id>
       ```
       Use `printf '%s'` / quoted expansions for field bodies — never re-shell-
       interpret (RISK-1 discipline). A leading blank line separates blocks.
   - **SIGNOFF helper** `_populate_signoff <signoff_file> <terminal_block_count> <approved_by>`:
     write (overwrite) the `templates/signoff.md` frontmatter with `approved_by`
     flipped from null to `<approved_by>`, `review_md` = REVIEW_OUT basename,
     `terminal_review_block` = `<terminal_block_count>`, `signed_at` = iso; then
     the `# Sign-off — <gate_id>` heading + the populated-from line.

   - **`_run_test_responses`** (this task's deliverable):
     1. `[ -f "$TEST_RESPONSES" ]` else error+exit 1.
     2. `FIXTURE_JSON="$(cat "$TEST_RESPONSES")"`; validate it is a JSON array
        (`jq -e 'type=="array"'`) else error+exit 1.
     3. `_ensure_review_header "$REVIEW_OUT"`.
     4. `base=$(_review_block_count "$REVIEW_OUT")` (resume-safe base index).
     5. Read active ids in packet order:
        `ids="$(bash "$READER" active-ids "$PACKET")"`.
     6. `n=$base`; for each `id` in `$ids`:
        - `entry="$(printf '%s' "$FIXTURE_JSON" | jq -c --arg id "$id" '.[] | select(.id==$id)' | head -n 1)"`
        - if empty → `action=accept`, `rationale=""`, `value=""` (defaulted).
        - else extract `action`/`value`/`rationale` with `jq -r '.action // "accept"'` etc.
        - validate: `[ "$(decisions_is_valid_action "$action")" = ok ]` else error+exit 1.
        - `n=$((n+1))`; `_append_review_block "$REVIEW_OUT" "$n" "$id" "$action" "$rationale" "$value"`.
     7. `_populate_signoff "$SIGNOFF_OUT" "$n" "${ORCH_REVIEWER:-operator}"`.
     8. Print `INTERACTIVE-REVIEW: reviewed <count> decisions -> $REVIEW_OUT` (count = n - base), exit 0.

   - **Stub functions** (filled by later tasks — leave the marker comments
     intact so the executor can locate them):
     ```bash
     # >>> T03 fills this: headless auto-mode policy paths (FR-8/FR-9). <<<
     _run_headless_policy() {
       echo "interactive-review: headless policy path not yet implemented (M034/P02/T03)" >&2
       exit 20
     }

     # >>> T04 fills this: --resume re-entry at last_review_md_block_index (PC-5). <<<
     _run_resume() {
       echo "interactive-review: --resume not yet implemented (M034/P02/T04)" >&2
       exit 21
     }

     # >>> T06 fills this: interactive-cc render-descriptor (FR-6, Case A). <<<
     _emit_interactive_descriptor() {
       echo "interactive-review: interactive renderer descriptor not yet implemented (M034/P02/T06)" >&2
       exit 22
     }
     ```

   - **Dispatch skeleton** (end of file):
     ```bash
     if [ -n "${RESUME_FILE:-}" ]; then
       _run_resume
     elif [ -n "${TEST_RESPONSES:-}" ]; then
       _run_test_responses
     else
       _renderer="$(bash "$DISPATCH_IFACE" --probe-renderer 2>/dev/null | grep -E '^renderer=' | head -n 1 | cut -d= -f2)"
       case "$_renderer" in
         interactive-cc|interactive-cursor) _emit_interactive_descriptor "$_renderer" ;;
         *) _run_headless_policy ;;
       esac
     fi
     ```

3. **Co-author** `tools/verify/m034-p02-test-responses.sh` (see Verification).

## Must-Haves

- `interactive-review.sh --test-responses=<fixture> --packet=<packet> ...` appends exactly one REVIEW.md block per active decision, in packet order, each recording the fixture action.
- An `override` entry's `override_value` + `rationale` appear verbatim in its block.
- `SIGNOFF.md` is populated (approved_by flipped from null; terminal_review_block = block count).
- After reviewing every active decision, `read-decisions.sh unreviewed-count <packet>` returns 0 (SC-2 zero-after).
- The run is hermetic: no prompt, no network; deterministic across repeated runs against a fresh REVIEW_OUT.
- A missing packet (non-resume) fails closed (exit 3), not silently.

## Verification

```bash
bash tools/verify/m034-p02-test-responses.sh
```

## Inputs

### From Previous Tasks
- `scripts/knowledge/lib/decisions-constants.sh` (from T01)
  - Key API: `DECISIONS_ACTION_VALUES`, `DECISIONS_POLICY_DEFAULT`, `decisions_is_valid_action <v>` → prints `ok`/empty.
- `templates/review.md`, `templates/signoff.md` (from T01) — the frontmatter shapes to emit.
- `scripts/dispatch/dispatch-interface.sh` (from T01) — `--probe-renderer` → `renderer=<state>`.

### From Disk (Pre-existing)
- `scripts/knowledge/read-decisions.sh` — modify to add the `active-ids` subcommand; `_active_ids` already emits active ids one per line in file order; `unreviewed-count <packet>` counts active ids whose id is NOT marked `reviewed: <id>` in the sibling `*-REVIEW.md`.
- `scripts/knowledge/write-decisions.sh` — reference for the `--field=value` flag-parse idiom and the `## <id>` + `- **field**: value` block shape REVIEW.md mirrors.
- `scripts/lifecycle/auto-loop.sh` — CON-1 prior-art for flag parsing and `printf '%s' ... >> file` append discipline.

## Constraints

- CON-1: bash 3.2 / POSIX-sh single file; no `declare -A`, no `${var,,}`, no process substitution. Pipes / awk / `$()` / jq permitted in the body.
- CON-7: renderer selection routes ONLY through `dispatch-interface.sh --probe-renderer`; never call `AskUserQuestion`/elicitation directly from bash.
- RISK-1 escaping: field bodies (rationale, override_value, summary) are written via quoted `printf '%s'` — never `eval`, never unquoted re-expansion.
- CON-5/SC-5: the REVIEW.md + SIGNOFF.md are always written on this path; the test path never silently skips.
- The three stub functions and the dispatch skeleton are required (T03/T04/T06 depend on them) — do not delete the marker comments.

## Expected Output

See `## Notes`.

## Notes

`bash tools/verify/m034-p02-test-responses.sh` builds a fixture packet (via
`write-decisions.sh`) with ≥3 decisions including one whose fixture action is
`override` (with a multi-word value + rationale), drives
`interactive-review.sh --test-responses=<fixture>`, and asserts: one REVIEW.md
block per active id in order; the override block contains the exact value +
rationale strings; SIGNOFF.md has `approved_by:` non-null and the right
`terminal_review_block`; `read-decisions.sh unreviewed-count` returns 0; a
second identical run against a fresh scratch dir produces byte-identical REVIEW
block bodies (determinism, modulo the timestamp line). It prints `PASS: m034-p02
test-responses` + exit 0, else `FAIL: m034-p02 test-responses — <reason>` +
exit 1. All scratch under the repo `tmp/` or `mktemp`; no human, no network.
