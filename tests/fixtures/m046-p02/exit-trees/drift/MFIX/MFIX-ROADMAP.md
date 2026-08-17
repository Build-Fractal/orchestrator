---
schema_version: "1.0"
type: roadmap
milestone: MFIX
tier: C
---

# MFIX Roadmap — M046/P02 exit-battery `drift` fixture (throwaway)

Synthetic 1-phase milestone for the SC-9 exit battery. P01 is CHECKED in
this roadmap but phases/P01/P01-SUMMARY.md does NOT exist on disk, so
auto-loop's roadmap↔disk drift guard (sync-roadmap.sh read-only pass)
reports SYNC:MISMATCH → `AUTO:ROADMAP_DRIFT` → exit 12 → marker
`unexpected_state`. Verifiers ALWAYS run against scratch copies.

## Phases

- [x] **P01**: Fixture phase — "fixture demo"
  - Risk: low
  - Depends: none
