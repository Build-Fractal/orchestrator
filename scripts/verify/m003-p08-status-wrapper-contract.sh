#!/usr/bin/env bash
# scripts/verify/m003-p08-status-wrapper-contract.sh
# Truth: scripts/orchestrator/status.sh is a thin CLI wrapper that resolves the
# orchestrator root via resolve-root.sh, accepts --root, and emits a structured
# milestone summary (MILESTONE:/STATE:/PHASE: lines).
#
# Static shape checks (no execution here -- "works" is exercised by
# m003-p08-status-wrapper-works.sh against a populated root):
#   - file exists and is executable.
#   - at least 40 lines (non-trivial implementation).
#   - references resolve-root (M008 integration).
#   - declares MILESTONE: output contract.
#   - accepts --root flag.
#
# AD-19 / MEM001 safe. Exit 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATUS_SH="$REPO_ROOT/scripts/orchestrator/status.sh"

if [ ! -f "$STATUS_SH" ]; then
  echo "FAIL: $STATUS_SH missing"
  exit 1
fi

if [ ! -x "$STATUS_SH" ]; then
  echo "FAIL: $STATUS_SH not executable"
  exit 1
fi

lines="$(wc -l <"$STATUS_SH" | tr -d ' ')"
if [ "$lines" -lt 40 ]; then
  echo "FAIL: $STATUS_SH too short ($lines lines; expected >= 40)"
  exit 1
fi

if ! grep -q 'resolve-root' "$STATUS_SH"; then
  echo "FAIL: $STATUS_SH does not reference resolve-root"
  exit 1
fi

if ! grep -q 'MILESTONE:' "$STATUS_SH"; then
  echo "FAIL: $STATUS_SH does not declare MILESTONE: output contract"
  exit 1
fi

if ! grep -q -- '--root' "$STATUS_SH"; then
  echo "FAIL: $STATUS_SH does not accept --root flag"
  exit 1
fi

echo "PASS: status.sh contract satisfied ($lines lines)"
exit 0
