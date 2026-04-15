---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P07"
milestone: "M003"
provides:
  - "rebuild-index wired into migrate.sh as P04 stage; warn-but-continue on failure"
requires:
  - "from:P07/T01 what:resolved target_root + MIGRATE_TARGET_ROOT export"
affects:
  - "P07/T05"
key_files:
  - "scripts/migrate/migrate.sh"
key_decisions:
  - "AD-14"
patterns_established:
  - "warn-but-continue post-pipeline rebuild; portable rebuild-script path via _MIGRATE_DIR/.."
drill_down_paths:
  - ".specify/orchestrator/milestones/M003/phases/P07/tasks/T03-PAYLOAD.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-15T02:27:54Z"
---

Appended P04 'Knowledge Index + Graph Rebuild' stage to scripts/migrate/migrate.sh after report.sh. New block resolves rebuild-index.sh via $_MIGRATE_DIR/.., invokes it with --root "$target_root", logs success + graph-DB presence, and warns (does not fail migration) on either rebuild-script failure or missing/empty knowledge.db. Smoke run on this repo (commit 2de7e29) produced KNOWLEDGE-INDEX.md (213 bytes, 0 entries) and knowledge.db (36KB SQLite) at the temp target_root; migration exits 0. traverse-graph.sh --id MEM001 against the live repo DB returns MEM002/MEM004/MEM008 (exit 0) — graph stack is functional. T05 verify scripts (m003-p07-rebuild-index-wired.sh, m003-p07-bash32-compat.sh, m003-p07-cli-contract.sh) do not exist yet — to be created in T05; CLI contract sanity-checked manually (--help exit 0, no-path exit 1). Bash 3.2 compat preserved: only [ ], if/then/else, no associative arrays, no process substitution. Commit: 2de7e29.
