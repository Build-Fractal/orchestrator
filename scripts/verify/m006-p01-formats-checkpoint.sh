#!/usr/bin/env bash
# Verify references/file-formats.md documents engine-checkpoint.json format.
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "checkpoint" "$f" || { echo "FAIL: missing checkpoint documentation"; exit 1; }
grep -q "engine-checkpoint.json" "$f" || { echo "FAIL: missing engine-checkpoint.json reference"; exit 1; }
grep -q "run_id" "$f" || { echo "FAIL: missing run_id field"; exit 1; }
grep -q "last_task" "$f" || { echo "FAIL: missing last_task field"; exit 1; }
grep -q "checkpoint_write" "$f" || { echo "FAIL: missing checkpoint_write reference"; exit 1; }
echo "PASS: file-formats.md documents engine-checkpoint.json"
