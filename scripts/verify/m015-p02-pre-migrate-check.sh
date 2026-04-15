#!/usr/bin/env bash
set -eu
test -d .specify/orchestrator || { echo "FAIL: .specify/orchestrator/ missing — nothing to migrate"; exit 1; }
test ! -e .orchestrator || { echo "FAIL: .orchestrator/ already exists — cannot migrate"; exit 1; }
test -f .specify/orchestrator/config.yml || { echo "FAIL: source config.yml missing"; exit 1; }
test -d .specify/orchestrator/milestones || { echo "FAIL: source milestones/ missing"; exit 1; }
echo "PASS: pre-migration check — ready to migrate"
