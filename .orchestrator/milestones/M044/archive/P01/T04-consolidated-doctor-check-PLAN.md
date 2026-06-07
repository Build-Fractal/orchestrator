---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M044"
name: "Consolidated doctor knowledge-activation check (FR-15 part 2 + FR-9-enforcement)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: canonical `get_index_path`/`get_db_path` available (the vestigial-index symptom reuses the resolver).
- `scripts/diagnostics/run-doctor.sh` exists and aggregates `DOCTOR:<NAME> status=ok|warn|fail` emitting checks; `commands/doctor.md` documents the check roster.
- No `scripts/diagnostics/check-knowledge*.sh` exists (confirmed 2026-06-07 — forward-clean; no test asserts an old surface).

## Description

FR-15 (part 2) / FR-9-enforcement / SC-11 / CON-5: one consolidated `DOCTOR:KNOWLEDGE_ACTIVATION` check reporting three symptoms, reconciling `papercut-doctor-knowledge-gap-surface.md` into a single surface (no second overlapping doctor check). Symptoms:
1. **0-MEM-on-mature-project** — project is mature (≥1 milestone SUMMARY or non-empty DECISIONS.md) but `KNOWLEDGE-INDEX.md` has zero `MEM[0-9]` entries.
2. **vestigial/divergent index path** — more than one on-disk `KNOWLEDGE-INDEX.md` under the project root in divergent locations, OR an index reader resolving a path other than `get_index_path`.
3. **runtime-memory-divergence** — `execution-log.jsonl` `note` fields (or `*-SUMMARY.md`) contain decision-shaped content while `DECISIONS.md` is empty/absent (decisions landed somewhere dispatch never reads).

## Steps

1. Create `scripts/diagnostics/check-knowledge-activation.sh` (bash 3.2, sources `index-utils.sh` for `get_index_path`). Resolve the project root (4-rule resolver / `$PWD`). Compute the three symptom booleans deterministically (file-based; no SQL — keeps the real-DB rule satisfied). Aggregate: `fail` if symptom 1 (the load-bearing silent-degradation case), else `warn` if symptom 2 or 3, else `ok`. Emit per-symptom detail lines then `DOCTOR:KNOWLEDGE_ACTIVATION status=<s> symptoms=<csv-or-none>`.
2. Wire into `scripts/diagnostics/run-doctor.sh` (add the check to the roster) and document it in `commands/doctor.md` under the checks section.
3. Annotate `.orchestrator/proposals/papercut-doctor-knowledge-gap-surface.md` with a one-line header note: `> **Reconciled into M044/FR-15 (2026-06-07).** The negative-space KNOWLEDGE_GAP density check, if shipped, MUST land as an additional symptom under the single \`DOCTOR:KNOWLEDGE_ACTIVATION\` surface — never as a parallel doctor check (CON-5).`
4. Author `tools/verify/m044-p01-t04-consolidated-doctor.sh`: assert exactly one knowledge-activation doctor surface exists (`grep -rl 'DOCTOR:KNOWLEDGE' scripts/diagnostics/` returns exactly `check-knowledge-activation.sh`); drive the check against a mature-empty fixture ⇒ `status=fail symptoms` includes `0-mem-on-mature`; against a healthy fixture ⇒ `status=ok`. Emit `PASS:`/`FAIL:`.

## Must-Haves

- FR-15 part 2 / FR-9-enforcement / SC-11 / CON-5: single consolidated 3-symptom check; papercut reconciled; no second surface.

## Verification

`bash tools/verify/m044-p01-t04-consolidated-doctor.sh`

## Inputs

### From Previous Tasks
- `scripts/knowledge/lib/index-utils.sh` (confirmed canonical in T01) — `get_index_path`.

### From Disk (Pre-existing)
- `scripts/diagnostics/run-doctor.sh` — doctor aggregator + `DOCTOR:<NAME> status=` convention.
- `commands/doctor.md` — check roster doc.
- `.orchestrator/proposals/papercut-doctor-knowledge-gap-surface.md` — reconciled.

## Constraints

- CON-5: exactly one knowledge-activation doctor surface. File-based symptom detection only (no SQL ⇒ real-DB rule N/A). Bash 3.2. Deterministic output (CON-3): symptom CSV in fixed order, no wall-clock.

## Expected Output

`orchestrator:doctor` reports one `DOCTOR:KNOWLEDGE_ACTIVATION` line; the papercut carries the reconciliation annotation; verifier emits `PASS:`.

## Notes

- Expected verifier output: `PASS: ...`, exit 0.
