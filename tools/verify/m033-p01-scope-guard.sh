#!/usr/bin/env bash
set -u -o pipefail

# m033-p01-scope-guard.sh
# SC-13 invariant: P01 must not author files belonging to P02–P05.
# This is a "should not exist on disk" check — at P01 close, none of
# the listed paths should exist. Once P02 lands grilling-shell.sh
# (etc.), validate-milestone.sh's phase-aware skipping excludes this
# verifier from the M033-wide aggregator.
#
# Additionally asserts P01 did not write under wiki/ or under
# tests/paired-m032-m033/ (M032 + M033 pairing scope).

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

pass=0
fail=0

forbidden=(
  scripts/lifecycle/grilling-shell.sh
  scripts/lifecycle/constitution-author.sh
  scripts/lifecycle/ingest-codebase.sh
  scripts/lifecycle/materials-intake.sh
  scripts/lifecycle/ideation.sh
  scripts/lifecycle/customblock-draft.sh
  scripts/verify/constitution-shape-lint.sh
  templates/constitution-starters/web-saas.md
  templates/constitution-starters/cli-tool.md
  templates/constitution-starters/library.md
  references/constitution-starter-format.md
  references/customblock-format.md
  tests/paired-m032-m033
)

for f in "${forbidden[@]}"; do
  if [ -e "$PROJECT_ROOT/$f" ]; then
    fail=$((fail+1))
    echo "FAIL: P01 scope-guard violated — $f exists (belongs to P02-P05)"
  else
    pass=$((pass+1))
    echo "PASS: $f not present (P02-P05 deliverable)"
  fi
done

# No M033-scoped wiki writes from P01 (SC-13 — wiki/ projection is a
# P02 deliverable). The wiki/ directory itself predates M033 (M012),
# so its existence is not a violation; the violation shape is any
# M033-tagged content authored under wiki/. We check for the specific
# P02 deliverable paths: wiki/M033/, wiki/docs/M033/, and any file or
# directory under wiki/ whose basename starts with "M033" or "m033".
wiki_violations=0
if [ -d "$PROJECT_ROOT/wiki" ]; then
  while IFS= read -r match; do
    [ -z "$match" ] && continue
    wiki_violations=$((wiki_violations+1))
    fail=$((fail+1))
    echo "FAIL: P01 scope-guard violated — $match (M033 wiki content is a P02 deliverable)"
  done <<EOF
$(find "$PROJECT_ROOT/wiki" \( -name 'M033*' -o -name 'm033*' \) -print 2>/dev/null)
EOF
fi
if [ "$wiki_violations" -eq 0 ]; then
  pass=$((pass+1))
  echo "PASS: no M033-scoped paths under wiki/ (SC-13 — P02 deliverable)"
fi

echo "SUMMARY: m033-p01-scope-guard.sh pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
