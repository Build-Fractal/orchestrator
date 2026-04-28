---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M018"
provides:
  - "compression_underperformance JSONL emitter; kf_get_underperformance_* config accessors; underperformance block in compression config schema"
requires:
  - "T01,T02"
affects:
  - "P03 tier1 reuses underperformance signal; P04 tier2 reuses; P05 eval harness consumes compression_underperformance JSONL; P06 tier3 reuses"
key_files:
  - "scripts/dispatch/build-context.sh;scripts/lib/knowledge-filter.sh;.orchestrator/config.yml;templates/orchestrator-config-default.yml"
key_decisions:
  - "Extended kf_read_compression_scalar to walk underperformance child block (parity with knowledge_filter pattern) rather than going through dotted-key config_read which does not support compression keys; awk single-process float math (AP-009 safe); call site placed AFTER payload_breakdown so the running mean includes the just-emitted record"
patterns_established:
  - "kf_get accessor convention for nested compression sub-blocks (extends T02 kf_get_knowledge_filter_enabled pattern); awk substring offset equals byte length of full key prefix including quotes and colon (off-by-one risk; verified via key-length probe)"
drill_down_paths:
  - ".orchestrator/scratch/m018-p02-t03-smoke.sh;.orchestrator/scratch/m018-p02-t03-e2e.sh;.orchestrator/scratch/m018-p02-t03-disabled.sh"
duration: "45"
verification_result: "pass"
completed_at: "2026-04-28T00:03:30Z"
---

T03 ships the MIT-09 aggregate-savings self-check that gates against SC-9 calibrated 34.7 percent floor as an operational signal. After every payload_breakdown emission, build-context.sh now invokes _bc_emit_compression_underperformance, which scans the milestone execution-log.jsonl with a single awk pass to compute the running mean payload-token reduction over the last window_size records (default 30). When the mean is below floor_pct (default 34.7) AND sample_size meets min_sample_size (default 10), a compression_underperformance JSONL record is appended naming running_mean_pct, floor_pct, window_size, sample_size, shortfall_pct, and timestamp. The check never blocks dispatch — failure modes (missing log, awk error, mkdir failure) all return 0 silently per Constitution XI. Config plumbing extends scripts/lib/knowledge-filter.sh: kf_read_compression_scalar now walks the underperformance child block in addition to knowledge_filter, and four kf_get_underperformance_enabled / window_size / floor_pct / min_sample_size accessors return the configured value or its documented default. Both .orchestrator/config.yml and templates/orchestrator-config-default.yml carry the new block. The emitter uses these accessors directly because config_read does not support dotted compression keys (build-context.sh line 175 comment). Substring math note: the awk offsets in the original task plan (RSTART+25 for payload_tokens_estimate, RSTART+34 for tier3_compression_savings_tokens) were off-by-one; the correct values are +26 and +35 (matching the byte length of the full quote-key-quote-colon prefix). A small key-length probe confirmed each value before the fix landed in build-context.sh. Smoke / e2e / disabled probes verify all four contract paths: 30-record underperforming log emits exactly one compression_underperformance record with running_mean_pct around 4.60 percent and shortfall_pct around 30.10; 5-record log triggers the INSUFFICIENT branch (min_sample_size guard); 12-record above-floor log (37.5 percent) does not emit; and enabled=false short-circuits emission. The end-to-end probe runs build-context.sh against a synthetic ORCH_ROOT and confirms the additive emitter sequence (payload_breakdown to dispatch_usage to compression_underperformance) lands correctly. All scripts are bash 3.2 / AP-009 / AD-19 clean. Commit 9afb942 on feat/m018-context-compression.
