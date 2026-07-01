---
schema_version: "1.0"
type: viability-evidence
milestone: "M045"
phase: "P01"
question: "#Q-1 / SC-6 — does in-session ScheduleWakeup re-entry give bounded context relief across rotation boundaries?"
---

# M045 P01 — Viability Evidence (SC-6 / #Q-1 decision gate)

## Question under test

Spec `#Q-1` (the milestone's load-bearing risk, enforced by `SC-6`): when the
Tier C auto loop hits context rotation and, instead of exiting for a human,
schedules its own in-session re-entry via `ScheduleWakeup`, **does the
orchestrating session's context actually get relieved across rotation
boundaries — or does it compound?** `CON-1` bets it is "bounded, in-session
(via harness compaction)"; `CON-5` routes a negative answer to `M-auto-v2b`'s
process-fresh substrate.

## Measurements

Source: `spike/segments.jsonl` (3 rotation boundaries via the throwaway harness
driving the REAL `scripts/lifecycle/context-monitor.sh` with `--limit 3`).

| Segment | Phase | status | weight (on-disk proxy) | Δ vs prior |
|---|---|---|---|---|
| 1 | P01 | rotate | 4 | — |
| 2 | P02 | rotate | 11 | +7 |
| 3 | P03 | rotate | 18 | +7 |
| 4 | — | complete | — | — |

Live harness token/context readout: **unavailable** from a synchronous shell
run (see Correctness/Constraint below).

## Correctness (CON-2 dimension) — PASS

Every segment re-derived its position purely from on-disk state (`plan.txt` +
the accumulating `execution-log.jsonl`); the loop resumed the next phase across
each boundary with no reliance on in-memory carryover. Disk-authoritative resume
holds. This is the solid, unambiguous positive result: the *correctness* half of
the mechanism works exactly as `CON-2` requires.

## Boundedness analysis — NOT SUPPORTED (in-session)

Two independent lines of evidence converge:

1. **Structural (decisive).** `ScheduleWakeup` re-fires within the *same*
   session — it does **not** start a new process or reset context. The harness
   relieves context only via its own automatic summarization, which triggers
   "when the conversation grows long" (a large, non-rotation-aware threshold),
   **not** at rotation boundaries. So in-session re-entry defers relief to a
   schedule that is blind to rotation — it does not provide *per-rotation*
   context relief.

2. **Empirical analog.** The only capturable proxy (on-disk session `weight`)
   compounds monotonically (4 → 11 → 18, +7 per boundary) because nothing resets
   between re-entries. This mirrors what an in-session context does when
   re-entry does not reset it.

**Critical comparison.** Context rotation exists precisely to let the deep
orchestrating context be *replaced by a fresh one*. Today's behavior achieves
that by exiting and having the operator re-invoke in a fresh session. An
in-session `ScheduleWakeup` re-entry does **not** replace the context — so on
the exact axis rotation targets, the in-session approach as scoped is *weaker
than today's behavior*, not stronger. The thing that restores a genuine
per-rotation reset is a **process-fresh** re-entry — which is `M-auto-v2b`'s
headless-driver substrate (Posture 2, proposal D2).

## Verdict

VERDICT: PARTIAL

- **Mechanism + correctness: PASS.** Rotation detection → self-continue
  directive → disk-authoritative resume works end-to-end (real
  `context-monitor.sh`, real exit-14 branch shape).
- **In-session context relief (the CON-1 premise): NOT SUPPORTED.** In-session
  `ScheduleWakeup` re-entry does not reset context and is not rotation-aware; the
  weight analog compounds. A definitive "bounded via harness compaction over a
  long run" claim cannot be made from a synchronous spike, and is not something
  the in-session design controls (compaction is the harness's call, not
  rotation's). The honest reading tilts negative for CON-1 as written.

PARTIAL rather than clean NEGATIVE because one path could still rescue an
attended in-session variant: an operator-launched `/loop` soak long enough to
trigger harness compaction, confirming compaction bounds a real multi-hour run.
That soak is operator-gated (see #Q-2) and does not change the structural fact
that relief would be compaction-timed, not rotation-timed.

## #Q-1 resolution

In-session `ScheduleWakeup` re-entry preserves **correctness** (disk-authoritative)
but does **not** deliver per-rotation **context relief** — it defers relief to
non-rotation-aware harness compaction, making it weaker than today's
fresh-session re-invoke on the very axis rotation targets. Genuine per-rotation
relief requires **process-fresh** re-entry (`M-auto-v2b` headless driver).

## #Q-2 recommendation

`ScheduleWakeup` exists **only inside `/loop` dynamic mode**, never a plain
turn. So *if* an in-session attended variant is pursued, its arming surface must
be the **`/loop` recipe**, not a bare `--self-continue` flag. But given the
boundedness finding, the stronger answer is that v2a's primary substrate should
be the process-fresh driver, whose arming is a launch flag/driver — moving #Q-2
into v2b's domain.

## Downstream routing (CON-5)

Recommend **routing the per-rotation-relief goal to `M-auto-v2b`'s process-fresh
substrate** rather than building P02–P04 on the in-session premise as scoped.
Two viable operator decisions:

- **(A) Re-scope M045** to "automate the re-invoke keystroke" honestly — value is
  removing babysitting, explicitly accepting harness-compaction-bounded (not
  fresh) context. Keep P02–P04 but reframe FR/SC-6 around compaction-bounded, and
  run the operator `/loop` soak to set expectations.
- **(B) Fold M045 into M-auto-v2b** — make the first self-continue substrate the
  process-fresh headless driver (skip the in-session approach), per CON-5. The
  P02–P04 mechanism work (deterministic branch, capability detection, safety
  envelope, observability) is ~unchanged and carries over; only the re-entry
  substrate swaps from ScheduleWakeup to `claude -p`.

Either way, P01 did its job: it caught, before P02–P04 were built, that the
in-session premise does not hold on the axis that matters. This is exactly the
RISK-1/MIT-1 failure mode the conversus deliberation demanded SC-6 guard against.

Measurement source: `spike/segments.jsonl`.
