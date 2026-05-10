---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P07"
milestone: "M003"
provides:
  - "dual-root idempotency detection in scripts/migrate/lib/idempotency.sh::check_existing_state"
requires:
  - "from:P07/T01 what:resolver-derived target_root semantics in migrate.sh"
affects:
  - "P07/T03,P07/T04,P07/T05"
key_files:
  - "scripts/migrate/lib/idempotency.sh"
key_decisions:
  - "AD-13"
patterns_established:
  - "dual-layout state probe (orchestrator-root vs project-root); bash 3.2 safe glob loop with [ -f ] guard; ls -A non-empty test as single-command form"
drill_down_paths:
  - ".specify/orchestrator/milestones/M003/phases/P07/tasks/T02-PAYLOAD.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-15T02:17:25Z"
---

Replaced check_existing_state body to detect orchestrator state under both [M008](../../../../../milestones/M008/index.md) canonical layouts under $target_root: layout (a) where target IS an orchestrator root (KNOWLEDGE-INDEX.md, DECISIONS.md, knowledge/*.md, knowledge/*/*.md, milestones/ directly under it) and layout (b) where target is a project root containing .orchestrator/ or .specify/orchestrator/ subdirectories (legacy parent-dir mode). Updated header docstring per task plan Step 3. enforce_conflict_policy untouched per Step 2. Manually verified 8 in-process scenarios plus 3 end-to-end migrate.sh invocations: all three layout-(a)/(b)/.orchestrator-style cases exit 4; clean target and empty knowledge/ + empty .orchestrator/ remain clean. Bash 3.2 syntax check passes; no declare -A, no |&, no ${,,}, no < <(), no sed -i.bak. T05's verify scripts (m003-p07-idempotency-dual-root.sh) do not yet exist — will land in T05. Commit: dbb21ac.
