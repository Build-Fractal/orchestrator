#!/usr/bin/env bash
set -eu
# Verify: scripts/diagnostics/run-doctor.sh exits 0 with no FAIL lines.
test -x scripts/diagnostics/run-doctor.sh || { echo "FAIL: run-doctor.sh missing or not executable"; exit 1; }
out=$(bash scripts/diagnostics/run-doctor.sh 2>&1 || true)
rc=$?
if [ "$rc" != "0" ]; then
  echo "FAIL: run-doctor.sh exited $rc"
  echo "$out"
  exit 1
fi
if echo "$out" | grep -q '^FAIL:'; then
  echo "FAIL: run-doctor.sh reported failures:"
  echo "$out" | grep '^FAIL:'
  exit 1
fi
echo "PASS: doctor reports clean state"
