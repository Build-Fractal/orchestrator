---
schema_version: "1.0"
type: task-plan
task: "T99"
phase: "P99"
milestone: "M999"
name: "P03 fixture: plan with no model_override (mechanical body)"
---

# Fixture plan: no model_override + mechanical body signature

This plan is a fixture input for `tools/verify/p03-override-source-enum.sh`
(Scenarios A, B, D, E). No `model_override` frontmatter; the classifier
alone returns `character=mechanical`. Used as the baseline plan against
the four overlay-config scenarios in T01's enum gate.

Do NOT edit the embedded `M999`/`P99`/`T99` markers in the path — they are
load-bearing for the round-trip dispatch's MILESTONE_ID extraction.

## Steps

1. Touch `tests/fixtures/m030-p03/output-a.txt` with the literal string `a`.
2. Touch `tests/fixtures/m030-p03/output-b.txt` with the literal string `b`.
3. Touch `tests/fixtures/m030-p03/output-c.txt` with the literal string `c`.

## Verification

```bash
bash tools/verify/p03-override-source-enum.sh
```
