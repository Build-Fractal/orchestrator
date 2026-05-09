#!/usr/bin/env bash
# tools/verify/m035-p05-rollback-marker-shape.sh
#
# M035 P05 T01 — Asserts scripts/lifecycle/write-rollback-marker.sh shape:
#   1. greenfield (no prior installed-files.txt) -> SKIP, no marker written
#   2. copy-mode prior -> --dry-run emits would_write= + correct fields
#   3. symlink-mode prior -> --dry-run emits prior_install_mode=symlink
#   4. non-dry-run against copy-mode fixture -> snapshot is byte-identical
#   5. marker file contains all five required fields
#   6. --dry-run emits would_write= and would_snapshot=
#
# AD-19 single-script-file shape; runs against staged fixtures under
# /tmp/m035-p05-t01-marker-fixture-$$/.

set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
WRITER="$REPO/scripts/lifecycle/write-rollback-marker.sh"

FIXTURE_ROOT="/tmp/m035-p05-t01-marker-fixture-$$"
mkdir -p "$FIXTURE_ROOT"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

pass=0
fail=0

# --- Scenario 1: greenfield (no prior installed-files.txt) ---
GREEN="$FIXTURE_ROOT/greenfield"
mkdir -p "$GREEN/.orchestrator"

green_out="$(bash "$WRITER" --project-dir "$GREEN" --dry-run 2>&1)"
green_rc=$?
if [ "$green_rc" -eq 0 ] && echo "$green_out" | grep -q '^SKIP: greenfield'; then
  if [ ! -f "$GREEN/.orchestrator/.previous-version" ]; then
    echo "PASS: greenfield no-op"
    pass=$((pass + 1))
  else
    echo "FAIL: greenfield wrote .previous-version"
    fail=$((fail + 1))
  fi
else
  echo "FAIL: greenfield did not emit SKIP (rc=$green_rc, out=$green_out)"
  fail=$((fail + 1))
fi

# --- Scenario 2: copy-mode prior --dry-run ---
COPY="$FIXTURE_ROOT/copy-mode"
mkdir -p "$COPY/.orchestrator"
printf '%s\tmode:copy\n' "commands/auto.md" > "$COPY/.orchestrator/installed-files.txt"
printf '%s\tmode:copy\n' "commands/dispatch.md" >> "$COPY/.orchestrator/installed-files.txt"
{
  printf 'source_root=/some/path\n'
  printf 'runtime=claude-code\n'
  printf 'installed_at=2026-01-01T00:00:00Z\n'
  printf 'commit_sha=abc123\n'
  printf 'version=0.9.2\n'
} > "$COPY/.orchestrator/install-meta.txt"

copy_out="$(bash "$WRITER" --project-dir "$COPY" --dry-run 2>&1)"
copy_rc=$?

copy_ok=1
if [ "$copy_rc" -ne 0 ]; then
  copy_ok=0
fi
if ! echo "$copy_out" | grep -q '^would_write='; then
  copy_ok=0
fi
if ! echo "$copy_out" | grep -q '^would_content_line=prior_install_mode=copy$'; then
  copy_ok=0
fi
if ! echo "$copy_out" | grep -q '^would_content_line=prior_version=0\.9\.2$'; then
  copy_ok=0
fi
if ! echo "$copy_out" | grep -q '^would_content_line=prior_commit_sha=abc123$'; then
  copy_ok=0
fi
if ! echo "$copy_out" | grep -q '^would_content_line=prior_manifest_path=\.orchestrator/\.rollback/manifest-0\.9\.2\.txt$'; then
  copy_ok=0
fi

if [ "$copy_ok" -eq 1 ]; then
  echo "PASS: copy-mode prior writes correct marker"
  pass=$((pass + 1))
else
  echo "FAIL: copy-mode --dry-run output incorrect (rc=$copy_rc)"
  echo "$copy_out" | sed 's/^/  /'
  fail=$((fail + 1))
fi

# --- Scenario 3: symlink-mode prior --dry-run ---
SYM="$FIXTURE_ROOT/symlink-mode"
mkdir -p "$SYM/.orchestrator"
printf '%s\tmode:symlink\n' "commands/auto.md" > "$SYM/.orchestrator/installed-files.txt"
printf '%s\tmode:symlink\n' "commands/dispatch.md" >> "$SYM/.orchestrator/installed-files.txt"
{
  printf 'version=0.9.2\n'
  printf 'commit_sha=abc123\n'
} > "$SYM/.orchestrator/install-meta.txt"

sym_out="$(bash "$WRITER" --project-dir "$SYM" --dry-run 2>&1)"
sym_rc=$?
if [ "$sym_rc" -eq 0 ] && echo "$sym_out" | grep -q '^would_content_line=prior_install_mode=symlink$'; then
  echo "PASS: symlink-mode prior writes correct marker (mode=symlink)"
  pass=$((pass + 1))
else
  echo "FAIL: symlink-mode mode field incorrect (rc=$sym_rc)"
  echo "$sym_out" | sed 's/^/  /'
  fail=$((fail + 1))
fi

# --- Non-dry-run against scenario 2's fixture ---
real_out="$(bash "$WRITER" --project-dir "$COPY" 2>&1)"
real_rc=$?

MARKER="$COPY/.orchestrator/.previous-version"
SNAPSHOT="$COPY/.orchestrator/.rollback/manifest-0.9.2.txt"

# --- Scenario 4: snapshot byte-identical ---
snap_ok=0
if [ "$real_rc" -eq 0 ] && [ -f "$SNAPSHOT" ]; then
  if cmp -s "$SNAPSHOT" "$COPY/.orchestrator/installed-files.txt"; then
    snap_ok=1
  fi
fi
if [ "$snap_ok" -eq 1 ]; then
  echo "PASS: snapshot is byte-identical to source manifest"
  pass=$((pass + 1))
else
  echo "FAIL: snapshot missing or not byte-identical (rc=$real_rc)"
  fail=$((fail + 1))
fi

# --- Scenario 5: marker contains all five fields ---
marker_ok=1
if [ ! -f "$MARKER" ]; then
  marker_ok=0
fi
if [ "$marker_ok" -eq 1 ]; then
  for field in prior_version prior_commit_sha prior_manifest_path prior_install_mode rolled_at; do
    if ! grep -qE "^${field}=" "$MARKER"; then
      marker_ok=0
    fi
  done
fi
if [ "$marker_ok" -eq 1 ]; then
  echo "PASS: marker file contains all five required fields"
  pass=$((pass + 1))
else
  echo "FAIL: marker missing one or more required fields"
  if [ -f "$MARKER" ]; then
    cat "$MARKER" | sed 's/^/  /'
  fi
  fail=$((fail + 1))
fi

# --- Scenario 6: --dry-run emits would_write= and would_snapshot= ---
DRY="$FIXTURE_ROOT/dry-run-shape"
mkdir -p "$DRY/.orchestrator"
printf '%s\tmode:copy\n' "commands/auto.md" > "$DRY/.orchestrator/installed-files.txt"
printf 'version=0.9.2\n' > "$DRY/.orchestrator/install-meta.txt"

dry_out="$(bash "$WRITER" --project-dir "$DRY" --dry-run 2>&1)"
dry_rc=$?
dry_ok=1
if [ "$dry_rc" -ne 0 ]; then
  dry_ok=0
fi
if ! echo "$dry_out" | grep -q '^would_write='; then
  dry_ok=0
fi
if ! echo "$dry_out" | grep -q '^would_snapshot='; then
  dry_ok=0
fi
# Also verify nothing was actually written.
if [ -f "$DRY/.orchestrator/.previous-version" ]; then
  dry_ok=0
fi
if [ -d "$DRY/.orchestrator/.rollback" ]; then
  dry_ok=0
fi

if [ "$dry_ok" -eq 1 ]; then
  echo "PASS: --dry-run emits would_write= and would_snapshot="
  pass=$((pass + 1))
else
  echo "FAIL: --dry-run shape incorrect (rc=$dry_rc)"
  echo "$dry_out" | sed 's/^/  /'
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
