---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M034"
name: "SSOT enums + dispatch-interface --probe-renderer seam + REVIEW/SIGNOFF templates"
depends_on: []
---

## Prerequisites

- `scripts/knowledge/lib/decisions-constants.sh` exists (P01 CON-4 SSOT) — verified on disk.
- `scripts/dispatch/dispatch-interface.sh` exists with a `--query` first-arg passthrough at line ~55 — verified on disk.
- `scripts/dispatch/backend-registry.sh` exists with a `--probe <name>` mode emitting `available=true|false` — verified on disk.
- `scripts/dispatch/adapters/backend/local-agent.sh` + `cursor-agent.sh` exist with `--probe` modes — verified on disk.

## Description

Lay P02's foundation: the named-constant enums every later task references, the
renderer-detection seam `interactive-review.sh` probes (PC-4 / D-P02-1), and the
two output templates the stage populates (REVIEW.md block schema + SIGNOFF
shape). No behavior in `interactive-review.sh` yet — this task produces only the
shared contracts.

## Steps

1. **Extend the CON-4 SSOT** — append to `scripts/knowledge/lib/decisions-constants.sh`
   (after the existing `DECISIONS_WARN_FINDING_THRESHOLD` block, before the
   validator functions, keeping the file's no-top-level-execution property):

   ```bash
   # M034 P02: walkthrough action enum (FR-6). One per operator response.
   #   accept   — agree with the decision as-is.
   #   override — replace picked_value; carries value + rationale (verbatim).
   #   pushback — record a concern without changing the value.
   #   na       — boundary_translation false-positive: acknowledged-not-applicable.
   DECISIONS_ACTION_VALUES="accept override pushback na"

   # M034 P02: auto-mode policy enum (FR-8 / AD-4 / CON-8). Default defer.
   # The value is `refuse-entry`, NEVER `block` (CON-8 — `block` is a severity
   # value AND the conversus verdict; the policy enum stays lexically distinct).
   DECISIONS_POLICY_VALUES="defer accept-with-audit refuse-entry"
   DECISIONS_POLICY_DEFAULT="defer"
   ```

   And append two validators next to the existing
   `decisions_is_valid_severity` / `decisions_is_valid_type`:

   ```bash
   # Validator: print "ok" if $1 is a member of the action enum, else "".
   decisions_is_valid_action() {
     case " $DECISIONS_ACTION_VALUES " in
       *" $1 "*) printf 'ok' ;;
       *) printf '' ;;
     esac
   }

   # Validator: print "ok" if $1 is a member of the policy enum, else "".
   decisions_is_valid_policy() {
     case " $DECISIONS_POLICY_VALUES " in
       *" $1 "*) printf 'ok' ;;
       *) printf '' ;;
     esac
   }
   ```

2. **Add the `--probe-renderer` passthrough to `dispatch-interface.sh`.** Insert
   a new first-arg passthrough block IMMEDIATELY AFTER the existing `--query`
   block (which ends at the line `fi` following `exec bash "$query_script" "$@"`,
   around `dispatch-interface.sh:64`). Place it BEFORE the `# Parse arguments`
   `while` loop so it `exec`s out before any backend/shadow logic. Verbatim:

   ```bash
   # --- M034/P02/T01: --probe-renderer subcommand passthrough (PC-4 / D-P02-1) -
   # When the FIRST argument is --probe-renderer, resolve the interactive-review
   # renderer state and exit. This is the CON-7 renderer-selection seam:
   # interactive-review.sh routes through here, never calling a question
   # primitive directly. Emits exactly one line:
   #   renderer=interactive-cc | interactive-cursor | headless
   # Precedence (PC-4, M034-P01-ADDENDUM.md):
   #   ORCH_HEADLESS=1 -> headless (highest, unconditional)
   #   else local-agent probe available=true -> interactive-cc
   #   else cursor-agent probe available=true -> interactive-cursor (P03 renders)
   #   else -> headless
   if [ "${1:-}" = "--probe-renderer" ]; then
     if [ "${ORCH_HEADLESS:-0}" = "1" ]; then
       echo "renderer=headless"
       exit 0
     fi
     _pr_registry="$SCRIPT_DIR/backend-registry.sh"
     _pr_cc="$(bash "$_pr_registry" --probe local-agent 2>/dev/null | grep -E '^available=' | head -n 1 | cut -d= -f2)"
     if [ "$_pr_cc" = "true" ]; then
       echo "renderer=interactive-cc"
       exit 0
     fi
     _pr_cursor="$(bash "$_pr_registry" --probe cursor-agent 2>/dev/null | grep -E '^available=' | head -n 1 | cut -d= -f2)"
     if [ "$_pr_cursor" = "true" ]; then
       echo "renderer=interactive-cursor"
       exit 0
     fi
     echo "renderer=headless"
     exit 0
   fi
   # ---------------------------------------------------------------------------
   ```

   NOTE: `SCRIPT_DIR` is already defined at `dispatch-interface.sh:32` ABOVE the
   `--query` block, so it is in scope here. Do not redefine it.

3. **Author `templates/review.md`** — the append-only REVIEW.md block schema
   (FR-7 / D-P02-3). The reviewed-marker line `reviewed: <id>` is what P01's
   `read-decisions.sh::_is_reviewed` matches to drive the unreviewed-count down.
   Write exactly:

   ```markdown
   ---
   schema_version: "1.0"
   type: review-log
   milestone: "M###"
   phase: "P##"
   gate_id: "<gate name from review_gates[]>"
   packet: "<path to the *-DECISIONS.md this log adjudicates>"
   ---

   <!--
     REVIEW.md SCHEMA (M034 FR-7). Append-only audit trail. One block per
     operator response per gate visit, in packet order. Written by the
     orchestrating agent (interactive-cc path, Case A) or by
     interactive-review.sh (test-responses / auto / headless paths).

     Block fields:
       id            The decision id this block adjudicates (matches a
                     *-DECISIONS.md `## <id>` block).
       action        Enum DECISIONS_ACTION_VALUES (accept|override|pushback|na).
       reviewed_at   ISO timestamp.
       rationale     Present for override|pushback|na (operator's reason).
       override_value Present for override only (the new picked_value, verbatim).
     Each block ENDS with `reviewed: <id>` — the reviewed-marker line
     read-decisions.sh::_is_reviewed matches. `defer` writes NO block (the
     decision stays pending until orchestrator:resume completes it).
   -->

   # Review Log — <gate_id>

   ## <id> — review block 1
   - **id**: D-1
   - **action**: accept
   - **reviewed_at**: <iso>
   reviewed: D-1
   ```

4. **Author `templates/signoff.md`** — the SIGNOFF shape interactive-review.sh
   populates from REVIEW.md's terminal entry (D-P02-2). Write exactly:

   ```markdown
   ---
   schema_version: "1.0"
   type: signoff
   milestone: "M###"
   phase: "P##"
   gate_id: "<gate name from review_gates[]>"
   approved_by: null
   review_md: "<path to the sibling *-REVIEW.md>"
   terminal_review_block: 0
   signed_at: null
   ---

   <!--
     SIGNOFF.md (M034 FR-7). Populated from REVIEW.md's terminal entry by
     scripts/lifecycle/interactive-review.sh. `approved_by` is flipped from
     null to the reviewer label (operator name, or "auto-accept" for the
     accept-with-audit policy). `terminal_review_block` is the count of
     REVIEW.md blocks written when sign-off occurred. This feature POPULATES
     SIGNOFF.md; it does not replace the sign-off primitive (non-goal).
   -->

   # Sign-off — <gate_id>

   Populated from REVIEW.md terminal entry (block <terminal_review_block>).
   ```

5. **Co-author the verifier** `tools/verify/m034-p02-renderer-probe.sh` (see
   Verification). It exercises the probe states + ORCH_HEADLESS precedence +
   asserts the SSOT enums and the two templates exist with the required tokens.

## Must-Haves

- `decisions-constants.sh` defines `DECISIONS_ACTION_VALUES`, `DECISIONS_POLICY_VALUES` (`defer accept-with-audit refuse-entry`), `DECISIONS_POLICY_DEFAULT=defer`, and the two validators; the policy enum contains `refuse-entry` and NOT `block` (CON-8).
- `dispatch-interface.sh --probe-renderer` emits `renderer=interactive-cc|interactive-cursor|headless`; `ORCH_HEADLESS=1` forces `renderer=headless` regardless of backend availability.
- `templates/review.md` carries the REVIEW.md block schema with an `action` field and a `reviewed: <id>` marker line.
- `templates/signoff.md` carries `approved_by` and `terminal_review_block`.

## Verification

```bash
bash tools/verify/m034-p02-renderer-probe.sh
```

## Inputs

### From Disk (Pre-existing)
- `scripts/knowledge/lib/decisions-constants.sh` — the CON-4 SSOT; append enums/validators following the existing `case " $X_VALUES " in *" $1 "*)` validator idiom (no `declare -A`, no `${var,,}`).
- `scripts/dispatch/dispatch-interface.sh` — `SCRIPT_DIR` defined at line 32; `--query` passthrough at lines 55-63 is the structural model for the new `--probe-renderer` block. Insert AFTER the `--query` block's closing `fi`, BEFORE `# Parse arguments`.
- `scripts/dispatch/backend-registry.sh` — `--probe <name>` runs `adapters/backend/<name>.sh --probe` and prints its `available=`/`backend=`/`reason=` lines.
- `scripts/dispatch/adapters/backend/local-agent.sh` — `--probe` prints `available=true` when `SPECKIT_AGENT_TOOL=1` or `.claude/` present.

## Constraints

- CON-1: bash 3.2 / POSIX-sh, single-file additions; no `declare -A`, no `${var,,}`, no process substitution.
- The `dispatch-interface.sh` edit is ADDITIVE and must not alter the `--query` passthrough, the backend-resolution flow, or any M030 shadow logic. The new block `exec`s/`exit`s before reaching them.
- CON-4: the action/policy enums live ONLY in `decisions-constants.sh`; do not duplicate the literal values in any other file.

## Expected Output

See `## Notes`.

## Notes

`bash tools/verify/m034-p02-renderer-probe.sh` prints `PASS: m034-p02
renderer-probe` and exits 0 when: the SSOT enums + validators are present and
`block` is absent from the policy enum; `--probe-renderer` returns `headless`
under `ORCH_HEADLESS=1` and `interactive-cc` under `SPECKIT_AGENT_TOOL=1` with
`ORCH_HEADLESS` unset; and both templates carry their required tokens. On any
miss it prints `FAIL: m034-p02 renderer-probe — <reason>` and exits 1.
