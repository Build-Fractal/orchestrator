#!/usr/bin/env bash
# tools/verify/p01-d-a4-timeline.sh -- D-A4/SC-10 timeline-ordering verifier (graduation).
#
# Two-mode operation:
#   Mode A (pre-T02, classify-task.sh absent): pass by absence.
#   Mode B (post-T02, classify-task.sh exists): assert
#     labels.yml first-commit-ts < classify-task.sh first-commit-ts
#     via `git log --diff-filter=A --pretty=format:%at`.
#
# Output contract:
#   stdout final line: "SUMMARY: p01-d-a4-timeline.sh pass=N fail=M"
#   exit 0 iff pass=1 fail=0.
#
# Bash 3.2 compatible. AD-19 single-script-file shape (no compound
# chains, no $() with pipes feeding compound operators, no process
# substitution).

set -uo pipefail

labels_path="tests/fixtures/m030-classifier-corpus/labels.yml"
classifier_path="scripts/dispatch/classify-task.sh"

pass=0
fail=0

if [ ! -f "$labels_path" ]; then
  echo "FAIL: $labels_path not found -- D-A4 corpus missing"
  fail=$((fail+1))
  echo "SUMMARY: p01-d-a4-timeline.sh pass=$pass fail=$fail"
  exit 1
fi

if [ ! -f "$classifier_path" ]; then
  # Mode A: classify-task.sh absent -- independence by construction.
  echo "OK: classify-task.sh absent -- D-A4 independence by construction (pre-T02 mode)"
  pass=$((pass+1))
  echo "SUMMARY: p01-d-a4-timeline.sh pass=$pass fail=$fail"
  exit 0
fi

# Mode B: classify-task.sh exists -- git-log ordering check.
labels_ts="$(git log --diff-filter=A --pretty=format:%at -- "$labels_path" | tail -1)"
classifier_ts="$(git log --diff-filter=A --pretty=format:%at -- "$classifier_path" | tail -1)"

if [ -z "$labels_ts" ]; then
  echo "FAIL: $labels_path has no add-commit in git log"
  fail=$((fail+1))
  echo "SUMMARY: p01-d-a4-timeline.sh pass=$pass fail=$fail"
  exit 1
fi

if [ -z "$classifier_ts" ]; then
  echo "FAIL: $classifier_path has no add-commit in git log"
  fail=$((fail+1))
  echo "SUMMARY: p01-d-a4-timeline.sh pass=$pass fail=$fail"
  exit 1
fi

if [ "$labels_ts" -lt "$classifier_ts" ]; then
  echo "OK: labels.yml committed at $labels_ts precedes classify-task.sh at $classifier_ts"
  pass=$((pass+1))
  echo "SUMMARY: p01-d-a4-timeline.sh pass=$pass fail=$fail"
  exit 0
else
  echo "FAIL: D-A4 timeline violated -- labels.yml=$labels_ts classify-task.sh=$classifier_ts"
  fail=$((fail+1))
  echo "SUMMARY: p01-d-a4-timeline.sh pass=$pass fail=$fail"
  exit 1
fi
