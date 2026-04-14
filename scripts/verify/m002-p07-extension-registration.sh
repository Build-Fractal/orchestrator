#!/usr/bin/env bash
set -eu
f="extension.yml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'speckit.orchestrator.doctor' "$f" || { echo "FAIL: doctor command not registered"; exit 1; }
grep -q 'commands/doctor.md' "$f" || { echo "FAIL: commands/doctor.md not registered"; exit 1; }
grep -q 'scripts/diagnostics/run-doctor.sh' "$f" || { echo "FAIL: run-doctor.sh not registered"; exit 1; }
grep -q 'scripts/diagnostics/check-orphaned.sh' "$f" || { echo "FAIL: check-orphaned.sh not registered"; exit 1; }
grep -q 'scripts/diagnostics/check-stale.sh' "$f" || { echo "FAIL: check-stale.sh not registered"; exit 1; }
grep -q 'scripts/diagnostics/check-scope.sh' "$f" || { echo "FAIL: check-scope.sh not registered in extension.yml"; exit 1; }
grep -q 'scripts/diagnostics/check-cost-spikes.sh' "$f" || { echo "FAIL: check-cost-spikes.sh not registered"; exit 1; }
echo "PASS: extension.yml registers doctor command and all core diagnostics scripts"
