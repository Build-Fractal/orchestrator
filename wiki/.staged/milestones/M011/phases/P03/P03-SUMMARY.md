---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M011"
milestone: "M011"
provides:
  - "ingest-spec.sh re-ingest decision layer: classify_chunk_decision helper, _do_create_chunk extraction, per-PID observed-ID log with EXIT trap, dump_observed_log helper, DECIDE-NEW/UNCHANGED/CHANGED intermediate output prefixes, ingest-spec.sh supersession wiring, REMOVED detection pass, phase-impact REVIEW emission, versioned-ID chain helper, Phase demo-scenario verify script, provenance traversal verify script, re-ingest idempotency verify script (chain-tip hash comparison check)"
requires:
  - "P02: ingest-spec.sh with full classifiers and content_hash population; detail-utils.sh find_detail_file + fm_field + sed_i; hash.sh compute_content_hash, T01: classify_chunk_decision helper, _do_create_chunk helper, INGEST_OBSERVED_LOG, dump_observed_log helper; supersede-entry.sh; lib/detail-utils.sh, T01: classify_chunk_decision; T02: supersession wiring and REMOVED pass; traverse-graph.sh; rebuild-index.sh"
affects:
  - "P03/T02 supersession wiring, P03/T02 REMOVED detection via dump_observed_log, P03/T03 final CREATED/SKIPPED/SUPERSEDED/REMOVED prefix rewrite, T03 verification, P04 dispatch integration, spec re-ingest change/remove workflows, P03 phase verification completeness, P04 dispatch integration"
key_files:
  - "scripts/knowledge/ingest-spec.sh, scripts/knowledge/lib/detail-utils.sh, scripts/verify/m011-p03-bash32-compat.sh, scripts/verify/m011-p03-skip-unchanged.sh, scripts/verify/m011-p03-supersede-on-change.sh, scripts/knowledge/ingest-spec.sh, scripts/verify/m011-p03-removed-on-deletion.sh, scripts/verify/m011-p03-supersede-frontmatter.sh, scripts/verify/m011-p03-removed-frontmatter.sh, scripts/verify/m011-p03-phase-impact-review.sh, scripts/verify/m011-p03-supersede-on-change.sh, scripts/verify/m011-p03-skip-unchanged.sh, scripts/verify/m011-p03-demo-scenario.sh, scripts/verify/m011-p03-provenance-traversable.sh, scripts/verify/m011-p03-reingest-idempotent.sh"
key_decisions:
  - "Intermediate DECIDE-* prefixes leave T01 verifiable in isolation; per-PID observed-ID log ($$ suffix) instead of associative arrays for Bash 3.2 compat; extended find_detail_file to scan two-level category trees so spec/* entries resolve, Versioned-ID convention base-vN walking chain tip; REMOVED pass skips *-v[0-9]* successors; CREATED: passthrough from _do_create_chunk; emit_phase_impact extracts both [phase:P##] and [milestone:M###/P##], Sandbox PROJECT_ROOT=mktemp -d with EXIT trap; verify scripts internally allowed any bash (AD-19 applies only to plan Check: lines); no ingest-spec.sh modification needed — T02 already walks superseded_by chain to tip"
patterns_established:
  - "Decision-layer wrapper around creation primitive (classify + dispatch); append-only text file as cross-subshell state sink under Bash 3.2; comment-aware forbidden-construct scan in verify scripts; permissive grep patterns to allow downstream tightening without rewriting verify scripts, Decision-layer -> action-layer separation (T01 emits DECIDE; T02 wires real actions); chain-walking next-version helper; base-ID observed-log diff for removal detection, Demo-scenario verify reproduces roadmap sentence literally; triple-ingest idempotency check surfaces chain-tip hash comparison edge case; provenance chain-length-2 assertion"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P03/tasks/T01-SUMMARY.md, .orchestrator/milestones/M011/phases/P03/tasks/T02-SUMMARY.md, .orchestrator/milestones/M011/phases/P03/tasks/T03-SUMMARY.md"
duration: "75m"
verification_result: "pass"
completed_at: "2026-04-17T00:54:41Z"
observability_surfaces:
  - "none"
---

P03 delivered idempotent re-ingest and versioning for the spec ingest pipeline. scripts/knowledge/ingest-spec.sh grew a decision layer (classify_chunk_decision), a versioned-ID helper (next_version_id that walks the chain to the tip before appending -vN+1), a phase-impact emitter (emit_phase_impact), and a post-dispatch REMOVED-detection pass (detect_removed_entries). create_chunk was restructured around classify+dispatch: NEW → _do_create_chunk passthrough of CREATED, UNCHANGED → SKIPPED, CHANGED → _do_create_chunk for the new versioned ID plus supersede-entry.sh wiring emitting SUPERSEDED: <old> -> <new>.

The phase-impact helper parses scope_tags for [phase:P##] and [milestone:M###/P##] patterns and emits REVIEW: P## affected by <id> supersession for each affected phase, on both supersessions and removals. The REMOVED pass diffs an observed-ID log (append-only text file under .orchestrator/tmp/ with per-PID suffix and EXIT-trap cleanup, chosen over associative arrays for Bash 3.2 compat) against the on-disk SPEC-* entries, skipping *-v[0-9]* successors to avoid self-marking.

A small extension was made to scripts/knowledge/lib/detail-utils.sh find_detail_file — it now scans both one-level (knowledge/<cat>/<id>.md) and two-level (knowledge/<cat>/<subcat>/<id>.md) layouts so nested spec entries resolve during re-ingest.

Three tasks (T01, T02, T03) delivered 10 verification scripts covering classification decisions, supersession frontmatter, REMOVED marking, phase-impact review, provenance traversal (traverse-graph.sh --provenance chain length 2 on one supersession), end-to-end demo scenario reproducing the roadmap sentence, triple-ingest idempotency (chain-tip hash comparison), and Bash 3.2 compat. All 10 P03 verify scripts PASS. P01/P02 regression checks continue to PASS after T02's CREATED: passthrough restored the expected prefix.

Key patterns: decision-layer wrapper around a creation primitive; append-only text file as cross-subshell state sink; base-ID observed-log diff for removal detection; chain-walking version helper; permissive-then-tightened verify script grep patterns across tasks in a phase.
