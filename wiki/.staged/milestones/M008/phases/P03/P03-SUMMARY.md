---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M008"
milestone: "M008"
provides:
  - "intensity-gate.sh — central stage-level gate with 7x3 matrix (stages × Quick/Standard/Full), intensity-override.sh — atomic mid-workflow intensity override with scope-limited file touches, intensity-knowledge.sh — intensity-aware wrapper over M007 knowledge scripts with --dry-run support, Intensity Behavior sections appended to 5 pipeline command docs — discuss, plan-phase, dispatch, verify, auto, P03 Bash 3.2 compat scan + end-to-end intensity scaling integration test"
requires:
  - "from:P01/T04 what:intensity-metadata.md schema, from:P01/T04 what:intensity-metadata.md schema, from:P01/T04 what:intensity-metadata.md schema, from:P03/T01 what:intensity-gate.sh, from:P03/T01 what:intensity-gate.sh,from:P03/T02 what:intensity-override.sh,from:P03/T03 what:intensity-knowledge.sh"
affects:
  - "P03/T04,P03/T05, P03/T05, P03/T05, P03/T05, P05/all"
key_files:
  - "scripts/engine/intensity-gate.sh, scripts/engine/intensity-override.sh, scripts/knowledge/intensity-knowledge.sh, commands/discuss.md,commands/plan-phase.md,commands/dispatch.md,commands/verify.md,commands/auto.md, scripts/verify/m008-p03-bash32-compat.sh,scripts/verify/m008-p03-integration-e2e.sh"
key_decisions:
  - "centralized stage×intensity matrix in one script to avoid drift across 5 command docs, atomic frontmatter rewrite via mktemp+mv preserves body; scope limited to metadata file only (verified by cksum sentinels), thin wrapper pattern — delegates to existing M007 scripts rather than reimplementing, additive-only command doc refactor — preserves MEM012 structure and degrades gracefully if gate script absent"
patterns_established:
  - "central lookup table for stage-level behavior scaling — single source of truth for intensity-aware pipeline, atomic metadata rewrite — awk-based frontmatter surgery with cksum sentinel verification, intensity-aware wrapper with --dry-run mode for integration testing without knowledge-side-effects, additive intensity-awareness refactor — command docs reference intensity-gate.sh at entry rather than rewriting core workflow, end-to-end intensity scaling test with mid-workflow override — validates all 4 substep behaviors"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P03/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P03/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P03/tasks/T03-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P03/tasks/T04-SUMMARY.md, .specify/orchestrator/milestones/M008/phases/P03/tasks/T05-SUMMARY.md"
duration: "14m"
verification_result: "pass"
completed_at: "2026-04-14T16:11:37Z"
observability_surfaces:
  - "intensity-gate.sh stdout (execute_substeps= and skip_substeps= key=value pairs); intensity-override.sh exit codes (0=success, 1=IO, 2=invalid intensity, 3=no-op); intensity-knowledge.sh --dry-run stdout (echoed sub-invocations for inspection)"
---

Phase P03 wired intensity awareness into every pipeline stage. Created scripts/engine/intensity-gate.sh — the central 7×3 stage×intensity matrix (discuss/research/plan-phase/dispatch/verify/knowledge/auto × Quick/Standard/Full) that returns execute_substeps + skip_substeps as key=value pairs. Created scripts/engine/intensity-override.sh implementing atomic frontmatter rewrite via awk+mktemp+mv, preserving original_intensity on first override, setting overridden_by=developer, rejecting no-ops and invalid levels. Scope-limited to metadata file only — verified by cksum sentinels against other files. Created scripts/knowledge/intensity-knowledge.sh as a thin wrapper over [M007](../../../../milestones/M007/index.md) knowledge scripts: Quick invokes only write-summary.sh, Standard adds append-decision.sh, Full adds append-knowledge.sh + rebuild-index.sh. --dry-run mode echoes intended invocations without side effects, enabling integration test. Additively refactored 5 pipeline command docs (discuss.md, plan-phase.md, dispatch.md, verify.md, auto.md) with Intensity Behavior sections — 18 insertions each, 0 deletions, MEM012 structure preserved, graceful degradation if gate absent. Integration test validates gate matrix distinctness (21 combinations), override atomicity/scope-limiting, and mid-workflow Quick→Full override with completed-stage preservation. Patterns established: (1) central lookup table for stage-level behavior scaling, (2) atomic metadata rewrite via awk+mktemp+mv with cksum-sentinel verification, (3) thin wrapper pattern over existing scripts with --dry-run mode, (4) additive-only command doc refactor.
