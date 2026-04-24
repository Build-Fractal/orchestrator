---
type: task-plan
task: T02
phase: P00
---

## Verification

This phase has prose describing what to verify but no executable command lines —
neither inline backticks nor a fenced code block. The parser should hard-fail
rather than silently report checks_passed=0.

The author needs to add either an inline-backtick command on a Check line
or a fenced code block with bash commands.

Without that, this section is unverifiable.
