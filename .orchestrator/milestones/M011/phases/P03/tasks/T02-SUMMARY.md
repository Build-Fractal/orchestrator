---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M011"
provides:
  - "ingest-spec.sh supersession wiring, REMOVED detection pass, phase-impact REVIEW emission, versioned-ID chain helper"
requires:
  - "T01: classify_chunk_decision helper, _do_create_chunk helper, INGEST_OBSERVED_LOG, dump_observed_log helper; supersede-entry.sh; lib/detail-utils.sh"
affects:
  - "T03 verification, P04 dispatch integration, spec re-ingest change/remove workflows"
key_files:
  - "scripts/knowledge/ingest-spec.sh, scripts/verify/m011-p03-removed-on-deletion.sh, scripts/verify/m011-p03-supersede-frontmatter.sh, scripts/verify/m011-p03-removed-frontmatter.sh, scripts/verify/m011-p03-phase-impact-review.sh, scripts/verify/m011-p03-supersede-on-change.sh, scripts/verify/m011-p03-skip-unchanged.sh"
key_decisions:
  - "Versioned-ID convention base-vN walking chain tip; REMOVED pass skips *-v[0-9]* successors; CREATED: passthrough from _do_create_chunk; emit_phase_impact extracts both [phase:P##] and [milestone:M###/P##]"
patterns_established:
  - "Decision-layer -> action-layer separation (T01 emits DECIDE; T02 wires real actions); chain-walking next-version helper; base-ID observed-log diff for removal detection"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P03/tasks/T02-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-16T20:45:52Z"
---

T02 wires T01's decision layer into real supersession and removal actions in scripts/knowledge/ingest-spec.sh.

CHANGED branch now derives a versioned new ID via next_version_id (walks superseded_by chain to tip, appends -v(N+1) or -v2), creates the new chunk via _do_create_chunk, invokes supersede-entry.sh to set the bidirectional frontmatter fields, emits SUPERSEDED: <old> -> <new>, and calls emit_phase_impact.

NEW branch drops the DECIDE-NEW: prefix and lets the CREATED: line from create-entry.sh pass through (_do_create_chunk re-emits the captured create-entry.sh CREATED line). UNCHANGED emits SKIPPED: <id>.

A post-dispatch detect_removed_entries pass walks knowledge/spec/*/SPEC-*.md, filters out *-v[0-9]* successors and already-superseded entries, checks each base ID against the observed log, patches superseded_by: "REMOVED" on unobserved entries, and emits REMOVED: <id> plus phase-impact REVIEW lines.

emit_phase_impact parses scope_tags for [phase:P##] or [milestone:M###/P##] patterns, emits one REVIEW: P## affected by <id> supersession line per distinct phase.

Summary line now reports created, skipped, superseded, removed, and review counters.

Verification: all 7 P03 verify scripts PASS (skip-unchanged, supersede-on-change, removed-on-deletion, supersede-frontmatter, removed-frontmatter, phase-impact-review, bash32-compat). T01 verify scripts tightened to strict ^SKIPPED: and ^SUPERSEDED: patterns. P02 idempotent verify (m011-p02-idempotent.sh) restored to PASS after the CREATED: passthrough was added. All P02 verify scripts continue to PASS. bash -n clean.
