---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M046"
name: "Envelope function library + unit verifier"
depends_on: []
---

## Prerequisites

- `scripts/lifecycle/self-continue-drive.sh` exists (M045/M046-P02 hardened driver; this task does NOT modify it — T02 does).
- `scripts/knowledge/write-summary.sh` exists — its `_ws_emit_unit_close` (line ~322) emits the production `unit_close` JSONL record whose printf template (line ~512) contains the keys `"record_type":"unit_close"` and `"estimated_cost_usd":<num|null>`. This task's cost probe MUST match those exact key names.
- `.orchestrator/milestones/M046/phases/P01/spike/cost/CADENCE-FINDINGS.md` exists — the binding #Q-4 verdict: JSONL `unit_close` records are readable mid-segment at unit grain but `estimated_cost_usd` is a NULLABLE advisory estimate; the authoritative per-segment actual is the child's `claude -p --output-format json` `total_cost_usd`.
- P02 atomic-write discipline: every marker-class write is temp-file-then-`mv -f`-rename in the same directory (see `scripts/lifecycle/self-continue-drive.sh` lines 109–113 for the canonical shape).

## Description

Create `scripts/lifecycle/unattended-envelope.sh` — a **sourceable POSIX-sh function library**
(no side effects at source time, `#!/usr/bin/env sh` header, works under bash 3.2 and dash;
no `declare -A`, no arrays, awk for float math). It is the M046 P04 unattended envelope's
brain: caps validation (FR-13), reserve-then-spend budget-lease ledger (FR-8), mid-segment
cost probe (FR-7), authoritative cost parse (FR-8 true-up), atomic kill-reason write, and the
watchdog poll loop (FR-7/FR-10/D016). The driver (T02) sources it and calls these functions
only under `--unattended`.

Also create `tools/verify/m046-p04-envelope-unit.sh` unit-testing every function against
mktemp fixtures (zero LLM, zero driver spawn).

## Steps

1. Create `scripts/lifecycle/unattended-envelope.sh` with this exact function surface
   (interface contracts below are binding; internal implementation may vary but MUST be
   POSIX sh + awk/grep/sed only — pipes and `$()` are fine INSIDE the script per the
   MEM004 lib-internal carve-out):

   **Header comment** must state: sourceable library, M046 P04 FR-7/FR-8/FR-10/FR-12/FR-13,
   D016 wall-clock resolution, the ledger line vocabulary, and that all functions are
   side-effect-free except the explicitly-writing ones.

   ```sh
   # envelope_caps_problems <budget_usd> <max_cont_set:true|false> <max_cont> <wall_s>
   #   stdout exactly one line:
   #     "ok"                                     — all three caps present and valid
   #     "caps-unset missing=<csv>"               — csv from {budget,continuations,wall-clock}
   #     "caps-invalid invalid=<csv>"             — set but non-numeric or <= 0
   #   Unset detection: budget_usd empty; max_cont_set != "true"; wall_s empty.
   #   Numeric validation: positive decimal (budget) / positive integer (cont, wall).
   #   caps-unset takes precedence over caps-invalid when both classes present.
   envelope_caps_problems() { ...; }

   # envelope_ledger_init <ledger> <cap_usd> <wall_s> <max_cont>
   #   Appends: run_start ts=<ISO8601-UTC> cap_usd=<x> wall_clock_s=<n> max_continuations=<n>
   #   Creates the file if absent. Append-only — never truncates (the ledger persists
   #   across runs; cumulative spend binds later runs, SC-4).
   envelope_ledger_init() { ...; }

   # envelope_next_segment <ledger>
   #   stdout: (count of lines starting with "reserve ") + 1. Missing file -> 1.
   envelope_next_segment() { ...; }

   # envelope_reserve <ledger> <segment> <amount_usd>
   #   Appends: reserve segment=<n> amount_usd=<x> ts=<ISO>
   envelope_reserve() { ...; }

   # envelope_reconcile <ledger> <segment> <actual_usd> <source>
   #   Appends: reconcile segment=<n> actual_usd=<x> source=<s> ts=<ISO>
   envelope_reconcile() { ...; }

   # envelope_forfeit <ledger> <segment> <amount_usd> <source>
   #   Appends: forfeit segment=<n> amount_usd=<x> source=<s> ts=<ISO>
   envelope_forfeit() { ...; }

   # envelope_spent_total <ledger>
   #   stdout: total spent USD as a decimal (e.g. "1.300000").
   #   Per-segment rule (FR-8 fail-closed): a reconcile or forfeit line for segment N
   #   OVERRIDES that segment's reserve; a bare reserve (no reconcile/forfeit yet)
   #   counts at its full reserve amount — an unreconciled reserve is SPENT, never free.
   #   Missing file -> 0. Implemented in one awk pass keyed by segment number.
   envelope_spent_total() { ...; }

   # envelope_observed_cost <log_file> <since_lines>
   #   stdout: decimal sum of NUMERIC estimated_cost_usd values on lines with
   #   NR > since_lines that contain "record_type":"unit_close".
   #   "estimated_cost_usd":null contributes 0 (P01: nullable advisory estimates).
   #   Missing file -> 0. awk match: /"estimated_cost_usd":[0-9][0-9.]*/
   envelope_observed_cost() { ...; }

   # envelope_parse_total_cost <result_json_file>
   #   stdout: the numeric total_cost_usd value, or EMPTY on missing file /
   #   missing key / non-numeric value (fail-closed: caller forfeits on empty).
   #   grep -o '"total_cost_usd"[[:space:]]*:[[:space:]]*[0-9][0-9.]*' + sed, head -n1.
   envelope_parse_total_cost() { ...; }

   # envelope_write_kill_reason <reason_file> <reason_line>
   #   ATOMIC write (P02 discipline): printf to "<reason_file>.tmp.$$" then
   #   mv -f into place. Same-directory rename. No direct redirect to the target.
   envelope_write_kill_reason() { ...; }

   # envelope_watchdog <child_pid> <poll_s> <stop_file> <deadline_epoch> \
   #                   <cap_usd> <spent_before_usd> <cost_log> <cost_baseline_lines> \
   #                   <reason_file>
   #   Foreground poll loop; returns 0 when the child is no longer alive.
   #   Each tick, in order, while `kill -0 <pid>` succeeds:
   #     1. stop-file: [ -n <stop_file> ] && [ -f <stop_file> ]
   #          -> envelope_write_kill_reason <reason_file> "stop-file"
   #     2. wall-clock: now_epoch >= deadline_epoch
   #          -> ... "wall-clock-exceeded elapsed_s=<e> cap_s=<c>"
   #     3. budget (cost-derived, SC-3): obs=$(envelope_observed_cost <cost_log> <baseline>);
   #        awk float compare: spent_before + obs >= cap_usd
   #          -> ... "budget-exceeded observed=<obs> spent_before=<s> cap=<c>"
   #     On any trigger: write reason FIRST (atomic), then `kill -9 <pid>`, then
   #     continue looping until kill -0 fails (the wait/reap happens in the caller).
   #     Empty <cost_log> or missing file: budget check contributes obs=0 (the
   #     pre-spawn reserve check in the driver is the backstop — never crash).
   #   sleep <poll_s> between ticks.
   envelope_watchdog() { ...; }
   ```

   Implementation notes (binding):
   - ISO timestamps: `date -u +%Y-%m-%dT%H:%M:%SZ` (MEM008).
   - Float comparisons/sums via awk only (`awk -v a="$a" -v b="$b" 'BEGIN{exit !(a+0>=b+0)}'`);
     never shell arithmetic on decimals.
   - Ledger appends are single-line `printf '%s\n' ... >> "$ledger"` (single-writer
     append; the safety property is the reserve-BEFORE-spawn ordering, enforced by the
     driver call sequence, not by append atomicity).
   - The ONLY file the watchdog writes is the kill-reason file, and only via
     `envelope_write_kill_reason` (atomic) — a SIGKILL can land at any instant relative
     to marker writes, and P02's torn-marker guarantee must extend to this file.
   - No function reads config files; the envelope is flag-driven only (FR-6).

2. Create `tools/verify/m046-p04-envelope-unit.sh` (`#!/usr/bin/env sh`, `set -eu`,
   mktemp scratch + `trap 'rm -rf "$scratch"' EXIT`, `pass()`/`fail()` counters, final
   `SUMMARY: pass=N fail=N` line, exit 1 on any fail — follow the shape of
   `tools/verify/m046-p02-child-abort.sh`). It sources the library
   (`. "$REPO_ROOT/scripts/lifecycle/unattended-envelope.sh"`) and asserts at minimum:

   - `envelope_caps_problems`: all-set-valid → `ok`; budget missing → `caps-unset missing=budget`;
     cont-not-explicit (`false 20`) → missing=continuations (the silent default is NOT accepted);
     wall missing → missing=wall-clock; all missing → `missing=budget,continuations,wall-clock`;
     budget `abc` → `caps-invalid invalid=budget`; wall `0` → invalid (must be > 0).
   - Ledger math: init + reserve(1, 1.00) → spent_total 1.00 (bare reserve is spent);
     + reconcile(1, 0.30) → 0.30 (true-up down); reserve(2, 1.00) + forfeit(2, 6.00) →
     spent 6.30 (forfeit overrides reserve, can exceed it); `envelope_next_segment` → 3;
     missing ledger → spent 0, next segment 1.
   - `envelope_observed_cost`: fixture log with 2 pre-baseline cost records, then after
     baseline: one `"estimated_cost_usd":2.5` unit_close, one `"estimated_cost_usd":null`
     unit_close, one non-unit_close record with a cost — sum == 2.5 exactly (null ignored,
     baseline honored, foreign record types ignored); missing file → 0.
   - `envelope_parse_total_cost`: file with `{"total_cost_usd":0.244,...}` → `0.244`;
     file without the key → empty; missing file → empty; `"total_cost_usd":"abc"` → empty.
   - `envelope_write_kill_reason`: behavioral — target contains exactly the reason line,
     no `*.tmp.*` residue in the directory; static — grep the library source for a
     `tmp.$$` temp path AND `mv -f`, and assert zero direct `> "$reason_file"`-style
     redirects to the target (P02 atomic-discipline verifier pattern).
   - `envelope_watchdog` (cheap behavioral, no driver): background `sleep 30`, run the
     watchdog with a pre-created stop-file and poll 1 → returns within ~3s, kill-reason
     file contains `stop-file`, PID dead. Second leg: background `sleep 30`, deadline
     already past → reason starts `wall-clock-exceeded`. Third leg: background a stub
     that appends a `"estimated_cost_usd":9.0` unit_close line to a fixture log after
     1s, cap 5, spent_before 0 → reason starts `budget-exceeded`, PID dead.

3. `chmod +x` both files.

## Must-Haves

- The envelope library functions honor their contracts in isolation (phase Truth 7)
  - Check: `bash tools/verify/m046-p04-envelope-unit.sh`
- Artifact: scripts/lifecycle/unattended-envelope.sh (min 120 lines, contains "envelope_spent_total")
- Artifact: tools/verify/m046-p04-envelope-unit.sh (min 80 lines, contains "SUMMARY:")

## Verification

```bash
bash tools/verify/m046-p04-envelope-unit.sh
sh -n scripts/lifecycle/unattended-envelope.sh
```

## Notes

Expected: the unit verifier ends with `SUMMARY: pass=<N> fail=0` and exits 0; `sh -n` is a
syntax-only pass (no output, exit 0). The watchdog legs sleep a few seconds — total runtime
should stay under ~15s.

Do NOT touch `scripts/lifecycle/self-continue-drive.sh` or `scripts/lifecycle/auto-loop.sh`
in this task (CON-2; driver integration is T02). Do NOT create files under `tests/fixtures/`
— all fixtures are mktemp-scratch-internal to the verifier.

## Inputs

### From Previous Tasks

- none (first task of the phase)

### From Disk (Pre-existing)

- `scripts/knowledge/write-summary.sh` — read-only reference for the unit_close record keys
  (`"record_type":"unit_close"`, `"estimated_cost_usd":`); the probe regex must match this
  production emitter template (printf at line ~512).
- `scripts/lifecycle/self-continue-drive.sh` — read-only reference for the P02 atomic
  temp+rename shape (lines 109–113) that `envelope_write_kill_reason` must mirror.
- `.orchestrator/milestones/M046/phases/P01/spike/cost/CADENCE-FINDINGS.md` — the #Q-4
  cost-source split this library implements.

## Constraints

- POSIX sh, bash-3.2-safe; no `declare -A`, no process substitution, no jq hard dependency.
- Sourcing the library must be side-effect-free (defines functions only) — T02 sources it
  unconditionally and FR-17 requires the attended path byte-behavior unchanged.
- No config-file reads (FR-6: flag-driven only, no config enable for unattended).
- Kill-reason writes atomic (temp+rename); ledger is append-only, never truncated.

## Expected Output

`scripts/lifecycle/unattended-envelope.sh` (sourceable, 11 functions) and
`tools/verify/m046-p04-envelope-unit.sh` (green, `SUMMARY: pass=N fail=0`), both executable.
