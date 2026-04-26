---
schema_version: "1.0"
type: task-summary
id: T03
parent: M024/P01
task: T03
phase: P01
milestone: M024
outcome: success
verification_result: pass
---

# T03 — Author the input-shape detector

## Files Created

- `scripts/intake/shape-detect.sh` (executable) — mechanical FR-1 input-shape classifier with `idea | paragraph | fragment | spec | empty` enum and `high | low` confidence.
- `scripts/verify/m024-p01-shape-detector.sh` (executable) — exercises six canonical cases (spec, empty, idea, paragraph, fragment-gwt, fragment-heading).

## Verification

```
$ bash scripts/verify/m024-p01-shape-detector.sh
PASS: shape-detect.sh — spec, empty, idea, paragraph, fragment-gwt, fragment-heading
```
