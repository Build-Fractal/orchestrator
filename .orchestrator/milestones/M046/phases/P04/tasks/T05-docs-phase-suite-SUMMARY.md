---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P04"
milestone: "M046"
provides:
  - "commands/auto.md '### Unattended envelope (--unattended, M046 P04)' contract subsection (additive, inserted after the P02 FR-14 self-continue-status.sh paragraph): opt-in+fail-closed caps (--max-budget-usd/--max-continuations/--max-wall-clock-s all mandatory, SELF_CONTINUE:REFUSE reason=caps-unset|caps-invalid, no silent MAX_CONT=20, D016 wall-clock resolution), optional tuning flags (--segment-reserve-usd def 1.00/--thrash-threshold def 2/--watchdog-poll-s def 1/--cost-log), four new terminals (BUDGET_EXCEEDED/WALL_CLOCK_EXCEEDED stage=pre-spawn|mid-segment, STOPPED reason=stop-file stage=mid-segment, THRASH), three accounting dotfiles (.self-continue-budget-ledger reserve-then-spend+true-up-from-total_cost_usd+persist+reset-by-deletion, .self-continue-kill-reason atomic, .self-continue-segment-result.json), watchdog trigger order stop-file->wall-clock->budget cost-derived from non-null unit_close estimated_cost_usd, child env-export contract, unattended-envelope.sh seam+FR-17 byte-parity; tools/verify/m046-p04-docs-shape.sh (12 presence checks + 8 bidirectional docs-vs-code drift-guard checks, 20/20); tools/verify/m046-p04-phase-suite.sh 9-member aggregator 9/9"
requires:
  - "scripts/lifecycle/self-continue-drive.sh (T02, authoritative flag/terminal surface), scripts/lifecycle/unattended-envelope.sh (T01, doc seam), all 8 T01-T04 P04 verifiers (suite members), commands/auto.md P02 self-continue section, .orchestrator/DECISIONS.md D016"
affects:
  - "P04 close, P07 (documented envelope surface + child-visible env-var contract)"
key_files:
  - "commands/auto.md,tools/verify/m046-p04-docs-shape.sh,tools/verify/m046-p04-phase-suite.sh"
key_decisions:
  - "DRIVER is authoritative over the dispatch-briefing flag names: documented the actual driver flags --segment-reserve-usd/--thrash-threshold/--watchdog-poll-s (matching driver header + plan step-1) NOT the briefing's --reserve-usd/--thrash-n/--poll-s aliases which the driver does not parse; drift-guard is bidirectional (each unattended terminal token + each cap flag must appear in BOTH auto.md and self-continue-drive.sh) so aspirational docs OR undocumented terminals both fail; grep -qF -e for dash-leading flag tokens; suite member order per plan with attended-parity last as the FR-17 gate carrying the 4 P02 regressions; additive-only, zero driver/library/auto-loop.sh changes"
patterns_established:
  - "docs-vs-code bidirectional drift guard: for each load-bearing terminal/flag token assert presence in BOTH the operator-facing doc and the authoritative script, failing on either-direction drift; docs-shape verifier = per-token presence checks + drift guard, PASS/FAIL + SUMMARY: pass=N fail=N"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P04/"
duration: "780s"
verification_result: "pass"
completed_at: "2026-07-13T18:21:58Z"
---

T05 closed P04 by documenting the unattended-envelope contract on the driver's operator-facing surface and shipping the phase-close gate. Read the T02 driver + T01 library headers first and documented ONLY what the driver actually emits: the additive '### Unattended envelope (--unattended, M046 P04)' subsection in commands/auto.md (inserted after the P02 FR-14 material, leaving that verified text untouched) covers the three mandatory fail-closed caps and the SELF_CONTINUE:REFUSE caps-unset/caps-invalid refusal (D016 wall-clock cited), the four new terminals (BUDGET_EXCEEDED/WALL_CLOCK_EXCEEDED with stage=pre-spawn|mid-segment, STOPPED reason=stop-file stage=mid-segment, THRASH), the three accounting dotfiles with the reserve-then-spend/true-up-from-total_cost_usd/persist-and-reset-by-deletion semantics, the stop-file->wall-clock->budget watchdog order with cost-derived non-null unit_close estimated_cost_usd, and the child env-export + unattended-envelope.sh seam with FR-17 byte-parity. tools/verify/m046-p04-docs-shape.sh runs 12 per-token presence checks plus an 8-check bidirectional docs-vs-code drift guard (each unattended terminal + cap flag must live in BOTH auto.md and self-continue-drive.sh) at 20/20. tools/verify/m046-p04-phase-suite.sh aggregates all 9 P04 verifiers (envelope-unit, fail-closed, budget-kill, reserve-spend, stop-file-live, thrash, wall-clock, docs-shape, attended-parity-last-as-FR-17-gate) at SUMMARY: pass=9 fail=0. Deviation noted: the driver flags are --segment-reserve-usd/--thrash-threshold/--watchdog-poll-s, not the dispatch-briefing aliases; the driver is authoritative and the docs follow it. check-must-haves: 9 truths + all artifacts + all key links PASS. No driver/library/auto-loop.sh changes.
