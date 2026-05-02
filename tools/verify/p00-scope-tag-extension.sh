#!/usr/bin/env bash
# tools/verify/p00-scope-tag-extension.sh -- M036 P00 T03 gate for
# the [source:<cite_id>] namespace addition to file-formats.md
# ### Scope Tags table. Asserts the new row's presence AND the
# pre-existing rows' presence (CON-1: no-regression).
set -eu
FILE="${1:-references/file-formats.md}"
pass=0
fail=0
if [ ! -f "$FILE" ]; then
  echo "FAIL: $FILE missing"
  echo "SUMMARY: p00-scope-tag-extension.sh pass=0 fail=1"
  exit 1
fi
for token in '### Scope Tags' '`source:<cite_id>`' 'reference-frontmatter-contract'; do
  if grep -qF "$token" "$FILE"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $FILE missing token: $token"
  fi
done
# Pre-existing namespaces preserved (CON-1).
for token in '`project`' '`milestone:M001`' '`phase:M001/P02`'; do
  if grep -qF "$token" "$FILE"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $FILE missing pre-existing token: $token"
  fi
done
echo "SUMMARY: p00-scope-tag-extension.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
