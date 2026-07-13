---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M046"
name: "auto-loop.sh outcome-marker mechanism + FR-17 legacy parity"
depends_on: []
---

## Prerequisites

- `scripts/lifecycle/auto-loop.sh` exists (verified at plan time; 641 lines). This task adds the SINGLE CON-2-authorized additive change. Read the whole file before editing.
- `tests/fixtures/` exists; `tests/fixtures/m046-p02/` does not yet exist (collision-checked at plan time) — this task creates it.
- No other task touches `auto-loop.sh`. P02 is the only M046 phase allowed to touch it at all.

## Description

Add a deterministic, env-gated, atomic outcome-marker write to `scripts/lifecycle/auto-loop.sh`, keyed to its complete exit-code contract (M046 FR-14, Gap 3). The mechanism is ONE logical writer realized as two purely-additive insertions (see "CON-2 Accounting" in `P02-PLAN.md`). Then pin FR-17 attended legacy parity with a byte-equality golden (M045 P03 precedent: `tools/verify/m045-p03-legacy-golden.sh`).

**Gate**: the marker write happens ONLY when the environment variable `ORCHESTRATOR_SELF_CONTINUE_MARKER` equals `1`. When it is absent/other, `auto-loop.sh` behavior must be byte-identical to today (stdout, stderr semantics, exit codes, no marker file).

**Marker file**: `$MILESTONE_DIR/.self-continue-outcome` (same path the M045 driver reads at `scripts/lifecycle/self-continue-drive.sh:39`). Content: `<word>` or `<word> <phase>` plus trailing newline.

**Mapping** (single source of truth — the table in `P02-PLAN.md` "Marker Vocabulary"):
- exit 0 + substate `AUTO:PLANNING phase=P##` → `planning P##`
- exit 0 + substate `AUTO:PHASE_COMPLETE phase=P##` → `phase_complete P##`
- exit 0 + substate `AUTO:MILESTONE_VALIDATING` → `validating`
- exit 0 + any other substate (`AUTO:READY`, `AUTO:RECORDED`, `AUTO:VERIFY_PASS`, `CONTEXT:OK`, `AUTO:VERIFY_NO_CHECKS` is exit 1 not 0) → NO write (mid-segment step; the previous marker, if any, stands — last-write-wins)
- exit 1 → `error`; exit 2 → `budget`; exit 3 → `stuck`; exit 10 → `complete`; exit 11 → `pause`; exit 12 → `unexpected_state`; exit 13 → `planning_failed`
- exit 14 → `rotation` plus best-effort phase word from `bash "$READ_ROADMAP" "$ROADMAP_FILE" active-phase` (the `CONTEXT:ROTATE` line carries no `phase=` field; without the phase word the driver's forward-progress counter cannot advance and healthy runs would look like thrash)
- any other exit code → NO write (future-proof: unknown codes are not guessed)

## Steps

1. Read `scripts/lifecycle/auto-loop.sh` in full. Confirm the exit-site table in `P02-PLAN.md` still matches (if it does not, STOP and report — the plan was authored against the 2026-07-13 revision).

2. **Insertion A** — immediately after line 100 (`fi` closing the `[[ ! -d "$MILESTONE_DIR" ]]` check), BEFORE the `STEP=""` block, insert the self-contained marker mechanism. Exact-syntax-matters code (adapt line references, keep the logic verbatim):

   ```
   # --- M046 FR-14: deterministic outcome marker (the single CON-2-authorized
   # additive change). Active ONLY when ORCHESTRATOR_SELF_CONTINUE_MARKER=1
   # (exported by scripts/lifecycle/self-continue-drive.sh). Maps this
   # invocation's exit code (+ exit-0 substate captured in the _auto_output
   # funnel) to the self-continue marker vocabulary and writes it atomically
   # (temp + rename), so a kill landing mid-write leaves old-or-new, never torn.
   _MARKER_SUBSTATE=""
   _MARKER_PHASE=""
   _write_outcome_marker() {
     _marker_rc=$?
     [[ "${ORCHESTRATOR_SELF_CONTINUE_MARKER:-}" = "1" ]] || return 0
     _marker_word=""
     case "$_marker_rc" in
       0)
         case "${_MARKER_SUBSTATE:-}" in
           PLANNING)             _marker_word="planning" ;;
           PHASE_COMPLETE)       _marker_word="phase_complete" ;;
           MILESTONE_VALIDATING) _marker_word="validating" ;;
         esac
         ;;
       1)  _marker_word="error" ;;
       2)  _marker_word="budget" ;;
       3)  _marker_word="stuck" ;;
       10) _marker_word="complete" ;;
       11) _marker_word="pause" ;;
       12) _marker_word="unexpected_state" ;;
       13) _marker_word="planning_failed" ;;
       14)
         _marker_word="rotation"
         if [[ -z "${_MARKER_PHASE:-}" && -n "${READ_ROADMAP:-}" && -f "${ROADMAP_FILE:-/nonexistent}" ]]; then
           _MARKER_PHASE="$(bash "$READ_ROADMAP" "$ROADMAP_FILE" active-phase 2>/dev/null)" || _MARKER_PHASE=""
           [[ "$_MARKER_PHASE" = "none" ]] && _MARKER_PHASE=""
         fi
         ;;
     esac
     [[ -n "$_marker_word" ]] || return 0
     _marker_tmp="$MILESTONE_DIR/.self-continue-outcome.tmp.$$"
     if [[ -n "${_MARKER_PHASE:-}" ]]; then
       printf '%s %s\n' "$_marker_word" "$_MARKER_PHASE" > "$_marker_tmp" 2>/dev/null || return 0
     else
       printf '%s\n' "$_marker_word" > "$_marker_tmp" 2>/dev/null || return 0
     fi
     mv -f "$_marker_tmp" "$MILESTONE_DIR/.self-continue-outcome" 2>/dev/null || rm -f "$_marker_tmp" 2>/dev/null || true
     return 0
   }
   trap _write_outcome_marker EXIT
   ```

   Trap-safety notes (load-bearing): capture `$?` on the FIRST line; every variable that may be unset at early exit-1 paths (`READ_ROADMAP` is set at line 63 so it is always set post-insertion-point — but guard anyway; `ROADMAP_FILE` is set at line 163, i.e. AFTER the option-parse loop, so the unknown-option exit at line 136 fires with it unset) is expanded with `${VAR:-}` so `set -u` cannot abort the trap; every write step is `|| return 0`/`|| true`-guarded so the trap can never change the script's exit code.

3. **Insertion B** — inside the existing `_auto_output()` function body (lines 146–153), add a substate-capture `case` as the first statement of the function (before the existing `if`):

   ```
   case "$1" in
     "AUTO:PLANNING "*)            _MARKER_SUBSTATE="PLANNING"
                                   _MARKER_PHASE="$(printf '%s' "$1" | sed -n 's/.*phase=\([^ ]*\).*/\1/p')" ;;
     "AUTO:PHASE_COMPLETE "*)      _MARKER_SUBSTATE="PHASE_COMPLETE"
                                   _MARKER_PHASE="$(printf '%s' "$1" | sed -n 's/.*phase=\([^ ]*\).*/\1/p')" ;;
     "AUTO:MILESTONE_VALIDATING"*) _MARKER_SUBSTATE="MILESTONE_VALIDATING"; _MARKER_PHASE="" ;;
   esac
   ```

   Do NOT modify any existing line of the function — the `case` is inserted whole. Note `AUTO:MILESTONE_VALIDATING` is emitted with no trailing fields (line 528), hence the bare-prefix pattern.

4. **CON-2 audit**: run `git diff scripts/lifecycle/auto-loop.sh` and confirm the diff contains ONLY added lines (no `-` lines other than context-free noise; there must be zero deletions/modifications). If any existing line had to change, STOP and raise a Decision row per the escalation rule in `P02-PLAN.md`.

5. **Create the shared fixture tree** `tests/fixtures/m046-p02/verifying-tree/MFIX/` (pattern: `.orchestrator/milestones/M046/phases/P01/spike/cost/fixture/milestones/MFIX/`):
   - `MFIX-ROADMAP.md` — minimal roadmap with one phase, UNCHECKED: a `## Phases` section containing `- [ ] **P01**: Fixture phase — "fixture demo"` (match the shape `scripts/state/read-roadmap.sh` parses; copy the P01 MFIX roadmap shape and simplify).
   - `phases/P01/P01-PLAN.md` — minimal valid phase-plan frontmatter (copy shape from the P01 MFIX fixture).
   - `phases/P01/tasks/T01-PLAN.md` and `phases/P01/tasks/T01-SUMMARY.md` — minimal, so all tasks are complete but no `P01-SUMMARY.md` exists → `derive-phase.sh` yields `verifying`/`summarizing` → auto-loop emits `AUTO:PHASE_COMPLETE phase=P01` and exits 0.
   - Verify the tree behaves as intended: copy it to a scratch dir (`mktemp -d`), run the real `bash scripts/lifecycle/auto-loop.sh <scratch>/MFIX`, confirm stdout is exactly `AUTO:PHASE_COMPLETE phase=P01` and exit 0. Adjust fixture content until it is. (auto-loop mutates trees — payload files, drift logs — so verifiers must ALWAYS run against scratch copies, never the checked-in tree.)

6. **Pin the golden**: `tests/fixtures/m046-p02/legacy-parity.golden` containing exactly the gate-off stdout from step 5 (expected: `AUTO:PHASE_COMPLETE phase=P01` + newline). Byte-equality is the contract (project convention: default fixture suites to byte-equality, not substring).

7. **Author `tools/verify/m046-p02-legacy-parity.sh`** (POSIX sh, executable, `set -eu`, model on `tools/verify/m045-p03-legacy-golden.sh`). Behavior:
   - Copy `tests/fixtures/m046-p02/verifying-tree/MFIX` to a `mktemp -d` scratch.
   - Leg 1 (gate off): run `bash scripts/lifecycle/auto-loop.sh <scratch>/MFIX` with `ORCHESTRATOR_SELF_CONTINUE_MARKER` explicitly unset; capture stdout to a file and the exit code. Assert exit 0, stdout byte-equal to the golden (`cmp -s`), and `<scratch>/MFIX/.self-continue-outcome` does NOT exist.
   - Leg 2 (gate on): fresh scratch copy; run with `ORCHESTRATOR_SELF_CONTINUE_MARKER=1` in the child env. Assert exit 0, stdout byte-equal to the SAME golden (stdout must not change), and the marker file content is exactly `phase_complete P01`.
   - Emit `PASS: ...` / `FAIL: ...` lines; exit 0 only if all assertions hold.

8. **Author `tools/verify/m046-p02-marker-unit.sh`** (POSIX sh, executable, `set -eu`). Unit-grain direct invocations of the real `auto-loop.sh`, all gate-on, all against scratch copies of `verifying-tree/MFIX` (mutated per case):
   - Case `phase_complete`: unmodified scratch tree → expect exit 0, marker `phase_complete P01`.
   - Case `error`: run `bash scripts/lifecycle/auto-loop.sh <scratch>/MFIX --step=G` (missing `--task`) → expect exit 1, marker `error`.
   - Case `pause`: `touch <scratch>/MFIX/pause-requested` → expect exit 11, marker `pause` (note auto-loop deletes the pause file — scratch copy absorbs the mutation).
   - Case `unexpected_state`: mark the roadmap phase checked (`- [x] **P01**`) while `P01-SUMMARY.md` is absent → drift guard → expect exit 12, marker `unexpected_state`.
   - Case `gate-off-negative`: repeat the `pause` case WITHOUT the env var → expect exit 11 and NO marker file.
   - Each case: `rm -f` the marker before the run; assert exit code AND exact marker content (or absence). Emit `PASS:`/`FAIL:` per case, summary line, exit non-zero on any failure.

## Must-Haves

- With `ORCHESTRATOR_SELF_CONTINUE_MARKER=1`, `auto-loop.sh` deterministically writes the outcome marker keyed to its exit code (+ exit-0 substate)
  - Check: `bash tools/verify/m046-p02-marker-unit.sh`
- With the marker gate absent, `auto-loop.sh` stdout/exit are byte-identical to the pinned golden and no marker is written; with the gate on, stdout is unchanged
  - Check: `bash tools/verify/m046-p02-legacy-parity.sh`

## Verification

```bash
bash tools/verify/m046-p02-marker-unit.sh
bash tools/verify/m046-p02-legacy-parity.sh
bash tools/verify/m045-p03-legacy-golden.sh
```

## Notes

Expected output: each verifier ends with a `PASS:` summary line and exits 0. `m045-p03-legacy-golden.sh` is a pre-existing M045 regression guard (touches `self-continue-branch.sh`, which this task must NOT modify) — expected `PASS: golden matches (AUTO:ROTATE_EXIT reason=not-armed)`.

The `git diff` audit in step 4 is the CON-2 proof: added-lines-only. Keep the entire mechanism inside the two insertions; if a third location seems necessary, escalate (Decision row) instead of widening.

## Inputs

### From Previous Tasks

- none (T01 is a root task)

### From Disk (Pre-existing)

- `scripts/lifecycle/auto-loop.sh` — the modify target. Key facts: single output funnel `_auto_output()` at lines 146–153; `MILESTONE_DIR` validated by line 100; `READ_ROADMAP` var set at line 63; `ROADMAP_FILE` set at line 163; full exit-code table in `P02-PLAN.md`.
- `scripts/state/derive-phase.sh` — state oracle the fixture tree drives (`verifying`/`summarizing` ← all task summaries present, no phase summary).
- `scripts/state/read-roadmap.sh` — `active-phase` subcommand used for the exit-14 phase word; also parses the fixture roadmap.
- `.orchestrator/milestones/M046/phases/P01/spike/cost/fixture/milestones/MFIX/` — proven fixture-tree shape to copy from.
- `tools/verify/m045-p03-legacy-golden.sh` + `tests/fixtures/m045-rotation-exit-legacy.golden` — golden-verifier pattern to model.

## Constraints

- CON-2: at most ONE additive, idempotent change to `auto-loop.sh` — the two insertions of this one mechanism, zero existing lines modified. `git diff` must show additions only.
- FR-17: gate-absent behavior byte-unchanged (stdout, exit codes, no marker side effect).
- Do NOT touch `self-continue-drive.sh` (T02's file), `self-continue-branch.sh`, or `self-continue-status.sh`.
- Verifiers are POSIX sh, executable (`chmod +x`), run from repo root, and use scratch copies of fixture trees (never mutate checked-in fixtures).
- Bash 3.2 compatibility for anything the verifiers do; `auto-loop.sh` itself is bash (`#!/usr/bin/env bash`) so `[[ ]]` is fine inside it.

## Expected Output

- `scripts/lifecycle/auto-loop.sh` modified (additions only): marker mechanism (Insertion A) + funnel capture (Insertion B).
- `tests/fixtures/m046-p02/verifying-tree/MFIX/` fixture tree; `tests/fixtures/m046-p02/legacy-parity.golden`.
- `tools/verify/m046-p02-marker-unit.sh`, `tools/verify/m046-p02-legacy-parity.sh` — both green.
- `bash tools/verify/m045-p03-legacy-golden.sh` still green (no regression).
