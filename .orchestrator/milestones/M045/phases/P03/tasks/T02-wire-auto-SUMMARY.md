---
schema_version: "1.0"
type: task-summary
task: "T02"
phase: "P03"
milestone: "M045"
name: "Wire commands/auto.md to the driver + pin the legacy golden (SC-4)"
outcome: success
---

Updated `commands/auto.md` `## Self-Continue` to the live launch contract (driver invocation + `.self-continue-outcome` marker emission at each exit path; additive, rotation-exit decision + legacy handoff unchanged, FR-8). Pinned `tests/fixtures/m045-rotation-exit-legacy.golden` and `tools/verify/m045-p03-legacy-golden.sh` (SC-4) — un-armed branch output byte-matches the golden. PASS.
