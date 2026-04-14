---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P06"
milestone: "M005"
provides:
  - "scripts/diagnostics/check-hashes.sh scanning knowledge entries for valid content_hash fields emitting DOCTOR:HASHES; scripts/diagnostics/check-run-ids.sh scanning JSONL entries for run_id presence emitting DOCTOR:RUNIDS"
requires:
  - "from:P01 what:sha256:{hex} format convention from scripts/lib/hash.sh"
affects:
  - "P06"
key_files:
  - "scripts/diagnostics/check-hashes.sh, scripts/diagnostics/check-run-ids.sh, scripts/verify/p06-check-hashes.sh, scripts/verify/p06-check-run-ids.sh"
key_decisions:
  - "none"
patterns_established:
  - "YAML frontmatter content_hash validation, JSONL field presence checking via string match, vacuous truth for empty datasets"
drill_down_paths:
  - "none"
duration: "90s"
verification_result: "pass"
completed_at: "2026-04-13T02:27:33Z"
---

Created check-hashes.sh that scans knowledge entry .md files under .specify/orchestrator/knowledge/ and .specify/knowledge/ for valid content_hash fields in YAML frontmatter matching sha256:[a-f0-9]{64} format. Created check-run-ids.sh that scans execution-log.jsonl files for run_id field presence using simple string matching. Both emit DOCTOR:* structured output. Verification scripts confirm existence, executability, output format, and runtime behavior.
