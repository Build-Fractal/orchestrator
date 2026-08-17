---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M046"
provides:
  - "Throwaway default-DENY PreToolUse probe evidence: deny-drive.log (6/6 PASS + live-e2e=deferred-to-SC-5) and install-matrix.log (shape A+B all-1s) proving the FR-9 hook premise for #Q-1"
requires:
  - "scripts/hooks/pre-bash-shape-guard.sh, scripts/util/settings-merge.sh, packaging/install/install-claude-code.sh, packaging/bundle/build-bundle.sh"
affects:
  - "T03 (#Q-1 verdict), P05 (FR-9 hook design: policy-file + matcher shape + HOOKS_PAYLOAD addition)"
key_files:
  - ".orchestrator/milestones/M046/phases/P01/spike/hook/unattended-deny-probe.sh, spike/hook/drive-hook-case.sh, spike/hook/run-install-matrix.sh, spike/hook/deny-drive.log, spike/hook/install-matrix.log, spike/hook/policy.txt, spike/hook/fixtures/"
key_decisions:
  - "Bash default-behavior scope: non-dangerous Bash passes in the probe (full Bash default-deny is P05 policy design); allow_bash proven to override the dangerous-pattern deny; --all truncates the log for deterministic re-runs"
patterns_established:
  - "New PreToolUse hook = staged file + one managed settings-merge fragment (matcher Write|Edit|Bash|mcp__.*), zero installer changes; isolated-HOME probe discipline"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P01/spike/hook/"
duration: "496s"
verification_result: "pass"
completed_at: "2026-07-13T15:17:36Z"
---

Hook-install portability spike (#Q-1) all legs green: default-DENY works through the real stdin/exit-2 hook contract (3 deny vectors incl. MCP, 2 allows, fail-closed on missing policy; verified under literal /bin/bash 3.2.57); M028 consumer path accepts a NEW hook on both install shapes (source-tree and bundle-staged) via cp into orchestrator-hooks/ plus one managed settings-merge fragment — coexists with the shape-guard (8 leaf lines, distinct dedup tuples), re-merge no-op, uninstall removes all managed leaves. All runs under scratch HOMEs at /private/tmp/m046-p01-hook-spike/; real HOME never touched. Optional live claude -p leg deferred to SC-5 per dispatch instruction. #Q-1 mechanical halves both point to PASS; T03 owns the verdict line.
