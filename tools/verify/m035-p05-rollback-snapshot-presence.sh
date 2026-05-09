#!/usr/bin/env bash
# tools/verify/m035-p05-rollback-snapshot-presence.sh
#
# M035 P05 T01 — Lighter-weight snapshot verifier:
#   1. snapshot file written
#   2. snapshot file is non-empty
#   3. snapshot SHA-256 matches source installed-files.txt SHA-256
#
# AD-19 single-script-file shape; runs against staged fixture under
# /tmp/m035-p05-t01-snapshot-fixture-$$/.

set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
WRITER="$REPO/scripts/lifecycle/write-rollback-marker.sh"

FIXTURE="/tmp/m035-p05-t01-snapshot-fixture-$$"
mkdir -p "$FIXTURE/.orchestrator"

cleanup() {
  rm -rf "$FIXTURE"
}
trap cleanup EXIT

# Author a minimal copy-mode fixture.
SOURCE_MANIFEST="$FIXTURE/.orchestrator/installed-files.txt"
printf '%s\tmode:copy\n' "commands/auto.md" > "$SOURCE_MANIFEST"
printf '%s\tmode:copy\n' "commands/dispatch.md" >> "$SOURCE_MANIFEST"
printf '%s\tmode:copy\n' "scripts/state/derive-phase.sh" >> "$SOURCE_MANIFEST"

{
  printf 'version=0.9.2\n'
  printf 'commit_sha=abc123\n'
} > "$FIXTURE/.orchestrator/install-meta.txt"

# Run the writer.
bash "$WRITER" --project-dir "$FIXTURE" >/dev/null 2>&1
writer_rc=$?

SNAPSHOT="$FIXTURE/.orchestrator/.rollback/manifest-0.9.2.txt"

pass=0
fail=0

# Assertion 1: snapshot file written.
if [ "$writer_rc" -eq 0 ] && [ -f "$SNAPSHOT" ]; then
  echo "PASS: snapshot file written"
  pass=$((pass + 1))
else
  echo "FAIL: snapshot file not written (writer rc=$writer_rc, path=$SNAPSHOT)"
  fail=$((fail + 1))
fi

# Assertion 2: snapshot file is non-empty.
if [ -s "$SNAPSHOT" ]; then
  echo "PASS: snapshot file is non-empty"
  pass=$((pass + 1))
else
  echo "FAIL: snapshot file is empty or missing"
  fail=$((fail + 1))
fi

# Assertion 3: snapshot SHA-256 matches source installed-files.txt SHA-256.
src_hash=""
snap_hash=""
if [ -f "$SOURCE_MANIFEST" ]; then
  src_hash="$(shasum -a 256 "$SOURCE_MANIFEST" | awk '{print $1}')"
fi
if [ -f "$SNAPSHOT" ]; then
  snap_hash="$(shasum -a 256 "$SNAPSHOT" | awk '{print $1}')"
fi

if [ -n "$src_hash" ] && [ "$src_hash" = "$snap_hash" ]; then
  echo "PASS: snapshot SHA-256 matches source installed-files.txt SHA-256"
  pass=$((pass + 1))
else
  echo "FAIL: SHA-256 mismatch (src=$src_hash snap=$snap_hash)"
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
