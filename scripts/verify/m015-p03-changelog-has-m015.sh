#!/usr/bin/env bash
set -eu
test -f CHANGELOG.md || { echo "FAIL: CHANGELOG.md missing"; exit 1; }
SNAP=scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt
test -f "$SNAP" || { echo "FAIL: snapshot $SNAP missing (T01 incomplete)"; exit 1; }
grep -q "M015" CHANGELOG.md || { echo "FAIL: CHANGELOG.md has no M015 entry"; exit 1; }
M015_LINE=$(grep -n "M015" CHANGELOG.md | head -1 | cut -d: -f1)
FIRST_OLD=$(grep -n "^## \[0\.8\.0\]" CHANGELOG.md | head -1 | cut -d: -f1)
test -n "$M015_LINE" || { echo "FAIL: no M015 line number resolved"; exit 1; }
test -n "$FIRST_OLD" || { echo "FAIL: no [0.8.0] header resolved"; exit 1; }
if [ "$M015_LINE" -ge "$FIRST_OLD" ]; then
  echo "FAIL: M015 entry must appear above [0.8.0] entry"
  exit 1
fi
awk '/^## \[/{count++} count>=2{print}' CHANGELOG.md > /tmp/m015-p03-changelog-current-historical.txt
if ! diff -q "$SNAP" /tmp/m015-p03-changelog-current-historical.txt >/dev/null 2>&1; then
  echo "FAIL: historical CHANGELOG entries have been modified"
  exit 1
fi
echo "PASS: CHANGELOG.md has M015 entry at top; historical entries immutable"
