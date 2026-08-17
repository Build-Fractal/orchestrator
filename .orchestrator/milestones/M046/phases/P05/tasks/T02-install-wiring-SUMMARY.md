---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P05"
milestone: "M046"
provides:
  - "The M046/P05 production scope-guard hook + its committed protected-surface manifest now ride the M028 consumer install path: two HOOKS_PAYLOAD appends in packaging/install/install-claude-code.sh stage scripts/hooks/unattended-scope-guard.sh + unattended-protected-surface.txt into ~/.claude/orchestrator-hooks/ (+ MANIFEST), and a SECOND PreToolUse wrapper (matcher Write|Edit|Bash|mcp__.*, _orchestrator_managed:true) in the claude-code.sh --hook-config heredoc merges the scope-guard command alongside the existing shape-guard Bash wrapper. One installer run does both (staging + settings-merge) with no installer redesign. Durable verifier tools/verify/m046-p05-install-wiring.sh productionizes the P01 install-matrix against the REAL hook + REAL adapter fragment on both shapes (source-tree A + bundle-staged B), asserting staged/merged/coexists/matcher/idempotent/uninstall-clean = 2/2 all-1s plus bundle-hygiene survival and an isolated-HOME self-check."
requires:
  - "T01 (scripts/hooks/unattended-scope-guard.sh + scripts/hooks/unattended-protected-surface.txt on disk — this task stages them via the installer)"
affects:
  - "T03 (driver exports policy the installed hook reads), T04/T05 (harnesses install the real hook)"
key_files:
  - "packaging/install/install-claude-code.sh (HOOKS_PAYLOAD +2 appends + staged-set doc comment), scripts/dispatch/adapters/runtime/claude-code.sh (2nd PreToolUse wrapper + event-mapping comment), tools/verify/m046-p05-install-wiring.sh (new durable verifier)"
key_decisions:
  - "Single installer run stages via HOOKS_PAYLOAD AND merges via the adapter fragment (no manual cp+merge like the P01 spike); coexistence of the two PreToolUse wrappers is guaranteed by settings-merge's (event,matcher,command) dedup key — distinct matcher strings yield distinct tuples, shape-guard Bash wrapper kept byte-identical; bundle-hygiene filter (M035) does NOT strip the hook/manifest because scripts/hooks/ is outside scripts/verify//tools/verify//templates/conversus-presets/ and neither file carries a bundle:dogfood-only magic comment; uninstall-clean check tolerates the installer normalizing settings.json to file-absent"
patterns_established:
  - "Install-matrix spike productionized as a durable verifier that drives the REAL installer + REAL adapter (not a hand-built probe/fragment); isolated-HOME safety self-check asserts SCRATCH is a prefix of HOME before ANY installer run so a deny-hook never lands in the operator live ~/.claude; leaf-count idempotency metric (grep -c command before==after) survives re-install"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P05/"
duration: "780s"
verification_result: "pass"
completed_at: "2026-07-13T18:56:36Z"
---

Wired the T01 production default-DENY scope-guard hook + committed protected-surface manifest into the M028 consumer install path via two HOOKS_PAYLOAD appends (install-claude-code.sh) and a second PreToolUse wrapper (matcher Write|Edit|Bash|mcp__.*) in the claude-code.sh --hook-config heredoc, coexisting with the existing shape-guard Bash wrapper via settings-merge's (event,matcher,command) dedup key; authored tools/verify/m046-p05-install-wiring.sh which productionizes the P01 install-matrix against the real hook + real adapter on both install shapes (source-tree A + bundle-staged B) and reports SUMMARY: pass=2 fail=0 with each shape all-1s (staged/merged/coexists/matcher/idempotent/uninstall-clean), confirms bundle-hygiene survival, and enforces an isolated-scratch-HOME self-check so the operator's live ~/.claude is never touched.
