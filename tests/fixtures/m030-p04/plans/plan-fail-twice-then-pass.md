---
schema_version: "1.0"
type: task-plan
task: "T97"
phase: "P99"
milestone: "M999"
name: "P04 fixture: plan-fail-twice-then-pass (mechanical body, SC-4 demo)"
---

# Fixture plan: SC-4 verifier-fail auto-escalation demo input

This plan is a fixture input for `tools/verify/p04-sc4-escalation.sh`
(T03 deliverable). The body signature is mechanical (explicit `## Steps`
with file paths + bash verifier). Used in conjunction with the
`stub-fail-n` adapter and a counter file pre-seeded to `2`: the first
two invocations exit 1 (verifier-fail signal), the third (escalated)
invocation exits 0. The `stub-fail-n` invocation count proves SC-4's
"fail twice, escalate, pass" contract.

The mechanical body signature ensures the classifier returns
`character=mechanical` (routing-table default tier=fast pre-escalation).
The escalation ladder (defined in T03) walks fast -> balanced -> smart
on each adapter failure, capped at two escalations per CON-5.

Do NOT edit the embedded `M999`/`P99`/`T97` markers; they tag this plan
as the SC-4 demo input.

## Steps

1. Touch `tests/fixtures/m030-p04/output-a.txt` with the literal string `a`.
2. Touch `tests/fixtures/m030-p04/output-b.txt` with the literal string `b`.
3. Touch `tests/fixtures/m030-p04/output-c.txt` with the literal string `c`.

## Verification

```bash
bash tools/verify/p04-sc4-escalation.sh
```
