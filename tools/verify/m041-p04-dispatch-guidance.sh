#!/usr/bin/env bash
# tools/verify/m041-p04-dispatch-guidance.sh
# Verifies commands/dispatch.md carries detective-recommendation guidance
# scoped to internal dispatch errors, not user-fixable preconditions (FR-8 / NG-1).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

target="commands/dispatch.md"
if [ ! -f "$target" ]; then
  echo "FAIL: $target not found"
  exit 1
fi

if ! grep -q "detective-recommend.sh" "$target"; then
  echo "FAIL: dispatch.md does not reference detective-recommend.sh"
  exit 1
fi

if ! grep -qi "orchestrator-internal" "$target"; then
  echo "FAIL: dispatch.md guidance does not scope to orchestrator-internal errors"
  exit 1
fi

# Must warn against firing on user-fixable preconditions (NG-1)
if ! grep -qi "user-fixable\|sequencing" "$target"; then
  echo "FAIL: dispatch.md guidance does not exclude user-fixable preconditions"
  exit 1
fi

echo "PASS: dispatch.md carries internal-error-scoped detective guidance"
