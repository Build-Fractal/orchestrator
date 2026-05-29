# Knowledge Management Guide

**The orchestrator turns lessons learned into a scoped, decaying knowledge graph so each fresh context window starts smart instead of blank.**

**TL;DR.** Knowledge lives in two layers and one register. Use the quick **append-only file** (`.orchestrator/KNOWLEDGE.md`) for in-the-moment notes during execution; use **detail files** (`knowledge/{category}/{id}.md`) for durable entries that need confidence tracking, hit counts, staleness decay, and graph links. The mental model is a **hot / warm / cold graph plus an append-only register**: hot entries are freshly verified and high-hit, warm entries live in `knowledge/`, cold entries are archived but preserved for audit. Everything is filtered by **scope tag** so a dispatched task only ever sees the knowledge relevant to its milestone and phase. This guide is the deep reference for creating, maintaining, decaying, and consolidating those entries.

> This implements Constitution Principle 7, **Knowledge Compounds** (see [Constitution](../.orchestrator/memory/constitution.md)). Audience: users operating an orchestrator-managed project.

---

## Prerequisites / assumes you know

This is a reference guide, not an intro. Before reading, you should have a project initialized and at least one milestone underway — see [Getting Started](./getting-started.md) for install and your first milestone.

Terms used throughout, glossed once here:

- **Scope tag** — a label that bounds where an entry applies: `project`, `milestone:M###`, or `phase:M###/P##`. Canonical format defined in [Scope Tags](#scope-tags).
- **MEM** — the `MEM###` identifier scheme for detail-file entries (e.g. `MEM001`).
- **Milestone / phase / task structure** — work is organized as milestone `M###` → phases `P##` → tasks `T##`. Scope tags and `source_unit` reference these.
- **Knowledge injection** — the dispatch-time step that filters knowledge by scope and feeds only the relevant subset into a task's context.

---

## Section index

- [The two layers — and when to use each](#the-two-layers--and-when-to-use-each)
- [Anatomy: detail files](#anatomy-detail-files)
- [Anatomy: the append-only register](#anatomy-the-append-only-register)
- [Scope tags](#scope-tags)
- [Creating entries](#creating-entries)
- [Worked example: create, verify, and maintain one entry](#worked-example-create-verify-and-maintain-one-entry)
- [Lifecycle operations](#lifecycle-operations)
- [Staleness & decay](#staleness--decay)
- [Graph relationships & traversal](#graph-relationships--traversal)
- [Scope filtering (knowledge injection)](#scope-filtering-knowledge-injection)
- [Overlap detection](#overlap-detection)
- [Consolidation workflow](#consolidation-workflow)
- [Rebuilding the index](#rebuilding-the-index)
- [Next / See also](#next--see-also)

> All commands below assume you run them from your project root — the directory where both `scripts/` and `.orchestrator/` are present. To confirm you're there, run `ls -d scripts .orchestrator`; if both list without error, you're in the right place. If they don't, `cd` to the directory that contains them (or, inside a dispatched task whose working directory differs, prefix the relative paths with the resolved root from `scripts/state/resolve-root.sh`). If you installed via the bundle, these scripts ship with it (see [Getting Started](./getting-started.md)).

---

## The two layers — and when to use each

Knowledge is stored in two layers plus a separate decisions register. Pick the layer by how durable and how structured the entry needs to be.

| Layer | File / location | Use it when… | Supports |
|-------|-----------------|--------------|----------|
| **Append-only register** | `.orchestrator/KNOWLEDGE.md` | You want a fast, low-ceremony note *during* execution — a gotcha, a rule, a one-liner you don't want to lose. This is the **inbox**: cheap to write, but it never gains confidence, decay, or graph links. | Scope tag + date only. No confidence, no decay. Filtered directly by scope at dispatch. |
| **Detail file** | `knowledge/{category}/{id}.md` | The entry is durable and should compound — a pattern, decision, or constraint future tasks will rely on. This is the **durable layer**: anything you want a future fresh context to lean on belongs here. | Confidence, hit counts, staleness decay, graph links (`relates_to`), supersession, overlap detection. Indexed in `KNOWLEDGE-INDEX.md`. |
| **Decisions register** | `.orchestrator/DECISIONS.md` | You're recording an architectural decision with rationale and scope. | Scope + decision type; filtered at dispatch via `--type decisions` (see [Scope filtering](#scope-filtering-knowledge-injection)). |

**Which one for a real task?** If you're mid-execution and just want to jot a gotcha so you don't lose it, append to `KNOWLEDGE.md`. If the lesson is something future tasks should *rely on* — a pattern, constraint, or decision — author it as a detail file with `create-entry.sh`, because only detail files carry confidence, decay, and graph links. The two are independent stores, not stages of one pipeline: writing an append note does **not** create a detail file, and there is no command that converts an append line into a detail entry. When an append note proves durable, re-author it as a detail file with `create-entry.sh` (the append line can stay as the inbox record). See the [worked example](#worked-example-create-verify-and-maintain-one-entry) below for the full happy path.

Both knowledge layers are indexed. Detail files are tracked in `KNOWLEDGE-INDEX.md` at the project root (a generated, rebuildable artifact). The append-only file is filtered directly by scope tags at dispatch — no separate index.

---

## Anatomy: detail files

Durable entries under `knowledge/{category}/{id}.md` use YAML frontmatter followed by a markdown body:

```markdown
---
id: MEM001
scope_tags: "[project], [milestone:M001]"
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

### Frontmatter fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier in `MEM###` format (auto-assigned if omitted) |
| `scope_tags` | string | Bracketed scope value(s), e.g. `"[project]"` or `"[project], [milestone:M001]"`; multiple scopes are comma-separated inside the quoted string (see [Scope tags](#scope-tags)) |
| `category` | string | Category name (e.g. `patterns`, `decisions`, `constraints`) |
| `confidence` | float | Raw confidence score, 0.0 to 1.0 |
| `created_at` | date | ISO 8601 creation date |
| `last_verified` | date | Date the entry was last confirmed accurate (resets the staleness clock) |
| `hit_count` | integer | Times this entry was referenced or used |
| `source_unit` | string | The milestone/phase/task that produced this entry |
| `source_type` | string | How it was generated: `execution`, `review`, or `manual` |
| `supersedes` | string | ID of the entry this one replaces (empty if none) |
| `superseded_by` | string | ID of the entry that replaced this one (empty if active) |
| `relates_to` | list | YAML inline list of related entry IDs |

### ID scheme

Entry IDs follow the `MEM###` pattern (e.g. `MEM001`, `MEM042`). IDs are auto-generated sequentially by scanning both the index file and the `knowledge/` directory for the highest existing number.

### KNOWLEDGE-INDEX.md

A pipe-delimited flat file at the project root, regenerable at any time:

```
# Knowledge Index
<!-- Generated artifact -- rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
MEM001 | [project], [milestone:M001] | patterns | 0.90 | 2026-03-19 | verified:2026-03-19 | hits:3 | File-presence state derivation
MEM002 | [project] | constraints | 0.95 | 2026-03-20 | verified:2026-04-01 | hits:7 | Bash 3.2 compatibility required
```

The index excludes archived and superseded entries. Rebuild it any time with [`rebuild-index.sh`](#rebuilding-the-index).

---

## Anatomy: the append-only register

Entries in `.orchestrator/KNOWLEDGE.md` are a single line each:

```markdown
- **[<scope>]** [<date>] Description of the pattern, rule, or lesson learned.
```

Examples:

```markdown
- **[project]** [2026-03-19] All state scripts must handle missing .orchestrator/ dir
- **[milestone:M001]** [2026-03-20] Phase verification requires all tasks to have summaries
- **[phase:M001/P02]** [2026-03-21] Bash 3.2 does not support associative arrays
```

The scope appears **bracketed and bolded** here as the on-disk syntax for this file. You pass `append-knowledge.sh` the **bare** scope (`milestone:M001`) and the script wraps it as `**[milestone:M001]**`. Note that detail-file frontmatter and the index store the **bracketed** form directly (`[milestone:M001]`) — see [Scope tags](#scope-tags) for exactly how each surface writes a scope.

---

## Scope tags

There is **one** scope-tag vocabulary across the whole subsystem. Only the rendering differs by file.

| Scope value (canonical) | Means | Applies to |
|-------------------------|-------|------------|
| `project` | Project-wide | Everywhere |
| `milestone:M###` | A single milestone | All phases within that milestone |
| `phase:M###/P##` | A single phase | Only that phase (unless pulled in via `--depends`) |

How the same value is written in each place:

| Where | Notation | Example |
|-------|----------|---------|
| `KNOWLEDGE.md` line | bolded + bracketed | `- **[milestone:M001]** [date] …` |
| Detail-file `scope_tags` frontmatter | bracketed, quoted (comma-separated for multiple) | `scope_tags: "[project], [milestone:M001]"` |
| `KNOWLEDGE-INDEX.md` column | bracketed | `… | [milestone:M001] | …` |
| `append-knowledge.sh` 3rd argument | **bare** (the script adds the brackets) | `"milestone:M001"` |

The only place you pass a **bare** scope is the `append-knowledge.sh` argument — the script wraps it in brackets when it writes the line. Everywhere a scope is *stored on disk* (the `KNOWLEDGE.md` line, detail-file `scope_tags`, and the `KNOWLEDGE-INDEX.md` column) it is written **bracketed**, and the brackets are part of the stored value. Detail files may carry more than one bracketed scope in a single quoted string, comma-separated (e.g. `"[project], [milestone:M001]"`). The scope values form an implicit hierarchy — broader scopes are included when filtering for a narrower one (see [Scope filtering](#scope-filtering-knowledge-injection)).

---

## Creating entries

### Append to KNOWLEDGE.md (quick capture)

Use `append-knowledge.sh` for lightweight capture during execution:

```bash
bash scripts/knowledge/append-knowledge.sh \
  .orchestrator/KNOWLEDGE.md \
  "All state scripts must handle missing .orchestrator/ dir" \
  "milestone:M001"
```

| Argument | Value |
|----------|-------|
| 1 | Path to the KNOWLEDGE.md file (must already exist) |
| 2 | Entry text |
| 3 | Scope tag — bare form: `project`, `milestone:M###`, or `phase:M###/P##` |

It appends one line with the scope and today's date, never modifying existing lines (append-only). Output: `KNOWLEDGE: entry appended with scope [<scope>]`.

### Create a detail-file entry (durable)

Use `create-entry.sh` for structured entries with confidence and relationships:

```bash
bash scripts/knowledge/create-entry.sh \
  --category patterns \
  --scope-tags "[project], [milestone:M001]" \
  --source-unit "M001/P01/T01" \
  --description "File-presence state derivation is more crash-safe" \
  --body "Deriving state from which files exist on disk..." \
  --confidence 0.90 \
  --relates-to "MEM003,MEM007"
```

| | Flags |
|---|-------|
| **Required** | `--category`, `--scope-tags`, `--source-unit`, `--description`, `--body` |
| **Optional** | `--id` (auto-generated if omitted), `--confidence` (default `0.90`), `--source-type` (default `execution`), `--supersedes`, `--relates-to` (comma-separated IDs) |

Pass `--scope-tags` in the **bracketed** form (`"[project]"`, or comma-separated `"[project], [milestone:M001]"`); the value is stored verbatim into the `scope_tags` frontmatter and the index, so it must match the bracketed on-disk convention (see [Scope tags](#scope-tags)).

It writes `knowledge/{category}/{id}.md` with frontmatter and atomically updates `KNOWLEDGE-INDEX.md`. Idempotent: if the detail file already exists it prints `EXISTS` and exits cleanly.

### When entries get created

- After task execution, when a pattern or constraint surfaces.
- During verification, when a behavioral review yields a lesson.
- During [consolidation](#consolidation-workflow), when cross-phase patterns emerge.
- Manually, to record a decision rationale.

---

## Worked example: create, verify, and maintain one entry

A complete happy-path, from a throwaway note to a durable, indexed entry. Run each step from your project root.

**1. Jot a quick note during execution.** You hit a gotcha mid-task and don't want to lose it:

```bash
bash scripts/knowledge/append-knowledge.sh \
  .orchestrator/KNOWLEDGE.md \
  "Bash 3.2 does not support associative arrays" \
  "milestone:M001"
# → KNOWLEDGE: entry appended with scope [milestone:M001]
```

The note now lives as one bracketed line in `.orchestrator/KNOWLEDGE.md`. Nothing else happened — no detail file, no index row.

**2. Examine what you just wrote.** Confirm the line landed with the bracketed scope:

```bash
tail -n 1 .orchestrator/KNOWLEDGE.md
# → - **[milestone:M001]** [<today>] Bash 3.2 does not support associative arrays
```

**3. Promote it into the durable layer by authoring a detail file.** The note proves it will be reused, so re-author it with `create-entry.sh` (this is a fresh authoring step, not an automatic conversion of the append line):

```bash
bash scripts/knowledge/create-entry.sh \
  --category constraints \
  --scope-tags "[project], [milestone:M001]" \
  --source-unit "M001/P02/T01" \
  --description "Bash 3.2 has no associative arrays" \
  --body "Target Bash 3.2 for portability; use parallel indexed arrays or temp files instead of declare -A." \
  --confidence 0.95
# → CREATED: MEM001 at knowledge/constraints/MEM001.md
```

This writes `knowledge/constraints/MEM001.md` and adds a row to `KNOWLEDGE-INDEX.md` atomically.

**4. Update it later.** When you re-confirm the constraint still holds, reset its staleness clock and bump confidence:

```bash
bash scripts/knowledge/update-entry.sh --id MEM001 --last-verified now --confidence 0.98
```

**5. Verify it appears in the index.** Confirm the durable entry is tracked, with the bracketed scope and updated metadata:

```bash
grep '^MEM001 ' KNOWLEDGE-INDEX.md
# → MEM001 | [project], [milestone:M001] | constraints | 0.98 | <created> | verified:<today> | hits:0 | Bash 3.2 has no associative arrays
```

From here the entry participates in scope filtering, staleness decay, graph traversal, and consolidation like any other detail file. The individual operations are detailed in the sections below.

---

## Lifecycle operations

Each detail file moves through create → update → (supersede | archive ↔ promote). All operations update both the detail file and `KNOWLEDGE-INDEX.md` atomically and are idempotent.

| Operation | Script | What it does |
|-----------|--------|--------------|
| Update metadata | `update-entry.sh` | Change confidence, `last_verified`, or hit count without touching the body |
| Promote | `promote-entry.sh` | Move an entry from cold (archive) back to warm storage |
| Archive | `archive-entry.sh` | Move warm → cold; preserves file for audit |
| Supersede | `supersede-entry.sh` | Mark an old entry replaced by a newer one |

### Update (`update-entry.sh`)

```bash
# Update confidence after re-verification
bash scripts/knowledge/update-entry.sh --id MEM001 --confidence 0.95

# Mark as recently verified (resets staleness clock to today)
bash scripts/knowledge/update-entry.sh --id MEM001 --last-verified now

# Set an explicit hit count
bash scripts/knowledge/update-entry.sh --id MEM001 --hit-count 5

# Increment the hit counter
bash scripts/knowledge/update-entry.sh --id MEM001 --increment-hits
```

At least one field must be specified. `--last-verified now` uses today's date.

**Convenience wrappers:**

- `increment-hits.sh --id MEM001` — thin wrapper around `update-entry.sh --increment-hits`
- `update-confidence.sh --id MEM001 --confidence 0.85` — thin wrapper around `update-entry.sh`

### Promote (`promote-entry.sh`)

```bash
bash scripts/knowledge/promote-entry.sh --id MEM001

# Optionally override confidence and category on promotion
bash scripts/knowledge/promote-entry.sh --id MEM001 --confidence 0.80 --category patterns
```

Moves the file from `knowledge/archive/{id}.md` back to `knowledge/{category}/{id}.md`, resets `last_verified` to today, clears `superseded_by`, and re-adds the row to the index. Default confidence on promotion is `0.80`. If the entry is not in archive, prints `NOT_ARCHIVED`.

### Archive (`archive-entry.sh`)

```bash
bash scripts/knowledge/archive-entry.sh --id MEM001
```

Moves `knowledge/{category}/{id}.md` → `knowledge/archive/{id}.md` and removes the index row. The file is preserved for audit; empty category dirs are cleaned up. If already archived, prints `ALREADY_ARCHIVED`.

### Supersede (`supersede-entry.sh`)

```bash
bash scripts/knowledge/supersede-entry.sh --old-id MEM001 --new-id MEM042
```

1. Sets `superseded_by: MEM042` on the old entry.
2. Sets `supersedes: MEM001` on the new entry.
3. Removes the old entry from the index.

The old file stays in place (not archived) to preserve the audit trail. If already superseded by the same new ID, prints `ALREADY_SUPERSEDED`.

---

## Staleness & decay

**Why decay at all?** Knowledge that was true six months ago may quietly be wrong today, and a fresh context window can't tell. Rather than trust an entry forever, the orchestrator lets unverified entries lose confidence over time — so stale advice fades instead of misleading future tasks. Three deliberate choices shape the formula:

- **Why protect high-hit entries.** An entry referenced often is load-bearing; auto-archiving it because the clock ran out would silently drop something the project actively relies on. So archival is gated on a hit-count floor, never on staleness alone.
- **Why 180 days.** A two-quarter horizon is long enough that genuinely stable patterns survive a normal review cadence, but short enough that abandoned notes decay within a release cycle or two.
- **Why a 0.5 floor.** Decay should *discount* an entry, not erase it. Flooring the decay factor at 0.5 means an entry can fall to at most half its raw confidence — enough to deprioritize it, never enough to make it vanish without a human or a re-verification deciding so.

The formula (from `scripts/knowledge/lib/staleness.sh`):

```
effective_confidence = confidence * max(0.5, 1.0 - (days_since_verified / 180))
```

**Example.** An entry with raw confidence `0.90`, last verified 90 days ago:
`0.90 * max(0.5, 1.0 - 90/180) = 0.90 * max(0.5, 0.5) = 0.90 * 0.5 = 0.45`.

### Staleness report

Use `compute-staleness.sh` to see decay across all entries:

```bash
# Report only -- no modifications
bash scripts/knowledge/compute-staleness.sh

# Report and show what would be archived (dry run)
bash scripts/knowledge/compute-staleness.sh --archive-below 0.50 --dry-run

# Auto-archive entries below 0.50 effective confidence AND fewer than 10 hits
bash scripts/knowledge/compute-staleness.sh --archive-below 0.50 --min-hits 10
```

The report lists each entry with raw confidence, effective (decayed) confidence, days since verification, hit count, and description. With `--archive-below`, entries whose effective confidence is below the threshold **and** whose hit count is below `--min-hits` (default 10) are auto-archived. High-hit entries are protected regardless of staleness.

### Refresh an entry's staleness clock

Re-verify it:

```bash
bash scripts/knowledge/update-entry.sh --id MEM001 --last-verified now
```

---

## Graph relationships & traversal

**Why you'd want this.** A single lesson rarely stands alone — a constraint usually relates to the pattern that motivated it and the decision that resolved it. When a task is about to touch one entry, you want the *neighborhood* of related knowledge, not just the one node you happened to name. Graph traversal walks `relates_to` links so dispatch can pull in the connected context a task actually needs, bounded by depth and count so it never floods the payload.

### Traverse the graph (`traverse-graph.sh`)

```bash
# Find entries related to MEM042 (1 hop, max 5 results)
bash scripts/knowledge/traverse-graph.sh --id MEM042

# Traverse up to 3 hops deep, returning up to 10 entries
bash scripts/knowledge/traverse-graph.sh --id MEM042 --max-depth 3 --max-entries 10
```

Uses breadth-first search (BFS) with cycle detection, emitting one related entry ID per line to stdout. The starting entry is excluded; archived entries are not followed (warm storage only).

| Flag | Default | Description |
|------|---------|-------------|
| `--id` | required | Starting entry ID |
| `--max-depth` | 1 | Maximum BFS depth (hops from the start) |
| `--max-entries` | 5 | Maximum related entries to return |

If `--max-entries` is reached before all reachable entries are visited, `WARNING: max-entries limit reached` is emitted to stderr.

### Resolve entry content (`resolve-entries.sh`)

After traversal, read the full content of the related entries:

```bash
# Resolve by arguments
bash scripts/knowledge/resolve-entries.sh MEM042 MEM015

# Resolve from stdin (piped from traverse-graph.sh)
bash scripts/knowledge/traverse-graph.sh --id MEM042 | bash scripts/knowledge/resolve-entries.sh
```

Outputs the full markdown of each resolved entry, separated by blank lines. Unresolved IDs warn to stderr; archived entries are excluded.

### Relationship types

| Field(s) | Captures |
|----------|----------|
| `relates_to` | **Peer** links — entries that share a topic, reinforce each other, or are facets of one constraint |
| `supersedes` / `superseded_by` | **Replacement** — one entry obsoletes another |

---

## Scope filtering (knowledge injection)

This is the step that makes the graph usable at dispatch time: instead of dumping all knowledge into a task, `scope-filter.sh` (in `scripts/dispatch/`) injects only the entries relevant to the current execution scope, keeping payloads bounded (Constitution Principle 1, Context Minimization).

```bash
# Filter KNOWLEDGE.md for phase P02 of milestone M001
bash scripts/dispatch/scope-filter.sh \
  .orchestrator/KNOWLEDGE.md \
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

### Inclusion rules

An entry is included if its scope matches the current context (here, filtering for `M001/P02`):

| Entry scope | Included? |
|-------------|-----------|
| `project` | Yes — project-scoped entries always pass |
| `milestone:M001` | Yes — same milestone |
| `milestone:M002` | No — different milestone |
| `phase:M001/P02` | Yes — exact match |
| `phase:M001/P01` | Only if P01 is listed in `--depends` |
| `phase:M001/P03` | No — different phase, not a dependency |

### Index vs. flat-file filtering

The filter auto-detects whether the input is the pipe-delimited index (`KNOWLEDGE-INDEX.md`) or a flat markdown file (`KNOWLEDGE.md`) by filename and content. Index files support extra filters:

| Flag | Effect |
|------|--------|
| `--min-confidence` | Exclude entries below a confidence threshold |
| `--use-effective-confidence` | Apply staleness decay before the confidence comparison |
| `--category` | Include only entries of a given category |

### Filtering decisions

The same script filters `.orchestrator/DECISIONS.md` via `--type decisions`. Decision rows are included when they belong to the current milestone **and** either have architectural scope or belong to the current phase or an upstream dependency.

---

## Overlap detection

Use `detect-overlap.sh` to find near-duplicate entries within the same category — candidates for supersession or consolidation:

```bash
# Default 70% Jaccard similarity threshold
bash scripts/knowledge/detect-overlap.sh

# Custom threshold
bash scripts/knowledge/detect-overlap.sh --threshold 0.80
```

It computes word-level Jaccard similarity for each pair within a category and flags pairs above the threshold for review.

---

## Consolidation workflow

### When and how often to run it

Run consolidation **once per milestone, as the last step in the milestone lifecycle** — after every phase summary is written and the milestone summary itself exists. It is not a periodic cron job; it is a milestone-boundary ritual. It compresses verbose per-task artifacts while preserving the durable knowledge, hitting a target of **≥60% footprint reduction** (per SC-011). Typical triggers:

- A milestone has just been verified complete.
- You want to reclaim space and surface stale/overlapping knowledge before starting the next milestone.

### Run it (`consolidate-artifacts.sh`)

```bash
bash scripts/knowledge/consolidate-artifacts.sh \
  .orchestrator \
  M001
```

| Argument | Value |
|----------|-------|
| 1 | Path to the orchestrator root (`.orchestrator`) |
| 2 | Milestone ID (e.g. `M001`) |

### Preconditions

All phases must be complete — each phase directory must contain a `P##-SUMMARY.md`. The script reads the milestone roadmap to discover phases and validates completeness before proceeding.

### What moves vs. what stays

| Archived to `{milestone}/archive/{phase}/` | Preserved in place |
|--------------------------------------------|--------------------|
| Task plans (`T##-PLAN.md`) | Phase summaries (`P##-SUMMARY.md`) |
| Task summaries (`T##-SUMMARY.md`) | Milestone summary, roadmap |
| Phase plans (`P##-PLAN.md`) | `DECISIONS.md`, `KNOWLEDGE.md` |

### Advisory checks (non-blocking)

During consolidation the script runs two informational checks that never block the run:

1. **Overlap detection** — calls [`detect-overlap.sh`](#overlap-detection) to flag high-similarity entries.
2. **Staleness report** — calls [`compute-staleness.sh`](#staleness--decay) to show decayed entries.

### Output

Reports bytes before/after and the reduction percentage to stderr; stdout receives a structured `CONSOLIDATE:` message.

---

## Rebuilding the index

If `KNOWLEDGE-INDEX.md` drifts from the detail files (e.g. after manual edits), regenerate it:

```bash
bash scripts/knowledge/rebuild-index.sh
```

The script scans all files in `knowledge/*/` (excluding `knowledge/archive/`), extracts frontmatter from each `MEM###.md`, skips superseded entries, sorts by ID, and writes the full index atomically (temp-file-then-rename, to prevent corruption).

---

## Next / See also

- **[Getting Started](./getting-started.md)** — install and run your first milestone; the prerequisite for everything on this page.
- **[Hook Development Guide](./hook-development.md)** — write lifecycle hooks that read or update knowledge (e.g. auto-incrementing hits, gating on confidence) at dispatch and verify boundaries.
- **[Architecture Reference](../references/architecture.md)** — where the knowledge subsystem sits in the dispatch → verify → consolidate pipeline.
- **[File Formats Reference](../references/file-formats.md)** — the canonical on-disk schemas for `KNOWLEDGE.md`, `KNOWLEDGE-INDEX.md`, and `DECISIONS.md` referenced throughout this guide.
- **[Constitution](../.orchestrator/memory/constitution.md)** — Principle 7 (Knowledge Compounds) is the *why* behind this entire subsystem; Principle 1 (Context Minimization) is why scope filtering exists.
