---
schema_version: "1.0"
type: task-plan
task: "T99"
phase: "P99"
milestone: "M999"
name: "P03 fixture: plan with model_override=fast (vs milestone-floor smart)"
model_override: "fast"
---

# Fixture plan: model_override=fast + mechanical body (override-vs-floor case)

This plan is a fixture input for `tools/verify/p03-override-conflict.sh`
(T03 deliverable). The frontmatter declares `model_override: fast` while a
typical operator-overlay declares `min_tier: smart`; the precedence rule
under T02 is: plan_frontmatter wins over milestone_floor for tier choice
EXCEPT when min_tier would force a higher floor. The exact precedence
semantics are T02's responsibility; T01 only ships the fixture so the
later verifier has stable inputs.

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
