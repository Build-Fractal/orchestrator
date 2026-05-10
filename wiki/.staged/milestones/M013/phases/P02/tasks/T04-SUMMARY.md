---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P02"
milestone: "M013"
provides:
  - "commands/github-init.md subcommand definition (MEM012 structure); scripts/verify/m013-p02-github-init-command.sh 6-assertion gate"
requires:
  - "from:T02 what:scripts/integrations/github-init.sh flag surface; from:T01 what:scripts/integrations/github-common.sh helper API; from:P01/T02 what:commands/github-status.md sibling structure precedent"
affects:
  - "P02/T07 (phase-suite gate ordering); P03 (sync command will mirror this doc shape); M013 operator-facing UX"
key_files:
  - "commands/github-init.md; scripts/verify/m013-p02-github-init-command.sh"
key_decisions:
  - "MEM012-strict (preserve exact section order + headers); SC-7 auto-mode safety documented under Prerequisites (not Idempotency) for discoverability; description field begins 'Use when' per commands/*.md convention"
patterns_established:
  - "6-assertion gate shape — 1 content/length + 1 structural + 1 Referenced-Scripts-resolve + 1 Referenced-Templates-resolve + 1 description-prefix + 1 section-scoped-SC-7; awk-scoped section localisation for 'token must appear inside Prerequisites'; tri-token SC-7 contract check (SC-7 + pending-operator-complete + --i-am-operator)"
drill_down_paths:
  - ".orchestrator/milestones/M013/phases/P02/tasks/T04-PLAN.md; commands/github-init.md; scripts/verify/m013-p02-github-init-command.sh"
duration: "12"
verification_result: "pass"
completed_at: "2026-04-21T21:20:56Z"
---

T04 shipped commands/github-init.md as the agent-facing instruction surface for orchestrator:github init, authored verbatim per T04-PLAN with MEM012 structure preserved: YAML frontmatter (description starts with 'Use when'), Title '# speckit.orchestrator.github-init', Prerequisites / State Check (with SC-7 auto-mode safety paragraph), Core Workflow (7 numbered steps: preflight -> authenticate -> sub-issue mode -> label collisions -> live run -> post-verify -> re-run), Output (three concrete examples: first-live, auto-mode, second-invocation), Idempotency, Error Handling (exit 0/1/2/3), Referenced Scripts (4 paths: github-init.sh, github-common.sh, sidecar-init-pending.sh, github-status.sh — all resolve on disk), Referenced Templates (1 path: templates/github-integration-sidecar.json — resolves). All AD-19 constraints honored: Output examples use single-script-file shapes only. Knowledge-Layer Boundary honored: no KNOWLEDGE-INDEX.md or knowledge/spec/ references beyond P01's existing surface. commands/README.md intentionally untouched per plan (index convention defers to repo lead). The companion gate scripts/verify/m013-p02-github-init-command.sh runs 6 top-level PASS assertions exactly matching the plan's Expected Verification contract: (1) file present + >=50 lines + contains github-init.sh, (2) MEM012 structural sections (frontmatter opener on line 1, Title heading, Prerequisites/Core Workflow/Output/Idempotency/Error Handling/Referenced Scripts/Referenced Templates headers, Core Workflow numbered items 1 and 2), (3) all 4 Referenced Scripts resolve on disk with all 4 mentioned in doc, (4) 1 Referenced Template resolves, (5) description field starts with 'Use when' (tolerant of optional leading quote), (6) SC-7 pending-sentinel contract documented — tri-token check (SC-7 literal + pending-operator-complete + i-am-operator) AND awk-scoped assertion that SC-7 appears inside the Prerequisites section specifically. Gate executed: 6/6 PASS, exit 0. Structural judgment calls: (a) SC-7 placed under Prerequisites rather than Idempotency because it's a pre-invocation safety gate not a re-run property — matches plan Step 1 content verbatim; (b) Core Workflow numbered-item check uses '^1. ' / '^2. ' anchored patterns to avoid matching arbitrary '1.' / '2.' tokens in body prose; (c) assertion-5 description-prefix check strips optional leading quote so both quoted and unquoted YAML forms pass without churn; (d) assertion-6 uses awk block-scope rather than grep -A/-B line windows because MEM012 section lengths vary across commands.
