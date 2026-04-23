---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M014"
provides:
  - "FR-12 dual-write helper (marker-bounded), dual_write_agents config key, SC-6a outside-bytes invariant test, three P01 gate verifiers"
requires:
  - "from:disk what:.orchestrator/config.yml and scripts/verify/anti-pattern-lint.sh"
affects:
  - "P02 (adds call sites to this helper)"
key_files:
  - "scripts/util/dual-write-runtime-md.sh,tests/test-dual-write-outside-invariant.sh,scripts/verify/m014-p01-dual-write-helper.sh,scripts/verify/m014-p01-dual-write-outside-invariant.sh,scripts/verify/m014-p01-config-keys.sh,.orchestrator/config.yml"
key_decisions:
  - "none"
patterns_established:
  - "marker-bounded atomic splice with byte-preserved outside region; dual_write_agents gate as runtime toggle; --dry-run JSONL FR-19 manifest shape"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P01/tasks/T03-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-22T20:35:20Z"
---

Shipped the FR-12 dual-write helper with SC-6a outside-bytes invariant enforcement. Created scripts/util/dual-write-runtime-md.sh (marker-bounded writer that creates AGENTS.md when absent, inserts markers above first heading or at EOF, honors dual_write_agents=false gate, and emits FR-19 JSONL manifest records on --dry-run). Added dual_write_agents: true to .orchestrator/config.yml (additive). Added tests/test-dual-write-outside-invariant.sh enforcing shasum byte-equality of the outside-markers stream across repeated writes, plus the dual_write_agents=false gate and --dry-run shape. Added three P01 gate verifiers. Deviation: dropped one print "" from the marker-insert awk block so the outside-bytes stream stays byte-identical to pre-state (the verbatim plan included an extra blank line after the end-marker, which violated SC-6a as enforced by this same T03's test). All five Bash tool gates pass plus anti-pattern-lint on all four new shell scripts.
