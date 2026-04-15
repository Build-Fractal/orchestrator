#!/usr/bin/env bash
set -eu
# Verify: the five primary standalone docs no longer instruct readers
# to install extension.yml, reference .specify/orchestrator/ as the
# canonical state path, or invoke /speckit.* slash commands as this
# project's SDD entry point.
PRIMARIES="README.md CLAUDE.md references/architecture.md references/installation.md docs/getting-started.md"
fail=0
for f in $PRIMARIES; do
  test -f "$f" || { echo "FAIL: $f missing"; fail=1; continue; }
  if grep -q "extension\.yml" "$f"; then
    echo "FAIL: '$f' still references extension.yml"
    fail=1
  fi
  if grep -q "\.specify/orchestrator" "$f"; then
    echo "FAIL: '$f' still references .specify/orchestrator"
    fail=1
  fi
  if grep -q "\.specify/memory/constitution" "$f"; then
    echo "FAIL: '$f' still references .specify/memory/constitution"
    fail=1
  fi
  if grep -qE "/speckit\.(specify|plan|tasks|clarify|implement|analyze|checklist)" "$f"; then
    echo "FAIL: '$f' still references /speckit.* slash commands as SDD entry points"
    fail=1
  fi
done
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "PASS: no legacy install/runtime references in primary standalone docs"
