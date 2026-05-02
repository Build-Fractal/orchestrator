#!/usr/bin/env bash
# tools/verify/p00-edge-types-shape.sh -- M036 P00 T02 shape gate for
# references/reference-edge-types.md. Asserts frontmatter + ## Edge
# Types heading + each of the five edge types appears as a level-3
# heading. Single-script-file shape per AD-19.
set -eu
FILE="${1:-references/reference-edge-types.md}"
pass=0
fail=0
if [ ! -f "$FILE" ]; then
  echo "FAIL: $FILE missing"
  echo "SUMMARY: p00-edge-types-shape.sh pass=0 fail=1"
  exit 1
fi
for token in 'schema_version' 'type: reference-edge-types' '## Edge Types' '### cites' '### derived_from' '### applies_to_field' '### relates_to' '### supersedes'; do
  if grep -qF "$token" "$FILE"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $FILE missing token: $token"
  fi
done
echo "SUMMARY: p00-edge-types-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
