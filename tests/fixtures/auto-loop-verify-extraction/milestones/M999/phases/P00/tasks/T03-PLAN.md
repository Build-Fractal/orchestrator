---
schema_version: "1.0"
type: task-plan
id: T03
phase: P00
milestone: M999
---

## Task

M028/P01 dogfood regression fixture. The `## Verification` section contains
both a real executable check fence AND an `Expected output:` example fence.
The auto-loop verifier must run the real check and skip the example fence's
`PASS:`-prefixed body — otherwise it eval's `PASS:` as a literal command and
reports a false failure.

## Verification

```bash
echo verification-real-check
```

Expected output:

```
PASS: example-output-string-that-is-not-a-command
```

## Notes

End of plan.
