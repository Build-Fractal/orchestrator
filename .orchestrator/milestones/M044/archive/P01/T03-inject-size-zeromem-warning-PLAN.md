---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M044"
name: "Inject-size surface + 0-MEM-on-mature-project warning (FR-15 part 1)"
depends_on: ["T02"]
---

## Prerequisites

- T02 complete: `build-context.sh` computes a resolved MEM/entry set and emits a provenance header with `entries_considered`.
- `_M031_MEM_COUNT` already exists in `build-context.sh:210` (count of resolved MEM ids).

## Description

FR-15 (part 1) / SC-10: surface inject size everywhere (`knowledge: N MEMs / X tokens`) and WARN when an inject resolves to 0 MEMs on a project that already has milestones/decisions on disk (mature). A 0-MEM inject on a brand-new project is normal and must NOT warn; only mature projects warn (the original month-long silent-degradation incident was a mature project).

## Steps

1. In `build-context.sh`, after the resolved entry set is known, compute `X tokens` as a stable estimate over the injected knowledge body (reuse the T02 token estimator; same `wc -w`-based stable formula). Emit `knowledge: N MEMs / X tokens` into the payload (under `## Knowledge`, adjacent to the provenance header) AND to stderr.
2. Add a maturity probe `_M044_is_mature`: true when either (a) `.orchestrator/milestones/M*/` contains ≥1 directory with a `*-SUMMARY.md`, or (b) `.orchestrator/DECISIONS.md` exists with ≥1 `^| D[0-9]` data row. Use the dispatch root (`_M031_PROJECT_ROOT`).
3. When `N == 0` AND `_M044_is_mature` is true, emit `WARNING: 0-MEM inject on a project with prior milestones/decisions on disk — knowledge may not be activating (run: orchestrator:doctor)` to stderr AND into the payload `## Knowledge` section. (This composes with the T02 degraded WARNING but is distinct: T02 warns on a bad *index*; T03 warns on a 0-result *inject* even when the index looked healthy.)
4. Author `tools/verify/m044-p01-t03-zeromem-warning.sh`: drive `build-context.sh` against (a) a mature fixture forced to 0 MEMs ⇒ assert the warning string present; (b) a fresh (non-mature) fixture at 0 MEMs ⇒ assert the warning string ABSENT; (c) any inject ⇒ assert `knowledge: N MEMs` line present. Emit `PASS:`/`FAIL:`.

## Must-Haves

- FR-15 part 1 / SC-10: inject-size surface always; 0-MEM warning on mature projects only.

## Verification

`bash tools/verify/m044-p01-t03-zeromem-warning.sh`

## Inputs

### From Previous Tasks
- `scripts/dispatch/build-context.sh` (from T02)
  - Key API: `_M031_MEM_COUNT` (resolved MEM count); the T02 token estimator; `kp_emit_header`.

### From Disk (Pre-existing)
- `.orchestrator/milestones/M*/*-SUMMARY.md`, `.orchestrator/DECISIONS.md` — maturity signals.

## Constraints

- The 0-MEM warning fires ONLY on mature projects (no false alarm on greenfield). Bash 3.2. CON-3: no wall-clock; the `X tokens` estimate is a stable function of content. Surgical edit — reuse the T02 estimator, do not introduce a second token-counting path.

## Expected Output

Every inject shows `knowledge: N MEMs / X tokens`; a mature 0-MEM inject warns; a fresh 0-MEM inject does not. Verifier emits `PASS:`.

## Notes

- Expected verifier output: `PASS: ...`, exit 0.
