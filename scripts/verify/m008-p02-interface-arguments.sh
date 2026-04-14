#!/usr/bin/env bash
# Verifies dispatch-interface.sh accepts required arguments and rejects
# missing inputs with a structured error.
set -u

f="scripts/dispatch/dispatch-interface.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Script declares the expected flags
grep -q '\-\-task-plan' "$f" || { echo "FAIL: $f missing --task-plan"; exit 1; }
grep -q '\-\-payload' "$f" || { echo "FAIL: $f missing --payload"; exit 1; }
grep -q '\-\-intensity-metadata' "$f" || { echo "FAIL: $f missing --intensity-metadata"; exit 1; }
grep -q '\-\-backend' "$f" || { echo "FAIL: $f missing --backend"; exit 1; }
grep -q 'backend-registry.sh' "$f" || { echo "FAIL: $f does not reference backend-registry.sh"; exit 1; }

# Missing --task-plan: must exit non-zero and emit a dispatch-error on stderr
err="$(bash "$f" --payload /dev/null 2>&1 >/dev/null || true)"
echo "$err" | grep -q '^type: "dispatch-error"' || { echo "FAIL: missing --task-plan did not emit dispatch-error"; exit 1; }
echo "$err" | grep -q 'input_invalid' || { echo "FAIL: missing --task-plan did not emit error_type=input_invalid"; exit 1; }

# Missing --payload: must exit non-zero and emit a dispatch-error
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
echo '---' > "$tmp/tp.md"
err2="$(bash "$f" --task-plan "$tmp/tp.md" 2>&1 >/dev/null || true)"
echo "$err2" | grep -q '^type: "dispatch-error"' || { echo "FAIL: missing --payload did not emit dispatch-error"; exit 1; }

echo "PASS: dispatch-interface.sh accepts required arguments and rejects missing inputs with structured errors"
