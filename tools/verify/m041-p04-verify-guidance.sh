#!/usr/bin/env bash
# tools/verify/m041-p04-verify-guidance.sh
# Verifies commands/verify.md carries detective-recommendation guidance
# scoped to orchestrator-internal failures (FR-8 / NG-1).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

target="commands/verify.md"
if [ ! -f "$target" ]; then
  echo "FAIL: $target not found"
  exit 1
fi

if ! grep -q "detective-recommend.sh" "$target"; then
  echo "FAIL: verify.md does not reference detective-recommend.sh"
  exit 1
fi

# Must scope to orchestrator-internal failures, not user-code check failures (NG-1)
if ! grep -qi "orchestrator-internal" "$target"; then
  echo "FAIL: verify.md guidance does not scope to orchestrator-internal failures"
  exit 1
fi

if ! grep -q "diagnose" "$target"; then
  echo "FAIL: verify.md guidance does not distinguish detective from diagnose (NG-1)"
  exit 1
fi

echo "PASS: verify.md carries orchestrator-internal-scoped detective guidance"
