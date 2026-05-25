#!/usr/bin/env bash
# tools/verify/m041-p05-gate-yes-proceeds.sh
# FR-9: with --yes, file-issue.sh proceeds with the write even non-interactively.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash scripts/diagnostics/triage-issue.sh --symptom "gate yes-proceeds test" \
  > "$tmpdir/report.md" 2>/dev/null

# --yes + non-interactive stdin (< /dev/null) must still write the mock request
GH_MOCK_DIR="$tmpdir" bash scripts/diagnostics/file-issue.sh \
  --triage-report "$tmpdir/report.md" --yes < /dev/null > /dev/null 2>&1
rc=$?

if [ "$rc" -ne 0 ]; then
  echo "FAIL: file-issue.sh --yes exited $rc (expected 0)"
  exit 1
fi
if [ ! -f "$tmpdir/issue-create-request.json" ]; then
  echo "FAIL: --yes did not produce the mock create request (gate blocked the write)"
  exit 1
fi
echo "PASS: --yes proceeds with the write non-interactively"
