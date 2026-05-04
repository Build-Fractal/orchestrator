---
schema_version: "1.0"
type: command
description: Draft the CLAUDE.md custom block from upstream sub-flow outputs (FR-13/FR-14).
---

# orchestrator:customblock-draft

Drafts the marker-delimited custom block in `<project-dir>/CLAUDE.md` by **strict
aggregation** of upstream sub-flow outputs (constitution, ingest-codebase MEMs,
intake pre-spec). Implements the FR-13 contract and the FR-14 prescriptive
5-section structure documented in `references/customblock-format.md`.

This command is structurally downstream of `orchestrator:constitution`
(US-7 AS-5 gate): if `<project-dir>/.orchestrator/memory/constitution.md` is
absent, the driver exits non-zero with the diagnostic
`constitution not present -- run "orchestrator:constitution" first`.

## Prerequisites / State Check

- A constitution at `<project-dir>/.orchestrator/memory/constitution.md`
  (US-7 AS-5 structurally-downstream-of-US-2 gate; authored by
  `orchestrator:constitution` per FR-3).
- Optionally: ingest-codebase MEMs at
  `<project-dir>/.orchestrator/knowledge/{architecture,conventions,decisions}/MEM-*.md`
  (authored by `orchestrator:ingest-codebase` per FR-7; rich-context MEMs
  including `MEM-DR-*` cross-references per FR-8).
- Optionally: an intake artifact at
  `<project-dir>/.orchestrator/intake/<timestamp>/reconciled-pre-spec.md`
  (FR-9 / `orchestrator:materials-intake` output) or
  `<project-dir>/.orchestrator/intake/<timestamp>/ideation-pre-spec.md`
  (FR-10 / `orchestrator:ideation` output).

## Core Workflow

1. **Verify the constitution exists.** On absence, exit non-zero with
   `constitution not present -- run "orchestrator:constitution" first` to stderr
   per US-7 AS-5. This is the structurally-downstream-of-US-2 gate.

2. **Detect upstream outputs and choose the section variant.** When an intake
   pre-spec (`reconciled-pre-spec.md` from FR-9 OR `ideation-pre-spec.md` from
   FR-10) is present under `<project-dir>/.orchestrator/intake/<timestamp>/`,
   the driver renders the `## Source-Docs` section variant. When no intake
   artifact exists but ingest-codebase architecture MEMs do, the driver renders
   the `## Entry Points` section variant. This branch-dependent variant rule
   is documented in `references/customblock-format.md` (FR-14 SSOT).

3. **Strictly aggregate upstream outputs into the 5-section draft.** The
   prescriptive sections are `## Project`, `## Stack`, `## Source-Docs` OR
   `## Entry Points` (branch-dependent), `## Conventions`, and `## Decisions`.
   Every line emitted into the draft traces verbatim to a file under
   `<project-dir>/.orchestrator/{memory,knowledge,intake}/`. There is no LLM
   invocation, no conversus invocation, no model routing in the draft path —
   per Constitution XV (Strict Aggregation Discipline).

4. **Hand the draft to `$EDITOR`** (default `vi`). Skipped under `--yes`.

5. **Write the reviewed content into the marker-delimited region of
   `<project-dir>/CLAUDE.md`.** The write region is delimited by the
   `<!-- BEGIN CUSTOM -->` and `<!-- END CUSTOM -->` markers. Operator
   additions beyond the prescribed 5 sections (e.g., `## Notes`,
   `## Open Questions`) are preserved verbatim per US-7 AS-2 — the prescriptive
   structure is a **floor**, not a **ceiling**.

6. **Write the FR-20 partial-state marker.** Calls
   `bash scripts/util/start-state-markers.sh write customblock-drafted <project-dir>`
   to record `<project-dir>/.orchestrator/start-state/customblock-draft.complete`
   (alias-mapped to the canonical `customblock-drafted.complete` filename per
   the P03/T05 alias-mapping comment block in `start-state-markers.sh`).

7. **Emit the FR-22 JSONL event.** Calls
   `bash scripts/util/jsonl-event-emitter.sh emit customblock_drafted '<payload>'`
   appending a record to `<project-dir>/.orchestrator/execution-log.jsonl`.
   The `customblock_drafted` event-type is in the closed enum per FR-22.

8. **Append the FR-21 dual-write Recent Changes fragment.** Calls
   `bash scripts/util/dual-write-runtime-md.sh --root <project-dir>
   --marker recent-changes --append-entry '<fragment>'` per the P03/T05
   harmonized API documented in
   `references/m033-fr21-dual-write-convention.md`.

## Output

- `<project-dir>/CLAUDE.md` (modified — marker-delimited region populated with
  the 5-section custom block plus any operator-additional sections preserved).
- `<project-dir>/.orchestrator/start-state/customblock-draft.complete` (created
  via the `customblock-drafted` sub-flow alias; idempotent first-write timestamp).
- `<project-dir>/.orchestrator/execution-log.jsonl` (appended one
  `customblock_drafted` record with `project_dir` / `section_variant` / `force`
  payload fields).
- `<project-dir>/CLAUDE.md` and (if `dual_write_agents` is true)
  `<project-dir>/AGENTS.md` Recent Changes regions appended with one fragment.

## Idempotency

- Without `--force`: re-runs preserve byte-identical content of the existing
  custom block. Diagnostic: `no changes -- existing custom block preserved
  (use --force to regenerate)` to stdout. Exit 0.
- With `--force`: regenerates the custom block in place. Stderr warning:
  `--force discards prior operator edits in CLAUDE.md custom block` per
  US-7 AS-4. Operator additions outside the prescribed 5 sections are still
  preserved per the floor-not-ceiling discipline (US-7 AS-2).
- The FR-20 marker is idempotent — the first-completion timestamp is preserved
  on re-write.

## Error Handling

- Missing constitution: exit 1 with `constitution not present -- run
  "orchestrator:constitution" first` to stderr (US-7 AS-5).
- Unknown flag: exit 2 with `unknown flag: <flag>` to stderr.

## Referenced Scripts

- `scripts/lifecycle/customblock-draft.sh` — the FR-13 deterministic
  strict-aggregation driver.
- `scripts/util/jsonl-event-emitter.sh` — FR-22 closed-enum JSONL emitter.
- `scripts/util/start-state-markers.sh` — FR-20 partial-state marker primitives.
- `scripts/util/dual-write-runtime-md.sh` — FR-21 dual-write helper for the
  CLAUDE.md / AGENTS.md Recent Changes region.

## See Also

- `references/customblock-format.md` — FR-14 SSOT documenting the prescriptive
  5-section format, the `## Source-Docs` vs `## Entry Points` branch-dependent
  variant rule, the floor-not-ceiling discipline, and the strict-aggregation
  invariant.
- `references/m033-fr21-dual-write-convention.md` — FR-21 dual-write callsite
  convention SSOT.
