#!/usr/bin/env bash
# tools/verify/p00-taxonomy-shape.sh — M036 P00 T01 shape gate for
# references/reference-taxonomy.md. Asserts frontmatter + ## Categories
# heading + each of the four taxonomy categories appears as a level-3
# heading. Single-script-file shape per AD-19.
set -eu
FILE="${1:-references/reference-taxonomy.md}"
pass=0
fail=0
if [ ! -f "$FILE" ]; then
  echo "FAIL: $FILE missing"
  echo "SUMMARY: p00-taxonomy-shape.sh pass=0 fail=1"
  exit 1
fi
for token in 'schema_version' 'type: reference-taxonomy' '## Categories' '### cms-rule' '### training-material' '### glossary' '### regulatory-doc'; do
  if grep -qF "$token" "$FILE"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $FILE missing token: $token"
  fi
done
echo "SUMMARY: p00-taxonomy-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
