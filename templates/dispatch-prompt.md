---
schema_version: "1.0"
type: dispatch-prompt
---

## First-Turn Completeness

<!-- Emitted by scripts/dispatch/build-context.sh (M019/P00/L1). Derived block
     surfacing intent + constraints + acceptance criteria + files-to-touch
     from the already-included task plan and phase plan. First volatile
     section (appears after the dispatch-volatile opening marker line). -->

{{first_turn_completeness}}

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

- **Duration Budget**: {{duration_budget}}
- **Dispatch Budget**: {{dispatch_budget}}
- **Budget Enforcement**: {{budget_enforcement}}

## Verification

- **Verification Criteria**: {{verification_criteria}}

<!-- M019/P00/L2 Cache Boundary Contract:
     Dispatch payloads assembled by scripts/dispatch/build-context.sh emit
     stable sections (Knowledge, Decisions, Constraints, Scope) first, then
     a standalone dispatch-volatile opening marker line, then volatile
     sections (First-Turn Completeness, State Context, Task Plan, Upstream
     Context, Parallel Fan-Out when applicable), then a standalone
     dispatch-volatile closing marker line. This aligns with Opus 4.7
     cache-boundary guidance. Markers are standalone lines, not XML
     elements inside sections. -->

## Parallel Fan-Out

<!-- Emitted by scripts/dispatch/build-context.sh (M019/P00/L4) ONLY when the
     recipe or task plan declares parallelizable work. Content is the known
     literal directive: spawn multiple subagents in the same turn rather
     than issuing serial tool calls when a task requires reading multiple
     files or fanning out across items. -->

{{parallel_fanout_directive}}

## Payload Size Guidance

Target payload size: **< 30,000 tokens** (~120KB). Payloads beyond this threshold waste context window capacity in the dispatched agent without proportional benefit.

### Priority ordering for context inclusion

When assembling payloads, include sections in this priority order. If the payload exceeds the target size, truncate from the bottom of this list:

1. **Task plan** (always include in full — this is the task's primary instruction)
2. **Phase must-haves** (the verification criteria the task must satisfy)
3. **Direct upstream API signatures** (method signatures, types, and behavioral contracts from immediate dependency summaries — the `provides` fields)
4. **Knowledge entries** (scoped patterns and lessons)
5. **Decision entries** (scoped architectural decisions)
6. **Full upstream summaries** (complete summary bodies — reduce to just `provides` fields if over budget)

### Truncation strategy

When over budget:
- Drop knowledge and decision entries first (they inform but don't constrain)
- Reduce upstream summaries to just their `provides` YAML field values
- Always include the task plan and must-haves in full; truncate lower-priority sections instead.
