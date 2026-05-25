#!/usr/bin/env bash
# tools/verify/m041-p04-auto-hook.sh
# Verifies auto-loop.sh wires the detective recommendation hook at the
# unexpected-state seam, and that the hook is structurally correct.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

target="scripts/lifecycle/auto-loop.sh"
if [ ! -f "$target" ]; then
  echo "FAIL: $target not found"
  exit 1
fi

# Structural check: the unexpected-state case must call detective-recommend.sh
if ! grep -q "detective-recommend.sh" "$target"; then
  echo "FAIL: auto-loop.sh does not reference detective-recommend.sh"
  exit 1
fi

# The hook must be guarded by a file-existence test (advisory, never blocks)
if ! grep -q '\[ -f "\$_detective_recommend" \]' "$target"; then
  echo "FAIL: auto-loop.sh detective hook is not guarded by a file-existence test"
  exit 1
fi

# The hook must emit a symptom referencing the unexpected state
if ! grep -q "unexpected state" "$target"; then
  echo "FAIL: auto-loop.sh hook symptom does not reference the unexpected state"
  exit 1
fi

echo "PASS: auto-loop.sh wires the detective hook at the unexpected-state seam"
