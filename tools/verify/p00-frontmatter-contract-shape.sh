#!/usr/bin/env bash
# tools/verify/p00-frontmatter-contract-shape.sh — M036 P00 T01 shape gate
# for references/reference-frontmatter-contract.md. Asserts frontmatter +
# the four section headings + every required-field / chunk-output /
# graph-edge field name appears as a fixed-string match. Structural only;
# semantic enforcement is T03's job. Single-script-file shape per AD-19.
set -eu
FILE="${1:-references/reference-frontmatter-contract.md}"
pass=0
fail=0
if [ ! -f "$FILE" ]; then
  echo "FAIL: $FILE missing"
  echo "SUMMARY: p00-frontmatter-contract-shape.sh pass=0 fail=1"
  exit 1
fi
for token in 'schema_version' 'type: reference-frontmatter-contract' '## Required Fields' 'source' 'published' 'version' 'cite_id' 'topic_tags' 'applies_to_field' '## Chunk-Output Additions' 'category' 'chunk_id' 'content_hash' 'scope_tags' '## Graph Edge Fields' 'cites' 'derived_from' 'relates_to' 'supersedes'; do
  if grep -qF "$token" "$FILE"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $FILE missing token: $token"
  fi
done
echo "SUMMARY: p00-frontmatter-contract-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
