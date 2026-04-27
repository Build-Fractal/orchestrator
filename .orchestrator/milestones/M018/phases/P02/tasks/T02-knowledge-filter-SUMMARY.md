---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M018"
provides:
  - "scripts/lib/knowledge-filter.sh (sourceable filter lib); build-context.sh + section-handlers.sh integration applying FR-3 status filter to both planning + task-dispatch payloads; payload_filter JSONL record_type; additive filter_dropped_tokens field on payload_breakdown (CON-5); compression: config block (.orchestrator/config.yml + templates/orchestrator-config-default.yml); ORCH_OVERRIDE_COMPRESSION_ENABLED env override; tests/fixtures/m018-p02-knowledge-status/ fixture; tests/fixtures/m018-p02-baseline-payload.golden.txt golden baseline for SC-8/FR-15 disable-flag regression"
requires:
  - "T01 (preservation-check.sh sourced defensively); compression-grammar.md Tier filter section (failure semantics: missing status field -> RETAINED)"
affects:
  - "T03 (underperformance emitter — reuses kf_get_compression_enabled toggle pattern); T04 (verifiers — golden + fixture are the ground truth for m018-p02-disable-flag-honored.sh, m018-p02-filter-drops.sh, m018-p02-emitter-additivity.sh); P03 (T1 microcompact — inherits sourced preservation-check.sh path); P04 (T2 snip — same); P06 (T3 auto-compact — same); every M018 dispatch from P03 onward filters knowledge entries by status — pre-M020 entries with no status field default to RETAINED, so dogfooding stays safe"
key_files:
  - "scripts/lib/knowledge-filter.sh,scripts/dispatch/build-context.sh,scripts/dispatch/lib/section-handlers.sh,.orchestrator/config.yml,templates/orchestrator-config-default.yml,tests/fixtures/m018-p02-knowledge-status/knowledge-stream.md,tests/fixtures/m018-p02-baseline-payload.golden.txt"
key_decisions:
  - "Extracted filter into scripts/lib/knowledge-filter.sh (pure-lib pattern per MEM004) so both planning helpers in build-context.sh AND handle_knowledge in section-handlers.sh can apply the same filter — payload spec named only build-context.sh paths but task-dispatch knowledge gather has been refactored into section-handlers.sh; filtering only there would have missed every real T-task payload. Bypassed read-config.sh for the dotted compression.* keys since read-config.sh validates against a fixed VALID_KEYS list and rejects unknowns; awk-walks the YAML block directly — supports both inline list and block-list shapes. ORCH_OVERRIDE_COMPRESSION_ENABLED env beats config so the SC-8 regression verifier can flip the master toggle without mutating .orchestrator/config.yml."
patterns_established:
  - "kf_filter_stream consumes a multi-entry markdown stream on stdin, writes filtered stream to stdout, and writes a single dropped_count=N dropped_tokens=N dropped_ids=csv stats line to a caller-named file — the build-context emitter reads the stats file post-assembly to produce the payload_filter JSONL record. This stats-file handoff means filtering and emission can stay decoupled (filter knows nothing about JSONL; emitter knows nothing about awk)."
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P02/tasks/T02-knowledge-filter-PAYLOAD.md;scripts/lib/knowledge-filter.sh;tests/fixtures/m018-p02-knowledge-status/README.md"
duration: "70"
verification_result: "pass"
completed_at: "2026-04-27T23:54:35Z"
---

T02 wires the FR-3 knowledge-aware status filter into the dispatch payload pipeline. The implementation centerpiece is scripts/lib/knowledge-filter.sh — a pure, sourceable library exposing kf_get_compression_enabled (honors ORCH_OVERRIDE_COMPRESSION_ENABLED env beat for the SC-8 test seam), kf_get_knowledge_filter_enabled, kf_read_drop_list (parses both inline and block YAML list shapes; defaults to [superseded, experimental] when config or block missing), and kf_filter_stream (awk-driven entry-boundary detection on the resolve-entries.sh output stream; writes a stats sidecar file the emitters consume).

Two integration sites consume the library: scripts/dispatch/build-context.sh _bc_apply_knowledge_filter wraps both planning knowledge-gather paths, and scripts/dispatch/lib/section-handlers.sh _sh_apply_knowledge_filter wraps the task-dispatch handle_knowledge plus _sh_emit_flat_knowledge paths. The wider-than-payload-spec scope was necessary because section-handlers.sh contains the actual T-task knowledge gather (the payload reference to two paths in build-context.sh predates the recipe-driven refactor). Filtering only the build-context paths would have missed every real dispatched task. Both wrappers honor compression.enabled and compression.knowledge_filter.enabled and emit the literal '(no qualifying knowledge entries)' sentinel when every entry drops (spec acceptance scenario 5).

Telemetry is additive (CON-5): _bc_emit_payload_breakdown carries a new top-level filter_dropped_tokens field (defaults to 0 when no filter ran), and a new _bc_emit_payload_filter emits a brand-new payload_filter JSONL record_type when at least one entry was dropped. Pre-M018 rollups ignore the new record_type cleanly; pre-M018 jq filters reading payload_breakdown remain valid (filter_dropped_tokens is missing on old records, which jq treats as null).

Verification: the s04 (74/74), s06 (64/64), and s07 (17/17) regression suites all pass post-change. Direct end-to-end smoke against the new fixture (tests/fixtures/m018-p02-knowledge-status/knowledge-stream.md) confirms MEM901+MEM903 drop, MEM900+MEM902+MEM904 retain, MEM902 (no status field) is RETAINED per fail-open, and ORCH_OVERRIDE_COMPRESSION_ENABLED=false produces byte-identical pass-through against tests/fixtures/m018-p02-baseline-payload.golden.txt — the mechanical fixture-and-golden combo that T04 m018-p02-disable-flag-honored.sh verifier will diff against. preservation-check.sh is sourced defensively in build-context.sh so P03/P04/P06 inherit a working source path with no further wiring.
