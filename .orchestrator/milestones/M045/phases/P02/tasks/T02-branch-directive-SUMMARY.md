---
schema_version: "1.0"
type: task-summary
task: "T02"
phase: "P02"
milestone: "M045"
name: "Author scripts/lifecycle/self-continue-branch.sh (deterministic directive) + SC-5 truth-table"
outcome: success
---

Authored `scripts/lifecycle/self-continue-branch.sh` (FR-3): given the rotation-
monitor status + `--armed` + `headless_reentry` capability, emits exactly one
directive — `AUTO:SELF_CONTINUE substrate=process-fresh` (rotation ∧ armed ∧
headless), `AUTO:ROTATE_EXIT reason=not-armed|headless-unavailable` (rotation,
otherwise), or `AUTO:NO_ROTATION`. Substrate-agnostic; policy in shell
(Principle X), agent only acts on the directive. Reads the capability from
`detect-capabilities.sh` (or `--capabilities-file` / `--headless` for tests).
SC-5 verifier `tools/verify/m045-p02-branch-truth-table.sh` drives all 5
truth-table rows hermetically (explicit `--headless`) — PASS.
