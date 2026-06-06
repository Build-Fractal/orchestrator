---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P01"
milestone: "M034"
provides:
  - "status/doctor unreviewed-decision surfacing (FR-4): read-decisions.sh engine + render-status field + check-decisions advisory"
requires:
  - "from:T01 what:DECISIONS_WARN_FINDING_THRESHOLD SSOT; from:T02 what:packet emit format"
affects:
  - "P02"
key_files:
  - "scripts/knowledge/read-decisions.sh scripts/diagnostics/check-decisions.sh scripts/diagnostics/render-status-json.sh scripts/diagnostics/run-doctor.sh tools/verify/m034-p01-surfacing.sh"
key_decisions:
  - "active=no superseded_by bullet; unreviewed honors sibling REVIEW.md (P02 drives to zero); top-level unreviewed_decisions fallback (M029 envelope has no per-phase array); threshold/warn from SSOT"
patterns_established:
  - "read-decisions subcommands print one int; check-decisions DOCTOR status line; additive read-only renderer field"
drill_down_paths:
  - ".orchestrator/milestones/M034/phases/P01/tasks/T04-surfacing-PLAN.md"
duration: "22m"
verification_result: "pass"
completed_at: "2026-06-06T23:44:15Z"
---

read-decisions.sh: active-count, unreviewed-count (sibling REVIEW.md aware), unreviewed-warn-count, dir-unreviewed-count. render-status-json.sh gains additive unreviewed_decisions int via dir-unreviewed-count over the milestone dir (top-level fallback per plan step 2 — M029 envelope has no per-phase object). check-decisions.sh advisory DOCTOR: status=warn at >=DECISIONS_WARN_FINDING_THRESHOLD else ok/skip; wired into run-doctor.sh. SC-2 non-zero half verified; zero-after-SIGNOFF forward to P02. Slice verifier PASS; live render smoke valid JSON unreviewed_decisions:0.
