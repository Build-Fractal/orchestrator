---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P03"
milestone: "M021"
provides:
  - ".claude/settings.json PreToolUse hook registration (bash scripts/hooks/pre-bash-shape-guard.sh, Bash matcher, single-hook per AD-1a), 9 new allow-list entries widening the M016 set without removing any pre-existing entry, scripts/dispatch/lib/section-handlers.sh handle_template constraints branch extended with a sibling Allowed invocation shapes subsection naming the three P01 wrappers with usage examples"
requires:
  - "from:T02 what:scripts/hooks/pre-bash-shape-guard.sh; from:P01 what:scripts/util/with-env.sh,read-range.sh,run-probe.sh"
affects:
  - "P03,P04,P05"
key_files:
  - ".claude/settings.json,scripts/dispatch/lib/section-handlers.sh"
key_decisions:
  - "AD-1a,SC-5"
patterns_established:
  - "Additive JSON edit preserves existing allow entries in original order; JSON validity preserved across edit via python3 json.tool round-trip"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P03/tasks/T03-PLAN.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-17T19:35:39Z"
---

T03 registers the T02 PreToolUse hook in .claude/settings.json and widens the allow-list by 9 entries. The 71 pre-existing allow entries and 35 deny entries remain byte-identical. The new allow entries are Read for /var/folders/**, Bash for bash /tmp/*.sh and bash /var/folders/**/*.sh, Bash for ls tmp/**, cat tmp/**, sed -n *, head *, tail *, and stat *. section-handlers.sh handle_template constraints branch now emits a sibling Allowed invocation shapes subsection listing scripts/util/with-env.sh, scripts/util/read-range.sh, scripts/util/run-probe.sh with one-line usage examples and a pointer to scripts/hooks/pre-bash-shape-guard.sh. Verification: python3 json.tool parses settings.json; bash -n on section-handlers.sh exits 0; manual handle_template render emits both Prohibited inline bash patterns and Allowed invocation shapes subsections in order. The m021-p03-hook-integration.sh gate referenced in must-haves is T05s deliverable (not yet present); it runs as part of the phase verification suite. Note: running the hook against my own dispatch turned out to exercise it live - the hook hard-rejected a brace expansion in one of my summary args, proving the T02 hook is wired correctly.
