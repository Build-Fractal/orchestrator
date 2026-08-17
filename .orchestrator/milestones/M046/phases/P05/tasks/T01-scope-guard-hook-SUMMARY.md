---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P05"
milestone: "M046"
provides:
  - "Framework-owned production default-DENY PreToolUse scope guard scripts/hooks/unattended-scope-guard.sh (D017 env-gate: exit 0 unless ORCHESTRATOR_UNATTENDED set -> attended session never constrained; D018 policy path from ORCHESTRATOR_UNATTENDED_POLICY, fail-closed on missing/unreadable; D019 default-DENY all mcp__* unless exact allow_tool; FR-20/CON-7 readonly_path directive with create-vs-overwrite seam; expanded Bash denylist git-push + network family curl/wget/nc/ncat/ssh/scp/sftp/telnet + rm-rf-outside-allow_path, allow_bash wins); committed generic manifest scripts/hooks/unattended-protected-surface.txt (project-relative globs specs/ tools/verify/ scripts/verify/ scripts/hooks/); unit verifier tools/verify/m046-p05-scope-guard-deny.sh with 9 fixtures + policy.txt driving the real stdin->exit-2 contract, SUMMARY: pass=14 fail=0"
requires:
  - "P01 throwaway probe design (unattended-deny-probe.sh stdin/extract/policy-helper/dispatch scaffolding); pre-bash-shape-guard.sh sibling conventions"
affects:
  - "T02 (install wiring), T03 (driver composes the policy), T04/T05 (SC-5/SC-15 harnesses drive this hook)"
key_files:
  - "scripts/hooks/unattended-scope-guard.sh, scripts/hooks/unattended-protected-surface.txt, tools/verify/m046-p05-scope-guard-deny.sh, tools/verify/fixtures/m046-p05/"
key_decisions:
  - "D017 env-gate is the FIRST executable statement after set -u (attended = pure fast no-op, safety-critical); readonly_path checked BEFORE allow_path so protected surface overrides writability; Write create-new to readonly path falls through to allow_path (doing-vs-scoring seam); network family via single grep -Eq word-boundary regex instead of per-tool case arms; UNATTENDED_SCOPE_GUARD: reason prefix replaces probe DENY_PROBE:; policy composed per-run by T03 driver, manifest carries only framework-generic globs (P07 attempts-ledger forward-slot contract documented)"
patterns_established:
  - "Env-gated PreToolUse hook: gate on ORCHESTRATOR_UNATTENDED as first statement so operator session is untouched; readonly_path create-vs-overwrite via [ -e ] test; verifier case_expect(fixture,expected,UNATT,policy) with separate unset-vs-export branch so env-gate no-op is proven distinctly; isolated /tmp/m046p05 scratch fixtures never touch repo tree"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P05/"
duration: "1080s"
verification_result: "pass"
completed_at: "2026-07-13T18:50:20Z"
---

T01 productionized the P01 throwaway deny-probe into the framework-owned default-DENY PreToolUse hook scripts/hooks/unattended-scope-guard.sh (272 lines, Bash 3.2, no jq, no process substitution, self-contained), applying the four specced production changes: (1) D017 env-gate as the first statement after set -u (exit 0 unless ORCHESTRATOR_UNATTENDED set, so the operator interactive session is never constrained), (2) D018 policy path from ORCHESTRATOR_UNATTENDED_POLICY with fail-closed deny on missing/unreadable, (3) FR-20/CON-7 readonly_path directive checked before allow_path denying Edit/NotebookEdit unconditionally and Write only when the target already exists while passing Write to a not-yet-existing path (the doing-vs-scoring seam), and (4) UNATTENDED_SCOPE_GUARD reason prefix plus expanded Bash denylist (git push, network family curl/wget/nc/ncat/ssh/scp/sftp/telnet, rm -rf outside allow_path, allow_bash wins), plus D019 default-DENY on all mcp__* unless exactly allow_tool-listed; committed the generic manifest scripts/hooks/unattended-protected-surface.txt (specs/, tools/verify/, scripts/verify/, scripts/hooks/) and the unit verifier tools/verify/m046-p05-scope-guard-deny.sh with nine JSON fixtures under isolated /tmp/m046p05, which asserts the enforcing deny/pass matrix, the SAFETY-CRITICAL env-gate no-op leg (out-of-scope Write/git push/mcp all exit 0 when ORCHESTRATOR_UNATTENDED is unset), the readonly create-vs-overwrite distinction, and fail-closed on missing policy: SUMMARY pass=14 fail=0 under both the tool bash and literal /bin/bash 3.2.57, and both invocations survived the live M021 shape-guard with no REJECT.
