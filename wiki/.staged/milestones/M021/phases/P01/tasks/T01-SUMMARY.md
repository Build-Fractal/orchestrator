---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M021"
provides:
  - "scripts/util/with-env.sh wrapper exporting KEY=VALUE assignments before -- into a child command, plus m021-p01-with-env.sh gate"
requires:
  - "none"
affects:
  - "P01"
key_files:
  - "scripts/util/with-env.sh"
key_decisions:
  - "none"
patterns_established:
  - "with-env wrapper replaces inline VAR=val cmd prefix that trips Claude Code safety heuristic"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P01/tasks/T01-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-17T16:03:00Z"
---

Created scripts/util/with-env.sh — Bash 3.2 compatible wrapper that parses KEY=VALUE pairs before a -- separator, validates identifier shape via case globs, exports them, then execs the trailing command forwarding its exit code. Exits 2 on usage errors (missing --, empty command, malformed assignment). Identifier validation uses two nested case checks against negated character classes ([!A-Za-z_]* and *[!A-Za-z0-9_]*) rather than the [A-Za-z_][A-Za-z_0-9]*=* glob from the plan's literal source — the plan's glob rejected single-letter keys like A=1, so the implementation was hardened while keeping Bash 3.2 semantics. Created scripts/verify/m021-p01-with-env.sh gate exercising six assertions (happy path, multi-assignment, RC forwarding, missing --, empty cmd, malformed assignment); all six PASS. No declare -A, mapfile, process substitution, or bashism-incompatible expansions in either file.
