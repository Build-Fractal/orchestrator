---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "M033/P01"
milestone: "M033"
provides:
  - "references/branch-detection.md SSOT for FR-2 branch-detection rules; tools/verify/m033-p01-branch-detection-ssot-parity.sh cross-parity verifier"
requires:
  - "from:none what:none"
affects:
  - "P02..P05 sub-flow phases that may extend detection; T03 (start.sh implementation must byte-match SSOT pattern strings)"
key_files:
  - "references/branch-detection.md;tools/verify/m033-p01-branch-detection-ssot-parity.sh"
key_decisions:
  - "none"
patterns_established:
  - "SSOT-with-byte-matched-implementation parity pattern (grep -F fixed-string cross-check between reference doc and implementing script); fenced-rule-block convention (branch-detection-rule-N markers); SKIP-gate pattern for verifiers co-authored before their implementation lands"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P01/tasks/T02-branch-detection-ssot-PAYLOAD.md"
duration: "18m"
verification_result: "pass"
completed_at: "2026-05-04T02:55:34Z"
---

T02 ships references/branch-detection.md (235 lines) as the canonical SSOT for FR-2 deterministic branch-detection rules and tools/verify/m033-p01-branch-detection-ssot-parity.sh (177 lines, executable) as the cross-parity verifier. The SSOT documents the four-branch closed enum (greenfield-empty, greenfield-with-materials, existing-codebase, migrating), the four ordered detection rules with literal pattern strings in fenced branch-detection-rule-N blocks, ambiguity handling (Case A: rule-1+rule-3 collision; Case B: thin-git-history per MIT-006/RISK-006), the --branch override contract, and cross-references to FR-2/MIT-006/RISK-006/AD-4 plus the P02..P05 consumers and start.sh implementer. The verifier first asserts SSOT internal shape (rule blocks present, branch names documented, load-bearing pattern strings present in SSOT — 16 PASS), then gates on scripts/lifecycle/start.sh existence: when absent (current T02 state), emits SKIP and exits 0; when present (post-T03), runs cross-parity grep -F fixed-string assertions for each pattern string. Verification result: pass=16 fail=0 skip=1 — the exact shape predicted by the task-plan Notes (one SKIP for the deferred start.sh cross-check, all SSOT-internal assertions PASS). No deviations from plan; no scope-affecting decisions taken.
