---
schema_version: "1.0"
type: phase-summary
id: "P00"
parent: "M034"
milestone: "M034"
provides:
  - "PC-1 stdin-JSON calling convention; PC-2 Case A RISK-5 cleared; #Q-1 append-with-supersede-chain; representative decision-packet fixture"
requires:
  - "from:spec what:FR-1 schema + PC-1/PC-2 acceptance criteria"
affects:
  - "P01"
key_files:
  - ".orchestrator/milestones/M034/M034-P00-ADDENDUM.md,.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md,tools/verify/m034-p00-addendum.sh"
key_decisions:
  - "PC-1=stdin-JSON;PC-2=CaseA-RISK5-cleared;Q1=append-with-supersede-chain"
patterns_established:
  - "agent-writes-REVIEW.md-directly on interactive CC path (in-process coordination boundary)"
drill_down_paths:
  - ".orchestrator/milestones/M034/M034-P00-ADDENDUM.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-06-06T21:53:57Z"
observability_surfaces:
  - "tools/verify/m034-p00-addendum.sh PASS"
---

# P00 — Empirical baseline + P0 pre-planning addendum

Resolved the two P0 pre-planning conditions and #Q-1 so P01 starts
zero-context-complete. No spec amendment required — RISK-5 cleared.

## What shipped

- **M034-P00-ADDENDUM.md** (265 lines) — PC-1, PC-2, #Q-1 sections.
- **fixtures/decisions-packet-baseline.md** (99 lines) — synthetic-representative-of-lakeledger-M066/P01 packet; 8 entries exercising the full FR-1 field-set, incl. one `severity: warn` (D-5) and one `type: boundary_translation` (D-7, the surface_acres→surface_area_acres drift).
- **tools/verify/m034-p00-addendum.sh** (46 lines) — AD-19-clean phase verifier; PASS.

## PC-1 — write-decisions.sh calling convention

Decided: **stdin-fed JSON document** `{"decisions": [ {8 FR-1 keys} ]}`; non-content params (`--milestone`/`--artifact`/`--out`) are shell-safe flags; **no escaping required** of field bodies (JSON carries newlines/quotes/metacharacters losslessly; writer uses `jq -r` + quoted expansion, never re-shell-interprets). jq moves optional→required for this script (P01 packaging note). Baseline: write-summary.sh's per-field-file trick (`write-summary.sh:78-93`) does not scale to an entry array — stdin-JSON is the array-native analog.

## PC-2 — CC renderer execution context (RISK-5) — Case A, CLEARED

Inspected the REAL backend `local-agent.sh` (the arbiter's `cc.sh` does not exist). Evidence: normal mode spawns no subprocess — emits a dispatch-result descriptor (`local-agent.sh:98-143`) and per MEM018 (`:2-15`, `:133-143`) the Agent invocation runs in-process at the orchestrating agent layer. `grep 'claude -p'` and `grep 'AskUserQuestion'` both empty across `scripts/dispatch/**`. Only CC backend is local-agent.sh; it is in-process. **Case A**: the interactive_review stage issues AskUserQuestion from the already-interactive top-level CC session (AD-3 two-layer model). RISK-5 does NOT escalate. REVIEW.md write-path: **agent-writes-directly** on the interactive path; interactive-review.sh writes it on the deterministic non-interactive paths (defer/accept-with-audit/refuse-entry/headless).

## #Q-1 — supersede semantics

Decided: **append-with-supersede-chain** (mirrors M036). Per-entry content_hash; unchanged=no-op, changed=append with `supersedes:`/`superseded_by:`. SC-1 "one entry per decision" = one *active* entry. Rationale: Principle VI auditability, M036 mechanism consistency, bounded cost. Resolves tolerated RISK-7.

## Verification

`bash tools/verify/m034-p00-addendum.sh` → PASS. `check-must-haves.sh P00` → all truths/artifacts/key-link PASS. P01 unblocked.
