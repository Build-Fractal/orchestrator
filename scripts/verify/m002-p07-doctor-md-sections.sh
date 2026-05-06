#!/usr/bin/env bash
set -eu
f="commands/doctor.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi 'orphan' "$f" || { echo "FAIL: doctor.md does not mention orphaned artifacts"; exit 1; }
grep -qi 'stale' "$f" || { echo "FAIL: doctor.md does not mention stale knowledge"; exit 1; }
grep -qi 'scope' "$f" || { echo "FAIL: doctor.md does not mention scope issues"; exit 1; }
grep -qi 'cost' "$f" || { echo "FAIL: doctor.md does not mention cost spikes"; exit 1; }
grep -q 'orchestrator:doctor' "$f" || { echo "FAIL: doctor.md missing command name"; exit 1; }
grep -q 'run-doctor.sh' "$f" || { echo "FAIL: doctor.md does not reference run-doctor.sh"; exit 1; }
echo "PASS: doctor.md describes all four core check categories"
