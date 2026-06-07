---
schema_version: "1.0"
type: phase-summary
phase: "P03"
milestone: "M044"
status: complete
---

# M044/P03 Summary — Resilient Rebuild + Scoped Archive Glob

The rebuild can no longer be silently zeroed by one malformed entry, and a project
rooted under a directory named `archive` indexes correctly. Three tasks, all
verified; phase-suite `BATTERY: pass=3 fail=0`.

## What shipped

- **T01 — FR-3 resilient per-entry skip-and-warn rebuild (B-1, the proven root
  incident).** `rebuild-index.sh` ran under `set -euo pipefail` with an unguarded
  description grep at `:117`; one heading-less entry made grep exit 1, `pipefail`
  propagated it, and `set -e` aborted the entire rebuild mid-loop (~146 chunks left
  unindexed for a month). Now per-entry **try/skip/warn**: the description grep is
  captured into `heading_line` guarded with `|| true`; a heading-less (or id-less)
  entry emits a `SKIP:` warning to stderr, bumps a skip counter, and `continue`s —
  every valid entry still indexes. A final `INDEXED: N / SKIPPED: M [ids]` summary
  prints to stdout. Exit stays 0 on per-entry skips; non-zero is reserved for the
  catastrophic cases (missing `knowledge/`, DB write failure). The
  heading-present-but-empty-description case keeps its ID fallback (no regression).
- **T01 — FR-3 bounded audit (SC-3).** `.orchestrator/milestones/M044/gates/P03-rebuild-unguarded-audit.md`
  audits `rebuild-index.sh` + its two directly-sourced libs (`index-utils.sh`,
  `graph-db.sh`) for every command that can fail silently under `set -e`/`pipefail`,
  marking each guarded / FIXED / intentional-catastrophic-abort. Bounded — no
  whole-codebase sweep (Principle XIV).
- **T02 — FR-4 scoped archive glob (B-4, CON-4).** The bare `*/archive/*` skip-glob
  matched the **absolute** path, so a project rooted under a dir named `archive`
  zeroed its whole index. Scoped to the `knowledge/`-relative path in
  `rebuild-index.sh:74` **and** `resolve-entries.sh:45`, preserving the genuine
  `knowledge/archive/` cold-storage exclusion. The bounded audit surfaced a **third**
  instance — `index-utils.sh::emit_spec_chunks_section:264` — fixed the same way.
- **T03 — Phase suite + cleared the repo's own stale index.** Aggregator
  `tools/verify/m044-p03-phase-suite.sh`. Ran the real `bash scripts/knowledge/rebuild-index.sh`
  against this repo (now safe under FR-3): `REBUILT: 51 entries`, `INDEXED: 51 / SKIPPED: 0`,
  no stderr skips. The repo's index was **mtime-stale** (not content-wrong — the
  P01 staleness signal is mtime-based), so the rebuild refreshed mtime with
  byte-identical content (no committable diff to the tracked `KNOWLEDGE-INDEX.md`;
  `knowledge.db` is gitignored). `check-knowledge-activation.sh` now reports
  `status=ok symptoms=none`.

## Verification

- Phase suite: `bash tools/verify/m044-p03-phase-suite.sh` → `BATTERY: pass=3 fail=0`.
- Framework must-haves: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M044/phases/P03` → all truths/artifacts/key-links PASS.
- Regression: `m007-p01-rebuild-*`, `m011-p02-rebuild-index`, `m003-p07-rebuild-index-wired`,
  `m002-p03-resolve-outputs-content`, `m013-p01-rebuild-index-additive` (spec-chunks),
  `m011-p05/p06` pipeline suites all green. Three pre-existing `m002` traverse-graph
  failures confirmed **unrelated** (they fail on clean pre-P03 code — a DB-build
  environment dependency, not touched by this phase).

## Carried forward

- P04 (capture-by-default at Quick + Decisions digest, FR-6/FR-8 G-1) — the last P0
  phase, depends on P01 + P02.
