#!/usr/bin/env bash
# Verify docs/getting-started.md documents the complete orchestrator workflow.
set -eu
f="docs/getting-started.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "evaluate" "$f" || { echo "FAIL: missing evaluate command mention"; exit 1; }
grep -q "discuss" "$f" || { echo "FAIL: missing discuss command mention"; exit 1; }
grep -q "roadmap" "$f" || { echo "FAIL: missing roadmap command mention"; exit 1; }
grep -q "plan-phase" "$f" || { echo "FAIL: missing plan-phase command mention"; exit 1; }
grep -q "dispatch\|auto" "$f" || { echo "FAIL: missing dispatch or auto command mention"; exit 1; }
grep -q "verify" "$f" || { echo "FAIL: missing verify command mention"; exit 1; }
grep -q "status" "$f" || { echo "FAIL: missing status command mention"; exit 1; }
echo "PASS: getting-started.md workflow documentation"
