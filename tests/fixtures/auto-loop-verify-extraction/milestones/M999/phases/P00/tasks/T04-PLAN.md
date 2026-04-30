---
schema_version: "1.0"
type: task-plan
id: T04
phase: P00
milestone: M999
---

## Task

Bare-backtick bullet shape under `## Verification` — the entire bullet body is a
single backtick-wrapped command with no `Check:` prefix. Earlier the parser
silently dropped these and reported AUTO:VERIFY_NO_CHECKS; the fix accepts the
shape per the no-checks-found error message's documented contract.

## Verification

- `echo bare-backtick-pass`
- `echo bare-backtick-pass-2`
