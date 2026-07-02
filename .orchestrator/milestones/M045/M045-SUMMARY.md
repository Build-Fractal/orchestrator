---
schema_version: "1.0"
type: milestone-summary
milestone: "M045"
feature_ref: "046-self-continuing-auto"
outcome: complete
validated: "2026-07-01"
---

# M045 — Self-Continuing Auto (Auto v2, Posture 1)

## What shipped

`orchestrator:auto --self-continue`: a Tier C autonomous run that continues
itself across context-rotation boundaries via **process-fresh `claude -p`
re-entry** — kick it once and it advances to a terminal state without a human
re-invoking at each rotation.

- **Decision core** (`scripts/lifecycle/self-continue-branch.sh`) — deterministic
  `AUTO:SELF_CONTINUE` / `AUTO:ROTATE_EXIT reason=...` / `AUTO:NO_ROTATION` per the
  armed × capable × rotation truth table (Principle X: policy in shell).
- **Capability** (`detect-capabilities.sh` `headless_reentry`) — can we spawn a
  fresh `claude -p`? Gates the feature; graceful degradation to legacy exit where
  absent (FR-7/FR-8).
- **Driver** (`scripts/lifecycle/self-continue-drive.sh`) — the outer loop that
  re-spawns a fresh `claude -p` per rotation-exit until a terminal outcome, the
  `--max-continuations` cap, or a `--stop-file`. Forward-progress field increments
  only on phase change → thrash detection.
- **Observability** — FR-9 continuity JSONL (`--log`) + FR-10 structural stall
  (`SELF_CONTINUE:STALLED`, a dangling `self_continue_unconfirmed` record) surfaced
  by `scripts/diagnostics/self-continue-status.sh`.
- **Arming** — explicit per-run `--self-continue` (default OFF, CON-4); documented
  in `commands/auto.md`. The live rotation-exit decision is UNCHANGED (legacy
  parity, FR-8) — the driver wraps it.

## The defining moment: P01

The P01 viability spike returned **VERDICT: PARTIAL** and reshaped the milestone.
The originally-specced in-session `ScheduleWakeup` substrate does not relieve
context per-rotation (it re-fires in the same session; relief depends on
non-rotation-aware harness compaction; the weight analog compounded 4→11→18) —
making it *weaker* than today's fresh-session re-invoke on the exact axis rotation
targets. Per CON-5 and operator decision **D015**, the substrate pivoted to
process-fresh. P01 caught the flawed premise **before** P02–P04 were built on it —
exactly the RISK-1/MIT-1 failure mode the conversus spec-gate demanded SC-6 guard
against. A cheap, correct "no" that redirected the milestone.

## Success criteria

| SC | Where | Result |
|----|-------|--------|
| SC-1 continuity | P04 `m045-p04-continuity.sh` | PASS |
| SC-2 terminal-never-respawn | P03 `m045-p03-driver-terminal.sh` | PASS |
| SC-3 cap + progress/thrash | P03 `m045-p03-driver-cap.sh` | PASS |
| SC-4 legacy golden | P03 `m045-p03-legacy-golden.sh` | PASS |
| SC-5 branch truth table | P02 `m045-p02-branch-truth-table.sh` | PASS |
| SC-6 viability spike | P01 `P01-VIABILITY-EVIDENCE.md` | PARTIAL → pivot (its purpose) |
| SC-7 stall | P04 `m045-p04-stall.sh` | PASS |

`validate-milestone.sh` → PASS 8/8.

## Provenance

specify (conversus PASS-with-conditions, 7 mitigations applied) → evaluate (Tier
C) → discuss gate → roadmap → P01 (spike → D015 pivot) → P02 → P03 → P04
(fresh-context dispatch). Branch `046-self-continuing-auto`. Spec
`specs/046-self-continuing-auto/spec.md`. Decision D015. Proposal
`.orchestrator/proposals/Mxx-auto-v2-claude-code-loop-integration.md`.

## Forward pointers

- **M-auto-v2b** builds on this: Posture 2 unattended (the driver already IS a
  headless driver — v2b adds `--unattended` per-run opt-in + safety red-team),
  Posture 3 Stop-hook until-verified, unified A/B/C entry, `orchestrator:do` merge.
- **Pre-existing cleanup**: `test-s08-auto-safety.sh` carries 2 pre-existing
  `auto.md` pipe-chain audit fails (present before M045; stash-confirmed) — worth a
  separate paper-cut.
- **`/goal` + Monitor** primitives were NOT relied on (sourced from third-party
  blogs during research; verify against official docs before any v2b use).
