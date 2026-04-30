#!/usr/bin/env bash
# tools/verify/p00-d-a4-independence.sh — M030/P00/T03 D-A4 independence gate.
#
# Asserts the load-bearing D-A4 property: the classifier
# ground-truth corpus (`tests/fixtures/m030-classifier-corpus/labels.yml`)
# was authored independently of `scripts/dispatch/classify-task.sh`.
#
# Two phases:
#
#   Phase 1 (during P00, pre-P01 commit of classifier):
#     `scripts/dispatch/classify-task.sh` does NOT yet exist on disk.
#     Independence holds by absence — the classifier cannot have
#     informed the labeling because the classifier does not exist.
#     This script ships ONLY the absence path.
#
#   Phase 2 (post-P01, NOT YET ENABLED — comments only):
#     Once `scripts/dispatch/classify-task.sh` is committed, this
#     verifier should graduate to a `git log` ordering check:
#
#       labels_ts=$(git log --diff-filter=A --pretty=format:%at \
#         -- tests/fixtures/m030-classifier-corpus/labels.yml | tail -1)
#       classifier_ts=$(git log --diff-filter=A --pretty=format:%at \
#         -- scripts/dispatch/classify-task.sh | tail -1)
#       [ "$labels_ts" -lt "$classifier_ts" ] || FAIL
#
#     P01's plan-phase MUST flip this verifier from absence-check to
#     git-log-ordering before ratifying SC-10. The current P00 ship
#     deliberately avoids the git-log path because the classifier
#     does not yet exist and the comparison would be ill-defined.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.
# Working tree assumed at $(pwd). No path argument.

set -u

CLASSIFIER="scripts/dispatch/classify-task.sh"

pass=0
fail=0

if [ ! -f "$CLASSIFIER" ]; then
  printf 'OK: classify-task.sh absent -- D-A4 independence by construction\n'
  pass=1
else
  printf 'FAIL: classify-task.sh exists at %s -- D-A4 phase-2 git-log check not yet enabled in this verifier\n' "$CLASSIFIER"
  printf 'HINT: graduate this script to the git-log ordering check (see header comments) before P01 close.\n'
  fail=1
fi

printf 'SUMMARY: p00-d-a4-independence.sh pass=%s fail=%s\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
