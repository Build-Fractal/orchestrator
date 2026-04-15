#!/usr/bin/env bash
set -eu
# One-shot helper: capture the historical portion of CHANGELOG.md
# (everything from the FIRST `## [` heading downward) into a snapshot
# file that T04 diffs against to prove historical entries were not
# rewritten during P03. Run this once in T01, before any CHANGELOG edit.
OUT=scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt
SRC=CHANGELOG.md
test -f "$SRC" || { echo "FAIL: $SRC missing"; exit 1; }
awk '/^## \[/{found=1} found{print}' "$SRC" > "$OUT"
test -s "$OUT" || { echo "FAIL: snapshot empty"; exit 1; }
echo "PASS: snapshot written to $OUT"
