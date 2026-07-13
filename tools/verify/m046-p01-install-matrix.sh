#!/usr/bin/env bash
# tools/verify/m046-p01-install-matrix.sh
# M046 P01: install-matrix.log shows the probe hook staged + PreToolUse
# fragment merged (managed-tagged, idempotent, uninstall-clean, shape-guard
# coexistent) on BOTH install shapes (A=symlink/source, B=packaged bundle).
# Bash 3.2 compatible.
set -u
LOG=".orchestrator/milestones/M046/phases/P01/spike/hook/install-matrix.log"

if [ ! -f "$LOG" ]; then
  echo "FAIL: install-matrix log missing at $LOG"
  exit 1
fi

fail=0
FLAGS="staged=1 merged=1 coexists=1 idempotent=1 uninstall_clean=1"

if ! grep -q "^shape=A $FLAGS$" "$LOG"; then
  echo "FAIL: 'shape=A $FLAGS' not found in $LOG"
  fail=1
fi

if ! grep -q "^shape=B $FLAGS$" "$LOG"; then
  echo "FAIL: 'shape=B $FLAGS' not found in $LOG"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: install matrix shows shape=A and shape=B all-1s (staged, merged, coexists, idempotent, uninstall_clean)"
exit 0
