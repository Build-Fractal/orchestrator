---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M044"
---

# T01 — FR-3 resilient per-entry skip-and-warn rebuild + bounded audit

## Zero-context summary

`rebuild-index.sh` runs under `set -euo pipefail` (`:11`). The description grep at
`:117` (`description="$(grep "^# ${id}:" "$file" | head -1 | sed ...)"`) is
unguarded: a heading-less entry makes grep exit 1, `pipefail` propagates it, and
`set -e` aborts the entire rebuild mid-loop — zero output, ~146 chunks unindexed
(B-1, the proven root incident). The sibling `fm_field()` at `:40` already ends in
`|| true`; the description grep does not.

## Steps

1. Initialize `skipped_count=0` and `skipped_ids=""` near `entry_count=0` (`:64`).
2. After `id` extraction (`:93-99`), compute `rel_path="${file#$root/}"` once
   (move the later `:125` assignment up) and add an explicit skip guard: if `id`
   is empty → `echo "SKIP: $rel_path (no id/chunk_id)" >&2`, bump skipped, `continue`.
3. Replace the `:117` description block: capture the heading line guarded
   (`heading_line="$(grep "^# ${id}:" "$file" 2>/dev/null | head -1 || true)"`).
   If `heading_line` is empty → heading-less: `echo "SKIP: $rel_path ($id — no '# $id:' heading)" >&2`,
   bump `skipped_count`, append `$id` to `skipped_ids`, `continue`. Otherwise derive
   `description` from `heading_line` via the existing sed; keep the ID-fallback for a
   heading-present-but-empty description (preserves the currently-working case).
4. After the REBUILT lines (`:256-257`), emit the final summary to stdout:
   `INDEXED: <db_entry_count> / SKIPPED: <skipped_count> [<skipped_ids>]` (bracket
   only when skipped>0). Exit 0 — non-zero stays reserved for the catastrophic
   cases already handled (missing `knowledge/` `:47-50`; DB write failure via the
   `mv` `:254` under `set -e`).
5. Bounded audit: read `rebuild-index.sh` + `lib/index-utils.sh` + `lib/graph-db.sh`,
   list every command that can fail silently under `set -e`/`pipefail`, mark each
   guarded or justify-and-track, write `.orchestrator/milestones/M044/gates/P03-rebuild-unguarded-audit.md`.

## Verifiers

- `tools/verify/m044-p03-t01-resilient-rebuild.sh` — `mktemp -d` corpus with a
  valid `# MEM###:`-headed entry + a heading-less entry → run `rebuild-index.sh --root`,
  assert exit 0, the valid entry indexed, a `SKIP:` stderr warning naming the bad
  entry, and an `INDEXED: N / SKIPPED: 1` summary on stdout.
- `tools/verify/m044-p03-t01-audit-artifact.sh` — assert the audit artifact exists,
  names `:117`/description grep as guarded, and covers index-utils.sh + graph-db.sh.

## Done when

- `bash tools/verify/m044-p03-t01-resilient-rebuild.sh` → `PASS:`
- `bash tools/verify/m044-p03-t01-audit-artifact.sh` → `PASS:`
