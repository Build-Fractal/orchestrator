#!/usr/bin/env bash
# tools/verify/m041-p02-file-issue-comment.sh -- Verify file-issue.sh writes
# a correct comment request JSON when --comment-on is supplied.
#
# Bash 3.2 compatible.
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Generate a triage report
bash "$PROJECT_ROOT/scripts/diagnostics/triage-issue.sh" \
  --symptom "test comment for verification" > "$tmpdir/report.md" 2>/dev/null

export GH_MOCK_DIR="$tmpdir"

bash "$PROJECT_ROOT/scripts/diagnostics/file-issue.sh" \
  --triage-report "$tmpdir/report.md" --comment-on 42 2>/dev/null
rc=$?

if [ "$rc" -ne 0 ]; then
  echo "FAIL: file-issue.sh exited $rc (expected 0)"
  exit 1
fi

request_file="$tmpdir/issue-comment-request.json"
if [ ! -f "$request_file" ]; then
  echo "FAIL: issue-comment-request.json not written to mock dir"
  exit 1
fi

contents="$(cat "$request_file")"

# Verify issue_number field present
case "$contents" in
  *'"issue_number"'*) : ;;
  *) echo "FAIL: request missing '\"issue_number\"' field"; exit 1 ;;
esac

# Verify issue number 42 present
case "$contents" in
  *'42'*) : ;;
  *) echo "FAIL: request does not contain issue number 42"; exit 1 ;;
esac

echo "PASS: file-issue.sh writes correct comment request to mock"
