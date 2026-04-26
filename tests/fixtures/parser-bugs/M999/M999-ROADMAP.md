---
schema_version: "1.0"
milestone: M999
tier: C
---

## Phases

- [x] **P01**: First phase — "demo"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: tests/fixtures/parser-bugs/M999/M999-ROADMAP.md
    - Consumes: none

- [x] **P02**: Second phase — "demo"
  - Risk: low
  - Depends: P01
  - Boundary Map:
    - Produces: tests/fixtures/parser-bugs/M999/M999-ROADMAP.md
    - Consumes: none

- [ ] **P02.1**: Decimal phase — "post-roadmap addition between P02 and P03"
  - Risk: low
  - Depends: P02
  - Boundary Map:
    - Produces: tests/fixtures/parser-bugs/M999/M999-ROADMAP.md
    - Consumes: none

- [x] **P03**: Third phase — "demo"
  - Risk: low
  - Depends: P02
  - Boundary Map:
    - Produces: tests/fixtures/parser-bugs/M999/M999-ROADMAP.md
    - Consumes: none
