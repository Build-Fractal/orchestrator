---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M024"
goal: "Foundation — input-shape detector + 6-axis proposal artifact schema"
demo_sentence: "On any input, `evaluate` emits `.orchestrator/intake/<id>/proposal.md` with all six axes populated and frontmatter passing the M014-manifest superset assertion."
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

- A 6-axis proposal template exists at `templates/intake-proposal.md` with frontmatter containing exactly the keys named below (no more, no fewer).
  - Check: `bash scripts/verify/m024-p01-template-frontmatter.sh`
- The input-shape detector classifies any string into exactly one of `idea | paragraph | fragment | spec | empty` via mechanical word-count + structural rules.
  - Check: `bash scripts/verify/m024-p01-shape-detector.sh`
- Intake-id allocation is counter-based when no spec path is supplied (AD-2: `intake/<NNN>-<short-slug>` where `<NNN>` = max-existing + 1) and reuses the spec slug when a spec path is supplied (FR-11).
  - Check: `bash scripts/verify/m024-p01-intake-id-allocate.sh`
- The proposal emitter writes a complete proposal.md whose frontmatter contains all six axes plus required metadata, and whose body has six per-axis sections each citing at least one evidence pointer (FR-13, with the `no-evidence — operator-supplied` honest fallback when no evidence is available).
  - Check: `bash scripts/verify/m024-p01-proposal-emit.sh`
- The proposal-shape phase test (SC-7) and the M014-manifest-superset phase test (SC-8 / FR-15 / DC-5) both exit 0.
  - Check: `bash scripts/verify/m024-p01-suite.sh`
- The `.orchestrator/intake/<id>/` directory layout is the only location M024 P01 writes to (SB-3 confined-writes invariant).
  - Check: `bash scripts/verify/m024-p01-write-confinement.sh`
- Proposal frontmatter pins `schema_version: "1.0"` (AD-3) — the same key spec frontmatter uses; no `intake_schema_version` field is introduced.
  - Check: `bash scripts/verify/m024-p01-schema-version.sh`

### Artifacts

- templates/intake-proposal.md (min 80 lines, contains "input_shape")
- scripts/intake/shape-detect.sh (min 60 lines, contains "paragraph")
- scripts/intake/intake-id-allocate.sh (min 40 lines, contains "intake")
- scripts/intake/proposal-emit.sh (min 100 lines, contains "schema_version")
- tests/test-intake-proposal-shape.sh (min 50 lines, contains "input_shape")
- tests/test-intake-manifest-superset.sh (min 40 lines, contains "superset")
- tests/fixtures/m014-interim-manifest-keys.txt (min 5 lines, contains "schema_version")
- scripts/verify/m024-p01-template-frontmatter.sh (min 20 lines, contains "input_shape")
- scripts/verify/m024-p01-shape-detector.sh (min 30 lines, contains "paragraph")
- scripts/verify/m024-p01-intake-id-allocate.sh (min 30 lines, contains "intake")
- scripts/verify/m024-p01-proposal-emit.sh (min 30 lines, contains "axes")
- scripts/verify/m024-p01-suite.sh (min 15 lines, contains "test-intake")
- scripts/verify/m024-p01-write-confinement.sh (min 15 lines, contains "intake")
- scripts/verify/m024-p01-schema-version.sh (min 10 lines, contains "1.0")

### Key Links

- scripts/intake/proposal-emit.sh → templates/intake-proposal.md (emitter renders this template)
- scripts/intake/proposal-emit.sh → scripts/intake/shape-detect.sh (emitter calls the detector)
- scripts/intake/proposal-emit.sh → scripts/intake/intake-id-allocate.sh (emitter calls the allocator)
- tests/test-intake-proposal-shape.sh → scripts/intake/proposal-emit.sh (test invokes emitter end-to-end)
- tests/test-intake-manifest-superset.sh → tests/fixtures/m014-interim-manifest-keys.txt (test reads the fixture)

## Tasks

### T01: Author the 6-axis proposal template

See `tasks/T01-PLAN.md`. Establishes the YAML frontmatter contract (schema_version pinned at 1.0 per AD-3, exactly the keys named in T01) plus the body section skeleton for the six per-axis rationale blocks. Pure markdown template — no shell logic. Forward-binding for every other phase per cross-cutting concern AD-3.

### T02: Author the intake-id allocator

See `tasks/T02-PLAN.md`. POSIX sh + bash 3.2 portable shell script implementing AD-2 counter allocation for non-spec inputs and FR-11 spec-slug reuse when a spec path is supplied. Single-purpose: emit one line `intake_id=<value>` to stdout; write nothing. Test fixtures live in `/tmp` per task.

### T03: Author the input-shape detector

See `tasks/T03-PLAN.md`. POSIX sh + bash 3.2 portable. Resolves `#Q-1` with concrete mechanical thresholds: spec path (file exists + ends `.md` + `frontmatter has type: feature-spec`) → `spec`; empty argument → `empty`; word-count ≤10 → `idea`; 11–80 → `paragraph`; ≥81 OR contains `Given/When/Then` skeleton OR contains `## ` headers OR `^##? FR-` markers → `fragment`. Emits `input_shape=<value>` and `confidence=<high|low>` to stdout (low when only the catch-all `paragraph` rule fires on a string with no other signals).

### T04: Author the proposal emitter

See `tasks/T04-PLAN.md`. Wires T01 + T02 + T03: detect shape → allocate id → populate axis stubs (Tier from existing `scripts/state/spec-metrics.sh`-style heuristic for shape `spec`, Tier A stub otherwise; Intensity from `scripts/engine/intensity-recommend.sh`; conversus_gate / design_gate / decomposition default to `none / none / single-task` for stubs — full per-axis decision logic lands in subsequent phases). Writes `.orchestrator/intake/<id>/proposal.md` from the template. Emits the proposal path to stdout. P01 stubs do not need to make sophisticated tier/conversus/design recommendations — they must produce a structurally complete file that downstream phases will deepen.

### T05: Author the two phase-level tests + the M014 manifest fixture

See `tasks/T05-PLAN.md`. `tests/test-intake-proposal-shape.sh` — invokes the emitter with three inputs (paragraph, idea, spec-path), greps each output for the seven required frontmatter keys plus the six axis-rationale section headings. `tests/test-intake-manifest-superset.sh` — reads `tests/fixtures/m014-interim-manifest-keys.txt` (the M014 manifest key set, captured at plan-phase time per AD-4 direction `a`), invokes the emitter, parses the proposal frontmatter keys, and asserts strict containment (every M014 key appears; the proposal additionally contains the six axes). Both follow `tests/test-knowledge-query.sh` pass/fail style (MEM002 conventions — parallel arrays, structured `PASS:`/`FAIL:` summary).

## Task Dependencies

```
T01 → T02
T01 → T03    (T02 and T03 can run in parallel)
T01 + T02 + T03 → T04
T04 → T05
```

T01 (template) is the schema contract every later task conforms to. T02 (id-allocate) and T03 (shape-detect) are pure, file-disjoint, and parallelizable once T01 lands. T04 (emitter) integrates all three. T05 (tests) exercises T04 end-to-end.

## Files Likely Touched

- templates/intake-proposal.md (create)
- scripts/intake/shape-detect.sh (create)
- scripts/intake/intake-id-allocate.sh (create)
- scripts/intake/proposal-emit.sh (create)
- tests/test-intake-proposal-shape.sh (create)
- tests/test-intake-manifest-superset.sh (create)
- tests/fixtures/m014-interim-manifest-keys.txt (create)
- scripts/verify/m024-p01-template-frontmatter.sh (create)
- scripts/verify/m024-p01-shape-detector.sh (create)
- scripts/verify/m024-p01-intake-id-allocate.sh (create)
- scripts/verify/m024-p01-proposal-emit.sh (create)
- scripts/verify/m024-p01-suite.sh (create)
- scripts/verify/m024-p01-write-confinement.sh (create)
- scripts/verify/m024-p01-schema-version.sh (create)
