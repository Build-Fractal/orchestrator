---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M020"
provides:
  - "scripts/knowledge/query.sh implementing FR-2 sub-clauses a-e plus --format ids from f; five T01 verifier scripts under scripts/verify/ for help, default-state-filter, match-rule, ranking, and format-ids"
requires:
  - "from:P01/T02 what:scripts/knowledge/lib/frontmatter.sh::fm_read_status, from:P01/T01 what:knowledge/conventions/MEM031.md closed enum candidate-graduated-archived"
affects:
  - "P02/T02,P02/T03,P02/T04"
key_files:
  - "scripts/knowledge/query.sh,scripts/verify/m020-p02-query-help.sh,scripts/verify/m020-p02-query-default-state-filter.sh,scripts/verify/m020-p02-query-match-rule.sh,scripts/verify/m020-p02-query-ranking.sh,scripts/verify/m020-p02-query-format-ids.sh"
key_decisions:
  - "D024"
patterns_established:
  - "dispatch-callable read-only knowledge query surface sourcing only fm_read_status; lazy topic-keyword index (no persistent cache, walks knowledge tree every query per Principle VI); two-tier ranking buffer tier 0 topic-field tier 1 tag-only sorted -k1,1n -k2,2r for last_verified-desc tiebreak; PROJECT_ROOT env-var fixture isolation reused from P01"
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P02/tasks/T01-query-core-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-25T12:23:36Z"
---

Created scripts/knowledge/query.sh (read-only FR-2 query surface) and five T01 verifier scripts. All five verifiers PASS. T02 surface (--format json + no-match diagnostic + side-effect-free verifier) intentionally deferred per CON-4. No deviations from plan.
