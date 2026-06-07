#!/usr/bin/env bash
# tools/verify/m034-p03-phase-suite.sh — M034 P03 T04 phase-suite aggregator.
#
# The single entry point orchestrator:verify P03 (and the phase Must-Have
# `Check:` commands) resolve to. Runs the four P03 slice verifiers in order
# (plain `bash <path>` — never run-probe, per plan-time discipline rule 4),
# printing each one's output.
#
# Prints "PASS: m034-p03 phase-suite (4/4 slices)" + exit 0 iff every slice
# exited 0. Otherwise "FAIL: m034-p03 phase-suite — <which failed>" + exit 1.
# Bash 3.2 / POSIX-sh single file (CON-1 / AD-19).

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

FAILED=""

for slice in mcp-stub registration runtime-assumptions byte-parity; do
  verifier="$REPO_ROOT/tools/verify/m034-p03-$slice.sh"
  echo "--- m034-p03-$slice ---"
  if [ ! -f "$verifier" ]; then
    echo "slice verifier missing: $verifier"
    FAILED="$FAILED slice:$slice(missing)"
    continue
  fi
  bash "$verifier"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    FAILED="$FAILED slice:$slice(exit $rc)"
  fi
done

if [ -z "$FAILED" ]; then
  echo "PASS: m034-p03 phase-suite (4/4 slices)"
  exit 0
fi

echo "FAIL: m034-p03 phase-suite —$FAILED"
exit 1
