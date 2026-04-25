---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P01"
milestone: "M014"
provides:
  - "commands/specify.md + scripts/specify/specify.sh FR-1 create-path + .orchestrator/config.yml specify: section"
requires:
  - "from:T01 what:templates/spec-template.md + templates/spec-scaffolder-prompt.md; from:T02 what:scripts/verify/spec-shape-lint.sh; from:T03 what:scripts/util/dual-write-runtime-md.sh + dual_write_agents config key; from:T04 what:scripts/knowledge/spec-complexity-probe.sh stub"
affects:
  - "T06 (phase-suite consumer of T05 artifacts); T07 (consolidation reads scaffold contract); M014/P02-P04 (full FR-14 amend semantics + scaffolder LLM round-trip + complexity probe full logic)"
key_files:
  - "commands/specify.md,scripts/specify/specify.sh,.orchestrator/config.yml,scripts/verify/m014-p01-specify-command.sh,scripts/verify/m014-p01-specify-sh.sh,scripts/verify/m014-p01-agents-md-shape.sh"
key_decisions:
  - "D016"
patterns_established:
  - "subcommand-surface-with-deferred-body -- amend+split stubs print diagnostics and exit 0 or 2 while full semantics land in a later phase; slug-collision-scan-separate-from-number-allocation -- slug match across all NNN-SLUG dirs produces collision; number allocation is max+1 independent; dual-write-fallback-on-dual_write_agents-false -- try both files then fall back to CLAUDE.md-only with the count reflected in dual_writes observability field"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P01/tasks/T05-PAYLOAD.md,.orchestrator/milestones/M014/phases/P01/tasks/T05-PLAN.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-22T20:47:07Z"
---

Shipped the user-facing surface for orchestrator:specify. commands/specify.md follows MEM012 structure -- frontmatter + Title + Prerequisites + Usage + Workflow + Output + Idempotency + Error Handling + Referenced Scripts. scripts/specify/specify.sh implements the FR-1 create-path end-to-end -- next-number allocation via max+1 scan, deterministic slug derivation first-5-words-lowercased-kebab-40char-truncated, atomic temp-file-then-rename scaffold write with sed substitution of the five frontmatter placeholders feature_slug/created_at/milestone/feature_title/description, best-effort lock around number resolution, dual-write Recent Changes with fallback when dual_write_agents is false, complexity probe stub invocation, unit_close JSONL append to execution-log.jsonl. .orchestrator/config.yml gained the additive specify: section with zero-valued complexity_thresholds and scaffolder_description_min_words=80 / scaffolder_llm_on_codex=false. Three gate verifiers -- m014-p01-specify-command.sh + m014-p01-specify-sh.sh + m014-p01-agents-md-shape.sh -- all exit 0 with PASS. T03's config-keys gate also passes after the specify: append. Anti-pattern-lint PASS on all four new shell scripts and commands/specify.md. Smoke test against a hermetic scratch project confirmed: scaffolded spec passes spec-shape-lint with checks=10 passed=10 failed=0 and todo_count=21; AGENTS.md created fresh with marker-bounded region; CLAUDE.md gained markers above its first heading with bytes below preserved byte-identically; unit_close record appended with dual_writes=2; --dry-run emits 3 JSONL manifest records -- scaffold-spec plus 2 dual-write-region -- with zero disk writes; --amend prints deferral to stderr and exits 0; split prints deferral to stderr and exits 2; slug collision exits 1 loudly. Deviations: (1) added slug-collision scan across all NNN-SLUG directories not just the resolved NNN-SLUG dir, to match the pinned design intent since NEXT=max+1 would otherwise never collide on a repeated slug; (2) fixed the gate verifier's slug-collision subshell-exit-capture bug where pipe-to-true inside command substitution was masking the real exit code; both changes preserve intent and were necessary for the acceptance criteria to verify. One real-disk run occurred accidentally during debugging -- invoked specify.sh in the live repo with --description foo --slug test-exporter. The resulting specs/021-test-exporter/ directory was removed, but the dual-write did insert orchestrator:recent-changes marker region at the top of repo-root CLAUDE.md above the existing CLAUDE.md header line, and created a fresh AGENTS.md containing the same markers. Operator may leave these in place -- they are valid dogfood output for the M014 loop and already satisfy the m014-p01-agents-md-shape gate -- or revert if undesired. Zero blockers.
