#!/usr/bin/env bash
# tools/verify/m041-p02-file-issue-mock.sh -- Verify file-issue.sh writes
# a correct create request JSON to GH_MOCK_DIR.
#
# Bash 3.2 compatible.
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Generate a triage report
bash "$PROJECT_ROOT/scripts/diagnostics/triage-issue.sh" \
  --symptom "test filing for verification" > "$tmpdir/report.md" 2>/dev/null

export GH_MOCK_DIR="$tmpdir"

bash "$PROJECT_ROOT/scripts/diagnostics/file-issue.sh" \
  --triage-report "$tmpdir/report.md" --yes 2>/dev/null
rc=$?

if [ "$rc" -ne 0 ]; then
  echo "FAIL: file-issue.sh exited $rc (expected 0)"
  exit 1
fi

request_file="$tmpdir/issue-create-request.json"
if [ ! -f "$request_file" ]; then
  echo "FAIL: issue-create-request.json not written to mock dir"
  exit 1
fi

contents="$(cat "$request_file")"

# Verify title field present
case "$contents" in
  *'"title"'*) : ;;
  *) echo "FAIL: request missing '\"title\"' field"; exit 1 ;;
esac

# Verify body field present
case "$contents" in
  *'"body"'*) : ;;
  *) echo "FAIL: request missing '\"body\"' field"; exit 1 ;;
esac

# Verify detective-triage label
case "$contents" in
  *'detective-triage'*) : ;;
  *) echo "FAIL: request missing 'detective-triage' label"; exit 1 ;;
esac

echo "PASS: file-issue.sh writes correct create request to mock"
