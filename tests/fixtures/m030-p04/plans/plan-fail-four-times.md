---
schema_version: "1.0"
type: task-plan
task: "T96"
phase: "P99"
milestone: "M999"
name: "P04 fixture: plan-fail-four-times (CON-5 hard-cap demo)"
---

# Fixture plan: CON-5 escalation-cap-is-hard demo input

This plan is a fixture input for `tools/verify/p04-con5-hard-cap.sh`
(T03 deliverable). The body signature is mechanical. Used with the
`stub-fail-n` adapter and a counter file pre-seeded to `4`: the dispatcher
invokes the adapter, sees exit 1, escalates (1st escalation), invokes
again, sees exit 1, escalates (2nd escalation), invokes again, sees exit 1,
HARD-FAILS. The fourth pre-seeded failure remains untouched on disk —
proof that the cap is hard, not soft.

The `STUB_FAIL_COUNTER_INVOCATIONS_FILE` env var captures one append per
invocation. The CON-5 verifier asserts the file contains exactly 3 lines
(NOT 4), proving the cap was honored.

Do NOT edit the embedded `M999`/`P99`/`T96` markers; the unitId is shared
with `plan-fail-three-times.md` by design (path-distinct fixtures, shared
unitId — the per-test counter is the load-bearing assertion).

## Steps

1. Touch `tests/fixtures/m030-p04/output-a.txt` with the literal string `a`.
2. Touch `tests/fixtures/m030-p04/output-b.txt` with the literal string `b`.
3. Touch `tests/fixtures/m030-p04/output-c.txt` with the literal string `c`.

## Verification

```bash
bash tools/verify/p04-con5-hard-cap.sh
```
