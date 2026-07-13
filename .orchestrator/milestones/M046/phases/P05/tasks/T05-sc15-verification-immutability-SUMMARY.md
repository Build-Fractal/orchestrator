---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P05"
milestone: "M046"
provides:
  - "tools/verify/m046-p05-sc15-verification-immutability.sh -- the SC-15 MILESTONE-BLOCKING NON-STUBBED verification-integrity gate proving FR-20/CON-7 separation-of-doing-and-scoring: a real unattended child driven through the LIVE installed production hook (real install-claude-code.sh into isolated HOME + real Write|Edit matcher merged into settings.json + real per-run policy composed by T03 envelope_write_scope_policy) is BLOCKED (exit 2) on mutation of all three protected categories (SC/spec definition under specs/, verification harness under tools/verify/, its own P07 attempts-ledger scoring record) via Edit AND via Write-overwrite-of-existing, while the doing-vs-scoring seam is proven honest in both directions -- a Write CREATING a not-yet-existing verifier under the protected tree PASSES (exit 0) and a legitimate work-dir summary Write PASSES (exit 0); pass=12 fail=0 exit 0"
requires:
  - "scripts/hooks/unattended-scope-guard.sh (T01 readonly_path semantics), scripts/hooks/unattended-protected-surface.txt (T01 manifest globs), scripts/lifecycle/unattended-envelope.sh::envelope_write_scope_policy (T03), packaging/install/install-claude-code.sh (T02 M028 install path)"
affects:
  - "T06 (phase suite aggregates this verifier), P05 close (SC-15 milestone-blocking gate)"
key_files:
  - "tools/verify/m046-p05-sc15-verification-immutability.sh"
key_decisions:
  - "Reused the T04 SC-5 honest-realism harness spine (isolated scratch HOME + mandatory mktemp-prefix self-check + real installer + real matcher-routing extraction + real composed policy + live hook stdin/exit-2 contract). Extended the plan's four cases to SIX to satisfy the dispatch honesty requirement of proving BOTH seam directions: added an Edit-on-ledger case (dispatch requires 'prove Edit is denied' for the scoring record; the plan only specified a Write-overwrite) and a create-new-verifier-under-protected-tree case (Write to a not-yet-existing path under tools/verify/ PASSES because readonly_path denies overwrite/Edit but preserves creation, then allow_path admits it). The P07 attempts-ledger forward-slot is exercised for real: the harness stub-creates the ledger file so envelope_write_scope_policy PROMOTES it from a #-comment placeholder to an active readonly_path line, then proves Edit + Write-overwrite are both denied on it. Adapted the T04 same-wrapper matcher-routing awk proof from the mcp__.* token to the Edit token since SC-15 exercises Write|Edit not MCP. No stub in the enforcement path; no seeded exit codes; operator ~/.claude never touched."
patterns_established:
  - "doing-vs-scoring seam proven in BOTH directions in one harness: edit/overwrite-existing-protected DENIED (exit 2) vs create-new-under-protected-tree PASSED (exit 0), so a blanket-deny regression that would break real unattended execution cannot hide behind deny-only assertions. P07-ledger-forward-slot exercise pattern: stub-create the scoring file so the composition promotes the placeholder comment to an active readonly_path, then assert both mutation paths deny."
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P05/"
duration: "780s"
verification_result: "pass"
completed_at: "2026-07-13T21:06:01Z"
---

Authored tools/verify/m046-p05-sc15-verification-immutability.sh (292 lines, contains readonly_path), the SC-15 milestone-blocking non-stubbed verification-integrity gate. It installs the production PreToolUse hook via the real install-claude-code.sh into an isolated scratch HOME (mandatory mktemp-prefix self-check, rm -rf on EXIT), confirms the merged settings.json Write|Edit wrapper resolves to the staged guard, composes the real per-run policy via T03 envelope_write_scope_policy (allow_path project-root + readonly_path per committed manifest glob + the P07 attempts-ledger which the harness stub-creates so the forward-slot promotes to an active readonly_path), and drives the live hook under ORCHESTRATOR_UNATTENDED=1: all three protected categories deny on Edit (SC/spec under specs/ exit 2, harness under tools/verify/ exit 2, own attempts-ledger scoring record exit 2) plus a Write-overwrite of the existing ledger denies (exit 2); the doing-vs-scoring seam is proven honest in both directions -- a Write creating a not-yet-existing verifier under tools/verify/ passes (exit 0) and a legitimate work-dir P05-SUMMARY.md Write passes (exit 0). Result SUMMARY: pass=12 fail=0, exit 0. No stub in the enforcement path, no seeded exit codes, operator ~/.claude untouched.
