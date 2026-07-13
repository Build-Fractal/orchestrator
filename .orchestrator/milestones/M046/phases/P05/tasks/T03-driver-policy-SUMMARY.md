---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P05"
milestone: "M046"
provides:
  - "envelope_write_scope_policy(): composes the per-run default-DENY write/tool-scope policy (D018) — allow_path project-root, readonly_path per committed-manifest glob + roadmap + policy self-line, MCP default-deny (no allow_tool), atomic temp+rename; driver wiring: self-continue-drive.sh recomposes .self-continue-scope-policy before each unattended spawn and exports ORCHESTRATOR_UNATTENDED_POLICY into the child; verifier tools/verify/m046-p05-driver-policy.sh (20 assertions incl. live-drive export proof)"
requires:
  - "T01 manifest scripts/hooks/unattended-protected-surface.txt + policy vocabulary (allow_path/readonly_path/allow_tool/allow_bash); P04 scripts/lifecycle/unattended-envelope.sh (sourceable lib) + self-continue-drive.sh (driver, ORCHESTRATOR_UNATTENDED=1 export at run_child)"
affects:
  - "T04/T05 (SC-5/SC-15 harnesses drive a real child under the composed policy), P07 (attempts-ledger forward-slot promotes to active readonly_path once the scoring record exists)"
key_files:
  - "scripts/lifecycle/unattended-envelope.sh, scripts/lifecycle/self-continue-drive.sh, tools/verify/m046-p05-driver-policy.sh"
key_decisions:
  - "Composition function lands in the P04 sourceable envelope lib (minimal driver diff, P04 seam precedent); REPO_ROOT inside driver = <repo>/scripts so manifest=REPO_ROOT/hooks/... and project-root=REPO_ROOT/..; policy recomposed per-spawn (not once) so the P07 ledger forward-slot promotes mid-run; all new logic guarded by UNATTENDED=true and path vars defined inside the unattended init block so the attended region stays byte-identical (FR-17); atomic temp+rename write; P07 slot emitted as # comment placeholder until the ledger file exists"
patterns_established:
  - "Per-run policy composition = committed generic manifest (project-relative globs) abs-resolved against spawn-time project root + milestone-specific SC surfaces + policy self-line, default-DENY (absent allow_tool => MCP deny); forward-slot pattern: contract-now/path-later via existence-gated readonly_path vs comment placeholder; verifier live-drive leg = real driver + stub --auto-cmd child that dumps its env to prove export without a claude -p spawn"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P05/"
duration: "1500s"
verification_result: "pass"
completed_at: "2026-07-13T19:05:59Z"
---

T03 gave the unattended driver a real per-run write/tool-scope policy (D018) for the T01 hook to enforce: added envelope_write_scope_policy() to the P04 sourceable envelope lib (atomic temp+rename; emits allow_path project-root, a readonly_path per committed-manifest glob resolved against the spawn-time project root, readonly_path for the milestone roadmap and the policy file itself, an existence-gated P07 attempts-ledger forward-slot, and NO allow_tool line => MCP default-deny); wired self-continue-drive.sh to resolve PROJECT_ROOT/MANIFEST_FILE/SCOPE_POLICY/ROADMAP_FILE in the unattended init block, recompose .self-continue-scope-policy before each spawn, and export ORCHESTRATOR_UNATTENDED_POLICY into the child beside ORCHESTRATOR_UNATTENDED=1 — all under UNATTENDED=true so the attended path stays byte-identical (FR-17 P04 attended-parity golden re-verified green); authored tools/verify/m046-p05-driver-policy.sh (20/20 pass) exercising the function, driver static wiring, attended-parity absence, and a live-drive leg that runs the real driver with a stub --auto-cmd child dumping its env to prove the export.
