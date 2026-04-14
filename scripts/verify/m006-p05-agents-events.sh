#!/usr/bin/env bash
# Verify scripts/AGENTS.md documents event emission and result protocol.
set -eu
f="scripts/AGENTS.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "emit_event" "$f" || { echo "FAIL: missing emit_event documentation"; exit 1; }
grep -q "emit_result" "$f" || { echo "FAIL: missing emit_result documentation"; exit 1; }
grep -qi "silent failure\|RESULT.*line" "$f" || { echo "FAIL: missing silent failure definition"; exit 1; }
count=0
for evt in SESSION_START TASK_COMPLETE PHASE_COMPLETE; do
  grep -q "$evt" "$f" && count=$((count + 1))
done
test "$count" -ge 3 || { echo "FAIL: fewer than 3 event types listed (found $count)"; exit 1; }
echo "PASS: scripts/AGENTS.md event emission and result protocol documentation"
