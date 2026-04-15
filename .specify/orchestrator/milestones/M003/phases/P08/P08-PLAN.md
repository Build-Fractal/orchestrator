---
schema_version: "1.0"
type: phase-plan
phase: "P08"
milestone: "M003"
goal: "Validate the refitted migration pipeline end-to-end against live GSD2 data from the lakeledger submodule parent, confirming resolved target root, index + graph database rebuild, and orchestrator readability."
demo_sentence: "A developer can run `bash scripts/migrate/migrate.sh --source gsd2 --path /Users/brettkellgren/Sites/lakeledger --output <tempdir> --force`, and the tempdir contains a valid orchestrator state tree (via the resolved root), `KNOWLEDGE-INDEX.md` with entries, a non-empty `knowledge.db`, a `MIGRATION-REPORT.md` with non-zero counts across knowledge/decisions/requirements/milestones/telemetry, and `bash scripts/state/derive-phase.sh <tempdir>/.../milestones/M001` emits a valid state without error."
risk: "low"
depends_on: ["P07"]
---

## Must-Haves

### Truths

- An integration test script at `tests/integration/test-m003-e2e-migration.sh` exists, is executable, and exits 0 when run against the live lakeledger `.gsd/` fixture; it skips cleanly (exit 0 with a skip message) when the fixture is absent, so CI on hosts without the submodule still passes.
  - Check: `bash scripts/verify/m003-p08-integration-test-exists.sh`
- The integration test asserts all five content categories have non-zero counts in the generated `MIGRATION-REPORT.md` (knowledge, decisions, requirements, milestones, telemetry).
  - Check: `bash scripts/verify/m003-p08-report-has-nonzero-counts.sh`
- The integration test asserts `knowledge.db` exists and is non-empty in the migrated output, and that at least one migrated knowledge entry is queryable via `scripts/knowledge/traverse-graph.sh`.
  - Check: `bash scripts/verify/m003-p08-graph-db-populated.sh`
- The integration test asserts `bash scripts/state/derive-phase.sh <migrated>/milestones/M001` exits 0 and emits a state name from the state machine enumeration (`pre-planning`, `discussing`, `planning`, `executing`, `summarizing`, `validating`, `completing`, `complete`).
  - Check: `bash scripts/verify/m003-p08-status-derivable.sh`
- The test harness never writes inside `/Users/brettkellgren/Sites/lakeledger/.gsd/` — only reads from it. All output goes to a `mktemp -d` directory cleaned up on exit.
  - Check: `bash scripts/verify/m003-p08-source-not-modified.sh`
- P07's seven verify scripts still pass end-to-end (no regression introduced by test harness or corrections).
  - Check: `bash scripts/verify/m003-p08-p07-still-green.sh`
- If validation uncovers corrections to migration scripts, each correction is committed separately from the test-harness commit with a short rationale in the commit body.
  - Check: `bash scripts/verify/m003-p08-corrections-documented.sh`

### Artifacts

- `tests/integration/test-m003-e2e-migration.sh` (new, min 80 lines; contains `sqlite3\|traverse-graph\|derive-phase`)
- `scripts/verify/m003-p08-integration-test-exists.sh` (new)
- `scripts/verify/m003-p08-report-has-nonzero-counts.sh` (new)
- `scripts/verify/m003-p08-graph-db-populated.sh` (new)
- `scripts/verify/m003-p08-status-derivable.sh` (new)
- `scripts/verify/m003-p08-source-not-modified.sh` (new)
- `scripts/verify/m003-p08-p07-still-green.sh` (new — wraps a run of all `scripts/verify/m003-p07-*.sh`)
- `scripts/verify/m003-p08-corrections-documented.sh` (new — optional gate; passes by default when no corrections needed)
- Any correction patches to `scripts/migrate/**` uncovered during validation (scope TBD — documented case-by-case in commit messages)

### Key Links

- `tests/integration/test-m003-e2e-migration.sh` → `scripts/migrate/migrate.sh` (invokes the refitted CLI)
- `tests/integration/test-m003-e2e-migration.sh` → `scripts/state/derive-phase.sh` (verifies status is derivable against migrated state)
- `tests/integration/test-m003-e2e-migration.sh` → `scripts/knowledge/traverse-graph.sh` (verifies graph DB populated)
- `scripts/verify/m003-p08-p07-still-green.sh` → all `scripts/verify/m003-p07-*.sh` (regression guard)

## Tasks

### T01: Write End-to-End Integration Test Harness

Create `tests/integration/test-m003-e2e-migration.sh`:
- First step: `FIXTURE=/Users/brettkellgren/Sites/lakeledger/.gsd`; if `[ ! -d "$FIXTURE" ]`, print `SKIP: lakeledger .gsd fixture not available` and `exit 0`.
- Second step: `OUT="$(mktemp -d -t m003-e2e-XXXX)"`; install a trap to `rm -rf "$OUT"` on exit.
- Third step: record `$FIXTURE` mtime and file-count snapshot before and after migration to confirm read-only access.
- Fourth step: `bash scripts/migrate/migrate.sh --source gsd2 --path /Users/brettkellgren/Sites/lakeledger --output "$OUT" --force` and capture exit code — must be 0.
- Fifth step: assert `$OUT/MIGRATION-REPORT.md` exists and contains non-zero counts for knowledge, decisions, requirements, milestones, and telemetry (parse with `grep -E 'Knowledge:|Decisions:|Requirements:|Milestones:|Telemetry:' | grep -v '\b0\b'` or equivalent, compatible with the actual report format — check `scripts/migrate/transform/report.sh` for the literal pattern before writing the assertion).
- Sixth step: assert `$OUT/knowledge.db` is a file with non-zero size (`test -s`).
- Seventh step: pick any migrated entry ID (first `MEM*` match from `find "$OUT/knowledge" -name 'MEM*.md'`), run `bash scripts/knowledge/traverse-graph.sh --id <id>` with `PROJECT_ROOT="$OUT"`, exit must be 0.
- Eighth step: `bash scripts/state/derive-phase.sh "$OUT/milestones/M001"` — exit must be 0 and stdout must match one of the enumerated state names.
- Ninth step: compare mtime/file-count snapshots — fail if `$FIXTURE` was modified.

Acceptance: `bash tests/integration/test-m003-e2e-migration.sh` exits 0 on a host with the lakeledger submodule, exits 0 with a skip message on a host without it.

### T02: Write P08 Verify Scripts

Implement the seven `scripts/verify/m003-p08-*.sh` scripts. Most are thin wrappers that run the integration test and inspect its output file or artifacts in a cached temp dir. Keep each script single-purpose per AD-19: no inline compound bash beyond what the template permits.

`scripts/verify/m003-p08-p07-still-green.sh` iterates every `scripts/verify/m003-p07-*.sh` and exits non-zero on first failure.

Acceptance: `for f in scripts/verify/m003-p08-*.sh; do bash "$f" || exit 1; done` exits 0.

### T03: Execute Validation and Triage Findings

Run the integration test against the real lakeledger fixture. For each failure:
- Classify as (a) test-harness bug, (b) latent P07 refit bug, (c) latent P01–P06 bug uncovered only by live data, or (d) architectural gap (requires escalation to a new phase).
- (a) and (b) get fixed inline as part of this phase. (c) gets fixed inline with a commit message noting the latent-bug origin. (d) gets appended as an open question to this plan and escalated to the user before landing.

Acceptance: Integration test exits 0 on the live fixture. All P07 verify scripts still pass. If any finding was classified (d), the phase blocks until the user decides how to proceed.

### T04: Mark P07 and P08 Complete; Update milestone-summary.md

After T01–T03 pass, flip `- [ ] **P07**` and `- [ ] **P08**` to `- [x]` in `M003-ROADMAP.md`. Append a short "M003 refit complete (2026-04-14)" note to `.specify/orchestrator/milestone-summary.md` describing what drift was closed and pointing to the integration test.

Acceptance: Both phase checkboxes are `[x]`. `milestone-summary.md` contains the new note. No other content changed.

## Task Dependencies

```
T01 ──→ T02 ──→ T03 ──→ T04
```

Strict linear chain: the integration test must exist before verify scripts can exercise it, verify scripts must exist before a clean validation run is meaningful, and the roadmap checkbox flip is the last step after the green run.

## Files Likely Touched

- `tests/integration/test-m003-e2e-migration.sh` (create)
- `scripts/verify/m003-p08-integration-test-exists.sh` (create)
- `scripts/verify/m003-p08-report-has-nonzero-counts.sh` (create)
- `scripts/verify/m003-p08-graph-db-populated.sh` (create)
- `scripts/verify/m003-p08-status-derivable.sh` (create)
- `scripts/verify/m003-p08-source-not-modified.sh` (create)
- `scripts/verify/m003-p08-p07-still-green.sh` (create)
- `scripts/verify/m003-p08-corrections-documented.sh` (create)
- `.specify/orchestrator/milestones/M003/M003-ROADMAP.md` (modify — P07/P08 checkboxes)
- `.specify/orchestrator/milestone-summary.md` (modify — append refit note)
- `scripts/migrate/**` (modify if and only if T03 uncovers latent bugs — scope per-finding)
