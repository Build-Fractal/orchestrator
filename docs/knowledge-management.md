# Knowledge Management Guide

> User guide for the orchestrator's knowledge compounding system.
> Self-contained — learn how to create, manage, and consolidate knowledge entries across milestones.

> Audience: users

## Overview

The knowledge management subsystem implements Constitution Principle 7: **Knowledge Compounds**. Every task the orchestrator executes can produce lessons, patterns, and decisions. Without a system to capture and surface them, each new context window starts from scratch. The knowledge subsystem solves this by providing a structured way to record what was learned, track how confident you are in each entry, decay entries that go unverified, and filter entries by scope so that dispatched tasks only receive relevant knowledge.

Knowledge lives in two layers:

1. **KNOWLEDGE.md** -- an append-only markdown file at `.specify/orchestrator/KNOWLEDGE.md` with scope-tagged entries. This is the lightweight, quick-append layer used during execution.
2. **Knowledge detail files** -- structured markdown files with YAML frontmatter stored under `knowledge/{category}/{id}.md`. These support confidence tracking, hit counting, staleness decay, graph relationships, and overlap detection.

Both layers are indexed. The detail files are tracked in `KNOWLEDGE-INDEX.md` at the project root. The append-only file is filtered directly by scope tags during dispatch.

---

## Knowledge Entry Anatomy

### Append-Only Entries (KNOWLEDGE.md)

Entries in `.specify/orchestrator/KNOWLEDGE.md` follow a simple format:

```markdown
- **[scope]** [date] Description of the pattern, rule, or lesson learned.
```

For example:

```markdown
- **[project]** [2026-03-19] All state scripts must handle missing .specify/orchestrator/ dir
- **[milestone:M001]** [2026-03-20] Phase verification requires all tasks to have summaries
- **[phase:M001/P02]** [2026-03-21] Bash 3.2 does not support associative arrays
```

### Detail File Entries (knowledge/{category}/{id}.md)

Detail files use YAML frontmatter followed by a markdown body:

```markdown
---
id: MEM001
scope_tags: "milestone:M001"
category: patterns
confidence: 0.90
created_at: 2026-03-19
last_verified: 2026-03-19
hit_count: 0
source_unit: "M001/P01/T01"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: [MEM003, MEM007]
---

# MEM001: File-presence state derivation is more crash-safe than status fields

Body text describing the pattern, with examples and rationale.
```

### Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier in `MEM###` format (auto-assigned if omitted) |
| `scope_tags` | string | Scope tag: `project`, `milestone:M###`, or `phase:M###/P##` |
| `category` | string | Category name (e.g., `patterns`, `decisions`, `constraints`) |
| `confidence` | float | Raw confidence score, 0.0 to 1.0 |
| `created_at` | date | ISO 8601 creation date |
| `last_verified` | date | Date the entry was last confirmed as still accurate |
| `hit_count` | integer | Number of times this entry was referenced or used |
| `source_unit` | string | The milestone/phase/task that produced this entry |
| `source_type` | string | How the entry was generated: `execution`, `review`, `manual` |
| `supersedes` | string | ID of the entry this one replaces (empty if none) |
| `superseded_by` | string | ID of the entry that replaced this one (empty if active) |
| `relates_to` | list | YAML inline list of related entry IDs |

### ID Scheme

Entry IDs follow the `MEM###` pattern (e.g., `MEM001`, `MEM042`). IDs are auto-generated sequentially by scanning both the index file and the `knowledge/` directory for the highest existing number.

### KNOWLEDGE-INDEX.md

The index file is a pipe-delimited flat file at the project root:

```
# Knowledge Index
<!-- Generated artifact -- rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
MEM001 | milestone:M001 | patterns | 0.90 | 2026-03-19 | verified:2026-03-19 | hits:3 | File-presence state derivation
MEM002 | project | constraints | 0.95 | 2026-03-20 | verified:2026-04-01 | hits:7 | Bash 3.2 compatibility required
```

The index excludes archived and superseded entries. It can be fully regenerated from detail files at any time using `rebuild-index.sh`.

---

## Creating Entries

### Appending to KNOWLEDGE.md

Use `append-knowledge.sh` for quick, lightweight knowledge capture during execution:

```bash
bash scripts/knowledge/append-knowledge.sh \
  .specify/orchestrator/KNOWLEDGE.md \
  "All state scripts must handle missing .specify/orchestrator/ dir" \
  "milestone:M001"
```

**Arguments:**

1. Path to the KNOWLEDGE.md file (must already exist)
2. The entry text to record
3. Scope tag: `project`, `milestone:M###`, or `phase:M###/P##`

The script appends a new line with the scope tag and today's date. It never modifies existing entries (append-only). Output: `KNOWLEDGE: entry appended with scope [<scope>]`.

### Creating Detail File Entries

Use `create-entry.sh` for structured entries that support confidence tracking and relationships:

```bash
bash scripts/knowledge/create-entry.sh \
  --category patterns \
  --scope-tags "milestone:M001" \
  --source-unit "M001/P01/T01" \
  --description "File-presence state derivation is more crash-safe" \
  --body "Deriving state from which files exist on disk..." \
  --confidence 0.90 \
  --relates-to "MEM003,MEM007"
```

**Required flags:** `--category`, `--scope-tags`, `--source-unit`, `--description`, `--body`

**Optional flags:** `--id` (auto-generated if omitted), `--confidence` (default 0.90), `--source-type` (default `execution`), `--supersedes`, `--relates-to` (comma-separated IDs)

The script creates `knowledge/{category}/{id}.md` with YAML frontmatter and atomically updates `KNOWLEDGE-INDEX.md`. It is idempotent: if the detail file already exists, it prints `EXISTS` and exits cleanly.

### When Entries Are Created

Knowledge entries are typically created:

- After task execution, when a pattern or constraint is discovered
- During verification, when a behavioral review surfaces a lesson
- During consolidation, when cross-phase patterns emerge
- Manually, when a developer wants to record a decision rationale

---

## Lifecycle Operations

### Update (update-entry.sh)

Modify metadata on an existing entry without changing its body content:

```bash
# Update confidence after re-verification
bash scripts/knowledge/update-entry.sh --id MEM001 --confidence 0.95

# Mark as recently verified
bash scripts/knowledge/update-entry.sh --id MEM001 --last-verified now

# Set an explicit hit count
bash scripts/knowledge/update-entry.sh --id MEM001 --hit-count 5

# Increment the hit counter
bash scripts/knowledge/update-entry.sh --id MEM001 --increment-hits
```

Updates both the detail file's YAML frontmatter and the corresponding `KNOWLEDGE-INDEX.md` row atomically. At least one field must be specified. The `--last-verified now` shorthand uses today's date.

**Convenience wrappers:**

- `increment-hits.sh --id MEM001` -- thin wrapper around `update-entry.sh --increment-hits`
- `update-confidence.sh --id MEM001 --confidence 0.85` -- thin wrapper around `update-entry.sh`

### Promote (promote-entry.sh)

Move an entry from cold storage (archive) back to warm storage:

```bash
bash scripts/knowledge/promote-entry.sh --id MEM001

# Optionally override confidence and category on promotion
bash scripts/knowledge/promote-entry.sh --id MEM001 --confidence 0.80 --category patterns
```

Promotion moves the file from `knowledge/archive/{id}.md` back to `knowledge/{category}/{id}.md`, resets `last_verified` to today, clears `superseded_by`, and re-adds the entry to `KNOWLEDGE-INDEX.md`. Default confidence on promotion is 0.80. Idempotent: if the entry is not in archive, prints `NOT_ARCHIVED` and exits cleanly.

### Archive (archive-entry.sh)

Move an entry from warm to cold storage:

```bash
bash scripts/knowledge/archive-entry.sh --id MEM001
```

Moves the file from `knowledge/{category}/{id}.md` to `knowledge/archive/{id}.md` and removes the entry from `KNOWLEDGE-INDEX.md`. The detail file is preserved for audit trail. Empty category directories are cleaned up automatically. Idempotent: if already archived, prints `ALREADY_ARCHIVED`.

### Supersede (supersede-entry.sh)

Mark an old entry as replaced by a newer, more accurate entry:

```bash
bash scripts/knowledge/supersede-entry.sh --old-id MEM001 --new-id MEM042
```

This operation:

1. Sets `superseded_by: MEM042` on the old entry's frontmatter
2. Sets `supersedes: MEM001` on the new entry's frontmatter
3. Removes the old entry from `KNOWLEDGE-INDEX.md`

The old detail file stays in place (not moved to archive) to preserve the audit trail. Idempotent: if already superseded by the same new ID, prints `ALREADY_SUPERSEDED`.

---

## Staleness

### How Staleness Works

Knowledge entries decay in confidence over time if they are not re-verified. The staleness formula (from `lib/staleness.sh`) is:

```
effective_confidence = confidence * max(0.5, 1.0 - (days_since_verified / 180))
```

- **180-day window**: an entry loses confidence linearly over 180 days from its last verification date.
- **0.5 floor**: the decay factor never drops below 0.5, so an entry's effective confidence can fall to at most half its raw confidence, never to zero.

For example, an entry with raw confidence 0.90 that was last verified 90 days ago has an effective confidence of `0.90 * max(0.5, 1.0 - 0.5) = 0.90 * 0.5 = 0.45`.

### Staleness Report

Use `compute-staleness.sh` to generate a report across all entries:

```bash
# Report only -- no modifications
bash scripts/knowledge/compute-staleness.sh

# Report and show what would be archived (dry run)
bash scripts/knowledge/compute-staleness.sh --archive-below 0.50 --dry-run

# Auto-archive entries with effective confidence below 0.50 and fewer than 10 hits
bash scripts/knowledge/compute-staleness.sh --archive-below 0.50 --min-hits 10
```

The report prints each entry with its raw confidence, effective (decayed) confidence, days since verification, hit count, and description. When `--archive-below` is specified, entries whose effective confidence is below the threshold AND whose hit count is below `--min-hits` (default 10) are auto-archived. High-hit entries are protected from automatic archival regardless of staleness.

### Refreshing Staleness

To reset an entry's staleness clock, re-verify it:

```bash
bash scripts/knowledge/update-entry.sh --id MEM001 --last-verified now
```

---

## Graph Relationships

### Traversing the Graph

Entries can reference each other through the `relates_to` frontmatter field. Use `traverse-graph.sh` to discover related entries:

```bash
# Find entries related to MEM042 (1 hop, max 5 results)
bash scripts/knowledge/traverse-graph.sh --id MEM042

# Traverse up to 3 hops deep, returning up to 10 entries
bash scripts/knowledge/traverse-graph.sh --id MEM042 --max-depth 3 --max-entries 10
```

The traversal uses breadth-first search (BFS) with cycle detection. It outputs one related entry ID per line to stdout. The starting entry is excluded from output. Archived entries are excluded from traversal (only warm-storage files are followed).

**Parameters:**

| Flag | Default | Description |
|------|---------|-------------|
| `--id` | required | Starting entry ID |
| `--max-depth` | 1 | Maximum BFS depth (hops from the starting entry) |
| `--max-entries` | 5 | Maximum number of related entries to return |

If the `--max-entries` limit is reached before all reachable entries are visited, a `WARNING: max-entries limit reached` message is emitted to stderr.

### Resolving Entry Content

After traversal, use `resolve-entries.sh` to read the full content of related entries:

```bash
# Resolve by arguments
bash scripts/knowledge/resolve-entries.sh MEM042 MEM015

# Resolve from stdin (e.g., piped from traverse-graph.sh)
bash scripts/knowledge/traverse-graph.sh --id MEM042 | bash scripts/knowledge/resolve-entries.sh
```

Outputs the full markdown content of each resolved entry, separated by blank lines. Unresolved IDs produce a warning to stderr. Archived entries are excluded.

### Relationship Types

The `relates_to` field captures peer relationships between entries -- entries that share a topic, reinforce each other, or represent different facets of the same constraint. The `supersedes` / `superseded_by` pair captures replacement relationships, where one entry obsoletes another.

### Scope Hierarchy

Scope tags create an implicit hierarchy:

- `project` -- applies everywhere
- `milestone:M001` -- applies to all phases within M001
- `phase:M001/P02` -- applies only to phase P02 of M001

Scope filtering (see next section) uses this hierarchy to include broader-scoped entries when filtering for a specific phase.

---

## Scope Filtering

### How Filtering Works

The `scope-filter.sh` script in `scripts/dispatch/` prevents unbounded knowledge injection into dispatch payloads. When the orchestrator builds context for a task, it filters knowledge and decision entries to include only those relevant to the current execution scope.

```bash
# Filter KNOWLEDGE.md for phase P02 of milestone M001
bash scripts/dispatch/scope-filter.sh \
  .specify/orchestrator/KNOWLEDGE.md \
  M001/P02

# Filter KNOWLEDGE-INDEX.md with dependency awareness
bash scripts/dispatch/scope-filter.sh \
  KNOWLEDGE-INDEX.md \
  M001/P03 \
  --depends P01,P02

# Filter with minimum confidence threshold and staleness decay
bash scripts/dispatch/scope-filter.sh \
  KNOWLEDGE-INDEX.md \
  M001/P02 \
  --min-confidence 0.70 \
  --use-effective-confidence

# Filter by category
bash scripts/dispatch/scope-filter.sh \
  KNOWLEDGE-INDEX.md \
  M001/P02 \
  --category patterns
```

### Inclusion Rules

An entry is included in filtered output if its scope tag matches the current context:

| Entry scope | Included when filtering for M001/P02? |
|-------------|---------------------------------------|
| `project` | Yes -- project-scoped entries always pass |
| `milestone:M001` | Yes -- same milestone |
| `milestone:M002` | No -- different milestone |
| `phase:M001/P02` | Yes -- exact match |
| `phase:M001/P01` | Only if P01 is listed in `--depends` |
| `phase:M001/P03` | No -- different phase, not a dependency |

### Index vs. Flat File Filtering

The filter auto-detects whether the input is a pipe-delimited index file (`KNOWLEDGE-INDEX.md`) or a flat markdown file (`KNOWLEDGE.md`) based on the filename and content. Index files support additional filters:

- `--min-confidence` -- exclude entries below a confidence threshold
- `--use-effective-confidence` -- apply staleness decay before confidence comparison
- `--category` -- include only entries matching a specific category

### Filtering Decisions

The same script also filters `DECISIONS.md` using `--type decisions`. Decision rows are included if they belong to the current milestone and either have architectural scope or belong to the current phase or an upstream dependency.

---

## Overlap Detection

Use `detect-overlap.sh` to find entries within the same category that have high content similarity:

```bash
# Default 70% Jaccard similarity threshold
bash scripts/knowledge/detect-overlap.sh

# Custom threshold
bash scripts/knowledge/detect-overlap.sh --threshold 0.80
```

The script computes word-level Jaccard similarity for each pair of entries within the same category. Pairs exceeding the threshold are flagged for review. This helps identify candidates for supersession or consolidation.

---

## Consolidation Workflow

### What Consolidation Does

After a milestone completes, `consolidate-artifacts.sh` reduces the footprint of milestone artifacts while preserving essential knowledge. The target is at least 60% size reduction.

```bash
bash scripts/knowledge/consolidate-artifacts.sh \
  .specify/orchestrator \
  M001
```

**Arguments:**

1. Path to the orchestrator root (`.specify/orchestrator`)
2. Milestone ID (e.g., `M001`)

### Preconditions

All phases must be complete (each phase directory must contain a `P##-SUMMARY.md` file). The script reads the milestone's roadmap to discover all phases and validates completeness before proceeding.

### What Gets Archived

For each phase, the following files are moved to `{milestone}/archive/{phase}/`:

- Task plans (`T##-PLAN.md`)
- Task summaries (`T##-SUMMARY.md`)
- Phase plans (`P##-PLAN.md`)

### What Gets Preserved

- Phase summaries (`P##-SUMMARY.md`)
- Milestone summary, roadmap, `DECISIONS.md`, `KNOWLEDGE.md`

### Advisory Checks

During consolidation, the script runs two advisory checks:

1. **Overlap detection** -- calls `detect-overlap.sh` to flag entries with high content similarity
2. **Staleness report** -- calls `compute-staleness.sh` to show which entries have decayed

These are informational only and do not block consolidation.

### Output

The script reports the size before and after consolidation, along with the reduction percentage, to stderr. Stdout receives a structured `CONSOLIDATE:` message.

### When to Run

Run consolidation after verifying that a milestone is fully complete and all phase summaries have been written. It is typically the last step in the milestone lifecycle, after the milestone summary itself is written.

---

## Rebuilding the Index

If the `KNOWLEDGE-INDEX.md` file becomes out of sync with the detail files (e.g., after manual edits), regenerate it:

```bash
bash scripts/knowledge/rebuild-index.sh
```

The script scans all files in `knowledge/*/` (excluding `knowledge/archive/`), extracts frontmatter fields from each `MEM###.md` file, skips superseded entries, sorts by ID, and writes the full index atomically. All index writes use a temp-file-then-rename pattern to prevent corruption.

---

## Cross-References

- [Getting Started](./getting-started.md) -- installation and first milestone walkthrough
- [Hook Development Guide](./hook-development.md) -- writing lifecycle hooks that interact with knowledge
- [Architecture Reference](../references/architecture.md) -- how the knowledge subsystem fits into the orchestrator pipeline
- [File Formats Reference](../references/file-formats.md) -- canonical format definitions for KNOWLEDGE.md, KNOWLEDGE-INDEX.md, and DECISIONS.md
- [Constitution](../.specify/memory/constitution.md) -- Principle 7 (Knowledge Compounds) governs this subsystem
