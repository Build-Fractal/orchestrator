#!/usr/bin/env bash
set -eu
# Verify: a clean-clone simulation (via git archive HEAD) contains no
# extension-host artifacts. T02 runs git archive into a temp dir and
# writes a path-listing transcript to evidence/clean-clone-shape.txt.
# Required absent classes: extension.yml at root,
# .specify/scripts/bash/, .specify/templates/commands/,
# .specify/orchestrator/, .claude/commands/speckit.*.md.
SHAPE=.orchestrator/milestones/M015/phases/P04/evidence/clean-clone-shape.txt
test -f "$SHAPE" || { echo "FAIL: clean-clone shape missing at $SHAPE"; exit 1; }
test -s "$SHAPE" || { echo "FAIL: clean-clone shape empty"; exit 1; }
fail=0
# Each class is asserted absent by a negative grep
if grep -qE "^extension\.yml$|/extension\.yml$" "$SHAPE"; then
  echo "FAIL: extension.yml present in clean-clone shape"
  fail=1
fi
if grep -q "\.specify/scripts/bash/" "$SHAPE"; then
  echo "FAIL: .specify/scripts/bash/ present in clean-clone shape"
  fail=1
fi
if grep -q "\.specify/templates/commands/" "$SHAPE"; then
  echo "FAIL: .specify/templates/commands/ present in clean-clone shape"
  fail=1
fi
if grep -q "\.specify/orchestrator/" "$SHAPE"; then
  echo "FAIL: .specify/orchestrator/ present in clean-clone shape"
  fail=1
fi
if grep -qE "\.claude/commands/speckit\.[^/]+\.md" "$SHAPE"; then
  echo "FAIL: .claude/commands/speckit.*.md present in clean-clone shape"
  fail=1
fi
if ! grep -q "CLEAN_CLONE_OK" "$SHAPE"; then
  echo "FAIL: clean-clone shape missing CLEAN_CLONE_OK marker"
  fail=1
fi
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "PASS: clean-clone shape has no extension-host artifacts + CLEAN_CLONE_OK marker present"
