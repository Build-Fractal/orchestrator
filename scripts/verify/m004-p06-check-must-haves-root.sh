#!/usr/bin/env bash
# Verify check-must-haves.sh resolves PROJECT_ROOT to the actual repo root
# (not the milestone directory) when phase dirs are under .orchestrator/
set -eu
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# The script must use .git or .orchestrator as root markers,
# not just walk up to the parent of "phases"
if grep -q '\.git\|\.orchestrator' "$PROJECT_ROOT/scripts/verify/check-must-haves.sh" 2>/dev/null; then
  echo "PASS: check-must-haves.sh uses repo root markers"
  exit 0
fi

echo "FAIL: check-must-haves.sh does not use repo root markers (.git, .orchestrator)"
exit 1
