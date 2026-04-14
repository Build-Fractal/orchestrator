#!/usr/bin/env bash
set -eu
f="scripts/dispatch/classify-complexity.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'complexity:' "$f" || { echo "FAIL: does not check for complexity: frontmatter"; exit 1; }
grep -q 'frontmatter\|^---' "$f" || grep -q 'sed.*---' "$f" || { echo "FAIL: does not parse YAML frontmatter for override"; exit 1; }
grep -qE 'explicit|override' "$f" || grep -q 'complexity.*heavy\|complexity.*standard\|complexity.*light' "$f" || { echo "FAIL: no explicit override logic"; exit 1; }
echo "PASS: classify-complexity.sh respects explicit complexity: frontmatter override"
