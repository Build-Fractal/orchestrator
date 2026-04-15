#!/usr/bin/env bash
set -eu
# Verify: constitution at .orchestrator/memory/constitution.md; legacy .specify/memory/ gone.
test -f .orchestrator/memory/constitution.md || { echo "FAIL: .orchestrator/memory/constitution.md missing"; exit 1; }
test ! -e .specify/memory/constitution.md || { echo "FAIL: .specify/memory/constitution.md still exists"; exit 1; }
test ! -d .specify/memory || { echo "FAIL: .specify/memory/ directory still exists"; exit 1; }
# Cheap content sanity check: file should mention "Principle" at least once.
grep -q "Principle" .orchestrator/memory/constitution.md || { echo "FAIL: constitution body looks wrong (no 'Principle' found)"; exit 1; }
echo "PASS: constitution moved to .orchestrator/memory/constitution.md"
