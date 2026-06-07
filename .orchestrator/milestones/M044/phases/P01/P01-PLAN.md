---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M044"
goal: "Land the fail-loud, index-free-capable activation floor: one canonical index/db path resolver, a degraded-aware consumer with a deterministic grep-over-raw fallback + always-on provenance header, inject-size + 0-MEM observability, and one consolidated doctor knowledge-activation check."
demo_sentence: "With an empty/missing/stale index over a populated raw corpus, build-context.sh injects relevant entries via deterministic grep, stamps a provenance header, and emits a degradation WARNING; a 0-MEM inject on a mature project warns; orchestrator:doctor reports one consolidated 3-symptom knowledge-activation check."
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

- The canonical index/db path resolver is defined exactly once and every in-scope reader routes through it (FR-11 / SC-12).
  - Check: `bash tools/verify/m044-p01-t01-canonical-path.sh`
- `build-context.sh` no longer resolves `KNOWLEDGE-INDEX.md` via a hardcoded path join (the vestigial `:178` + `:462-465` divergences are gone) (FR-11).
  - Check: `bash tools/verify/m044-p01-t01-no-vestigial-path.sh`
- With an empty/missing/stale index over a populated raw corpus, the payload carries `source: grep-fallback` (or `degraded`), a degradation WARNING, and relevant entries resolved by deterministic grep over raw `knowledge/**/*.md` (FR-5 / SC-5).
  - Check: `bash tools/verify/m044-p01-t02-failloud-fallback.sh`
- The grep fallback is deterministic (same inputs → byte-identical provenance/fallback artifact; `LC_ALL=C`, stable order, no wall-clock) and bounded by the M036a token governor (FR-5 / SC-6 / CON-2/CON-3).
  - Check: `bash tools/verify/m044-p01-t02-determinism-budget.sh`
- The provenance header is always present in the payload (even on a healthy `source: index`) and pins `provenance_version: 1` (FR-5 / DQ-4 / #Q-4).
  - Check: `bash tools/verify/m044-p01-t02-provenance-always.sh`
- The payload surfaces inject size (`knowledge: N MEMs / X tokens`) and a 0-MEM inject on a project with prior milestones/decisions on disk emits a visible warning (FR-15 / SC-10).
  - Check: `bash tools/verify/m044-p01-t03-zeromem-warning.sh`
- `orchestrator:doctor` reports a single consolidated `DOCTOR:KNOWLEDGE_ACTIVATION` check covering the three symptoms (0-MEM-on-mature / vestigial-index / runtime-memory-divergence); no second overlapping doctor surface exists (FR-15 / FR-9-enforcement / SC-11 / CON-5).
  - Check: `bash tools/verify/m044-p01-t04-consolidated-doctor.sh`

### Artifacts

- `scripts/dispatch/lib/knowledge-provenance.sh` (create — min 60 lines, contains "provenance_version")
- `scripts/diagnostics/check-knowledge-activation.sh` (create — min 60 lines, contains "DOCTOR:KNOWLEDGE_ACTIVATION")
- `.orchestrator/milestones/M044/phases/P01/P01-SUMMARY.md` (create at phase close — min 20 lines)

### Key Links

- `scripts/dispatch/build-context.sh` → `scripts/dispatch/lib/knowledge-provenance.sh` (consumer sources the provenance/fallback lib)
- `scripts/dispatch/build-context.sh` → `scripts/knowledge/lib/index-utils.sh` (consumer routes index-path resolution through `get_index_path`)
- `commands/doctor.md` → `scripts/diagnostics/check-knowledge-activation.sh` (doctor wires the consolidated check)

## Tasks

### T01: Canonical index/db path resolver consolidation (FR-11)

Route every in-scope index/db reader through the single `get_index_path()` (`scripts/knowledge/lib/index-utils.sh:39`) / `get_db_path()` (`scripts/knowledge/lib/graph-db.sh:29`). Replace `build-context.sh`'s two vestigial hardcoded resolutions (`:178` `$_M031_PROJECT_ROOT/KNOWLEDGE-INDEX.md`; `:462-465` `$PROJECT_ROOT`/`$MILESTONE_DIR` joins) with a sourced `get_index_path` call that honors the dispatch-time project-root override. Document the canonical location in `references/` (one line) and the resolver docstring. Co-author `tools/verify/m044-p01-t01-canonical-path.sh` (asserts exactly one `get_index_path()` + one `get_db_path()` definition) and `m044-p01-t01-no-vestigial-path.sh` (asserts no hardcoded `KNOWLEDGE-INDEX.md` path-join survives in build-context.sh). See `tasks/T01-canonical-path-resolver-PLAN.md`.

### T02: Fail-loud consumer + index-free grep fallback + provenance header (FR-5)

Create `scripts/dispatch/lib/knowledge-provenance.sh` exposing: `kp_index_state <index_path> <knowledge_dir>` (echoes `present|empty|missing|stale` via mtime vs newest `knowledge/**/*.md` — #Q-2 mtime), `kp_grep_fallback <knowledge_dir> <touched_files> <budget_tokens>` (deterministic `LC_ALL=C` grep over raw files, routed through `reference_apply_budget` from `scripts/dispatch/lib/reference-budget.sh`), and `kp_emit_header <source> <index_age> <entries_considered>` (byte-stable `knowledge_provenance:` block with `provenance_version: 1`). Wire into `build-context.sh`: replace the silent `head -5` (`:208`) and add the always-on header + WARNING (payload + stderr). Co-author the T02 verifiers. See `tasks/T02-failloud-fallback-provenance-PLAN.md`.

### T03: Inject-size surface + 0-MEM-on-mature-project warning (FR-15 part 1)

In `build-context.sh`, surface `knowledge: N MEMs / X tokens` in the payload + stderr, and WARN when `N == 0` AND the project is mature (prior `.orchestrator/milestones/M*/` with a SUMMARY, or non-empty `DECISIONS.md`). Co-author `m044-p01-t03-zeromem-warning.sh`. See `tasks/T03-inject-size-zeromem-warning-PLAN.md`.

### T04: Consolidated doctor knowledge-activation check (FR-15 part 2 + FR-9-enforcement)

Create `scripts/diagnostics/check-knowledge-activation.sh` emitting one `DOCTOR:KNOWLEDGE_ACTIVATION status=ok|warn|fail` line covering three symptoms: (1) 0-MEM-on-mature-project, (2) vestigial/divergent index path, (3) runtime-memory-divergence (decisions present in `execution-log.jsonl`/summaries but `DECISIONS.md`/`KNOWLEDGE-INDEX.md` empty). Wire into `commands/doctor.md` + `scripts/diagnostics/run-doctor.sh`. Annotate `papercut-doctor-knowledge-gap-surface.md` "reconciled into M044/FR-15" (#Q-3). Co-author `m044-p01-t04-consolidated-doctor.sh`. See `tasks/T04-consolidated-doctor-check-PLAN.md`.

### T05: Fixtures + determinism/budget regression + phase suite (SC-5/SC-6/SC-10/SC-11/SC-12)

Build the integration fixtures (empty/stale/missing-index + populated-corpus project; mature-0-MEM project) under `.orchestrator/milestones/M044/fixtures/`, the determinism+budget regression (`m044-p01-t02-determinism-budget.sh`), and the phase-suite aggregator `tools/verify/m044-p01-phase-suite.sh`. See `tasks/T05-fixtures-regression-suite-PLAN.md`.

## Task Dependencies

```
T01 → T02 → T03 → T05
        ↘   ↘
         T04 → T05
```

- T01 (path resolver) lands first — T02/T03/T04 all consume the canonical resolver.
- T02 (fallback + provenance lib) precedes T03 (inject-size reads the same resolved MEM set) and T04 (doctor's vestigial-index symptom reuses T01's resolver assertion + T02's state probe).
- T05 integrates all four (fixtures + determinism/budget + aggregator).

## Files Likely Touched

- `scripts/dispatch/lib/knowledge-provenance.sh` (create)
- `scripts/diagnostics/check-knowledge-activation.sh` (create)
- `scripts/dispatch/build-context.sh` (modify — FR-11 path, FR-5 fallback/provenance/WARNING, FR-15 inject-size/0-MEM)
- `scripts/knowledge/lib/index-utils.sh` (modify — resolver docstring / canonical-location note only)
- `commands/doctor.md` (modify — wire the consolidated check)
- `scripts/diagnostics/run-doctor.sh` (modify — invoke the consolidated check)
- `references/knowledge-management.md` (modify — document the canonical index/db path; the index-as-cache / fail-loud contract)
- `.orchestrator/proposals/papercut-doctor-knowledge-gap-surface.md` (modify — one-line "reconciled into M044/FR-15" annotation)
- `tools/verify/m044-p01-t01-canonical-path.sh` (create)
- `tools/verify/m044-p01-t01-no-vestigial-path.sh` (create)
- `tools/verify/m044-p01-t02-failloud-fallback.sh` (create)
- `tools/verify/m044-p01-t02-determinism-budget.sh` (create)
- `tools/verify/m044-p01-t02-provenance-always.sh` (create)
- `tools/verify/m044-p01-t03-zeromem-warning.sh` (create)
- `tools/verify/m044-p01-t04-consolidated-doctor.sh` (create)
- `tools/verify/m044-p01-phase-suite.sh` (create)
- `.orchestrator/milestones/M044/fixtures/**` (create — fixture corpora)
