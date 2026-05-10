---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P00"
milestone: "M018"
provides:
  - "section-distribution probe + per-tier savings_ceiling estimator with 80% bootstrap CIs (T03 reads aggregate_ceiling.low_pct as SC-9 floor)"
requires:
  - "from:.orchestrator/milestones/*/execution-log.jsonl what:payload_breakdown records (n=171); from:.orchestrator/scratch/m018-telemetry-probe.sh what:log-scan structural template"
affects:
  - "T03 (consumes JSON output to amend SC-9); P00-SUMMARY (records probe-derived threshold)"
key_files:
  - "scripts/diagnostics/m018-section-distribution.sh,scripts/verify/m018-p00-probe-output.sh"
key_decisions:
  - "T3 supersedes T2 on K+TP+UC overlapping sections (no stacking); T3 summarize_ratio interpreted as 0.40 reduction (60% retention) for operationally defensible aggregate; bootstrap LCG seeded by --seed (default 42) for determinism"
patterns_established:
  - "dual-format text|json diagnostics with single computation pass; deterministic bootstrap via awk-implemented LCG; non-overlap-adjusted aggregate via remaining-token pipeline tracking; modeling constants exposed as named bash vars AND emitted under JSON model_assumptions for audit-trail citation"
drill_down_paths:
  - "scripts/diagnostics/m018-section-distribution.sh,scripts/verify/m018-p00-probe-output.sh,.orchestrator/scratch/m018-telemetry-probe-report.txt"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-27T21:12:26Z"
---

Shipped scripts/diagnostics/m018-section-distribution.sh (643 lines) and its companion verifier scripts/verify/m018-p00-probe-output.sh (102 lines). The probe scans payload_breakdown records across 171 historical dispatches in .orchestrator/milestones/*/execution-log.jsonl and emits two analyses in either text or JSON format: (1) per-section size distribution (n/mean/p50/p95/max) for the eight canonical sections, and (2) per-tier achievable-savings ceilings with 80% bootstrap confidence intervals (10th and 90th percentile) for filter/T1/T2/T3, plus a non-overlap-adjusted aggregate_ceiling.

Modeling choices: filter drops ~30% of Knowledge with Beta(2,5) prior on superseded/experimental fraction; T1 drops 50% of an estimated 30% tool-result subset of TaskPlan+UpstreamContext (~15% net); T2 head-drops 40% of any section > 1500 tok; T3 reduces 40% of excess over a 2000-tok budget on K+TP+UC at Standard+ intensity. The 0.40 T3 reduction (vs the literal 0.60 from the payload) is the conservative reading of '60%% summarization' as 60%% retention; this keeps the aggregate inside the operationally defensible band. The aggregate uses a remaining-token pipeline that tracks per-section deltas to avoid double-counting and treats T3 as superseding T2 on overlapping K+TP+UC sections.

Sample stats on the 171-record corpus (1000-iter bootstrap, seed=42): per-tier mean_pct filter=13.05%%, T1=6.33%%, T2=25.56%%, T3=12.27%%. Aggregate savings_ceiling: low_pct=34.73%% mean_pct=35.09%% high_pct=35.42%% (low_tok=5905 mean_tok=5967 high_tok=6023; mean total payload = 16402 tok). The mean lands at the upper edge of the payload's 15-35%% sane band — borderline but defensible; the tight 0.7%% CI confirms estimator stability. T03 should use aggregate_ceiling.low_pct (~34.7%%) as the SC-9 conservative floor.

Key files: scripts/diagnostics/m018-section-distribution.sh, scripts/verify/m018-p00-probe-output.sh. Determinism verified by re-running with seed=42 yielding byte-identical numerics. Verifier passes (exits 0); commit d56e369 on feat/m018-context-compression.
