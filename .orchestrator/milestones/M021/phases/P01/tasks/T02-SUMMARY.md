---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M021"
provides:
  - "scripts/util/read-range.sh wrapper emitting inclusive 1-indexed line ranges via awk, plus m021-p01-read-range.sh gate"
requires:
  - "none"
affects:
  - "P01"
key_files:
  - "scripts/util/read-range.sh"
key_decisions:
  - "none"
patterns_established:
  - "read-range wrapper replaces sed -n 'M,Np' inline shape that trips Claude Code quoted-brace / sed-write heuristic"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P01/tasks/T02-PLAN.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-17T16:13:24Z"
---

Created scripts/util/read-range.sh — Bash 3.2 compatible wrapper that validates three args (file + M + N), checks file presence/readability, validates integer shape via case globs against *[!0-9]* and empty string, enforces M>=1 and N>=M, rejects N beyond file line count (wc -l | awk), then emits the inclusive range via awk -v m -v n with an early NR>n exit. Exits 0 on success, 1 on missing/unreadable file, 2 on any argument/range invalidity. Created scripts/verify/m021-p01-read-range.sh gate with 7 assertions: happy-path 3..5 range, single-line 1..1 range, missing-file exit 1, inverted range exit 2, out-of-file range exit 2, non-integer M exit 2, missing-N arg exit 2. All 7 PASS. Implementation matches the literal plan source with no deviations. No declare -A, mapfile, readarray, process substitution, or ${var,,} in either file.
