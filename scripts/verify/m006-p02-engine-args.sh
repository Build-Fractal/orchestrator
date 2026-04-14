#!/usr/bin/env bash
# Verify references/engine.md documents CLI arguments and environment variables.
set -eu
f="references/engine.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "\-\-dry-run" "$f" || { echo "FAIL: missing --dry-run documentation"; exit 1; }
grep -q "\-\-force" "$f" || { echo "FAIL: missing --force documentation"; exit 1; }
grep -q "ORCH_RUN_SEED" "$f" || { echo "FAIL: missing ORCH_RUN_SEED documentation"; exit 1; }
grep -q "ORCH_DRY_RUN" "$f" || { echo "FAIL: missing ORCH_DRY_RUN documentation"; exit 1; }
grep -q "ORCH_FORCE" "$f" || { echo "FAIL: missing ORCH_FORCE documentation"; exit 1; }
grep -q "ORCH_ENGINE_STOP_AFTER_TASK" "$f" || { echo "FAIL: missing ORCH_ENGINE_STOP_AFTER_TASK documentation"; exit 1; }
echo "PASS: engine.md CLI arguments and environment variables"
