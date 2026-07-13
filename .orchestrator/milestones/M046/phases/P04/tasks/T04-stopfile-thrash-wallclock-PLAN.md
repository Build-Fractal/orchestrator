---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M046"
name: "SC-6 stop-file live-kill + SC-7 thrash + wall-clock distinctness harnesses"
depends_on: [T02]
---

## Prerequisites

- `scripts/lifecycle/self-continue-drive.sh` carries the T02 envelope surface (see
  `T03-budget-kill-accounting-PLAN.md` Prerequisites for the flag/terminal/dotfile
  enumeration; identical surface consumed here).
- `tools/verify/m046-p04-fail-closed.sh`, `tools/verify/m046-p04-attended-parity.sh`,
  `tools/verify/m046-p04-envelope-unit.sh` are green.

## Description

Author three behavioral harnesses against the T02 driver surface, all following the P02
`m046-p02-child-abort.sh` conventions (POSIX sh, mktemp scratch + EXIT trap, printf-generated
stub children with baked-in scratch paths, PASS/FAIL counters, `SUMMARY: pass=N fail=N`,
exit 1 on any fail, real driver invocations only — no seeded markers, no fabricated output):

1. `tools/verify/m046-p04-stop-file-live.sh` — FR-10/SC-6: the operator stop-file kills a
   LIVE segment within bounded wall-clock latency (not one-full-segment latency).
2. `tools/verify/m046-p04-thrash.sh` — FR-12/SC-7: `SELF_CONTINUE:THRASH` fires after the
   default 2 no-progress segments, well before generous caps; attended runs never thrash.
3. `tools/verify/m046-p04-wall-clock.sh` — D016/#Q-7: the wall-clock ceiling kills
   mid-segment AND refuses pre-spawn, with a terminal distinct from budget/thrash/abort.

## Steps

1. **Author `tools/verify/m046-p04-stop-file-live.sh`.**

   **Case 1 — mid-segment live kill (SC-6 core).** Scratch milestone dir + stop-file path
   `$scratch/stop`; child stub: `sleep 15`, then `touch <mdir>/natural-end`, write
   `complete` marker, print `{"total_cost_usd":0.01}`, exit 0. Launch the driver in the
   BACKGROUND:
   `sh "$DRIVER" "$MDIR" --unattended --max-budget-usd 5 --max-continuations 3
   --max-wall-clock-s 120 --min-interval 0 --watchdog-poll-s 1 --stop-file "$scratch/stop"
   --auto-cmd "sh $STUB" > "$OUT" 2>/dev/null &` and record `DPID=$!`. Sleep 2 (child now
   mid-sleep), record `t0=$(date +%s)`, `touch "$scratch/stop"`, `wait $DPID`, record `t1`.
   Assert ALL of:
   - `t1 - t0` ≤ 6 (bounded latency, wall-clock-asserted — poll 1s + kill + reap; the
     one-full-segment alternative would be ≥ 13);
   - output contains `SELF_CONTINUE:STOPPED reason=stop-file stage=mid-segment`;
   - `natural-end` ABSENT (the live child was killed, did not finish);
   - no `CHILD_ABORT` line (envelope terminal took precedence);
   - ledger has `forfeit segment=1` (killed child's reserve counted — no free segment).

   **Case 2 — pre-loop stop still works (M045 parity).** Stop-file created BEFORE launch;
   assert existing `SELF_CONTINUE:STOPPED reason=stop-file` line (no `stage=mid-segment`),
   child sentinel absent, no segment reserve in ledger.

2. **Author `tools/verify/m046-p04-thrash.sh`.**

   Stub child (fast, ~0.2s): appends nothing to the cost log, writes `rotation P01` marker
   (same phase word every time — progress can never advance past the first segment), prints
   `{"total_cost_usd":0.01}`, exits 0.

   **Case 1 — THRASH before caps (SC-7 core).** Driver:
   `--unattended --max-budget-usd 50 --max-continuations 10 --max-wall-clock-s 120
   --min-interval 0 --watchdog-poll-s 1 --auto-cmd "sh $STUB"`. Assert:
   - output contains `SELF_CONTINUE:THRASH` with `threshold=2`;
   - count of `SELF_CONTINUE:SCHEDULED` lines ≤ 3 (halted after ~2 no-progress
     continuations — segment 1 sets the phase, segments 2–3 accrue no_progress 1 and 2);
   - NO `CAP_REACHED`, NO `BUDGET_EXCEEDED`, NO `WALL_CLOCK_EXCEEDED` (fired well before
     the generous caps — the "before caps" clause of SC-7);
   - exit 0.

   **Case 2 — attended control (FR-17: thrash is unattended-only).** Same stub, driver
   WITHOUT `--unattended` and with `--max-continuations 3`. Assert: output contains
   `SELF_CONTINUE:CAP_REACHED`, NO `THRASH` line.

   **Case 3 — progress resets the counter.** Stub that cycles phase words `P01, P02, P03`
   across invocations (persist a counter file in scratch, emit `rotation P0<n>` with n
   incrementing): with `--max-continuations 3` and threshold 2, assert `CAP_REACHED` and NO
   `THRASH` (every segment advances the phase, so no_progress never reaches 2).

3. **Author `tools/verify/m046-p04-wall-clock.sh`.**

   **Case 1 — mid-segment kill.** Child: `sleep 10`, then sentinel + `complete` marker +
   JSON. Driver: `--unattended --max-budget-usd 50 --max-continuations 5
   --max-wall-clock-s 3 --min-interval 0 --watchdog-poll-s 1`. Record elapsed. Assert:
   - output contains `SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=mid-segment`;
   - elapsed ≤ 8 (killed ~3–4s in, not the child's natural 10s);
   - sentinel ABSENT;
   - distinctness: NO `BUDGET_EXCEEDED`, NO `THRASH`, NO `CHILD_ABORT` in output (the
     generous $50 cap and absent cost records guarantee budget cannot be the trigger —
     the duration-trigger produces the WALL_CLOCK terminal, never the budget one; this is
     the inverse of SC-3's anti-proxy leg);
   - ledger has `forfeit segment=1`.

   **Case 2 — pre-spawn refusal.** Fast child (~0.6s per segment: writes `rotation P0<n>`
   with an incrementing phase counter so thrash never fires, prints JSON, exits 0).
   Driver: `--max-wall-clock-s 2 --max-continuations 50 --max-budget-usd 50
   --min-interval 0`. Segments respawn until run-elapsed crosses 2s between segments.
   Assert: output contains `SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=pre-spawn`; NO
   `CAP_REACHED`; exit 0.

4. `chmod +x` all three; run all Verification commands.

## Must-Haves

- Stop-file kills a live segment within bounded latency (phase Truth 4)
  - Check: `bash tools/verify/m046-p04-stop-file-live.sh`
- No-progress fixture halts on THRASH before caps; attended control reaches CAP_REACHED with no THRASH (phase Truth 5)
  - Check: `bash tools/verify/m046-p04-thrash.sh`
- Wall-clock kill mid-segment + pre-spawn refusal, terminal distinct from budget/thrash/abort (phase Truth 6)
  - Check: `bash tools/verify/m046-p04-wall-clock.sh`
- Artifact: tools/verify/m046-p04-stop-file-live.sh (min 40 lines, contains "stop-file")
- Artifact: tools/verify/m046-p04-thrash.sh (min 40 lines, contains "THRASH")
- Artifact: tools/verify/m046-p04-wall-clock.sh (min 40 lines, contains "WALL_CLOCK_EXCEEDED")

## Verification

```bash
bash tools/verify/m046-p04-stop-file-live.sh
bash tools/verify/m046-p04-thrash.sh
bash tools/verify/m046-p04-wall-clock.sh
bash tools/verify/m046-p04-attended-parity.sh
```

## Notes

Expected: each harness ends `SUMMARY: pass=N fail=0` exit 0; parity wrapper stays green.
Total runtime ~25s (stop-file ~6s, thrash ~5s, wall-clock ~12s).

Timing discipline: latency bounds are deliberately generous (≤ 6s / ≤ 8s against 1s poll)
for CI safety. If a case flakes, widen the child's natural duration and the bound TOGETHER,
preserving the gap that makes the assertion meaningful (bound must stay well under the
natural-completion time). Never weaken the sentinel-absent or distinct-terminal assertions.

The driver runs in the background in stop-file Case 1 — inside the verifier script this is
fine (the AD-19 shape rule constrains plan `Check:`/Verification commands, not verifier
internals).

## Inputs

### From Previous Tasks

- `scripts/lifecycle/self-continue-drive.sh` (from T02)
  - Key API: flag surface + terminals as enumerated in `T03-budget-kill-accounting-PLAN.md`
    Prerequisites; watchdog tick order stop-file → wall-clock → budget; THRASH threshold
    default 2, halts instead of SCHEDULED.
- `tools/verify/m046-p04-attended-parity.sh` (from T02) — regression gate re-run here.

### From Disk (Pre-existing)

- `tools/verify/m046-p02-child-abort.sh` — harness-shape precedent (background driver,
  printf-generated stubs, kill semantics).

## Constraints

- All fixture trees in mktemp scratch; no repo/state writes.
- Real driver invocations only — no seeded markers, no fabricated terminals (Principle II).
- POSIX sh, bash-3.2-safe; no jq.
- Do not modify the driver or the envelope library in this task; if a bug surfaces, it is
  a T02/T01 fix (re-open within FR-17 guards), then re-run all four Verification commands.

## Expected Output

Three green harnesses (`stop-file-live`, `thrash`, `wall-clock`), executable, with the
parity wrapper still green.
