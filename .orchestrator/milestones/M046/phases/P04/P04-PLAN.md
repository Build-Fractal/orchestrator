---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M046"
goal: "Serial --unattended budget/caps envelope on the process-fresh driver: in-segment cost-derived SIGKILL watchdog, reserve-then-spend ledger, stop-file live-kill, SELF_CONTINUE:THRASH terminal, and fail-closed refuse-to-start when budget/continuations/wall-clock caps are unset"
demo_sentence: "A runaway segment under --unattended --max-budget-usd 5 is SIGKILLed mid-flight with a distinct SELF_CONTINUE:BUDGET_EXCEEDED terminal while an equal-duration low-cost control completes unkilled (proving the trigger is cost-derived, not a duration proxy); a child killed before flushing cost still decrements the budget; the stop-file kills a live segment within bounded latency; a no-progress fixture halts on SELF_CONTINUE:THRASH; and missing caps refuse to start with exit 2."
risk: "high"
depends_on: [P01, P02]
---

## Phase Overview

P04 builds the serial `--unattended` safety envelope (FR-6, FR-7, FR-8, FR-10, FR-12, FR-13)
as a layer on the M045/P02 process-fresh driver `scripts/lifecycle/self-continue-drive.sh`.
`auto-loop.sh` is NOT touched (CON-2 — P02 consumed the single authorized additive change).
The attended driver path stays byte-compatible with M045 (FR-17): every new behavior is
guarded by an `UNATTENDED=true` flag variable that only `--unattended` can set (FR-6 — no
config enable).

**Envelope placement decision (recorded here, Design-Before-Code):** the envelope ships as a
**sourceable sibling function library** `scripts/lifecycle/unattended-envelope.sh` (pure-ish
POSIX-sh functions: caps validation, ledger math, mid-segment cost probe, kill-reason write,
watchdog loop), with the driver `self-continue-drive.sh` gaining only flag parsing, the
fail-closed gate, and thin call sites guarded by `UNATTENDED=true`. Rationale:
(a) CON-2/FR-17 — the P02 verifiers (`m046-p02-legacy-parity.sh`, `m046-p02-child-abort.sh`,
`m046-p02-driver-continue-class.sh`, `m046-p02-injection-reject.sh`,
`m046-p02-atomic-write-discipline.sh` static leg) grep and drive `self-continue-drive.sh`
directly; keeping the driver diff small keeps those regression surfaces auditable and green.
(b) The envelope functions are independently unit-testable with temp ledgers/logs (no LLM, no
driver spawn) — SC-8/SC-4 math gets Tier-3-free mechanical coverage.
(c) Deep-module seam: the future v2c fan-out coordinator reuses the same ledger/watchdog
functions; the library is the module boundary, the driver is one consumer. Deletion test:
removing the library removes exactly the unattended capability and nothing attended.

**#Q-7 RESOLVED (Decision D016, `.orchestrator/DECISIONS.md`, recorded at plan time):** the
wall-clock ceiling is an **operator-supplied per-run flag `--max-wall-clock-s <seconds>`**
(whole-run ceiling measured from driver start) with **no default on the unattended path** —
the FR-13 fail-closed enumeration refuses to start if it is unset. Enforced live by the
mid-segment watchdog (kill + `SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=mid-segment`) and by a
pre-spawn check (`stage=pre-spawn`). Attended path unaffected. A fixed internal constant was
rejected because FR-13's text presumes the ceiling can be *unset* — a constant can never be
unset, making the enumeration vacuous. CON-4 presence-always-on is preserved by refuse-to-start.

**Cost-source contract (P01 #Q-4 verdict, binding on this phase):**
- The **watchdog's budget trigger is cost-derived**: it sums non-null `estimated_cost_usd`
  values from `"record_type":"unit_close"` records appended to the milestone execution log
  (`<milestone-dir>/execution-log.jsonl` by default — the exact path
  `scripts/knowledge/write-summary.sh::_ws_emit_unit_close` writes, including its fixture
  carve-out) since segment start. Null values are advisory-absent and contribute 0 (P01:
  values are nullable estimates; presence is never assumed).
- The **ledger's truth source is the exiting child's `claude -p --output-format json`
  `total_cost_usd`** (P00-proven authoritative), parsed from the segment's captured stdout at
  each segment boundary (FR-8 true-up). A segment with no parseable actual **forfeits**
  `max(reserve, observed-mid-segment-cost)` — unreconciled reserve counts as spent, never free.
- The **duration/wall-clock trigger is independent** of the nullable cost stream (P01:
  "duration probe primary") and produces a *distinct* terminal — it is never relabeled as
  budget-exceeded (SC-3 anti-proxy requirement).
- Known quirk honored: `budget-checker.sh`/`stuck-detector.sh` grep a literal `"dispatch"`
  token that `record-result.sh` output does not match — the envelope's accounting deliberately
  does NOT build on those scripts; the ledger is a new, self-contained surface.

**New on-disk surfaces (all runtime dotfiles inside `<milestone-dir>/`, sibling to the P02
marker):**
- `.self-continue-budget-ledger` — append-only accounting ledger, line-oriented
  `key=value` records (`run_start` / `reserve` / `reconcile` / `forfeit`). Persists across
  driver runs so a crashed run's forfeit still binds the next run's cap (SC-4). Operator
  starts a fresh budget by deleting the file (documented in `commands/auto.md`).
- `.self-continue-kill-reason` — envelope-owned, written atomically (temp+rename, P02
  discipline) by the watchdog BEFORE the SIGKILL; consumed and removed by the driver after
  `wait` to select the distinct terminal (budget / wall-clock / stop-file). Its presence is
  what keeps an envelope kill from being misreported as plain `CHILD_ABORT`.
- `.self-continue-segment-result.json` — the unattended child's captured stdout (the
  `--output-format json` result), parsed for `total_cost_usd` at reconcile time. Truncated
  per segment.

**Terminal vocabulary added (driver stdout lines, all exit 0 like existing terminals; refusal
exits 2 like `SELF_CONTINUE:REJECT`):**
- `SELF_CONTINUE:REFUSE reason=caps-unset missing=<csv>` / `reason=caps-invalid invalid=<csv>` (exit 2, FR-13)
- `SELF_CONTINUE:BUDGET_EXCEEDED stage=<mid-segment|pre-spawn> spent=<usd> observed=<usd> cap=<usd> continuations=<n> progress=<n>` (FR-7/FR-8)
- `SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=<mid-segment|pre-spawn> elapsed_s=<s> cap_s=<s> continuations=<n> progress=<n>` (#Q-7/D016)
- `SELF_CONTINUE:STOPPED reason=stop-file stage=mid-segment continuations=<n> progress=<n>` (FR-10; the existing between-segment `SELF_CONTINUE:STOPPED reason=stop-file` line is unchanged)
- `SELF_CONTINUE:THRASH no_progress_segments=<n> threshold=<n> continuations=<n> progress=<n>` (FR-12, default threshold 2)

## Must-Haves

### Truths

- Under `--unattended`, the driver itself refuses to start (exit 2, `SELF_CONTINUE:REFUSE`, no ledger write, no child spawn) when the budget cap, `--max-continuations`, or `--max-wall-clock-s` is unset or non-numeric — invoked directly, bypassing any CLI layer, with no silent `MAX_CONT=20` default on the unattended path (FR-13 / SC-8)
  - Check: `bash tools/verify/m046-p04-fail-closed.sh`
- A live segment whose mid-flight non-null `unit_close` cost crosses the budget cap is SIGKILLed within bounded latency with a distinct `SELF_CONTINUE:BUDGET_EXCEEDED stage=mid-segment` terminal, while an equal-duration low-cost control segment completes unkilled — the trigger is proven cost-derived, not a duration proxy (FR-7 / SC-3, non-stubbed: real driver, real watchdog, live mid-flight appends to the real log path, no seeded verdicts)
  - Check: `bash tools/verify/m046-p04-budget-kill.sh`
- A child killed before flushing its `total_cost_usd` record leaves its reserve counted as spent (forfeit ≥ reserve in the ledger), a subsequent run against the same ledger refuses to spawn past the cap at the pre-spawn check, and a normally-exiting child's ledger entry is trued-up from its actual `total_cost_usd` (FR-8 / SC-4)
  - Check: `bash tools/verify/m046-p04-reserve-spend.sh`
- Creating the stop-file mid-segment kills the live child and terminates the driver within bounded latency (asserted against wall-clock, not next-spawn), with the child's natural-completion sentinel absent (FR-10 / SC-6)
  - Check: `bash tools/verify/m046-p04-stop-file-live.sh`
- A no-progress fixture (continue-class exits, phase word never advances) halts on `SELF_CONTINUE:THRASH` after the default 2 no-progress segments, well before generous iteration/budget caps; the same fixture WITHOUT `--unattended` runs to `CAP_REACHED` with no THRASH (unattended-only, FR-12 / SC-7 / FR-17)
  - Check: `bash tools/verify/m046-p04-thrash.sh`
- A run whose wall-clock ceiling is crossed mid-segment is killed with `SELF_CONTINUE:WALL_CLOCK_EXCEEDED` distinct from the budget/thrash/child-abort terminals, and a run that outlives its ceiling between segments halts at the pre-spawn check (FR-7/FR-13/D016)
  - Check: `bash tools/verify/m046-p04-wall-clock.sh`
- The envelope library functions honor their contracts in isolation: caps-problem detection, spent-total math (reconcile/forfeit override reserve; bare reserve counts as spent), non-null-only observed-cost summation with line-offset baseline, total_cost_usd parsing with fail-closed empty on malformed input, and atomic temp+rename kill-reason writes
  - Check: `bash tools/verify/m046-p04-envelope-unit.sh`
- The attended driver path is behaviorally unchanged: all four P02 driver verifiers (legacy-parity golden, child-abort truth table, continue-class mapping, injection reject) stay green against the envelope-bearing driver (FR-17 / CON-3)
  - Check: `bash tools/verify/m046-p04-attended-parity.sh`
- `commands/auto.md` documents the unattended envelope contract: the three mandatory caps, the refusal line, the ledger/kill-reason/result-file surfaces, the new terminal vocabulary, and the ledger-reset-by-deletion operator action
  - Check: `bash tools/verify/m046-p04-docs-shape.sh`

### Artifacts

- scripts/lifecycle/unattended-envelope.sh (min 120 lines, contains "envelope_spent_total")
- scripts/lifecycle/self-continue-drive.sh (min 230 lines, contains "SELF_CONTINUE:REFUSE")
- tools/verify/m046-p04-envelope-unit.sh (min 80 lines, contains "SUMMARY:")
- tools/verify/m046-p04-fail-closed.sh (min 60 lines, contains "caps-unset")
- tools/verify/m046-p04-attended-parity.sh (min 20 lines, contains "m046-p02-legacy-parity")
- tools/verify/m046-p04-budget-kill.sh (min 100 lines, contains "BUDGET_EXCEEDED")
- tools/verify/m046-p04-reserve-spend.sh (min 70 lines, contains "forfeit")
- tools/verify/m046-p04-stop-file-live.sh (min 40 lines, contains "stop-file")
- tools/verify/m046-p04-thrash.sh (min 40 lines, contains "THRASH")
- tools/verify/m046-p04-wall-clock.sh (min 40 lines, contains "WALL_CLOCK_EXCEEDED")
- tools/verify/m046-p04-docs-shape.sh (min 20 lines, contains "unattended")
- tools/verify/m046-p04-phase-suite.sh (min 40 lines, contains "SUITE:")
- commands/auto.md (min 400 lines, contains "unattended")

### Key Links

- scripts/lifecycle/self-continue-drive.sh → scripts/lifecycle/unattended-envelope.sh (driver sources the envelope library)
- commands/auto.md → unattended-envelope.sh (docs name the envelope library)
- tools/verify/m046-p04-budget-kill.sh → scripts/knowledge/write-summary.sh (SC-3 shape-pin leg greps the production unit_close emitter template)
- tools/verify/m046-p04-phase-suite.sh → tools/verify/m046-p04-budget-kill.sh (suite membership)

## Tasks

### T01: Envelope function library + unit verifier

Create `scripts/lifecycle/unattended-envelope.sh` (sourceable POSIX-sh function library: caps
validation, budget-lease ledger append/aggregate, mid-segment non-null unit_close cost probe,
authoritative total_cost_usd parse, atomic kill-reason write, watchdog poll loop) and
`tools/verify/m046-p04-envelope-unit.sh` exercising every function against temp fixtures.
See `tasks/T01-envelope-lib-PLAN.md`.

### T02: Driver integration — flags, fail-closed gate, watchdog wiring, reserve/reconcile, thrash

Modify `scripts/lifecycle/self-continue-drive.sh`: parse the unattended flag set, enforce the
FR-13 fail-closed refusal in the driver, background the child under `--unattended` with the
envelope watchdog in the foreground, export the hard limits into the child's environment,
reserve-then-spend around each segment, consume the kill-reason file into distinct terminals,
and add the THRASH terminal. Author `tools/verify/m046-p04-fail-closed.sh` (SC-8) and
`tools/verify/m046-p04-attended-parity.sh` (FR-17 wrapper over the four P02 driver verifiers).
See `tasks/T02-driver-envelope-PLAN.md`.

### T03: SC-3 cost-discriminating budget-kill harness + SC-4 accounting harness

Author `tools/verify/m046-p04-budget-kill.sh` (runaway vs equal-duration control, live
mid-flight unit_close appends at controlled dollar values, latency bound, distinct-terminal
and anti-proxy assertions, production shape-pin) and `tools/verify/m046-p04-reserve-spend.sh`
(killed-before-flush forfeit, cross-run cap binding, true-up reconcile).
See `tasks/T03-budget-kill-accounting-PLAN.md`.

### T04: SC-6 stop-file live-kill + SC-7 thrash + wall-clock distinctness harnesses

Author `tools/verify/m046-p04-stop-file-live.sh`, `tools/verify/m046-p04-thrash.sh`, and
`tools/verify/m046-p04-wall-clock.sh`. See `tasks/T04-stopfile-thrash-wallclock-PLAN.md`.

### T05: commands/auto.md envelope contract + docs verifier + phase suite

Document the unattended envelope in `commands/auto.md`; author
`tools/verify/m046-p04-docs-shape.sh` and the aggregator `tools/verify/m046-p04-phase-suite.sh`
(all P04 verifiers + the FR-17 parity wrapper). See `tasks/T05-docs-phase-suite-PLAN.md`.

## Task Dependencies

T01 → T02 → T03
T02 → T04  (T03 and T04 can run in parallel after T02)
T03 + T04 → T05

## Boundary Map

- T01 Produces: `scripts/lifecycle/unattended-envelope.sh` (function contracts: `envelope_caps_problems`, `envelope_ledger_init`, `envelope_next_segment`, `envelope_reserve`, `envelope_reconcile`, `envelope_forfeit`, `envelope_spent_total`, `envelope_observed_cost`, `envelope_parse_total_cost`, `envelope_write_kill_reason`, `envelope_watchdog`); `tools/verify/m046-p04-envelope-unit.sh`. Consumes: P02 atomic temp+rename discipline (pattern); P01 CADENCE-FINDINGS cost-source split; `scripts/knowledge/write-summary.sh` unit_close record shape (read-only reference).
- T02 Produces: envelope-integrated `scripts/lifecycle/self-continue-drive.sh` (flag surface `--unattended --max-budget-usd --max-wall-clock-s --segment-reserve-usd --thrash-threshold --watchdog-poll-s --cost-log`; `SELF_CONTINUE:REFUSE/BUDGET_EXCEEDED/WALL_CLOCK_EXCEEDED/THRASH` + `STOPPED stage=mid-segment` terminals; child env exports); `tools/verify/m046-p04-fail-closed.sh`; `tools/verify/m046-p04-attended-parity.sh`. Consumes: T01 library; P02 hardened driver (run_child argv array, CHILD_ABORT wrapper, marker discipline).
- T03 Produces: `tools/verify/m046-p04-budget-kill.sh` (SC-3); `tools/verify/m046-p04-reserve-spend.sh` (SC-4). Consumes: T02 driver surface; write-summary.sh emitter template (shape-pin).
- T04 Produces: `tools/verify/m046-p04-stop-file-live.sh` (SC-6); `tools/verify/m046-p04-thrash.sh` (SC-7); `tools/verify/m046-p04-wall-clock.sh`. Consumes: T02 driver surface.
- T05 Produces: `commands/auto.md` unattended-envelope section; `tools/verify/m046-p04-docs-shape.sh`; `tools/verify/m046-p04-phase-suite.sh`. Consumes: T01–T04 verifier set + terminal vocabulary.

## Plan-Time Discipline Record

1. **Prerequisite existence** — verified on disk at plan-authoring time:
   `scripts/lifecycle/self-continue-drive.sh` (150 lines, P02 shape), `scripts/lifecycle/auto-loop.sh`,
   `scripts/knowledge/write-summary.sh` (`_ws_emit_unit_close` at line 322; printf template at line 512;
   log path `$orch_root/milestones/$m/execution-log.jsonl` with milestone-dir fixture carve-out at lines 337–346),
   `tools/verify/m046-p02-legacy-parity.sh`, `tools/verify/m046-p02-child-abort.sh`,
   `tools/verify/m046-p02-driver-continue-class.sh`, `tools/verify/m046-p02-injection-reject.sh`,
   `.orchestrator/milestones/M046/phases/P01/spike/cost/CADENCE-FINDINGS.md`, `commands/auto.md`
   (self-continue section lines ~527–607). All present.
2. **Verifier availability** — every `## Verification` command in every task plan is either
   (a) authored inside that same task's Steps, (b) an upstream task's deliverable consumed in
   dependency order, or (c) already on disk (the four P02 verifiers). No forward references.
3. **Classifier pre-validation** — `bash scripts/util/classify-command.sh "bash tools/verify/m046-p04-budget-kill.sh"`
   → `AUTO_SAFE` (recorded at plan time; all Check: commands share this single-script shape).
   Counter-trace: a raw driver invocation with scratch paths
   (`sh scripts/lifecycle/self-continue-drive.sh /tmp/... --unattended ...`) classifies
   `APPROVAL_REQUIRED reason=tmp_write` — therefore NO task plan places raw driver invocations
   in `## Verification`; drivers are exercised only inside verifier scripts (which use mktemp
   scratch internally, per the P02 `m046-p02-child-abort.sh` precedent).
4. **run-probe scope** — all verifiers are repo-resident under `tools/verify/` and are invoked
   directly (`bash tools/verify/...`); `run-probe.sh` is not used anywhere in this phase.
5. **Real-DB rule** — N/A: no SQL, schema, or DB-bound code in this phase.
6. **Path-collision check** — `ls` performed at plan time: no `tools/verify/m046-p04-*` exists
   (tools/verify tops out at `m046-p02-*`); `scripts/lifecycle/unattended-envelope.sh` does not
   exist; no `tests/fixtures/m046-p04/` is created (fixture children are generated in mktemp
   scratch inside the verifiers, per the P02 child-abort precedent — the roadmap's "SC-x
   fixtures" are realized as verifier-embedded stubs). Runtime dotfiles
   (`.self-continue-budget-ledger`, `.self-continue-kill-reason`,
   `.self-continue-segment-result.json`) have no existing references anywhere in the repo
   (grepped at plan time). `commands/auto.md` and `self-continue-drive.sh` are declared
   modify, not create.

## Files Likely Touched

- scripts/lifecycle/unattended-envelope.sh (create)
- scripts/lifecycle/self-continue-drive.sh (modify)
- commands/auto.md (modify)
- tools/verify/m046-p04-envelope-unit.sh (create)
- tools/verify/m046-p04-fail-closed.sh (create)
- tools/verify/m046-p04-attended-parity.sh (create)
- tools/verify/m046-p04-budget-kill.sh (create)
- tools/verify/m046-p04-reserve-spend.sh (create)
- tools/verify/m046-p04-stop-file-live.sh (create)
- tools/verify/m046-p04-thrash.sh (create)
- tools/verify/m046-p04-wall-clock.sh (create)
- tools/verify/m046-p04-docs-shape.sh (create)
- tools/verify/m046-p04-phase-suite.sh (create)
- .orchestrator/DECISIONS.md (modified at plan time — D016 #Q-7 resolution, already appended)
