---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M006"
name: "Create docs/knowledge-management.md — entry lifecycle, staleness, graphs, consolidation"
depends_on: ["T01"]
---

## Prerequisites

- `docs/` directory exists (created by T01).
- P01 reference docs exist: `references/architecture.md`, `references/file-formats.md`.
- Knowledge scripts exist: `scripts/knowledge/*.sh`.

## Description

Create a user guide at `docs/knowledge-management.md` that teaches a user how to
use the orchestrator's knowledge management system. The knowledge system is one
of the orchestrator's most distinctive features — it captures patterns, decisions,
and lessons learned during development, then makes them available to future tasks
via scope-filtered context injection. The audience is "users" (DC-2).

The guide follows progressive disclosure (DC-1): start with what knowledge
entries are, then walk through the lifecycle, then cover advanced features
like graph relationships and consolidation. All cross-links use relative
paths (DC-3).

The document covers:

1. **Overview** — what the knowledge system does, why it matters
   (Constitution Principle 7: Knowledge Compounds), how entries flow into
   task dispatch context (2-3 paragraphs).

2. **Knowledge Entry Anatomy** — the structure of a knowledge entry:
   - YAML frontmatter fields (type, scope, confidence, tags, supersedes,
     related_to, etc.)
   - Markdown body (the actual knowledge content)
   - Where entries live (`KNOWLEDGE.md` index, inline in summaries)
   - Cross-links to `references/file-formats.md` for full schema.

3. **Creating Entries** — how entries are created:
   - Automatic creation via `write-summary.sh` (after task/phase completion)
   - Manual creation via `create-entry.sh`
   - Inline entries in decision logs (`append-decision.sh`, `append-knowledge.sh`)
   - Entry types: pattern, decision, lesson, antipattern

4. **Entry Lifecycle** — the operations available on entries:
   - **Update** (`update-entry.sh`) — modify content or metadata
   - **Promote** (`promote-entry.sh`) — increase confidence level
   - **Archive** (`archive-entry.sh`) — mark as no longer actively relevant
   - **Supersede** (`supersede-entry.sh`) — replace with a newer entry
   - Each operation with a concrete example of when you'd use it.

5. **Staleness** — how the system tracks entry freshness:
   - How `compute-staleness.sh` works
   - Staleness factors (age, hit count, confidence, related changes)
   - How stale entries are flagged during context assembly
   - `scripts/knowledge/lib/staleness.sh` library

6. **Graph Relationships** — how entries relate to each other:
   - `related_to` links (bidirectional association)
   - `supersedes` links (replacement chain)
   - `traverse-graph.sh` — walking the relationship graph
   - `detect-overlap.sh` — finding duplicate or overlapping entries
   - `resolve-entries.sh` — resolving entries by scope and relationship

7. **Scope Filtering** — how entries are filtered for relevance:
   - Scope levels: global, milestone, phase, task
   - How `scripts/dispatch/scope-filter.sh` selects entries for dispatch context
   - Filtering by confidence, staleness, tags
   - How to tag entries for effective filtering

8. **Consolidation Workflow** — compressing knowledge after milestones:
   - When to consolidate (after milestone completion)
   - `consolidate-artifacts.sh` — what it does
   - `rebuild-index.sh` — rebuilding the knowledge index
   - The `speckit.orchestrator.consolidate` command
   - Before/after example showing how verbose task-level entries
     compress into milestone-level patterns

## Steps

### Step 1 — Read source materials for accuracy

Read all knowledge scripts to understand the actual behavior:

- `scripts/knowledge/create-entry.sh` — entry creation
- `scripts/knowledge/update-entry.sh` — entry updates
- `scripts/knowledge/promote-entry.sh` — confidence promotion
- `scripts/knowledge/archive-entry.sh` — archiving
- `scripts/knowledge/supersede-entry.sh` — supersession
- `scripts/knowledge/compute-staleness.sh` — staleness calculation
- `scripts/knowledge/lib/staleness.sh` — staleness library
- `scripts/knowledge/traverse-graph.sh` — graph traversal
- `scripts/knowledge/detect-overlap.sh` — overlap detection
- `scripts/knowledge/resolve-entries.sh` — entry resolution
- `scripts/knowledge/consolidate-artifacts.sh` — consolidation
- `scripts/knowledge/rebuild-index.sh` — index rebuilding
- `scripts/knowledge/append-decision.sh` — decision logging
- `scripts/knowledge/append-knowledge.sh` — knowledge logging
- `scripts/knowledge/increment-hits.sh` — hit counter
- `scripts/knowledge/update-confidence.sh` — confidence updates
- `scripts/knowledge/write-summary.sh` — summary generation
- `scripts/dispatch/scope-filter.sh` — scope-based filtering
- `references/file-formats.md` — knowledge entry frontmatter schema
- `references/architecture.md` — knowledge subsystem in subsystem map
- `.specify/orchestrator/KNOWLEDGE.md` — example of the knowledge index
- `commands/consolidate.md` — consolidate command flow

### Step 2 — Write docs/knowledge-management.md

Create the file following the structure in the Description section.
Use concrete examples throughout — show actual YAML frontmatter, actual
script invocations, and actual output. Where possible, use simplified
versions of real entries from `.specify/orchestrator/KNOWLEDGE.md` as
examples.

### Step 3 — Verify-as-you-write (DC-4)

For every script name mentioned:
- Confirm the script exists at the stated path.
- Confirm the script accepts the documented arguments.

For every YAML field name:
- Confirm it appears in `references/file-formats.md` knowledge entry schema
  or in actual knowledge entries.

For every lifecycle operation:
- Read the corresponding script to confirm the operation works as described.

## Must-Haves

- [ ] `docs/knowledge-management.md` exists and is 150+ lines
- [ ] File opens with progressive disclosure statement and audience label "users"
- [ ] Contains `## Overview` section
- [ ] Documents knowledge entry anatomy (frontmatter fields, body, location)
- [ ] Documents entry creation (automatic and manual)
- [ ] Documents entry lifecycle (update, promote, archive, supersede)
- [ ] Documents staleness computation
- [ ] Documents graph relationships (related_to, supersedes, traversal)
- [ ] Documents scope filtering
- [ ] Documents consolidation workflow
- [ ] Cross-links to `references/file-formats.md` and `references/architecture.md`
- [ ] All cross-links use relative paths and resolve to existing files
- [ ] Every script path mentioned exists on disk

## Verification

After writing the file, run:

```
bash scripts/verify/m006-p04-km-header.sh
bash scripts/verify/m006-p04-km-content.sh
```

All must exit 0. If any verification script does not yet exist (because T05
has not run), verify manually by grepping the file for required patterns.

## Inputs

### From Previous Tasks

- T01: `docs/` directory exists.

### From Disk (Pre-existing)

- `scripts/knowledge/create-entry.sh` — entry creation
- `scripts/knowledge/update-entry.sh` — entry updates
- `scripts/knowledge/promote-entry.sh` — confidence promotion
- `scripts/knowledge/archive-entry.sh` — archiving
- `scripts/knowledge/supersede-entry.sh` — supersession
- `scripts/knowledge/compute-staleness.sh` — staleness calculation
- `scripts/knowledge/lib/staleness.sh` — staleness library
- `scripts/knowledge/traverse-graph.sh` — graph traversal
- `scripts/knowledge/detect-overlap.sh` — overlap detection
- `scripts/knowledge/resolve-entries.sh` — entry resolution
- `scripts/knowledge/consolidate-artifacts.sh` — consolidation
- `scripts/knowledge/rebuild-index.sh` — index rebuilding
- `scripts/knowledge/append-decision.sh` — decision logging
- `scripts/knowledge/append-knowledge.sh` — knowledge logging
- `scripts/knowledge/increment-hits.sh` — hit counter
- `scripts/knowledge/update-confidence.sh` — confidence updates
- `scripts/knowledge/write-summary.sh` — summary generation
- `scripts/dispatch/scope-filter.sh` — scope-based filtering
- `references/file-formats.md` — knowledge entry frontmatter schema (1105 lines)
- `references/architecture.md` — knowledge subsystem context (378 lines)
- `.specify/orchestrator/KNOWLEDGE.md` — real knowledge index example
- `commands/consolidate.md` — consolidate command flow

## Constraints

- **DC-1**: Progressive disclosure format — `## Overview` immediately after title,
  `##`/`###` structure, ASCII diagrams OK, no inline HTML.
- **DC-2**: Audience label: `users`.
- **DC-3**: All cross-links use relative paths from `docs/` directory.
- **DC-4**: Verify-as-you-write — every script path, argument, and behavior claim
  confirmed by reading the actual script.
- **DC-5**: Any bug fix commit messages reference `docs/knowledge-management.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.

## Expected Output

After completing this task:

1. `docs/knowledge-management.md` exists with 150+ lines.
2. A user can follow the guide to create, manage, and consolidate knowledge entries.
3. All script paths mentioned exist on disk.
4. All YAML field names match the actual schema.
5. All cross-links resolve to existing files.
6. If any code bugs were found and fixed, each fix is committed with a message
   referencing `(found via docs/knowledge-management.md)`.
