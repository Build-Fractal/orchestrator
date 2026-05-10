---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P01"
milestone: "M013"
provides:
  - "knowledge/spec/defect/ schema (README.md); scripts/integrations/uat-ingest.sh fixture-driven ingester; SPEC-DEFECT-NNN.md frontmatter contract with status enum (open|chunk-lookup-failed|triaged|closed) and chunk/phase/tests graph edges"
requires:
  - "from:T04 what:KNOWLEDGE-INDEX.md ## Spec Chunks section emitted by rebuild-index.sh used as chunk-lookup source"
affects:
  - "knowledge/spec/defect/,scripts/integrations/,tests/fixtures/m013-p01/uat-bug-issues/,scripts/verify/"
key_files:
  - "knowledge/spec/defect/README.md,scripts/integrations/uat-ingest.sh,tests/fixtures/m013-p01/uat-bug-issues/valid-chunk.json,tests/fixtures/m013-p01/uat-bug-issues/unknown-chunk.json,scripts/verify/m013-p01-defect-schema.sh,scripts/verify/m013-p01-uat-ingest.sh"
key_decisions:
  - "D014 Knowledge-Layer Boundary: SPEC-DEFECT-NNN is a new category owned by spec/defect; chunk field references existing SPEC-* IDs verbatim with no composite addressing; FR-10 ruling requires chunk-lookup-failed sentinel entries (never silent drop)"
patterns_established:
  - "fixture-driven ingester with issue-number-pinned IDs (SPEC-DEFECT-NNN where NNN is zero-padded github issue number) for deterministic idempotency; python3-preferred with grep/sed fallback JSON reader avoids jq hard dep on bare macOS; chunk lookup sourced from KNOWLEDGE-INDEX.md ## Spec Chunks section via awk range scan (T04 contract); sentinel-value pattern for lookup failures (status=chunk-lookup-failed, chunk='') preserves input rather than dropping"
drill_down_paths:
  - ".orchestrator/milestones/M013/phases/P01/tasks/T05-PLAN.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-21T18:12:27Z"
---

T05 ships the knowledge/spec/defect/ schema contract and the scripts/integrations/uat-ingest.sh fixture-driven ingester. README.md documents the 10 required frontmatter fields (id, scope_tags, category, status, chunk, phase, tests, github_issue_number, created_at, ingested_at), the four-value status enum with transitions, [M020](../../../../../milestones/M020/index.md) forward-compatibility (optional review_state/cluster_id/similarity_hash fields remain valid), and the Knowledge-Layer Boundary ruling (D014). uat-ingest.sh is bash 3.2 compatible (no declare -A, no process substitution), makes zero gh subprocess calls (P01 is scaffold only), uses a python3-preferred JSON reader with grep/sed fallback to avoid a jq hard dep, builds the known-chunk set from awk-scanning KNOWLEDGE-INDEX.md's ## Spec Chunks section (T04 contract), writes SPEC-DEFECT-NNN.md files with frontmatter edges to chunk/phase/tests, flags unknown chunk IDs as status=chunk-lookup-failed with empty chunk field (never silent drop per FR-10/D014), and is idempotent via github_issue_number match (second run reports created=0 skipped=N). Two fixtures (valid-chunk.json referencing SPEC-US-001, unknown-chunk.json referencing SPEC-NOEXIST-999) drive the two gates. Both gates pass: m013-p01-defect-schema.sh (15 PASS + final PASS, exit 0) and m013-p01-uat-ingest.sh (14 PASS + final PASS, exit 0). Non-negotiables honored: bash 3.2 compat, AD-19 single-script-file shape, AP-009 no compound chains in verification, structured INGEST/SKIP/SUMMARY/PASS/FAIL output prefixes, 0/1 exits (2 for CLI args), idempotent check-before-write. Constitution XIV/XV: only T05-PLAN Must-Have files touched; rebuild-index.sh, github-status.sh, and issue template left untouched.
