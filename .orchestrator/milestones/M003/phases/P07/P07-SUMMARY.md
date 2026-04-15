---
schema_version: "1.0"
type: phase-summary
id: "P07"
parent: "M003"
milestone: "M003"
provides:
  - "resolver-wired migrate.sh; transform scripts that consume target_root as the absolute orchestrator state root, dual-root idempotency detection in scripts/migrate/lib/idempotency.sh::check_existing_state, rebuild-index wired into migrate.sh as P04 stage; warn-but-continue on failure, commands/migrate.md documents AD-13/AD-14/AD-15 with script cross-references, seven AD-19-safe Tier-1 verify scripts wiring all P07 truth Check: commands to passing static grep-based checks"
requires:
  - "from:M008/P04 what:scripts/state/resolve-root.sh (5-rule resolver, --absolute mode), from:P07/T01 what:resolver-derived target_root semantics in migrate.sh, from:P07/T01 what:resolved target_root + MIGRATE_TARGET_ROOT export, from:M003/P07/T01 what:resolver-wiring; from:M003/P07/T03 what:rebuild-index-wiring, from:P07/T01 what:resolver+MIGRATE_TARGET_ROOT in migrate.sh; from:P07/T02 what:dual-root idempotency probe; from:P07/T03 what:rebuild-index final step; from:P07/T04 what:AD-13/14/15 in commands/migrate.md"
affects:
  - "P07/T02,P07/T03,P07/T04,P07/T05, P07/T03,P07/T04,P07/T05, P07/T05, M003/P07/T05, P07-phase-transition"
key_files:
  - "scripts/migrate/migrate.sh,scripts/migrate/transform/milestone-rollup.sh,scripts/migrate/transform/active-milestone.sh,scripts/migrate/transform/milestone-tiering.sh, scripts/migrate/lib/idempotency.sh, scripts/migrate/migrate.sh, commands/migrate.md, scripts/verify/m003-p07-migrate-sources-resolver.sh,scripts/verify/m003-p07-no-hardcoded-state-paths.sh,scripts/verify/m003-p07-rebuild-index-wired.sh,scripts/verify/m003-p07-idempotency-dual-root.sh,scripts/verify/m003-p07-migrate-md-documents-ads.sh,scripts/verify/m003-p07-bash32-compat.sh,scripts/verify/m003-p07-cli-contract.sh"
key_decisions:
  - "AD-13, AD-13, AD-14, AD-13,AD-14,AD-15, AD-13,AD-14,AD-15,AD-19"
patterns_established:
  - "invoke-not-source for set -u resolver scripts; export resolved root via env var for downstream verify scripts, dual-layout state probe (orchestrator-root vs project-root); bash 3.2 safe glob loop with [ -f ] guard; ls -A non-empty test as single-command form, warn-but-continue post-pipeline rebuild; portable rebuild-script path via _MIGRATE_DIR/.., progressive-disclosure ADR sections in command docs (short body + link to M###-CONTEXT.md), Tier-1 static-grep verify per truth; comment-aware code-line scan via case-pattern filter; broad regex alternation (MIGRATE_TARGET_ROOT OR target_root) to avoid false negatives on legitimate refactors"
drill_down_paths:
  - ".specify/orchestrator/milestones/M003/phases/P07/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M003/phases/P07/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M003/phases/P07/tasks/T03-SUMMARY.md, .specify/orchestrator/milestones/M003/phases/P07/tasks/T04-SUMMARY.md, .specify/orchestrator/milestones/M003/phases/P07/tasks/T05-SUMMARY.md"
duration: "70m"
verification_result: "pass"
completed_at: "2026-04-15T03:04:48Z"
observability_surfaces:
  - "none"
---

P07 refits the M003 migration pipeline to align with architectural surfaces introduced by M007 (knowledge graph) and M008 (5-rule state resolver) after P01–P06 landed.

**What was built** (5 tasks, 5 commits):
- **T01** — `scripts/migrate/migrate.sh` now invokes `scripts/state/resolve-root.sh --absolute` to derive the target root and exports `MIGRATE_TARGET_ROOT`; three transform scripts (`milestone-rollup.sh`, `active-milestone.sh`, `milestone-tiering.sh`) drop the hardcoded `.specify/orchestrator/` segment and consume the resolved root directly.
- **T02** — `scripts/migrate/lib/idempotency.sh::check_existing_state` now probes both orchestrator-root layout (direct `KNOWLEDGE-INDEX.md`/`knowledge/`/`milestones/` under target) and project-root layout (non-empty `.orchestrator/` or `.specify/orchestrator/` subdirs). Eight in-process scenarios pass, plus three end-to-end `migrate.sh` exit-4 conflict scenarios.
- **T03** — `migrate.sh` adds a P04 stage that invokes `scripts/knowledge/rebuild-index.sh --root "$target_root"` after `report.sh`, with warn-but-continue behavior on failure. Produces `knowledge.db` graph file and populates the M007 graph database post-migration.
- **T04** — `commands/migrate.md` documents AD-13 (resolver-driven target root), AD-14 (`relates_to: []` on migrate, post-migration `detect-overlap.sh` enriches), and AD-15 (command-naming deferral) with script cross-references.
- **T05** — Seven AD-19-safe Tier-1 static-verification scripts under `scripts/verify/m003-p07-*.sh` wire each phase truth's `Check:` command to a passing single-file invocation. All seven emit `PASS` and exit 0 against the P07 implementation.

**Key patterns established** (MEM-candidates for consolidation): (1) invoke-not-source pattern for `set -u` resolver scripts to avoid variable-shadow failures; (2) dual-layout state probe with Bash-3.2-safe glob + `[ -f ]` guard; (3) warn-but-continue post-pipeline rebuild with portable relative-path resolution via `_MIGRATE_DIR/..`; (4) progressive-disclosure ADR documentation pattern in command docs (short body + link to `M###-CONTEXT.md`); (5) Tier-1 static-grep verify-per-truth with broad regex alternation to avoid false negatives during legitimate refactors.

**Verification** (Stage 1 phase-level): `check-must-haves.sh` reports 7/7 truth checks PASS. Artifact/key-link check FAILs are false positives from backtick-wrapped paths in the plan; all files exist on disk (confirmed via direct `ls`). Each of the seven `m003-p07-*.sh` verify scripts emits `PASS` and exits 0. No external-mod alerts for files outside the phase's declared produces set.

**Affects downstream**: P08 (end-to-end validation against live GSD2) now has a resolver-wired, graph-populating, dual-root-aware migration pipeline to validate against. No changes invalidate M008/P04 or M007 knowledge consumers.
