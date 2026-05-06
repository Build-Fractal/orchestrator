---
schema_version: "1.0"
type: roadmap
milestone: "M996"
feature_ref: "037-roadmap-visibility-cli-ux"
tier: "C"
created_at: "2026-05-06"
---

# M996 — SC-9 Auto-Preflight Quick Fixture Milestone

Synthetic milestone tree used only by
`tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh` to exercise
the FR-9 Quick-intensity preflight-suppression contract surface against
a deterministic fixture. Not a real milestone.

## Phases

- [x] **P01**: Completed phase — has P01-SUMMARY.md.
- [ ] **P02**: Pending phase — empty directory.
- [ ] **P03**: Pending phase — empty directory.

## Notes

- Tier C — fixture mirrors the canonical M029 tier.
- `intensity: quick` declared in EVALUATION frontmatter — load-bearing
  for SC-9 (the documented invariant: Quick intensity suppresses the
  Preflight Summary block).
- `execution-log.jsonl` carries M019 Tier 1 records (mirrors the SC-8
  fixture for renderer-shape parity).
