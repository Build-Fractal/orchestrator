---
schema_version: "1.0"
type: dispatch-prompt
---

## State Context

- **Current State**: {{current_state}}
- **Milestone**: {{milestone_id}}
- **Phase**: {{phase_id}}
- **Task**: {{task_id}}
- **Tier**: {{tier}}

## Scope

{{task_scope}}

## Upstream Context

<!-- Scope-filtered summaries from dependency phases/tasks.
     Only includes summaries from phases listed in the current phase's depends_on field. -->

{{upstream_summaries}}

## Knowledge

<!-- Scope-filtered entries from KNOWLEDGE.md.
     Includes: [project] entries + entries scoped to current milestone/phase. -->

{{knowledge_entries}}

## Decisions

<!-- Scope-filtered entries from DECISIONS.md.
     Includes: decisions scoped to current milestone/phase or marked project-wide. -->

{{decision_entries}}

## Task Plan

<!-- The full task plan content from the current task's plan file. -->

{{task_plan_content}}

## Constraints

- **Verification Criteria**: {{verification_criteria}}
- **Duration Budget**: {{duration_budget}}
- **Dispatch Budget**: {{dispatch_budget}}
- **Budget Enforcement**: {{budget_enforcement}}
