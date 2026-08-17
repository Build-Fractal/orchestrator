---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P04"
milestone: "M046"
provides:
  - "Non-stubbed cost-discriminating SC-3 budget-kill harness tools/verify/m046-p04-budget-kill.sh (4 cases: A runaway 3x$2.00>$5 SIGKILLed mid-flight with distinct SELF_CONTINUE:BUDGET_EXCEEDED stage=mid-segment terminal + natural-end-absent + forfeit=6.00; B byte-identical-timing $0.06 control runs UNKILLED to natural completion + reconcile from total_cost_usd=0.05 -- proves the trigger is cost not a duration proxy since durations are held constant by construction; C shape-pin greps record_type:unit_close + estimated_cost_usd literals in production emitter, watchdog probe, and generated fixture stub; D 3x null-cost records contribute 0 and never false-trigger, P01 #Q-4 honesty) and SC-4 reserve-spend harness tools/verify/m046-p04-reserve-spend.sh (3 cases: 1 killed-before-flush forfeits $1.00 reserve as unreconciled spend with CHILD_ABORT terminal + no reconcile; 2 cross-run cap binding refuses next run at pre-spawn since persisted 1.00+reserve 1.00>cap 1.50, child never spawns, no reserve seg2; 3 true-up reconcile from total_cost_usd=0.30 with envelope_spent_total returning 0.30 not the 1.00 reserve). Live-shell child stand-ins emit production-shaped unit_close JSONL to the live default cost-log path mid-flight; real driver + real envelope watchdog end-to-end; no pre-seeded logs, no seeded markers, no fabricated terminals"
requires:
  - "scripts/lifecycle/self-continue-drive.sh (T02 --unattended envelope surface), scripts/lifecycle/unattended-envelope.sh (T01 watchdog + ledger lib), scripts/knowledge/write-summary.sh (production unit_close emit template, shape-pin target)"
affects:
  - "T05 (phase suite aggregates), P04 close (SC-3/SC-4 milestone-blocking gates)"
key_files:
  - "tools/verify/m046-p04-budget-kill.sh, tools/verify/m046-p04-reserve-spend.sh"
key_decisions:
  - "Cost-discrimination realized by holding segment DURATION constant (identical 0.3s+3-record emit schedule + sleep 8 completion) while varying only estimated_cost_usd (2.00 vs 0.02) between Case A and Case B, so any duration-proxy trigger kills both or neither and the paired assertion fails; child stub built via printf header (paths/cost/sleep injected) + QUOTED heredoc body ($LOG/$COST/$i stay literal until stub runs), mirroring _ws_emit_unit_close verbatim; latency bound 6s with margin (observed 2s kill) and control elapsed>=8 with margin (observed 9s) per plan flake guidance; forfeit-amount grep uses amount_usd=6 / amount_usd=1.00 prefix to match the %.6f-formatted ledger values; headless-independent by construction (budget kill + reconcile happen before the branch/marker read, so detect-capabilities result never affects assertions)"
patterns_established:
  - "Cost-vs-duration discrimination via byte-identical timing structure with only the dollar field varied -- the anti-proxy paired-assertion pattern for honest budget-kill verification; live-shell LLM stand-in that appends production-shaped unit_close records to the real cost-log mid-flight so the real watchdog reads them through the production envelope_observed_cost probe (extends the P02 child-abort stand-in precedent from crash-signals to cost-emission); three-surface shape-pin (production emitter + watchdog probe + fixture stub grep the same key literals)"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P04/"
duration: "1500s"
verification_result: "pass"
completed_at: "2026-07-13T17:59:17Z"
---

T03 authored the two milestone-blocking accounting harnesses against the T01/T02 envelope surface with zero driver/lib modification. m046-p04-budget-kill.sh (SC-3, non-stubbed) drives the real driver + real watchdog end-to-end; the only substitution is a live-shell child that emits production-shaped unit_close JSONL mid-flight to the live execution-log.jsonl the watchdog polls. Honest cost-discrimination is achieved by holding segment duration byte-identical between Case A (3x$2.00, cap $5) and Case B (3x$0.02, same timing) so the ONLY explanation for A being SIGKILLed mid-flight while B survives to natural completion is the dollar cost -- a duration proxy would kill both or neither. Case A asserts the distinct SELF_CONTINUE:BUDGET_EXCEEDED stage=mid-segment terminal, natural-end sentinel absent, <=6s latency, and forfeit=6.00 (unreconciled=observed); Case B asserts no kill, natural-end present, elapsed>=8, TERMINAL outcome=complete, and reconcile from total_cost_usd. Case C shape-pins the record_type/estimated_cost_usd literals across emitter/probe/stub; Case D proves null-cost records contribute 0 (P01 #Q-4). m046-p04-reserve-spend.sh (SC-4) proves killed-before-flush forfeits the reserve as spend, cross-run persisted spend binds the next run's pre-spawn cap refusal, and normal exit trues-up from total_cost_usd (envelope_spent_total=0.30 not the 1.00 lease). All 7 cases green across repeat runs; attended-parity wrapper stays green (no driver changes). No defects found in T02's surface.
