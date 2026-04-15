# M003/P08 Synthetic GSD2 Fixture

A minimal, deterministic, fully synthetic GSD2 project used as the
end-to-end migration target for the `tests/integration/test-m003-e2e-migration.sh`
integration test. It is the CI-reachable replacement for the developer-specific
lakeledger submodule.

## Purpose

Exercise every branch in `scripts/migrate/adapters/gsd2.sh` +
`scripts/migrate/lib/sqlite-reader.sh` against a source small enough to
diff but rich enough that every P01–P06 transform emits non-zero output
into `MIGRATION-REPORT.md`.

## Regenerate `gsd.db`

```bash
bash tests/fixtures/m003-p08-gsd-minimal/build-fixture.sh
```

The build script removes the old db and rebuilds it from
`.gsd/seed.sql` using `sqlite3`. Output is deterministic on the same
machine because all timestamps in the seed are hard-coded.

## Contents

| File                               | Purpose                                    |
| ---------------------------------- | ------------------------------------------ |
| `.gsd/seed.sql`                    | CREATE + INSERT for every GSD2 table       |
| `.gsd/gsd.db`                      | Pre-built binary (committed for CI speed)  |
| `.gsd/memories-snapshot.json`      | JSON fallback for when `gsd.db` is missing |
| `.gsd/milestones/M001/SUMMARY.md`  | Filesystem-scan target (P04 branch)        |
| `build-fixture.sh`                 | Regeneration entrypoint                    |

## Row Counts

| Table                   | Rows |
| ----------------------- | ---- |
| `memories`              | 4    |
| `decisions`             | 2    |
| `requirements`          | 2    |
| `milestones`            | 2    |
| `slices`                | 3    |
| `tasks`                 | 3    |
| `verification_evidence` | 3    |

## Why Minimal

The fixture is intentionally small — just enough to exercise every
pipeline branch once. It is not an exhaustive conformance suite.
Conformance lives in the unit tests for each transform; this fixture
exists to prove the end-to-end pipeline still stitches together.

## No Real Data

All content is synthetic. No private data from any real project is
included here.
