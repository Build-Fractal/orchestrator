---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P03"
milestone: "M011"
provides:
  - "ingest-spec.sh re-ingest decision layer: classify_chunk_decision helper, _do_create_chunk extraction, per-PID observed-ID log with EXIT trap, dump_observed_log helper, DECIDE-NEW/UNCHANGED/CHANGED intermediate output prefixes"
requires:
  - "P02: ingest-spec.sh with full classifiers and content_hash population; detail-utils.sh find_detail_file + fm_field + sed_i; hash.sh compute_content_hash"
affects:
  - "P03/T02 supersession wiring, P03/T02 REMOVED detection via dump_observed_log, P03/T03 final CREATED/SKIPPED/SUPERSEDED/REMOVED prefix rewrite"
key_files:
  - "scripts/knowledge/ingest-spec.sh, scripts/knowledge/lib/detail-utils.sh, scripts/verify/m011-p03-bash32-compat.sh, scripts/verify/m011-p03-skip-unchanged.sh, scripts/verify/m011-p03-supersede-on-change.sh"
key_decisions:
  - "Intermediate DECIDE-* prefixes leave T01 verifiable in isolation; per-PID observed-ID log ($$ suffix) instead of associative arrays for Bash 3.2 compat; extended find_detail_file to scan two-level category trees so spec/* entries resolve"
patterns_established:
  - "Decision-layer wrapper around creation primitive (classify + dispatch); append-only text file as cross-subshell state sink under Bash 3.2; comment-aware forbidden-construct scan in verify scripts; permissive grep patterns to allow downstream tightening without rewriting verify scripts"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P03/tasks/T01-PAYLOAD.md"
duration: "30m"
verification_result: "pass"
completed_at: "2026-04-16T20:38:34Z"
---

Added a re-ingest change-detection layer to scripts/knowledge/ingest-spec.sh. classify_chunk_decision looks up the existing detail file via find_detail_file, reads its content_hash frontmatter, and echoes NEW / UNCHANGED / CHANGED based on hash comparison. _do_create_chunk extracts the existing create-entry.sh invocation plus post-creation sed_i hash patch into a pure creation helper with no stdout side effects. create_chunk was rewritten as a thin decision wrapper that (1) computes the normalized content hash, (2) appends id|category to a per-PID observed-ID log at $INGEST_PROJECT_ROOT/.orchestrator/tmp/ingest-spec-observed.$$ (cleaned up on EXIT via trap), (3) calls classify_chunk_decision, and (4) routes to either _do_create_chunk + DECIDE-NEW echo, or DECIDE-UNCHANGED, or DECIDE-CHANGED. dump_observed_log exposes the log for T02's REMOVED-detection pass.

find_detail_file in detail-utils.sh was extended to also scan the two-level knowledge/*/*/ID.md tree so spec/requirement/SPEC-FR-NNN.md resolves. Without this the decision layer classified every re-ingested spec chunk as NEW.

Three verify scripts were created. m011-p03-bash32-compat.sh runs bash -n and does a comment-aware scan for declare -A, mapfile, readarray. m011-p03-skip-unchanged.sh scaffolds a sandbox PROJECT_ROOT, ingests a minimal 6-chunk spec, re-ingests it, and asserts every line is DECIDE-UNCHANGED (or SKIPPED) with zero DECIDE-NEW/DECIDE-CHANGED. m011-p03-supersede-on-change.sh ingests a spec, modifies FR-001's text, re-ingests, and asserts exactly one DECIDE-CHANGED (or SUPERSEDED) line for SPEC-FR-001 with the other chunks unchanged. Verify-script grep patterns are permissive so T02 can tighten to final prefixes without rewriting the checks.

All three verify scripts print PASS and exit 0. bash -n on ingest-spec.sh succeeds. The P02 idempotency script intentionally fails at this checkpoint because it still greps for CREATED:/SKIPPED: literals -- that prefix rewrite lands in T02 per the task plan.
