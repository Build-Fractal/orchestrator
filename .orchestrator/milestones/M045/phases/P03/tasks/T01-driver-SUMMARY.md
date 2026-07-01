---
schema_version: "1.0"
type: task-summary
task: "T01"
phase: "P03"
milestone: "M045"
name: "Author the process-fresh driver scripts/lifecycle/self-continue-drive.sh"
outcome: success
---

Authored `scripts/lifecycle/self-continue-drive.sh` — the outer loop that re-spawns a fresh `claude -p` auto segment per rotation-exit until terminal/cap/stop-file (FR-2/4/5/5a/6, D015). Consults `self-continue-branch.sh` for the armed×capable decision; reads `<milestone-dir>/.self-continue-outcome`. `progress=` increments only on phase change (thrash detection). Smoke-tested hermetically (stub rotate-once-then-complete → one SCHEDULED then TERMINAL outcome=complete). Executable.
