---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M044"
---

# T03 — AC-1 round-trip oracle + phase suite (SC-1 / SC-7)

## Zero-context summary

AC-1 is the acceptance oracle for BUG-A: a capture→rebuild→grep→byte-assert
round-trip over the legacy `append-decision.sh` / `append-knowledge.sh` primitives
on a **default-intensity (Quick)** fixture, byte-asserting the resolved row (not
substring — per `feedback_fixtures_byte_equality_default`). The **dynamic** lane
(runtime-appended row) is split from the **static** byte-equality fixtures (a
frozen file is never forced to contain a runtime-appended row).

## Steps

1. `tools/verify/m044-p02-t03-roundtrip-oracle.sh`:
   - **Dynamic decision lane:** `mktemp -d` fixture with a consumer-order
     `DECISIONS.md` header → `append-decision.sh` a decision with WHEN=`M044/P01`,
     SCOPE=`arch`, known DECISION/CHOICE/RATIONALE → source `scope-filter.sh`,
     run `filter_decisions` for milestone `M044` phase `P01` → byte-assert the
     resolved row's `awk -F'|'` `$5` == `arch` (Scope) and `$6` == `M044/P01` (When),
     and that the appended row is present in the filtered output. This proves the
     producer writes what the consumer reads.
   - **Dynamic knowledge lane:** a flat `## K###` fixture KNOWLEDGE.md →
     `filter_knowledge` for the in-scope milestone/phase → assert the `## K###`
     entry resolves (and a `[project]` entry resolves project-wide).
   - **Static byte-equality fixture:** a frozen consumer-order `DECISIONS.md`
     under `phases/P02/fixtures/` → `filter_decisions` output byte-equals a frozen
     `expected` file (no runtime append into the frozen file).
   - **SC-7 flat passes:** a flat `## K###` stream through `kf_filter_stream` +
     the wrapper empty-detection → asserts no `(no qualifying knowledge entries)`.
2. `tools/verify/m044-p02-phase-suite.sh` — copy `m044-p01-phase-suite.sh`,
   retarget the glob to `tools/verify/m044-p02-*.sh`. Emits `BATTERY: pass=N fail=0`.
3. Static fixtures under `.orchestrator/milestones/M044/phases/P02/fixtures/`:
   `decisions-consumer-order.md` (frozen input) + `decisions-expected.md` (frozen
   filter_decisions output for a fixed scope).

## Determinism (CON-3)

`filter_decisions` / `filter_knowledge` are deterministic line filters (no
wall-clock, stable order). The dynamic lane stamps no timestamp into the asserted
row body. `rebuild-index.sh` (if invoked) is a no-op-safe step in the round-trip
(the append-register proof is the filter resolution, not the index).

## Verifier

This task IS the verifier set. Done when:
- `bash tools/verify/m044-p02-t03-roundtrip-oracle.sh` → `PASS:`
- `bash tools/verify/m044-p02-phase-suite.sh` → `BATTERY: pass=N fail=0`
