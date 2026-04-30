#!/usr/bin/env bash
# tools/verify/p05-doctor-config-check.sh — M030/P05/T01 SC-9 wrapper.
#
# Delegates to tools/verify/p01-doctor-config-check.sh (P01/T04 deliverable)
# which exercises both well-formed and malformed templates/model-routing.yml
# scenarios against scripts/diagnostics/run-doctor.sh --config-check.
#
# This wrapper exists so the P05 phase-suite carries the SC-9 contract
# gate (FR-17: doctor --config-check exits 1 with file:line on malformed
# routing.yml) without re-implementing the underlying scenarios.
#
# Mirrors the p04-additive-schema.sh delegate-and-pass-through shape.
#
# Bash 3.2 compatible. AD-19 single-script-file shape (invoked via plain
# `bash <path>`; no compound chains).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

UPSTREAM="$PROJECT_ROOT/tools/verify/p01-doctor-config-check.sh"

pass=0
fail=0

if [ ! -f "$UPSTREAM" ]; then
  echo "FAIL: p01-doctor-config-check.sh missing at $UPSTREAM"
  echo "SUMMARY: p05-doctor-config-check.sh pass=0 fail=1"
  exit 1
fi

bash "$UPSTREAM"
rc=$?

if [ "$rc" -eq 0 ]; then
  pass=1
  echo "OK: p01-doctor-config-check.sh exited 0 (SC-9 gate green)"
else
  fail=1
  echo "FAIL: p01-doctor-config-check.sh exited $rc"
fi

echo "SUMMARY: p05-doctor-config-check.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
