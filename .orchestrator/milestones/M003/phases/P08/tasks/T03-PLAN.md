---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P08"
milestone: "M003"
name: "Write end-to-end integration test and P08 verify scripts"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: synthetic fixture at `tests/fixtures/m003-p08-gsd-minimal/.gsd/` exists and causes `migrate.sh` to produce non-zero counts across all categories.
- T02 complete: `scripts/orchestrator/status.sh` exists, is executable, supports `--root`.
- P07 complete: all seven `scripts/verify/m003-p07-*.sh` exit 0 against current main.

## Description

Build the P08 end-to-end integration test and all eight `scripts/verify/m003-p08-*.sh` helpers that back the truth `Check:` commands in `P08-PLAN.md`. Every Check is a single-script-file invocation per AD-19.

The integration test runs two passes:
1. **Primary pass** (always runs): migrates the synthetic fixture (from T01) into a temp dir, then asserts all post-migration invariants. This is the CI-reachable pass.
2. **Secondary pass** (skip-gracefully): repeats against the live lakeledger fixture at `/Users/brettkellgren/Sites/lakeledger/.gsd/` when present; prints `SKIP: lakeledger fixture not present` and continues when absent.

Each `scripts/verify/m003-p08-*.sh` helper is a thin, single-purpose check that caches its result by running the integration test once (or consuming a shared fixture-output directory). To avoid redundant migrations across the eight helpers, introduce one shared migrate-output helper that the verify scripts consume.

## Steps

1. Write `tests/integration/test-m003-e2e-migration.sh` (executable, min 120 lines) with this structure:

   ```bash
   #!/usr/bin/env bash
   # tests/integration/test-m003-e2e-migration.sh
   # End-to-end validation of the refitted M003 migration pipeline against
   # a synthetic GSD2 fixture (always) and the live lakeledger fixture (when
   # present). Bash 3.2 compatible, AD-19 safe (no inline compound bash).

   set -euo pipefail

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   SYNTHETIC_FIXTURE="$REPO_ROOT/tests/fixtures/m003-p08-gsd-minimal"
   LAKELEDGER_FIXTURE="/Users/brettkellgren/Sites/lakeledger"
   LAKELEDGER_GSD="$LAKELEDGER_FIXTURE/.gsd"

   pass_count=0
   fail_count=0
   skip_count=0

   pass() { echo "PASS: $1"; pass_count=$((pass_count + 1)); }
   fail() { echo "FAIL: $1" >&2; fail_count=$((fail_count + 1)); }
   skip() { echo "SKIP: $1"; skip_count=$((skip_count + 1)); }

   run_pass() {
     local label="$1" source_path="$2"
     local out; out="$(mktemp -d -t "m003-e2e-${label}-XXXX")"
     trap 'rm -rf "$out"' RETURN

     # mtime snapshot of source for read-only assertion
     local src_snapshot; src_snapshot="$(bash "$REPO_ROOT/tests/integration/lib/snapshot-tree.sh" "$source_path/.gsd" 2>/dev/null || echo "")"

     # Run migration
     if ! bash "$REPO_ROOT/scripts/migrate/migrate.sh" --source gsd2 --path "$source_path" --output "$out" --force >"$out/.migrate.log" 2>&1; then
       fail "$label: migrate.sh exited non-zero (see $out/.migrate.log)"
       return 1
     fi
     pass "$label: migrate.sh exit 0"

     # MIGRATION-REPORT exists and has non-zero counts
     local report="$out/MIGRATION-REPORT.md"
     if [ ! -f "$report" ]; then fail "$label: MIGRATION-REPORT.md missing"; return 1; fi
     bash "$REPO_ROOT/scripts/verify/m003-p08-report-has-nonzero-counts.sh" --report "$report" \
       && pass "$label: MIGRATION-REPORT non-zero counts" \
       || fail "$label: MIGRATION-REPORT has zero counts"

     # knowledge.db populated + traverse-graph returns OK for at least one entry
     bash "$REPO_ROOT/scripts/verify/m003-p08-graph-db-populated.sh" --root "$out" \
       && pass "$label: knowledge.db queryable" \
       || fail "$label: knowledge.db not queryable"

     # status.sh wrapper works
     bash "$REPO_ROOT/scripts/verify/m003-p08-status-wrapper-works.sh" --root "$out" \
       && pass "$label: status.sh emits MILESTONE/STATE" \
       || fail "$label: status.sh failed"

     # Source not modified
     local src_after; src_after="$(bash "$REPO_ROOT/tests/integration/lib/snapshot-tree.sh" "$source_path/.gsd" 2>/dev/null || echo "")"
     if [ "$src_snapshot" = "$src_after" ]; then
       pass "$label: source fixture unmodified"
     else
       fail "$label: source fixture was modified"
     fi
   }

   # Primary pass: synthetic fixture
   if [ ! -d "$SYNTHETIC_FIXTURE/.gsd" ]; then
     fail "synthetic fixture missing at $SYNTHETIC_FIXTURE/.gsd — run T01 first"
     echo "passed=$pass_count failed=$fail_count skipped=$skip_count"
     exit 1
   fi
   run_pass "synthetic" "$SYNTHETIC_FIXTURE"

   # Secondary pass: live lakeledger (skip-gracefully)
   if [ -d "$LAKELEDGER_GSD" ]; then
     run_pass "lakeledger" "$LAKELEDGER_FIXTURE"
   else
     skip "lakeledger fixture not present at $LAKELEDGER_GSD"
   fi

   echo "passed=$pass_count failed=$fail_count skipped=$skip_count"
   [ "$fail_count" -eq 0 ]
   ```

2. Write the small helper `tests/integration/lib/snapshot-tree.sh` that emits a reproducible fingerprint (concatenation of `find <dir> -type f -exec stat -f '%m %z %N' {} \;` sorted) of a directory tree. This supports the "source not modified" assertion without the Check needing inline compound bash.

3. Create the eight verify scripts. Each is AD-19-safe (single-script-file shape), exits 0 on pass, non-zero on fail, and prints `PASS:` / `FAIL:` lines.

   **`scripts/verify/m003-p08-fixture-shape.sh`** — checks T01 output:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   F="tests/fixtures/m003-p08-gsd-minimal/.gsd"
   [ -s "$F/gsd.db" ] || { echo "FAIL: gsd.db missing or empty"; exit 1; }
   [ -s "$F/memories-snapshot.json" ] || { echo "FAIL: memories-snapshot.json missing"; exit 1; }
   count=0
   for d in "$F"/milestones/M*; do [ -d "$d" ] && count=$((count + 1)); done
   [ "$count" -ge 1 ] || { echo "FAIL: no milestone directories under $F/milestones"; exit 1; }
   echo "PASS: fixture shape valid"
   ```

   **`scripts/verify/m003-p08-status-wrapper-contract.sh`** — checks T02 output:
   - File exists, executable, min 40 lines.
   - Contains strings `resolve-root` and `MILESTONE:`.
   - Handles `--root` flag (grep for `--root`).

   **`scripts/verify/m003-p08-status-wrapper-works.sh`** — callable with `--root <dir>`; runs `scripts/orchestrator/status.sh --root <dir>` and asserts stdout contains a `MILESTONE:` line and a `STATE:` line.

   **`scripts/verify/m003-p08-integration-test-exists.sh`** — checks `tests/integration/test-m003-e2e-migration.sh` exists, is executable, min 120 lines, and mentions `sqlite3|traverse-graph|derive-phase|status.sh` (regex alternation).

   **`scripts/verify/m003-p08-report-has-nonzero-counts.sh`** — callable with `--report <path>`. Reads the report and asserts each of these sections has at least one non-zero integer: `## Knowledge`, `## Decisions`, `## Requirements`, `## Milestones`, `## Telemetry`. When invoked without `--report`, it runs migrate against the synthetic fixture into a temp dir and validates the produced report.

   **`scripts/verify/m003-p08-graph-db-populated.sh`** — callable with `--root <dir>`. Asserts `<root>/knowledge.db` is a non-empty file; picks the first `MEM*.md` file under `<root>/knowledge/` (via `find ... -name 'MEM*.md' -print -quit`); invokes `scripts/knowledge/traverse-graph.sh --id <that-id>` with `PROJECT_ROOT=<root>` exported, asserts exit 0. When invoked without `--root`, runs migrate against the synthetic fixture first.

   **`scripts/verify/m003-p08-source-not-modified.sh`** — delegates to the integration test's snapshot logic by running the test once and grepping stdout/stderr for any `FAIL: *source fixture was modified` line; exits 0 if none found.

   **`scripts/verify/m003-p08-p07-still-green.sh`** — iterates `scripts/verify/m003-p07-*.sh` (via `for f in ...; do bash "$f" || exit 1; done` inside the helper script — permitted because it is itself a single-script-file invocation, not an inline compound Check); prints `PASS: P07 green` at the end.

4. `chmod +x` every script created.

5. Run the full suite:
   ```bash
   bash tests/integration/test-m003-e2e-migration.sh
   bash scripts/verify/m003-p08-fixture-shape.sh
   bash scripts/verify/m003-p08-status-wrapper-contract.sh
   bash scripts/verify/m003-p08-status-wrapper-works.sh --root "$(mktemp -d)"  # expected fail (no milestones); separately test with a populated migration root
   bash scripts/verify/m003-p08-integration-test-exists.sh
   bash scripts/verify/m003-p08-report-has-nonzero-counts.sh
   bash scripts/verify/m003-p08-graph-db-populated.sh
   bash scripts/verify/m003-p08-source-not-modified.sh
   bash scripts/verify/m003-p08-p07-still-green.sh
   ```
   All must exit 0 in the end-to-end happy path.

## Must-Haves

- `tests/integration/test-m003-e2e-migration.sh` exists, is executable, min 120 lines.
- All eight `scripts/verify/m003-p08-*.sh` files exist and are executable.
- Every truth `Check:` in `P08-PLAN.md` is wired to exactly one single-script-file invocation — no inline compound bash.
- `tests/integration/test-m003-e2e-migration.sh` exits 0 on the synthetic fixture and emits `SKIP: lakeledger fixture not present` when the live fixture is absent (instead of failing).

## Verification

- `bash scripts/verify/m003-p08-integration-test-exists.sh`
- `bash scripts/verify/m003-p08-fixture-shape.sh`
- `bash scripts/verify/m003-p08-status-wrapper-contract.sh`
- `bash scripts/verify/m003-p08-report-has-nonzero-counts.sh`
- `bash scripts/verify/m003-p08-graph-db-populated.sh`
- `bash scripts/verify/m003-p08-status-wrapper-works.sh` (with `--root` pointing at a populated migration)
- `bash scripts/verify/m003-p08-source-not-modified.sh`
- `bash scripts/verify/m003-p08-p07-still-green.sh`

## Inputs

### From Previous Tasks
- `tests/fixtures/m003-p08-gsd-minimal/.gsd/gsd.db` (from T01)
  - Key API: SQLite database conforming to GSD2 adapter schema.
- `scripts/orchestrator/status.sh` (from T02)
  - Key API: `bash status.sh --root <dir>` → prints `MILESTONE:`/`STATE:`/`PHASE:` lines; exit 0/1/2.

### From Disk (Pre-existing)
- `scripts/migrate/migrate.sh` — migration CLI entry point.
- `scripts/knowledge/traverse-graph.sh` — graph traversal (expects `knowledge.db` under `PROJECT_ROOT`).
- `scripts/state/derive-phase.sh` — state derivation.
- `scripts/verify/m003-p07-*.sh` — regression guard.

## Constraints

- AD-19: every truth `Check:` in `P08-PLAN.md` MUST be a bare `bash scripts/verify/m003-p08-*.sh` invocation. No `( … )`, no `$(… | …)`, no `<(…)`. Inline loops inside verify scripts are fine because the Check itself is still a single-file invocation.
- Bash 3.2 compatibility (MEM001).
- Integration test must not delete any path outside its own `mktemp -d` temp dir. The trap should scope `rm -rf` to the known temp var only.
- Integration test must not `cd` into the source fixture. All paths are absolute.
- Synthetic-fixture pass must be deterministic; the lakeledger pass is best-effort (latent-data tolerant).

## Expected Output

After T03 completes:
- `tests/integration/test-m003-e2e-migration.sh` (~150 lines, executable)
- `tests/integration/lib/snapshot-tree.sh` (~15 lines)
- `scripts/verify/m003-p08-*.sh` × 8 (total ~300 lines)

Running the full verify suite in the happy path prints eight `PASS:` lines and exits 0.
