#!/usr/bin/env bash
set -eu
# Verify: all four evidence transcripts exist and are non-empty.
DIR=.orchestrator/milestones/M015/phases/P04/evidence
test -d "$DIR" || { echo "FAIL: evidence dir missing at $DIR"; exit 1; }
fail=0
for f in test-suite-transcript.txt doctor-report.txt migration-adapter-transcript.txt clean-clone-shape.txt; do
  path="$DIR/$f"
  if [ ! -f "$path" ]; then
    echo "FAIL: evidence missing: $path"
    fail=1
    continue
  fi
  if [ ! -s "$path" ]; then
    echo "FAIL: evidence empty: $path"
    fail=1
  fi
done
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "PASS: all four evidence transcripts present and non-empty"
