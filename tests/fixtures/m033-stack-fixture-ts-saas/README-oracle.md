# README-oracle.md — ts-saas-fixture

Ground truth for SC-3 acceptance assertions against this fixture.

- expected MEM count: 8 (within FR-7 5-15 range)
- expected categories:
  - architecture: 3 (README.md + ARCHITECTURE.md + src/ directory)
  - conventions: 3 (package.json + tests/ + prior-tooling .orchestrator/)
  - decisions: 2 (DR-DEMO-001 + DR-DEMO-002 — imported by T04 rich-context branch)

The two `DR-` entries the rich-context branch imports are
`DR-DEMO-001` and `DR-DEMO-002`. Each becomes one `MEM-DR-` carrying
`context_source: imported` (T04 deliverable; T03 ships only the
deterministic core, so T03's count is 6 — the DR-imports raise it to 8
once T04 lands).
