---
schema_version: "1.0"
type: roadmap
milestone: "M013"
name: "GitHub native integration (fixture)"
current_phase: "P02"
phases:
  - id: "P02"
    name: "init + dry-run (fixture)"
    state: "in-flight"
  - id: "P03"
    name: "live projection (fixture)"
    state: "planning"
---

# M013 Roadmap (fixture — tests only)

This is a minimal roadmap used by `tests/fixtures/m013-p02/` to exercise
the M013/P02 dry-run manifest walker with zero live `gh` calls.

- P02: in-flight with two tasks (T01, T02). Must project.
- P03: planning-state with zero tasks. Must NOT project per AS-4a.
