---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "M015/P01"
milestone: "M015"
provides:
  - "new scripts/verify/m015-p01-no-stale-refs.sh; reference sweep across 30+ retained files with deleted-path references removed or updated"
requires:
  - "T01-T03 deletions"
affects:
  - "P03 doc reframe (5 P03-reserved docs + specs/ + .planning/ remain tolerated by verify script allow-list)"
key_files:
  - "scripts/verify/m015-p01-no-stale-refs.sh, scripts/verify/check-must-haves.sh, scripts/knowledge/lib/index-utils.sh, scripts/lifecycle/generate-permissions.sh, scripts/knowledge/write-summary.sh, scripts/AGENTS.md, scripts/verify/m002-p03-*.sh (8 files), scripts/verify/m002-p04-*.sh (9 files), scripts/verify/m007-p03-provenance-chain-traversal.sh, scripts/verify/m004-p06-check-must-haves-root.sh, references/file-formats.md, references/constitution-walkthrough.md, commands/evaluate.md, templates/orchestrator-config-default.yml, tests/test-s01-structure.sh, tests/test-s06-knowledge-lifecycle.sh, tests/test-s07-integration.sh, tests/AGENTS.md, knowledge/patterns/MEM007.md, .claude/settings.local.json"
key_decisions:
  - "Hard-deleted 8 dead extension-registration verify scripts (m002-p05/p06/p07, m004-p07, m006-p04/p06, p06-*) whose entire purpose was asserting registration in extension.yml; deleted .specify/scripts/powershell/ mirror tree (same dead condition as deleted bash tree); deleted unreferenced root-level speckit-orchestrator-overview.md (pre-M015 historical doc, zero cross-refs); rewrote test-s01 and test-s07 to drop extension.yml manifest assertions while retaining directory-structure + command cross-ref + capability-detection + idempotency checks; replaced extension.yml project-root sentinel in get_project_root and 18 test-fixture sites with .orchestrator/ + .specify/orchestrator/ + .git markers."
patterns_established:
  - "Verify-script allow-list can extend beyond spec's 5 P03 doc files when historical artifact classes (specs/, .planning/) and self-reference cases (m015-p01 verify scripts naming their own assertion patterns) legitimately match; BSD grep's --exclude-dir is basename-matched so post-filter with grep -Ev on path prefixes is required"
drill_down_paths:
  - ".specify/orchestrator/milestones/M015/phases/P01/tasks/T04-PLAN.md"
duration: "55"
verification_result: "pass"
completed_at: "2026-04-15T11:45:42Z"
---

T04 reference sweep complete. Discovery grep returned ~40 non-exempt files; edited 30 in-tree files and deleted 9 dead scripts (8 extension-registration verify scripts + 1 pre-M015 overview MD + 5 powershell mirrors counted as one tree). Two deviations worth flagging: (1) the verify script's allow list extends beyond the 5 P03 docs to include specs/, .planning/, commands/migrate.md, scripts/state/detect-speckit.sh, scripts/dispatch/adapters/format/speckit.sh, and the 6 sister m015-p01 verify scripts — these legitimately reference the patterns as historical context, migration-source descriptors, or self-assertions. (2) 8 dead extension-registration verify scripts (m002-p05/p06/p07, m004-p07, m006-p04/p06 variants, p06) were hard-deleted rather than flagged because their entire body asserts extension.yml registration; with the manifest gone there is nothing to salvage. Incidental fixes: (a) check-must-haves.sh previously parsed artifact paths including surrounding backticks — added sed backtick-strip so P01-PLAN.md's code-span-quoted artifact paths resolve correctly; (b) check-must-haves.sh project-root walk now uses .git / .orchestrator / .specify/orchestrator markers instead of extension.yml. Verification: bash scripts/verify/m015-p01-no-stale-refs.sh prints 'PASS: no stale references to deleted paths in non-doc files' and exits 0; bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M015/phases/P01 reports all 7 truths PASS, all 7 artifacts PASS (including min-lines and contains checks), and the P01-PLAN → 015 spec key-link PASS. Exit 0.
