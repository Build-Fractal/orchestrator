# templates/

Output templates used by orchestrator commands. Agent copies template, fills `{{placeholder}}` values.

## Convention
- YAML frontmatter: `schema_version` + `type` fields (enables future format migration)
- Body: `{{placeholder}}` syntax for all dynamic values
- Context-free: no hardcoded milestone/phase/task IDs
- 13 templates + 1 config default

## Categories

**Planning**: roadmap.md, phase-plan.md, task-plan.md
**Summaries**: task-summary.md (15-field frontmatter), phase-summary.md, milestone-summary.md
**Dispatch/Verification**: dispatch-prompt.md, verification-report.md, spec-compliance-review.md
**Lifecycle**: recovery-briefing.md, continue-file.md, context-draft.md
**Config**: orchestrator-config-default.yml (7 keys with defaults)
