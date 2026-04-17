---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P04"
milestone: "M011"
provides:
  - "End-to-end demo-scenario verification (m011-p04-demo-scenario.sh) + widened Bash 3.2 compat scan (m011-p04-bash32-compat.sh) covering scope-filter.sh + build-context.sh + section-handlers.sh"
requires:
  - "T01: scope-filter.sh --spec-scope-tags mode, T02: build-context.sh spec_context section handler + recipe entry"
affects:
  - "scripts/dispatch/scope-filter.sh (fixed graph-neighbor non-goal/superseded filter in filter_spec_scope_tags), scripts/verify/m011-p04-demo-scenario.sh, scripts/verify/m011-p04-bash32-compat.sh"
key_files:
  - "scripts/verify/m011-p04-demo-scenario.sh, scripts/verify/m011-p04-bash32-compat.sh"
key_decisions:
  - "AD-7 enforcement extended to graph-neighbor Pass 2 in filter_spec_scope_tags; superseded-tip skip applied uniformly to both direct scope tags and graph neighbors; demo fixture designed with SPEC-NG-001 relates_to edge to force AD-7 exercise"
patterns_established:
  - "Rich 13-entry spec fixture pattern for end-to-end dispatch verification; present-ids + absent-ids parallel assertion loops; _spec_id_meta helper for per-neighbor category/superseded lookup with DB + file-frontmatter fallback"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P04/tasks/T03-SUMMARY.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-17T04:02:23Z"
---

T03 delivered end-to-end demo-scenario verification for P04 plus the Bash 3.2 compat widening.

Created scripts/verify/m011-p04-demo-scenario.sh (~180 lines): builds a sandboxed fixture with 13 spec entries across requirement/acceptance/constraint/non-goal/story subdirs. Fixture includes 5 live requirements (SPEC-FR-001..004, SPEC-FR-005-v2), a superseded v1 chunk (SPEC-FR-005-v1 -> -v2), 3 acceptances (AC-006..008), 2 constraints (CON-001..002), a non-goal SPEC-NG-001 carrying relates_to: [SPEC-FR-003] to exercise the AD-7 graph-neighbor exclusion path, and an unrelated story SPEC-US-010. SPEC-FR-003 declares relates_to: [SPEC-AC-007, SPEC-AC-008, SPEC-CON-001]. A task plan scoped to [spec/requirement/SPEC-FR-003] drives build-context.sh; the script asserts the payload contains ## Spec Context, SPEC-FR-003, SPEC-AC-007, SPEC-AC-008, SPEC-CON-001, and does NOT contain SPEC-FR-001/002/004/005 (both v1 and v2), SPEC-AC-006, SPEC-CON-002, SPEC-NG-001, SPEC-US-010. Sandbox is mktemp -d with EXIT trap cleanup; PROJECT_ROOT is set before rebuild-index.sh / build-context.sh.

scripts/verify/m011-p04-bash32-compat.sh was already widened during T02 to scan all three dispatch files (scope-filter.sh, build-context.sh, section-handlers.sh) with comment-aware stripping and process-substitution detection; T03 validated it matches the spec without changes.

Bug surfaced and fixed in T01 territory: scope-filter.sh filter_spec_scope_tags was emitting SPEC-NG-001 as a graph neighbor because traverse-graph.sh returns all relates_to neighbors regardless of category. Applied a Pass-2 filter step to _spec_id_meta helper: for each neighbor SPEC- ID, look up (superseded_by, category) via knowledge.db (with file-frontmatter fallback) and drop neighbors that are superseded tips or spec/non-goal unless --include-non-goals is set. This closes the AD-7 exclusion path for graph-neighbor traversal while preserving existing behavior for directly-referenced spec tags and non-SPEC IDs.

All 10 P04 verify scripts print PASS: and exit 0:
- m011-p04-bash32-compat.sh
- m011-p04-spec-scope-tag-resolve.sh
- m011-p04-spec-scope-tag-graph-neighbors.sh
- m011-p04-requirement-pulls-neighbors.sh
- m011-p04-spec-scope-excludes-non-goals.sh
- m011-p04-spec-scope-skips-superseded.sh
- m011-p04-dispatch-includes-spec-context.sh
- m011-p04-dispatch-omits-spec-context-when-unused.sh
- m011-p04-dispatch-excludes-out-of-scope.sh
- m011-p04-demo-scenario.sh
