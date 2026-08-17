---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P04"
milestone: "M046"
provides:
  - "Three durable behavioral harnesses driving the REAL T02 driver plus REAL envelope watchdog end-to-end with a live-shell child stand-in and no seeded markers or terminals: tools/verify/m046-p04-stop-file-live.sh proves SC-6 mid-segment stop-file live-kill with wall-clock-asserted bounded latency plus a pre-loop-stop M045-parity case; tools/verify/m046-p04-thrash.sh proves SC-7 THRASH-before-caps plus an attended no-THRASH control and a progress-reset case; tools/verify/m046-p04-wall-clock.sh proves the D016 dual wall-clock legs mid-segment kill and pre-spawn refusal with distinctness from budget/thrash/child_abort and the elapsed_s and cap_s reason fields"
requires:
  - "T02 self-continue-drive.sh unattended envelope surface plus unattended-envelope.sh; T01 m046-p02-child-abort.sh harness-shape precedent; headless_reentry capability true so continue-class re-spawn fires"
affects:
  - "T05 phase suite aggregates, P04 close SC-6 and SC-7 gates"
key_files:
  - "tools/verify/m046-p04-stop-file-live.sh, tools/verify/m046-p04-thrash.sh, tools/verify/m046-p04-wall-clock.sh"
key_decisions:
  - "Bounded latency asserted against measured wall-clock elapsed not next-spawn latency, with the gap to the child natural duration preserved for CI safety; distinct-terminal precedence checked by asserting the absence of budget/thrash/child_abort lines when the envelope terminal fires; wall-clock mid-segment leg is the inverse of the SC-3 anti-proxy leg using a generous 50 dollar budget and zero cost records so duration is provably the trigger; pre-spawn refusal made deterministic by holding the fast child duration under the watchdog poll interval so a post-deadline watchdog tick always finds the child dead; progress-reset and attended-control legs added to the thrash harness per the plan"
patterns_established:
  - "Background-driver invocation inside a verifier with wall-clock-elapsed bounded-latency measurement; distinct-terminal precedence asserted via negative greps on competing terminal lines; child-duration-under-poll invariant to force pre-spawn rather than mid-segment wall-clock; persisted-counter stub for incrementing phase words to exercise progress-reset"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P04/"
duration: "1500s"
verification_result: "pass"
completed_at: "2026-07-13T18:13:11Z"
---

Authored three behavioral harnesses against the T02 driver plus envelope surface following the P02 m046-p02-child-abort.sh conventions: stop-file-live proves SC-6 mid-segment live-kill within one-second measured latency plus a pre-loop-stop parity case, thrash proves SC-7 halt on THRASH threshold 2 after two SCHEDULED segments before the generous caps plus an attended no-THRASH control and a progress-reset case, and wall-clock proves the D016 mid-segment kill and pre-spawn refusal legs with terminal distinctness and the elapsed_s and cap_s reason fields; all four Verification commands pass and the three timing-sensitive harnesses were confirmed stable across three repeat iterations with no driver or envelope defect surfaced.
