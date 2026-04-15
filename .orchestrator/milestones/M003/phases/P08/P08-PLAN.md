---
schema_version: "1.0"
type: phase-plan
phase: "P08"
milestone: "M003"
goal: "Validate the refitted migration pipeline end-to-end against a GSD2 source (primary: synthetic fixture under tests/fixtures/; optional secondary: live lakeledger .gsd/) — confirming the resolver-derived output root, graph database rebuild, status readability, and non-zero MIGRATION-REPORT counts."
demo_sentence: "A developer can run `bash scripts/migrate/migrate.sh --source gsd2 --path tests/fixtures/m003-p08-gsd-minimal --output <tempdir> --force`, then `bash scripts/orchestrator/status.sh --root <tempdir>` returns a structured milestone summary (exit 0), `bash scripts/knowledge/traverse-graph.sh --id <any-migrated-id>` with PROJECT_ROOT=<tempdir> returns ≥1 related entry when overlaps exist, and `MIGRATION-REPORT.md` in the output contains non-zero counts for knowledge, decisions, requirements, milestones, and telemetry."
risk: "low"
depends_on: ["P07"]
---

## Context Notes (read before executing)

- The roadmap's demo sentence cites `bash scripts/orchestrator/status.sh`. That path does **not** currently exist in the repo (verified 2026-04-14). P08 establishes a thin `scripts/orchestrator/status.sh` wrapper that takes `--root <dir>` and delegates to `scripts/state/derive-phase.sh` plus a minimal milestone summary, so the demo sentence becomes literally executable. This choice is documented in T01 and mirrored in the integration test.
- The primary end-to-end target is a **synthetic minimal GSD2 fixture** at `tests/fixtures/m003-p08-gsd-minimal/.gsd/`, committed to the repo. It contains the smallest `gsd.db` + `memories-snapshot.json` + milestone directory shape that exercises every P01–P06 transform and every P07 refit. This gives CI and non-lakeledger hosts a deterministic, always-available fixture.
- The **optional secondary target** is the live lakeledger submodule at `/Users/brettkellgren/Sites/lakeledger/.gsd/`. The integration test includes a second pass against that path that skips gracefully (prints `SKIP:` and exits 0) when the fixture is absent. AD-19 applies: the Check commands for this secondary pass must also skip-gracefully.
- AD-19 constraint: every truth `Check:` below is a single-script-file invocation. No inline compound bash, no `$(…)` with pipes, no subshells. All logic goes inside the named `scripts/verify/m003-p08-*.sh` helper.

## Must-Haves

### Truths

- The synthetic GSD2 fixture exists at `tests/fixtures/m003-p08-gsd-minimal/.gsd/` and contains the minimum data surface (`gsd.db`, `memories-snapshot.json`, at least one milestone directory with a completed-slice summary) needed for every P01–P06 transform to emit non-zero output.
  - Check: `bash scripts/verify/m003-p08-fixture-shape.sh`
- A thin CLI wrapper exists at `scripts/orchestrator/status.sh` that accepts `--root <dir>` (plus `ORCHESTRATOR_ROOT` env fallback), resolves the root via `scripts/state/resolve-root.sh --absolute`, and emits a structured milestone summary (one header line `MILESTONE: <ID>` plus one `STATE: <state>` line plus zero or more `PHASE: <Pxx> <state>` lines). Exit 0 on success; exit 1 when no milestones found.
  - Check: `bash scripts/verify/m003-p08-status-wrapper-contract.sh`
- An integration test at `tests/integration/test-m003-e2e-migration.sh` exists, is executable, and exits 0 when run against the synthetic fixture. Against the live lakeledger fixture it runs a second pass; it skips cleanly (prints `SKIP: lakeledger fixture not present` and continues) when `/Users/brettkellgren/Sites/lakeledger/.gsd/` is absent.
  - Check: `bash scripts/verify/m003-p08-integration-test-exists.sh`
- The integration test asserts all five content categories have non-zero counts in `MIGRATION-REPORT.md` (knowledge, decisions, requirements, milestones, telemetry).
  - Check: `bash scripts/verify/m003-p08-report-has-nonzero-counts.sh`
- The integration test asserts `knowledge.db` exists and is non-empty in the migrated output, and at least one migrated knowledge entry ID is queryable via `scripts/knowledge/traverse-graph.sh --id <MEM>` (exit 0).
  - Check: `bash scripts/verify/m003-p08-graph-db-populated.sh`
- The integration test asserts `bash scripts/orchestrator/status.sh --root <migrated-output>` exits 0 and stdout contains a `MILESTONE:` line and a `STATE:` line.
  - Check: `bash scripts/verify/m003-p08-status-wrapper-works.sh`
- The test harness never writes inside the source fixture (synthetic or real). Output goes to a `mktemp -d` directory cleaned up on exit; mtime snapshot before/after matches.
  - Check: `bash scripts/verify/m003-p08-source-not-modified.sh`
- All seven P07 verify scripts still pass (no regression from the P08 test harness or any corrections).
  - Check: `bash scripts/verify/m003-p08-p07-still-green.sh`

### Artifacts

- `tests/fixtures/m003-p08-gsd-minimal/.gsd/gsd.db` (new; SQLite schema-compatible with GSD2 adapter; at least one row per table the adapter reads)
- `tests/fixtures/m003-p08-gsd-minimal/.gsd/memories-snapshot.json` (new; min 3 entries across ≥2 categories with at least one `relates_to` edge for graph traversal to return non-empty)
- `tests/fixtures/m003-p08-gsd-minimal/.gsd/milestones/M001/` (new; min one completed slice summary)
- `tests/fixtures/m003-p08-gsd-minimal/README.md` (new; min 20 lines; explains fixture shape and regeneration steps)
- `scripts/orchestrator/status.sh` (new; min 40 lines; contains `resolve-root` and `MILESTONE:`)
- `tests/integration/test-m003-e2e-migration.sh` (new; executable; min 120 lines; contains `sqlite3\|traverse-graph\|derive-phase\|status.sh`)
- `scripts/verify/m003-p08-fixture-shape.sh` (new)
- `scripts/verify/m003-p08-status-wrapper-contract.sh` (new)
- `scripts/verify/m003-p08-integration-test-exists.sh` (new)
- `scripts/verify/m003-p08-report-has-nonzero-counts.sh` (new)
- `scripts/verify/m003-p08-graph-db-populated.sh` (new)
- `scripts/verify/m003-p08-status-wrapper-works.sh` (new)
- `scripts/verify/m003-p08-source-not-modified.sh` (new)
- `scripts/verify/m003-p08-p07-still-green.sh` (new; wraps run of all `scripts/verify/m003-p07-*.sh`)
- Any correction patches to `scripts/migrate/**` or `scripts/knowledge/**` uncovered during validation (scope per-finding, documented in commit messages)

### Key Links

- `tests/integration/test-m003-e2e-migration.sh` → `scripts/migrate/migrate.sh`
- `tests/integration/test-m003-e2e-migration.sh` → `scripts/orchestrator/status.sh`
- `tests/integration/test-m003-e2e-migration.sh` → `scripts/knowledge/traverse-graph.sh`
- `scripts/orchestrator/status.sh` → `scripts/state/resolve-root.sh`
- `scripts/orchestrator/status.sh` → `scripts/state/derive-phase.sh`
- `scripts/verify/m003-p08-p07-still-green.sh` → `scripts/verify/m003-p07-bash32-compat.sh`

## Tasks

### T01 — Build synthetic GSD2 fixture

Create `tests/fixtures/m003-p08-gsd-minimal/.gsd/` with the minimum data shape that every P01–P06 transform will successfully consume and produce non-zero output against. Detailed steps, exact schema, and data content live in `tasks/T01-PLAN.md`.

### T02 — Build `scripts/orchestrator/status.sh` wrapper

Create the thin status wrapper the roadmap demo sentence cites: resolves the root via `scripts/state/resolve-root.sh --absolute`, walks `milestones/M*/`, and emits a `MILESTONE:` / `STATE:` / `PHASE:` structured summary. Detailed spec in `tasks/T02-PLAN.md`.

### T03 — Write the end-to-end integration test and P08 verify scripts

Build `tests/integration/test-m003-e2e-migration.sh` (primary pass on the synthetic fixture; secondary pass on the live lakeledger fixture with skip-gracefully semantics) and all eight `scripts/verify/m003-p08-*.sh` helpers wired to each truth's Check. Detailed spec in `tasks/T03-PLAN.md`.

### T04 — Execute validation, triage findings, mark refit complete

Run the integration test. Triage any failures as (a) test-harness bug, (b) latent P07 refit bug, (c) latent P01–P06 bug uncovered by live data, or (d) architectural gap requiring escalation. Fix (a)/(b)/(c) inline with descriptive commits; escalate (d) to the user before landing. On green: flip `P07` and `P08` to `[x]` in `M003-ROADMAP.md` and append a short refit note to `.specify/orchestrator/milestone-summary.md`. Detailed spec in `tasks/T04-PLAN.md`.

## Task Dependencies

```
T01 ──→ T03 ──→ T04
        ↑
T02 ────┘
```

T01 and T02 are independent and may be executed in parallel. T03 consumes both. T04 consumes T03.

## Files Likely Touched

- `tests/fixtures/m003-p08-gsd-minimal/.gsd/gsd.db` (create)
- `tests/fixtures/m003-p08-gsd-minimal/.gsd/memories-snapshot.json` (create)
- `tests/fixtures/m003-p08-gsd-minimal/.gsd/milestones/M001/SUMMARY.md` (create)
- `tests/fixtures/m003-p08-gsd-minimal/README.md` (create)
- `tests/fixtures/m003-p08-gsd-minimal/build-fixture.sh` (create — regenerates `gsd.db` from a SQL seed so fixture is reproducible)
- `scripts/orchestrator/status.sh` (create)
- `tests/integration/test-m003-e2e-migration.sh` (create)
- `scripts/verify/m003-p08-fixture-shape.sh` (create)
- `scripts/verify/m003-p08-status-wrapper-contract.sh` (create)
- `scripts/verify/m003-p08-status-wrapper-works.sh` (create)
- `scripts/verify/m003-p08-integration-test-exists.sh` (create)
- `scripts/verify/m003-p08-report-has-nonzero-counts.sh` (create)
- `scripts/verify/m003-p08-graph-db-populated.sh` (create)
- `scripts/verify/m003-p08-source-not-modified.sh` (create)
- `scripts/verify/m003-p08-p07-still-green.sh` (create)
- `.specify/orchestrator/milestones/M003/M003-ROADMAP.md` (modify — P07/P08 checkboxes)
- `.specify/orchestrator/milestone-summary.md` (modify — refit closeout note)
- `scripts/migrate/**` or `scripts/knowledge/**` (modify if and only if T04 uncovers latent bugs — scope per-finding)
