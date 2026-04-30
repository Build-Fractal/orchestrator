---
schema_version: "1.0"
type: task-plan
task: "T99"
phase: "P99"
milestone: "M999"
name: "P04 fixture: plan with no model_override (mechanical body)"
---

# Fixture plan: no model_override + mechanical body signature

This plan is a fixture input for `tools/verify/p04-override-source-enum-extended.sh`
(Scenario F — live + empty corpus path) and the partial-flip routing demo
in P04/T02. The classifier returns `character=mechanical`. No
`model_override:` frontmatter; the live-mode override-resolution path
either shadow-gate-blocks (Scenario F, empty corpus) or routes per the
routing-table default (mechanical -> fast).

The path under `tests/fixtures/m030-p04/plans/` distinguishes this fixture
from the path-equivalent P03 plan; the unitId markers `M999`/`P99`/`T99`
are intentionally identical (load-bearing only at the path level — the
verifier engages the ORCH_ROOT/phases/ carve-out so unitId extraction
is a non-issue).

Do NOT edit the embedded `M999`/`P99`/`T99` markers — they mirror the
P03 fixtures by design.

## Steps

1. Touch `tests/fixtures/m030-p04/output-a.txt` with the literal string `a`.
2. Touch `tests/fixtures/m030-p04/output-b.txt` with the literal string `b`.
3. Touch `tests/fixtures/m030-p04/output-c.txt` with the literal string `c`.

## Verification

```bash
bash tools/verify/p04-override-source-enum-extended.sh
```
