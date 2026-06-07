---
schema_version: "1.0"
type: milestone-summary
milestone: "M044"
feature_ref: "045-knowledge-activation-reliability"
status: complete
validated_at: "2026-06-07"
---

# M044 Summary — Knowledge-Activation Reliability (P0 Hotfix)

Hardened the orchestrator knowledge-activation pipeline so it can never silently
degrade, and closed the capture→store→inject loop. Authored from the
conversus-validated brief `.orchestrator/proposals/knowledge-activation-reliability.md`
(16-agent deliberation, 0 rejections, DQ-1…DQ-8 binding). Four phases, all green;
acceptance battery (phase suites) `M044 TOTAL pass=16 fail=0`;
`validate-milestone.sh .orchestrator/milestones/M044` → PASS 8/8.

## The problem (recap)

On two production projects the knowledge base stopped activating for ~a month / two
milestones — every dispatch resolved to 0 MEMs and nobody was told. Five proven,
file:line-verified defects, none of which failed loud: (B-1) one heading-less entry
aborted the whole index rebuild; (B-2) the consumer then silently injected "first-5"
off the empty index; (B-3) the capture command wrote a column order the consumer
couldn't parse; (B-4) a bare `*/archive/*` glob zeroed the index for any project
rooted under a dir named `archive`; (B-5) the compression filter dropped flat
`## K###` knowledge. Plus the gaps: Quick captured no decisions (G-1) and the Quick
inject dropped Decisions (G-2); decisions in runtime memory the injector never read
(G-3).

## What shipped, by phase

- **P01 — Fail-loud activation floor** (FR-11/FR-5/FR-15/FR-9-enforcement). Canonical
  `get_index_path`/`get_db_path` resolver routing (no vestigial hardcoded joins);
  new `scripts/dispatch/lib/knowledge-provenance.sh` — fail-loud index-free grep
  fallback (mtime stale detection, budget-bounded via the M036a governor, always-on
  `knowledge_provenance: provenance_version: 1` header); inject-size surface +
  0-MEM-on-mature-project warning; new
  `scripts/diagnostics/check-knowledge-activation.sh` consolidated 3-symptom doctor
  check (papercut reconciled). Phase suite `pass=7 fail=0`.
- **P02 — Producer/consumer format unification + round-trip oracle** (FR-1/FR-2,
  BUG-A co-primary). `append-decision.sh` + `scaffold.sh` init header flipped to
  canonical **consumer-order** so the consumer's `awk -F'|'` `$5`=Scope/`$6`=When
  lands on the intended fields (#Q-1 forward-only); `scope-filter.sh` comment
  corrected, awk unchanged. `kf_filter_stream` `## ` flat-entry boundary detection +
  the two wrapper empty-detections (`build-context.sh` + `section-handlers.sh` count
  `^---$|^## `) so flat `## K###` survives; `filter_knowledge` now resolves standalone
  `append-knowledge.sh` scoped bullets independently. AC-1 round-trip oracle (dynamic
  decision+knowledge lanes / static byte-equality golden / SC-7 flat). Phase suite
  `pass=3 fail=0`.
- **P03 — Resilient rebuild + scoped archive glob** (FR-3/FR-4). `rebuild-index.sh`
  per-entry try/skip/warn (one heading-less entry can never zero the index) +
  `INDEXED: N / SKIPPED: M` summary + bounded unguarded-command audit; archive
  skip-glob scoped to the `knowledge/` subtree at all **three** sites
  (`rebuild-index.sh`, `resolve-entries.sh`, `index-utils.sh::emit_spec_chunks_section`)
  preserving the genuine `knowledge/archive/` exclusion (CON-4). Ran the real rebuild
  to clear the repo's own mtime-stale index (`status=ok`). Phase suite `pass=3 fail=0`.
- **P04 — Capture-by-default at Quick + Decisions digest** (FR-6/FR-8 G-1).
  `intensity-knowledge.sh --decision-arg` runs `append-decision.sh` at any intensity
  incl Quick (DQ-7, no net-new verb) without changing the auto-pipeline step counts;
  new `scripts/dispatch/lib/decisions-digest.sh` emits a bounded, budget-bounded
  (CON-2), deterministic (CON-3) `## Decisions` digest in the Quick inject.
  Capture→DECISIONS.md→rebuild→digest round-trip green. Phase suite `pass=3 fail=0`.

## Success-criteria coverage (SC-1…SC-12)

| SC | What | Phase | Verifier |
|---|---|---|---|
| SC-1 | decision round-trip byte-equality | P02 | `m044-p02-t03-roundtrip-oracle.sh` |
| SC-2 | resilient rebuild (skip-and-warn) | P03 | `m044-p03-t01-resilient-rebuild.sh` |
| SC-3 | bounded audit recorded | P03 | `m044-p03-t01-audit-artifact.sh` |
| SC-4 | archive glob scoped, exclusion preserved | P03 | `m044-p03-t02-scoped-archive-glob.sh` |
| SC-5 | fail-loud consumer + grep fallback | P01 | `m044-p01-t02-failloud-fallback.sh` |
| SC-6 | deterministic, budget-bounded fallback | P01 | `m044-p01-t02-determinism-budget.sh` |
| SC-7 | flat `## K###` passes the filter | P02 | `m044-p02-t02-flat-knowledge.sh` |
| SC-8 | capture-at-Quick + Decisions digest | P04 | `m044-p04-t02-decisions-digest.sh` |
| SC-9 | capture-by-default round-trip | P04 | `m044-p04-t03-capture-roundtrip.sh` |
| SC-10 | 0-MEM warning on a mature project | P01 | `m044-p01-t03-zeromem-warning.sh` |
| SC-11 | single consolidated doctor check | P01 | `m044-p01-t04-consolidated-doctor.sh` |
| SC-12 | canonical path resolver | P01 | `m044-p01-t01-canonical-path.sh` |

## Plan-time open questions resolved

- **#Q-1** consumer-order is canonical; `append-decision.sh` rewritten; forward-only (P02).
- **#Q-2** mtime stale detection for P0; content-hash deferred to FR-10/P1 (P01).
- **#Q-3** reconcile into one `DOCTOR:KNOWLEDGE_ACTIVATION` surface; papercut annotated (P01).
- **#Q-4** pin `provenance_version: 1` now (P01).

## Forward-pointed (Non-Goals, P1/M040-track)

Discoverable `/orchestrator-capture` + `/orchestrator-promote` UX; FR-8
auto-graduate-at-phase-close; graduation mechanism + system-of-record docs;
FR-10 freshness content-hash contract; corpus-exhaustion hard gates beyond
`comments`; embeddings. Live runtime-memory read is **cut** (DQ-8, M009).

## Discovered + closed beyond the named defects

- A standalone `append-knowledge.sh` scoped bullet was glued to (and dropped with) the
  preceding `## K###` entry — `filter_knowledge` now scope-resolves it independently (P02).
- A **third** bare-archive-glob site (`emit_spec_chunks_section`) surfaced by the P03
  bounded audit — fixed the same way (P03).

## Ship status

PR #11 (branch `m044-knowledge-activation-reliability`) carries the full M044 work
(spec → roadmap → P01-P04). Operator to smoke-test + merge alongside the M034 PR #12.
Three pre-existing `m002` traverse-graph test failures were confirmed unrelated (they
fail on clean pre-M044 code — a DB-build environment dependency).
