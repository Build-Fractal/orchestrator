#!/usr/bin/env bash
# Verify references/events.md documents all 18 canonical event types.
set -eu
f="references/events.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
for etype in SESSION_START SESSION_END PHASE_START PHASE_COMPLETE \
             TASK_START TASK_COMPLETE DISPATCH_START DISPATCH_FALLBACK \
             VERIFY_START VERIFY_COMPLETE GUARD_BLOCKED GUARD_WARNING \
             SAFETY_WARNING HOOK_START HOOK_COMPLETE HOOK_BLOCKED \
             HOOK_VIOLATION CHECKPOINT_WRITE CHECKPOINT_RESUME; do
  grep -q "$etype" "$f" || { echo "FAIL: missing event type $etype"; exit 1; }
done
echo "PASS: events.md documents all 18 canonical event types"
