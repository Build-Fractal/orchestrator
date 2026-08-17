---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P05"
milestone: "M046"
provides:
  - "tools/verify/m046-p05-sc5-write-tool-scope.sh — the SC-5 MILESTONE-BLOCKING, NON-STUBBED write/Bash/MCP scope harness. Installs the REAL production hook via the real install-claude-code.sh into an isolated scratch HOME, composes the real per-run policy via the T03 envelope_write_scope_policy function, proves matcher routing is real (the mcp__.* PreToolUse wrapper command resolves to the staged unattended-scope-guard.sh), and drives the genuinely-installed hook through the authentic PreToolUse stdin->exit-2 contract to BLOCK all three out-of-scope vectors (write outside allow_path, git push, mcp__* call) with the MCP vector as a first-class DENY; positive control (in-scope Write) passes exit 0; env-gate leg (ORCHESTRATOR_UNATTENDED unset) no-ops all three. SUMMARY: pass=13 fail=0, exit 0."
requires:
  - "scripts/hooks/unattended-scope-guard.sh (T01), packaging/install/install-claude-code.sh + scripts/dispatch/adapters/runtime/claude-code.sh Write|Edit|Bash|mcp__.* matcher (T02), scripts/lifecycle/unattended-envelope.sh::envelope_write_scope_policy (T03), scripts/hooks/unattended-protected-surface.txt manifest"
affects:
  - "T06 (phase suite aggregates), P05 close (SC-5 milestone-blocking gate)"
key_files:
  - "tools/verify/m046-p05-sc5-write-tool-scope.sh"
key_decisions:
  - "Honest-realism: no live remote MCP round-trip is attempted because reaching an MCP server would prove the hook FAILED — a PreToolUse deny fires BEFORE tool dispatch, so the exit-2 block IS the containment and IS the MCP proof; the enforcement path (installer -> settings matcher -> live hook -> exit 2) contains no stub and no seeded verdict. Mandatory isolation self-check refuses to run unless HOME is under a mktemp scratch prefix; rm -rf on EXIT trap; the operator real ~/.claude is never touched. Routing-is-real proven by a serializer-agnostic awk brace-depth walk of the PreToolUse array that extracts the command belonging to the wrapper whose matcher contains mcp__.* and asserts it equals 'bash <staged-guard>' with the guard executable — deny provably comes from real wiring. The composed policy uses allow_path <project-root>/ so any write outside the work dir is out-of-scope, and no allow_tool line => MCP default-deny."
patterns_established:
  - "NON-STUBBED milestone-blocking gate shape: real installer into isolated scratch HOME + real T03 policy composition + same-wrapper routing extraction + authentic PreToolUse stdin/exit-2 drive across write/bash/mcp vectors with env-gate no-op leg; the MCP containment is asserted as an exit-2 block, never a network call."
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P05/"
duration: "780s"
verification_result: "pass"
completed_at: "2026-07-13T21:00:43Z"
---

Authored tools/verify/m046-p05-sc5-write-tool-scope.sh, the SC-5 milestone-blocking non-stubbed gate: it runs the real install-claude-code.sh into an isolated mktemp scratch HOME (mandatory self-check + rm -rf EXIT trap so the operator real ~/.claude is never touched), composes the per-run policy via the T03 envelope_write_scope_policy function exported as ORCHESTRATOR_UNATTENDED_POLICY, proves the merged settings.json mcp__.* PreToolUse wrapper command resolves to the staged unattended-scope-guard.sh (routing is real, not assumed), then drives the genuinely-installed hook through the authentic PreToolUse stdin->exit-2 contract to BLOCK an out-of-scope Write, a git push Bash, AND an mcp__slack__post_message call (all exit 2, MCP a first-class DENY), while the in-scope Write positive control passes exit 0 and the env-gate leg no-ops all three; no live remote MCP server is ever contacted because the deny fires before tool dispatch; verification SUMMARY: pass=13 fail=0, exit 0.
