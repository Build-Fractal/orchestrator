---
schema_version: "1.0"
type: phase-summary
phase: "P02"
milestone: "M044"
status: complete
---

# M044/P02 Summary — Producer/Consumer Format Unification + Round-Trip Oracle (BUG-A)

The co-primary BUG-A slice: one canonical decision/knowledge format so the official
capture primitives write rows the dispatch consumer can actually read, proven by a
capture→resolve→byte-assert round-trip oracle. Three tasks, all verified; phase-suite
`BATTERY: pass=3 fail=0`.

## What shipped

- **T01 — FR-1 decision format unification (B-3).** `append-decision.sh:93` now
  emits canonical **consumer-order** `| ID | Decision | Choice | Scope | When | Rationale | Revisable |`
  (same vars, reordered — the CLI arg order is unchanged), so the consumer's
  `awk -F'|'` `$5`=Scope / `$6`=When indices land on the intended fields. The
  init-time empty `DECISIONS.md` header (`scaffold.sh:89`) and the producer
  docstring match. The `scope-filter.sh:351` column-map comment now describes the
  awk reality (leading empty `$1`; `$5`=Scope `$6`=When); the awk at `:353-354` is
  unchanged (it was already correct). Per #Q-1: **consumer-order wins, producer is
  the loser, forward-only** — pre-M044 producer-order rows already never resolved
  (that *was* B-3), so no migration is owed. Out of scope (flagged, untouched):
  `scripts/migrate/transform/decisions.sh` (a third order, external-tool migration)
  and this repo's hand-maintained 7-col `category`-bearing `DECISIONS.md`.
- **T02 — FR-2 flat `## K###` knowledge survives the filter + inject (B-5).**
  `kf_filter_stream` split entries only on `---` frontmatter fences, so a flat
  `## K###` entry trailing a frontmatter entry was glued onto it and silently
  dropped when that entry was dropped (verified live). Fixed with `## ` flat-entry
  boundary detection (per-entry `fm_seen`/`heading_seen` flags; a frontmatter
  entry's own `# `/`## ` heading stays bound to it so superseded-drop covers
  heading+body). The two wrapper empty-detections (`_bc_apply_knowledge_filter` in
  `build-context.sh`, `_sh_apply_knowledge_filter` in `section-handlers.sh`) now
  count entry markers (`^---$|^## `), not just `---` fences, so a flat-only inject
  is no longer falsely nulled to `(no qualifying knowledge entries)`. **Bonus
  divergence closed:** a standalone `append-knowledge.sh` scoped bullet
  (`- **[scope]** [date] text`) was being glued to (and dropped with) the preceding
  `## K###` entry; `filter_knowledge` now treats it as its own scope-resolved entry
  (scope rule factored into the shared `_sf_tag_includes()` helper — Principle XI).
- **T03 — AC-1 round-trip oracle + phase suite (SC-1/SC-7).** Four lanes: a
  **dynamic decision** lane (runtime append → resolve → byte-assert `$5`/`$6`), a
  **dynamic knowledge** lane (flat `## K###` + append-knowledge bullet resolve
  in-scope; out-of-scope excluded), a **static byte-equality** lane (frozen fixture
  → frozen golden output — split from the dynamic lane per
  `feedback_fixtures_byte_equality_default`), and the **SC-7** flat-passes assertion.

## Verification

- Phase suite: `bash tools/verify/m044-p02-phase-suite.sh` → `BATTERY: pass=3 fail=0`.
- Framework must-haves: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M044/phases/P02` → all truths/artifacts/key-links PASS.
- Regression: M018 `filter-drops` + `disable-flag-honored`, and the M011/M007/M025
  scope-filter suites (nongoal inclusion/exclusion, spec-scope-tag-resolve,
  skips-superseded, graph-mode/filters, knowledge-entries) all green after the
  `filter_knowledge` refactor.

## Plan-time open questions resolved here

- **#Q-1** canonical column order → **consumer-order is the written contract**;
  `append-decision.sh` (the loser) rewritten; **forward-only**, no migration
  (the dogfood scan found the only `append-decision.sh`-divergent shape was the
  producer itself; init-seeded stores already match consumer-order).

## Carried forward

- The append-knowledge **bullet** shape (`- **[scope]**`) vs. the consolidated
  `## K###` heading shape remain two write shapes; P02 made the **consumer**
  resolve both. Unifying the *write* surface (a discoverable capture verb that
  always emits one shape) is M040 capture-UX track, not P0 (DQ-7: no net-new
  capture verb).
- P03 (resilient rebuild + scoped archive glob) and P04 (capture-at-Quick +
  Decisions digest) remain. P04 consumes this canonical decision format.
