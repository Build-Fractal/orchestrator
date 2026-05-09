#!/usr/bin/env bash
# tools/verify/p00-source-types-shape.sh — M036 P00 T01 shape gate for
# references/reference-source-types.yaml. Asserts schema_version + type
# header + the five-key source_types: map and a default_tier: declaration.
# Single-script-file shape per AD-19.
set -eu
FILE="${1:-references/reference-source-types.yaml}"
pass=0
fail=0
if [ ! -f "$FILE" ]; then
  echo "FAIL: $FILE missing"
  echo "SUMMARY: p00-source-types-shape.sh pass=0 fail=1"
  exit 1
fi
for token in 'schema_version' 'type: reference-source-types' 'source_types:' 'cms-rule:' 'training-material:' 'glossary:' 'regulatory-doc:' 'business-doc:' 'default_tier:'; do
  if grep -qF "$token" "$FILE"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $FILE missing token: $token"
  fi
done
echo "SUMMARY: p00-source-types-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
