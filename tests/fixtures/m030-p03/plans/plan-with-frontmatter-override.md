---
schema_version: "1.0"
type: task-plan
task: "T99"
phase: "P99"
milestone: "M999"
name: "P03 fixture: plan with model_override=smart frontmatter (mechanical body)"
model_override: "smart"
---

# Fixture plan: model_override=smart + mechanical body signature

This plan is a fixture input for `tools/verify/p03-override-source-enum.sh`
(Scenario C) and `tools/verify/p03-sc6-frontmatter-override.sh` (T03).

The frontmatter declares `model_override: smart`. The body matches the
mechanical-classifier signature: `## Steps` block with explicit file paths +
bash verifiers, ≤3 file targets, unambiguous `## Verification` block. The
classifier alone returns `character=mechanical`; T02's override-resolution
path applies the `model_override` frontmatter value to route the dispatch
to the smart tier with `override_source=plan_frontmatter`.

Do NOT edit the embedded `M999`/`P99`/`T99` markers in the path or the
`model_override: smart` frontmatter line — both are load-bearing for the
SC-6 contract.

## Steps

1. Touch `tests/fixtures/m030-p03/output-a.txt` with the literal string `a`.
2. Touch `tests/fixtures/m030-p03/output-b.txt` with the literal string `b`.
3. Touch `tests/fixtures/m030-p03/output-c.txt` with the literal string `c`.

## Verification

```bash
bash tools/verify/p03-override-source-enum.sh
```
