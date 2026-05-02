#!/usr/bin/env bash
# tools/verify/p00-spec-management-crossref.sh -- M036 P00 T03 gate
# for the cross-reference paragraph added to spec-management.md.
# Asserts the paragraph names file-formats.md, the [source:<cite_id>]
# namespace, and the M036 milestone tag.
set -eu
FILE="${1:-references/spec-management.md}"
pass=0
fail=0
if [ ! -f "$FILE" ]; then
  echo "FAIL: $FILE missing"
  echo "SUMMARY: p00-spec-management-crossref.sh pass=0 fail=1"
  exit 1
fi
for token in 'file-formats.md' 'source:<cite_id>' 'M036'; do
  if grep -qF "$token" "$FILE"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $FILE missing token: $token"
  fi
done
echo "SUMMARY: p00-spec-management-crossref.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
