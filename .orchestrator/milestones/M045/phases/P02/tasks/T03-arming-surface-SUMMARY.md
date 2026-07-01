---
schema_version: "1.0"
type: task-summary
task: "T03"
phase: "P02"
milestone: "M045"
name: "Document the --self-continue arming surface in commands/auto.md"
outcome: success
---

Added a `## Self-Continue (M045 — process-fresh re-entry)` section to
`commands/auto.md` documenting the explicit per-run `--self-continue` opt-in
(default OFF, spec CON-4), the `headless_reentry` gate, the three
`self-continue-branch.sh` directives, and the D015 process-fresh substrate note
(with a pointer to the P01 evidence). Doc-only: the live `## Context Rotation
Check` exit behavior is UNCHANGED (legacy parity FR-8 preserved until P03 wires
the spawn). Verifier `tools/verify/m045-p02-arming-surface.sh` PASS.
Regression: `test-s08-auto-safety.sh` unchanged (33/35; the 2 fails are
pre-existing, confirmed by stash-compare — not introduced by this section).
