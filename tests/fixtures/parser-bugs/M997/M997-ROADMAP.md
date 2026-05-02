---
schema_version: "1.0"
type: roadmap
milestone: "M997"
feature_ref: "997-empty-phase-list-regression"
vision: "Fixture for the empty-phase-list false-validation bug surfaced 2026-05-01 by M036's parenthetical-tagged phase headers."
tier: "C"
created_at: "2026-05-01"
updated_at: "2026-05-01"
---

## Phases

### M997a — Pre-Launch

- [ ] **P00 (M997a)**: Foundation — "Operator runs the foundation script and sees output."
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: foo.md
    - Consumes: none

- [ ] **P01 (M997a)**: Second phase — "Operator runs the second script."
  - Risk: medium
  - Depends: P00
  - Boundary Map:
    - Produces: bar.md
    - Consumes: foo.md

### M997b — Post-Launch

- [ ] **P02 (M997b)**: Third phase — "Operator runs the third script."
  - Risk: low
  - Depends: P01
  - Boundary Map:
    - Produces: baz.md
    - Consumes: bar.md
