---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M044"
goal: "Make the index rebuild resilient (per-entry try/skip/warn — one heading-less entry can never silently zero the whole index) and scope the archive skip-glob to the orchestrator's own subtree (a project rooted under a dir named `archive` indexes correctly) while preserving the genuine knowledge/archive/ cold-storage exclusion."
demo_sentence: "A corpus with a heading-less entry rebuilds successfully — all valid entries indexed, a per-skip warning + an INDEXED: N / SKIPPED: M summary emitted, exit 0; an archive/-rooted fixture project builds a non-empty index and a non-zero :do quick-inject while a genuine knowledge/archive/ entry stays excluded."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

### Truths

- `rebuild-index.sh` performs per-entry try/skip/warn: a heading-less entry is skipped with a stderr warning, every valid entry is still indexed, a final `INDEXED: N / SKIPPED: M` summary is emitted, and the script exits 0 (non-zero only on catastrophic failure — missing `knowledge/`, DB write failure). (FR-3 / SC-2)
  - Check: `bash tools/verify/m044-p03-t01-resilient-rebuild.sh`
- A bounded audit artifact lists every command in `rebuild-index.sh` plus its directly-sourced libs that can fail silently under `set -e`/`pipefail`, each marked guarded or justify-and-track; `:117` is guarded. (FR-3 / SC-3)
  - Check: `bash tools/verify/m044-p03-t01-audit-artifact.sh`
- The archive skip-glob is scoped to the orchestrator's own subtree in both `rebuild-index.sh` and `resolve-entries.sh`: a project rooted under a path segment named `archive` builds a non-empty index, while a genuine `knowledge/archive/` entry remains excluded. (FR-4 / SC-4 / CON-4)
  - Check: `bash tools/verify/m044-p03-t02-scoped-archive-glob.sh`

### Artifacts

- `tools/verify/m044-p03-t01-resilient-rebuild.sh` (create — min 30 lines)
- `tools/verify/m044-p03-t01-audit-artifact.sh` (create — min 20 lines)
- `tools/verify/m044-p03-t02-scoped-archive-glob.sh` (create — min 30 lines)
- `tools/verify/m044-p03-phase-suite.sh` (create — aggregator)
- `.orchestrator/milestones/M044/gates/P03-rebuild-unguarded-audit.md` (create — min 20 lines, contains "INDEXED")
- `.orchestrator/milestones/M044/phases/P03/P03-SUMMARY.md` (create at phase close — min 20 lines)

### Key Links

- `scripts/knowledge/rebuild-index.sh` → `scripts/knowledge/lib/index-utils.sh` (rebuild sources the index-path/format utilities it audits)
- `scripts/knowledge/resolve-entries.sh` → `scripts/knowledge/lib/index-utils.sh` (resolver shares the same archive-scoping subtree contract)

## Tasks

### T01: FR-3 resilient per-entry skip-and-warn rebuild + bounded audit

Guard the description grep (`rebuild-index.sh:117`) so a heading-less entry skips
(warn to stderr, `continue`) instead of aborting the whole rebuild under
`set -e`/`pipefail` (B-1). Add `skipped_count` / `skipped_ids` accumulators and an
explicit `id`-empty skip guard. Emit a final `INDEXED: N / SKIPPED: M [ids]`
summary to stdout. Exit non-zero only on the named catastrophic failures (missing
`knowledge/`, DB write failure — already handled). Conduct a **bounded** audit of
`rebuild-index.sh` + its directly-sourced libs (`index-utils.sh`, `graph-db.sh`)
for other commands that can fail silently under `set -e`/`pipefail`; record each as
guarded or justify-and-track in `.orchestrator/milestones/M044/gates/P03-rebuild-unguarded-audit.md`.
Co-author `tools/verify/m044-p03-t01-resilient-rebuild.sh` + `m044-p03-t01-audit-artifact.sh`.
See `tasks/T01-resilient-rebuild-PLAN.md`.

### T02: FR-4 scoped archive glob (preserve knowledge/archive/)

Replace the bare `*/archive/*` false-match at `rebuild-index.sh:74` and
`resolve-entries.sh:45` with a subtree-scoped check against the path **relative to
`knowledge/`** (`archive/*` or `*/archive/*` within the knowledge subtree), so a
project rooted under an absolute path segment named `archive` indexes correctly
while the genuine `knowledge/archive/` cold-storage exclusion (declared at
`rebuild-index.sh:6`, CON-4) is preserved. Co-author
`tools/verify/m044-p03-t02-scoped-archive-glob.sh`. See `tasks/T02-scoped-archive-glob-PLAN.md`.

### T03: Fixtures + phase suite + clear the repo's own stale index

Build the resilient-rebuild fixture (≥1 valid + ≥1 heading-less entry) and the
archive-rooted fixture (project root under a dir named `archive`, with a genuine
`knowledge/archive/` entry) referenced by the T01/T02 verifiers (inline `mktemp -d`
corpora — the proven P01 pattern). Build `tools/verify/m044-p03-phase-suite.sh`
(copy P01's aggregator, retarget `m044-p03-*`). After FR-3 lands, run
`bash scripts/knowledge/rebuild-index.sh` to clear this repo's genuinely-stale
`KNOWLEDGE-INDEX.md` (surfaced loud by P01). See `tasks/T03-fixtures-suite-PLAN.md`.

## Task Dependencies

```
T01 ─┐
     ├─► T03
T02 ─┘
```

- T01 (resilient rebuild) and T02 (archive glob) touch the same file
  (`rebuild-index.sh`) at disjoint seams (`:117` loop body vs `:74` skip-glob);
  build T01 first, then T02.
- T03 (fixtures + suite + index-clear) integrates both.

## Files Likely Touched

- `scripts/knowledge/rebuild-index.sh` (modify — FR-3 guard/skip/summary `:117`+loop; FR-4 scoped glob `:74`)
- `scripts/knowledge/resolve-entries.sh` (modify — FR-4 scoped glob `:45`)
- `.orchestrator/milestones/M044/gates/P03-rebuild-unguarded-audit.md` (create — bounded audit)
- `tools/verify/m044-p03-t01-resilient-rebuild.sh` (create)
- `tools/verify/m044-p03-t01-audit-artifact.sh` (create)
- `tools/verify/m044-p03-t02-scoped-archive-glob.sh` (create)
- `tools/verify/m044-p03-phase-suite.sh` (create)
- `KNOWLEDGE-INDEX.md` + `knowledge.db` (regenerated by the index-clear run)
