---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P08"
milestone: "M003"
provides:
  - "tests/fixtures/m003-p08-gsd-minimal/ synthetic deterministic GSD2 fixture (16 KB gsd.db from seed.sql + memories-snapshot.json + milestones/M001/SUMMARY.md + build-fixture.sh + README.md); .gitignore exception for tests/fixtures/**/.gsd/**"
requires:
  - "from:P07 what:migrate.sh --source gsd2 accepts --path/--output/--force; from:scripts/migrate/lib/sqlite-reader.sh what:GSD2 schema contract"
affects:
  - "P08/T02,P08/T03,P08/T04"
key_files:
  - "tests/fixtures/m003-p08-gsd-minimal/.gsd/seed.sql,tests/fixtures/m003-p08-gsd-minimal/.gsd/gsd.db,tests/fixtures/m003-p08-gsd-minimal/.gsd/memories-snapshot.json,tests/fixtures/m003-p08-gsd-minimal/.gsd/milestones/M001/SUMMARY.md,tests/fixtures/m003-p08-gsd-minimal/build-fixture.sh,tests/fixtures/m003-p08-gsd-minimal/README.md,.gitignore"
key_decisions:
  - "AD-001 (commit both seed and pre-built db for CI speed + reproducibility)"
patterns_established:
  - "PRAGMA page_size=1024 for compact SQLite fixtures under 50 KB; hard-coded ISO-8601 timestamps for deterministic binary output; .gitignore negation for test-fixture subtrees that share a name with ignored dev state"
drill_down_paths:
  - ".specify/orchestrator/milestones/M003/phases/P08/tasks/T01-PAYLOAD.md,tests/fixtures/m003-p08-gsd-minimal/README.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-15T03:24:21Z"
---

Built the synthetic GSD2 fixture that replaces the developer-specific lakeledger submodule as the CI-reachable end-to-end target for the P08 integration test. Seed.sql seeds all seven tables (memories, decisions, requirements, milestones, slices, tasks, verification_evidence) with hard-coded timestamps; PRAGMA page_size=1024 keeps gsd.db at 16 KB (well under the 50 KB budget). build-fixture.sh regenerates gsd.db deterministically — two consecutive builds produce byte-identical output (sha verified). memories-snapshot.json mirrors the memories rows for the JSON fallback branch; milestones/M001/SUMMARY.md exercises the filesystem-scan branch. Added a .gitignore negation for tests/fixtures/**/.gsd/** so the committed fixture isn't swallowed by the repo-root .gsd ignore (which covers live dev state). Smoke-test: migrate.sh --source gsd2 exits 0 and MIGRATION-REPORT.md shows non-zero counts in every section (Knowledge 4, Decisions 2, Requirements Active 2, Milestones Active 1 + Recent 1 + Total 2, Telemetry 3). Used R-prefix (R001/R002) for requirement IDs because report.sh counts table rows via grep -cE '^\| *R[0-9]'. Two pre-existing report.sh quirks surfaced but are out of T01 scope: rebuild-index.sh warn-but-continue emits "Index generation failed" (ignored), and trailing "0" double-lines appear on zero-count rows from a grep -c || echo 0 pattern. Neither affects the non-zero assertion per section.
