#!/usr/bin/env bash
# m008-p04-resolve-root-exists.sh -- verify resolve-root.sh exists and is executable
set -u

SCRIPT="scripts/state/resolve-root.sh"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT does not exist"
  exit 1
fi

if [[ ! -x "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT is not executable"
  exit 1
fi

# Sanity: script should mention the key precedence tokens
if ! grep -q "ORCHESTRATOR_ROOT" "$SCRIPT"; then
  echo "FAIL: $SCRIPT missing ORCHESTRATOR_ROOT env-var handling"
  exit 1
fi

echo "PASS: resolve-root.sh exists, executable, and mentions ORCHESTRATOR_ROOT"
exit 0
