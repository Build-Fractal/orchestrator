# M014/P02 Write-Site Manifest

This file is the P02 source of truth for every call site in the repository that
writes to `CLAUDE.md` or `AGENTS.md`. All writes flow through the single FR-12
helper at `scripts/util/dual-write-runtime-md.sh`. No write-site calls the helper
or writes to either file outside the enumerated set below.

## Scope

Four call sites total, one per task:

| Site | Script | Region | Task | Status |
|------|--------|--------|------|--------|
| 1 | `scripts/specify/specify.sh` | `recent-changes` | M014/P01/T05 | shipped (P01) |
| 2 | `scripts/lifecycle/init-project.sh` | `project-identity` | M014/P02/T02 | pending (P02) |
| 3 | `scripts/lifecycle/reinit-handler.sh` | `project-identity` | M014/P02/T02 | pending (P02) |
| 4 | `scripts/knowledge/consolidate-artifacts.sh` | `recent-changes` | M014/P02/T03 | pending (P02) |

## Regions

Two marker regions are in use across the four sites:

- **`project-identity`** — captures project-level identity attributes populated
  by `orchestrator:init` and refreshed by the reinit handler. Fragment shape is
  five one-line key=value entries: `project_name=<name>`, `runtime=<name>`,
  `cap_score=<N>`, `recommended_intensity=<quick|standard|full>`, and
  `initialized_at=<ISO-8601>`. Regenerated in full on every init/reinit — not
  append-only.
- **`recent-changes`** — append-only Recent Changes log. One entry per
  `orchestrator:specify` scaffold and one entry per `orchestrator:consolidate`
  milestone close. Entry format: `- <NNN>-<slug>: <description>` (specify) or
  `- <milestone-id>: milestone consolidated (<N>% reduction, <M> phases archived)`
  (consolidate). Existing entries are preserved on append; new entries are
  inserted above the closing marker.

## Write-Site Enumeration Invariant

A `grep` across the repository for direct `CLAUDE.md` or `AGENTS.md` writes
outside the helper must return zero results. The gate verifier
`scripts/verify/m014-p02-write-site-manifest.sh` asserts this invariant by
scanning `scripts/**/*.sh` and `commands/**/*.md` for disallowed write
patterns and matching the enumerated set against the table above.

Allowed write patterns (by shape):

- `render_template ... > "$INSTRUCTION_FILE"` where `INSTRUCTION_FILE` is
  one of `CLAUDE.md`, `AGENTS.md`, or `.cursor/rules/orchestrator.md` — these
  are runtime-native full-file writes in `init-project.sh` and
  `reinit-handler.sh`. The dual-write invocation is *additive* to this render
  path; it does not replace it.
- Invocations of `scripts/util/dual-write-runtime-md.sh` — the single
  dual-write surface.
- Verifier / test scripts under `scripts/verify/` and `tests/` that write to
  scratch directories under `$(mktemp -d)` — excluded from the scan (no repo
  writes).

Disallowed shapes (the scan fails if any match):

- Any non-test, non-verifier shell script under `scripts/` containing a
  direct `> "$PROJECT_DIR/CLAUDE.md"` or `>> "$PROJECT_DIR/CLAUDE.md"` redirect
  (same for `AGENTS.md`) that is NOT the `render_template` full-file render in
  `init-project.sh` or `reinit-handler.sh`.

## Non-Goals

- This file does NOT enumerate write-sites for `.cursor/rules/orchestrator.md` —
  that file has a single renderer in `init-project.sh` and is runtime-native
  only (Cursor has no dual-write peer).
- This file does NOT enumerate read sites — drift detection reads both files
  but is not a write-site.

## Maintenance

Any future milestone introducing a new write-site MUST:

1. Add a row to the Scope table above.
2. Name the marker region used (or declare a new region with a one-paragraph
   explanation).
3. Update `scripts/verify/m014-p02-write-site-manifest.sh` to accept the new
   site in the allow list (or the scan will fail on the next phase suite run).
