---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M046"
name: "SC-3 cost-discriminating budget-kill harness + SC-4 accounting harness"
depends_on: [T02]
---

## Prerequisites

- `scripts/lifecycle/self-continue-drive.sh` carries the T02 envelope surface: flags
  `--unattended --max-budget-usd --max-continuations --max-wall-clock-s --segment-reserve-usd
  --watchdog-poll-s --min-interval --auto-cmd --stop-file`; terminals
  `SELF_CONTINUE:BUDGET_EXCEEDED stage=<mid-segment|pre-spawn> ...`,
  `SELF_CONTINUE:CHILD_ABORT`, `SELF_CONTINUE:TERMINAL outcome=...`,
  `SELF_CONTINUE:CAP_REACHED`; ledger at `<milestone-dir>/.self-continue-budget-ledger`
  (`run_start`/`reserve`/`reconcile`/`forfeit` lines); default cost log
  `<milestone-dir>/execution-log.jsonl`; captured child stdout at
  `<milestone-dir>/.self-continue-segment-result.json`.
- `tools/verify/m046-p04-fail-closed.sh` and `tools/verify/m046-p04-envelope-unit.sh` are green.
- `scripts/knowledge/write-summary.sh` exists — the production `unit_close` printf template
  (line ~512) is the shape the fixture records must mirror.

## Description

Author the milestone's hardest fixture — the **SC-3 non-stubbed, cost-discriminating
budget-kill harness** `tools/verify/m046-p04-budget-kill.sh` — plus the **SC-4
reserve-then-spend accounting harness** `tools/verify/m046-p04-reserve-spend.sh`.

**SC-3 honesty design (binding; this is what "non-stubbed" means here):**
- The REAL driver + REAL envelope watchdog run end-to-end; the only substitution is the
  LLM child, replaced by a live shell process (the P02 `m046-p02-child-abort.sh` precedent:
  stand-in children driving the real driver truth table).
- The child **emits genuine `unit_close` records mid-flight** — production-shaped JSONL
  lines appended to the LIVE default log path (`<milestone-dir>/execution-log.jsonl`) WHILE
  the child runs, at controlled dollar values. The watchdog reads them through the same
  `envelope_observed_cost` probe production uses. NO pre-seeded log, NO seeded verdict,
  NO marker fabrication, NO duration proxy.
- **Cost discrimination**: two children with IDENTICAL timing structure (same record-emit
  schedule, same natural sleep duration, same completion behavior) differing ONLY in the
  `estimated_cost_usd` values they emit. The high-cost one must be SIGKILLed mid-flight with
  the budget terminal; the low-cost control must complete unkilled. Because duration is held
  constant by construction, an implementation that triggers on any duration proxy relabeled
  "budget-exceeded" kills both or neither — and fails the harness either way.
- **Shape-pin leg**: the harness greps `scripts/knowledge/write-summary.sh` for the literal
  keys `"record_type":"unit_close"` and `"estimated_cost_usd":` to prove the fixture records
  and the watchdog probe use the exact production key names (drift in either direction fails).

## Steps

1. **Author `tools/verify/m046-p04-budget-kill.sh`** (`#!/usr/bin/env sh`, `set -eu`, mktemp
   scratch + EXIT trap, PASS/FAIL counters, `SUMMARY: pass=N fail=N`, exit 1 on any fail).

   Shared stub generator (write into scratch; paths baked in via printf like
   `m046-p02-child-abort.sh` does — scratch mktemp paths contain no spaces or disallowed
   charset bytes, so they pass the driver's FR-15 allowlist and `--auto-cmd`
   whitespace-split):

   ```sh
   # gen_child <path> <cost-per-record>  — 3 unit_close records at ~0.3s, then sleep 8,
   # then natural-completion sentinel + marker + authoritative JSON, exit 0
   #!/usr/bin/env sh
   LOG="<mdir>/execution-log.jsonl"
   sleep 0.3 2>/dev/null || sleep 1
   i=1
   while [ $i -le 3 ]; do
     printf '{"record_type":"unit_close","granularity":"task","unitId":"MFIX/P01/T0%s","milestone":"MFIX","phase":"P01","task":"T0%s","duration_s":1,"outcome":"pass","completed_at":"2026-07-13T00:00:00Z","estimated_cost_usd":<COST>,"pricing_version":"fixture","verification_pass_rate":1.0,"deviation_count":0,"retry_count":0,"filter_dropped_tokens":0,"tier1_savings_tokens":0,"tier2_savings_tokens":0,"tier1_invocations":0,"tier3_compression_savings_tokens":0,"tier3_invocations":0,"source":"m046-p04-fixture","timestamp":"2026-07-13T00:00:00Z"}\n' >> "$LOG"
     i=$((i+1))
   done
   sleep 8
   touch "<mdir>/natural-end"
   printf 'complete\n' > "<mdir>/.self-continue-outcome"
   printf '{"total_cost_usd":0.05,"result":"fixture"}\n'
   exit 0
   ```

   (Record fields mirror the `_ws_emit_unit_close` printf template — keep every key; only
   `estimated_cost_usd` varies between cases: `2.00` runaway / `0.02` control.)

   **Case A — runaway killed mid-flight (SC-3 core).** Fresh scratch milestone dir `MA`
   (must contain a `phases/` subdir is NOT required — the driver only needs the dir);
   child = `gen_child` with cost `2.00` (3 records = $6.00 observed). Record `t0=$(date +%s)`,
   run:
   `sh "$DRIVER" "$MA" --unattended --max-budget-usd 5 --max-continuations 2 --max-wall-clock-s 120 --min-interval 0 --watchdog-poll-s 1 --auto-cmd "sh $STUB_A"`,
   capture stdout + exit code, `t1=$(date +%s)`. Assert ALL of:
   - output contains `SELF_CONTINUE:BUDGET_EXCEEDED stage=mid-segment`;
   - output contains NONE of `WALL_CLOCK_EXCEEDED`, `SELF_CONTINUE:THRASH`,
     `SELF_CONTINUE:CHILD_ABORT`, `CAP_REACHED` (distinct-terminal leg; the generous
     120s wall cap guarantees wall-clock cannot be the trigger);
   - `<MA>/natural-end` sentinel ABSENT (child died mid-sleep — killed, did not finish);
   - bounded latency: `t1 - t0` ≤ 6 (records land ~0.3s in; poll 1s; natural duration
     ~8.5s — a kill after natural end would show ≥ 8);
   - ledger `<MA>/.self-continue-budget-ledger` has `reserve segment=1` AND a
     `forfeit segment=1` line with `amount_usd=6` prefix (unreconciled forfeit =
     max(reserve, observed) = observed 6.00) — the kill did not leave the spend
     unaccounted (SC-4 adjacency);
   - driver exit code 0 (terminal, not crash).

   **Case B — equal-duration low-cost control completes (anti-proxy leg).** Fresh scratch
   dir `MB`; child = `gen_child` with cost `0.02` (identical timing). Same driver flags
   (`--max-continuations 1` to end after one segment). Assert ALL of:
   - NO `BUDGET_EXCEEDED` anywhere in output;
   - `<MB>/natural-end` PRESENT (ran to natural completion);
   - elapsed ≥ 8 (full natural duration — nothing shortened it);
   - output contains `SELF_CONTINUE:TERMINAL outcome=complete`;
   - ledger has `reconcile segment=1 actual_usd=0.05 source=total_cost_usd` (the
     authoritative JSON true-up, NOT the reserve).

   **Case C — shape-pin.** `grep -q '"record_type":"unit_close"'
   scripts/knowledge/write-summary.sh` AND `grep -q '"estimated_cost_usd":'
   scripts/knowledge/write-summary.sh` AND grep the SAME two literals in this harness's own
   generated stub text and in `scripts/lifecycle/unattended-envelope.sh`'s probe — all four
   must hit, proving fixture, watchdog, and production emitter share key names.

   **Case D — null-cost records do not trigger (nullable-estimate honesty, P01 verdict).**
   Fresh dir `MD`; child identical to Case A but emits `"estimated_cost_usd":null` on all 3
   records and sleeps only 3s, then completes. Assert: no `BUDGET_EXCEEDED`, natural-end
   present — null values contribute 0 and never false-trigger a kill.

2. **Author `tools/verify/m046-p04-reserve-spend.sh`** (same harness conventions). Uses a
   small reserve to keep math visible: `--segment-reserve-usd 1.00`.

   **Case 1 — killed-before-flush decrements (SC-4 core).** Scratch dir `M1`; child:
   `kill -9 $$` immediately (no JSON, no records, no marker). Driver flags:
   `--unattended --max-budget-usd 1.50 --max-continuations 3 --max-wall-clock-s 60
   --min-interval 0 --watchdog-poll-s 1 --segment-reserve-usd 1.00 --auto-cmd "sh $STUB"`.
   Assert: output has `SELF_CONTINUE:CHILD_ABORT` (envelope did not kill it — the child
   crashed; the P02 truth table owns this terminal); ledger has `reserve segment=1
   amount_usd=1.00` AND `forfeit segment=1 amount_usd=1.00` with `source=unreconciled`
   (reserve counted as spent, fail-closed); NO `reconcile` line.

   **Case 2 — cross-run cap binding (the decrement is real).** Re-run the driver against the
   SAME `M1` dir and ledger with the same flags and a benign child (would write `complete`
   + JSON if it ran) that also touches a sentinel. Assert: output has
   `SELF_CONTINUE:BUDGET_EXCEEDED stage=pre-spawn` (spent 1.00 + reserve 1.00 > cap 1.50);
   sentinel ABSENT (never spawned); ledger has NO `reserve segment=2` line; exit 0.
   Combined ledger spend (1.00) never exceeded the 1.50 cap — SC-4's "the run does not
   over-spend" leg.

   **Case 3 — true-up reconcile (spend is actual, not reserve).** Fresh dir `M3`, cap 5;
   child prints `{"total_cost_usd":0.30}`, writes `rotation P01` marker, exits 0;
   `--max-continuations 1` → `CAP_REACHED` after one segment. Assert: ledger has
   `reconcile segment=1 actual_usd=0.30 source=total_cost_usd`; a subsequent
   `envelope_spent_total` (source the library in the verifier) returns 0.30 (not 1.00) —
   reconciliation freed the unspent reserve.

3. `chmod +x` both verifiers; run all Verification commands.

## Must-Haves

- Cost-derived mid-flight SIGKILL with distinct budget terminal; equal-duration control unkilled (phase Truth 2)
  - Check: `bash tools/verify/m046-p04-budget-kill.sh`
- Killed-before-flush forfeits reserve; subsequent run refuses pre-spawn; normal exit trues-up from total_cost_usd (phase Truth 3)
  - Check: `bash tools/verify/m046-p04-reserve-spend.sh`
- Artifact: tools/verify/m046-p04-budget-kill.sh (min 100 lines, contains "BUDGET_EXCEEDED")
- Artifact: tools/verify/m046-p04-reserve-spend.sh (min 70 lines, contains "forfeit")
- Key Link: tools/verify/m046-p04-budget-kill.sh → scripts/knowledge/write-summary.sh

## Verification

```bash
bash tools/verify/m046-p04-budget-kill.sh
bash tools/verify/m046-p04-reserve-spend.sh
bash tools/verify/m046-p04-attended-parity.sh
```

## Notes

Expected: both harnesses end `SUMMARY: pass=N fail=0`, exit 0; the parity wrapper stays green
(these harnesses must not have required driver changes that break attended behavior — if a
driver bug surfaces, fix it in the driver WITHIN the FR-17 guards and re-run all three).

Runtime budget: Case A ~4s, B ~9s, D ~4s, reserve-spend ~6s — keep total under ~30s. Use
`sleep` values exactly as specified; do not "speed up" Case B below 8s or the anti-proxy
elapsed assertion loses its meaning.

If Case A flakes on a slow machine (kill later than 6s), the fix is raising the latency
bound to 8 AND the natural duration to 12 together — never weakening the sentinel-absent or
distinct-terminal assertions.

## Inputs

### From Previous Tasks

- `scripts/lifecycle/self-continue-drive.sh` (from T02)
  - Key API: flag surface + terminal lines + ledger/dotfile paths listed in Prerequisites.
  - Key behavior: watchdog polls every `--watchdog-poll-s`; budget trigger =
    spent_before + observed-non-null-unit_close-cost ≥ cap → atomic kill-reason write →
    SIGKILL → `BUDGET_EXCEEDED stage=mid-segment`; unparseable segment stdout → forfeit
    max(reserve, observed).
- `scripts/lifecycle/unattended-envelope.sh` (from T01)
  - Key API: `envelope_spent_total <ledger>` (sourced by reserve-spend Case 3 assertion).

### From Disk (Pre-existing)

- `scripts/knowledge/write-summary.sh` — shape-pin grep target (production unit_close keys).
- `tools/verify/m046-p02-child-abort.sh` — harness-shape precedent (scratch stubs, PASS/FAIL,
  SUMMARY line).

## Constraints

- Non-stubbed discipline (SC-3, milestone-blocking): real driver, real watchdog, live
  mid-flight log appends; NO pre-seeded logs, NO seeded markers, NO fabricated terminals.
- All fixture trees in mktemp scratch; nothing written under the repo or `.orchestrator/`.
- POSIX sh, bash-3.2-safe; no jq (parse with grep/sed/awk).
- Do not modify the P02 verifiers or goldens.

## Expected Output

`tools/verify/m046-p04-budget-kill.sh` (4 cases green) and
`tools/verify/m046-p04-reserve-spend.sh` (3 cases green), both executable, parity wrapper
still green.
