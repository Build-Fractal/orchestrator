#!/usr/bin/env bash
# scripts/verify/m013-p01-uat-ingest.sh
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INGEST="${REPO_ROOT}/scripts/integrations/uat-ingest.sh"
FIXTURES="${REPO_ROOT}/tests/fixtures/m013-p01/uat-bug-issues"

fail_count=0
assert_ok() {
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    fail_count=$((fail_count + 1))
  fi
}
assert_eq() {
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (expected=$2 actual=$3)"
    fail_count=$((fail_count + 1))
  fi
}

[ -f "$INGEST" ]
assert_ok $? "uat-ingest.sh present"

[ -d "$FIXTURES" ]
assert_ok $? "fixtures directory present"

# Build a tempdir with the same structure as repo, pre-seed KNOWLEDGE-INDEX.md
# with a Spec Chunks section naming SPEC-US-001.
TMP="$(mktemp -d)"
mkdir -p "${TMP}/knowledge/spec/defect" "${TMP}/scripts/integrations" "${TMP}/tests/fixtures/m013-p01/uat-bug-issues"
cp "$INGEST" "${TMP}/scripts/integrations/"
cp "${FIXTURES}"/*.json "${TMP}/tests/fixtures/m013-p01/uat-bug-issues/"

cat > "${TMP}/KNOWLEDGE-INDEX.md" <<'EOF'
# Knowledge Index

## Spec Chunks
SPEC-US-001 | Full Phase Runs To Completion Without Prompts |
EOF

# First run
bash "${TMP}/scripts/integrations/uat-ingest.sh" --source "${TMP}/tests/fixtures/m013-p01/uat-bug-issues" --root "$TMP" > "${TMP}/run1.out" 2>&1
rc=$?
assert_eq "first run exit 0" "0" "$rc"

# Two defect files created
count=$(ls "${TMP}/knowledge/spec/defect/"SPEC-DEFECT-*.md 2>/dev/null | wc -l | tr -d ' ')
assert_eq "two defect files written" "2" "$count"

# Valid-chunk: status=open, chunk=SPEC-US-001
valid_file="${TMP}/knowledge/spec/defect/SPEC-DEFECT-101.md"
[ -f "$valid_file" ]
assert_ok $? "SPEC-DEFECT-101.md written"

grep -q '^status: open' "$valid_file"
assert_ok $? "valid-chunk has status: open"

grep -q '^chunk: "SPEC-US-001"' "$valid_file"
assert_ok $? "valid-chunk has chunk: SPEC-US-001"

# Unknown-chunk: status=chunk-lookup-failed, chunk=""
unknown_file="${TMP}/knowledge/spec/defect/SPEC-DEFECT-102.md"
[ -f "$unknown_file" ]
assert_ok $? "SPEC-DEFECT-102.md written"

grep -q '^status: chunk-lookup-failed' "$unknown_file"
assert_ok $? "unknown-chunk flagged"

grep -q '^chunk: ""' "$unknown_file"
assert_ok $? "unknown-chunk has empty chunk field"

# Both files: phase empty, tests empty
grep -q '^phase: ""' "$valid_file"
assert_ok $? "valid-chunk phase is empty on ingest"

grep -q '^tests: \[\]' "$valid_file"
assert_ok $? "valid-chunk tests is empty list on ingest"

# Idempotency: second run
bash "${TMP}/scripts/integrations/uat-ingest.sh" --source "${TMP}/tests/fixtures/m013-p01/uat-bug-issues" --root "$TMP" > "${TMP}/run2.out" 2>&1
grep -q "SUMMARY: created=0 skipped=2 errors=0" "${TMP}/run2.out"
assert_ok $? "second run idempotent"

# Malformed fixture
echo '{"title": "no issue number"}' > "${TMP}/tests/fixtures/m013-p01/uat-bug-issues/bad.json"
bash "${TMP}/scripts/integrations/uat-ingest.sh" --source "${TMP}/tests/fixtures/m013-p01/uat-bug-issues" --root "$TMP" > "${TMP}/run3.out" 2>&1
rc=$?
assert_eq "malformed fixture exits 1" "1" "$rc"

rm -rf "$TMP"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-uat-ingest.sh"
  exit 0
fi
echo "FAIL: m013-p01-uat-ingest.sh ($fail_count failures)"
exit 1
