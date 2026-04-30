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

## Investigation Patterns

<!-- Static reference for the dispatched agent. Names the four canonical
     wrappers under scripts/util/ that replace agent-invented compound shells.
     The dispatched agent reads this section in-payload and calls these
     wrappers instead of constructing inline grep ; echo ; grep / find | head |
     xargs sh -c '...' / node -e "<multiline body>" / etc. shapes. -->

If you need to investigate the codebase mid-task, use these canonical wrappers under `scripts/util/` instead of constructing compound shells (which the active M021/M028 shape guard will reject):

- **Grep one pattern across multiple files**: `bash scripts/util/grep-files.sh <pattern> <file...>` — emits per-file separators; replaces `grep PAT f1 ; echo '---' ; grep PAT f2`. Cross-ref: ANTIPATTERNS.md AP-010.
- **Remove stale per-step result files for a milestone**: `bash scripts/util/cleanup-stale-results.sh <milestone-id>` — refuses paths outside the milestone tree. Cross-ref: M028 Finding D.
- **Run a short Node script** (file path, NOT `-e` body): `bash scripts/util/node-eval.sh <script-path> [args...]` — refuses `-e`/`-p`. Cross-ref: ANTIPATTERNS.md AP-012.
- **Peek first N lines of files matching a glob**: `bash scripts/util/peek-files.sh <glob> [--lines N] [--exclude PATH] [--max N]` — replaces `find ... | head | xargs -I PH sh -c '...'`. Cross-ref: ANTIPATTERNS.md AP-013 + AP-014.

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

<!-- handle_template (scripts/dispatch/lib/section-handlers.sh) emits two
     sub-sections under Constraints: "### Prohibited inline bash patterns"
     and "### Branch Discipline". The Branch Discipline subsection forbids
     unannounced git checkout/switch/branch/merge/rebase inside a dispatched
     task. -->


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
