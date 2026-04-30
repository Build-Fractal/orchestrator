---
schema_version: "1.0"
type: task-plan
task: "T96"
phase: "P99"
milestone: "M999"
name: "P04 fixture: plan-fail-three-times (mechanical body, SC-5 cap demo)"
---

# Fixture plan: SC-5 escalation-hard-cap demo input

This plan is a fixture input for `tools/verify/p04-sc5-cap.sh`
(T03 deliverable). The body signature is mechanical. Used with the
`stub-fail-n` adapter and a counter file pre-seeded to `3`: the first
three invocations exit 1 (each one a verifier-fail signal); after the
second escalation the cap fires and dispatch surfaces a hard failure
(no fourth invocation). CON-5 proven: at most two escalations, total
adapter invocations ∈ {1, 2, 3}.

Per the SC-5 contract, the escalation ladder fast -> balanced -> smart
walks exactly twice on `stub-fail-n` exit-1 signals. After the third
exit-1, the dispatcher declares HARD_FAIL and does NOT invoke a fourth
escalation.

Do NOT edit the embedded `M999`/`P99`/`T96` markers; they tag this plan
as the SC-5 cap demo input. (The unitId is shared with `plan-fail-four-times.md`
intentionally — the load-bearing assertion is the stub-fail-n
invocation count file, not the unitId.)

## Steps

1. Touch `tests/fixtures/m030-p04/output-a.txt` with the literal string `a`.
2. Touch `tests/fixtures/m030-p04/output-b.txt` with the literal string `b`.
3. Touch `tests/fixtures/m030-p04/output-c.txt` with the literal string `c`.

## Verification

```bash
bash tools/verify/p04-sc5-cap.sh
```
