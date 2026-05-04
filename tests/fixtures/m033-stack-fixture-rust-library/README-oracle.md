# README-oracle.md — rust-library-fixture

Ground truth for SC-3 acceptance assertions against this fixture.

- expected MEM count: 5 (FR-7 floor — exercises the minimum end of the 5-15 range)
- expected categories:
  - architecture: 2 (README.md + src/ directory)
  - conventions: 2 (Cargo.toml + tests/)
  - decisions: 1 (no .git/ in fixture, no DR- file — degenerate case for SC-3 floor coverage)

This fixture has no synthetic `.orchestrator/DECISIONS.md` so it
exercises the FR-7 deterministic core only.
