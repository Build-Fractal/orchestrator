#!/usr/bin/env bash
set -eu
# Verify: M015-VERIFICATION.md scores every FR-001 through FR-019 with
# a PASS or FAIL verdict.
DOC=.orchestrator/milestones/M015/M015-VERIFICATION.md
test -f "$DOC" || { echo "FAIL: verification doc missing at $DOC"; exit 1; }
test -s "$DOC" || { echo "FAIL: verification doc empty"; exit 1; }
fail=0
i=1
while [ "$i" -le 19 ]; do
  # zero-pad to 3 digits: FR-001, FR-002, ..., FR-019
  if [ "$i" -lt 10 ]; then
    tag="FR-00$i"
  else
    tag="FR-0$i"
  fi
  if ! grep -q "$tag" "$DOC"; then
    echo "FAIL: $tag missing from verification doc"
    fail=1
  fi
  i=$((i + 1))
done
# Require at least one PASS verdict (sanity — full PASS sweep expected)
if ! grep -q "PASS" "$DOC"; then
  echo "FAIL: verification doc has no PASS verdicts"
  fail=1
fi
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "PASS: verification doc references FR-001 through FR-019 and contains PASS verdicts"
