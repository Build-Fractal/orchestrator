#!/usr/bin/env bash
set -eu
# Verify: M015-SUMMARY.md exists and follows milestone-summary schema.
DOC=.orchestrator/milestones/M015/M015-SUMMARY.md
test -f "$DOC" || { echo "FAIL: milestone summary missing at $DOC"; exit 1; }
test -s "$DOC" || { echo "FAIL: milestone summary empty"; exit 1; }
fail=0
# Required schema markers
if ! grep -q "type: milestone-summary" "$DOC"; then
  echo "FAIL: missing 'type: milestone-summary' in frontmatter"
  fail=1
fi
if ! grep -q "schema_version:" "$DOC"; then
  echo "FAIL: missing schema_version in frontmatter"
  fail=1
fi
# Each phase must be referenced by id
for p in P01 P02 P03 P04; do
  if ! grep -q "$p" "$DOC"; then
    echo "FAIL: phase $p not referenced in milestone summary"
    fail=1
  fi
done
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "PASS: milestone summary schema-shaped and references P01..P04"
