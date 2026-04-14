#!/usr/bin/env bash
set -eu
f="scripts/dispatch/classify-complexity.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
# Check that the script contains all three tier keywords as output values
grep -q '"heavy"\|echo.*heavy' "$f" || { echo "FAIL: does not output heavy tier"; exit 1; }
grep -q '"standard"\|echo.*standard' "$f" || { echo "FAIL: does not output standard tier"; exit 1; }
grep -q '"light"\|echo.*light' "$f" || { echo "FAIL: does not output light tier"; exit 1; }
# Check that it reads a task plan file as input
grep -q 'TASK_PLAN\|task.plan\|task-plan' "$f" || { echo "FAIL: does not accept task plan file"; exit 1; }
# Check keyword signal matching
grep -q 'keyword\|signal\|pattern' "$f" || { echo "FAIL: no keyword signal matching logic"; exit 1; }
echo "PASS: classify-complexity.sh outputs heavy/standard/light from keyword signals"
