#!/usr/bin/env bash
# scripts/verify/m013-p01-defect-schema.sh
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="${REPO_ROOT}/knowledge/spec/defect"
README="${DIR}/README.md"

fail_count=0
assert_ok() {
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    fail_count=$((fail_count + 1))
  fi
}

[ -d "$DIR" ]
assert_ok $? "knowledge/spec/defect/ directory exists"

[ -f "$README" ]
assert_ok $? "README.md exists"

for field in id status chunk phase tests github_issue_number created_at ingested_at; do
  grep -q "\`${field}\`" "$README"
  assert_ok $? "README documents field: ${field}"
done

for val in open chunk-lookup-failed triaged closed; do
  grep -q "$val" "$README"
  assert_ok $? "README documents status: ${val}"
done

grep -q "M020" "$README"
assert_ok $? "README references M020 forward-compatibility"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-defect-schema.sh"
  exit 0
fi
echo "FAIL: m013-p01-defect-schema.sh ($fail_count failures)"
exit 1
