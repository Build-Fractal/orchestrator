---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "M024/P02"
milestone: "M024"
provides:
  - "scripts/intake/spec-shape-classify.sh; scripts/intake/proposal-emit.sh (3b spec hook); scripts/verify/m024-p02-spec-shape-classify.sh"
requires:
  - "from:M024/P01/T04 what:proposal-emit.sh override-variable convention"
affects:
  - "P02/T03"
key_files:
  - "scripts/intake/spec-shape-classify.sh, scripts/intake/proposal-emit.sh, scripts/verify/m024-p02-spec-shape-classify.sh"
key_decisions:
  - "Use spec 028 (M014-migrated) instead of plan-suggested spec 023 (lacks type:feature-spec frontmatter)"
patterns_established:
  - "Spec-branch override hook mirroring (3a) paragraph hook; chunks-first metric path with raw-spec fallback per NG-1"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P02/tasks/T01-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-26T01:53:09Z"
---

T01 replaces P01 stub axis values for input_shape=spec by adding scripts/intake/spec-shape-classify.sh — a pure stdout classifier that emits scope_tier (A/B/C), decomposition, recommended_command (always orchestrator:roadmap per FR-6), metrics_source (spec_chunks|raw_spec), and rationale_spec. Tier thresholds inherited unchanged from commands/evaluate.md (NG-1: FR ≥10 OR AC ≥15 OR story ≥4 -> Tier C; FR ≤3 AND AC ≤5 AND story ≤1 -> Tier A; else Tier B). Chunks-first via scripts/state/spec-metrics.sh when knowledge/spec/ exists; raw-spec grep fallback otherwise. Wired into scripts/intake/proposal-emit.sh as the (3b) hook block immediately after the existing (3a) paragraph hook — sets the same scope_tier_override / decomposition_override / recommended_command_override variables that the existing override-application block at line ~100 consumes. Also stages spec_rationale and spec_evidence variables for T03 to swap into the body. Verify script asserts both classifier stdout shape and emitter end-to-end wiring (proposal frontmatter populated correctly + no P01 stub on scope_tier/decomposition slots). DEVIATION: plan specifies spec 023-github-native-integration as fixture, but that spec lacks the M014 type:feature-spec frontmatter that the classifier requires. Used spec 028-universal-intake-routing instead (in-repo, M014-migrated, classifies as Tier C). The other in-repo migrated specs are 021/025/026/027 — same outcome. Open question for P02 plan: should spec 023 be retroactively migrated to M014 frontmatter, or should the plan reference a migrated spec? Verification: PASS: spec-shape-classify.sh — tier classification + emitter wiring.
