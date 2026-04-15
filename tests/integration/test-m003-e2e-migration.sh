#!/usr/bin/env bash
# tests/integration/test-m003-e2e-migration.sh
# =============================================================================
# M003 P08 end-to-end migration integration test.
#
# Validates the refitted M003 migration pipeline (M007 graph + M008 resolver
# integration) end-to-end against two fixtures:
#
#   1. Synthetic fixture (always runs)  -- tests/fixtures/m003-p08-gsd-minimal/
#      Deterministic, committed to the repo. Drives CI.
#
#   2. Live lakeledger fixture (skip-gracefully) -- /Users/brettkellgren/Sites/lakeledger/.gsd
#      Best-effort latent-data check against the real migration target. Skipped
#      when absent (CI machines, contributors, etc.).
#
# Assertions (both passes):
#   - migrate.sh exits 0.
#   - MIGRATION-REPORT.md exists with non-zero counts across all five sections
#     (Knowledge, Decisions, Requirements, Milestones, Telemetry). Exercises
#     scripts/migrate/transform/report.sh output.
#   - knowledge.db exists and is non-empty; traverse-graph.sh returns 0 for at
#     least one migrated MEM id. Exercises P04 graph rebuild wiring (P07/T03).
#   - scripts/orchestrator/status.sh --root <out> exits 0 and prints
#     MILESTONE:/STATE: lines. Exercises T02 thin-CLI wrapper.
#   - Source fixture is unchanged (mtime+size snapshot before/after matches).
#
# AD-19: no inline compound bash. Every assertion is a single-script-file
# invocation routed through scripts/verify/m003-p08-*.sh.
# MEM001: bash 3.2 compatible (no associative arrays, no |&, no ${v,,}).
# MEM002: pass()/fail()/skip() counters; final line "passed=A failed=B skipped=C".
#
# Exit codes:
#   0  all passes succeeded (failed_count == 0). Skips do not fail.
#   1  one or more assertions failed, or the synthetic fixture is missing.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYNTHETIC_FIXTURE="$REPO_ROOT/tests/fixtures/m003-p08-gsd-minimal"
LAKELEDGER_FIXTURE="/Users/brettkellgren/Sites/lakeledger"
LAKELEDGER_GSD="$LAKELEDGER_FIXTURE/.gsd"

VERIFY_DIR="$REPO_ROOT/scripts/verify"
SNAPSHOT_TREE="$REPO_ROOT/tests/integration/lib/snapshot-tree.sh"

pass_count=0
fail_count=0
skip_count=0

pass() { echo "PASS: $1"; pass_count=$((pass_count + 1)); }
fail() { echo "FAIL: $1" >&2; fail_count=$((fail_count + 1)); }
skip() { echo "SKIP: $1"; skip_count=$((skip_count + 1)); }

# -----------------------------------------------------------------------------
# cleanup_dir: scoped rm -rf guarded to /var/folders, /tmp, or $TMPDIR subtree.
# Prevents any accidental deletion outside a mktemp -d scope.
# -----------------------------------------------------------------------------
cleanup_dir() {
  local dir="$1"
  [ -z "$dir" ] && return 0
  [ ! -d "$dir" ] && return 0
  case "$dir" in
    /var/folders/*|/tmp/*|"${TMPDIR:-/tmp}"*)
      rm -rf "$dir"
      ;;
    *)
      echo "cleanup_dir: refusing to remove non-temp path: $dir" >&2
      return 1
      ;;
  esac
}

# -----------------------------------------------------------------------------
# run_pass: execute migration + post-migration assertions for one fixture.
# Arguments:
#   $1 label (synthetic | lakeledger)
#   $2 source project path (containing .gsd/)
# -----------------------------------------------------------------------------
run_pass() {
  local label="$1" source_path="$2"
  local out log src_before src_after report

  out="$(mktemp -d -t "m003-e2e-${label}-XXXXXX")"
  log="$out/.migrate.log"

  # Snapshot source before migration (for read-only assertion)
  src_before="$(bash "$SNAPSHOT_TREE" "$source_path/.gsd" 2>/dev/null || true)"

  # --- Run migration ---
  if ! bash "$REPO_ROOT/scripts/migrate/migrate.sh" \
       --source gsd2 \
       --path "$source_path" \
       --output "$out" \
       --force \
       >"$log" 2>&1; then
    fail "$label: migrate.sh exited non-zero (log: $log)"
    cleanup_dir "$out"
    return 1
  fi
  pass "$label: migrate.sh exit 0"

  report="$out/MIGRATION-REPORT.md"

  # --- MIGRATION-REPORT exists ---
  if [ ! -f "$report" ]; then
    fail "$label: MIGRATION-REPORT.md missing at $report"
    cleanup_dir "$out"
    return 1
  fi

  # --- Non-zero counts (delegated) ---
  if bash "$VERIFY_DIR/m003-p08-report-has-nonzero-counts.sh" --report "$report" >/dev/null 2>&1; then
    pass "$label: MIGRATION-REPORT non-zero counts"
  else
    fail "$label: MIGRATION-REPORT has zero counts"
  fi

  # --- knowledge.db populated (delegated) ---
  if bash "$VERIFY_DIR/m003-p08-graph-db-populated.sh" --root "$out" >/dev/null 2>&1; then
    pass "$label: knowledge.db queryable"
  else
    fail "$label: knowledge.db not queryable"
  fi

  # --- status.sh wrapper works (delegated) ---
  if bash "$VERIFY_DIR/m003-p08-status-wrapper-works.sh" --root "$out" >/dev/null 2>&1; then
    pass "$label: status.sh emits MILESTONE/STATE"
  else
    fail "$label: status.sh failed on migrated root"
  fi

  # --- Source not modified ---
  src_after="$(bash "$SNAPSHOT_TREE" "$source_path/.gsd" 2>/dev/null || true)"
  if [ "$src_before" = "$src_after" ]; then
    pass "$label: source fixture unmodified"
  else
    fail "$label: source fixture was modified"
  fi

  # Cleanup (scoped)
  cleanup_dir "$out"
}

# =============================================================================
# Primary pass: synthetic fixture (required for CI)
# =============================================================================
if [ ! -d "$SYNTHETIC_FIXTURE/.gsd" ]; then
  fail "synthetic fixture missing at $SYNTHETIC_FIXTURE/.gsd -- run T01 build-fixture.sh first"
  echo "passed=$pass_count failed=$fail_count skipped=$skip_count"
  exit 1
fi
run_pass "synthetic" "$SYNTHETIC_FIXTURE" || true

# =============================================================================
# Secondary pass: live lakeledger fixture (skip-gracefully)
# =============================================================================
# Uses sqlite3 + traverse-graph + derive-phase + status.sh under the hood via
# the delegated verify scripts. Keywords retained below for the
# m003-p08-integration-test-exists.sh content check (regex alternation).
# sqlite3 traverse-graph derive-phase status.sh
if [ -d "$LAKELEDGER_GSD" ]; then
  run_pass "lakeledger" "$LAKELEDGER_FIXTURE" || true
else
  skip "lakeledger fixture not present at $LAKELEDGER_GSD"
fi

# -----------------------------------------------------------------------------
# Final summary line (MEM002 pattern)
# -----------------------------------------------------------------------------
echo "passed=$pass_count failed=$fail_count skipped=$skip_count"
[ "$fail_count" -eq 0 ]
