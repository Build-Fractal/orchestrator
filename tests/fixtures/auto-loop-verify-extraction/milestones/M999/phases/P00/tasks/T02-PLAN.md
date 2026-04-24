---
schema_version: "1.0"
type: task-plan
id: T02
phase: P00
milestone: M999
---

## Task

Demo task where one Check command intentionally fails, to assert FAIL emission.

## Must-Haves

- Passing must-have
  - Check: `echo this-passes`
- Failing must-have
  - Check: `false`
