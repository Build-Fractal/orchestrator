---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P04"
milestone: "M014"
provides:
  - "scripts/specify/specify.sh split full body (FR-7 LLM-assisted decomposition, CC-only v1); RUNTIME-ASSUMPTIONS.md FR-7 entry; scripts/verify/m014-p04-split-subcommand.sh gate verifier"
requires:
  - "from:P01 what:scripts/specify/specify.sh P01 stub + RUNTIME-ASSUMPTIONS.md registry scaffold; from:P04/T03 what:templates/spec-splitter-prompt.md; from:P04/T04 what:specify.sh three-way d-path delegation; from:disk what:scripts/dispatch/dispatch-interface.sh"
affects:
  - "M014/P04/T07 phase-suite (gate verifier registered); M024 Universal Intake (interim manifest path migrates to .orchestrator/intake/<id>/decomposition.md); M009 runtime-parity audit (FR-7 entry appended to punch-list)"
key_files:
  - "scripts/specify/specify.sh,scripts/verify/m014-p04-split-subcommand.sh,RUNTIME-ASSUMPTIONS.md"
key_decisions:
  - "D016 (RUNTIME-ASSUMPTIONS registry); D007 (conversus-adapter reuse — splitter uses dispatch-interface directly, not adapter); verbatim plan body faithfully reproduced"
patterns_established:
  - "stub-to-full transition (P01 stub exit 2 -> P04 full body with distinct exit 3 for runtime gate); CC-only LLM round-trip via dispatch-interface with canned-response hermetic smoke; manifest validation by line-count grep (>=2 and <=4 '  - slug:' entries) + type marker grep; interim-path-with-forward-compat-schema (M024 migration target documented in FR-7 entry body)"
drill_down_paths:
  - "/Users/brettkellgren/Sites/lakeledger/orchestrator/.orchestrator/milestones/M014/phases/P04/tasks/T05-PAYLOAD.md,/Users/brettkellgren/Sites/lakeledger/orchestrator/.orchestrator/milestones/M014/phases/P04/tasks/T05-PLAN.md"
duration: "18m"
verification_result: "pass"
completed_at: "2026-04-23T01:01:20Z"
---

T05 replaces P01 split stub (exit 2) with FR-7 full LLM-assisted splitter body (CC-only v1, exit 3 under Codex/Cursor). specify.sh split <path> validates the target, derives source-id from spec-directory basename, gates on CC runtime (CLAUDE_CODE_RUNTIME=1 env or detect-capabilities.sh --runtime), invokes scripts/dispatch/dispatch-interface.sh with templates/spec-splitter-prompt.md, validates the YAML manifest shape (type: decomposition-manifest marker + 2..4 '  - slug:' entries), writes to .orchestrator/specify/decomposition/<source-id>/manifest.md (interim — [M024](../../../../milestones/M024/index.md) migrates to .orchestrator/intake/<id>/decomposition.md with write-forward-compat schema), emits unit_close JSONL on write. Dry-run path emits one FR-19 propose-decomposition record per proposed sub-spec, no disk writes. RUNTIME-ASSUMPTIONS.md appended with FR-7 entry between FR-5 and end-of-file sentinel (four required subsections: Claude Code assumption / Codex-Cursor fallback / Milestone-phase / M009 obligation). Gate verifier scripts/verify/m014-p04-split-subcommand.sh exercises: P01-stub-gone, full-body markers (propose-decomposition + spec-splitter-prompt.md + decomposition/), non-CC exit 3, no-arg exit 1, missing-path exit 1, FR-7 four-subsection shape, FR-7 position between FR-5 and sentinel. Hermetic CC-path smoke (via staged mock of dispatch-interface.sh with canned YAML) confirmed: manifest written with 3 entries, dry-run emits 3 propose-decomposition JSONL records with no disk write. No deviations from plan body. Bash 3.2 + anti-pattern-lint clean on both modified/created scripts.
