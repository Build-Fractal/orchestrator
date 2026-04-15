#!/usr/bin/env bash
set -eu
# Verify: scripts/state/resolve-root.sh contains no bridge rule.
RESOLVER=scripts/state/resolve-root.sh
test -f "$RESOLVER" || { echo "FAIL: $RESOLVER missing"; exit 1; }
# Must NOT contain the bridge source string.
if grep -q 'bridge:.specify/orchestrator' "$RESOLVER"; then
  echo "FAIL: bridge source rule still present in $RESOLVER"
  exit 1
fi
# Must NOT contain a directory test against .specify/orchestrator.
if grep -q '\-d "\$repo_root/\.specify/orchestrator"' "$RESOLVER"; then
  echo "FAIL: bridge directory test still present in $RESOLVER"
  exit 1
fi
# Must NOT contain the literal assignment to .specify/orchestrator as a resolved path.
if grep -q 'resolved=".specify/orchestrator"' "$RESOLVER"; then
  echo "FAIL: bridge assignment still present in $RESOLVER"
  exit 1
fi
# Must NOT mention the bridge rule in the header comment block.
if grep -q 'migration bridge' "$RESOLVER"; then
  echo "FAIL: bridge rule header comment still present in $RESOLVER"
  exit 1
fi
echo "PASS: resolver has no bridge rule"
