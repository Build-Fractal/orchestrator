---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P07"
milestone: "M003"
name: "Document Resolver + Graph Policy in commands/migrate.md"
depends_on: ["T01"]
---

## Prerequisites

- T01 has landed: `migrate.sh` resolves `$target_root` via `scripts/state/resolve-root.sh`.
- `commands/migrate.md` exists as the agent-facing command document for `speckit.orchestrator.migrate`. It currently does NOT mention AD-13, AD-14, or AD-15.
- The three architectural decisions are authoritatively captured in `.specify/orchestrator/milestones/M003/M003-CONTEXT.md` under the "Addendum — 2026-04-14 Refit (post-M007/M008)" header:
  - **AD-13: Target Root via 5-Rule Resolver** — migration writes to the resolver's output, not a hardcoded path. `--output` overrides the resolver.
  - **AD-14: Knowledge Graph Participation Policy** — migrated entries emit `relates_to: []`. `migrate.sh` calls `rebuild-index.sh` to build `KNOWLEDGE-INDEX.md` + `knowledge.db`. Semantic inference via `detect-overlap.sh` is a user-driven post-migration step.
  - **AD-15: Command Naming — Defer to Cohort** — command stays `speckit.orchestrator.migrate` until a coordinated cohort rename.

## Description

Add three short progressive-disclosure sections to `commands/migrate.md` that summarize AD-13, AD-14, and AD-15 and link readers to the authoritative full text in `M003-CONTEXT.md`. Each section is ≤15 lines so the command file stays scannable. The goal is that a future agent reading `commands/migrate.md` learns:

1. The migration target root is resolver-driven; do not hardcode `.specify/orchestrator/`.
2. Migrated `relates_to` is intentionally empty; running `detect-overlap.sh` post-migration is the documented enrichment path.
3. The command name `speckit.orchestrator.migrate` is intentional and not a renaming target in this milestone.

## Steps

### Step 1: Choose insertion point in `commands/migrate.md`

Open `commands/migrate.md`. The conventional orchestrator command file structure (MEM012) is:

```
YAML frontmatter
-> Title
-> Prerequisites / State Check
-> Core Workflow (numbered sections)
-> Output
-> Idempotency
-> Error Handling
-> Referenced Scripts/Templates
```

Insert the three new sections between the existing "Output" (or "Idempotency") section and "Error Handling" — they are reference / policy material rather than workflow steps.

### Step 2: Append the State Root Resolution section (AD-13)

```markdown
## State Root Resolution (AD-13)

`migrate.sh` writes to the path returned by `scripts/state/resolve-root.sh`,
honoring the M008 5-rule precedence chain (`ORCHESTRATOR_ROOT` env →
`config.yml state_root` → `.orchestrator/` → `.specify/orchestrator/` →
default `.orchestrator/`). The `--output <path>` flag overrides the
resolver for offline extraction runs.

No transform script may concatenate `.specify/orchestrator/` itself — every
output path is derived from the `target_root` argument passed in by
`migrate.sh`. See AD-13 in `.specify/orchestrator/milestones/M003/M003-CONTEXT.md`
for the full rationale.
```

### Step 3: Append the Knowledge Graph Participation section (AD-14)

```markdown
## Knowledge Graph Participation (AD-14)

Migrated knowledge entries emit `relates_to: []` during transform.
Migration's final step invokes `scripts/knowledge/rebuild-index.sh --root
<resolved>`, which regenerates `KNOWLEDGE-INDEX.md` and the M007 graph
database (`knowledge.db`). Supersession edges (`supersedes` /
`superseded_by`) ARE preserved from source and indexed by the rebuild.

Semantic relationships between migrated entries are NOT inferred during
migration. To populate `relates_to` based on content similarity, run
`bash scripts/knowledge/detect-overlap.sh` post-migration. This keeps
migration deterministic and lets users tune overlap thresholds against
their own data. See AD-14 in `M003-CONTEXT.md` for full rationale.
```

### Step 4: Append the Command Naming section (AD-15)

```markdown
## Command Naming (AD-15)

This command is registered in `extension.yml` as
`speckit.orchestrator.migrate`. M008 decoupled the orchestrator from
spec-kit as a runtime dependency but did NOT rename the command cohort.
The `speckit.orchestrator.*` namespace stays intact until a coordinated
cohort rename ships in a future milestone, tracked separately. Do not
rename this command in isolation — see AD-15 in `M003-CONTEXT.md`.
```

### Step 5: Add cross-references in the Referenced Scripts/Templates section

If `commands/migrate.md` already has a "Referenced Scripts" or similar tail section, append two entries:

```markdown
- `scripts/state/resolve-root.sh` — M008 5-rule state root resolver (AD-13)
- `scripts/knowledge/rebuild-index.sh` — index + graph DB rebuilder, called as final pipeline step (AD-14)
- `scripts/knowledge/detect-overlap.sh` — optional post-migration semantic enrichment (AD-14)
```

If no such section exists, create it.

## Must-Haves

This task addresses this phase truth:
- `commands/migrate.md` documents AD-13 (resolved target root), AD-14 (`relates_to` stays empty; post-migration `detect-overlap.sh` enriches), and AD-15 (command-naming deferral).

## Verification

```
grep -c 'AD-13' commands/migrate.md
grep -c 'AD-14' commands/migrate.md
grep -c 'AD-15' commands/migrate.md
grep -q 'resolve-root' commands/migrate.md && echo OK_RESOLVE
grep -q 'detect-overlap' commands/migrate.md && echo OK_OVERLAP
grep -q 'rebuild-index' commands/migrate.md && echo OK_REBUILD
```

Expected: each `grep -c` returns ≥1; the three `OK_*` markers all print.

## Inputs

### From Previous Tasks

- T01's migrate.sh changes inform the AD-13 prose (resolver wiring is now real, not aspirational).
- T03's rebuild-index wiring informs the AD-14 prose (the `rebuild-index.sh` call is real after T03).

### From Disk (Pre-existing)

- `commands/migrate.md` — modify by appending three sections plus optional reference list updates.
- `.specify/orchestrator/milestones/M003/M003-CONTEXT.md` — read-only source of truth for AD-13/14/15 wording. Do not duplicate the full rationale text; link to it.

## Constraints

- **Each new section ≤15 content lines** — progressive disclosure, full text lives in `M003-CONTEXT.md`.
- **No new commands or workflow steps** — this task is documentation only. Do NOT change the agent workflow described in `commands/migrate.md`.
- **Preserve existing content** — only append/insert. Do not delete or restructure existing sections.
- **Use the AD-NN identifiers verbatim** so the verify script's `grep -c 'AD-13'` style checks land.
- **Mention the script names verbatim** (`resolve-root.sh`, `rebuild-index.sh`, `detect-overlap.sh`) — they are the substrings the verify script keys on.
- **Do not invent new ADs**. Stick to AD-13/14/15 as captured in the milestone context.

## Expected Output

After this task, `commands/migrate.md` contains three new sections referencing AD-13, AD-14, and AD-15 by ID, mentions all three relevant script names (`resolve-root.sh`, `rebuild-index.sh`, `detect-overlap.sh`), and points readers at `M003-CONTEXT.md` for full rationale. Total file growth is in the +30 to +50 line range.
