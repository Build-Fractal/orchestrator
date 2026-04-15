#!/usr/bin/env bash
set -eu
# Verify: .orchestrator/ exists with expected structure AND .specify/orchestrator/ is gone.
test -d .orchestrator || { echo "FAIL: .orchestrator/ directory missing"; exit 1; }
test ! -e .specify/orchestrator || { echo "FAIL: .specify/orchestrator/ still exists"; exit 1; }
test -d .orchestrator/milestones || { echo "FAIL: .orchestrator/milestones missing"; exit 1; }
test -f .orchestrator/KNOWLEDGE.md || { echo "FAIL: .orchestrator/KNOWLEDGE.md missing"; exit 1; }
test -f .orchestrator/DECISIONS.md || { echo "FAIL: .orchestrator/DECISIONS.md missing"; exit 1; }
test -f .orchestrator/execution-log.jsonl || { echo "FAIL: .orchestrator/execution-log.jsonl missing"; exit 1; }
test -f .orchestrator/config.yml || { echo "FAIL: .orchestrator/config.yml missing"; exit 1; }
echo "PASS: state tree migrated to .orchestrator/"
