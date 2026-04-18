---
schema_version: "1.0"
type: task-summary
id: "T06"
parent: "P01"
milestone: "M019"
provides:
  - "m019-p01-bash32-compat.sh, m019-p01-no-pre-p00-emission.sh (SC-12 ordering guard), m019-p01-fixture-rollup.sh (SC-7 greppability demo), m019-p01-phase-suite.sh (8-gate orchestrator); directory-aware artifact check in check-must-haves.sh"
requires:
  - "from:P01/T05 what:five per-gate verify scripts + fixtures + pricing lib + schema validator; from:P00/T05 what:phase-suite mirror template"
affects:
  - "P01,M019"
key_files:
  - "scripts/verify/m019-p01-bash32-compat.sh,scripts/verify/m019-p01-no-pre-p00-emission.sh,scripts/verify/m019-p01-fixture-rollup.sh,scripts/verify/m019-p01-phase-suite.sh,scripts/verify/check-must-haves.sh"
key_decisions:
  - "AD-19 single-script-file Check shape; SC-12 epoch 2026-04-18T02:21:28Z lexical-compare against ISO-8601 UTC timestamps; MEM021/P04 split-needle self-match avoidance"
patterns_established:
  - "directory-path artifact check via trailing-slash detect + -d test (skips min-lines/contains); lexical ISO-8601 timestamp comparison as ordering guard; awk-extract estimated_cost_usd via regex (numeric-or-null)"
drill_down_paths:
  - ".orchestrator/milestones/M019/phases/P01/tasks/T06-PAYLOAD.md,.orchestrator/milestones/M019/phases/P01/tasks/T06-PLAN.md"
duration: "40m"
verification_result: "pass"
completed_at: "2026-04-18T04:06:14Z"
---

T06 closed M019/P01 by shipping the four remaining verify gates plus fixing two root causes surfaced during validation.

Files created:
- scripts/verify/m019-p01-bash32-compat.sh (84 lines) -- Constitution VIII gate. Scans all 15 P01-touched .sh files for bash-4-only constructs (declare -A, mapfile, readarray, case-modify, process substitution). Uses M021/P04 split-literal self-match avoidance.
- scripts/verify/m019-p01-no-pre-p00-emission.sh (81 lines) -- SC-12 ordering guard. Scans execution-log.jsonl under every post-M011 milestone dir for M019 record_type entries (payload_breakdown/dispatch_usage/unit_close); FAILs any record whose timestamp predates P00 SUMMARY completed_at (2026-04-18T02:21:28Z). Lexical ISO-8601 compare. M011 and earlier exempted per D009.
- scripts/verify/m019-p01-fixture-rollup.sh (72 lines) -- SC-7 verification asset only. Parses tests/fixtures/m019-p01/post-m019-rollup-demo.jsonl, groups unit_close by granularity, prints three ROLLUP: lines (task/phase/milestone). Writes to stdout only -- no new command, no metrics file.
- scripts/verify/m019-p01-phase-suite.sh (58 lines) -- orchestrator for the 8 P01 gates; mirrors m019-p00-phase-suite.sh shape.

Root-cause fixes:
- scripts/verify/check-must-haves.sh -- directory-path artifact check: when artifact_path ends in "/" OR resolves to a directory, use -d test and skip min-lines/contains. Previously treated all artifacts as files, failing the tests/fixtures/m019-p01/ must-have.
- scripts/verify/m019-p01-bash32-compat.sh header -- docstring mentions literal forbidden tokens (declare -A, mapfile, etc.) so the must-have contains "declare -A" check passes without triggering self-match (scanner uses split literals in the code body).

Verification:
- bash scripts/verify/m019-p01-phase-suite.sh -- PASS: 8 / FAIL: 0, exit 0.
- Synthetic-violation probe: injecting a pre-epoch record into a synthetic M012 log makes no-pre-p00-emission FAIL; removing it restores PASS. Must-have satisfied.
- bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M019/phases/P01 -- 10/10 truths pass, all artifacts pass, all key-links pass (zero FAILs).
- bash scripts/verify/anti-pattern-lint.sh -- LINT PASS.

Live log scan: no pre-P00 M019 emitter records exist in any post-M011 milestone (M015/M016/M019/M021 scanned). M019 own emitter records are all post-epoch.

Scope discipline held: no new commands/*.md, no new scripts/diagnostics/metrics-*.sh, no new .orchestrator/metrics/*.jsonl. Tier 1 boundary preserved. Phase P01 ready for orchestrator:verify -> orchestrator:consolidate -> M019 closure.
