---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M046"
name: "commands/auto.md envelope contract + docs verifier + phase suite"
depends_on: [T01, T02, T03, T04]
---

## Prerequisites

- All nine upstream P04 deliverables exist and are green:
  `scripts/lifecycle/unattended-envelope.sh`, envelope-integrated
  `scripts/lifecycle/self-continue-drive.sh`, and the verifiers
  `tools/verify/m046-p04-envelope-unit.sh`, `m046-p04-fail-closed.sh`,
  `m046-p04-attended-parity.sh`, `m046-p04-budget-kill.sh`, `m046-p04-reserve-spend.sh`,
  `m046-p04-stop-file-live.sh`, `m046-p04-thrash.sh`, `m046-p04-wall-clock.sh`.
- `commands/auto.md` exists with the M046-P02 self-continue outcome-marker section
  (~lines 527–607: `--self-continue` launch, marker contract, FR-14 writer-of-record,
  `self-continue-status.sh` note).
- `.orchestrator/DECISIONS.md` carries D016 (#Q-7 wall-clock resolution — recorded at plan
  time; verify with `grep -n "max-wall-clock-s" .orchestrator/DECISIONS.md`).

## Description

Document the unattended envelope contract in `commands/auto.md` (the driver's operator- and
agent-facing instruction surface), author the docs-shape verifier
`tools/verify/m046-p04-docs-shape.sh`, and ship the phase aggregator
`tools/verify/m046-p04-phase-suite.sh` running every P04 verifier plus the FR-17 parity
wrapper (which itself carries the four P02 driver regressions).

## Steps

1. **Amend `commands/auto.md`** — add a new `### Unattended envelope (--unattended, M046 P04)`
   subsection immediately after the existing self-continue outcome-marker material
   (after the `self-continue-status.sh` paragraph around line 607). Content requirements
   (prose, matching the shipped T02 driver behavior EXACTLY — read the driver header first):

   - **Opt-in and fail-closed caps**: `--unattended` is per-run and default OFF; no config
     key can enable it (FR-6). Under it, `--max-budget-usd`, `--max-continuations`, and
     `--max-wall-clock-s` are ALL mandatory; the driver itself refuses to start with exit 2
     and `SELF_CONTINUE:REFUSE reason=caps-unset missing=<csv>` (or `caps-invalid`) if any
     is unset — there is no silent `MAX_CONT=20` default on this path (FR-13). Note the
     #Q-7/D016 resolution: the wall-clock ceiling is operator-supplied per run, whole-run,
     enforced live.
   - **Terminal vocabulary table**: `SELF_CONTINUE:BUDGET_EXCEEDED stage=<mid-segment|pre-spawn>`,
     `SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=<...>`,
     `SELF_CONTINUE:STOPPED reason=stop-file stage=mid-segment` (live kill, bounded latency),
     `SELF_CONTINUE:THRASH no_progress_segments=<n> threshold=<n>` (default threshold 2,
     `--thrash-threshold` to change), plus the pre-existing terminals unchanged.
   - **Accounting surfaces**: `<milestone-dir>/.self-continue-budget-ledger` (append-only
     `run_start`/`reserve`/`reconcile`/`forfeit` lines; reserve-then-spend: a conservative
     reserve — `--segment-reserve-usd`, default 1.00 — is written BEFORE each spawn and
     trued-up from the exiting child's `claude -p --output-format json` `total_cost_usd`;
     an unreconciled segment forfeits max(reserve, observed) — a killed child is never
     free; the ledger PERSISTS across runs and the operator resets the budget by deleting
     the file); `<milestone-dir>/.self-continue-kill-reason` (envelope-owned, atomic
     temp+rename, written before every envelope SIGKILL); 
     `<milestone-dir>/.self-continue-segment-result.json` (captured child stdout).
   - **Watchdog**: poll cadence `--watchdog-poll-s` (default 1s); trigger order stop-file →
     wall-clock → budget; the budget trigger is cost-derived from non-null
     `"record_type":"unit_close"` `estimated_cost_usd` values in
     `<milestone-dir>/execution-log.jsonl` (override: `--cost-log`); null estimates
     contribute 0 (P01 #Q-4: JSONL supplies grain, JSON result supplies truth).
   - **Child-visible limits**: the env-export contract (`ORCHESTRATOR_UNATTENDED`,
     `ORCHESTRATOR_MAX_BUDGET_USD`, `ORCHESTRATOR_BUDGET_REMAINING_USD`,
     `ORCHESTRATOR_WALL_CLOCK_DEADLINE_EPOCH`, `ORCHESTRATOR_MAX_CONTINUATIONS`) — the
     FR-7 in-child self-abort leg, to be consumed by the P07 instruments.
   - **Implementation pointer**: the envelope lives in
     `scripts/lifecycle/unattended-envelope.sh` (sourced by `self-continue-drive.sh`);
     attended behavior is byte-compatible with M045 (FR-17) — the envelope wraps, never
     alters.

2. **Author `tools/verify/m046-p04-docs-shape.sh`** (`#!/usr/bin/env sh`, `set -eu`,
   PASS/FAIL + `SUMMARY:`). Greps `commands/auto.md` for each load-bearing token, one
   check per token: `--unattended`, `--max-budget-usd`, `--max-wall-clock-s`,
   `--max-continuations`, `SELF_CONTINUE:REFUSE`, `BUDGET_EXCEEDED`,
   `WALL_CLOCK_EXCEEDED`, `SELF_CONTINUE:THRASH`, `.self-continue-budget-ledger`,
   `.self-continue-kill-reason`, `total_cost_usd`, `unattended-envelope.sh`, plus a
   cross-file check that every terminal token documented also appears in
   `scripts/lifecycle/self-continue-drive.sh` (docs-vs-code drift guard).

3. **Author `tools/verify/m046-p04-phase-suite.sh`** — the P04 aggregator, following
   `tools/verify/m046-p02-phase-suite.sh` conventions: `cd "$REPO_ROOT"` first (members use
   repo-relative paths), run each member via `bash tools/verify/<member>`, emit one
   `SUITE: name=<member> result=<PASS|FAIL>` line per member and a final
   `SUMMARY: pass=N fail=N`, exit 1 on any failure. Members, in order:

   1. `m046-p04-envelope-unit.sh`
   2. `m046-p04-fail-closed.sh`
   3. `m046-p04-budget-kill.sh`
   4. `m046-p04-reserve-spend.sh`
   5. `m046-p04-stop-file-live.sh`
   6. `m046-p04-thrash.sh`
   7. `m046-p04-wall-clock.sh`
   8. `m046-p04-docs-shape.sh`
   9. `m046-p04-attended-parity.sh` (carries the four P02 driver regressions — FR-17 gate)

4. `chmod +x` both new verifiers; run all Verification commands.

## Must-Haves

- commands/auto.md documents the unattended envelope contract (phase Truth 9)
  - Check: `bash tools/verify/m046-p04-docs-shape.sh`
- Artifact: commands/auto.md (min 400 lines, contains "unattended")
- Artifact: tools/verify/m046-p04-docs-shape.sh (min 20 lines, contains "unattended")
- Artifact: tools/verify/m046-p04-phase-suite.sh (min 40 lines, contains "SUITE:")
- Key Link: commands/auto.md → unattended-envelope.sh
- Key Link: tools/verify/m046-p04-phase-suite.sh → tools/verify/m046-p04-budget-kill.sh

## Verification

```bash
bash tools/verify/m046-p04-docs-shape.sh
bash tools/verify/m046-p04-phase-suite.sh
```

## Notes

Expected: docs-shape `SUMMARY: pass=N fail=0` exit 0; phase suite reports 9/9 members PASS
(`SUMMARY: pass=9 fail=0`) exit 0. Suite runtime ~60–90s (the behavioral harnesses sleep).

Documentation-accuracy discipline: every token the docs verifier asserts must reflect what
the T02 driver ACTUALLY emits — read `scripts/lifecycle/self-continue-drive.sh` (header +
terminal echo lines) before writing prose; do not document aspirational flags. If a
discrepancy between this plan's vocabulary and the shipped driver exists, the DRIVER is
authoritative and the docs + docs verifier follow it (note the deviation in the task
summary).

## Inputs

### From Previous Tasks

- `scripts/lifecycle/self-continue-drive.sh` (from T02) — the authoritative flag/terminal
  surface being documented (read its header comment and echo lines).
- `scripts/lifecycle/unattended-envelope.sh` (from T01) — named in docs as the
  implementation seam.
- All seven T01–T04 verifiers — suite members (paths in Prerequisites).

### From Disk (Pre-existing)

- `commands/auto.md` — file to amend (self-continue section ends ~line 607).
- `tools/verify/m046-p02-phase-suite.sh` — aggregator-shape precedent (cd REPO_ROOT,
  SUITE:/SUMMARY: protocol).
- `.orchestrator/DECISIONS.md` — D016 row referenced from the docs prose (cite the decision
  ID next to the wall-clock flag documentation).

## Constraints

- Amend `commands/auto.md` additively — do not rewrite the existing self-continue/marker
  sections (P02's FR-14 contract text is verified by P02 tooling).
- No driver/library changes in this task.
- POSIX sh, bash-3.2-safe verifiers; suite members invoked as single `bash <path>` commands.

## Expected Output

`commands/auto.md` with the unattended-envelope contract subsection;
`tools/verify/m046-p04-docs-shape.sh` and `tools/verify/m046-p04-phase-suite.sh` green
(suite 9/9).
