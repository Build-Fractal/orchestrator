---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M044"
goal: "Unify the producer/consumer decision+knowledge format into one canonical contract and prove it with a capture→rebuild→grep→byte-assert round-trip oracle: append-decision.sh emits consumer-order so awk -F'|' $5=Scope/$6=When holds, the init-time DECISIONS.md header matches, the consumer comment describes the awk reality, and a flat ## K### knowledge entry survives kf_filter_stream and appears in the inject."
demo_sentence: "A decision appended by append-decision.sh on a Quick fixture, rebuilt, then resolved by filter_decisions, byte-equals the captured scope/choice fields (observed awk $5/$6 land on Scope/When); a flat ## K### entry passes kf_filter_stream and appears in the inject."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

### Truths

- `append-decision.sh` emits a row in canonical consumer-order so that `awk -F'|'` `$5`=Scope and `$6`=When (the observed indices the consumer reads — CON-6/#Q-1); the init-time empty `DECISIONS.md` header (`scaffold.sh`) matches the same canonical order; the `scope-filter.sh` `filter_decisions` column-map comment describes the awk reality; the awk at `:353-354` is unchanged. (FR-1 / SC-1)
  - Check: `bash tools/verify/m044-p02-t01-decision-format.sh`
- A decision captured by `append-decision.sh` scoped `M044/P01`, then resolved by `filter_decisions`, byte-equals the captured Scope/When/Choice fields (dynamic round-trip lane); the static byte-equality fixtures hold; the knowledge `append-knowledge.sh` ↔ `filter_knowledge` (`## K###`) round-trip resolves. (FR-1 / SC-1 / AC-1)
  - Check: `bash tools/verify/m044-p02-t03-roundtrip-oracle.sh`
- A flat `## K###` knowledge entry survives `kf_filter_stream` even when it follows a dropped frontmatter entry (entry-boundary detection), and a flat-only inject is never replaced by the `(no qualifying knowledge entries)` sentinel (wrapper empty-detection). (FR-2 / SC-7)
  - Check: `bash tools/verify/m044-p02-t02-flat-knowledge.sh`

### Artifacts

- `tools/verify/m044-p02-t01-decision-format.sh` (create — min 30 lines)
- `tools/verify/m044-p02-t02-flat-knowledge.sh` (create — min 30 lines)
- `tools/verify/m044-p02-t03-roundtrip-oracle.sh` (create — min 40 lines)
- `tools/verify/m044-p02-phase-suite.sh` (create — aggregator)
- `.orchestrator/milestones/M044/phases/P02/P02-SUMMARY.md` (create at phase close — min 20 lines)

### Key Links

- `scripts/dispatch/build-context.sh` → `scripts/dispatch/scope-filter.sh` (consumer calls `filter_decisions`/`filter_knowledge`, the contract endpoint the producer format must satisfy)
- `scripts/dispatch/build-context.sh` → `scripts/lib/knowledge-filter.sh` (consumer sources `kf_filter_stream`, whose flat-entry handling + the wrapper empty-detection gate the inject)

## Tasks

### T01: FR-1 decision format unification (one CI-checked change set)

Rewrite the DQ-6 loser (`append-decision.sh:93`) to emit consumer-order `| ID | Decision | Choice | Scope | When | Rationale | Revisable |` (same vars, reordered — no var renames). Rewrite the init-time empty `DECISIONS.md` header in `scripts/lifecycle/scaffold.sh:89` to the same canonical order. Correct the `scope-filter.sh:351` column-map comment to the awk reality (`$2`=ID `$3`=Decision `$4`=Choice `$5`=Scope `$6`=When `$7`=Rationale); leave the awk at `:353-354` unchanged (already correct). Update the `append-decision.sh` header docstring `Column order:` line to match. Flag-only (do NOT touch): `scripts/migrate/transform/decisions.sh` (external-tool migration, a third order) and this repo's own hand-maintained 7-col `category`-bearing `DECISIONS.md`. Forward-only: no migration of existing producer-order rows (they already never resolved — that IS B-3). Co-author `tools/verify/m044-p02-t01-decision-format.sh`. See `tasks/T01-decision-format-PLAN.md`.

### T02: FR-2 flat `## K###` knowledge passes the filter

Fix `scripts/lib/knowledge-filter.sh::kf_filter_stream` so a `## K###` heading at top level (outside frontmatter) is an entry boundary — flushing the prior entry before starting a new one — while the first `## ` heading immediately after a closing `---` fence stays bound to its own frontmatter entry (so superseded-entry drop semantics are preserved). Fix the wrapper empty-detection in `scripts/dispatch/build-context.sh::_bc_apply_knowledge_filter` and `scripts/dispatch/lib/section-handlers.sh::_sh_apply_knowledge_filter` so a flat-only filtered stream (no `^---$` fences) is not falsely reported empty and replaced by `(no qualifying knowledge entries)`. Confirm `append-knowledge.sh` (`- **[scope]** [date] text`) ↔ `filter_knowledge` (`## K###`) agree on the `## K###` shape — verify, do not rewrite unless divergent. Co-author `tools/verify/m044-p02-t02-flat-knowledge.sh`. See `tasks/T02-flat-knowledge-PLAN.md`.

### T03: AC-1 round-trip oracle + phase suite (SC-1 / SC-7)

Build the acceptance oracle: a **dynamic** lane (`mktemp -d` Quick fixture — `append-decision.sh` a `M044/P01`-scoped decision → `rebuild-index.sh` no-op-safe → `filter_decisions` → byte-assert the resolved row's awk `$5`/`$6` land on Scope/When, not Decision/Choice; parallel `append-knowledge.sh` ↔ `filter_knowledge`) split from the **static** byte-equality fixtures (frozen files, never carrying a runtime-appended row — per `feedback_fixtures_byte_equality_default`). Add the SC-7 flat-`## K###`-passes assertion. Build `tools/verify/m044-p02-phase-suite.sh` (copy P01's aggregator, retarget `m044-p02-*`). Co-author `tools/verify/m044-p02-t03-roundtrip-oracle.sh`. See `tasks/T03-roundtrip-oracle-PLAN.md`.

## Task Dependencies

```
T01 ─┐
     ├─► T03
T02 ─┘
```

- T01 (decision format) and T02 (flat knowledge) touch disjoint files and can be built in either order.
- T03 (round-trip oracle + suite) integrates both: the decision round-trip needs T01's canonical producer; the SC-7 flat assertion needs T02's filter fix.

## Files Likely Touched

- `scripts/knowledge/append-decision.sh` (modify — `:93` row + docstring column-order line)
- `scripts/lifecycle/scaffold.sh` (modify — `:89` init header)
- `scripts/dispatch/scope-filter.sh` (modify — `:351` comment only; awk unchanged)
- `scripts/lib/knowledge-filter.sh` (modify — `kf_filter_stream` `## ` entry-boundary detection)
- `scripts/dispatch/build-context.sh` (modify — `_bc_apply_knowledge_filter` empty-detection)
- `scripts/dispatch/lib/section-handlers.sh` (modify — `_sh_apply_knowledge_filter` empty-detection)
- `tools/verify/m044-p02-t01-decision-format.sh` (create)
- `tools/verify/m044-p02-t02-flat-knowledge.sh` (create)
- `tools/verify/m044-p02-t03-roundtrip-oracle.sh` (create)
- `tools/verify/m044-p02-phase-suite.sh` (create)
- `.orchestrator/milestones/M044/phases/P02/fixtures/**` (create — static byte-equality fixtures)
