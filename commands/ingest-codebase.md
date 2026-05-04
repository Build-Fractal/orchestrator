---
description: "Use when seeding the project knowledge graph from an existing codebase via deterministic structural extraction. Produces 5-15 seed MEMs across architecture/conventions/decisions categories."
---

# orchestrator:ingest-codebase

`orchestrator:ingest-codebase` seeds the project knowledge graph from an
existing codebase. It is the FR-7 surface of M033 (Project Onboarding
Experience). The extraction path is **deterministic and structural** —
no LLM augmentation, no semantic summarization, no model routing. See
the determinism section below.

## Prerequisites / State Check

- `orchestrator:init` has run for the target project: the directory
  `<project-dir>/.orchestrator/` exists.
- The project has been opened via `orchestrator:start` (greenfield-with-
  materials or existing-codebase branch). The `init-invoked.complete`
  start-state marker is present.
- The target directory contains at least one of the closed signal-source
  set (top-level docs / package manifests / source directory tree / test
  directory shape / git log / prior-tooling artifacts).

## Core Workflow

1. **Signal-source scan.** Walk the closed signal-source set documented
   in the fenced `# >>> ingest-signal-sources >>>` SSOT block inside
   `scripts/lifecycle/ingest-codebase.sh`. Each source kind contributes
   at most one MEM file (per-category) to keep the seed set bounded.
2. **Deterministic stable-ID derivation.** For each detected signal,
   compute `stable_id(<source-path>, <signal-kind>)` — an 8-char hex
   digest of `<source-path>:<signal-kind>` via `md5` (darwin) or
   `md5sum` (linux). Re-runs against the same inputs produce identical
   IDs by construction; no per-run state file is needed for idempotency.
3. **Per-category MEM emission.** Emit at most 15 MEM files into
   `<project-dir>/.orchestrator/knowledge/{architecture,conventions,decisions}/`
   following the M020 `MEM-<CAT>-<id>.md` filename convention. Each MEM
   carries `derived_from_codebase_ingest: true` in frontmatter — that
   flag is the load-bearing marker for the re-ingest detection path.
   Per-MEM body cap of ~30 lines (seed, not documentation).
4. **Rich-context import-path branch detection (FR-8 / MIT-005).** When
   prior-tooling artifacts include a synthetic `.orchestrator/DECISIONS.md`
   carrying `DR-` entries, OR when a free-form context document is
   detected via the path-resolver convention, the rich-context branch
   imports that material into either
   `<current-milestone>-CONTEXT.md` (when a milestone is active) or
   `_imported-context/_imported-context.md` per `#Q-11`. The import path
   sets `context_source: imported` on each `MEM-DR-` it generates so the
   provenance is traceable. **T03 ships the deterministic core only;
   T04 fills the rich-context branch in-place** (see the reserved
   `# >>> rich-context-branch >>>` block in the driver).
5. **Re-ingest detection.** Before writing any MEM, scan
   `<knowledge>/{architecture,conventions,decisions}/MEM-*.md` for files
   carrying `derived_from_codebase_ingest: true`. If every MEM about to
   be written has the same stable ID as an existing file, emit
   `re-ingest: <N> existing entries detected, no changes` to stdout,
   emit one `ingest_codebase_completed` JSONL event with
   `payload: {"action":"re-ingest","existing":<N>}`, and exit 0.
6. **Marker write.** Invoke `scripts/util/start-state-markers.sh write
   ingest-codebase <project-dir>` to land the FR-20 partial-state
   marker `<project-dir>/.orchestrator/start-state/ingest-codebase.complete`
   (the post-completion semantic alias is `ingest-codebase-completed.complete`
   — see the script comment).
7. **JSONL event emission.** Invoke
   `scripts/util/jsonl-event-emitter.sh emit ingest_codebase_completed
   '{"mem_count":<N>,"categories":"architecture,conventions,decisions"}'`
   to land one FR-22 observability record. The rich-context branch (T04)
   additionally emits `imported_context_loaded`.
8. **FR-21 dual-write fragment.** Invoke
   `scripts/util/dual-write-runtime-md.sh --root <project-dir> --marker
   recent-changes --append-entry "036-project-onboarding-experience:
   orchestrator:ingest-codebase seeded <N> MEMs from existing codebase"`
   so the runtime-md (CLAUDE.md / AGENTS.md) recent-changes block
   reflects the ingest event.

## Output

- 5-15 MEM files under
  `<project-dir>/.orchestrator/knowledge/{architecture,conventions,decisions}/`,
  each with `derived_from_codebase_ingest: true` frontmatter and a
  ≤30-line seed body.
- Optional rich-context import file (T04 deliverable):
  - `<current-milestone>-CONTEXT.md` when a milestone is active.
  - `_imported-context/_imported-context.md` when no milestone is
    configured (per `references/imported-context-sentinel.md` —
    T04 deliverable; see `#Q-11`).
- `<project-dir>/.orchestrator/start-state/ingest-codebase.complete`
  marker (load-bearing alias: `ingest-codebase-completed.complete`).
- One `ingest_codebase_completed` JSONL record appended to
  `<project-dir>/.orchestrator/execution-log.jsonl`. T04 additionally
  emits one `imported_context_loaded` record per rich-context import.
- One FR-21 dual-write fragment appended to the
  `# >>> orchestrator:recent-changes >>>` region of the project's
  runtime-md files.

## Idempotency

Re-runs against the same project directory detect existing
`derived_from_codebase_ingest: true` MEMs by stable ID and emit:

```
re-ingest: <N> existing entries detected, no changes
```

to stdout, then exit 0. No new MEMs are written; one JSONL event
records the no-op (`payload.action = "re-ingest"`). Operators who want
to force re-ingest can manually delete the seeded MEMs (a future
`--force` flag is demand-driven; out of T03 scope).

## Determinism (CON-3 / NG-8)

The extraction path is structural-extraction-only:

- Reads files (top-level docs, package manifests, directory listings,
  git log, prior-tooling artifacts).
- Writes MEMs whose bodies are direct quotations / structured facts
  derived from those files.
- Does NOT generate semantic summaries.
- Does NOT call `claude-code`, `conversus`, `scripts/dispatch/build-context.sh`,
  or any model-routing surface.

The T03 verifier asserts zero matches for `claude-code`, `conversus`,
and `model_routing` in the script body. LLM-augmented summarization is
deferred to M033.5 per `#Q-3`.

## Imported Context Sentinel (#Q-11)

When the rich-context branch (T04) detects free-form context material
to import (e.g., a synthetic `.orchestrator/DECISIONS.md` carrying
`DR-` entries) AND no milestone is active, the imported context is
written to `<project-dir>/_imported-context/_imported-context.md` per
the path-resolver convention documented in `references/imported-context-sentinel.md`
(T04 deliverable). When a milestone IS active, the imported context
goes to `<current-milestone>-CONTEXT.md`. Each imported `MEM-DR-`
carries `context_source: imported` so the provenance is traceable.

## Referenced Scripts

- `scripts/lifecycle/ingest-codebase.sh` — the FR-7 deterministic
  driver. T03 ships the core; T04 fills the reserved rich-context
  branch in-place.
- `scripts/util/jsonl-event-emitter.sh` — FR-22 event emitter (accepts
  `ingest_codebase_completed` and `imported_context_loaded`).
- `scripts/util/start-state-markers.sh` — FR-20 marker write primitive
  (accepts `ingest-codebase` sub-flow name).
- `scripts/util/dual-write-runtime-md.sh` — FR-21 dual-write helper
  (called with `--root`, `--marker recent-changes`, `--append-entry`).
- `references/imported-context-sentinel.md` — T04 deliverable
  documenting the FR-8 / `#Q-11` path-resolver convention.
