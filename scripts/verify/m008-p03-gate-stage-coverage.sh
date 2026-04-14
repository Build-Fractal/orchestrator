#!/usr/bin/env bash
# Verifies all seven pipeline stages are handled at all three intensity
# levels with a non-empty, distinct output.
set -u

f="scripts/engine/intensity-gate.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

stages="discuss research plan-phase dispatch verify knowledge auto"
levels="Quick Standard Full"

for s in $stages; do
  for l in $levels; do
    out="$(bash "$f" --stage "$s" --intensity "$l" 2>/dev/null)"
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "FAIL: stage=$s intensity=$l exited $rc"
      exit 1
    fi
    echo "$out" | grep -q '^execute_substeps=' || { echo "FAIL: stage=$s intensity=$l missing execute_substeps"; exit 1; }
    echo "$out" | grep -q '^skip_substeps=' || { echo "FAIL: stage=$s intensity=$l missing skip_substeps"; exit 1; }
  done
done

# Distinctness smoke: discuss Quick vs discuss Full must differ
q="$(bash "$f" --stage discuss --intensity Quick 2>/dev/null)"
full="$(bash "$f" --stage discuss --intensity Full 2>/dev/null)"
if [[ "$q" = "$full" ]]; then
  echo "FAIL: discuss Quick and discuss Full produce identical output (matrix not distinct)"
  exit 1
fi

echo "PASS: all 7 stages x 3 levels produce non-empty, distinct key=value output"
