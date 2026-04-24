---
schema_version: "1.0"
milestone: M999
tier: C
---

## Phases

- [ ] **P01**: Real paths only — "demo"
  - Risk: low
  - Depends: none
  - Produces: tests/fixtures/boundary-map-parser/roadmap-with-prose.md, tests/fixtures/boundary-map-parser/sample-file.txt
  - Consumes: none

- [ ] **P02**: Prose-mixed Produces — "demo"
  - Risk: low
  - Depends: P01
  - Produces: patched conversus.sh (FR-1, FR-2); edition env-var handling (FR-2, FR-3); OAuth auto-preflight closes OQ-16 false-PASS
  - Consumes: none

- [ ] **P03**: Real path with parenthetical note — "demo"
  - Risk: low
  - Depends: P01
  - Produces: tests/fixtures/boundary-map-parser/sample-file.txt (touched), tests/fixtures/boundary-map-parser/roadmap-with-prose.md
  - Consumes: none
